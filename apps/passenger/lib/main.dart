import 'dart:convert';
import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

const _navy = Color(0xFF071321);
const _panel = Color(0xFF102338);
const _panelLight = Color(0xFF18334D);
const _yellow = Color(0xFFFFC928);
const _silver = Color(0xFFE8EEF5);

class AppConfig {
  static const supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://ewdkhekztkzugrmsknay.supabase.co',
  );
  static const supabasePublishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: 'sb_publishable_bshUTophPUo2GGLjJCpe7w_vF_lzyol',
  );
  static const tomtomApiKey = String.fromEnvironment('TOMTOM_API_KEY');
  static bool get hasTomtomKey => tomtomApiKey.isNotEmpty;
  static bool get supabaseConfigured =>
      supabaseUrl.startsWith('https://') &&
      supabasePublishableKey.startsWith('sb_publishable_');
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (AppConfig.supabaseConfigured) {
    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      publishableKey: AppConfig.supabasePublishableKey,
    );
  }

  runApp(const MoonridePassengerApp());
}

class MoonridePassengerApp extends StatelessWidget {
  const MoonridePassengerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MOONRIDE GO',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: _navy,
        colorScheme: ColorScheme.fromSeed(
          seedColor: _yellow,
          brightness: Brightness.dark,
          surface: _panel,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: _navy,
          foregroundColor: _silver,
          elevation: 0,
          centerTitle: false,
        ),
        cardTheme: CardThemeData(
          color: _panel,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(color: Colors.white.withValues(alpha: 0.07)),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: _panelLight,
          hintStyle: const TextStyle(color: Colors.white54),
          labelStyle: const TextStyle(color: Colors.white70),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
        ),
      ),
      home: const AuthGate(),
    );
  }
}

