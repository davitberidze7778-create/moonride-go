# MOONRIDE GO — Passenger Android

Flutter passenger app using the existing Supabase GO database, the official 2GIS Flutter Mobile SDK Full for map display, and TomTom Search / the existing authenticated route-quote service for address and route functions.

## Current implemented scope

- Supabase email/password registration and sign-in.
- Passenger role check backed by `public.profiles`.
- GPS permission and current-position capture, with active-city matching.
- GO tariff-plan and active vehicle-category-rate reads from Supabase.
- 2GIS mobile map display and passenger location marker.
- TomTom place search for a destination and up to four intermediate stops.
- Passenger route quotes through the existing authenticated `quote-route` Edge Function.
- TomTom fastest-route calculation per segment, GO tariff pricing, quote snapshot, and category selection.
- Passenger bottom navigation: Main, Orders, Profile.
- 112 emergency-call shortcut.

## 2GIS map credential

The 2GIS Flutter Mobile SDK Full package requires a **licensed SDK key** to render map tiles. A free demo key is not supported by this SDK integration.

Add the licensed key, Base64-encoded, as a GitHub Actions repository secret named:

`DGIS_SDK_KEY_BASE64`

The workflow decodes it into `apps/passenger/assets/dgissdk.key` only during the CI build. The real key is not committed to Git. If the secret is absent, the APK can still compile, but the map screen displays setup instructions instead of map tiles.

## TomTom search and route quote

TomTom is retained only for place search and the existing server-side `quote-route` Edge Function. Configure `TOMTOM_API_KEY` as a GitHub Actions secret for client-side place search and as a Supabase Edge Function secret for server-side route calculation. These are separate settings from the 2GIS map key.

## Not enabled yet

The app currently creates and prices a GO fare quote; it does not dispatch a driver or create an accepted passenger booking. Cash/card payments and passenger live trip tracking remain disabled by the current GO feature flags. The app does not fake a successful booking, driver assignment, or payment.

## Build

GitHub Actions workflow: `.github/workflows/passenger-android-apk.yml`

It generates Android project files, adds the official 2GIS Maven repository and internet/location permissions, runs `flutter pub get`, `flutter analyze`, `flutter test`, and `flutter build apk --release`. The APK is uploaded as the workflow artifact `moonride-passenger-apk`.

The public Supabase Publishable Key is used in the client. No `service_role` or other privileged server key is placed in the app.
