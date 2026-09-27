-- ============================================================
-- ADMIN ROLES, ROW LEVEL SECURITY AND THE MODERATION LOG
--
-- Run this ONCE in Supabase Dashboard -> SQL Editor. It is written to be
-- re-runnable: every object is created with `if not exists` / `or replace` and
-- every policy is dropped before it is created, so applying it twice is a
-- no-op rather than an error.
--
-- What this file adds, and why each piece is necessary:
--
--   1. profiles.role            — where access level lives (fails closed).
--   2. admin_email_allowlist    — server-side list of sign-ups allowed to
--                                 start as admins. This is what makes the
--                                 `--dart-define=ADMIN_EMAILS` build flag
--                                 safe: the client *asks* for a role, the
--                                 database decides.
--   3. Column/constraint guards — a client can never write its own role.
--   4. admin_audit_log          — populated by triggers, so privileged
--                                 actions are recorded even if a modified
--                                 build of the app misbehaves.
--   5. Count maintenance triggers for the denormalised `total_lessons` and
--      `total_signs` columns.
--   6. RLS policies             — the actual enforcement. The in-app route
--                                 guard and hidden buttons are only UX; this
--                                 is what stops the anon key from writing
--                                 curriculum or escalating a role.
--   7. RPC functions            — aggregates PostgREST cannot express
--                                 (distinct-learner and distinct-sign counts).
--
-- After running this file, promote your first admin with
-- `supabase/promote_first_admin.sql`.
--
-- IMPORTANT: review section 8 before running it in production. It replaces
-- the write policies on the curriculum tables, which is the point, but it also
-- re-declares their read policies so that enabling RLS does not accidentally
-- lock the learner-facing app out of the catalogue.
-- ============================================================


-- ============================================================
-- 1. profiles.role
-- ============================================================

alter table public.profiles add column if not exists role text;

-- Normalise anything already there before the NOT NULL lands. A value the app
-- does not recognise must become 'learner', never NULL: UserRole.fromValue()
-- fails closed, and so must the database.
update public.profiles
   set role = 'learner'
 where role is null
    or role not in ('learner', 'admin');

alter table public.profiles alter column role set default 'learner';
alter table public.profiles alter column role set not null;

do $$
begin
  if not exists (
    select 1
      from pg_constraint
     where conrelid = 'public.profiles'::regclass
       and conname = 'profiles_role_check'
  ) then
    alter table public.profiles
      add constraint profiles_role_check
      check (role in ('learner', 'admin'));
  end if;
end $$;

create index if not exists profiles_role_idx on public.profiles (role);


-- ============================================================
-- 2. Sign-up allowlist
--
-- Rows here are written from the SQL Editor or by a service-role key only:
-- RLS is enabled below and no policy grants any client role access, so
-- `authenticated` and `anon` can neither read nor write this table. That is
-- the point — if clients could edit the allowlist, every user could add
-- themselves.
-- ============================================================

create table if not exists public.admin_email_allowlist (
  email text primary key
    constraint admin_email_allowlist_email_format
    check (email = lower(btrim(email)) and position('@' in email) > 1),
  note text,
  created_at timestamptz not null default now()
);

alter table public.admin_email_allowlist enable row level security;

revoke all on public.admin_email_allowlist from anon, authenticated;


-- ============================================================
-- 3. Helper functions
--
-- All of these are SECURITY DEFINER with an empty search_path: they are
-- called from RLS policies and from triggers, so they must be able to read
-- the tables regardless of the caller's own policies, and they must not be
-- hijackable by a caller-controlled search_path.
-- ============================================================

-- True when the caller holds the admin role. Used by every RLS policy below.
create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
      from public.profiles p
     where p.id = auth.uid()
       and p.role = 'admin'
  );
$$;

grant execute on function public.is_admin() to authenticated, service_role;

