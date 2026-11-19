-- Publish only passenger-visible GO settings and tariff rows to Supabase Realtime.
-- RLS remains enabled and controls which authenticated users can receive each row.
DO $realtime$
DECLARE
  v_table text;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_publication WHERE pubname='supabase_realtime') THEN
    RAISE EXCEPTION 'Supabase Realtime publication is not available';
  END IF;
  FOREACH v_table IN ARRAY ARRAY[
    'go_app_feature_flags',
    'go_tariff_plans',
    'go_tariff_category_rates',
    'go_tariff_waiting_rules',
    'go_tariff_dynamic_rules',
    'vehicle_categories'
  ] LOOP
    IF NOT EXISTS (
      SELECT 1 FROM pg_publication_tables
      WHERE pubname='supabase_realtime'
        AND schemaname='public'
        AND tablename=v_table
    ) THEN
      EXECUTE format('ALTER PUBLICATION supabase_realtime ADD TABLE public.%I',v_table);
    END IF;
  END LOOP;
END;
$realtime$;
