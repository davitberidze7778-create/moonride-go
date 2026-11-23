# MOONRIDE GO

A three-application ride platform for passengers, drivers and master administrators.

## Android apps

| App | Purpose | Android application ID | Build artifact |
|---|---|---|---|
| **MoonrideGo** | Passenger ride planning, TomTom route quote, fare categories, profile and ride history | `ge.moonride.passenger` | `moonride-passenger-apk` |
| **MoonrideDrive** | Driver onboarding, vehicle application, offers, ride lifecycle and live GPS presence | `ge.moonride.driver` | `MoonrideDrive-APK` |
| **moonrideAdmin** | Master-admin dashboard, passenger/driver/vehicle review, ride operations, feature flags and tariff visibility | `ge.moonride.admin` | `moonrideAdmin-APK` |

All three use the same Classic Blue brand system: navy background, blue panels and actions, white/ice-blue text, and the shared M + location-pin launcher icon.

## Source layout

- `apps/passenger` — existing Flutter passenger app. Its current TomTom route, GPS, stop, quote, six-category fare and profile/order flows are preserved.
- `apps/driver` — Flutter driver app.
- `apps/admin` — Flutter master-admin app.
- `packages/moonride_core` — shared theme, brand mark, Supabase initialization, sign-in and strict role gate.
- `apps/shared/brand/moonride-app-icon.svg` — single approved launcher-icon source for all three apps.
- `scripts/android/apply_moonride_branding.py` — applies the shared app icon and visible Android app label during CI builds.

## Connected backend workflows

The Driver client uses the existing authenticated Supabase RPCs:
- `go_submit_driver_application`
- `go_submit_vehicle_application`
- `go_update_driver_presence`
- `go_respond_driver_offer`
- `go_update_ride_status`

The Admin client uses:
- `go_admin_set_account_status`
- `go_admin_review_driver`
- `go_admin_review_vehicle`
- `go_update_ride_status`
- `go_get_online_driver_map`
- existing `go_app_feature_flags` rows and active tariff tables

The role gate verifies `profiles.role` and rejects suspended accounts. Admin access is restricted to `master_admin`; driver access is restricted to `driver`. The mobile clients use only the public Supabase publishable key, never a service-role key.

## Honest implementation boundary

A successful APK build or a visible screen is not proof that every production workflow is complete. The current database audit confirms profiles, driver profiles, vehicles, driver documents, driver live locations, driver offers, rides, route quotes, tariff plans/rates/waiting rules and feature flags.

The current public schema audit did **not** find dedicated Wallet ledger, card-payment provider, payout/refund, voucher/redemption, loyalty-reward or support-ticket tables. Therefore those money-moving or persistence features are not represented as live in these apps. Card and Wallet payments must stay disabled until their backend contracts, provider integration and security tests are implemented. Tariff-plan display is available in Admin; tariff editing is intentionally not exposed until the complete audit-safe update flow is verified.

Other remaining work before production sign-off includes driver document file upload/review UX, background-safe GPS tracking, in-app TomTom navigation for drivers/admin live map, SOS/support persistence, payment provider integration, wallet/refund/payout ledger, vouchers/loyalty, full tariff editing and real-device acceptance testing.

## CI

- Passenger: `.github/workflows/passenger-android-apk.yml`
- Driver and Admin: `.github/workflows/moonride-role-apps-apk.yml`

Each job runs Flutter dependency resolution, analysis, tests, then a separate Android release APK build. Artifacts are uploaded separately. APKs must still be installed and exercised on real Android devices before release approval.
