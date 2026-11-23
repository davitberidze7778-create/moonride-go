# moonrideAdmin

Classic Blue Flutter Android master-administration app. Access is restricted by the shared role gate to active `master_admin` profiles.

## Currently connected
- Dashboard reads passenger, driver, vehicle, ride and online-driver data.
- Passenger search/filter and account status changes through `go_admin_set_account_status`.
- Driver review through `go_admin_review_driver`.
- Vehicle approval with a selectable permitted category through `go_admin_review_vehicle`.
- Recent real rides and admin cancellation through `go_update_ride_status`.
- Online-driver coordinate list through `go_get_online_driver_map`.
- Feature switches backed by `go_app_feature_flags`.
- Active tariff plan and category-rate visibility.

## Not yet production-complete
Tariff editing, document signed-preview/review, live map rendering, country/city/zone editing, comprehensive audit-log views, finance reconciliation, card PSP, Wallet ledger, refunds, payouts, vouchers, loyalty and support tickets remain outstanding or require backend support. No false revenue or payment values are displayed.
