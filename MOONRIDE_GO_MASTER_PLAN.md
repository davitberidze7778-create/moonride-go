# MOONRIDE GO — საბოლოო ერთიანი პროექტის გეგმა

**განახლებულია:** 2026-11-20  
**სტატუსი:** არქიტექტურა და ძირითადი backend-ის ნაწილი არსებობს; მობილური აპები, 2GIS-ის რეალური გასაღებები და სრულყოფილი ride lifecycle ჯერ დასასრულებელია.  
**მიზანი:** სამი სრულად განცალკევებული პროდუქტის შექმნა ერთი უსაფრთხო backend-ით და რეალური Android/iOS/Web გამოშვებით.

---

## 1. საბოლოო არქიტექტურა

MOONRIDE GO არის ერთი სატაქსო პლატფორმა სამი დამოუკიდებელი აპლიკაციით:

1. **MOONRIDE GO Passenger** — მგზავრის Android/iOS აპი და ვებ-ვერსია.
2. **MOONRIDE GO Driver** — მძღოლის Android/iOS სამუშაო აპი და ვებ-ვერსია.
3. **MOONRIDE GO MASTER ADMIN** — ადმინისტრირების ვებ-დაფა და Android/iOS აპი, მათ შორის ცალკე Master Admin APK.

სამივე იყენებს ერთ Supabase პროექტს, მაგრამ ეკრანები, შესაძლებლობები და როლები განცალკევებულია. მგზავრს არ უნდა შეეძლოს Driver/Admin მონაცემების ან ოპერაციების ნახვა. ყველა წვდომა სერვერზე მოწმდება.

### ტექნოლოგიები

- Flutter — მობილური აპლიკაციები; ერთი საერთო mobile workspace და სამი entrypoint/build flavor.
- Supabase — Auth, PostgreSQL, RLS, Realtime, Storage, Edge Functions.
- 2GIS Full Flutter SDK — Passenger/Driver რუკა, ძებნა და მობილური ნავიგაცია.
- 2GIS MapGL JS — Master Admin Web რუკა.
- 2GIS Routing API — სერვერული მარშრუტი, დრო და მანძილი; მობილური კლიენტი ფასის/მანძილის წყაროდ არ ითვლება.
- GitHub — კოდი, მიგრაციები, შემოწმებები და release pipeline.

**არ გამოიყენოთ:** ძველი Vue2/OpenRide როგორც production აპი; Airtable როგორც backend; TomTom როგორც რუკის/მარშრუტის საბოლოო პროვაიდერი; Supabase service-role key მობილურ ან ვებ კოდში.

## 2. ბრენდი და ვიზუალური სტანდარტი

- პროექტის სახელი ყველგან: **MOONRIDE GO**.
- შეთანხმებული ემბლემა: ვერცხლისფერი/თეთრი სტილიზებული M და ზემოთ ყვითელი ლოკაციის პინი; გარშემო რგოლისა და დამატებითი წარწერის გარეშე.
- ამ გეგმაში დამატებულია მხოლოდ ადრე შერჩეული მუქი ლურჯი ფონის ეფექტი: ღრმა navy/blue ტონების რბილი გრადიენტი.
- ტექსტი: თეთრი/ვერცხლისფერი; აქცენტები: შეთანხმებული ყვითელი.
- ლოგო, ყვითელი აქცენტები, ელემენტების განლაგება და ფუნქციური დიზაინი არ იცვლება ამ ფონის დამატების გამო.
- პირველი ჩატვირთვისას ბრენდირებული startup ეკრანი.
- ენა, ვალუტა და დროის სარტყელი განისაზღვრება მდებარეობით; მომხმარებელს ენის ხელით შეცვლაც შეეძლება.
- Passenger/Driver ქვედა ნავიგაცია: **მთავარი / შეკვეთები / პროფილი**. დანარჩენი შესაძლებლობები — მარჯვენა გვერდით მენიუში.

## 3. Passenger — მგზავრის აპი

