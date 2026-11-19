-- Performance hardening based on Supabase Database Advisor audit (2026-11-20).
-- Add covering indexes for foreign keys that were reported without one.
-- No rows, tariffs, or business rules are modified.

CREATE INDEX IF NOT EXISTS idx_city_vehicle_rates_category_id
  ON public.city_vehicle_rates(category_id);

CREATE INDEX IF NOT EXISTS idx_driver_documents_reviewed_by
  ON public.driver_documents(reviewed_by);
CREATE INDEX IF NOT EXISTS idx_driver_documents_supersedes_document_id
  ON public.driver_documents(supersedes_document_id);

CREATE INDEX IF NOT EXISTS idx_go_app_feature_flags_updated_by
  ON public.go_app_feature_flags(updated_by);
CREATE INDEX IF NOT EXISTS idx_go_tariff_category_rates_category_id
  ON public.go_tariff_category_rates(category_id);

CREATE INDEX IF NOT EXISTS idx_ride_quote_items_category_id
  ON public.ride_quote_items(category_id);
CREATE INDEX IF NOT EXISTS idx_ride_quotes_fare_rule_id
  ON public.ride_quotes(fare_rule_id);
CREATE INDEX IF NOT EXISTS idx_ride_quotes_selected_category_id
  ON public.ride_quotes(selected_category_id);

CREATE INDEX IF NOT EXISTS idx_ride_route_legs_quote_start_point
  ON public.ride_route_legs(quote_id, start_point_id);
CREATE INDEX IF NOT EXISTS idx_ride_route_legs_quote_end_point
  ON public.ride_route_legs(quote_id, end_point_id);
CREATE INDEX IF NOT EXISTS idx_ride_route_legs_start_point_id
  ON public.ride_route_legs(start_point_id);
CREATE INDEX IF NOT EXISTS idx_ride_route_legs_end_point_id
  ON public.ride_route_legs(end_point_id);

CREATE INDEX IF NOT EXISTS idx_vehicle_ai_inspections_assigned_category_id
  ON public.vehicle_ai_inspections(assigned_category_id);
CREATE INDEX IF NOT EXISTS idx_vehicle_ai_inspections_recommended_category_id
  ON public.vehicle_ai_inspections(recommended_category_id);

CREATE INDEX IF NOT EXISTS idx_vehicle_category_history_changed_by
  ON public.vehicle_category_history(changed_by);
CREATE INDEX IF NOT EXISTS idx_vehicle_category_history_new_category_id
  ON public.vehicle_category_history(new_category_id);
CREATE INDEX IF NOT EXISTS idx_vehicle_category_history_old_category_id
  ON public.vehicle_category_history(old_category_id);

CREATE INDEX IF NOT EXISTS idx_vehicle_category_rates_category_id
  ON public.vehicle_category_rates(category_id);
CREATE INDEX IF NOT EXISTS idx_vehicle_photos_uploaded_by
  ON public.vehicle_photos(uploaded_by);
