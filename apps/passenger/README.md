# MOONRIDE GO — Passenger Android

Flutter passenger-app foundation using the existing Supabase GO database and the TomTom Orbis Maps raster tiles via Flutter Map.

## Current implemented scope

- Supabase email/password registration and sign-in.
- New user profile creation through the existing `handle_new_user` database trigger. The database's default role remains `passenger`.
- Role check before showing the passenger home screen.
- GPS permission and current-position capture.
- Current city lookup from the existing `countries / regions / cities` records.
- GO tariff-plan and active vehicle-category-rate reads from Supabase.
- Passenger bottom navigation: Main, Orders, Profile.
- 112 emergency-call shortcut.
- Android APK build workflow in GitHub Actions.

## Deliberately not enabled yet

The database currently has no end-to-end ride-dispatch/order-acceptance and payment flow wired to this app. The existing `ride.quote` calculator is separate from booking/dispatch. Cash/card payments and live trip tracking are currently disabled in GO feature flags. This app therefore does not fake a successful ride booking or payment.

The existing Supabase `quote-route` Edge Function already calls TomTom for routing. Map display and routing are separate TomTom APIs and each consumes its own monthly free allowance.

## TomTom map key

The passenger map uses TomTom Orbis raster tiles through the `flutter_map` renderer. Add a TomTom API key from MyTomTom as a GitHub Actions repository secret named `TOMTOM_API_KEY`. TomTom's Freemium plan has separate monthly free request allowances per API; once an API's allowance is exhausted, requests are blocked until the allowance renews. The map can still compile without the key, but tiles will not load until the secret is configured.

## Build

GitHub Actions workflow: `.github/workflows/passenger-android-apk.yml`

It generates the Android Gradle wrapper, runs `flutter pub get`, `flutter analyze`, `flutter test`, and `flutter build apk --release`. The APK is uploaded as the workflow artifact `moonride-passenger-apk`.

The public Supabase Publishable Key is used in the client. No `service_role` or other privileged server key is placed in the app.


## CI status
The PR checks use the workflow file registered on the `1.0` base branch. The APK must not be described as release-ready until the workflow has completed successfully and the TomTom API key has been provided.
