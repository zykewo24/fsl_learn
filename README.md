# fsl_learn

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Admin area

The app has a role-based admin area (Settings → Admin) covering system
analytics, learner management, curriculum authoring and a moderation log.
Access is stored in `profiles.role` (`learner` / `admin`) and enforced in two
places: a route guard plus hidden controls in the app, and Postgres RLS
policies in the database. The database is the real boundary — a tampered build
of the app still cannot write curriculum or promote itself.

### One-time database setup

There is no committed schema; all SQL is applied by hand.

1. Run [`supabase/admin_roles_and_rls.sql`](supabase/admin_roles_and_rls.sql)
   in the Supabase Dashboard → SQL Editor. It adds `profiles.role`, the RLS
   policies, the `admin_audit_log` table and its triggers, the two analytics
   RPCs, and the triggers that maintain the denormalised lesson/sign counts.
   It is re-runnable.
2. Run [`supabase/promote_first_admin.sql`](supabase/promote_first_admin.sql),
   editing the single email list at the top. This is the only way to create the
   first admin — by design, since granting a role requires already having one.
   Re-run it to add more admins later.
3. Sign out and back in. The role is read at cold start, so the Admin entry
   point only appears on a fresh launch.

#### If the SQL Editor times out

`Connection terminated due to connection timeout` on step 1 means the request
died in transit, not that the database is slow — the migration's heaviest
statement is a backfill over the `lessons` table. The SQL Editor sends the whole
editor buffer as one request, so a long script is the thing to change.

Split it into its numbered sections and run one at a time:

```powershell
.\scripts\split_admin_sql.ps1
```

This writes `supabase/.chunks/01_*.sql` … `10_*.sql` (gitignored, regenerated
from the migration on every run). Paste them into the SQL Editor in numeric
order — they are not independent, since later sections call `is_admin()` and the
audit triggers from earlier ones — but each is individually re-runnable, so a
run that fails partway is safe to repeat.

To find out how far a timed-out run actually got, run
[`supabase/verify_admin_setup.sql`](supabase/verify_admin_setup.sql) first. It
is read-only and lists every object the migration creates, so you can see which
sections landed before deciding what to re-run.

### Creating an admin during local development

`--dart-define=ADMIN_EMAILS` lets a sign-up start as an admin without editing
SQL every time:

```powershell
$env:ADMIN_EMAILS = 'you@example.com'
.\scripts\build_and_install.ps1
```

The flag is a development convenience, not a security boundary — the list is
compiled into the binary. The database ignores whatever role the app requests
and recomputes it from `public.admin_email_allowlist`, so an address has to be
allowlisted there (by `promote_first_admin.sql` or the SQL Editor) *and* be
built into the app. Leave `ADMIN_EMAILS` unset for release builds.

### Layout

| Path | Contents |
| --- | --- |
| `lib/app/session_role.dart` | Synchronous role cache read by the router guard |
| `lib/app/router.dart` | `redirect` guard on `/admin` |
| `lib/features/admin/models/` | `UserRole`, stats, roster, audit, popularity, drafts |
| `lib/features/admin/services/admin_service.dart` | All admin data access |
| `lib/features/admin/providers/` | Riverpod providers for each tab |
| `lib/features/admin/presentation/` | Dashboard and the four tabs |
| `lib/features/admin/widgets/` | Badges, stat tiles, editor sheet, pickers |
| `supabase/admin_roles_and_rls.sql` | Roles, RLS, audit log, analytics RPCs |
| `supabase/promote_first_admin.sql` | Admin bootstrap |
