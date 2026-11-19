# MOONRIDE GO Passenger — implementation roadmap

Updated: 2026-11-19
Passenger implementation branch: `moonride-go-passenger-implementation`
Admin implementation branch: `moonride-go-admin`

This roadmap separates the existing verified foundation from features still to be built. It is intentionally sequenced so the map and quote path are stable before live bookings, money movement, and driver dispatch are introduced. The legacy application and existing data are not to be deleted as part of this work.

## Current verified foundation

- Passenger Android debug APK builds successfully; latest completed run before the current map patch: https://github.com/davitberidze7778-create/moonride-go/actions/runs/44562238161
- Passenger login/profile shell and Home, Orders, Profile navigation exist.
- TomTom Maps SDK 1.0.0 / MapLibre GL JS 6.19.0 map component exists.
- GPS location, reverse geocoding, address search, local route calculation and route display are present in the app code.
- GO fare quote tables, seven Batumi category rates, price calculator and quote snapshot infrastructure exist.
- The active Batumi category rates are ECONOM 1.20, ECONOM+ 1.25, COMFORT 1.35, COMFORT+ 1.60, XL 1.71, MINIVAN 1.85, GROUP RIDE 1.17 GEL/km. PREMIUM is not an approved GO category.
- A JWT-protected Supabase Edge Function `quote-route` exists (version 3). It requests server-side TomTom route data and validates passenger category selection.
- Feature flags and their audit table exist. Six GO settings/tariff tables are published to Supabase Realtime.
- MASTER ADMIN has a System Controls & Pricing page with category switches/rates, base fare, included distance/time, extra minute rate, waiting fee thresholds, dynamic/weather/demand/manual multipliers, feature switches and audits.

## Immediate blocker: separate TomTom credentials

There are two different credential uses:
1. `VUE_APP_TOMTOM_API_KEY` is the restricted client map key used by the app's WebView. This key is expected to be present for the map tiles, geocoding and client map display.
2. `TOMTOM_API_KEY` is the server-side secret read by the Supabase `quote-route` Edge Function. The app currently reports that this secret is missing.

Do not put the server key into Vue source, the APK, GitHub client build variables, or chat. Add it in Supabase Dashboard → Edge Functions → Secrets, with the exact name `TOMTOM_API_KEY`. Use a server-side TomTom key with only the routing permissions needed. Until configured, client map display can work while server-verified fare quotation fails.

## Phase 0 — map stability (current task)

Status: code changes committed; Android build is running; physical-device interaction test is still required.

- Keep one TomTom/MapLibre map instance alive; do not recreate it on every GPS refresh or Vue render.
- Enable one-finger pan and two-finger pinch zoom; disable pitch/rotation gestures that are not needed by the passenger flow.
- Provide visible native +/− navigation controls and a recenter-to-GPS control.
- Use min/max zoom bounds to prevent accidental extreme zoom.
- Recalculate the map viewport after load, container ResizeObserver changes, screen rotation, WebView resize and app resume.
- Apply touch-action/overscroll containment to the map canvas so Android WebView does not take over map gestures.
- Reduce unnecessary animation and disable antialiasing on the mobile map to lower GPU load.
- Test on a real Android phone: pan, one/two-finger pinch, +/− controls, recenter, portrait/landscape, scrolling above/below the map, route overlays, background/resume, slow network and GPS denied/granted.
- Do not call the map fixed until these manual device tests pass.

Acceptance gate: smooth map pan/zoom, no page-wide zoom or scroll stealing map gestures, no map jumps during GPS refresh, correct resize after rotation/resume, and no WebGL/map worker errors.

## Phase 1 — verified price quote

- Add the missing server-side `TOMTOM_API_KEY` secret.
- Verify route segments returned by TomTom on the server; the client-reported distance/time is not trusted for final pricing.
- Confirm all seven active category results, the five-minute quote expiry, selected category persistence and immutable fare snapshot.
- Add end-to-end test cases for zero/one/four intermediate stops, expired quote, disabled category, changed tariff version and dynamic/weather multiplier disabled.
- Weather and demand multipliers must affect new quotes only; an existing quote snapshot remains unchanged.

Acceptance gate: a passenger can enter pickup/destination, see a server-priced offer for each active category, select one, and retrieve the exact same quote snapshot afterward.

## Phase 2 — real booking and driver dispatch

The current public schema inventory has quote/route, driver profile and driver live-location foundations, but not the complete driver offer and passenger ride lifecycle. Build this as a separate, reviewed GO module rather than changing legacy ride tables.