-- Whether a sign-up email is allowed to start as an admin.
create or replace function public.is_allowlisted_admin(p_email text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
      from public.admin_email_allowlist a
     where a.email = lower(btrim(coalesce(p_email, '')))
  );
$$;

-- The single source of truth for a role granted at sign-up.
create or replace function public.resolve_role_for_email(p_email text)
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select case
           when public.is_allowlisted_admin(p_email) then 'admin'
           else 'learner'
         end;
$$;

-- Actor identity for the audit log. Returns NULL when the write was not made
-- by a signed-in user (a seed script, or the sign-up trigger), which the audit
-- trigger renders as "system".
create or replace function public.current_actor_id()
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select auth.uid();
$$;

create or replace function public.current_actor_email()
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select lower(u.email)
    from auth.users u
   where u.id = auth.uid();
$$;

create or replace function public.current_actor_name()
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select nullif(
           btrim(
             coalesce(
               p.full_name,
               u.raw_user_meta_data ->> 'full_name',
               u.raw_user_meta_data ->> 'name'
             )
           ),
           ''
         )
    from auth.users u
    left join public.profiles p on p.id = u.id
   where u.id = auth.uid();
$$;


-- ============================================================
-- 4. Writing profiles
--
-- Two rules, both enforced by triggers so they hold no matter which code path
-- reaches the table:
--   * a client may only ever create its own row, and
--   * the role column is always recomputed server-side, so the value the app
--     sends during sign-up is advisory only.
-- ============================================================

create or replace function public.guard_profile_insert()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_email text;
begin
  -- A NULL auth.uid() means a trusted server-side insert (the sign-up
  -- trigger below, or the service role). Those may create any row, but still
  -- get the allowlist-derived role, so a server path cannot accidentally mint
  -- an admin that nobody recorded.
  if v_uid is not null and new.id is distinct from v_uid then
    raise exception 'A profile can only be created for the signed-in user.'
      using errcode = '42501';
  end if;

  v_email := lower(btrim(coalesce(
    new.email,
    (select u.email from auth.users u where u.id = new.id),
    ''
  )));

  new.email := v_email;
  new.role := public.resolve_role_for_email(v_email);

  return new;
end $$;

create or replace function public.guard_profile_update()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.id is distinct from old.id then
    raise exception 'A profile id is immutable.'
      using errcode = '42501';
  end if;

  -- Note this reads the *pre-update* row, so an admin demoting themselves still
  -- passes here. That is deliberate: the last-admin rule below is the one that
  -- has to stop it, and keeping the two concerns separate makes each readable.
  --
  -- A NULL auth.uid() means the SQL Editor or the service role. Those are
  -- trusted and are allowed through — see promote_first_admin.sql, which has to
  -- be able to grant the very first admin to an account that has none.
  if new.role is distinct from old.role
     and auth.uid() is not null
     and not public.is_admin() then
    raise exception 'Only an admin can change a role.'
      using errcode = '42501';
  end if;

  if new.email is distinct from old.email
     and auth.uid() is not null
     and not public.is_admin() then
    raise exception 'Only an admin can change an account email.'
      using errcode = '42501';
  end if;

  return new;
end $$;

-- Refuses to remove the final admin. Without this, one careless demotion (or a
-- script that demotes "everyone not in this list") locks every admin out of
-- the app with no client-side path back in, because the only way to grant a
-- role is to already have one.
create or replace function public.prevent_last_admin_demotion()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_remaining integer;
begin
  if new.role = 'admin' or old.role is distinct from 'admin' then
    return new;  -- a grant, or a row that was not an admin to begin with
  end if;

  -- A NULL auth.uid() is the SQL Editor or the service role, and those are
  -- left alone on purpose: an operator demoting the final admin from the
  -- dashboard is the escape hatch for exactly the lock-out this trigger is
  -- there to prevent, and they can always re-promote a row the same way.
  if auth.uid() is null then
    return new;
  end if;

  -- Serialise demotions against each other. Without this, two admins who
  -- demote one another at the same moment each see the other still present,
  -- both commit, and the system is left with no admin at all — the exact
  -- outcome this trigger exists to prevent. A transaction-scoped advisory
  -- lock is the cheapest way to make the check-then-write atomic; it is held
  -- until commit, so the count below sees the other transaction's result.
  perform pg_advisory_xact_lock(hashtext('fsl.profiles.last_admin'));

  select count(*) into v_remaining
    from public.profiles
   where role = 'admin'
     and id <> old.id;

  if v_remaining = 0 then
    raise exception 'Cannot demote the last remaining admin.'
      using errcode = '42501';
  end if;

  return new;
