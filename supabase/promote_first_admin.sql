-- ============================================================
-- PROMOTE THE FIRST ADMIN(S)
--
-- Run this in Supabase Dashboard -> SQL Editor AFTER
-- supabase/admin_roles_and_rls.sql.
--
-- There is no way to become the first admin from inside the app: the admin
-- area is gated on already holding the role, and the database refuses role
-- changes from anyone who does not hold it. So the first admin has to be
-- created here, from a session that already has authority (the SQL Editor runs
-- as `postgres`).
--
-- HOW TO USE
--   1. Edit the single email list below.
--   2. Sign up in the app with that address (either before or after this run —
--      both work; see step 1 inside the block).
--   3. Run this file and read the notices.
--   4. Sign out and back in. The role is read at cold start, so the admin
--      entry point in Settings only appears on a fresh launch.
--
-- Re-running it is safe. It is also the intended way to add a second admin
-- later, and the way to recover from locking yourself out — the database's
-- "do not demote the last admin" rule deliberately lets this script through,
-- because an operator needs an escape hatch.
-- ============================================================

do $$
declare
  -- >>> EDIT THIS LIST <<<
  -- One quoted, lower-case address per entry. Remove the comma on the last
  -- line when you delete the example.
  v_emails text[] := array[
    'you@example.com'
  ];

  v_email text;
  v_admins integer;
begin
  foreach v_email in array v_emails loop
    v_email := lower(btrim(v_email));

    if v_email = '' then
      continue;
    end if;

    if position('@' in v_email) <= 1 then
      raise notice 'Skipped "%": that is not a valid email address.', v_email;
      continue;
    end if;

    -- 1. Remember the address so a sign-up with it starts as an admin too.
    --    admin_email_allowlist has no RLS policies at all, which is what makes
    --    that table safe: only the SQL Editor and the service role can touch
    --    it, so a client cannot add itself. Doing this before the account
    --    exists is fine — the sign-up trigger reads the same list.
    begin
      insert into public.admin_email_allowlist (email, note)
      values (v_email, 'Promoted by promote_first_admin.sql')
      on conflict (email) do nothing;
    exception when others then
      raise notice 'Could not allowlist "%": %', v_email, sqlerrm;
      continue;
    end;

    -- 2. Promote the profile, if the account has already signed up.
    update public.profiles
       set role = 'admin'
     where lower(btrim(email)) = v_email
       and role is distinct from 'admin';

    select count(*) into v_admins
      from public.profiles
     where lower(btrim(email)) = v_email
       and role = 'admin';

    if v_admins > 0 then
      raise notice '%: promoted to admin.', v_email;
    else
      raise notice '%: allowlisted, but no profiles row yet — sign up with this address and it will start as an admin.', v_email;
    end if;
  end loop;
end $$;


-- Verification. Re-run just this query any time to see who currently holds the
-- admin role, and whether anyone is allowlisted without an account yet.
select
  a.email as allowlisted,
  p.id is not null as has_account,
  p.role as role_now,
  p.full_name
from public.admin_email_allowlist a
left join public.profiles p
  on lower(btrim(p.email)) = a.email
order by a.email;


-- Everything currently holding the admin role, however it was granted.
select id, full_name, email, role, created_at
from public.profiles
where role = 'admin'
order by created_at;
