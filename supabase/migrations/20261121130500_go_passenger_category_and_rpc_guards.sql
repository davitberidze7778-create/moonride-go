CREATE OR REPLACE FUNCTION public.go_calculate_tariff_options(p_tariff_plan_id uuid, p_distance_km numeric, p_movement_minutes numeric, p_waiting_minutes numeric DEFAULT 0)
 RETURNS TABLE(category_code text, rate_per_km numeric, base_fare numeric, distance_fare numeric, time_fare numeric, waiting_fare numeric, dynamic_multiplier numeric, total_fare numeric, currency_code text)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
    v_plan public.go_tariff_plans%ROWTYPE;

    v_rate record;

    v_lower_minutes numeric;
    v_lower_fee numeric;
    v_upper_minutes numeric;
    v_upper_fee numeric;

    v_waiting_fare numeric := 0;
    v_dynamic_multiplier numeric := 1.0;
    v_raw_multiplier numeric := 1.0;

    v_base numeric;
    v_distance_fare numeric;
    v_time_fare numeric;
    v_total numeric;

    v_dynamic public.go_tariff_dynamic_rules%ROWTYPE;
BEGIN

    -- 1. INPUT VALIDATION

    IF p_tariff_plan_id IS NULL THEN
        RAISE EXCEPTION 'Tariff plan ID is required.';
    END IF;

    IF p_distance_km IS NULL OR p_distance_km < 0 THEN
        RAISE EXCEPTION 'Distance must be zero or greater.';
    END IF;

    IF p_movement_minutes IS NULL OR p_movement_minutes < 0 THEN
        RAISE EXCEPTION 'Movement time must be zero or greater.';
    END IF;

    IF p_waiting_minutes IS NULL OR p_waiting_minutes < 0 THEN
        RAISE EXCEPTION 'Waiting time must be zero or greater.';
    END IF;


    -- 2. LOAD ACTIVE TARIFF PLAN

    SELECT *
    INTO v_plan
    FROM public.go_tariff_plans
    WHERE id = p_tariff_plan_id
      AND is_active = true
      AND effective_from <= now()
      AND (
          effective_until IS NULL
          OR effective_until > now()
      );

    IF NOT FOUND THEN
        RAISE EXCEPTION
            'Tariff plan does not exist, is inactive, or is outside its effective dates.';
    END IF;


    -- 3. LOAD DYNAMIC PRICING CONFIGURATION
    -- Dynamic pricing remains 1.0 unless safely configured.

    SELECT *
    INTO v_dynamic
    FROM public.go_tariff_dynamic_rules
    WHERE tariff_plan_id = p_tariff_plan_id
      AND is_active = true
      AND public.go_is_feature_enabled('pricing.dynamic');

    IF FOUND THEN

        -- Manual override takes precedence.
        IF public.go_is_feature_enabled('pricing.manual')
           AND v_dynamic.manual_override_multiplier IS NOT NULL
           AND (
               v_dynamic.manual_override_until IS NULL
               OR v_dynamic.manual_override_until > now()
           )
        THEN
            v_raw_multiplier :=
                v_dynamic.manual_override_multiplier;

        ELSE

            v_raw_multiplier := 1.0;

            IF v_dynamic.weather_enabled
               AND public.go_is_feature_enabled('pricing.weather') THEN
                v_raw_multiplier :=
                    v_raw_multiplier
                    * v_dynamic.weather_multiplier;
            END IF;

            IF v_dynamic.demand_enabled
               AND public.go_is_feature_enabled('pricing.demand') THEN
                v_raw_multiplier :=
                    v_raw_multiplier
                    * v_dynamic.demand_multiplier;
            END IF;

        END IF;

        -- Safety: dynamic pricing is not applied
        -- until an administrator sets a maximum multiplier.
        IF v_dynamic.max_multiplier IS NOT NULL THEN
            v_dynamic_multiplier :=
                LEAST(
                    v_raw_multiplier,
                    v_dynamic.max_multiplier
                );
        ELSE
            v_dynamic_multiplier := 1.0;
        END IF;

    END IF;


    -- 4. CALCULATE WAITING FEE
    -- Uses linear interpolation between configured points.
    -- Above the last point, the last configured fee is retained.

    IF p_waiting_minutes <= v_plan.free_wait_minutes THEN

        v_waiting_fare := 0;

    ELSE

        SELECT
            wait_minutes,
            fee_amount
        INTO
            v_lower_minutes,
            v_lower_fee
        FROM public.go_tariff_waiting_rules
        WHERE tariff_plan_id = p_tariff_plan_id
          AND wait_minutes <= p_waiting_minutes
        ORDER BY wait_minutes DESC
        LIMIT 1;

        SELECT
            wait_minutes,
            fee_amount
        INTO
            v_upper_minutes,
            v_upper_fee
        FROM public.go_tariff_waiting_rules
        WHERE tariff_plan_id = p_tariff_plan_id
          AND wait_minutes > p_waiting_minutes
        ORDER BY wait_minutes ASC
        LIMIT 1;

        IF v_lower_minutes IS NULL THEN

            v_waiting_fare := 0;

        ELSIF v_upper_minutes IS NULL THEN

            v_waiting_fare := v_lower_fee;

        ELSE

            v_waiting_fare :=
                v_lower_fee
                +
                (
                    (p_waiting_minutes - v_lower_minutes)
                    /
                    NULLIF(
                        v_upper_minutes - v_lower_minutes,
                        0
                    )
                )
                *
                (v_upper_fee - v_lower_fee);

        END IF;

    END IF;


    -- 5. CALCULATE EACH ACTIVE VEHICLE CATEGORY

    FOR v_rate IN

        SELECT
            vc.code,
            tr.rate_per_km
        FROM public.go_tariff_category_rates tr
        JOIN public.vehicle_categories vc
          ON vc.id = tr.category_id
        WHERE tr.tariff_plan_id = p_tariff_plan_id
          AND vc.is_active = true
          AND vc.code IN (
              'ECONOM_GO','ECONOM_PLUS_GO','COMFORT_GO','COMFORT_PLUS_GO',
              'XL_GO','PREMIUM_GO'
          )
        ORDER BY vc.code

    LOOP

        -- Minimum fare
        v_base := v_plan.minimum_fare;

        -- Distance after included distance
        v_distance_fare :=
            v_rate.rate_per_km
            *
            GREATEST(
                0,
                p_distance_km - v_plan.included_distance_km
            );

        -- Actual movement time after included time
        v_time_fare :=
            v_plan.extra_movement_minute_rate
            *
            GREATEST(
                0,
                p_movement_minutes
                - v_plan.included_movement_minutes
            );

        -- Total before dynamic pricing
        v_total :=
            v_base
            + v_distance_fare
            + v_time_fare
            + v_waiting_fare;

        -- Apply dynamic multiplier and round to 2 decimals
        v_total :=
            ROUND(
                v_total * v_dynamic_multiplier,
                2
            );

        RETURN QUERY
        SELECT
            v_rate.code::text,
            v_rate.rate_per_km::numeric,
            ROUND(v_base, 2),
            ROUND(v_distance_fare, 2),
            ROUND(v_time_fare, 2),
            ROUND(v_waiting_fare, 2),
            v_dynamic_multiplier,
            v_total,
            v_plan.currency_code::text;

    END LOOP;


    -- 6. ENSURE AT LEAST ONE CATEGORY WAS FOUND

    IF NOT FOUND THEN
        RAISE EXCEPTION
            'No active vehicle categories or tariff rates found for this plan.';
    END IF;