end $$;

drop trigger if exists profiles_guard_insert on public.profiles;
create trigger profiles_guard_insert
  before insert on public.profiles
  for each row
  execute function public.guard_profile_insert();

drop trigger if exists profiles_guard_update on public.profiles;
create trigger profiles_guard_update
  before update on public.profiles
  for each row
  execute function public.guard_profile_update();

drop trigger if exists profiles_last_admin_guard on public.profiles;
create trigger profiles_last_admin_guard
  before update on public.profiles
  for each row
  execute function public.prevent_last_admin_demotion();


-- ============================================================
-- 5. Curriculum cascade
--
-- The admin delete confirmation promises "all of its modules, lessons and
-- signs are removed", which only holds if the foreign keys cascade. Adding
-- them is best-effort: if the existing data has orphans the constraint cannot
-- be validated, and failing the whole migration over that would be worse than
-- reporting it. Nothing in the app depends on the cascade existing.
--
-- `user_sign_progress` is deliberately left without a foreign key: cascading
-- learner progress away when a sign is deleted would destroy real history, and
-- deactivating the sign is the intended softer alternative.
-- ============================================================

do $$
begin
  if not exists (
    select 1
      from pg_constraint
     where conrelid = 'public.lesson_modules'::regclass
       and contype = 'f'
       and conkey = array[
         (select attnum from pg_attribute
           where attrelid = 'public.lesson_modules'::regclass
             and attname = 'level_id')
       ]::smallint[]
  ) then
    begin
      alter table public.lesson_modules
        add constraint lesson_modules_level_id_fkey
        foreign key (level_id) references public.lesson_levels (id)
        on delete cascade;
    exception when others then
      raise notice 'Skipped lesson_modules.level_id cascade: %', sqlerrm;
    end;
  end if;

  if not exists (
    select 1
      from pg_constraint
     where conrelid = 'public.lessons'::regclass
       and contype = 'f'
       and conkey = array[
         (select attnum from pg_attribute
           where attrelid = 'public.lessons'::regclass
             and attname = 'module_id')
       ]::smallint[]
  ) then
    begin
      alter table public.lessons
        add constraint lessons_module_id_fkey
        foreign key (module_id) references public.lesson_modules (id)
        on delete cascade;
    exception when others then
      raise notice 'Skipped lessons.module_id cascade: %', sqlerrm;
    end;
  end if;

  if not exists (
    select 1
      from pg_constraint
     where conrelid = 'public.lesson_signs'::regclass
       and contype = 'f'
       and conkey = array[
         (select attnum from pg_attribute
           where attrelid = 'public.lesson_signs'::regclass
             and attname = 'lesson_id')
       ]::smallint[]
  ) then
    begin
      alter table public.lesson_signs
        add constraint lesson_signs_lesson_id_fkey
        foreign key (lesson_id) references public.lessons (id)
        on delete cascade;
    exception when others then
      raise notice 'Skipped lesson_signs.lesson_id cascade: %', sqlerrm;
    end;
  end if;
end $$;


