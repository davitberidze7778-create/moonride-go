BEGIN;

-- Harden GO RPCs: all referenced objects are explicitly schema-qualified.
ALTER FUNCTION public.go_create_ride_quote(uuid, jsonb)
  SET search_path = '';
ALTER FUNCTION public.go_calculate_ride_quote(uuid, numeric)
  SET search_path = '';
ALTER FUNCTION public.go_calculate_tariff_options(uuid, numeric, numeric, numeric)
  SET search_path = '';
ALTER FUNCTION public.go_is_feature_enabled(text)
  SET search_path = '';
ALTER FUNCTION public.is_master_admin()
  SET search_path = '';

-- Trigger helpers are not client-callable RPC endpoints.
ALTER FUNCTION public.go_prevent_snapshot_mutation()
  SET search_path = '';
REVOKE EXECUTE ON FUNCTION public.go_prevent_snapshot_mutation()
  FROM PUBLIC, anon, authenticated;

REVOKE EXECUTE ON FUNCTION public.rls_auto_enable()
  FROM PUBLIC, anon, authenticated;

-- Keep the RLS helper available to authenticated policy evaluation,
-- but do not expose it to unauthenticated callers.
REVOKE EXECUTE ON FUNCTION public.is_master_admin()
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.is_master_admin()
  TO authenticated, service_role;

-- Attempt to remove client write rights from the PostGIS reference table.
-- This table is owned by supabase_admin; post-migration verification showed
-- its owner-managed grants remain unchanged. Do not treat this as resolved.
REVOKE INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER
  ON TABLE public.spatial_ref_sys
  FROM anon, authenticated;

COMMIT;