END;
$function$


CREATE OR REPLACE FUNCTION public.go_calculate_ride_quote(p_quote_id uuid, p_wait_minutes numeric DEFAULT 0)
 RETURNS TABLE(category_code text, rate_per_km numeric, base_fare numeric, distance_fare numeric, time_fare numeric, waiting_fare numeric, total_fare numeric, currency_code text)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
    v_quote public.ride_quotes%ROWTYPE;
    v_plan public.go_tariff_plans%ROWTYPE;
    v_option record;
    v_point_count integer;
    v_leg_count integer;
    v_rate_count integer;
    v_distance numeric;
    v_minutes numeric;
    v_wait numeric;
    v_applied_multiplier numeric := 1.0;
    v_weather_multiplier numeric := 1.0;
    v_demand_multiplier numeric := 1.0;
    v_category_prices jsonb := '{}'::jsonb;
    v_item_count integer := 0;
    v_category_id uuid;
BEGIN
    IF p_quote_id IS NULL THEN
        RAISE EXCEPTION 'Quote ID is required';
    END IF;

    IF p_wait_minutes IS NULL OR p_wait_minutes < 0 THEN
        RAISE EXCEPTION 'Waiting minutes must be non-negative';
    END IF;

    SELECT *
    INTO v_quote
    FROM public.ride_quotes q
    WHERE q.id = p_quote_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Quote not found';
    END IF;

    IF auth.uid() IS DISTINCT FROM v_quote.passenger_id
       AND coalesce(auth.role(), '') <> 'service_role' THEN
        RAISE EXCEPTION 'Not authorized to calculate this quote';
    END IF;

    IF NOT public.go_is_feature_enabled('ride.quote') THEN
        RAISE EXCEPTION 'MOONRIDE GO quote pricing is currently disabled by MASTER ADMIN';
    END IF;

    -- GO კალკულატორი მხოლოდ GO შეკვეთას ამუშავებს.
    IF v_quote.quote_source IS DISTINCT FROM 'GO' THEN
        RAISE EXCEPTION
            'This quote is not a GO quote';
    END IF;

    -- თუ Snapshot უკვე არსებობს, ძველი ფასი ბრუნდება.
    IF EXISTS (
        SELECT 1
        FROM public.go_quote_tariff_snapshots s
        WHERE s.quote_id = p_quote_id
    ) THEN
        RETURN QUERY
        SELECT
            i.category_code,
            i.rate_per_km,
            i.base_fare,
            i.distance_fare,
            i.time_fare,
            i.waiting_fare,
            i.total_fare,
            i.currency_code
        FROM public.ride_quote_items i
        WHERE i.quote_id = p_quote_id
        ORDER BY i.category_code;

        RETURN;
    END IF;

    IF v_quote.status <> 'pending' THEN
        RAISE EXCEPTION
            'Only pending quotes without a snapshot can be priced';
    END IF;

    IF v_quote.expires_at IS NOT NULL AND v_quote.expires_at <= now() THEN
        RAISE EXCEPTION 'This GO fare quote has expired. Please request a new quote.';
    END IF;

    v_wait := p_wait_minutes;

    SELECT *
    INTO v_plan
    FROM public.go_tariff_plans p
    WHERE p.city_id = v_quote.city_id
      AND p.scope_type = 'city'
      AND p.is_active = true
      AND p.effective_from <= now()
      AND (p.effective_until IS NULL OR p.effective_until > now());

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Active GO tariff plan not found';
    END IF;

    SELECT count(*)
    INTO v_point_count
    FROM public.ride_route_points rp
    WHERE rp.quote_id = p_quote_id;

    SELECT count(*)
    INTO v_leg_count
    FROM public.ride_route_legs rl
    WHERE rl.quote_id = p_quote_id;

    IF v_point_count < 2 OR v_leg_count <> v_point_count - 1 THEN
        RAISE EXCEPTION
            'Route is incomplete: expected one leg between each pair of points';
    END IF;

    -- თითოეული მონაკვეთი უნდა აკავშირებდეს მომდევნო ორ წერტილს.
    IF EXISTS (
        SELECT 1
        FROM public.ride_route_legs l
        LEFT JOIN public.ride_route_points s
          ON s.quote_id = l.quote_id
         AND s.sequence_number = l.sequence_number
        LEFT JOIN public.ride_route_points e
          ON e.quote_id = l.quote_id
         AND e.sequence_number = l.sequence_number + 1
        WHERE l.quote_id = p_quote_id
          AND (
              s.id IS NULL
              OR e.id IS NULL
              OR l.start_point_id <> s.id
              OR l.end_point_id <> e.id
          )
    ) THEN
        RAISE EXCEPTION 'Route leg point sequence is inconsistent';
    END IF;

    SELECT
        sum(l.distance_km),
        sum(l.duration_minutes)
    INTO v_distance, v_minutes
    FROM public.ride_route_legs l
    WHERE l.quote_id = p_quote_id;

    IF v_distance IS NULL OR v_minutes IS NULL THEN
        RAISE EXCEPTION 'Route distance or duration is missing';
    END IF;

    IF v_distance < 0 OR v_minutes < 0 THEN
        RAISE EXCEPTION 'Invalid route distance or duration';
    END IF;

    -- მინიმუმ ერთი აქტიური GO კატეგორიის ტარიფი აუცილებელია.
    SELECT count(DISTINCT c.id)
    INTO v_rate_count
    FROM public.go_tariff_category_rates r
    JOIN public.vehicle_categories c
      ON c.id = r.category_id
    WHERE r.tariff_plan_id = v_plan.id
      AND c.code IN (
          'ECONOM_GO',
          'ECONOM_PLUS_GO',
          'COMFORT_GO',
          'COMFORT_PLUS_GO',
          'XL_GO',
          'PREMIUM_GO'
      );

    IF v_rate_count < 1 THEN
        RAISE EXCEPTION
            'GO tariff plan must have at least one active approved category rate; found %',
            v_rate_count;
    END IF;

    -- დინამიკური წესების ფაქტორები Snapshot-ისთვის.
    SELECT
        CASE WHEN d.weather_enabled
             THEN greatest(1.0, coalesce(d.weather_multiplier, 1.0))
             ELSE 1.0 END,
        CASE WHEN d.demand_enabled
             THEN greatest(1.0, coalesce(d.demand_multiplier, 1.0))
             ELSE 1.0 END
    INTO v_weather_multiplier, v_demand_multiplier
    FROM public.go_tariff_dynamic_rules d
    WHERE d.tariff_plan_id = v_plan.id
      AND d.is_active = true
    LIMIT 1;

    v_weather_multiplier := coalesce(v_weather_multiplier, 1.0);
    v_demand_multiplier := coalesce(v_demand_multiplier, 1.0);

    -- GO კალკულატორი; ძველი ტარიფები არ გამოიყენება.
    FOR v_option IN
        SELECT *
        FROM public.go_calculate_tariff_options(
            v_plan.id,
            v_distance,
            v_minutes,
            v_wait
        ) AS o
        WHERE o.category_code IN (
          'ECONOM_GO',
          'ECONOM_PLUS_GO',
          'COMFORT_GO',
          'COMFORT_PLUS_GO',
          'XL_GO',
          'PREMIUM_GO'
      )
    LOOP
        SELECT c.id
        INTO v_category_id
        FROM public.vehicle_categories c
        WHERE c.code = v_option.category_code;

        IF v_category_id IS NULL THEN
            RAISE EXCEPTION
                'Vehicle category not found: %',
                v_option.category_code;
        END IF;

        INSERT INTO public.ride_quote_items (
            quote_id,
            category_id,
            category_code,
            rate_per_km,
            base_fare,
            distance_fare,
            time_fare,
            waiting_fare,
            total_fare,
            currency_code
        )
        VALUES (
            p_quote_id,
            v_category_id,
            v_option.category_code,
            v_option.rate_per_km,
            v_option.base_fare,
            v_option.distance_fare,
            v_option.time_fare,
            v_option.waiting_fare,
            v_option.total_fare,
            v_option.currency_code
        )
        ON CONFLICT (quote_id, category_id)
        DO UPDATE SET
            rate_per_km = EXCLUDED.rate_per_km,
            base_fare = EXCLUDED.base_fare,
            distance_fare = EXCLUDED.distance_fare,
            time_fare = EXCLUDED.time_fare,
            waiting_fare = EXCLUDED.waiting_fare,
            total_fare = EXCLUDED.total_fare,
            currency_code = EXCLUDED.currency_code;

        v_category_prices :=
            v_category_prices ||
            jsonb_build_object(
                v_option.category_code,
                jsonb_build_object(
                    'rate_per_km', v_option.rate_per_km,
                    'base_fare', v_option.base_fare,
                    'distance_fare', v_option.distance_fare,
                    'time_fare', v_option.time_fare,
                    'waiting_fare', v_option.waiting_fare,
                    'total_fare', v_option.total_fare,
                    'currency_code', v_option.currency_code
                )
            );

        v_applied_multiplier :=
            greatest(v_applied_multiplier, v_option.dynamic_multiplier);

        v_item_count := v_item_count + 1;
    END LOOP;

    IF v_item_count < 1 THEN
        RAISE EXCEPTION
            'Expected at least one GO category price, calculated %',
            v_item_count;
    END IF;

    -- ფასის პირობების უცვლელი Snapshot.
    INSERT INTO public.go_quote_tariff_snapshots (
        quote_id,
        tariff_plan_id,
        tariff_version,
        currency_code,
        minimum_fare,
        included_distance_km,
        included_movement_minutes,
        extra_movement_minute_rate,
        distance_km,
        movement_minutes,
        waiting_minutes,
        weather_multiplier,
        demand_multiplier,
        applied_multiplier,
        category_prices,
        calculation_details
    )
    VALUES (
        p_quote_id,
        v_plan.id,
        v_plan.rule_version,
        v_plan.currency_code,
        v_plan.minimum_fare,
        v_plan.included_distance_km,
        v_plan.included_movement_minutes,
        v_plan.extra_movement_minute_rate,
        v_distance,
        v_minutes,
        v_wait,
        v_weather_multiplier,
        v_demand_multiplier,
        greatest(1.0, v_applied_multiplier),
        v_category_prices,
        jsonb_build_object(
            'calculator', 'go_calculate_tariff_options',
            'tariff_plan_name', v_plan.plan_name,
            'tariff_scope', v_plan.scope_type,
            'waiting_fee_mode', v_plan.waiting_fee_mode,
            'free_wait_minutes', v_plan.free_wait_minutes,
            'calculated_at', now(),
            'dynamic_multiplier_is_combined',
                greatest(1.0, v_applied_multiplier)
        )
    );

    UPDATE public.ride_quotes
    SET
        total_distance_km = v_distance,
        total_duration_minutes = v_minutes,
        waiting_minutes = v_wait,
        currency_code = v_plan.currency_code,
        status = 'priced',
        updated_at = now()
    WHERE id = p_quote_id;

    RETURN QUERY
    SELECT
        i.category_code,
        i.rate_per_km,
        i.base_fare,
        i.distance_fare,
        i.time_fare,
        i.waiting_fare,
        i.total_fare,
        i.currency_code
    FROM public.ride_quote_items i
    WHERE i.quote_id = p_quote_id
    ORDER BY i.category_code;