class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 46});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Text(
            'M',
            style: TextStyle(
              color: _silver,
              fontWeight: FontWeight.w900,
              fontSize: size * 0.83,
              height: 1,
            ),
          ),
          Positioned(
            top: 0,
            child: Icon(
              Icons.location_pin,
              color: _yellow,
              size: size * 0.43,
            ),
          ),
        ],
      ),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    if (!AppConfig.supabaseConfigured) {
      return const _SetupNotice(
        title: 'სერვერთან კავშირი დაყენებული არ არის',
        message: 'შეამოწმე Supabase-ის URL და Publishable Key build პარამეტრებში.',
      );
    }

    final client = Supabase.instance.client;
    return StreamBuilder<AuthState>(
      stream: client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final session = snapshot.data?.session ?? client.auth.currentSession;
        if (session == null) return const AuthScreen();
        return PassengerHome(userId: session.user.id);
      },
    );
  }
}

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _register = false;
  bool _busy = false;
  String? _message;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _busy = true;
      _message = null;
    });

    try {
      final auth = Supabase.instance.client.auth;
      if (_register) {
        final response = await auth.signUp(
          email: _email.text.trim(),
          password: _password.text,
          data: {'full_name': _name.text.trim()},
        );
        if (response.session == null && mounted) {
          setState(() {
            _message = 'რეგისტრაცია მიღებულია. შეამოწმე ელფოსტა ანგარიშის დასადასტურებლად.';
          });
        }
      } else {
        await auth.signInWithPassword(
          email: _email.text.trim(),
          password: _password.text,
        );
      }
    } on AuthException catch (error) {
      if (mounted) setState(() => _message = error.message);
    } catch (error) {
      if (mounted) setState(() => _message = 'კავშირი ვერ შედგა. სცადე ხელახლა.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 24),
                  const Center(child: BrandMark(size: 82)),
                  const SizedBox(height: 12),
                  const Text(
                    'MOONRIDE GO',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _silver,
                      fontWeight: FontWeight.w900,
                      fontSize: 28,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'მგზავრის აპლიკაცია',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white60),
                  ),
                  const SizedBox(height: 34),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              _register ? 'ანგარიშის შექმნა' : 'შესვლა',
                              style: const TextStyle(
                                fontSize: 21,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 18),
                            if (_register) ...[
                              TextFormField(
                                controller: _name,
                                decoration: const InputDecoration(
                                  labelText: 'სახელი და გვარი',
                                  prefixIcon: Icon(Icons.person_outline),
                                ),
                                validator: (value) =>
                                    (value == null || value.trim().length < 2)
                                        ? 'შეიყვანე სახელი და გვარი'
                                        : null,
                              ),
                              const SizedBox(height: 12),
                            ],
                            TextFormField(
                              controller: _email,
                              keyboardType: TextInputType.emailAddress,
                              decoration: const InputDecoration(
                                labelText: 'ელფოსტა',
                                prefixIcon: Icon(Icons.email_outlined),
                              ),
                              validator: (value) =>
                                  (value == null || !value.contains('@'))
                                      ? 'შეიყვანე სწორი ელფოსტა'
                                      : null,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _password,
                              obscureText: true,
                              decoration: const InputDecoration(
                                labelText: 'პაროლი',
                                prefixIcon: Icon(Icons.lock_outline),
                              ),
                              validator: (value) =>
                                  (value == null || value.length < 8)
                                      ? 'პაროლი უნდა შეიცავდეს მინიმუმ 8 სიმბოლოს'
                                      : null,
                            ),
                            if (_message != null) ...[
                              const SizedBox(height: 12),
                              Text(
                                _message!,
                                style: const TextStyle(color: _yellow),
                              ),
                            ],
                            const SizedBox(height: 18),
                            FilledButton(
                              onPressed: _busy ? null : _submit,
                              style: FilledButton.styleFrom(
                                backgroundColor: _yellow,
                                foregroundColor: _navy,
                                padding: const EdgeInsets.symmetric(vertical: 15),
                              ),
                              child: _busy
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : Text(_register ? 'რეგისტრაცია' : 'შესვლა'),
                            ),
                            TextButton(
                              onPressed: _busy
                                  ? null
                                  : () => setState(() {
                                        _register = !_register;
                                        _message = null;
                                      }),
                              child: Text(
                                _register
                                    ? 'უკვე გაქვს ანგარიში? შესვლა'
                                    : 'არ გაქვს ანგარიში? რეგისტრაცია',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'ანგარიშის უფლებები და მონაცემები Supabase-ში მოწმდება. '
                    'აპლიკაციაში არ ინახება ადმინისტრატორის საიდუმლო გასაღებები.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white38, fontSize: 11),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class PassengerHome extends StatefulWidget {
  const PassengerHome({super.key, required this.userId});

  final String userId;

  @override
  State<PassengerHome> createState() => _PassengerHomeState();
}

class _PassengerHomeState extends State<PassengerHome> {
  int _tab = 0;
  bool _loadingLocation = false;
  bool _loadingTariffs = false;
  String _fullName = 'მგზავრი';
  String _role = 'passenger';
  String _cityName = '';
  String _currency = 'GEL';
  String _locationMessage = 'მდებარეობის დასადგენად ჩართე GPS.';
  String _tariffMessage = '';
  Position? _position;
  List<_Tariff> _tariffs = [];
  String? _cityId;
  final _destinationController = TextEditingController();
  final _stopController = TextEditingController();
  bool _searchingDestination = false;
  bool _addingStop = false;
  bool _searchingStop = false;
  bool _requestingQuote = false;
  bool _selectingCategory = false;
  String? _destinationError;
  String? _stopError;
  String? _quoteMessage;
  _PlaceResult? _destination;
  List<_PlaceResult> _destinationResults = [];
  List<_PlaceResult> _stopResults = [];
  List<_PlaceResult> _selectedStops = [];
  List<_QuoteFare> _quoteOptions = [];
  String? _quoteId;
  String? _selectedCategoryCode;
  double? _quoteDistanceKm;
  double? _quoteDurationMinutes;
  List<List<LatLng>> _routeLines = [];
  _PlaceResult? _pickupPlace;
  String _mapSelectionMode = 'dropoff';
  bool _resolvingMapPoint = false;
  bool _bookingEnabled = false;
  bool _cashPaymentEnabled = false;
  bool _walletPaymentEnabled = false;
  bool _tbcPaymentEnabled = false;
  bool _bogPaymentEnabled = false;
  int _availableDriversCount = 0;
  bool _bookingInProgress = false;
  String _profileEmail = '';
  String _accountStatus = 'active';
  bool _savingProfile = false;
  String? _profileMessage;
  final _profileNameController = TextEditingController();
  final _profilePhoneController = TextEditingController();

  @override
  void dispose() {
    _destinationController.dispose();
    _stopController.dispose();
    _profileNameController.dispose();
    _profilePhoneController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadProfile();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _getLocation();
    });
  }

  Future<void> _loadProfile() async {
    try {
      final row = await Supabase.instance.client
          .from('profiles')
          .select('full_name,role,email,phone,account_status')
          .eq('id', widget.userId)
          .maybeSingle();

      if (!mounted) return;
      if (row == null) {
        setState(() => _tariffMessage = 'ანგარიშის პროფილი ჯერ არ მოიძებნა.');
        return;
      }

      final role = (row['role'] ?? '').toString();
      if (role != 'passenger') {
        await Supabase.instance.client.auth.signOut();
        if (mounted) {
          setState(() => _tariffMessage =
              'ეს ანგარიში მგზავრის აპლიკაციისთვის არ არის განკუთვნილი.');
        }
        return;
      }

      final fullName = (row['full_name'] ?? '').toString().trim();
      final phone = (row['phone'] ?? '').toString().trim();
      setState(() {
        _role = role;
        _fullName = fullName.isEmpty ? 'მგზავრი' : fullName.split(RegExp(r'\s+')).first;
        _profileNameController.text = fullName;
        _profilePhoneController.text = phone;
        _profileEmail = (row['email'] ?? Supabase.instance.client.auth.currentUser?.email ?? '').toString();
        _accountStatus = (row['account_status'] ?? 'active').toString();
      });
    } catch (_) {
      if (mounted) {
        setState(() => _tariffMessage = 'პროფილის ჩატვირთვა ვერ მოხერხდა.');
      }
    }
  }

  Future<void> _getLocation() async {
    setState(() {
      _loadingLocation = true;
      _locationMessage = 'მდებარეობა განისაზღვრება...';
      _tariffMessage = '';
    });

    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw Exception('GPS-ზე წვდომა არ არის ნებადართული.');
      }

      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('ტელეფონში ჩართე Location/GPS.');
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 20),
        ),
      );

      if (!mounted) return;
      setState(() {
        _position = position;
        _locationMessage =
            'GPS მიღებულია: ${position.latitude.toStringAsFixed(5)}, '
            '${position.longitude.toStringAsFixed(5)}';
      });
      await _loadTariffs(position);
    } catch (error) {
      if (mounted) {
        setState(() => _locationMessage =
            error.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _loadingLocation = false);
    }
  }

  double _distanceKm(double lat1, double lon1, double lat2, double lon2) {
    const radius = 6371.0;
    double radians(double value) => value * math.pi / 180;
    final dLat = radians(lat2 - lat1);
    final dLon = radians(lon2 - lon1);
    final a = math.pow(math.sin(dLat / 2), 2) +
        math.cos(radians(lat1)) *
            math.cos(radians(lat2)) *
            math.pow(math.sin(dLon / 2), 2);
    return radius * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  Future<void> _loadTariffs(Position position) async {
    setState(() {
      _loadingTariffs = true;
      _tariffMessage = '';
      _tariffs = [];
    });

    try {
      final client = Supabase.instance.client;
      final cities = await client
          .from('cities')
          .select('id,name,latitude,longitude,is_active,service_enabled')
          .eq('is_active', true)
          .eq('service_enabled', true);

      final matchingCities = cities.where((city) {
        return city['latitude'] != null && city['longitude'] != null;
      }).map((city) {
        final distance = _distanceKm(
          position.latitude,
          position.longitude,
          (city['latitude'] as num).toDouble(),
          (city['longitude'] as num).toDouble(),
        );
        return {'city': city, 'distance': distance};
      }).toList()
        ..sort((a, b) =>
            (a['distance'] as double).compareTo(b['distance'] as double));

      if (matchingCities.isEmpty ||
          (matchingCities.first['distance'] as double) > 60) {
        throw Exception('MOONRIDE GO ჯერ არ მუშაობს ამ მდებარეობაზე.');
      }

      final city = matchingCities.first['city'] as Map<String, dynamic>;
      final cityId = city['id'].toString();
      final plans = await client
          .from('go_tariff_plans')
          .select('id,currency_code,effective_from,effective_until')
          .eq('city_id', cityId)
          .eq('scope_type', 'city')
          .eq('is_active', true)
          .order('effective_from', ascending: false)
          .limit(10);

      final now = DateTime.now().toUtc();
      Map<String, dynamic>? plan;
      for (final candidate in plans) {
        final from = DateTime.parse(candidate['effective_from'].toString()).toUtc();
        final until = candidate['effective_until'] == null
            ? null
            : DateTime.parse(candidate['effective_until'].toString()).toUtc();
        if (!from.isAfter(now) && (until == null || until.isAfter(now))) {
          plan = candidate;
          break;
        }
      }
      if (plan == null) {
        throw Exception('ამ ქალაქისთვის მოქმედი GO ტარიფი ვერ მოიძებნა.');
      }

      final rateRows = await client
          .from('go_tariff_category_rates')
          .select('category_id,rate_per_km')
          .eq('tariff_plan_id', plan['id'].toString());

      final categoryIds = rateRows
          .map((row) => row['category_id'].toString())
          .toSet()
          .toList();
      if (categoryIds.isEmpty) {
        throw Exception('ამ ტარიფზე კატეგორიები ჯერ არ არის დამატებული.');
      }

      final categoryRows = await client
          .from('vehicle_categories')
          .select('id,code,name,is_active')
          .inFilter('id', categoryIds)
          .eq('is_active', true);

      final ratesById = <String, double>{};
      for (final row in rateRows) {
        ratesById[row['category_id'].toString()] =
            (row['rate_per_km'] as num).toDouble();
      }

      const display = <String, ({String title, int seats, int order})>{
        'ECONOM_GO': (title: 'ECONOM', seats: 4, order: 0),
        'ECONOM_PLUS_GO': (title: 'ECONOM+', seats: 4, order: 1),
        'COMFORT_GO': (title: 'COMFORT', seats: 4, order: 2),
        'COMFORT_PLUS_GO': (title: 'COMFORT+', seats: 4, order: 3),
        'XL_GO': (title: 'XL', seats: 6, order: 4),
        'PREMIUM_GO': (title: 'PREMIUM', seats: 4, order: 5),
      };

      final loaded = <_Tariff>[];
      for (final row in categoryRows) {
        final code = row['code'].toString();
        final metadata = display[code];
        final rate = ratesById[row['id'].toString()];
        if (metadata == null || rate == null) continue;
        loaded.add(_Tariff(
          code: code,
          title: metadata.title,
          seats: metadata.seats,
          rate: rate,
          order: metadata.order,
        ));
      }
      loaded.sort((a, b) => a.order.compareTo(b.order));

      if (!mounted) return;
      setState(() {
        _cityId = cityId;
        _cityName = city['name'].toString();
        _currency = (plan!['currency_code'] ?? 'GEL').toString();
        _tariffs = loaded;
        _tariffMessage = loaded.isEmpty ? 'აქტიური კატეგორიები არ მოიძებნა.' : '';
      });
    } catch (error) {
      if (mounted) {
        setState(() => _tariffMessage =
            error.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _loadingTariffs = false);
    }
  }

  Future<void> _searchDestination() async {
    final query = _destinationController.text.trim();
    if (query.length < 3) {
      setState(() => _destinationError = 'შეიყვანე მინიმუმ 3 სიმბოლო.');
      return;
    }
    if (!AppConfig.hasTomtomKey) {
      setState(() => _destinationError =
          'TomTom API key ჯერ არ არის დამატებული. რუკისა და მისამართების ძებნის გასააქტიურებლად საჭიროა TOMTOM_API_KEY.');
      return;
    }

    setState(() {
      _searchingDestination = true;
      _destinationError = null;
      _destinationResults = [];
    });

    try {
      final params = <String, String>{
        'key': AppConfig.tomtomApiKey,
        'limit': '6',
        'language': 'ka',
      };
      if (_position != null) {
        params['lat'] = _position!.latitude.toString();
        params['lon'] = _position!.longitude.toString();
        params['radius'] = '50000';
      }
      final uri = Uri.https(
        'api.tomtom.com',
        '/search/2/search/$query.json',
        params,
      );
      final response = await http.get(uri).timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) {
        throw Exception('მისამართის ძებნის სერვისი მიუწვდომელია (${response.statusCode}).');
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final rawResults = decoded['results'] as List<dynamic>? ?? [];
      final places = <_PlaceResult>[];
      for (final raw in rawResults.take(6)) {
        if (raw is! Map) continue;
        final item = Map<String, dynamic>.from(raw);
        final position = item['position'];
        if (position is! Map) continue;
        final coordinates = Map<String, dynamic>.from(position);
        final addressValue = item['address'];
        final address = addressValue is Map
            ? Map<String, dynamic>.from(addressValue)
            : <String, dynamic>{};
        final poiValue = item['poi'];
        final poi = poiValue is Map
            ? Map<String, dynamic>.from(poiValue)
            : <String, dynamic>{};
        final title = (poi['name'] ?? address['freeformAddress'] ?? query)
            .toString();
        final subtitle = (address['freeformAddress'] ?? '').toString();
        final lat = coordinates['lat'];
        final lon = coordinates['lon'];
        if (lat is! num || lon is! num) continue;
        places.add(_PlaceResult(
          title: title,
          address: subtitle.isEmpty ? title : subtitle,
          latitude: lat.toDouble(),
          longitude: lon.toDouble(),
        ));
      }

      if (!mounted) return;
      setState(() {
        _destinationResults = places;
        if (places.isEmpty) {
          _destinationError = 'მისამართი ვერ მოიძებნა. შეცვალე საძიებო ტექსტი.';
        }
      });
    } catch (error) {
      if (mounted) {
        setState(() => _destinationError =
            error.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _searchingDestination = false);
    }
  }

  Future<void> _searchIntermediateStop() async {
    final query = _stopController.text.trim();
    if (query.length < 3) {
      setState(() => _stopError = 'შეიყვანე მინიმუმ 3 სიმბოლო.');
      return;
    }
    if (!AppConfig.hasTomtomKey) {
      setState(() => _stopError = 'TomTom API key ჯერ არ არის დამატებული.');
      return;
    }
    setState(() {
      _searchingStop = true;
      _stopError = null;
      _stopResults = [];
    });
    try {
      final params = <String, String>{
        'key': AppConfig.tomtomApiKey,
        'limit': '6',
        'language': 'ka',
      };
      if (_position != null) {
        params['lat'] = _position!.latitude.toString();
        params['lon'] = _position!.longitude.toString();
        params['radius'] = '50000';
      }
      final uri = Uri.https(
        'api.tomtom.com',
        '/search/2/search/$query.json',
        params,
      );
      final response = await http.get(uri).timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) {
        throw Exception('გაჩერების ძებნის სერვისი მიუწვდომელია (${response.statusCode}).');
      }
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final rawResults = decoded['results'] as List<dynamic>? ?? [];
      final places = <_PlaceResult>[];
      for (final raw in rawResults.take(6)) {
        if (raw is! Map) continue;
        final item = Map<String, dynamic>.from(raw);
        final position = item['position'];
        if (position is! Map) continue;
        final coordinates = Map<String, dynamic>.from(position);
        final addressValue = item['address'];
        final address = addressValue is Map
            ? Map<String, dynamic>.from(addressValue)
            : <String, dynamic>{};
        final poiValue = item['poi'];
        final poi = poiValue is Map
            ? Map<String, dynamic>.from(poiValue)
            : <String, dynamic>{};
        final title = (poi['name'] ?? address['freeformAddress'] ?? query).toString();
        final subtitle = (address['freeformAddress'] ?? '').toString();
        final lat = coordinates['lat'];
        final lon = coordinates['lon'];
        if (lat is! num || lon is! num) continue;
        places.add(_PlaceResult(
          title: title,
          address: subtitle.isEmpty ? title : subtitle,
          latitude: lat.toDouble(),
          longitude: lon.toDouble(),
        ));
      }
      if (!mounted) return;
      setState(() {
        _stopResults = places;
        if (places.isEmpty) _stopError = 'გაჩერება ვერ მოიძებნა.';
      });
    } catch (error) {
      if (mounted) {
        setState(() => _stopError =
            error.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _searchingStop = false);
    }
  }

  void _chooseIntermediateStop(_PlaceResult place) {
    setState(() {
      _selectedStops = [..._selectedStops, place];
      _stopController.clear();
      _stopResults = [];
      _stopError = null;
      _addingStop = false;
      _quoteOptions = [];
      _quoteId = null;
      _selectedCategoryCode = null;
      _quoteMessage = null;
    });
  }

  void _removeIntermediateStop(int index) {
    setState(() {
      _selectedStops.removeAt(index);
      _quoteOptions = [];
      _quoteId = null;
      _selectedCategoryCode = null;
      _quoteMessage = null;
    });
  }

  Future<void> _chooseDestination(_PlaceResult place) async {
    setState(() {
      _destination = place;
      _destinationController.text = place.title;
      _destinationResults = [];
      _destinationError = null;
      _quoteDistanceKm = null;
      _quoteDurationMinutes = null;
      _quoteId = null;
      _quoteOptions = [];
      _routeLines = [];
      _selectedCategoryCode = null;
      _quoteMessage = null;
    });
    if (_position != null && _cityId != null) await _requestFareQuote();
  }

  Future<void> _swapRouteDirection() async {
    if (_destination == null || _position == null) return;
    final previousPickup = _pickupPlace ??
        _PlaceResult(
          title: 'ჩემი GPS მდებარეობა',
          address: 'GPS ${_position!.latitude.toStringAsFixed(5)}, ${_position!.longitude.toStringAsFixed(5)}',
          latitude: _position!.latitude,
          longitude: _position!.longitude,
        );
    final previousDestination = _destination!;
    setState(() {
      _pickupPlace = previousDestination;
      _destination = previousPickup;
      _destinationController.text = previousPickup.title;
      _selectedStops = _selectedStops.reversed.toList();
      _quoteId = null;
      _quoteOptions = [];
      _routeLines = [];
      _selectedCategoryCode = null;
      _quoteMessage = null;
    });
    await _requestFareQuote();
  }

  Future<void> _chooseMapPoint(LatLng point) async {
    if (!AppConfig.hasTomtomKey) return;
    setState(() {
      _resolvingMapPoint = true;
      _quoteMessage = null;
    });
    try {
      final uri = Uri.https(
        'api.tomtom.com',
        '/search/2/reverseGeocode/${point.latitude},${point.longitude}.json',
        {'key': AppConfig.tomtomApiKey, 'language': 'ka', 'radius': '100'},
      );
      final response = await http.get(uri).timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) {
        throw Exception('არჩეული წერტილის მისამართის დადგენა ვერ მოხერხდა.');
      }
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final addresses = decoded['addresses'] as List<dynamic>? ?? [];
      final first = addresses.isNotEmpty && addresses.first is Map
          ? Map<String, dynamic>.from(addresses.first as Map)
          : <String, dynamic>{};
      final addressValue = first['address'];
      final addressData = addressValue is Map
          ? Map<String, dynamic>.from(addressValue)
          : <String, dynamic>{};
      final address = (addressData['freeformAddress'] ?? 'რუკაზე არჩეული წერტილი').toString();
      final place = _PlaceResult(
        title: address,
        address: address,
        latitude: point.latitude,
        longitude: point.longitude,
      );
      if (!mounted) return;
      if (_mapSelectionMode == 'pickup') {
        setState(() {
          _pickupPlace = place;
          _mapSelectionMode = 'dropoff';
          _quoteId = null;
          _quoteOptions = [];
          _routeLines = [];
          _selectedCategoryCode = null;
          _quoteMessage = 'აყვანის ადგილი რუკაზე განისაზღვრა.';
        });
        if (_destination != null && _cityId != null) await _requestFareQuote();
      } else {
        await _chooseDestination(place);
      }
    } catch (error) {
      if (mounted) {
        setState(() => _quoteMessage = error.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _resolvingMapPoint = false);
    }
  }

  Future<void> _requestFareQuote() async {
    if (_position == null) {
      setState(() => _quoteMessage = 'ჯერ დაადგინე აყვანის ადგილი GPS-ით.');
      return;
    }
    if (_cityId == null) {
      setState(() => _quoteMessage = 'მომსახურების ქალაქი ვერ განისაზღვრა.');
      return;
    }
    if (_destination == null) {
      setState(() => _quoteMessage = 'ჯერ მოძებნე და აირჩიე დანიშნულების ადგილი.');
      return;
    }
    if (!AppConfig.hasTomtomKey) {
      setState(() => _quoteMessage = 'TomTom API key აკლია; მარშრუტის გამოთვლა ვერ შესრულდება.');
      return;
    }

    setState(() {
      _requestingQuote = true;
      _quoteMessage = null;
      _quoteOptions = [];
      _quoteId = null;
      _selectedCategoryCode = null;
      _routeLines = [];
    });

    final pickupLatitude = _pickupPlace?.latitude ?? _position!.latitude;
    final pickupLongitude = _pickupPlace?.longitude ?? _position!.longitude;
    final pickupAddress = _pickupPlace?.address ??
        'GPS ${_position!.latitude.toStringAsFixed(5)}, ${_position!.longitude.toStringAsFixed(5)}';

    try {
      final response = await Supabase.instance.client.functions.invoke(
        'quote-route',
        body: {
          'cityId': _cityId,
          'points': [
            {
              'point_type': 'pickup',
              'latitude': pickupLatitude,
              'longitude': pickupLongitude,
              'address': pickupAddress,
            },
            ..._selectedStops.map((stop) => <String, dynamic>{
              'point_type': 'stop',
              'latitude': stop.latitude,
              'longitude': stop.longitude,
              'address': stop.address,
            }),
            {
              'point_type': 'dropoff',
              'latitude': _destination!.latitude,
              'longitude': _destination!.longitude,
              'address': _destination!.address,
            },
          ],
        },
      );

      final payload = response.data;
      if (response.status < 200 || response.status >= 300 || payload is! Map) {
        throw Exception('მარშრუტის სერვერმა ვერ დააბრუნა ფასის შეთავაზება.');
      }
      final data = Map<String, dynamic>.from(payload);
      final rawOptions = data['options'] as List<dynamic>? ?? [];
      final fares = <_QuoteFare>[];
      for (final raw in rawOptions) {
        if (raw is! Map) continue;
        final option = Map<String, dynamic>.from(raw);
        final categoryCode = (option['category_code'] ?? '').toString();
        if (categoryCode == 'MINIVAN_GO' || categoryCode == 'GROUP_RIDE_GO') continue;
        final total = option['total_fare'];
        if (total is! num) continue;
        fares.add(_QuoteFare(
          categoryCode: categoryCode,
          ratePerKm: (option['rate_per_km'] as num?)?.toDouble() ?? 0,
          totalFare: total.toDouble(),
          currency: (option['currency_code'] ?? _currency).toString(),
        ));
      }
      if (fares.isEmpty || data['quoteId'] == null) {
        throw Exception('მოქმედი GO ტარიფით შეთავაზება ვერ გამოითვალა.');
      }
      fares.sort((a, b) => a.totalFare.compareTo(b.totalFare));
      final rawSegments = data['routeGeometry'] as List<dynamic>? ?? [];
      final routeLines = rawSegments.whereType<Map>().map((segment) {
        final geometry = segment['coordinates'] as List<dynamic>? ?? [];
        return geometry.whereType<List>().where((pair) => pair.length >= 2).map((pair) {
          return LatLng((pair[1] as num).toDouble(), (pair[0] as num).toDouble());
        }).toList();
      }).where((points) => points.length >= 2).toList();
      final paymentMethods = data['paymentMethods'] is Map
          ? Map<String, dynamic>.from(data['paymentMethods'] as Map)
          : <String, dynamic>{};
      if (!mounted) return;
      setState(() {
        _quoteId = data['quoteId'].toString();
        _quoteDistanceKm = (data['distanceKm'] as num?)?.toDouble();
        _quoteDurationMinutes = (data['durationMinutes'] as num?)?.toDouble();
        _quoteOptions = fares;
        _routeLines = routeLines;
        _bookingEnabled = data['bookingEnabled'] == true;
        _cashPaymentEnabled = paymentMethods['cash'] == true && data['cashPaymentEnabled'] == true;
        _walletPaymentEnabled = paymentMethods['wallet'] == true;
        _tbcPaymentEnabled = paymentMethods['tbc'] == true;
        _bogPaymentEnabled = paymentMethods['bog'] == true;
        _availableDriversCount = (data['availableDriversCount'] as num?)?.toInt() ?? 0;
        _quoteMessage = 'მარშრუტი დათვლილია TomTom-ის მიხედვით. შეთავაზება 5 წუთის განმავლობაში მოქმედებს.';
      });
    } catch (error) {
      if (mounted) {
        setState(() => _quoteMessage =
            error.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _requestingQuote = false);
    }
  }

  Future<void> _selectQuoteCategory(_QuoteFare fare) async {
    final quoteId = _quoteId;
    if (quoteId == null) return;
    setState(() {
      _selectingCategory = true;
      _quoteMessage = null;
    });
    try {
      final response = await Supabase.instance.client.functions.invoke(
        'quote-route',
        body: {
          'action': 'select_category',
          'quoteId': quoteId,
          'categoryCode': fare.categoryCode,
        },
      );
      final payload = response.data;
      if (response.status < 200 || response.status >= 300 || payload is! Map) {
        throw Exception('არჩეული კატეგორიის შენახვა ვერ მოხერხდა.');
      }
      if (!mounted) return;
      setState(() {
        _selectedCategoryCode = fare.categoryCode;
        _quoteMessage = 'არჩეულია ${fare.categoryCode.replaceAll('_GO', '').replaceAll('_', ' ')} — ${fare.totalFare.toStringAsFixed(2)} ${fare.currency}.';
      });
      await _showPaymentOptions(fare);
    } catch (error) {
      if (mounted) {
        setState(() => _quoteMessage =
            error.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _selectingCategory = false);
    }
  }


  Future<void> _showPaymentOptions(_QuoteFare fare) async {
    final canDispatch = _bookingEnabled && _availableDriversCount > 0;
    final cashEnabled = canDispatch && _cashPaymentEnabled;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: _panel,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('გადახდის მეთოდი',
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              Text(
                '${fare.categoryCode.replaceAll('_GO', '').replaceAll('_', ' ')} · ${fare.totalFare.toStringAsFixed(2)} ${fare.currency}',
                style: const TextStyle(color: _yellow, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 14),
              ListTile(
                enabled: cashEnabled,
                leading: const Icon(Icons.payments_outlined, color: _yellow),
                title: const Text('ნაღდი ფული'),
                subtitle: Text(cashEnabled ? 'მძღოლთან ნაღდი ანგარიშსწორება' : 'ჯერ არ არის გააქტიურებული'),
                onTap: cashEnabled
                    ? () {
                        Navigator.of(sheetContext).pop();
                        _createRide(fare, 'cash');
                      }
                    : null,
              ),
              ListTile(
                enabled: false,
                leading: const Icon(Icons.credit_card, color: Colors.white54),
                title: const Text('უნაღდო — საბანკო ბარათი'),
                subtitle: Text((_tbcPaymentEnabled || _bogPaymentEnabled)
                    ? 'TBC / Bank of Georgia გადახდის სერვერი ჯერ არ არის დაკავშირებული'
                    : 'TBC / Bank of Georgia ჯერ არ არის გააქტიურებული'),
              ),
              ListTile(
                enabled: false,
                leading: const Icon(Icons.account_balance_wallet_outlined, color: Colors.white54),
                title: const Text('MOONRIDE Wallet'),
                subtitle: Text(_walletPaymentEnabled
                    ? 'Wallet-ის ჩამოჭრის სისტემა ჯერ არ არის მზად'
                    : 'Wallet ჯერ არ არის გააქტიურებული'),
              ),
              const Divider(height: 20),
              Text(
                !canDispatch
                    ? 'შეკვეთის ავტომატური გაგზავნა ჯერ გამორთულია. ამჟამად ხელმისაწვდომი ონლაინ მძღოლები: $_availableDriversCount.'
                    : !cashEnabled
                        ? 'ნაღდი გადახდა ჯერ არ არის გააქტიურებული.'
                        : 'აირჩიე გადახდის მეთოდი და დაადასტურე გამოძახება.',
                style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () => Navigator.of(sheetContext).pop(),
                child: const Text('დახურვა'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _createRide(_QuoteFare fare, String paymentMethod) async {
    final quoteId = _quoteId;
    if (quoteId == null || _bookingInProgress) return;
    if (!_bookingEnabled || !_cashPaymentEnabled || _availableDriversCount < 1) {
      setState(() => _quoteMessage =
          'შეკვეთა ვერ გაიგზავნა: მძღოლის განაწილება ან ნაღდი გადახდა ჯერ არ არის გააქტიურებული.');
      return;
    }
    if (paymentMethod != 'cash') {
      setState(() => _quoteMessage =
          'არჩეული გადახდის მეთოდი ჯერ არ არის ჩართული სერვერზე.');
      return;
    }
    setState(() {
      _bookingInProgress = true;
      _quoteMessage = 'ტაქსის გამოძახება იგზავნება...';
    });
    try {
      final result = await Supabase.instance.client.rpc(
        'go_create_ride_from_quote',
        params: {
          'p_quote_id': quoteId,
          'p_category_code': fare.categoryCode,
          'p_payment_method': paymentMethod,
        },
      );
      final data = result is Map
          ? Map<String, dynamic>.from(result)
          : <String, dynamic>{};
      if (data['ride_id'] == null) {
        throw Exception('შეკვეთის სერვერმა ride_id არ დააბრუნა.');
      }
      if (!mounted) return;
      setState(() {
        _quoteMessage = 'შეკვეთა შეიქმნა. მძღოლებთან გაგზავნილი შეთავაზებები: ${data['offers_sent'] ?? 0}.';
        _tab = 1;
      });
    } catch (error) {
      if (mounted) {
        setState(() => _quoteMessage =
            error.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _bookingInProgress = false);
    }
  }

  Future<void> _saveProfile() async {
    final fullName = _profileNameController.text.trim();
    final phone = _profilePhoneController.text.trim();
    if (fullName.length < 2) {
      setState(() => _profileMessage = 'შეიყვანე სახელი და გვარი.');
      return;
    }
    setState(() {
      _savingProfile = true;
      _profileMessage = null;
    });
    try {
      await Supabase.instance.client.from('profiles').update({
        'full_name': fullName,
        'phone': phone.isEmpty ? null : phone,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', widget.userId);
      if (!mounted) return;
      setState(() {
        _fullName = fullName.split(RegExp(r'\s+')).first;
        _profileMessage = 'პროფილი განახლდა.';
      });
    } catch (error) {
      if (mounted) {
        setState(() => _profileMessage =
            'პროფილის შენახვა ვერ მოხერხდა: ${error.toString().replaceFirst('Exception: ', '')}');
      }
    } finally {
      if (mounted) setState(() => _savingProfile = false);
    }
  }

  Widget _rideQuoteCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'მარშრუტი და ფასის შეთავაზება',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            Text(
              _pickupPlace?.address ??
                  (_position == null ? 'აყვანის ადგილი განისაზღვრება GPS-ით.' : 'GPS-ით განსაზღვრული აყვანის ადგილი'),
              style: const TextStyle(color: Colors.white60, fontSize: 12),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('რუკაზე აირჩიე საიდან'),
                  selected: _mapSelectionMode == 'pickup',
                  onSelected: (_) => setState(() => _mapSelectionMode = 'pickup'),
                ),
                ChoiceChip(
                  label: const Text('რუკაზე აირჩიე სად'),
                  selected: _mapSelectionMode == 'dropoff',
                  onSelected: (_) => setState(() => _mapSelectionMode = 'dropoff'),
                ),
              ],
            ),
            if (_resolvingMapPoint)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: LinearProgressIndicator(color: _yellow),
              ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _destination == null || _position == null ? null : _swapRouteDirection,
                icon: const Icon(Icons.swap_vert),
                label: const Text('მიმართულების შეცვლა'),
              ),
            ),
            const SizedBox(height: 4),
            TextField(
              controller: _destinationController,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _searchDestination(),
              decoration: const InputDecoration(
                labelText: 'დანიშნულების ადგილი',
                hintText: 'შეიყვანე ქუჩა, მისამართი ან ობიექტი',
                prefixIcon: Icon(Icons.place_outlined),
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _searchingDestination ? null : _searchDestination,
              icon: _searchingDestination
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.search),
              label: Text(_searchingDestination ? 'ვეძებ...' : 'მისამართის ძებნა'),
            ),
            if (_destinationError != null) ...[
              const SizedBox(height: 8),
              Text(_destinationError!,
                  style: const TextStyle(color: _yellow, fontSize: 12)),
            ],
            if (_destinationResults.isNotEmpty) ...[
              const SizedBox(height: 8),
              ..._destinationResults.map(
                (place) => ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.location_on_outlined, color: _yellow),
                  title: Text(place.title),
                  subtitle: Text(place.address),
                  onTap: () => _chooseDestination(place),
                ),
              ),
            ],
            if (_pickupPlace != null) ...[
              const SizedBox(height: 8),
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.trip_origin, color: _yellow),
                title: const Text('აყვანის ადგილი'),
                subtitle: Text(_pickupPlace!.address),
                trailing: IconButton(
                  tooltip: 'GPS-ზე დაბრუნება',
                  onPressed: () => setState(() {
                    _pickupPlace = null;
                    _quoteOptions = [];
                    _quoteId = null;
                    _routeLines = [];
                    _selectedCategoryCode = null;
                  }),
                  icon: const Icon(Icons.my_location),
                ),
              ),
            ],
            if (_destination != null) ...[
              const SizedBox(height: 8),
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.flag_outlined, color: _yellow),
                title: Text(_destination!.title),
                subtitle: Text(_destination!.address),
                trailing: IconButton(
                  tooltip: 'დანიშნულების წაშლა',
                  onPressed: () => setState(() {
                    _destination = null;
                    _destinationController.clear();
                    _quoteOptions = [];
                    _quoteId = null;
                    _selectedCategoryCode = null;
                  }),
                  icon: const Icon(Icons.close),
                ),
              ),
            ],
            if (_selectedStops.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Text('შუალედური გაჩერებები',
                  style: TextStyle(fontWeight: FontWeight.w800)),
              ..._selectedStops.asMap().entries.map((entry) => ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      radius: 13,
                      backgroundColor: _yellow.withValues(alpha: 0.16),
                      child: Text('${entry.key + 1}',
                          style: const TextStyle(color: _yellow, fontSize: 11)),
                    ),
                    title: Text(entry.value.title),
                    subtitle: Text(entry.value.address),
                    trailing: IconButton(
                      tooltip: 'გაჩერების წაშლა',
                      onPressed: () => _removeIntermediateStop(entry.key),
                      icon: const Icon(Icons.close),
                    ),
                  )),
            ],
            if (_selectedStops.length < 4)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => setState(() {
                    _addingStop = !_addingStop;
                    _stopError = null;
                    _stopResults = [];
                  }),
                  icon: const Icon(Icons.add_location_alt_outlined),
                  label: const Text('გაჩერების დამატება'),
                ),
              ),
            if (_addingStop && _selectedStops.length < 4) ...[
              TextField(
                controller: _stopController,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _searchIntermediateStop(),
                decoration: const InputDecoration(
                  labelText: 'შუალედური გაჩერება',
                  hintText: 'შეიყვანე მისამართი ან ობიექტი',
                  prefixIcon: Icon(Icons.add_location_alt_outlined),
                ),
              ),
              const SizedBox(height: 6),
              OutlinedButton.icon(
                onPressed: _searchingStop ? null : _searchIntermediateStop,
                icon: _searchingStop
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.search),
                label: Text(_searchingStop ? 'ვეძებ...' : 'გაჩერების ძებნა'),
              ),
              if (_stopError != null)
                Text(_stopError!,
                    style: const TextStyle(color: _yellow, fontSize: 12)),
              ..._stopResults.map((place) => ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.location_on_outlined, color: _yellow),
                    title: Text(place.title),
                    subtitle: Text(place.address),
                    onTap: () => _chooseIntermediateStop(place),
                  )),
            ],
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: _requestingQuote ? null : _requestFareQuote,
              icon: _requestingQuote
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2)
                    )
                  : const Icon(Icons.route),
              label: Text(_requestingQuote ? 'ვითვლი მარშრუტს...' : 'მარშრუტისა და ფასის გამოთვლა'),
              style: FilledButton.styleFrom(
                backgroundColor: _yellow,
                foregroundColor: _navy,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
            if (_quoteDistanceKm != null && _quoteDurationMinutes != null) ...[
              const SizedBox(height: 12),
              Text(
                '${_quoteDistanceKm!.toStringAsFixed(2)} კმ · დაახლოებით ${_quoteDurationMinutes!.round()} წუთი',
                style: const TextStyle(color: _silver, fontWeight: FontWeight.w700),
              ),
            ],
            if (_quoteMessage != null) ...[
              const SizedBox(height: 10),
              Text(_quoteMessage!, style: const TextStyle(color: _yellow, fontSize: 12)),
            ],
            if (_quoteOptions.isNotEmpty) ...[
              const Divider(height: 24),
              const Text(
                'ხელმისაწვდომი კატეგორიების შეთავაზება',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              ..._quoteOptions.map((fare) {
                final label = fare.categoryCode
                    .replaceAll('_GO', '')
                    .replaceAll('_', ' ');
                final selected = _selectedCategoryCode == fare.categoryCode;
                return Card(
                  margin: const EdgeInsets.only(bottom: 6),
                  color: selected ? _panelLight : _panel,
                  child: ListTile(
                    dense: true,
                    title: Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
                    subtitle: Text('${fare.ratePerKm.toStringAsFixed(2)} ${fare.currency} / კმ'),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${fare.totalFare.toStringAsFixed(2)} ${fare.currency}',
                          style: const TextStyle(color: _yellow, fontWeight: FontWeight.w900),
                        ),
                        TextButton(
                          onPressed: _selectingCategory
                              ? null
                              : () => _selectQuoteCategory(fare),
                          child: Text(selected ? 'გადახდის არჩევა' : 'არჩევა'),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _callEmergency() async {
    final uri = Uri(scheme: 'tel', path: '112');
    await launchUrl(uri);
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      _homeTab(),
      _ordersTab(),
      _profileTab(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const BrandMark(size: 34),
            const SizedBox(width: 8),
            const Text(
              'MOONRIDE GO',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
                letterSpacing: 1,
              ),
            ),
            const Spacer(),
            IconButton(
              tooltip: 'სასწრაფო დახმარება',
              onPressed: _callEmergency,
              icon: const Icon(Icons.sos, color: _yellow),
            ),
          ],
        ),
      ),
      body: IndexedStack(index: _tab, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        backgroundColor: _panel,
        indicatorColor: _yellow.withValues(alpha: 0.18),
        onDestinationSelected: (index) => setState(() => _tab = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home, color: _yellow),
            label: 'მთავარი',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long, color: _yellow),
            label: 'შეკვეთები',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person, color: _yellow),
            label: 'პროფილი',
          ),
        ],
      ),
    );
  }

  Widget _homeTab() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 22),
      children: [
        Text(
          'გამარჯობა, $_fullName!',
          style: const TextStyle(
            color: _silver,
            fontSize: 24,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'სად წავიდეთ დღეს?',
          style: TextStyle(color: Colors.white60),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 300,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: TomTomMap(
              currentPosition: _position,
              pickup: _pickupPlace,
              destination: _destination,
              routeLines: _routeLines,
              onTap: _chooseMapPoint,
              selectionMode: _mapSelectionMode,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'ჩემი მდებარეობა',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _locationMessage,
                  style: const TextStyle(color: Colors.white60, fontSize: 12),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _loadingLocation ? null : _getLocation,
                  icon: const Icon(Icons.my_location),
                  label: Text(_loadingLocation
                      ? 'მდებარეობა იტვირთება...'
                      : 'ჩემი GPS მდებარეობა'),
                  style: FilledButton.styleFrom(
                    backgroundColor: _yellow,
                    foregroundColor: _navy,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        _rideQuoteCard(),
        const SizedBox(height: 10),
        Row(
          children: [
            const Expanded(
              child: Text(
                'ავტომობილის კატეგორიები',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
              ),
            ),
            if (_cityName.isNotEmpty)
              Text(_cityName, style: const TextStyle(color: _yellow)),
          ],
        ),
        const SizedBox(height: 8),
        if (_loadingTariffs)
          const Padding(
            padding: EdgeInsets.all(20),
            child: Center(child: CircularProgressIndicator(color: _yellow)),
          )
        else if (_tariffMessage.isNotEmpty)
          _InfoCard(message: _tariffMessage)
        else if (_tariffs.isEmpty)
          const _InfoCard(message: 'GPS-ის შემდეგ გამოჩნდება ამ ქალაქის ტარიფები.')
        else
          ..._tariffs.map((tariff) => _TariffCard(
                tariff: tariff,
                currency: _currency,
              )),
        const SizedBox(height: 10),
        if (!_bookingEnabled || _availableDriversCount == 0)
          _InfoCard(
            message: 'შეკვეთების ავტომატური გაგზავნა ჯერ არ არის გააქტიურებული. ონლაინ მძღოლების რაოდენობა: $_availableDriversCount.',
          ),
      ],
    );
  }

  Widget _ordersTab() {
    final future = Supabase.instance.client
        .from('go_rides')
        .select('id,status,pickup_address,dropoff_address,fare_amount,currency_code,payment_method,created_at')
        .eq('passenger_id', widget.userId)
        .order('created_at', ascending: false)
        .limit(25);

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: _yellow));
        }
        if (snapshot.hasError) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(22),
              child: Text('შეკვეთების ისტორია ვერ ჩაიტვირთა.'),
            ),
          );
        }
        final rows = snapshot.data ?? [];
        if (rows.isEmpty) {
          return const Center(
            child: _InfoCard(message: 'შეკვეთები ჯერ არ გაქვს.'),
          );
        }
        return ListView(
          padding: const EdgeInsets.all(16),
          children: rows.map((row) {
            final id = row['id'].toString();
            return Card(
              child: ListTile(
                title: Text('შეკვეთა #${id.substring(0, 8).toUpperCase()}'),
                subtitle: Text(
                  '${row['pickup_address'] ?? '—'} → ${row['dropoff_address'] ?? '—'}\nსტატუსი: ${row['status']} · ${row['payment_method'] ?? '—'}',
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: Text(
                  row['fare_amount'] == null
                      ? '—'
                      : '${(row['fare_amount'] as num).toStringAsFixed(2)} ${row['currency_code'] ?? ''}',
                  style: const TextStyle(color: _yellow, fontWeight: FontWeight.w900),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _profileTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Center(child: BrandMark(size: 68)),
                const SizedBox(height: 10),
                Center(
                  child: Text(
                    _fullName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 20,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                const Center(
                  child: Text(
                    'მგზავრის ანგარიში',
                    style: TextStyle(color: Colors.white54),
                  ),
                ),
                const Divider(height: 28),
                TextField(
                  controller: _profileNameController,
                  decoration: const InputDecoration(
                    labelText: 'სახელი და გვარი',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _profilePhoneController,
                  decoration: const InputDecoration(
                    labelText: 'ტელეფონის ნომერი',
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 10),
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.email_outlined, color: _yellow),
                  title: const Text('ელფოსტა'),
                  subtitle: Text(_profileEmail.isEmpty ? 'არ არის მითითებული' : _profileEmail),
                ),
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: _savingProfile ? null : _saveProfile,
                  icon: _savingProfile
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.save_outlined),
                  label: Text(_savingProfile ? 'ინახება...' : 'პროფილის შენახვა'),
                  style: FilledButton.styleFrom(backgroundColor: _yellow, foregroundColor: _navy),
                ),
                if (_profileMessage != null) ...[
                  const SizedBox(height: 8),
                  Text(_profileMessage!, style: const TextStyle(color: _yellow, fontSize: 12)),
                ],
                const Divider(height: 28),
                Text('ანგარიშის სტატუსი: ${_accountStatus == 'active' ? 'აქტიური' : 'შეჩერებული'}'),
                const SizedBox(height: 8),
                Text('ანგარიშის ID: ${widget.userId}', style: const TextStyle(color: Colors.white54, fontSize: 11)),
                const SizedBox(height: 6),
                Text('როლი: $_role'),
                const SizedBox(height: 16),
                const Divider(),
                const ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.account_balance_wallet_outlined, color: _yellow),
                  title: Text('MOONRIDE Wallet'),
                  subtitle: Text('Wallet ჯერ არ არის გააქტიურებული. ბალანსი გამოჩნდება საფულის სერვერის ამოქმედების შემდეგ.'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => Supabase.instance.client.auth.signOut(),
          icon: const Icon(Icons.logout),
          label: const Text('ანგარიშიდან გამოსვლა'),
          style: OutlinedButton.styleFrom(
            foregroundColor: _yellow,
            side: const BorderSide(color: _yellow),
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
      ],
    );
  }
}

class _PlaceResult {
  const _PlaceResult({
    required this.title,
    required this.address,
    required this.latitude,
    required this.longitude,
  });

  final String title;
  final String address;
  final double latitude;
  final double longitude;
}

class _QuoteFare {
  const _QuoteFare({
    required this.categoryCode,
    required this.ratePerKm,
    required this.totalFare,
    required this.currency,
  });

  final String categoryCode;
  final double ratePerKm;
  final double totalFare;
  final String currency;
}

class _Tariff {
  const _Tariff({
    required this.code,
    required this.title,
    required this.seats,
    required this.rate,
    required this.order,
  });

  final String code;
  final String title;
  final int seats;
  final double rate;
  final int order;
}

class _TariffCard extends StatelessWidget {
  const _TariffCard({required this.tariff, required this.currency});

  final _Tariff tariff;
  final String currency;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          height: 42,
          width: 42,
          decoration: BoxDecoration(
            color: _yellow.withValues(alpha: 0.13),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.local_taxi, color: _yellow),
        ),
        title: Text(
          tariff.title,
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        subtitle: Text('${tariff.seats} მგზავრი'),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${tariff.rate.toStringAsFixed(2)} $currency',
              style: const TextStyle(
                color: _yellow,
                fontWeight: FontWeight.w900,
                fontSize: 16,
              ),
            ),
            const Text('/ კმ', style: TextStyle(color: Colors.white54)),
          ],
        ),
      ),
    );
  }
}