### მთავარი ეკრანი და შეკვეთის შექმნა
- ავტორიზაცია/რეგისტრაცია, პროფილი და საკონტაქტო ინფორმაცია.
- მთავარი რუკა 2GIS-ზე; GPS pickup, პინის ხელით გადაწევა და მისამართის/ობიექტის მოძებნა.
- დანიშნულების ადგილი და მაქსიმუმ ოთხი შუალედური გაჩერება.
- მარშრუტის მანძილი, სავარაუდო დრო და კატეგორიების ფასები.
- ახლომდებარე ონლაინ მძღოლები ძებნისას 10 კმ-ის ფარგლებში.
- შეკვეთის მინიჭების შემდეგ ავტომატური მასშტაბირება/მიდევნება მხოლოდ მინიჭებულ მძღოლზე.
- შეკვეთის დრო: ახლავე ან დაგეგმილი (ფუნქცია მხოლოდ სრულად ამოქმედების შემდეგ გამოჩნდეს).
- თითო შეკვეთაზე კატეგორიის არჩევა; ცალკე მეორე ტაქსის მოთხოვნაც შესაძლებელი უნდა იყოს, როცა პირველი უკვე მინიჭებულია.

### კატეგორიები
- ECONOM
- ECONOM+
- COMFORT
- COMFORT+
- XL
- MINIVAN
- GROUP RIDE

ფასები აპში არ ჩაიწეროს. კატეგორიის ხელმისაწვდომობა, ტევადობა და ტარიფი წამოვიდეს Supabase-ის მოქმედი GO ტარიფის გეგმიდან.

### უსაფრთხოება და კომფორტი
- SOS/112, მგზავრობის გაზიარება, მძღოლის/მანქანის მონაცემები და აქტიური მგზავრობის Live Tracking.
- მგზავრი ხედავს მხოლოდ მის შეკვეთაზე მინიჭებულ მძღოლს და მხოლოდ აქტიური მგზავრობისას.
- აუდიოჩაწერა არ გამოიყენება.
- დანამატები: ბავშვის სავარძელი, ცხოველი, ბარგი, აეროპორტის meet-and-greet, კონდიციონერი, მშვიდი მგზავრობა და ტემპერატურის არჩევანი — მხოლოდ შესაბამისი ავტომობილისა და ქალაქის მხარდაჭერისას.
- ჩაის/ბონუსების თანხა 100% მძღოლს ეკუთვნის.

### გადახდა
- ნაღდი ან tokenized/hosted card payment.
- ბარათის სრული მონაცემები MOONRIDE-ის ბაზაში არ ინახება.
- TBC/Bank of Georgia და სხვა პროვაიდერები ჩაირთოს მხოლოდ რეალური ხელშეკრულების, sandbox/live გასაღებებისა და webhook-ების ტესტის შემდეგ.
- **MOONRIDE Wallet GO არ შედის საბოლოო ფუნქციონალში.** ძველი mockup-ის wallet არჩევანი საბოლოო გეგმაში აღარ გამოიყენება.

## 4. Driver — მძღოლის აპი

- მძღოლის რეგისტრაცია იურიდიული სახელით/გვარით, კონტაქტებით და საჭირო პროფილის მონაცემებით.
- დოკუმენტებისა და მანქანის ფოტოების პირადი ატვირთვა; მგზავრისთვის ეს დოკუმენტები არასოდეს გამოჩნდეს.
- სტატუსები: pending / approved / rejected / suspended.
- ავტომობილის მარკა, მოდელი, წელი, ფერი, ნომერი, სურათები და დოკუმენტები.
- AI Vehicle Inspector მხოლოდ კატეგორიის რეკომენდაციას აკეთებს; საბოლოო დამტკიცება მხოლოდ MASTER ADMIN-ს შეუძლია.
- ONLINE/OFFLINE, GPS ნებართვა და background heartbeat.
- ზუსტი მდებარეობა ადმინისტრატორს მხოლოდ ონლაინ მდგომარეობაში; მგზავრს — მხოლოდ აქტიურ შეკვეთაზე მინიჭებული მძღოლი.
- შემომავალი შეკვეთის შეთავაზება, მიღება/უარყოფა და პასუხის 15-წამიანი ფანჯარა.
- 2GIS მარშრუტი და ნავიგაცია.
- server-enforced ride state: ACCEPTED → ARRIVED → STARTED → COMPLETED; გაუქმებასა და უარყოფას ჰქონდეს მიზეზი/ისტორია.
- შეკვეთების ისტორია, შემოსავალი, საკომისიო, ჩაის თანხა, ანგარიშსწორება, შეფასებები, დახმარება, საჩივარი/გასაჩივრება.
- დოკუმენტების ვადის გაფრთხილება, SOS და ანტიფროდის სერვერული შემოწმება.

## 5. MASTER ADMIN — სრული მართვა

