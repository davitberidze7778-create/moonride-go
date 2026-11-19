-- Cache JWT context once per statement in RLS policies.
-- This preserves the same access conditions while avoiding per-row auth function calls.

ALTER POLICY profiles_select_own_or_admin ON public.profiles
  USING ((id = (SELECT auth.uid()) OR (SELECT public.is_master_admin())));
ALTER POLICY profiles_update_own_or_admin ON public.profiles
  USING ((id = (SELECT auth.uid()) OR (SELECT public.is_master_admin())))
  WITH CHECK ((id = (SELECT auth.uid()) OR (SELECT public.is_master_admin())));

ALTER POLICY driver_profiles_insert_own ON public.driver_profiles
  WITH CHECK (user_id = (SELECT auth.uid()));
ALTER POLICY driver_profiles_select_own_or_admin ON public.driver_profiles
  USING ((user_id = (SELECT auth.uid()) OR (SELECT public.is_master_admin())));
ALTER POLICY driver_profiles_update_own_or_admin ON public.driver_profiles
  USING ((user_id = (SELECT auth.uid()) OR (SELECT public.is_master_admin())))
  WITH CHECK ((user_id = (SELECT auth.uid()) OR (SELECT public.is_master_admin())));

ALTER POLICY vehicles_insert_own ON public.vehicles
  WITH CHECK (owner_user_id = (SELECT auth.uid()));
ALTER POLICY vehicles_select_own_or_admin ON public.vehicles
  USING ((owner_user_id = (SELECT auth.uid()) OR (SELECT public.is_master_admin())));
ALTER POLICY vehicles_update_own_or_admin ON public.vehicles
  USING ((owner_user_id = (SELECT auth.uid()) OR (SELECT public.is_master_admin())))
  WITH CHECK ((owner_user_id = (SELECT auth.uid()) OR (SELECT public.is_master_admin())));

ALTER POLICY vehicle_photos_insert_owner ON public.vehicle_photos
  WITH CHECK (
    uploaded_by = (SELECT auth.uid())
    AND EXISTS (
      SELECT 1 FROM public.vehicles v
      WHERE v.id = vehicle_photos.vehicle_id
        AND v.owner_user_id = (SELECT auth.uid())
    )
  );
ALTER POLICY vehicle_photos_read_owner_admin ON public.vehicle_photos
  USING (
    EXISTS (
      SELECT 1 FROM public.vehicles v
      WHERE v.id = vehicle_photos.vehicle_id
        AND v.owner_user_id = (SELECT auth.uid())
    )
    OR (SELECT public.is_master_admin())
  );

ALTER POLICY ai_inspections_read_owner_admin ON public.vehicle_ai_inspections
  USING (
    EXISTS (
      SELECT 1 FROM public.vehicles v
      WHERE v.id = vehicle_ai_inspections.vehicle_id
        AND v.owner_user_id = (SELECT auth.uid())
    )
    OR (SELECT public.is_master_admin())
  );

ALTER POLICY passenger_read_own_quotes ON public.ride_quotes
  USING (passenger_id = (SELECT auth.uid()));

ALTER POLICY passenger_read_own_route_points ON public.ride_route_points
  USING (
    EXISTS (
      SELECT 1 FROM public.ride_quotes q
      WHERE q.id = ride_route_points.quote_id
        AND q.passenger_id = (SELECT auth.uid())
    )
  );

ALTER POLICY passenger_read_own_route_legs ON public.ride_route_legs
  USING (
    EXISTS (
      SELECT 1 FROM public.ride_quotes q
      WHERE q.id = ride_route_legs.quote_id
        AND q.passenger_id = (SELECT auth.uid())
    )
  );

ALTER POLICY passenger_read_own_quote_items ON public.ride_quote_items
  USING (
    EXISTS (
      SELECT 1 FROM public.ride_quotes q
      WHERE q.id = ride_quote_items.quote_id
        AND q.passenger_id = (SELECT auth.uid())
    )
  );

ALTER POLICY go_snapshots_owner_read ON public.go_quote_tariff_snapshots
  USING (
    EXISTS (
      SELECT 1 FROM public.ride_quotes q
      WHERE q.id = go_quote_tariff_snapshots.quote_id
        AND q.passenger_id = (SELECT auth.uid())
    )
  );
