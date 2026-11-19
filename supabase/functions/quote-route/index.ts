import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2.57.0";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Content-Type": "application/json",
};

const respond = (status: number, body: Record<string, unknown>) =>
  new Response(JSON.stringify(body), { status, headers: corsHeaders });

type PointType = "pickup" | "stop" | "dropoff";

type RoutePoint = {
  point_type: PointType;
  latitude: number;
  longitude: number;
  address: string | null;
};

type RouteLeg = {
  distance_km: number;
  duration_minutes: number;
  route_geometry: {
    type: "LineString";
    coordinates: [number, number][];
  };
};

function validatePoints(input: unknown): RoutePoint[] {
  if (!Array.isArray(input) || input.length < 2 || input.length > 6) {
    throw new Error(
      "Route must contain pickup, destination and up to four stops.",
    );
  }

  return input.map((value, index, array) => {
    if (!value || typeof value !== "object" || Array.isArray(value)) {
      throw new Error("Each route point must be an object.");
    }

    const point = value as Record<string, unknown>;
    const expectedType: PointType = index === 0
      ? "pickup"
      : index === array.length - 1
      ? "dropoff"
      : "stop";

    if (point.point_type !== expectedType) {
      throw new Error("Invalid route point order.");
    }

    const latitude = point.latitude;
    const longitude = point.longitude;

    if (
      typeof latitude !== "number" || !Number.isFinite(latitude) ||
      latitude < -90 || latitude > 90 ||
      typeof longitude !== "number" || !Number.isFinite(longitude) ||
      longitude < -180 || longitude > 180
    ) {
      throw new Error("Invalid route coordinates.");
    }

    const address = point.address;
    if (
      address !== undefined && address !== null &&
      typeof address !== "string"
    ) {
      throw new Error("Route point address must be text or null.");
    }

    return {
      point_type: expectedType,
      latitude,
      longitude,
      address: typeof address === "string" ? address.trim().slice(0, 500) : null,
    };
  });
}

function orderedValues(value: unknown): unknown[] {
  if (Array.isArray(value)) return value;
  if (!value || typeof value !== "object") return [];

  const record = value as Record<string, unknown>;
  return Object.keys(record)
    .sort((left, right) => {
      const a = Number(left);
      const b = Number(right);
      if (Number.isFinite(a) && Number.isFinite(b)) return a - b;
      return left.localeCompare(right);
    })
    .map((key) => record[key]);
}

function parseLineString(value: unknown): [number, number][] {
  if (typeof value !== "string") return [];

  const match = value.match(/^\s*LINESTRING(?:\s+Z)?\s*\((.*)\)\s*$/i);
  if (!match) return [];

  const coordinates: [number, number][] = [];
  for (const coordinateText of match[1].split(",")) {
    const parts = coordinateText.trim().split(/\s+/).map(Number);
    if (
      parts.length < 2 ||
      !Number.isFinite(parts[0]) ||
      !Number.isFinite(parts[1]) ||
      parts[0] < -180 || parts[0] > 180 ||
      parts[1] < -90 || parts[1] > 90
    ) {
      continue;
    }

    coordinates.push([parts[0], parts[1]]);
  }

  return coordinates;
}

function extractRouteGeometry(route: Record<string, unknown>) {
  const coordinates: [number, number][] = [];

  const append = (line: unknown) => {
    for (const coordinate of parseLineString(line)) {
      const last = coordinates[coordinates.length - 1];
      if (
        !last ||
        Math.abs(last[0] - coordinate[0]) > 1e-8 ||
        Math.abs(last[1] - coordinate[1]) > 1e-8
      ) {
        coordinates.push(coordinate);
      }
    }
  };

  const beginPath = route.begin_pedestrian_path as
    | Record<string, unknown>
    | undefined;
  const beginGeometry = beginPath?.geometry as
    | Record<string, unknown>
    | undefined;
  append(beginGeometry?.selection);

  for (const maneuverValue of orderedValues(route.maneuvers)) {
    if (!maneuverValue || typeof maneuverValue !== "object") continue;

    const maneuver = maneuverValue as Record<string, unknown>;
    const outgoing = maneuver.outcoming_path as
      | Record<string, unknown>
      | undefined;
    const geometry = outgoing?.geometry;

    for (const segmentValue of orderedValues(geometry)) {
      if (!segmentValue || typeof segmentValue !== "object") continue;
      const segment = segmentValue as Record<string, unknown>;
      append(segment.selection);
    }
  }

  const endPath = route.end_pedestrian_path as
    | Record<string, unknown>
    | undefined;
  const endGeometry = endPath?.geometry as
    | Record<string, unknown>
    | undefined;
  append(endGeometry?.selection);

  if (coordinates.length < 2) {
    throw new Error("2GIS returned no usable route geometry.");
  }

  return { type: "LineString" as const, coordinates };
}