- Add GO booking/ride and driver-offer records with RLS, indexes, state constraints and an immutable audit trail.
- Create a server-authoritative booking from a valid unexpired selected quote.
- Send offer notifications to multiple nearby online, approved drivers at the same time.
- Make the first valid driver acceptance win through one atomic database operation; expire/reject other offers.
- Expand the search radius in configurable steps if nobody accepts; notify passenger if no eligible driver is found.
- Keep starting radius, expansion distances, timeouts and city-specific dispatch behavior under MASTER ADMIN configuration.
- Support cancellation, driver no-show, passenger no-show, retry, duplicate request protection and idempotent state transitions.
- Implement notifications for new offer, acceptance, driver approaching, arrival, trip start, cancellation and completion.

Acceptance gate: concurrent driver acceptances cannot assign two drivers to one ride; no driver can accept an expired offer; a passenger sees honest search/timeout status.

## Phase 3 — trip lifecycle, realtime tracking and safety

- Define and enforce trip states: requested, searching, assigned, driver-arriving, arrived, in-progress, completed, cancelled, expired.
- Use authenticated driver location updates and show the assigned driver's live position only during the active ride.
- Restrict MASTER ADMIN live location access to online drivers under the agreed authorization model.
- Implement SOS/112, trip sharing, emergency contact presentation and audit logging.
- No audio recording.
- Persist pickup, intermediate stops, destination, arrival/start/completion timestamps and final route/fare adjustments.

Acceptance gate: every state transition is authorized, logged, and tested against unauthorized passenger/driver accounts.

## Phase 4 — payments and MOONRIDE Wallet

- Cash payment confirmation by driver/passenger under server-controlled ride completion rules.
- Wallet balance derived from an immutable ledger, not a client-editable balance column.
- MASTER ADMIN only may credit/top-up a passenger wallet; no passenger-to-passenger transfers.
- Wallet can pay only for that passenger's own rides.
- A wallet-paid booking cancelled under the agreed refund rule returns the full amount automatically, with idempotency protection.
- TBC and Bank of Georgia integrations must use hosted/tokenized payment flows, server-held merchant credentials and signed callback/webhook verification.
- Never store raw card number, CVV or bank secret in the app.
- Add settlement, reconciliation, payment retry, duplicate callback and refund failure tests.

Acceptance gate: no client can mint wallet credit or fake a card payment; all transactions have a traceable ledger record.

## Phase 5 — vouchers and loyalty

- MASTER ADMIN creates and manages fixed-amount and percentage vouchers, validity dates, usage limits, and category scope.
- Each passenger may redeem each voucher only once; server-side redemption is atomic.
- Apply vouchers to every approved category according to admin configuration.
- After every 10 completed rides, issue the agreed 25% discount on the next eligible ride's base fare only; add-ons are excluded.
- Expose reward eligibility, earned/redeemed status and usage history to the passenger and MASTER ADMIN.

Acceptance gate: concurrent redemption cannot use one voucher twice or issue the same loyalty reward twice.

## Phase 6 — passenger ride options and special workflows

- Child seat, pets, luggage, airport meet-and-greet, A/C, quiet ride and temperature preference.
- Driver capability/vehicle compatibility validation for every add-on.
- STAFF GO: one main requester (name/surname/institution/address) plus up to four additional addresses, optional names for extra passengers/recipients.
- Multiple independent rides by one passenger where permitted.
- Scheduled rides only after scheduled dispatch and driver availability are supported end-to-end.

Acceptance gate: an unavailable add-on or unsupported vehicle option cannot be booked.

## Phase 7 — internationalization, notifications and passenger completeness

- GPS-based country/city/timezone/currency/language selection, with manual override and remembered preference.
- Georgian, English, Russian, Hebrew, Polish, German, Ukrainian, Armenian, Turkish, Azerbaijani, Arabic and the other agreed language families.
- Complete passenger profile, contact verification, saved payment tokens, order history, receipts, support and notification preferences.
- Local currency formatting; server remains source of truth for currency and amounts.

Acceptance gate: quotes and receipts use the correct city plan/currency/timezone and never assume Batumi outside Batumi.

## Phase 8 — security, load and release

- RLS and RPC review for every new GO table/function; explicit grants only.
- Test passengers, drivers, admins and unauthenticated callers separately.
- Test duplicate submissions, race conditions, replayed callbacks, expired quotes/offers, disabled features and partial failures.
- Add structured logs and alerting without logging keys, card data or unnecessary precise location.
- Load test and tune before asserting readiness for 1M+ users / 50k vehicles; this scale target is not currently load-tested.
- Build signed release APK/AAB, test installation/update flows on real Android devices, and prepare Play Store release only after acceptance.

## Working rules

- Build only on the isolated GO branches until acceptance; do not merge changes into the legacy/default branch prematurely.
- Do not delete legacy tables, data, Firebase/Airtable code or storage as part of this roadmap.
- Audit existing tables/functions/policies before each migration; reuse existing GO foundations and avoid duplicate systems.
- Keep DB migrations small, additive and reviewable. Verify each migration after applying.
- Keep debug APKs clearly labelled as test builds. A successful Gradle build does not prove the ride/payment workflow is production-ready.
