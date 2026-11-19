# MOONRIDEGO Passenger implementation

This branch is an isolated implementation line based on `moonride-go-passenger`.
Do not merge into the default/legacy branch until build and acceptance tests pass.

## Existing baseline discovered
- Vue 2 / Vue CLI + Capacitor Android wrapper.
- Supabase JS client and passenger auth/profile routes exist.
- TomTom Maps SDK + MapLibre are already present in the Passenger branch.
- Existing Home screen obtains device GPS, performs TomTom geocoding and route calculation.
- Existing Orders screen lists `ride_quotes` only; it is not a completed-trip history.
- Legacy OpenRide/Firebase/Airtable code remains in the repository and must be isolated from Passenger GO flows.
- Current GitHub Actions APK workflow contains a MapLibre worker-copy step that must be verified against the installed MapLibre package before changing it.
- Supabase currently has no Edge Functions deployed.
- Supabase has no verified passenger Wallet, payment ledger, voucher/redemption, or ride-dispatch implementation yet.

## Passenger requirements confirmed by the owner
- Native Android installable Passenger APK; keep iOS/Web compatibility in architecture.
- Supabase backend; TomTom GPS, geocoding and routing.
- Payment choices: cash, TBC bank card, Bank of Georgia card, and MOONRIDE Wallet.
- Wallet funding: only MASTER ADMIN can credit a passenger. Passenger-to-passenger transfers are prohibited.
- Wallet can be spent only on the owner's rides.
- If a Wallet-paid ride is cancelled, refund the full Wallet amount automatically.
- Voucher system: percentage and fixed-amount vouchers; only MASTER ADMIN can create/manage; each passenger can redeem a voucher once; applies to all ride categories.
- Loyalty reward already agreed: 25% discount after every 10 completed rides (retain the prior eligibility/rule details during implementation; do not silently redefine).
- Dispatch: broadcast a ride offer to multiple nearby available drivers; first valid acceptance wins and competing offers are closed.
- If no driver accepts, expand the search radius before notifying the passenger.
- Keep the existing GO tariff snapshot architecture; do not alter tariff rows or legacy fare tables without a separately reviewed migration.
- Keep current brand and navigation: approved MoonrideGo emblem, dark navy/blue styling, Home / Orders / Profile.

## Implementation order
1. Stabilize the current Passenger branch build and Android packaging; verify the exact MapLibre worker asset paths.
2. Map existing Supabase ride quote RPCs/tables and connect quote creation without duplicating backend logic.
3. Implement secure dispatch lifecycle and real trip records.
4. Implement Wallet ledger with immutable transactions and MASTER ADMIN-only credit controls.
5. Implement voucher issuance/redemption and 10-ride loyalty reward with server-side enforcement.
6. Integrate TBC and Bank of Georgia payment APIs only after merchant credentials and provider callback/webhook setup are available. Never collect or store raw card data in the app.
7. Implement trip history, live tracking during active trips, cancellation/refund rules, and final acceptance tests.
8. Build APK artifact and test installation on a real Android device.

## Safety / release gates
- Never put Supabase service-role keys or bank secrets in the mobile app.
- Do not mark card payments live until signed provider callbacks/webhooks are verified server-side.
- Do not mark Wallet or voucher features live until database schema, RLS, RPCs and negative authorization tests pass.
- Do not delete legacy files or alter existing Supabase data as part of this branch setup.
- The search radius remains configurable; use the previously approved project setting unless the owner changes it.
- Debug APK is for testing only; Play Store release requires a signed release build.
