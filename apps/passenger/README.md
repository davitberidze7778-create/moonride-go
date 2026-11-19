# MOONRIDE GO — Passenger Android

Flutter passenger-app foundation using the existing Supabase GO database and the official 2GIS Flutter Mobile SDK Full package.

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

The current Supabase `quote-route` Edge Function still calls TomTom. It must be migrated and server-verified against the agreed 2GIS routing setup before quote/booking actions are enabled in the passenger client.

## Required 2GIS credential

The 2GIS Flutter Mobile SDK Full package requires the licensed `dgissdk.key` asset. The mobile SDK does not support free demo keys. Obtain the appropriate key/subscription from 2GIS Platform Manager, then add the file as a Base64 GitHub Actions repository secret named:

`DGIS_SDK_KEY_BASE64`

The workflow writes the key into `assets/dgissdk.key` only for the CI build. Never commit the real key into Git.

## Build

GitHub Actions workflow: `.github/workflows/passenger-android-apk.yml`

It generates the Android Gradle wrapper, adds the official 2GIS Maven repository, runs `flutter pub get`, `flutter analyze`, `flutter test`, and `flutter build apk --release`. The APK is uploaded as the workflow artifact `moonride-passenger-apk`.

The public Supabase Publishable Key is used in the client. No `service_role` or other privileged server key is placed in the app.
