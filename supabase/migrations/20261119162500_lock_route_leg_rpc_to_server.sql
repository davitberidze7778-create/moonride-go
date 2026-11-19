-- Keep client-supplied route leg distances out of public passenger RPC access.
-- A server-side TomTom route verifier will be the only caller.
REVOKE ALL ON FUNCTION public.go_save_ride_route_legs(uuid,jsonb) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.go_save_ride_route_legs(uuid,jsonb) TO service_role;