class TomTomMap extends StatefulWidget {
  const TomTomMap({
    super.key,
    required this.currentPosition,
    required this.pickup,
    required this.destination,
    required this.routeLines,
    required this.onTap,
    required this.selectionMode,
  });

  final Position? currentPosition;
  final _PlaceResult? pickup;
  final _PlaceResult? destination;
  final List<List<LatLng>> routeLines;
  final ValueChanged<LatLng> onTap;
  final String selectionMode;

  @override
  State<TomTomMap> createState() => _TomTomMapState();
}

class _TomTomMapState extends State<TomTomMap> {
  final MapController _controller = MapController();

  @override
  void didUpdateWidget(covariant TomTomMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    final current = widget.currentPosition;
    if (current != null &&
        (oldWidget.currentPosition == null ||
            oldWidget.currentPosition!.latitude != current.latitude ||
            oldWidget.currentPosition!.longitude != current.longitude)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _controller.move(LatLng(current.latitude, current.longitude), 15);
        }
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!AppConfig.hasTomtomKey) {
      return const _MapSetupCard(
        message: 'TomTom Map Display-ის გასააქტიურებლად დაამატე TOMTOM_API_KEY GitHub Actions secret-ში.',
      );
    }
    final current = widget.currentPosition;
    if (current == null) {
      return const _MapSetupCard(
        message: 'რუკა გამოჩნდება GPS ნებართვის მიღებისა და მიმდინარე მდებარეობის დადგენის შემდეგ.',
      );
    }