-- ============================================================
-- 6. Denormalised counts
--
-- `lesson_modules.total_lessons` and `lessons.total_signs` are caches the app
-- only reads for display, so the app does not let an admin type them — it
-- would immediately be wrong. They are maintained here instead.
--
-- `total_signs` counts *active* signs only, matching what a learner can
-- actually see (`LessonService.getLessonSigns` filters `is_active`), so a
-- lesson can never display "3 of 5" for content that no longer exists.
--
-- These are row-level triggers rather than statement-level ones with transition
-- tables: Postgres only allows a transition relation when the trigger has a
-- single event, and a "row was inserted" trigger has to work for inserts,
-- updates and deletes alike. The cost is one extra UPDATE per changed sign,
-- which is nothing at the volumes involved (a lesson's signs, not the whole
-- curriculum). The `update of` lists keep a plain `sort_order` reorder — the
-- most common write in the admin UI — from recomputing anything.
-- ============================================================

-- Recomputes one lesson's cache. Split out from the trigger function because a
-- trigger function cannot take arguments.
--
-- The `fsl.internal_write` flag is checked by audit_curriculum_change(). A
-- client cannot set it — PostgREST exposes no way to run arbitrary SQL — so it
-- only ever distinguishes "a human edited curriculum" from "the database is
-- keeping its own counters honest". Without it, adding one sign would log a
-- spurious `module.update` for every parent whose count moved.
create or replace function public.recompute_lesson_total_signs(p_lesson_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform set_config('fsl.internal_write', '1', true);

  update public.lessons l
     set total_signs = (
       select count(*)::int
         from public.lesson_signs ls
        where ls.lesson_id = l.id
          and ls.is_active
     )
   where l.id = p_lesson_id;

  perform set_config('fsl.internal_write', '0', true);
end $$;

create or replace function public.recompute_module_total_lessons(p_module_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform set_config('fsl.internal_write', '1', true);

  update public.lesson_modules m
     set total_lessons = (
       select count(*)::int
         from public.lessons l
        where l.module_id = m.id
     )
   where m.id = p_module_id;

  perform set_config('fsl.internal_write', '0', true);
end $$;

create or replace function public.refresh_lesson_total_signs()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if tg_op = 'DELETE' then
    perform public.recompute_lesson_total_signs(old.lesson_id);
    return null;
  end if;

  -- A sign moved to another lesson leaves the old lesson's count too high.
  if tg_op = 'UPDATE' and old.lesson_id is distinct from new.lesson_id then
    perform public.recompute_lesson_total_signs(old.lesson_id);
  end if;

  perform public.recompute_lesson_total_signs(new.lesson_id);
  return null;
end $$;

create or replace function public.refresh_module_total_lessons()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if tg_op = 'DELETE' then
    perform public.recompute_module_total_lessons(old.module_id);
    return null;
  end if;

  if tg_op = 'UPDATE' and old.module_id is distinct from new.module_id then
    perform public.recompute_module_total_lessons(old.module_id);
  end if;

  perform public.recompute_module_total_lessons(new.module_id);
  return null;
end $$;

drop trigger if exists lesson_signs_refresh_total on public.lesson_signs;
create trigger lesson_signs_refresh_total
  after insert or delete or update of is_active, lesson_id on public.lesson_signs
  for each row
  execute function public.refresh_lesson_total_signs();

drop trigger if exists lessons_refresh_total on public.lessons;
create trigger lessons_refresh_total
  after insert or delete or update of module_id on public.lessons
  for each row
  execute function public.refresh_module_total_lessons();

-- Backfill whatever the seed scripts wrote by hand. Done before the audit
-- triggers exist so the repair does not fill the moderation log with noise.
update public.lessons l
   set total_signs = (
     select count(*)::int
       from public.lesson_signs ls
      where ls.lesson_id = l.id
        and ls.is_active
   );

update public.lesson_modules m
   set total_lessons = (
     select count(*)::int
       from public.lessons l
      where l.module_id = m.id
   );


-- ============================================================
-- 7. Moderation log
--
-- `id` is a uuid rather than a bigserial because AuditLogModel reads it as a
-- String, and a JSON number would not survive that cast.
-- ============================================================

create table if not exists public.admin_audit_log (
  id uuid primary key default gen_random_uuid(),
  actor_id uuid references auth.users (id) on delete set null,
  actor_name text not null default 'Unknown',
  actor_email text not null default '',
  action text not null,
  target_table text not null,
  target_id text,
  target_label text,
  details jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists admin_audit_log_created_at_idx
  on public.admin_audit_log (created_at desc);

create index if not exists admin_audit_log_actor_idx
  on public.admin_audit_log (actor_id);

-- Shared writer for both audit triggers. SECURITY DEFINER because the
-- inserters below run for clients who have no insert policy at all.
create or replace function public.write_audit_log(
  p_action text,
  p_target_table text,
  p_target_id text default null,
  p_target_label text default null,
  p_details jsonb default '{}'::jsonb
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.admin_audit_log (
    actor_id,
    actor_name,
    actor_email,
    action,
    target_table,
    target_id,
    target_label,
    details
  )
  values (
    public.current_actor_id(),
    coalesce(public.current_actor_name(), 'system'),
    coalesce(public.current_actor_email(), ''),
    p_action,
    p_target_table,
    p_target_id,
    p_target_label,
    coalesce(p_details, '{}'::jsonb)
  );
end $$;

-- Every curriculum write, whatever issued it. `action` reads as
-- `<entity>.<operation>`, e.g. `sign.update`.
create or replace function public.audit_curriculum_change()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_entity text;
  v_operation text;
  v_row jsonb;
  v_details jsonb;
begin
  -- A count refresh triggered by someone else's edit, not a separate action.
  if coalesce(current_setting('fsl.internal_write', true), '0') = '1' then
    return null;
  end if;

  v_entity := case tg_table_name
    when 'lesson_levels' then 'level'
    when 'lesson_modules' then 'module'
    when 'lessons' then 'lesson'
    when 'lesson_signs' then 'sign'
    else tg_table_name
  end;

  v_operation := case tg_op
    when 'INSERT' then 'create'
    when 'UPDATE' then 'update'
    when 'DELETE' then 'delete'
  end;

  v_row := case when tg_op = 'DELETE' then to_jsonb(old) else to_jsonb(new) end;

  if tg_op = 'UPDATE' then
    -- Record only what actually changed, so the log stays readable when an
    -- admin saves a form that rewrites unchanged fields.
    select coalesce(jsonb_object_agg(e.key, jsonb_build_object(
             'old', e.old_value, 'new', e.new_value
           )), '{}'::jsonb)
      into v_details
      from (
        select n.key, n.new_value, o.old_value
          from jsonb_each(v_row) as n(key, new_value)
          join jsonb_each(to_jsonb(old)) as o(key, old_value)
            on o.key = n.key
         where n.new_value is distinct from o.old_value
           and n.key not in ('updated_at', 'created_at')
      ) as e;

    v_details := jsonb_build_object('changes', v_details);
  else
    v_details := jsonb_build_object('row', v_row);
  end if;

  perform public.write_audit_log(
    v_entity || '.' || v_operation,
    tg_table_name,
    v_row ->> 'id',
    coalesce(v_row ->> 'title', v_row ->> 'name', v_row ->> 'full_name'),
    v_details
  );

  return null;
end $$;

-- Role changes get their own action names because "who gained or lost admin"
-- is the question the moderation log exists to answer.
create or replace function public.audit_profile_role_change()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.role is not distinct from old.role then
    return null;
  end if;

  perform public.write_audit_log(
    case when new.role = 'admin' then 'role.grant' else 'role.revoke' end,
    'profiles',
    new.id::text,
    new.full_name,
    jsonb_build_object(
      'target_email', new.email,
      'previous_role', old.role,
      'new_role', new.role
    )
  );

  return null;
end $$;

-- Audit goes in before the counts are refreshed so the log shows the write
-- even if a count refresh ever fails.
drop trigger if exists lesson_levels_audit on public.lesson_levels;
create trigger lesson_levels_audit
  after insert or update or delete on public.lesson_levels
  for each row
  execute function public.audit_curriculum_change();

drop trigger if exists lesson_modules_audit on public.lesson_modules;
create trigger lesson_modules_audit
  after insert or update or delete on public.lesson_modules
  for each row
  execute function public.audit_curriculum_change();

drop trigger if exists lessons_audit on public.lessons;
create trigger lessons_audit
  after insert or update or delete on public.lessons
  for each row
  execute function public.audit_curriculum_change();

drop trigger if exists lesson_signs_audit on public.lesson_signs;
create trigger lesson_signs_audit
  after insert or update or delete on public.lesson_signs
  for each row
  execute function public.audit_curriculum_change();

drop trigger if exists profiles_role_audit on public.profiles;
create trigger profiles_role_audit
  after update on public.profiles
  for each row
  execute function public.audit_profile_role_change();


-- ============================================================
-- 8. Sign-up
--
-- Creates the profiles row for accounts that never had one (notably the Google
-- and Facebook OAuth paths, which never run AuthService.signUp). Any trigger
-- that already does this is removed first, so two of them cannot race to
-- insert the same row.
-- ============================================================

do $$
declare
  r record;
begin
  for r in
    select t.tgname
      from pg_trigger t
      join pg_proc p on p.oid = t.tgfoid
     where t.tgrelid = 'auth.users'::regclass
       and not t.tgisinternal
       and t.tgname <> 'on_auth_user_created'
       and (
         pg_get_functiondef(p.oid) ilike '%insert into public.profiles%'
         or pg_get_functiondef(p.oid) ilike '%insert into profiles%'
       )
  loop
    execute format('drop trigger %I on auth.users', r.tgname);
    raise notice 'Dropped earlier profile-creation trigger %.', r.tgname;
  end loop;
end $$;

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_email text := lower(btrim(coalesce(new.email, '')));
  v_name text := nullif(btrim(coalesce(
    new.raw_user_meta_data ->> 'full_name',
    new.raw_user_meta_data ->> 'name',
    ''
  )), '');
begin
  begin
    insert into public.profiles (id, full_name, email, role)
    values (
      new.id,
      coalesce(v_name, 'User'),
      v_email,
      public.resolve_role_for_email(v_email)
    )
    on conflict (id) do nothing;
  exception when others then
    -- A profile is not worth failing a sign-up over. getProfile() already
    -- falls back to the auth metadata when the row is missing, and the next
    -- sign-in or admin role change can reconcile it.
    raise notice 'Could not create a profile for %: %', new.id, sqlerrm;
  end;

  return new;
end $$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row
  execute function public.handle_new_user();


-- ============================================================
-- 9. Row level security
-- ============================================================

-- ---- clearing whatever was there before ------------------------
--
-- Postgres ORs permissive policies together, so *adding* a restrictive one
-- changes nothing if an older "Allow all for authenticated" policy is still
-- present. Every policy this section relies on therefore starts by dropping the
-- ones it replaces. Without this the lock-down below would silently be a no-op
-- on a project whose tables were set up by hand in the dashboard — which is how
-- this project's schema was created.
--
-- The curriculum tables only lose their write policies (see the note further
-- down). `profiles` and `user_sign_progress` are swept completely, because
-- both are meant to be private to their owner: a leftover policy there would
-- expose every learner's profile and practice history to every account, and
-- the delete case has neither a policy nor a trigger to stop it.
do $$
declare
  p record;
begin
  for p in
    select tablename, policyname, cmd
      from pg_policies
     where schemaname = 'public'
       and (
         -- Write policies only: their read access is preserved on purpose.
         (tablename in ('lesson_levels', 'lesson_modules', 'lessons', 'lesson_signs')
          and cmd in ('ALL', 'INSERT', 'UPDATE', 'DELETE'))
         -- Everything: these tables are owner-private.
         or tablename in ('profiles', 'user_sign_progress')
       )
  loop
    execute format('drop policy %I on public.%I', p.policyname, p.tablename);
    raise notice 'Dropped policy %.% (%)', p.tablename, p.policyname, p.cmd;
  end loop;
end $$;

-- ---- profiles -------------------------------------------------------------

alter table public.profiles enable row level security;

-- Own row, or every row when admin. The app only ever reads its own profile
-- outside the admin area, so this is not a behaviour change for learners.
drop policy if exists profiles_select_self_or_admin on public.profiles;
create policy profiles_select_self_or_admin
  on public.profiles
  for select
  to authenticated
  using (auth.uid() = id or public.is_admin());

-- Sign-up creates exactly this one row. guard_profile_insert() is the second
-- half of the check; this is the first.
drop policy if exists profiles_insert_own on public.profiles;
create policy profiles_insert_own
  on public.profiles
  for insert
  to authenticated
  with check (auth.uid() = id);

drop policy if exists profiles_update_self_or_admin on public.profiles;
create policy profiles_update_self_or_admin
  on public.profiles
  for update
  to authenticated
  using (auth.uid() = id or public.is_admin())
  with check (auth.uid() = id or public.is_admin());

-- No delete policy: an account is removed through Supabase Auth, not from the
-- app.

-- ---- curriculum -----------------------------------------------------------

-- Reads stay open to any caller that already has the table grant, exactly as
-- they were before RLS was switched on. Declared explicitly so that enabling
-- RLS cannot quietly lock the learner-facing catalogue out.
do $$
declare
  t text;
begin
  foreach t in array array['lesson_levels', 'lesson_modules', 'lessons', 'lesson_signs']::text[]
  loop
    execute format('alter table public.%I enable row level security', t);

    execute format('drop policy if exists curriculum_read on public.%I', t);
    execute format(
      'create policy curriculum_read on public.%I for select using (true)', t
    );

    execute format('drop policy if exists curriculum_write_admin on public.%I', t);
    execute format(
      'create policy curriculum_write_admin on public.%I for insert to authenticated with check (public.is_admin())',
      t
    );

    execute format('drop policy if exists curriculum_update_admin on public.%I', t);
    execute format(
      'create policy curriculum_update_admin on public.%I for update to authenticated using (public.is_admin()) with check (public.is_admin())',
      t
    );

    execute format('drop policy if exists curriculum_delete_admin on public.%I', t);
    execute format(
      'create policy curriculum_delete_admin on public.%I for delete to authenticated using (public.is_admin())',
      t
    );
  end loop;
end $$;

-- ---- user_sign_progress ---------------------------------------------------

-- Enabled here because the policies below assume it is. The app only ever
-- touches its own rows, and AdminService._rollupProgress reads other people's
-- rows through the admin branch, so the three policies cover every query the
-- codebase makes.
alter table public.user_sign_progress enable row level security;

drop policy if exists progress_read_self_or_admin on public.user_sign_progress;
create policy progress_read_self_or_admin
  on public.user_sign_progress
  for select
  to authenticated
  using (auth.uid() = user_id or public.is_admin());

drop policy if exists progress_insert_own on public.user_sign_progress;
create policy progress_insert_own
  on public.user_sign_progress
  for insert
  to authenticated
  with check (auth.uid() = user_id);

drop policy if exists progress_update_own on public.user_sign_progress;
create policy progress_update_own
  on public.user_sign_progress
  for update
  to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- Admins read learner progress to build the roster and the analytics. They
-- deliberately get no write policy: an admin must not be able to mark a sign
-- mastered on a learner's behalf.

-- ---- moderation log -------------------------------------------------------

alter table public.admin_audit_log enable row level security;

drop policy if exists admin_audit_log_read_admin on public.admin_audit_log;
create policy admin_audit_log_read_admin
  on public.admin_audit_log
  for select
  to authenticated
  using (public.is_admin());

-- No insert/update/delete policy: the log is written only by the triggers
-- above, which run as the table owner and so bypass RLS.

grant select on public.admin_audit_log to authenticated, service_role;


-- ============================================================
-- 10. Analytics functions
--
-- These exist as functions rather than plain selects because "distinct
-- learners who practised" and "distinct signs completed" are aggregates that
-- PostgREST cannot express as a filter, and because SECURITY DEFINER lets
-- them read every table regardless of the caller's own RLS.
--
-- AdminService reports a missing function (PostgREST code PGRST202) as an
-- explicit "apply supabase/admin_roles_and_rls.sql" message rather than
-- rendering a dashboard full of zeros.
-- ============================================================

create or replace function public.admin_system_stats()
returns table (
  total_users bigint,
  admin_users bigint,
  learner_users bigint,
  active_learners bigint,
  inactive_learners bigint,
  total_signs bigint,
  signs_practised bigint,
  total_levels bigint,
  total_modules bigint,
  total_lessons bigint,
  total_sign_rows bigint
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if not public.is_admin() then
    raise exception 'Admin role required.'
      using errcode = '42501';
  end if;

  return query
  select
    (select count(*) from public.profiles),
    (select count(*) from public.profiles where role = 'admin'),
    (select count(*) from public.profiles where role = 'learner'),
    (select count(*)
       from public.profiles p
      where p.role = 'learner'
        and exists (select 1 from public.user_sign_progress u where u.user_id = p.id)),
    (select count(*)
       from public.profiles p
      where p.role = 'learner'
        and not exists (select 1 from public.user_sign_progress u where u.user_id = p.id)),
    (select count(*) from public.lesson_signs where is_active),
    (select count(distinct sign_id) from public.user_sign_progress where completed),
    (select count(*) from public.lesson_levels),
    (select count(*) from public.lesson_modules),
    (select count(*) from public.lessons),
    (select count(*) from public.lesson_signs);
end $$;

create or replace function public.admin_top_signs(row_limit integer default 5)
returns table (
  sign_id uuid,
  title text,
  ai_label text,
  learner_count bigint,
  practice_count bigint,
  completed_count bigint
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if not public.is_admin() then
    raise exception 'Admin role required.'
      using errcode = '42501';
  end if;

  return query
  select
    s.id,
    s.title,
    s.ai_label,
    count(distinct u.user_id),
    coalesce(sum(u.practice_count), 0),
    count(*) filter (where u.completed)
  from public.lesson_signs s
  join public.user_sign_progress u on u.sign_id = s.id
  group by s.id, s.title, s.ai_label
  order by coalesce(sum(u.practice_count), 0) desc, s.title
  limit greatest(1, least(coalesce(row_limit, 5), 50));
end $$;

revoke all on function public.admin_system_stats() from public, anon;
revoke all on function public.admin_top_signs(integer) from public, anon;
grant execute on function public.admin_system_stats() to authenticated, service_role;
grant execute on function public.admin_top_signs(integer) to authenticated, service_role;

-- The audit writer is only ever reached from the triggers above, which run as
-- the owner. Leaving it executable by clients would let anyone forge entries.
revoke all on function public.write_audit_log(
  text, text, text, text, jsonb
) from public, anon, authenticated;
revoke all on function public.resolve_role_for_email(text) from public, anon;
revoke all on function public.is_allowlisted_admin(text) from public, anon;
revoke all on function public.recompute_lesson_total_signs(uuid)
  from public, anon, authenticated;
revoke all on function public.recompute_module_total_lessons(uuid)
  from public, anon, authenticated;