END;
$function$


CREATE OR REPLACE FUNCTION public.go_create_ride_quote(p_city_id uuid, p_points jsonb)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
    v_user_id uuid;
    v_quote_id uuid;
    v_plan_id uuid;
    v_currency text;
    v_count integer;
    v_i integer := 0;
    v_point jsonb;
    v_point_type text;
BEGIN
    v_user_id := auth.uid();

    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM public.profiles p
        WHERE p.id = v_user_id
          AND p.role = 'passenger'
          AND p.account_status = 'active'
    ) THEN
        RAISE EXCEPTION 'Active passenger account required' USING ERRCODE='42501';
    END IF;
    IF NOT public.go_is_feature_enabled('ride.quote') THEN
        RAISE EXCEPTION 'MOONRIDE GO quote service is currently disabled by MASTER ADMIN';
    END IF;

    IF p_points IS NULL
       OR jsonb_typeof(p_points) <> 'array' THEN
        RAISE EXCEPTION 'Route points must be a JSON array';
    END IF;

    v_count := jsonb_array_length(p_points);
    IF v_count > 2 AND NOT public.go_is_feature_enabled('ride.multiple_stops') THEN
        RAISE EXCEPTION 'Multiple stops are currently disabled by MASTER ADMIN';
    END IF;

    IF v_count < 2 OR v_count > 25 THEN
        RAISE EXCEPTION 'Route must contain 2 to 25 points';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM public.cities c
        WHERE c.id = p_city_id
          AND c.is_active = true
          AND c.service_enabled = true
    ) THEN
        RAISE EXCEPTION 'City is inactive or service is unavailable';
    END IF;

    -- მხოლოდ ერთი აქტიური, მოქმედი ქალაქის GO გეგმა.
    SELECT count(*)
    INTO v_i
    FROM public.go_tariff_plans p
    WHERE p.city_id = p_city_id
      AND p.scope_type = 'city'
      AND p.is_active = true
      AND p.effective_from <= now()
      AND (p.effective_until IS NULL OR p.effective_until > now());

    IF v_i <> 1 THEN
        RAISE EXCEPTION
            'Expected exactly one active GO city tariff plan; found %',
            v_i;
    END IF;

    SELECT p.id, p.currency_code
    INTO v_plan_id, v_currency
    FROM public.go_tariff_plans p
    WHERE p.city_id = p_city_id
      AND p.scope_type = 'city'
      AND p.is_active = true
      AND p.effective_from <= now()
      AND (p.effective_until IS NULL OR p.effective_until > now());

    IF v_currency IS NULL THEN
        RAISE EXCEPTION 'GO tariff plan has no currency';
    END IF;

    v_i := 0;

    -- წერტილების ფორმატისა და თანმიმდევრობის შემოწმება.
    FOR v_point IN
        SELECT value
        FROM jsonb_array_elements(p_points)
    LOOP
        v_i := v_i + 1;

        IF jsonb_typeof(v_point) <> 'object' THEN
            RAISE EXCEPTION 'Each route point must be an object';
        END IF;

        IF EXISTS (
            SELECT 1
            FROM jsonb_object_keys(v_point) AS k(key)
            WHERE k.key NOT IN (
                'point_type',
                'latitude',
                'longitude',
                'address'
            )
        ) THEN
            RAISE EXCEPTION 'Unknown route point field';
        END IF;

        IF jsonb_typeof(v_point->'point_type')
             IS DISTINCT FROM 'string'
           OR jsonb_typeof(v_point->'latitude')
             IS DISTINCT FROM 'number'
           OR jsonb_typeof(v_point->'longitude')
             IS DISTINCT FROM 'number' THEN
            RAISE EXCEPTION 'Invalid route point fields';
        END IF;

        v_point_type := v_point->>'point_type';

        IF v_i = 1 AND v_point_type <> 'pickup' THEN
            RAISE EXCEPTION 'First point must be pickup';
        ELSIF v_i = v_count AND v_point_type <> 'dropoff' THEN
            RAISE EXCEPTION 'Last point must be dropoff';
        ELSIF v_i > 1 AND v_i < v_count
              AND v_point_type <> 'stop' THEN
            RAISE EXCEPTION 'Intermediate points must be stops';
        END IF;

        IF (v_point->>'latitude')::numeric NOT BETWEEN -90 AND 90
           OR (v_point->>'longitude')::numeric NOT BETWEEN -180 AND 180 THEN
            RAISE EXCEPTION 'Invalid geographic coordinates';
        END IF;

        IF v_point ? 'address'
           AND v_point->'address' <> 'null'::jsonb
           AND jsonb_typeof(v_point->'address') <> 'string' THEN
            RAISE EXCEPTION 'Address must be text or null';
        END IF;

        IF length(v_point->>'address') > 500 THEN
            RAISE EXCEPTION 'Address is too long';
        END IF;
    END LOOP;

    INSERT INTO public.ride_quotes (
        passenger_id,
        city_id,
        currency_code,
        route_preference,
        status,
        expires_at,
        quote_source
    )
    VALUES (
        v_user_id,
        p_city_id,
        v_currency,
        'fastest',
        'pending',
        now() + interval '5 minutes',
        'GO'
    )
    RETURNING id INTO v_quote_id;

    v_i := 0;

    FOR v_point IN
        SELECT value
        FROM jsonb_array_elements(p_points)
    LOOP
        INSERT INTO public.ride_route_points (
            quote_id,
            point_type,
            sequence_number,
            latitude,
            longitude,
            address
        )
        VALUES (
            v_quote_id,
            v_point->>'point_type',
            v_i,
            (v_point->>'latitude')::numeric,
            (v_point->>'longitude')::numeric,
            v_point->>'address'
        );

        v_i := v_i + 1;
    END LOOP;

    RETURN v_quote_id;