### Dashboard
- მგზავრების საერთო რაოდენობა, ახალი/აქტიური/შეჩერებული ანგარიშები.
- მძღოლები: სულ, ონლაინ, ოფლაინ, pending, approved, suspended.
- ავტომობილები და AI შემოწმებები.
- შეკვეთები: აქტიური, დაგეგმილი, დასრულებული, გაუქმებული.
- შემოსავალი და კომპანიის საკომისიო; ცალკე ვალუტებით, არ მოხდეს GEL/EUR/USD არასწორი შეკრება.
- პერიოდები: დღეს, გუშინ, კვირა, თვე, წელი, custom date; ქვეყანა/რეგიონი/ქალაქი/ზონა.

### ძირითადი განყოფილებები
- **Passengers:** ძებნა/ფილტრი, სრული პროფილი, რეგისტრაციის თარიღი, კონტაქტი, შეკვეთები, გადახდები, საჩივრები, აქტიური/ახალი/შეჩერებული სტატუსი, შეჩერება/აღდგენა და აუდიტი.
- **Drivers & Applications:** განაცხადები, დოკუმენტები, დამტკიცება/უარყოფა/შეჩერება, ქალაქი, სტატუსი, მანქანა, კატეგორია, რეიტინგი, შემოსავალი, საკომისიო და appeal.
- **Vehicles & Categories:** ფოტოები, AI შეფასება, Admin-ის საბოლოო დამტკიცება და კატეგორიის ცვლილებების ისტორია.
- **Orders:** შეკვეთის ყველა ეტაპი, მარშრუტი/გაჩერებები, quote/final fare, მგზავრი, მძღოლი, მანქანა, გადახდა, გაუქმება და state history.
- **Live Map:** ონლაინ მძღოლების მიმდინარე მდებარეობა; ქვეყანა/რეგიონი/ქალაქი/ქუჩის ფილტრები, შეკვეთები და რაოდენობა. ოფლაინ მძღოლის ზუსტი მდებარეობა რუკაზე არ გამოჩნდეს.
- **Tariffs:** ქვეყანა → რეგიონი → ქალაქი → ზონა → კატეგორია. ვალუტა, დროის სარტყელი, საბაზისო ფასი, ჩართული მანძილი/დრო, ზედმეტი კმ/წუთი, ლოდინი, მოქმედების პერიოდი, ვერსია და ისტორია.
- **Dynamic Pricing:** ამინდი/მოთხოვნა/ზონა/ღონისძიება და ხელით დროებითი override. მხოლოდ ახალ quote-ებს ეხება.
- **Commission:** გლობალური საკომისიო, ქალაქის წესი და მძღოლის ინდივიდუალური გამონაკლისი; ცვლილებების ძველი/ახალი მნიშვნელობა, ავტორი, დრო და მიზეზი. მიმდინარე პროცენტი უნდა იყოს Admin-ის კონფიგურირებადი პარამეტრი; ისტორიული შეთანხმებების წინააღმდეგობის გამო არ ჩაიწეროს აპში ფიქსირებულად.
- **Promotions & Rewards:** ყოველდღიური, კვირეული, წლიური პროგრამები; კამპანიის თარიღები, პირობები, რეალური დასრულებული კმ/შეკვეთები/შემოსავალი, anti-fraud და appeal. საწყისი სამიზნე პირობები: დღიური 15 GEL ≥150 კმ-ზე შესაბამისი დასრულებული მგზავრობებით; კვირეული პრიზები 250/150/100 GEL რეალური შემოსავლისა და ქალაქის შედეგის მიხედვით; წლიური 1000/500/300 GEL, რეგიონული გაყოფის გარეშე. ყველა კამპანია Admin-ის ჩართვა/გამორთვას ექვემდებარება.
- **Payments & Refunds:** hosted payment, ავტორიზაცია/ჩამოჭრა, შეცდომა, დაბრუნება, კორექტირება, cash reconciliation, driver settlement და audit.
- **Feature Flags:** თითოეული ფუნქციის ჩართვა/გამორთვა და ხელმისაწვდომობა გარემოს/ქალაქის მიხედვით; off ფუნქციები UI-ში არ გამოჩნდეს.
- **System & Audit:** სისტემური შეცდომები, ინტეგრაციების ჯანმრთელობა, უსაფრთხოება, ადმინისტრატორების მოქმედებები, როლები და მხარდაჭერა.

## 6. ტარიფი და შეკვეთის ფასი