async function fetchTwoGisLeg(
  from: RoutePoint,
  to: RoutePoint,
  apiKey: string,
): Promise<RouteLeg> {
  const url = new URL(
    "https://routing.api.2gis.com/routing/7.0.0/global",
  );
  url.searchParams.set("key", apiKey);

  const response = await fetch(url, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      points: [
        {
          type: "stop",
          lon: from.longitude,
          lat: from.latitude,
        },
        {
          type: "stop",
          lon: to.longitude,
          lat: to.latitude,
        },
      ],
      transport: "driving",
      route_mode: "fastest",
      traffic_mode: "jam",
      locale: "en",
      alternative: 0,
    }),
    signal: AbortSignal.timeout(15_000),
  });

  if (!response.ok) {
    throw new Error(`2GIS Routing API returned HTTP ${response.status}.`);
  }

  const payload = await response.json();
  if (
    !payload || payload.status !== "OK" ||
    payload.type !== "result" || !Array.isArray(payload.result) ||
    payload.result.length === 0
  ) {
    const message = typeof payload?.message === "string"
      ? payload.message.slice(0, 240)
      : "No route was returned.";
    throw new Error(`2GIS route unavailable: ${message}`);
  }

  const route = payload.result[0] as Record<string, unknown>;
  const distanceMeters = route.total_distance;
  const durationSeconds = route.total_duration;

  if (
    typeof distanceMeters !== "number" ||
    !Number.isFinite(distanceMeters) || distanceMeters <= 0 ||
    typeof durationSeconds !== "number" ||
    !Number.isFinite(durationSeconds) || durationSeconds <= 0
  ) {
    throw new Error("2GIS returned invalid route distance or duration.");
  }

  return {
    distance_km: Number((distanceMeters / 1000).toFixed(3)),
    duration_minutes: Number((durationSeconds / 60).toFixed(2)),
    route_geometry: extractRouteGeometry(route),
  };
}