END;
$function$


CREATE OR REPLACE FUNCTION public.go_create_ride_from_quote(p_quote_id uuid, p_category_code text, p_payment_method text DEFAULT 'cash'::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_quote public.ride_quotes%ROWTYPE;
  v_item record;
  v_ride_id uuid;
  v_offers int := 0;
  v_pickup text;
  v_dropoff text;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Authentication required' USING ERRCODE='42501';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.profiles p
    WHERE p.id = v_uid AND p.role = 'passenger' AND p.account_status = 'active'
  ) THEN
    RAISE EXCEPTION 'Active passenger account required' USING ERRCODE='42501';
  END IF;

  IF NOT public.go_is_feature_enabled('ride.booking_dispatch') THEN
    RAISE EXCEPTION 'Ride booking is currently disabled by MASTER ADMIN';
  END IF;

  IF p_payment_method IS DISTINCT FROM 'cash' THEN
    RAISE EXCEPTION 'Only cash payment is available until a payment provider is connected';
  END IF;

  IF NOT public.go_is_feature_enabled('payment.cash') THEN
    RAISE EXCEPTION 'Cash payment is currently disabled by MASTER ADMIN';
  END IF;

  SELECT * INTO v_quote
  FROM public.ride_quotes q
  WHERE q.id = p_quote_id
  FOR UPDATE;

  IF NOT FOUND OR v_quote.passenger_id IS DISTINCT FROM v_uid THEN
    RAISE EXCEPTION 'Quote not found' USING ERRCODE='42501';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.driver_live_locations ll
    JOIN public.driver_profiles dp ON dp.user_id = ll.driver_user_id
    JOIN public.profiles pr ON pr.id = dp.user_id AND pr.account_status = 'active'
    WHERE dp.approval_status = 'approved'
      AND dp.work_city_id = v_quote.city_id
      AND ll.is_online = true
      AND ll.location IS NOT NULL
      AND ll.updated_at >= now() - interval '90 seconds'
  ) THEN
    RAISE EXCEPTION 'No approved online drivers are currently available in this city';
  END IF;

  IF v_quote.quote_source IS DISTINCT FROM 'GO' OR v_quote.status <> 'priced' THEN
    RAISE EXCEPTION 'Only priced GO quotes can be booked';
  END IF;

  IF v_quote.expires_at IS NULL OR v_quote.expires_at <= now() THEN
    RAISE EXCEPTION 'Fare quote expired; calculate a new quote';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.go_quote_tariff_snapshots s
    WHERE s.quote_id = p_quote_id
  ) THEN
    RAISE EXCEPTION 'Immutable fare snapshot is required';
  END IF;

  SELECT i.category_id, i.category_code, i.total_fare, i.currency_code
  INTO v_item
  FROM public.ride_quote_items i
  JOIN public.vehicle_categories c
    ON c.id = i.category_id AND c.is_active = true
  WHERE i.quote_id = p_quote_id AND i.category_code = p_category_code;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Selected vehicle category is unavailable';
  END IF;

  SELECT rp.address INTO v_pickup
  FROM public.ride_route_points rp
  WHERE rp.quote_id = p_quote_id
  ORDER BY rp.sequence_number
  LIMIT 1;

  SELECT rp.address INTO v_dropoff
  FROM public.ride_route_points rp
  WHERE rp.quote_id = p_quote_id
  ORDER BY rp.sequence_number DESC
  LIMIT 1;

  UPDATE public.ride_quotes
  SET selected_category_id = v_item.category_id,
      selected_fare = v_item.total_fare,
      status = 'confirmed',
      updated_at = now()
  WHERE id = p_quote_id;

  INSERT INTO public.go_rides (
    quote_id, passenger_id, city_id, category_code,
    pickup_address, dropoff_address, fare_amount, currency_code,
    payment_method, payment_status, status
  )
  VALUES (
    p_quote_id, v_uid, v_quote.city_id, v_item.category_code,
    v_pickup, v_dropoff, v_item.total_fare, v_item.currency_code,
    'cash', 'cash_due', 'dispatching'
  )
  RETURNING id INTO v_ride_id;

  INSERT INTO public.go_ride_events (
    ride_id, actor_user_id, actor_role, event_type, new_status, note
  )
  VALUES (
    v_ride_id, v_uid, 'passenger', 'ride.requested', 'dispatching',
    'Passenger confirmed a priced GO quote'
  );

  INSERT INTO public.go_driver_offers (
    ride_id, driver_user_id, status, offered_at, expires_at
  )
  SELECT
    v_ride_id, dp.user_id, 'sent', now(), now() + interval '45 seconds'
  FROM public.driver_live_locations ll
  JOIN public.driver_profiles dp ON dp.user_id = ll.driver_user_id
  JOIN public.profiles pr
    ON pr.id = dp.user_id AND pr.account_status = 'active'
  WHERE dp.approval_status = 'approved'
    AND dp.work_city_id = v_quote.city_id
    AND ll.is_online
    AND ll.location IS NOT NULL
    AND ll.updated_at >= now() - interval '90 seconds'
  ORDER BY public.ST_Distance(
    ll.location,
    (
      SELECT public.ST_SetSRID(
        public.ST_MakePoint(rp.longitude::double precision, rp.latitude::double precision),
        4326
      )::public.geography
      FROM public.ride_route_points rp
      WHERE rp.quote_id = p_quote_id
      ORDER BY rp.sequence_number
      LIMIT 1
    )
  ) ASC
  LIMIT 10
  ON CONFLICT (ride_id, driver_user_id) DO NOTHING;

  GET DIAGNOSTICS v_offers = ROW_COUNT;

  RETURN jsonb_build_object(
    'ride_id', v_ride_id,
    'status', 'dispatching',
    'offers_sent', v_offers,
    'payment_method', 'cash'
  );