### Batumi საწყისი GO ტარიფები
| კატეგორია | GEL/კმ |
|---|---:|
| ECONOM | 1.20 |
| ECONOM+ | 1.25 |
| COMFORT | 1.35 |
| COMFORT+ | 1.60 |
| XL | 1.71 |
| MINIVAN | 1.85 |
| GROUP RIDE | 1.17 |

საბაზისო პირობები: მინიმუმი 1.20 GEL; ჩართულია 1.3 კმ და 4 მოძრაობის წუთი; დამატებითი მოძრაობის წუთი 0.08 GEL; უფასო ლოდინი 3 წუთი; ლოდინის საფეხურები 5 წუთი = 0.50 GEL, 10 = 0.70 GEL, 15 = 1.20 GEL.

- Quote მხოლოდ სერვერზე ითვლება.
- Quote-ს აქვს 5-წუთიანი ვადა და ფასის უცვლელი tariff snapshot.
- ახალი ტარიფის ცვლილება უკვე გაცემულ quote-ს არ ცვლის.
- დინამიკური ტარიფი დარჩეს გამორთული მანამ, სანამ ამინდის/მოთხოვნის მონაცემი, ზღვრული multiplier და რეალური ტესტები არ იქნება დადასტურებული.
- ძველი `city_vehicle_rates` და GO `go_tariff_category_rates` არ აირიოს; Passenger/Driver იყენებს მხოლოდ მოქმედ GO გეგმას.
- საერთაშორისო გაფართოებისას ქვეყანა/ქალაქი/ვალუტა/timezone ადმინისტრატორიდან იმართება, არა კოდში ჩაშენებული ქალაქების სიით.

## 7. Backend და უსაფრთხოების წესები

- Auth role და Master Admin უფლებები სერვერზე განისაზღვრება; user-editable metadata არ არის ავტორიზაციის წყარო.
- RLS ყველა მომხმარებელთან დაკავშირებულ ცხრილზე; private storage buckets დოკუმენტებისთვის.
- მგზავრს — მხოლოდ საკუთარი პროფილი/შეკვეთები; მძღოლს — საკუთარი პროფილი/მანქანა/შეკვეთები; Admin — მხოლოდ სერვერზე დადასტურებული Master Admin.
- SECURITY DEFINER ფუნქციებს ჰქონდეს მინიმალური EXECUTE უფლება, ცარიელი/უსაფრთხო search_path და fully-qualified ობიექტები.
- Service-role გასაღები მხოლოდ სერვერზე/Edge Function secrets-ში; არასოდეს mobile/web bundle-ში.
- Payment webhook-ები იყოს ხელმოწერით შემოწმებული და idempotent.
- Live location-ზე retention/expiry პოლიტიკა; passenger visibility მხოლოდ active ride window.
- ყველა ფინანსური/ტარიფის/Admin ცვლილება აუდიტირებადი.
- Snapshot immutable; quote idempotency და transaction safety.
- Rate limiting, request validation, anti-abuse, App Check / device integrity სადაც შესაძლებელია.
- Auth leaked-password protection ჩართული release-მდე.
- PostGIS extension-ის public სქემიდან გადატანა უნდა მოხდეს Supabase-ის მხარდაჭერილი პროცედურითა და backup-ით; პირდაპირი DROP/CREATE CASCADE დაუშვებელია.

## 8. შეკვეთის სრული პროცესი

1. Passenger შედის აპში, იძებნება GPS pickup / destination / stops.
2. 2GIS server routing აბრუნებს მანძილს, დროსა და route geometry-ს.
3. Supabase GO tariff calculator ითვლის კატეგორიების შეთავაზებებს და ქმნის 5-წუთიან snapshot-ს.
4. Passenger ირჩევს კატეგორიასა და გადახდის საშუალებას.
5. Server ამოწმებს quote owner/status/expiry-ს და ქმნის შეკვეთას.
6. Dispatch აგზავნის შეთავაზებებს შესაბამის online/approved driver-ებთან; პირველი ვალიდური accept ატომურად იღებს შეკვეთას.
7. Passenger ხედავს მხოლოდ მინიჭებულ მძღოლს/მანქანას და ETA-ს.
8. Driver ადასტურებს ARRIVED, STARTED, COMPLETED ეტაპებს აპიდან; server ამოწმებს მდგომარეობის კანონიერ გადასვლას.
9. საბოლოო ფასი ითვალისწინებს შეთანხმებულ waiting/adjustment წესებს; payment ან cash settlement სრულდება.
10. Driver earnings, company commission, tips, audit/history და Admin dashboard ახლდება Realtime-ით.

