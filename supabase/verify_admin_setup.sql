-- Read-only diagnostic for the admin/RLS migration.
--
-- Run this BEFORE re-running admin_roles_and_rls.sql. It only reads system
-- catalogs (plus one count over profiles), so it is fast and cannot make things
-- worse if the previous run died partway through.
--
-- Every object admin_roles_and_rls.sql creates is listed. Anything showing
-- exists = false is missing; anything showing exists = true already applied.
-- The script is re-runnable, so a partial result is safe to finish.

-- ---- 1. Which objects exist? ---------------------------------------------
-- `exists` is ordered ascending so the MISSING objects print first: those are
-- the ones a re-run has to create. Read the list bottom-up to find the last
-- section that landed.
with expected(name) as (
  values
    ('table:admin_email_allowlist'),
    ('table:admin_audit_log'),
    ('function:is_admin'),
    ('function:is_allowlisted_admin'),
    ('function:resolve_role_for_email'),
    ('function:current_actor_id'),
    ('function:current_actor_email'),
    ('function:current_actor_name'),
    ('function:guard_profile_insert'),
    ('function:guard_profile_update'),
    ('function:prevent_last_admin_demotion'),
    ('function:recompute_lesson_total_signs'),
    ('function:recompute_module_total_lessons'),
    ('function:refresh_lesson_total_signs'),
    ('function:refresh_module_total_lessons'),
    ('function:write_audit_log'),
    ('function:audit_curriculum_change'),
    ('function:audit_profile_role_change'),
    ('function:handle_new_user'),
    ('function:admin_system_stats'),
    ('function:admin_top_signs'),
    ('trigger:profiles_guard_insert'),
    ('trigger:profiles_guard_update'),
    ('trigger:profiles_last_admin_guard'),
    ('trigger:lesson_signs_refresh_total'),
    ('trigger:lessons_refresh_total'),
    ('trigger:lesson_levels_audit'),
    ('trigger:lesson_modules_audit'),
    ('trigger:lessons_audit'),
    ('trigger:lesson_signs_audit'),
    ('trigger:profiles_role_audit'),
    ('trigger:on_auth_user_created')
),
found as (
  select 'table:' || c.relname as name
    from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
   where n.nspname = 'public'
     and c.relkind in ('r', 'p')

  union

  select 'function:' || p.proname
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public'

  union

  select 'trigger:' || t.tgname
    from pg_trigger t
    join pg_class c on c.oid = t.tgrelid
    join pg_namespace n on n.oid = c.relnamespace
   where n.nspname = 'public'
     and not t.tgisinternal
)
select e.name as object,
       (f.name is not null) as "exists"
  from expected e
  left join found f on f.name = e.name
 order by "exists", e.name;


-- ---- 2. RLS and policies per table ---------------------------------------
-- Expect rls_enabled = true on all seven tables. For profiles and
-- user_sign_progress the policies should be the self/admin ones; for the four
-- curriculum tables, curriculum_read + the three *_admin write policies.
select c.relname as table,
       c.relrowsecurity as rls_enabled,
       coalesce(string_agg(p.polname, ', ' order by p.polname), '(none)') as policies
  from pg_class c
  join pg_namespace n on n.oid = c.relnamespace
  left join pg_policy p on p.polrelid = c.oid
 where n.nspname = 'public'
   and c.relkind = 'r'
   and c.relname in ('profiles', 'user_sign_progress', 'lesson_levels',
                     'lesson_modules', 'lessons', 'lesson_signs',
                     'admin_audit_log')
 group by c.relname, c.relrowsecurity
 order by c.relname;


-- ---- 3. The role column ---------------------------------------------------
-- Catalog-only on purpose: the fourth column would need the role column to
-- exist, and this script has to survive a database that never got section 1.
select
  (select count(*)
     from information_schema.columns
    where table_schema = 'public'
      and table_name = 'profiles'
      and column_name = 'role') > 0
    as profiles_has_role,
  (select count(*) from public.profiles) as total_profiles;


-- ---- 4. Role values (only if query 3 says profiles_has_role = true) --------
select role, count(*)
  from public.profiles
 group by role
 order by role;


-- ---- 5. Allowlist contents (only if query 1 shows the table) --------------
-- Must match your --dart-define=ADMIN_EMAILS build value. An address has to be
-- in both this table and the build-time list to become an admin at sign-up.
select email, note, created_at
  from public.admin_email_allowlist
 order by email;
