# Moonride GO — Android Flutter flavors
Three separate Android apps share the starter Flutter source:
- MoonrideADMIN: Master Admin (com.moonridego.admin)
- MoonrideGo: Passenger (com.moonridego.passenger)
- Moonridedrive: Driver (com.moonridego.driver)
Supabase authentication, profile-role gate, realtime ride feed; driver online toggle uses GPS and existing presence RPC.
This starter is NOT production complete: passenger quote/booking actions, driver offer acceptance and ride lifecycle controls, full admin functions, map SDK and payments still require implementation and testing.
GitHub Actions creates debug APKs (installable, not production-signed) as downloadable workflow artifacts.
