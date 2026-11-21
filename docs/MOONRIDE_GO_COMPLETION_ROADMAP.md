# MOONRIDE GO — Completion Roadmap

> Baseline: `go-passenger-flutter` at `78920a50f56a7f63ed64711cc4432458fb1f6606`.
> This roadmap branch is isolated from the Passenger release branch. Do not replace or restart the existing Passenger app.

## Product target

Three separate Android apps sharing one Supabase backend:
- Passenger: `MoonrideGo`
- Driver: `MOONRIDE DRIVER`
- Master Admin: `MOONRIDE ADMIN`

Shared platform: Supabase Auth, Postgres/RLS, Edge Functions, Realtime, Storage; TomTom maps/routing/search; GPS; GitHub Actions Android APK builds.

## Rules of implementation

1. Audit before changing production data, policies, functions, or secrets.
2. Preserve the current Passenger baseline and its agreed dark-blue visual system.
3. Supabase backend work is performed through Supabase SQL Editor, one SQL statement at a time; record agreed / implemented / checked separately.
4. Never expose service-role/secret keys in Android apps or repository files.
5. No destructive migration, legacy deletion, or role/policy rewrite without dependency audit and a rollback plan.
6. A build passing is not proof of runtime functionality. Each feature needs acceptance tests on Android and backend.
7. Do not mark a feature complete until the end-to-end scenario passes.

## Work packages and acceptance criteria

### P0 — Baseline audit and safety (first)
- [ ] Record current branch/commit, latest workflow run and APK artifact.
- [ ] Inventory all Flutter, legacy Vue, Supabase functions, tables, triggers, policies, buckets and feature flags.
- [ ] Map every passenger/driver/admin workflow to its current implementation.
- [ ] Audit RLS and privileged functions, especially role changes, wallet ledger, ride state transitions and admin-only operations.
- [ ] Verify required Edge Function secret *presence only* (never reveal values); confirm TomTom server key is available.
- [ ] Produce a non-destructive gap report and rollback plan.

**Exit:** a verified inventory and a prioritized list of missing or unsafe components.

### P1 — Passenger completion
- [ ] Preserve current 3-tab HOME / ORDERS / PROFILE layout and blue theme.
- [ ] Add agreed 5-second branded splash.
- [ ] Complete email registration/login, logout, password reset and Google OAuth deep-link return.
- [ ] Verify real GPS permission, current-location marker, search/geocoding, reverse geocoding, map pin selection and route rendering.
- [ ] Support pickup, destination and up to four intermediate stops.
- [ ] Calculate TomTom route distance/time and all six GO fare categories; quote expires after five minutes.
- [ ] Hide MINIVAN and GROUP RIDE categories.
- [ ] Complete quote -> category -> payment selection -> order creation.
- [ ] Complete active order screen: driver/car details, live location, status changes, cancel rules and SOS.
- [ ] Complete order history, profile editing, support and notifications.
- [ ] Add vouchers: fixed/percentage, one use per passenger per voucher, all GO categories; master-admin creation only.
- [ ] Loyalty: every 10th completed ride receives 25% discount, with server-side eligibility enforcement.

**Exit:** passenger can register, request, pay, track, complete/cancel, and review a real trip in an Android device test.

### P2 — Dispatch and ride lifecycle (shared backend)
- [ ] Define canonical ride state machine and legal transitions.
- [ ] Match approved, online, eligible drivers within 10 km; rank by ETA/route, not straight-line distance alone.
- [ ] Expand search radius before showing "no driver found".
- [ ] Deliver offers through Supabase Realtime with expiry and idempotent accept/reject.
- [ ] Enforce one driver per ride and prevent double acceptance.
- [ ] Driver fare offers may only be above system quote: +0.50, +1, +1.50, +2, +2.50, +5 or validated custom increment.
- [ ] Preserve quote snapshot and fare source; audit every transition and price change.
- [ ] Test no-driver, timeout, duplicate acceptance, cancellation, reconnect and GPS-stale cases.

**Exit:** one complete passenger-to-driver-to-completion flow, including failure paths, passes integration tests.

