import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2.57.0";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Content-Type": "application/json",
};

type RoutePoint = {
  point_type: "pickup" | "stop" | "dropoff";
  latitude: number;
  longitude: number;
  address?: string | null;
};

function json(status: number, body: Record<string, unknown>) {
  return new Response(JSON.stringify(body), { status, headers: corsHeaders });
}

function validatePoints(input: unknown): RoutePoint[] {
  if (!Array.isArray(input) || input.length < 2 || input.length > 6) {
    throw new Error("Route must contain pickup, destination and up to four stops.");
  }
  const points = input as RoutePoint[];
  return points.map((point, index) => {
    const expectedType = index === 0 ? "pickup" : index === points.length - 1 ? "dropoff" : "stop";
    if (!point || point.point_type !== expectedType) throw new Error("Invalid route point order.");
    if (!Number.isFinite(point.latitude) || point.latitude < -90 || point.latitude > 90 ||
        !Number.isFinite(point.longitude) || point.longitude < -180 || point.longitude > 180) {
      throw new Error("Invalid route coordinates.");
    }
    const address = typeof point.address === "string" ? point.address.trim().slice(0, 500) : null;
    return { point_type: expectedType, latitude: point.latitude, longitude: point.longitude, address };
  });
}

async function routeSegment(
  from: RoutePoint,
  to: RoutePoint,
  apiKey: string,
) {
  const locations = `${from.latitude},${from.longitude}:${to.latitude},${to.longitude}`;
  const url = new URL(`https://api.tomtom.com/routing/1/calculateRoute/${locations}/json`);
  url.searchParams.set("key", apiKey);
  url.searchParams.set("routeType", "fastest");
  url.searchParams.set("traffic", "true");
  url.searchParams.set("travelMode", "car");
  url.searchParams.set("computeTravelTimeFor", "all");

  const response = await fetch(url);
  if (!response.ok) {
    throw new Error(`TomTom routing request failed (${response.status}).`);
  }
  const payload = await response.json();
  const route = payload?.routes?.[0];
  const leg = route?.legs?.[0];
  const summary = leg?.summary ?? route?.summary;
  const routePoints = leg?.points ?? route?.legs?.flatMap((item: any) => item.points ?? []) ?? [];

  if (!summary || !Number.isFinite(summary.lengthInMeters) ||
      !Number.isFinite(summary.travelTimeInSeconds) || !Array.isArray(routePoints) ||
      routePoints.length < 2) {
    throw new Error("TomTom returned an incomplete route.");
  }

  return {
    distance_km: Number((summary.lengthInMeters / 1000).toFixed(3)),
    duration_minutes: Number((summary.travelTimeInSeconds / 60).toFixed(2)),
    route_geometry: {
      type: "LineString",
      coordinates: routePoints.map((point: any) => [
        Number(point.longitude), Number(point.latitude)
      ]),
    },
  };
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return json(405, { error: "Method not allowed." });

  const authorization = req.headers.get("Authorization");
  if (!authorization?.startsWith("Bearer ")) return json(401, { error: "Authentication required." });

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const tomtomKey = Deno.env.get("TOMTOM_API_KEY");

  if (!supabaseUrl || !anonKey || !serviceRoleKey) {
    return json(503, { error: "Supabase server environment is incomplete." });
  }
  if (!tomtomKey) {
    return json(503, { error: "TomTom server key is not configured. Add TOMTOM_API_KEY to Supabase Edge Function secrets." });
  }

  const token = authorization.slice("Bearer ".length);
  const userClient = createClient(supabaseUrl, anonKey, {
    auth: { persistSession: false, autoRefreshToken: false },
    global: { headers: { Authorization: authorization } },
  });
  const serviceClient = createClient(supabaseUrl, serviceRoleKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  try {
    const { data: userData, error: authError } = await userClient.auth.getUser(token);
    if (authError || !userData.user) return json(401, { error: "Session is invalid or expired." });

    const { data: profile, error: profileError } = await userClient
      .from("profiles").select("role").eq("id", userData.user.id).maybeSingle();
    if (profileError || profile?.role !== "passenger") return json(403, { error: "Passenger account required." });

    const body = await req.json();
    const cityId = typeof body.cityId === "string" ? body.cityId : "";
    if (!cityId) return json(400, { error: "City ID is required." });
    const points = validatePoints(body.points);

    const { data: city, error: cityError } = await userClient
      .from("cities").select("id,is_active,service_enabled")
      .eq("id", cityId).maybeSingle();
    if (cityError || !city || !city.is_active || !city.service_enabled) {
      return json(409, { error: "GO taxi service is not active in this city." });
    }

    const segments = [];
    for (let index = 0; index < points.length - 1; index++) {
      segments.push(await routeSegment(points[index], points[index + 1], tomtomKey));
    }

    const { data: quoteId, error: createError } = await userClient.rpc("go_create_ride_quote", {
      p_city_id: cityId,
      p_points: points,
    });
    if (createError || !quoteId) {
      return json(409, { error: createError?.message || "Could not create the GO quote." });
    }

    const { data: storedPoints, error: pointsError } = await serviceClient
      .from("ride_route_points")
      .select("id,sequence_number")
      .eq("quote_id", quoteId)
      .order("sequence_number");
    if (pointsError || !storedPoints || storedPoints.length !== points.length) {
      await serviceClient.from("ride_quotes").update({ status: "cancelled" }).eq("id", quoteId);
      return json(500, { error: "Could not verify the saved route points." });
    }

    const legs = segments.map((segment, index) => ({
      quote_id: quoteId,
      start_point_id: storedPoints[index].id,
      end_point_id: storedPoints[index + 1].id,
      sequence_number: index,
      distance_km: segment.distance_km,
      duration_minutes: segment.duration_minutes,
      route_geometry: segment.route_geometry,
    }));

    const { error: legsError } = await serviceClient.from("ride_route_legs").insert(legs);
    if (legsError) {
      await serviceClient.from("ride_quotes").update({ status: "cancelled" }).eq("id", quoteId);
      return json(500, { error: "Could not save the verified TomTom route." });
    }

    const { data: options, error: pricingError } = await userClient.rpc("go_calculate_ride_quote", {
      p_quote_id: quoteId,
      p_wait_minutes: 0,
    });
    if (pricingError || !options?.length) {
      await serviceClient.from("ride_quotes").update({ status: "cancelled" }).eq("id", quoteId);
      return json(409, { error: pricingError?.message || "GO tariff pricing is not available." });
    }

    const totalDistance = segments.reduce((sum, leg) => sum + leg.distance_km, 0);
    const totalMinutes = segments.reduce((sum, leg) => sum + leg.duration_minutes, 0);
    return json(200, {
      quoteId,
      cityId,
      distanceKm: Number(totalDistance.toFixed(3)),
      durationMinutes: Number(totalMinutes.toFixed(2)),
      options,
    });
  } catch (error) {
    return json(400, { error: error instanceof Error ? error.message : "Invalid route request." });
  }
});
