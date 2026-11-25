# Recovery audit: `harden_trigger_function_execution`

**Audit date:** 2026-11-25  
**Supabase project:** `ewdkhekztkzugrmsknay`  
**GitHub repository:** `davitberidze7778-create/moonride-go`  
**Working branch:** `work/classic-blue-three-apps-2026-11-22`

## Status

The Supabase migration history contains version `20261119181535`, name `harden_trigger_function_execution`. The original SQL file was not found in the inspected GitHub branches or repository code search. Therefore the original source has **not** been recovered and this note must not be treated as a byte-for-byte copy.

The live database state does show restricted execution privileges for the three audited GO SECURITY DEFINER trigger functions. The evidence below narrows the likely purpose of the missing migration.

## Evidence from neighboring migrations

Two of the three audited functions were already restricted by earlier migration files that are present in GitHub:

- `20261119160000_go_admin_feature_controls.sql` contains `REVOKE ALL ON FUNCTION public.go_feature_flag_audit_trigger() FROM PUBLIC,anon,authenticated;` (line 55).
- `20261119173000_go_tariff_version_on_change.sql` contains `REVOKE ALL ON FUNCTION public.go_increment_tariff_plan_version() FROM PUBLIC,anon,authenticated;` (line 38).

Both corresponding migration versions appear in Supabase migration history under versions `20261119151820` and `20261119153719`, respectively. The filenames' timestamps differ from the recorded versions, but their intent and function names match.

The remaining audited GO SECURITY DEFINER trigger function is `public.go_tariff_write_audit()`. It is attached to active audit triggers on:
- `go_service_zones`
- `go_tariff_category_rates`
- `go_tariff_dynamic_rules`
- `go_tariff_plans`
- `go_tariff_waiting_rules`

The live database reports:
- owner: `postgres`
- SECURITY DEFINER: `true`
- `PUBLIC` EXECUTE: false
- `anon` EXECUTE: false
- `authenticated` EXECUTE: false
- `service_role` EXECUTE: true

This makes `go_tariff_write_audit()` the strongest candidate for the missing migration's additional target, but does not prove the exact original SQL or that it was the only statement in that migration.

## Reconstructed hypothesis — NOT ORIGINAL SOURCE

The following is a minimal candidate consistent with the live ACL for the remaining function. It is recorded for audit/recovery only and must **not** be run as a new migration without a separate schema review.

```sql
REVOKE ALL ON FUNCTION public.go_tariff_write_audit()
FROM PUBLIC, anon, authenticated;

GRANT EXECUTE ON FUNCTION public.go_tariff_write_audit()
TO service_role;
```

The current live database already has the intended effective permissions. Re-running this candidate is unnecessary and was not done.

## Other trigger functions reviewed

These legacy functions remain EXECUTE-accessible to PUBLIC/anon/authenticated, but they are not SECURITY DEFINER and return `trigger`; they are attached to table triggers rather than being ordinary RPC endpoints:

- `go_protect_profile_account_status()` → `profiles`
- `protect_driver_status()` → `driver_profiles`
- `protect_vehicle_status()` → `vehicles`
- `set_updated_at()` → `driver_profiles`, `profiles`, `vehicles`

No privilege changes were made to them. Their presence alone is not evidence of an exploitable direct RPC path, and changing them without a dedicated compatibility test could interfere with trigger operation.

PostGIS C trigger functions `checkauthtrigger()` and `postgis_cache_bbox()` were also found with public execute privileges but no attached user-table triggers in the inspected schema. They were not modified.

## Separate systemic observation

The database's default function ACL for functions created by `postgres` and `supabase_admin` includes EXECUTE for `anon` and `authenticated`. This is a broader default-privilege concern, separate from the missing migration. It was not changed because a blanket change could break intended application RPCs; it requires an inventory of public RPC contracts and a controlled test plan.

## Actions and non-actions

- Read-only Supabase inspection completed for function definitions, security-definer status, ACLs, attached triggers and default function ACLs.
- GitHub branches and migration files were inspected; the missing original source was not found.
- No Supabase SQL was executed that changes schema, data, permissions, or migration history.
- No migration was rerun.
- No production or preview branch was created.
- This report is an audit artifact only; it is outside `supabase/migrations` and cannot be picked up as a migration by the normal Supabase migration runner.

## Conclusion

The migration is recorded as applied in Supabase, and the live permissions of the audited GO trigger functions are in the hardened state. The strongest reconstruction is that the missing migration restricted `go_tariff_write_audit()`, since the other two audited GO trigger functions were already revoked by earlier tracked migrations. Exact source recovery remains unconfirmed; do not label this reconstructed hypothesis as the original migration.
