-- Category selection is now handled by the authenticated quote-route Edge Function.
-- The direct SECURITY DEFINER RPC is retained for migration history but no longer exposed.
REVOKE ALL ON FUNCTION public.go_select_ride_quote_category(uuid,text) FROM PUBLIC,anon,authenticated;