    final markers = <Marker>[
      Marker(
        point: LatLng(current.latitude, current.longitude),
        width: 42,
        height: 42,
        child: const Icon(Icons.my_location, color: Color(0xFF39A7FF), size: 34),
      ),
      if (widget.pickup != null)
        Marker(
          point: LatLng(widget.pickup!.latitude, widget.pickup!.longitude),
          width: 40,
          height: 48,
          child: const Icon(Icons.trip_origin, color: Color(0xFF45D483), size: 34),
        ),
      if (widget.destination != null)
        Marker(
          point: LatLng(widget.destination!.latitude, widget.destination!.longitude),
          width: 40,
          height: 48,
          child: const Icon(Icons.location_on, color: Color(0xFFFFC928), size: 38),
        ),
    ];

    return Stack(
      children: [
        FlutterMap(
          mapController: _controller,
          options: MapOptions(
            initialCenter: LatLng(current.latitude, current.longitude),
            initialZoom: 15,
            minZoom: 4,
            maxZoom: 19,
            onTap: (tapPosition, point) => widget.onTap(point),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://api.tomtom.com/maps/orbis/display/raster/tile/{z}/{x}/{y}?apiVersion=2&style=street-dark&key={key}',
              additionalOptions: {'key': AppConfig.tomtomApiKey},
              tileDimension: 256,
              maxNativeZoom: 22,
              userAgentPackageName: 'ge.moonride.passenger',
            ),
            if (widget.routeLines.isNotEmpty)
              PolylineLayer(
                polylines: widget.routeLines.map((points) => Polyline(
                  points: points,
                  strokeWidth: 5,
                  color: const Color(0xFF45A9FF),
                )).toList(),
              ),
            MarkerLayer(markers: markers),
          ],
        ),
        Positioned(
          left: 8,
          top: 8,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: _navy.withValues(alpha: 0.88),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white24),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              child: Text(
                widget.selectionMode == 'pickup'
                    ? 'მონიშნე აყვანის ადგილი'
                    : 'მონიშნე დანიშნულება',
                style: const TextStyle(color: _silver, fontSize: 11, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ),
        const Positioned(
          right: 6,
          bottom: 4,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Color(0xDD071321),
              borderRadius: BorderRadius.all(Radius.circular(5)),
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              child: Text(
                '© TomTom · © OpenStreetMap',
                style: TextStyle(color: Colors.white70, fontSize: 9),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _MapSetupCard extends StatelessWidget {
  const _MapSetupCard({this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _panel,
      padding: const EdgeInsets.all(22),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.map_outlined, color: _yellow, size: 45),
          const SizedBox(height: 12),
          const Text(
            'TomTom რუკა',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Text(
            message ?? 'TomTom რუკის მონაცემები ამჟამად მიუწვდომელია.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Text(
          message,
          style: const TextStyle(color: Colors.white70, height: 1.45),
        ),
      ),
    );
  }
}

class _SetupNotice extends StatelessWidget {
  const _SetupNotice({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const BrandMark(size: 72),
              const SizedBox(height: 18),
              Text(title, textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white60),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
