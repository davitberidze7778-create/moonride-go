# MOONRIDE GO — Passenger Android

Flutter passenger app using Supabase GO services and TomTom Orbis Map Display / Search / Routing APIs.

## Implemented in the passenger branch

- Supabase email/password registration and sign-in, plus passenger-role validation.
- GPS permission request on first app screen and current-position capture.
- TomTom Orbis raster map tiles; no 2GIS SDK dependency or 2GIS key.
- Tap the map to set pickup or destination; TomTom reverse geocoding resolves the selected point to an address.
- TomTom place search and up to four intermediate stops.
- Automatic fastest-route quote after selecting a destination when GPS and city service are ready.
- Route line, distance in kilometres, estimated minutes, and prices for passenger categories.
- Passenger fare list excludes MINIVAN and GROUP RIDE; ECONOM, ECONOM+, COMFORT, COMFORT+, XL, and PREMIUM remain.
- Tariff selection opens the payment-method sheet.
- Profile fields for full name, phone, and email, with name/phone saved to the signed-in passenger profile.
- Orders tab reads actual `go_rides`, rather than displaying fare quotes as completed bookings.
- Route direction reversal and 112 emergency-call shortcut.

## TomTom key setup

The mobile map and TomTom place search read `TOMTOM_API_KEY` from a Dart define. The GitHub Actions workflow passes the repository secret with that name into the APK build.

The authenticated `quote-route` Supabase Edge Function separately reads `TOMTOM_API_KEY` from Supabase Edge Function secrets. The GitHub secret and the Supabase secret are separate settings; configure the same API key in both places. The Edge Function must have the server key to calculate server-verified route legs.

TomTom Orbis map tiles are requested from the Orbis v2 Raster Tile endpoint. The map shows TomTom / OpenStreetMap attribution.

## Booking and payments — blocked pending backend readiness

The app opens the payment-choice sheet after a fare category is selected and reads current feature-flag / driver-availability information from `quote-route`.

The present Supabase project is not ready to dispatch real rides or accept payments:
- `ride.booking_dispatch` and `payment.cash` are disabled and unavailable.
- TBC, Bank of Georgia, and Wallet payment flags are disabled and unavailable.
- There is no Wallet ledger or Wallet RPC implementation.
- No approved vehicle is registered, no approved driver has a work city, and no fresh online driver GPS location is available.

For safety, payment options remain disabled and no fake booking success is shown. The current `go_create_ride_from_quote` server function still supports cash only; card and Wallet payments need their provider / ledger integrations before they can be enabled. Do not turn on dispatch until a real approved driver, vehicle, city assignment, and fresh online location exist.

## Build

GitHub Actions workflow: `.github/workflows/passenger-android-apk.yml`

The workflow runs `flutter pub get`, `flutter analyze`, `flutter test`, and `flutter build apk --release`, then uploads the APK as the `moonride-passenger-apk` artifact. A successful source update is not proof of a successful APK build; use the latest workflow run and its artifact as the build verification.