END;
$function$


CREATE OR REPLACE FUNCTION public.go_select_ride_quote_category(p_quote_id uuid, p_category_code text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
 v_user_id uuid := auth.uid();
 v_quote public.ride_quotes%ROWTYPE;
 v_item record;
BEGIN
 IF v_user_id IS NULL THEN
  RAISE EXCEPTION 'Authentication required' USING ERRCODE='42501';
 END IF;

 IF NOT EXISTS (
  SELECT 1 FROM public.profiles p
  WHERE p.id = v_user_id
    AND p.role = 'passenger'
    AND p.account_status = 'active'
 ) THEN
  RAISE EXCEPTION 'Active passenger account required' USING ERRCODE='42501';
 END IF;
 IF p_quote_id IS NULL OR NULLIF(btrim(p_category_code),'') IS NULL THEN
  RAISE EXCEPTION 'Quote and category are required';
 END IF;
 IF NOT public.go_is_feature_enabled('ride.quote') THEN
  RAISE EXCEPTION 'MOONRIDE GO quote service is currently disabled by MASTER ADMIN';
 END IF;

 SELECT * INTO v_quote
 FROM public.ride_quotes
 WHERE id=p_quote_id
 FOR UPDATE;

 IF NOT FOUND OR v_quote.passenger_id IS DISTINCT FROM v_user_id THEN
  RAISE EXCEPTION 'Not authorized for this quote' USING ERRCODE='42501';
 END IF;
 IF v_quote.quote_source IS DISTINCT FROM 'GO' OR v_quote.status<>'priced' THEN
  RAISE EXCEPTION 'Only priced GO quotes can select a category';
 END IF;
 IF v_quote.expires_at IS NOT NULL AND v_quote.expires_at<=now() THEN
  RAISE EXCEPTION 'This GO fare quote has expired. Please request a new quote.';
 END IF;

 SELECT i.category_id,i.category_code,i.total_fare,i.currency_code
 INTO v_item
 FROM public.ride_quote_items i
 JOIN public.vehicle_categories c ON c.id=i.category_id
 WHERE i.quote_id=p_quote_id
   AND i.category_code=p_category_code
   AND c.is_active=true;

 IF NOT FOUND THEN
  RAISE EXCEPTION 'This ride category is unavailable for this quote';
 END IF;

 UPDATE public.ride_quotes
 SET selected_category_id=v_item.category_id,
     selected_fare=v_item.total_fare,
     updated_at=now()
 WHERE id=p_quote_id;

 RETURN jsonb_build_object(
  'quote_id',p_quote_id,
  'category_code',v_item.category_code,
  'selected_fare',v_item.total_fare,
  'currency_code',v_item.currency_code,
  'expires_at',v_quote.expires_at
 );
END;
$function$

