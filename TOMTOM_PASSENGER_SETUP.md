# TomTom Passenger map setup

This test branch embeds TomTom Maps SDK for JavaScript 1.0.0 in the Passenger app.

## Required build environment

- Node.js 22 or newer.
- A browser or Android WebView with WebGL enabled.
- The dedicated TomTom key created for MoonrideGo Maps SDK.

## Add the TomTom key to GitHub Actions

1. Open the repository in GitHub.
2. Open Settings → Secrets and variables → Actions.
3. Select New repository secret.
4. Set the name to `VUE_APP_TOMTOM_API_KEY`.
5. Paste the full TomTom API key as the value and save it.

Do not place the key in source files, commits, screenshots, or chat messages. The key ID is not the API key value.

The Passenger build reads the value from the GitHub Actions secret. If it is absent, the APK can still compile, but the map displays a configuration notice and no TomTom tiles load.

## Key security

The map itself is rendered in the app's WebView, so the map key is delivered to the client and can be inspected in the built application. It must be treated as a restricted public-client key, not as a backend secret.

- Keep only the TomTom APIs required by the app enabled.
- Use TomTom per-key usage limits and analytics.
- Keep a separate key for each app/environment where practical.
- A domain whitelist helps prevent use from copied websites, but TomTom notes that it does not stop non-browser clients. Do not enable a domain restriction for the Android app until the WebView's actual origin/referrer has been tested.
- Never use this browser map key as a privileged server-side key.

## Current first milestone

- TomTom dark map centered on Batumi.
- GPS button recenters the map and places a user marker.
- Address search, reverse geocoding, route calculation, traffic overlays, ride quoting, and order dispatch are later integration milestones. The map component alone does not create a ride or send GPS coordinates to Supabase.