## 9. არსებული სისტემის რეალური აუდიტი — 2026-11-20

### Supabase GO ნაწილი, რომელიც უკვე არსებობს
- მოქმედი Supabase პროექტი: `ewdkhekztkzugrmsknay`.
- ქვეყანა Georgia, რეგიონი Adjara, ქალაქი Batumi.
- 8 vehicle category, მათ შორის PREMIUM არ არის აქტიური.
- ერთი მოქმედი Batumi GO tariff plan, 7 GO category rates, 4 waiting rules, 1 dynamic rules row.
- GO feature flags / audit.
- Quote, route points, route legs, quote items, quote snapshots ცხრილები.
- RLS ყველა ბიზნეს-ცხრილზე; RLS გამორთული მხოლოდ PostGIS `public.spatial_ref_sys` სისტემურ ცხრილზე.
- აქტიური Edge Function ჯერ კიდევ `quote-route` v3 და TomTom-ზეა მიბმული.
- ამჟამად quote/snapshot/route/vehicle/live-location ჩანაწერები ცარიელია; სრული ride/dispatch/payment/notifications ნაკადი არ არის დასრულებული.
- ბოლო DB migration დაემატა: `20261119204149_harden_go_function_search_path_and_postgis_write_access`.

### GitHub
- არსებული `1.0` branch არის ძველი Vue 2 / OpenRide proof-of-concept.
- README ამბობს, რომ პროექტი შეჩერებულია და Airtable production backend-ად არ გამოიყენება.
- ახალი GO სამუშაო გამოყოფილია ამ branch-ში: `go/flutter-foundation-2026-11-20`; legacy branch `1.0` არ შეცვლილა.
- ძველ კოდში ჩანს TomTom/Airtable-ის ისტორიული კავშირი და Admin/Driver placeholder-ები; ისინი ახალ აპებში არ უნდა გადაიტანოს.
- ახალი mobile workspace იწყება `apps/mobile` ქვეშ; native Android/iOS პროექტების გენერაცია Flutter CLI-ით დარჩენილ build ეტაპზე ხდება.

### უსაფრთხოების ცვლილება, რომელიც შესრულდა
- `go_create_ride_quote`, `go_calculate_ride_quote`, `go_calculate_tariff_options`, `go_is_feature_enabled`, `is_master_admin` ფუნქციებზე search_path გამკაცრდა.
- Trigger helper `go_prevent_snapshot_mutation` და event-trigger helper `rls_auto_enable` პირდაპირი anon/authenticated RPC გამოძახებიდან შეიზღუდა.
- `is_master_admin()` anon-ისთვის გაუქმდა; authenticated RLS evaluation შენარჩუნდა.
- Test table-ით დადასტურდა, რომ `ensure_rls` event trigger ახლად შექმნილ public table-ზე RLS ავტომატურად რთავს.
- Security Advisor-ში anon SECDEF finding-ები 5-დან 3-მდე შემცირდა; დარჩენილია PostGIS `st_estimatedextent` overload-ები.
- გაფრთხილება/ERROR `public.spatial_ref_sys`-ზე კვლავ რჩება. SQL migration-ის REVOKE მცდელობის შემდეგ შემოწმებამ აჩვენა, რომ ცხრილის მფლობელის `supabase_admin` privilege-ები არ შეცვლილა. ამიტომ ეს ცვლილება **არ ჩაითვალოს მოგვარებულად**. საჭიროა Supabase-ის მხარდაჭერილი PostGIS relocation / owner-side fix და სრული შემოწმება.
- Auth leaked-password protection ჯერ არ არის ჩართული.
- SECURITY DEFINER GO quote RPC-ები authenticated მომხმარებლებისთვის რჩება მხოლოდ owner/status/feature/route validation-ით დაცული, რადგან მიმდინარე Edge Function მომხმარებლის JWT-ით მათ RPC-ს იძახებს.

## 10. შემდეგი ტექნიკური ეტაპები

