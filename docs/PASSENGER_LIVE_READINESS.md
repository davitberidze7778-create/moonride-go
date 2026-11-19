# MOONRIDE GO Passenger — live readiness audit

Audit date: 2026-11-19
Branch: `moonride-go-passenger-implementation`

## What is verified

- GitHub Actions successfully built an installable Android **debug** APK on 2026-11-19.
- The run used the current Passenger branch and completed all 16 steps, including dependency install, TomTom key presence check, MapLibre worker preparation, Vue production build, Capacitor Android sync, Gradle APK build and artifact upload.
- Build run: https://github.com/davitberidze7778-create/moonride-go/actions/runs/44539546607
- APK artifact: `moonridego-passenger-apk` (debug build, temporary GitHub artifact; not a production release).
- Supabase Auth client and passenger sign-in/profile UI are present.
- TomTom/MapLibre map, GPS, geocoding and route calculation code are present.
- The APK package id is `com.moonridego.passenger`.
- The splash screen has been aligned with the purple/neon design and set to 10 seconds.

## Verified blockers for a genuine live passenger booking

### 1. GO tariff data and calculator disagree with the approved passenger categories

The active Batumi GO plan is `BATUMI_TAXI_2026_V1`, currency GEL, minimum fare 1.20, 1.3 km and 4 minutes included, 0.08 GEL per extra movement minute, 3 minutes free waiting.

Current active GO rates found in Supabase:
- ECONOM_GO: 1.20 GEL/km
- ECONOM_PLUS_GO: 1.25 GEL/km
- COMFORT_GO: 1.35 GEL/km
- COMFORT_PLUS_GO: 1.60 GEL/km
- XL_GO: 1.71 GEL/km
- PREMIUM_GO: 2.00 GEL/km

MINIVAN_GO and GROUP_RIDE_GO exist but are inactive and do not have active rates. PREMIUM_GO is active.

The agreed final passenger list is seven categories, with PREMIUM removed:
- ECONOM 1.20
- ECONOM+ 1.25
- COMFORT 1.35
- COMFORT+ 1.60
- XL 1.71
- MINIVAN 1.85
- GROUP RIDE 1.17

The current `go_calculate_ride_quote` function explicitly requires exactly six categories and explicitly includes PREMIUM_GO. The existing RPC therefore cannot implement the approved final category list yet. No tariff rows were changed in this audit.

### 2. Route pricing cannot yet complete end-to-end

- `go_create_ride_quote(p_city_id, p_points)` exists and safely creates a GO quote plus route points.
- `go_calculate_ride_quote(p_quote_id, p_wait_minutes)` requires one `ride_route_legs` row between each pair of route points.
- Current RLS policies allow passengers to read their own route legs, but do not provide an authenticated passenger insert policy.
- No existing passenger RPC was found to securely persist TomTom route legs.
- A new owner-checked SECURITY DEFINER RPC is required to save validated route legs before pricing.

### 3. The database does not yet expose the live order/dispatch/payment services

The current schema inventory contains no passenger Wallet ledger, voucher redemption, payment transaction, or driver-offer/ride dispatch tables. No deployed Supabase Edge Functions were found in the current audit.

The existing driver live-location table is present, but that alone is not a complete driver offer/acceptance, trip lifecycle, or passenger live-tracking service.

### 4. Bank card payments are not ready to be marked live

TBC and Bank of Georgia payments require merchant onboarding/API credentials and server-side signed callback/webhook verification. Credentials must remain in server-side secrets, never in the APK. No bank card payment is to be represented as live until those endpoints and callback verification have been implemented and tested.

## Safety / release status

- The current successful APK is **debug/test only** and does not meet the requested complete live feature set.
- No Supabase data or schema was modified during this audit.
- No existing legacy system data or files were deleted.
- The isolated branch is the implementation line; do not merge to the main/legacy branch until functional and security acceptance tests pass.
- Production release still needs a signed release APK/AAB and end-to-end tests on a real Android device.

## Next implementation gates

1. Review and approve a Supabase migration to align the seven GO categories and calculator.
2. Add a secure RPC to save TomTom-derived route legs, then wire the app to the existing GO quote RPC and show prices read from Supabase.
3. Build the real booking/dispatch/trip lifecycle (simultaneous driver offers, first valid acceptance wins, radius expansion, cancellation and live trip tracking).
4. Build the Wallet ledger, admin-only credits, automatic cancellation refunds, voucher issuance/redemption and server-verified 10-ride loyalty benefit.
5. Integrate TBC and Bank of Georgia through server-side payment services and signed webhooks after credentials are supplied.
6. Complete RLS/authorization, concurrency, refund, fraud and device acceptance tests before issuing a production-signed build.
