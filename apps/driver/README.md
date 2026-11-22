# MoonrideDrive

Classic Blue Flutter Android driver app. Uses the shared `moonride_core` package and the authenticated `driver` profile role.

## Currently connected
- Supabase sign-in and role/suspended-account checks.
- Driver application submission via `go_submit_driver_application`.
- Vehicle application submission via `go_submit_vehicle_application`.
- Approved-driver plus approved-vehicle gate before online mode.
- GPS permission, current fix and foreground location updates through `go_update_driver_presence`.
- Incoming `sent` offers and accept/reject through `go_respond_driver_offer`.
- Active ride lifecycle through `go_update_ride_status`.
- Vehicle, driver and document-status views from existing GO tables.

## Not yet production-complete
Document file upload UX, background-safe location service, in-app TomTom turn-by-turn navigation, SOS, driver earnings/payouts, wallet, and real-device lifecycle testing remain outstanding. The app does not fake a successful ride or payout.
