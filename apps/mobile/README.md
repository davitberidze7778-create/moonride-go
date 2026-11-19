# MOONRIDE GO Flutter workspace

ეს არის ახალი GO კოდის განცალკევებული საფუძველი. ძველი Vue2/OpenRide ფაილები ამ branch-ში მხოლოდ მემკვიდრეობით წყაროდ რჩება და არ არის ამ აპების entrypoint.

## სამი დამოუკიდებელი აპლიკაცია

- Passenger: `lib/main_passenger.dart`
- Driver: `lib/main_driver.dart`
- Master Admin: `lib/main_admin.dart`

ყველა იყენებს საერთო `lib/moonride_app.dart` დიზაინისა და საბაზისო აპლიკაციის სტრუქტურას. რეალურ release build-ში თითოეულს ექნება საკუთარი Android applicationId / iOS bundle identifier:

- `com.moonride.go.passenger`
- `com.moonride.go.driver`
- `com.moonride.go.masteradmin`

## შექმნა და გაშვება Flutter CLI-ით

საჭიროა Flutter stable SDK (Dart 3.14+, Flutter 3.50+) და Android SDK. iOS build-ისთვის საჭიროა macOS/Xcode.

```bash
cd apps/mobile
flutter create . --project-name moonride_go --platforms=android,ios,web
flutter pub get
```

Flutter CLI-ით გენერირებული native ფაილები არ უნდა აირიოს ძველ Vue პროექტში. Android Gradle-ში დაამატეთ სამი product flavor ზემოთ მოცემული applicationId-ებით; iOS-ში შექმენით სამი scheme/configuration შესაბამისი bundle identifier-ით.

მაგალითი Passenger debug build:

```bash
flutter run --target lib/main_passenger.dart \
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=YOUR_PUBLIC_ANON_OR_PUBLISHABLE_KEY
```

Passenger release APK:

```bash
flutter build apk --release --target lib/main_passenger.dart \
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=YOUR_PUBLIC_ANON_OR_PUBLISHABLE_KEY
```

Driver და Master Admin build-ები ანალოგიურია, მაგრამ გამოიყენება შესაბამისი target და საკუთარი applicationId.

## გასაღებები და secrets

- `SUPABASE_URL` და public anon/publishable key შეიძლება მიეწოდოს აპს compile-time config-ით.
- Supabase `service_role` / secret key არასოდეს ჩასვათ Dart-ში, Gradle-ში, web bundle-ში ან GitHub-ში.
- 2GIS SDK მოითხოვს თითოეული აპლიკაციის package/bundle identifier-ზე გაცემულ `dgissdk.key` ფაილს.
- სერვერული მარშრუტის ფუნქცია იყენებს `DGIS_ROUTING_API_KEY` secret-ს Supabase Edge Function-ში; ეს key Flutter აპში არ უნდა მოხვდეს.
- არასოდეს commit-ოთ `dgissdk.key`, signing keystore, `key.properties`, payment secrets ან push certificates.

## მიმდინარე შეზღუდვა

GitHub Actions CI-ში უკვე გაეშვა Flutter stable 3.50.0 და `flutter pub get` წარმატებით დასრულდა. Analyzer-ის პირველმა გაშვებამ გამოავლინა Flutter 3.50-ის Material UI პაკეტზე მიგრაციისა და Supabase `publishableKey`-ის საჭიროება; ისინი ახლა გასწორებულია. Android/iOS native build-ები და რეალური მოწყობილობის ტესტები ჯერ კიდევ ცალკე ეტაპია.

## რუკა

არჩეული პროვაიდერია 2GIS Full Flutter SDK. SDK integration უნდა დაემატოს მის ოფიციალურ API-თან და თითოეული აპის რეალური key-ის მიღების შემდეგ. რუკა არ უნდა ჩანაცვლდეს TomTom/MapLibre/სხვა რუკით. Server route metrics მოდის მხოლოდ 2GIS Routing API-დან; fare calculation რჩება Supabase-ში.