Deno.serve(async (request: Request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (request.method !== "POST") {
    return respond(405, { error: "Method not allowed." });
  }

  const authorization = request.headers.get("Authorization");
  if (!authorization?.startsWith("Bearer ")) {
    return respond(401, { error: "Authentication required." });
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

  if (!supabaseUrl || !anonKey || !serviceRoleKey) {
    return respond(503, { error: "Supabase server environment is incomplete." });
  }

  const userClient = createClient(supabaseUrl, anonKey, {
    auth: { persistSession: false, autoRefreshToken: false },
    global: { headers: { Authorization: authorization } },
  });
  const adminClient = createClient(supabaseUrl, serviceRoleKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  try {
    const token = authorization.slice("Bearer ".length);
    const { data: authData, error: authError } = await userClient.auth.getUser(
      token,
    );
    if (authError || !authData.user) {
      return respond(401, { error: "Session is invalid or expired." });
    }

    const userId = authData.user.id;
    const { data: profile, error: profileError } = await userClient
      .from("profiles")
      .select("role")
      .eq("id", userId)
      .maybeSingle();

    if (profileError || profile?.role !== "passenger") {
      return respond(403, { error: "Passenger account required." });
    }

    const body = await request.json();

    // Category selection uses the previously priced quote and does not call 2GIS.
    if (body?.action === "select_category") {
      const quoteId = typeof body.quoteId === "string" ? body.quoteId : "";
      const categoryCode = typeof body.categoryCode === "string"
        ? body.categoryCode
        : "";

      if (!quoteId || !categoryCode) {
        return respond(400, {
          error: "Quote ID and category are required.",
        });
      }

      const { data: quote, error: quoteError } = await adminClient
        .from("ride_quotes")
        .select("id,passenger_id,quote_source,status,expires_at")
        .eq("id", quoteId)
        .maybeSingle();

      if (
        quoteError || !quote || quote.passenger_id !== userId
      ) {
        return respond(404, { error: "Quote not found." });
      }
      if (quote.quote_source !== "GO" || quote.status !== "priced") {
        return respond(409, {
          error: "Quote is not ready for category selection.",
        });
      }
      if (
        quote.expires_at &&
        new Date(quote.expires_at).getTime() <= Date.now()
      ) {
        return respond(410, {
          error: "Fare quote expired. Calculate a new route.",
        });
      }

      const { data: item, error: itemError } = await adminClient
        .from("ride_quote_items")
        .select(
          "category_id,category_code,total_fare,currency_code,vehicle_categories!inner(is_active)",
        )
        .eq("quote_id", quoteId)
        .eq("category_code", categoryCode)
        .eq("vehicle_categories.is_active", true)
        .maybeSingle();

      if (itemError || !item) {
        return respond(409, {
          error: "This category is not available for the quote.",
        });
      }

      const { error: updateError } = await adminClient
        .from("ride_quotes")
        .update({
          selected_category_id: item.category_id,
          selected_fare: item.total_fare,
          updated_at: new Date().toISOString(),
        })
        .eq("id", quoteId)
        .eq("passenger_id", userId)
        .eq("status", "priced");

      if (updateError) {
        return respond(500, {
          error: "Could not save the selected category.",
        });
      }

      return respond(200, {
        quoteId,
        categoryCode: item.category_code,
        selectedFare: Number(item.total_fare),
        currencyCode: item.currency_code,
        expiresAt: quote.expires_at,
      });
    }

    const twoGisApiKey = Deno.env.get("DGIS_ROUTING_API_KEY");
    if (!twoGisApiKey) {
      return respond(503, {
        error:
          "2GIS Routing API key is not configured. Add DGIS_ROUTING_API_KEY to Supabase Edge Function secrets.",
      });
    }

    const cityId = typeof body?.cityId === "string" ? body.cityId : "";
    if (!cityId) {
      return respond(400, { error: "City ID is required." });
    }

    const points = validatePoints(body?.points);

    const { data: city, error: cityError } = await userClient
      .from("cities")
      .select("id,is_active,service_enabled")
      .eq("id", cityId)
      .maybeSingle();

    if (
      cityError || !city || !city.is_active || !city.service_enabled
    ) {
      return respond(409, { error: "GO service is not active in this city." });
    }

    // Build each segment through 2GIS so every stored DB leg has verified metrics.
    const segments: RouteLeg[] = [];
    for (let index = 0; index < points.length - 1; index++) {
      segments.push(
        await fetchTwoGisLeg(points[index], points[index + 1], twoGisApiKey),
      );
    }

    const { data: quoteId, error: createError } = await userClient.rpc(
      "go_create_ride_quote",
      { p_city_id: cityId, p_points: points },
    );

    if (createError || !quoteId) {
      return respond(409, {
        error: createError?.message || "Could not create GO quote.",
      });
    }

    const { data: storedPoints, error: storedError } = await adminClient
      .from("ride_route_points")
      .select("id,sequence_number")
      .eq("quote_id", quoteId)
      .order("sequence_number");

    if (
      storedError || !storedPoints ||
      storedPoints.length !== points.length ||
      storedPoints.some((point, index) => point.sequence_number !== index)
    ) {
      await adminClient.from("ride_quotes")
        .update({ status: "cancelled" })
        .eq("id", quoteId)
        .eq("passenger_id", userId);

      return respond(500, {
        error: "Could not verify saved route points.",
      });
    }

    const legRows = segments.map((segment, index) => ({
      quote_id: quoteId,
      start_point_id: storedPoints[index].id,
      end_point_id: storedPoints[index + 1].id,
      sequence_number: index,
      distance_km: segment.distance_km,
      duration_minutes: segment.duration_minutes,
      route_geometry: segment.route_geometry,
    }));

    const { error: legsError } = await adminClient
      .from("ride_route_legs")
      .insert(legRows);

    if (legsError) {
      await adminClient.from("ride_quotes")
        .update({ status: "cancelled" })
        .eq("id", quoteId)
        .eq("passenger_id", userId);

      return respond(500, {
        error: "Could not save verified 2GIS route segments.",
      });
    }

    const { data: options, error: pricingError } = await userClient.rpc(
      "go_calculate_ride_quote",
      { p_quote_id: quoteId, p_wait_minutes: 0 },
    );

    if (pricingError || !options?.length) {
      await adminClient.from("ride_quotes")
        .update({ status: "cancelled" })
        .eq("id", quoteId)
        .eq("passenger_id", userId);

      return respond(409, {
        error: pricingError?.message || "GO tariff pricing is unavailable.",
      });
    }

    const distanceKm = segments.reduce(
      (sum, segment) => sum + segment.distance_km,
      0,
    );
    const durationMinutes = segments.reduce(
      (sum, segment) => sum + segment.duration_minutes,
      0,
    );

    return respond(200, {
      quoteId,
      cityId,
      distanceKm: Number(distanceKm.toFixed(3)),
      durationMinutes: Number(durationMinutes.toFixed(2)),
      options,
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : "Invalid request.";
    const isTimeout = message.toLowerCase().includes("timed out");

    return respond(isTimeout ? 504 : 502, {
      error: message,
    });
  }
});