### A. 2GIS ინტეგრაცია
- Mobile SDK Full-ის სტაბილური ვერსია: `dgis_mobile_sdk_full 13.6.1` (დაწყებისას lockfile-ით დაფიქსირდეს კონკრეტული ვერსია).
- Supabase Flutter stable package: `supabase_flutter 2.17.2` (არ გამოიყენოთ prerelease 3.x).
- Server routing endpoint: `POST https://routing.api.2gis.com/routing/7.0.0/global?key=...`.
- Request: ordered point array, `transport=driving`, `route_mode=fastest`, `traffic_mode=jam`, `locale`.
- Server response-იდან გამოიყენება `total_distance`, `total_duration` და verified route geometry.
- Secret `DGIS_ROUTING_API_KEY` შეინახოს მხოლოდ Supabase Edge Function secrets-ში.
- თითოეულ Mobile appId-ს სჭირდება შესაბამისი `dgissdk.key`; key ფაილები/private credentials GitHub-ში არ აიტვირთოს.

### B. სრულად დასამატებელი backend lifecycle
- ride/order table + immutable status history.
- driver offers, 15-second acceptance, atomic first-accept assignment, dispatch retry/timeout.
- scheduled ride queue.
- live-location heartbeat, TTL/staleness, active-ride passenger visibility.
- payment intents/token references/provider events/refunds/settlements.
- commissions, driver-specific overrides, tips, reward campaigns, fraud review/appeal.
- notification records, push token registry, email/push delivery and retry.
- admin audit for passengers, drivers, vehicles, tariffs, commission, payments, flags and support.
- Server functions with service-role secrets, idempotency and explicit permission checks.
- Complete tests before enabling feature flags in production.

### C. Flutter client
- Passenger, Driver, Admin independent entrypoints and app IDs.
- Supabase Auth session management, typed repository layer, RLS-safe queries, realtime subscriptions.
- 2GIS map/search/routing/navigation; no direct client-side secret.
- Responsive web shell for each role; separate Master Admin layout.
- Localization, currency/timezone, graceful offline/error/loading state.
- Native Android/iOS configuration generated with Flutter CLI; flavors and distinct application IDs.

### D. Master Admin Web
- Role-protected admin login; all sensitive operations via secured Edge Functions/RPC.
- Dashboard + Passengers + Drivers + Vehicles + Orders + Live Map + Tariffs + Commission + Rewards + Payments + Reports + Settings + Audit.
- 2GIS MapGL JS with online-driver-only coordinates.
- Search, filters, server-side pagination, export and audit history.

### E. End-to-end tests and release
- Auth/RLS tests for passenger, driver, admin and anon.
- Fare quote calculation and expiry; snapshot immutable after tariff updates.
- Route point validation and 2GIS API response parsing for 2–6 points.
- Driver dispatch concurrency test; one and only one driver can claim an offer.
- Live location visibility and expiry tests.
- Ride state-machine transition tests; invalid sequence rejected.
- Cash/card, webhook signature, idempotency, refund and settlement tests.
- Admin permission/audit tests.
- Multi-city currency/timezone tests and dynamic pricing cap tests.
- App UI/accessibility/localization tests.
- Android debug and signed release build for all three apps; install/test on physical device; crash-free launch and smoke test before distribution.
- iOS and web builds plus Play Store/App Store review after Android baseline.

## 11. Release blockers that cannot be fabricated

These are real external credentials or device/build prerequisites, not missing design decisions:

1. A valid 2GIS Platform Manager Routing API key to store as `DGIS_ROUTING_API_KEY`.
2. Three app-specific 2GIS `dgissdk.key` files/app registrations for Passenger, Driver and Master Admin.
3. Flutter stable SDK and Android/iOS toolchains; the current working environment has no Flutter/Dart command.
4. A production Android signing keystore and protected signing passwords; never commit them to GitHub.
5. Payment provider merchant/sandbox/live credentials and webhook registration before enabling card payment.
6. Push provider credentials and platform certificates before enabling production push notifications.
7. Supabase support or owner-level procedure to move PostGIS out of `public` and resolve the `spatial_ref_sys` advisor finding safely.

No key, signed release APK, payment integration or 100% live ride test may be claimed until it exists and has passed verification.

## 12. Definition of done

The project is **100% complete only when** all three applications build and run on real devices/web, user roles and RLS tests pass, 2GIS map/search/routing works with production keys, quote and snapshot behavior is verified, dispatch/ride lifecycle works end-to-end, payments/refunds/reconciliation pass sandbox tests, Master Admin can manage all planned entities with audit history, security advisors have no unresolved critical project-owned findings, and signed release artifacts are generated and installed successfully.

Until then, mark each subsystem as one of: **verified**, **implemented but untested**, **blocked by credential/toolchain**, or **not yet implemented**. Never present placeholder screens or seeded counts as real live functionality.
