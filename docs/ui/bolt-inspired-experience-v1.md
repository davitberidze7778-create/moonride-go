# MOONRIDE GO — Bolt-inspired interaction plan

This is an original MOONRIDE interface using familiar ride-hailing interaction patterns. It is not a pixel-for-pixel copy of Bolt's branding or screens.

## Passenger — map-led booking

1. Full-screen live map is the primary canvas.
2. A compact top layer keeps the MOONRIDE identity, current-location control and SOS/112 visible.
3. One draggable lower panel owns the complete booking sequence: pickup, destination, optional stops, route distance/time, six active MOONRIDE fare categories, and payment choice.
4. Pickup and destination can be searched or selected on the map; moving a pin resolves its address.
5. After the route is calculated, show the route and fare cards together. Selecting a category opens only currently enabled payment methods.
6. Bottom navigation remains HOME / ORDERS / PROFILE.
7. Driver details and live tracking are shown only after a real ride is accepted.

## Driver — work-first map

1. Home opens on the driver's location/map and clear online/offline status.
2. The primary action is one large online/offline control, enabled only for approved drivers with an approved vehicle.
3. New requests are displayed as actionable offer cards with pickup, destination, category, fare and expiry.
4. Accepted work becomes the active ride card with the next permitted lifecycle action and navigation entry.
5. Vehicle/category switches remain explicit and driver-controlled; GROUP RIDE and STAFF GO are separate opt-in service modes, not ordinary fare categories.
6. Profile, vehicle/document status and offers remain accessible without burying the online control.

## Admin — operations console

Admin should not imitate a passenger booking screen. It remains a separate operations console: live operational KPIs, passenger accounts, driver/vehicle approvals, real rides and online-driver map, STAFF GO, and guarded system settings. Dashboard values must come from Supabase; never invent revenue, counts or status.

## Shared rules

- Keep MOONRIDE Classic Blue, M + location-pin branding and the three separate Android package IDs.
- Preserve Supabase role boundaries and existing GO RPCs.
- Never report a ride/payment/driver as successful without a confirmed backend response.
- Keep TBC/BOG card and Wallet disabled until provider/ledger contracts and security tests are live.
- Do not enable dispatch without an approved driver, approved vehicle, correct work city and fresh GPS.
- Keep the legacy tariff categories MINIVAN and GROUP RIDE out of the ordinary passenger fare list.

## Current implementation checkpoint

- [x] The Passenger address-entry card has been moved from the map's top overlay into its lower draggable booking panel.
- [x] The Passenger sheet opens larger and has dedicated snap stops for address entry, fare selection and expanded review.
- [x] Driver home is now a full-map screen with a draggable lower work panel for online/offline, active ride and incoming offers.
- [x] Passenger, Driver and Admin now prefer TomTom when the API key is configured, with OpenStreetMap fallback.
- [x] Passenger Flutter analysis, tests and Android APK build passed on 2026-11-26.
- [x] Driver and Admin Flutter analysis/tests passed; their Android APK build is still running.
- [ ] Device test of pickup/destination, stop selection, quote and payment sheet.
- [ ] Driver home / offer / active-ride visual pass.
- [ ] Admin live-operations visual pass.
- [ ] End-to-end three-app test against the same Supabase project.
