# MOONRIDE GO — Passenger Android

Flutter passenger-app foundation using the existing Supabase GO database and the TomTom Orbis Maps raster tiles via Flutter Map.

## Current implemented scope

- Supabase email/password registration and sign-in.
- New user profile creation through the existing `handle_new_user` database trigger. The database's default role remains `passenger`.
- Role check before showing the passenger home screen.
- GPS permission and current-position capture, with automatic active-city matching.
- GO tariff-plan and active vehicle-category-rate reads from Supabase.
- TomTom place search for destination and up to four intermediate stops.
- Passenger route quotes through the existing authenticated `quote-route` Edge Function.
- TomTom fastest-route calculation per segment, GO tariff pricing, immutable quote snapshot, and category selection.
- Passenger bottom navigation: Main, Orders, Profile.
- 112 emergency-call shortcut.
- Android APK build workflow in GitHub Actions, including internet and location permissions.

## Deliberately not enabled yet

The app currently creates and prices a GO fare quote; it does not yet dispatch a driver or create an accepted passenger booking. The `ride.booking_dispatch` feature flag is disabled. Cash/card payments and passenger live trip tracking are also disabled in the current GO feature flags, so the app does not fake a successful booking, driver assignment, or payment.

The existing `quote-route` Edge Function already verifies the passenger session and calls the TomTom Routing API. Route quote creation and category selection are performed through that authenticated function and the existing GO database functions.

The existing Supabase `quote-route` Edge Function already calls TomTom for routing. Map display and routing are separate TomTom APIs and each consumes its own monthly free allowance.

## TomTom API keys

The passenger app uses TomTom Orbis raster tiles and TomTom Search API for place lookup. Add the TomTom key as a GitHub Actions repository secret named `TOMTOM_API_KEY` so it can be included at build time. The same TomTom key must also be configured as a Supabase Edge Function secret named `TOMTOM_API_KEY` because `quote-route` calls TomTom Routing server-side.

These are two separate secret settings. The app can compile without the GitHub secret, but its map and address search will not work. Route calculation will return an error until the Supabase Edge Function secret is configured. TomTom Freemium quotas are separate by API; requests are blocked for a given API after its monthly allowance is exhausted.

## Build

GitHub Actions workflow: `.github/workflows/passenger-android-apk.yml`

It generates the Android Gradle wrapper, runs `flutter pub get`, `flutter analyze`, `flutter test`, and `flutter build apk --release`. The APK is uploaded as the workflow artifact `moonride-passenger-apk`.

The public Supabase Publishable Key is used in the client. No `service_role` or other privileged server key is placed in the app.


## CI status
The PR checks use the workflow file registered on the `1.0` base branch. The APK must not be described as release-ready until the workflow has completed successfully and the TomTom API key has been provided.