### P3 — Driver Android app
- [ ] Separate Flutter Android app and workflow.
- [ ] Driver registration/login and profile.
- [ ] Document and vehicle photo uploads to private Storage buckets with secure policies.
- [ ] Admin approval, rejection and resubmission flow.
- [ ] Online/offline toggle, GPS heartbeat and work-city eligibility.
- [ ] Incoming ride offers, fare offer, accept/reject and timeout.
- [ ] Navigation to pickup, passenger pickup confirmation, start/end ride.
- [ ] Earnings, commissions, wallet/settlement history, trip history and support.
- [ ] Background location behavior and Android permission disclosure tested.

**Exit:** approved driver can receive and complete a real trip and see correct earnings.

### P4 — Master Admin Android app
- [ ] Separate Flutter Android app and workflow; master_admin-only access.
- [ ] Passenger dashboard: totals, search, filters, profiles, suspend/reactivate.
- [ ] Driver onboarding: documents, vehicles, approval and suspension.
- [ ] Live orders, dispatch monitoring and driver map.
- [ ] Tariff/category/waiting-fee management with effective dates and overlap protection.
- [ ] Weather/rain/demand price overrides with enable/disable switches and audit trail.
- [ ] Voucher and loyalty campaign management.
- [ ] Payments configuration and reconciliation.
- [ ] Revenue/commission reporting in GEL/USD/EUR.
- [ ] Country/city/zone hierarchy, timezone, currency and service areas.
- [ ] Feature flags, admin roles, audit log and support ticket management.

**Exit:** master admin can safely control the operational system without direct database edits.

### P5 — Payments and wallet
- [ ] Cash workflow and driver cash/commission accounting.
- [ ] TBC and Bank of Georgia provider integrations, using provider-approved server-side flows and verified webhooks.
- [ ] Wallet ledger: admin credit only; wallet usable only for the passenger's own rides.
- [ ] Atomic debit on successful booking/payment; full automatic refund on eligible cancellation.
- [ ] No split payments.
- [ ] Idempotency, reconciliation, failed-payment recovery and immutable ledger tests.
- [ ] Driver payout/withdrawal policy: after 24 hours and only after 11:00, subject to final business rule validation.

**Exit:** every payment path has a verified transaction record and recovery/refund tests.

### P6 — Internationalization and operations
- [ ] Country -> region -> city -> service zone hierarchy.
- [ ] Currency, locale, timezone and tariff plan per city.
- [ ] GPS zone boundaries and manual fallback.
- [ ] Per-city driver eligibility and service availability.
- [ ] Monitoring, error reporting, backups, rate limits and abuse protection.
- [ ] Legacy dependency map; remove legacy only after GO parity and verification.

**Exit:** a second city/country can be configured without hard-coded Batumi assumptions.

### P7 — Release and acceptance
- [ ] Separate reproducible APK workflows for Passenger, Driver and Admin.
- [ ] Versioning, signing, artifact integrity and release notes.
- [ ] Automated unit, widget, Edge Function and integration tests.
- [ ] Real Android device matrix: login, GPS, map, route, quote, booking, dispatch, payments, active trip, cancellation, support.
- [ ] Security review: RLS, storage, secrets, role escalation, webhook authenticity and audit logs.
- [ ] Confirm APK install/launch and measured APK size; do not promise a sub-6 MB APK with bundled map/runtime until measured.
- [ ] Final release checklist signed off per app.

## First implementation order

1. P0 read-only inventory and security audit.
2. P2 canonical dispatch/ride lifecycle design (because Passenger, Driver and Admin all depend on it).
3. P1 Passenger end-to-end completion against that shared contract.
4. P3 Driver app.
5. P4 Admin app.
6. P5 payment integrations and wallet hardening.
7. P6 internationalization, P7 release acceptance.

## Status vocabulary

- **AGREED** — product requirement approved.
- **FOUND IN CODE** — code exists; not necessarily functional.
- **DEPLOYED** — deployed to the target environment.
- **VERIFIED** — acceptance test passed with evidence.
- **BLOCKED** — dependency, credential, provider approval or user action is required.
