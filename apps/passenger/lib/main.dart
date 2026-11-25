import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:url_launcher/url_launcher.dart';
import 'staff_go_passenger_page.dart';

const _navy = Color(0xFF071B34);
const _panel = Color(0xFF102E52);
const _panelLight = Color(0xFF173F6C);
const _yellow = Color(0xFF247FE5);
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
  static const mapboxAccessToken = String.fromEnvironment('MAPBOX_ACCESS_TOKEN');
  static const googleServerClientId = String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID');
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
      home: const LaunchGate(),
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

class PasswordRecoveryLatch extends ValueNotifier<bool> {
  PasswordRecoveryLatch() : super(false);

  void handle(AuthChangeEvent event) {
    if (event == AuthChangeEvent.passwordRecovery) {
      value = true;
    } else if (event == AuthChangeEvent.signedOut) {
      value = false;
    }
  }
}

class LaunchGate extends StatefulWidget {
  const LaunchGate({super.key, this.authBuilder});

  final WidgetBuilder? authBuilder;

  @override
  State<LaunchGate> createState() => _LaunchGateState();
}

class _LaunchGateState extends State<LaunchGate>
    with SingleTickerProviderStateMixin {
  bool _showAuth = false;
  Timer? _splashTimer;
  late final AnimationController _logoController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1150),
    lowerBound: 0.90,
    upperBound: 1.08,
  )..repeat(reverse: true);
  final PasswordRecoveryLatch _passwordRecovery = PasswordRecoveryLatch();
  StreamSubscription<AuthState>? _authSubscription;

  @override
  void initState() {
    super.initState();
    // Listen immediately: the five-second branded splash must not hide
    // Supabase's one-shot passwordRecovery event from the auth screen.
    if (widget.authBuilder == null && AppConfig.supabaseConfigured) {
      _authSubscription =
          Supabase.instance.client.auth.onAuthStateChange.listen((state) {
        _passwordRecovery.handle(state.event);
      });
    }
    _splashTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) setState(() => _showAuth = true);
    });
  }

  @override
  void dispose() {
    _splashTimer?.cancel();
    _authSubscription?.cancel();
    _logoController.dispose();
    _passwordRecovery.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_showAuth) {
      return widget.authBuilder?.call(context) ??
          AuthGate(passwordRecovery: _passwordRecovery);
    }
    return Scaffold(
      backgroundColor: const Color(0xFF041226),
      body: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 0.95,
                  colors: [
                    _panel.withValues(alpha: 0.88),
                    const Color(0xFF041226),
                  ],
                ),
              ),
            ),
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedBuilder(
                  animation: _logoController,
                  builder: (context, child) => Transform.scale(
                    scale: _logoController.value,
                    child: child,
                  ),
                  child: const BrandMark(size: 240),
                ),
                const SizedBox(height: 34),
                SizedBox(
                  width: 118,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: const LinearProgressIndicator(
                      minHeight: 4,
                      backgroundColor: Color(0xFF173F6C),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Color(0xFF43A9FF),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key, required this.passwordRecovery});

  final PasswordRecoveryLatch passwordRecovery;

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
        final event = snapshot.data?.event;
        if (event == AuthChangeEvent.passwordRecovery ||
            event == AuthChangeEvent.signedOut) {
          passwordRecovery.handle(event!);
        }
        final session = snapshot.data?.session ?? client.auth.currentSession;
        if (passwordRecovery.value) {
          return const PasswordUpdateScreen();
        }
        if (session == null) return const AuthScreen();
        return PassengerHome(userId: session.user.id);
      },
    );
  }
}

class PasswordUpdateScreen extends StatefulWidget {
  const PasswordUpdateScreen({super.key});

  @override
  State<PasswordUpdateScreen> createState() => _PasswordUpdateScreenState();
}

class _PasswordUpdateScreenState extends State<PasswordUpdateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  bool _completed = false;
  String? _message;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _savePassword() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: _password.text),
      );
      if (mounted) setState(() => _completed = true);
    } on AuthException catch (error) {
      if (mounted) setState(() => _message = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _message = 'პაროლის შეცვლა ვერ შესრულდა. სცადე ხელახლა.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _returnToSignIn() async {
    await Supabase.instance.client.auth.signOut();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _navy,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(22),
                  child: _completed
                      ? Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const BrandMark(size: 72),
                            const SizedBox(height: 18),
                            const Text(
                              'პაროლი წარმატებით შეიცვალა',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: _silver,
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 18),
                            FilledButton(
                              onPressed: _returnToSignIn,
                              child: const Text('შესვლაზე დაბრუნება'),
                            ),
                          ],
                        )
                      : Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                'ახალი პაროლი',
                                style: TextStyle(
                                  color: _silver,
                                  fontSize: 21,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 18),
                              TextFormField(
                                controller: _password,
                                obscureText: true,
                                decoration: const InputDecoration(
                                  labelText: 'ახალი პაროლი',
                                  prefixIcon: Icon(Icons.lock_outline),
                                ),
                                validator: (value) =>
                                    value == null || value.length < 8
                                        ? 'პაროლი უნდა შეიცავდეს მინიმუმ 8 სიმბოლოს'
                                        : null,
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _confirm,
                                obscureText: true,
                                decoration: const InputDecoration(
                                  labelText: 'გაიმეორე ახალი პაროლი',
                                  prefixIcon: Icon(Icons.lock_reset),
                                ),
                                validator: (value) =>
                                    value != _password.text
                                        ? 'პაროლები ერთმანეთს არ ემთხვევა'
                                        : null,
                              ),
                              if (_message != null) ...[
                                const SizedBox(height: 12),
                                Text(_message!, style: const TextStyle(color: _yellow)),
                              ],
                              const SizedBox(height: 18),
                              FilledButton(
                                onPressed: _busy ? null : _savePassword,
                                child: _busy
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      )
                                    : const Text('პაროლის შენახვა'),
                              ),
                            ],
                          ),
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
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

  Future<void> _sendPasswordReset() async {
    final email = _email.text.trim();
    if (!email.contains('@')) {
      setState(() => _message = 'პაროლის აღსადგენად ჯერ შეიყვანე სწორი ელფოსტა.');
      return;
    }

    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(
        email,
        redirectTo: 'ge.moonride.passenger://login-callback/',
      );
      if (mounted) {
        setState(() => _message =
            'პაროლის აღდგენის ინსტრუქცია გაიგზავნა ელფოსტაზე.');
      }
    } on AuthException catch (error) {
      if (mounted) setState(() => _message = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _message =
            'პაროლის აღდგენა ვერ შესრულდა. სცადე მოგვიანებით.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      if (AppConfig.googleServerClientId.isEmpty) {
        throw const AuthException('Google Sign-In კონფიგურაციას აკლია Google Web OAuth Client ID.');
      }
      final googleSignIn = GoogleSignIn(
        serverClientId: AppConfig.googleServerClientId,
        scopes: const ['email'],
      );
      final googleUser = await googleSignIn.signIn();
      if (googleUser == null) return;
      final googleAuth = await googleUser.authentication;
      final idToken = googleAuth.idToken;
      final accessToken = googleAuth.accessToken;
      if (idToken == null || accessToken == null) {
        throw const AuthException('Google ავტორიზაციის ტოკენები ვერ მივიღეთ.');
      }
      await Supabase.instance.client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );
    } on AuthException catch (error) {
      if (mounted) setState(() => _message = error.message);
    } catch (error) {
      if (mounted) setState(() => _message = 'Google ანგარიშის არჩევა ან შესვლა ვერ შესრულდა: $error');
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
                            if (!_register) ...[
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: _busy ? null : _sendPasswordReset,
                                  child: const Text('პაროლის აღდგენა'),
                                ),
                              ),
                            ],
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
                            const SizedBox(height: 8),
                            OutlinedButton.icon(
                              onPressed: _busy ? null : _signInWithGoogle,
                              icon: const Icon(Icons.g_mobiledata, size: 28),
                              label: const Text('Google ანგარიშით შესვლა'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: _silver,
                                side: BorderSide(color: Colors.white.withValues(alpha: 0.18)),
                                padding: const EdgeInsets.symmetric(vertical: 13),
                              ),
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
  final _pickupController = TextEditingController();
  final _destinationController = TextEditingController();
  final _stopController = TextEditingController();
  List<_PlaceResult> _pickupResults = [];
  bool _searchingPickup = false;
  String? _pickupError;
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
  double _walletBalance = 0;
  String _walletCurrency = 'GEL';
  List<Map<String, dynamic>> _walletTransactions = [];
  int _completedRideCount = 0;
  bool _loadingWallet = false;
  final _voucherController = TextEditingController();
  String _profileEmail = '';
  String _accountStatus = 'active';
  bool _savingProfile = false;
  String? _profileMessage;
  final _profileNameController = TextEditingController();
  final _profilePhoneController = TextEditingController();
  late final Stream<List<Map<String, dynamic>>> _ridesStream;

  @override
  void dispose() {
    _pickupController.dispose();
    _destinationController.dispose();
    _stopController.dispose();
    _profileNameController.dispose();
    _profilePhoneController.dispose();
    _voucherController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _ridesStream = Supabase.instance.client
        .from('go_rides')
        .stream(primaryKey: ['id'])
        .eq('passenger_id', widget.userId)
        .order('created_at', ascending: false)
        .limit(25);
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
      await _loadWalletSummary();
    } catch (_) {
      if (mounted) {
        setState(() => _tariffMessage = 'პროფილის ჩატვირთვა ვერ მოხერხდა.');
      }
    }
  }

  String get _loyaltyProgressLabel {
    final remaining = 10 - (_completedRideCount % 10);
    return remaining == 1
        ? 'შემდეგი მგზავრობა იქნება მე-10 — 25% ფასდაკლება'
        : '25% ფასდაკლებამდე დარჩა $remaining მგზავრობა';
  }

  Future<void> _loadWalletSummary({String? currencyCode}) async {
    if (_loadingWallet) return;
    setState(() => _loadingWallet = true);
    try {
      final currency = currencyCode ?? _currency;
      final client = Supabase.instance.client;
      final results = await Future.wait([
        client.from('go_wallet_accounts').select('balance,currency_code')
            .eq('user_id', widget.userId).eq('currency_code', currency).maybeSingle(),
        client.from('go_wallet_transactions').select('direction,transaction_type,amount,currency_code,note,created_at')
            .eq('user_id', widget.userId).order('created_at', ascending: false).limit(5),
        client.rpc('go_get_my_loyalty_progress'),
      ]);
      if (!mounted) return;
      final balance = results[0] as Map<String, dynamic>?;
      final loyalty = results[2] is Map
          ? Map<String, dynamic>.from(results[2] as Map)
          : <String, dynamic>{};
      setState(() {
        _walletCurrency = currency;
        _walletBalance = (balance?['balance'] as num?)?.toDouble() ?? 0;
        _walletTransactions = (results[1] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>().toList();
        _completedRideCount =
            (loyalty['completed_rides'] as num?)?.toInt() ?? 0;
      });
    } catch (_) {
      // Wallet panel is optional; booking is guarded by the server.
    } finally {
      if (mounted) setState(() => _loadingWallet = false);
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
        if (_pickupPlace == null && _pickupController.text.trim().isEmpty) {
          _pickupController.text = 'ჩემი მდებარეობა';
        }
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
      await _loadWalletSummary(currencyCode: _currency);
    } catch (error) {
      if (mounted) {
        setState(() => _tariffMessage =
            error.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _loadingTariffs = false);
    }
  }

  Future<void> _searchPickup() async {
    final query = _pickupController.text.trim();
    if (query.length < 3) {
      setState(() => _pickupError = 'შეიყვანე მინიმუმ 3 სიმბოლო.');
      return;
    }
    if (!AppConfig.hasTomtomKey) {
      setState(() => _pickupError = 'TomTom-ის გასაღები არ არის დაყენებული.');
      return;
    }
    setState(() {
      _searchingPickup = true;
      _pickupError = null;
      _pickupResults = [];
      _mapSelectionMode = 'pickup';
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
      final uri = Uri.https('api.tomtom.com', '/search/2/search/$query.json', params);
      final response = await http.get(uri).timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) {
        throw Exception('აყვანის მისამართის ძებნა ვერ შესრულდა (${response.statusCode}).');
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
        final poi = poiValue is Map ? Map<String, dynamic>.from(poiValue) : <String, dynamic>{};
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
        _pickupResults = places;
        if (places.isEmpty) _pickupError = 'მისამართი ვერ მოიძებნა.';
      });
    } catch (error) {
      if (mounted) {
        setState(() => _pickupError = error.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _searchingPickup = false);
    }
  }

  Future<void> _choosePickup(_PlaceResult place) async {
    setState(() {
      _pickupPlace = place;
      _pickupController.text = place.title;
      _pickupResults = [];
      _pickupError = null;
      _quoteId = null;
      _quoteOptions = [];
      _routeLines = [];
      _selectedCategoryCode = null;
      _quoteMessage = null;
      _mapSelectionMode = 'dropoff';
    });
    if (_destination != null && _cityId != null) await _requestFareQuote();
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

  Future<void> _chooseIntermediateStop(_PlaceResult place) async {
    setState(() {
      _selectedStops = [..._selectedStops, place];
      _stopController.clear();
      _stopResults = [];
      _stopError = null;
      _addingStop = false;
      _quoteOptions = [];
      _quoteId = null;
      _quoteDistanceKm = null;
      _quoteDurationMinutes = null;
      _routeLines = [];
      _selectedCategoryCode = null;
      _quoteMessage = null;
    });
    if (_destination != null && _position != null && _cityId != null) {
      await _requestFareQuote();
    }
  }

  Future<void> _removeIntermediateStop(int index) async {
    setState(() {
      _selectedStops.removeAt(index);
      _quoteOptions = [];
      _quoteId = null;
      _quoteDistanceKm = null;
      _quoteDurationMinutes = null;
      _routeLines = [];
      _selectedCategoryCode = null;
      _quoteMessage = null;
    });
    if (_destination != null && _position != null && _cityId != null) {
      await _requestFareQuote();
    }
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
    if (_destination == null || (_pickupPlace == null && _position == null)) return;
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
      _pickupController.text = previousDestination.title;
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
          _pickupController.text = place.title;
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
    final walletEnabled = canDispatch && _walletPaymentEnabled;
    await _loadWalletSummary(currencyCode: fare.currency);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: _panel,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(18, 18, 18, MediaQuery.of(sheetContext).viewInsets.bottom + 20),
          child: SingleChildScrollView(child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('გადახდის მეთოდი', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              Text(
                '${fare.categoryCode.replaceAll("_GO", "").replaceAll("_", " ")} · ${fare.totalFare.toStringAsFixed(2)} ${fare.currency}',
                style: const TextStyle(color: _yellow, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _voucherController,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'Promo Code / ვაუჩერი',
                  prefixIcon: Icon(Icons.local_offer_outlined),
                  helperText: 'ვაუჩერი გამოიყენება მხოლოდ ერთხელ თითო მგზავრზე.',
                ),
              ),
              const SizedBox(height: 8),
              ListTile(
                enabled: cashEnabled,
                leading: const Icon(Icons.payments_outlined, color: _yellow),
                title: const Text('ნაღდი ფული'),
                subtitle: Text(cashEnabled ? 'მძღოლთან ნაღდი ანგარიშსწორება' : 'ჯერ არ არის გააქტიურებული'),
                onTap: cashEnabled ? () {
                  Navigator.of(sheetContext).pop();
                  _createRide(fare, 'cash');
                } : null,
              ),
              ListTile(
                enabled: walletEnabled,
                leading: const Icon(Icons.account_balance_wallet_outlined, color: _yellow),
                title: const Text('MOONRIDE Wallet'),
                subtitle: Text(walletEnabled
                    ? 'ბალანსი: $_walletBalance $_walletCurrency'
                    : 'Wallet გადახდა გამორთულია ან მძღოლი არ არის ხელმისაწვდომი'),
                onTap: walletEnabled ? () {
                  Navigator.of(sheetContext).pop();
                  _createRide(fare, 'wallet');
                } : null,
              ),
              ListTile(
                enabled: false,
                leading: const Icon(Icons.credit_card, color: Colors.white54),
                title: const Text('TBC ბარათი'),
                subtitle: Text(_tbcPaymentEnabled
                    ? 'პროვაიდერის ანგარიშის/Webhook-ის დაყენება დარჩა'
                    : 'TBC ჯერ არ არის გააქტიურებული'),
              ),
              ListTile(
                enabled: false,
                leading: const Icon(Icons.account_balance, color: Colors.white54),
                title: const Text('Bank of Georgia ბარათი'),
                subtitle: Text(_bogPaymentEnabled
                    ? 'პროვაიდერის ანგარიშის/Webhook-ის დაყენება დარჩა'
                    : 'Bank of Georgia ჯერ არ არის გააქტიურებული'),
              ),
              const Divider(height: 20),
              Text(
                !canDispatch
                    ? 'შეკვეთა ვერ გაიგზავნება: ხელმისაწვდომი ონლაინ მძღოლები: $_availableDriversCount.'
                    : (!cashEnabled && !walletEnabled)
                        ? 'გადახდის ხელმისაწვდომი მეთოდი ჯერ არ არის გააქტიურებული.'
                        : 'ვაუჩერის კოდი მოწმდება შეკვეთის დადასტურებისას.',
                style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
              ),
              const SizedBox(height: 8),
              OutlinedButton(onPressed: () => Navigator.of(sheetContext).pop(), child: const Text('დახურვა')),
            ],
          )),
        ),
      ),
    );
  }

  Future<void> _createRide(_QuoteFare fare, String paymentMethod) async {
    final quoteId = _quoteId;
    if (quoteId == null || _bookingInProgress) return;
    final paymentAllowed = paymentMethod == 'cash'
        ? _cashPaymentEnabled
        : paymentMethod == 'wallet' && _walletPaymentEnabled;
    if (!_bookingEnabled || !paymentAllowed || _availableDriversCount < 1) {
      setState(() => _quoteMessage =
          'შეკვეთა ვერ გაიგზავნა: შეკვეთის სისტემა, გადახდა ან ონლაინ მძღოლი ხელმისაწვდომი არ არის.');
      return;
    }
    setState(() {
      _bookingInProgress = true;
      _quoteMessage = 'ტაქსის გამოძახება იგზავნება...';
    });
    try {
      final result = await Supabase.instance.client.rpc(
        'go_create_ride_from_quote_with_discounts',
        params: {
          'p_quote_id': quoteId,
          'p_category_code': fare.categoryCode,
          'p_payment_method': paymentMethod,
          'p_voucher_code': _voucherController.text.trim().isEmpty ? null : _voucherController.text.trim().toUpperCase(),
        },
      );
      final data = result is Map
          ? Map<String, dynamic>.from(result)
          : <String, dynamic>{};
      if (data['ride_id'] == null) {
        throw Exception('შეკვეთის სერვერმა ride_id არ დააბრუნა.');
      }
      _voucherController.clear();
      await _loadWalletSummary(currencyCode: fare.currency);
      if (!mounted) return;
      final discount = (data['discount_amount'] as num?)?.toDouble() ?? 0;
      final finalFare = (data['fare_amount'] as num?)?.toDouble() ?? fare.totalFare;
      setState(() {
        _quoteMessage = 'შეკვეთა შეიქმნა. საბოლოო ფასი: ' +
          finalFare.toStringAsFixed(2) + ' ' + fare.currency +
          (discount > 0 ? ' • ფასდაკლება: ' + discount.toStringAsFixed(2) : '') +
          ' • მძღოლებთან შეთავაზებები: ' + (data['offers_sent'] ?? 0).toString() + '.';
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
      appBar: _tab == 0
          ? null
          : AppBar(
              title: Row(
                children: [
                  const BrandMark(size: 34),
                  const SizedBox(width: 8),
                  const Text('MOONRIDE GO', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, letterSpacing: 1)),
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
          NavigationDestination(icon: Icon(Icons.map_outlined), selectedIcon: Icon(Icons.map, color: _yellow), label: 'მთავარი'),
          NavigationDestination(icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long, color: _yellow), label: 'შეკვეთები'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person, color: _yellow), label: 'პროფილი'),
        ],
      ),
    );
  }

  Widget _placeResultTile(_PlaceResult place, {required VoidCallback onTap}) {
    return ListTile(
      dense: true,
      visualDensity: VisualDensity.compact,
      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      leading: const Icon(Icons.location_on_outlined, color: _yellow),
      title: Text(place.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(place.address, maxLines: 1, overflow: TextOverflow.ellipsis),
      onTap: onTap,
    );
  }

  Widget _homeTab() {
    final pickupLabel = _pickupPlace?.title ??
        (_position == null ? 'ჩემი მდებარეობა' : 'ჩემი GPS მდებარეობა');
    final destinationLabel = _destination?.title ?? 'სად წავიდეთ?';

    return Stack(
      children: [
        Positioned.fill(
          child: TomTomMap(
            currentPosition: _position,
            pickup: _pickupPlace,
            destination: _destination,
            routeLines: _routeLines,
            onTap: _chooseMapPoint,
            selectionMode: _mapSelectionMode,
          ),
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const BrandMark(size: 34),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'გამარჯობა, $_fullName',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                shadows: [Shadow(color: Colors.black54, blurRadius: 8)],
                              ),
                            ),
                            const Text(
                              'სად წავიდეთ?',
                              style: TextStyle(color: Colors.white70, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        tooltip: 'ჩემი მდებარეობა',
                        onPressed: _loadingLocation ? null : _getLocation,
                        icon: const Icon(Icons.my_location, color: Colors.white),
                        style: IconButton.styleFrom(backgroundColor: _navy.withValues(alpha: 0.88)),
                      ),
                      IconButton(
                        tooltip: 'SOS / 112',
                        onPressed: _callEmergency,
                        icon: const Icon(Icons.sos, color: _yellow),
                        style: IconButton.styleFrom(backgroundColor: _navy.withValues(alpha: 0.88)),
                      ),
                    ],
                  ),
                  Card(
                    color: _panel.withValues(alpha: 0.97),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 25,
                                height: 25,
                                alignment: Alignment.center,
                                decoration: const BoxDecoration(color: Color(0xFF31C783), shape: BoxShape.circle),
                                child: const Text('A', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12)),
                              ),
                              const SizedBox(width: 9),
                              Expanded(
                                child: TextField(
                                  controller: _pickupController,
                                  textInputAction: TextInputAction.search,
                                  onTap: () => setState(() => _mapSelectionMode = 'pickup'),
                                  onSubmitted: (_) => _searchPickup(),
                                  decoration: const InputDecoration(
                                    filled: false,
                                    hintText: 'საიდან? ჩაწერე მისამართი',
                                    border: InputBorder.none,
                                    contentPadding: EdgeInsets.symmetric(vertical: 10),
                                  ),
                                ),
                              ),
                              IconButton(
                                tooltip: 'აყვანის მისამართის ძებნა',
                                onPressed: _searchingPickup ? null : _searchPickup,
                                icon: _searchingPickup
                                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                                    : const Icon(Icons.search),
                              ),
                              IconButton(
                                tooltip: 'A წერტილის რუკაზე მონიშვნა',
                                onPressed: () => setState(() => _mapSelectionMode = 'pickup'),
                                icon: const Icon(Icons.map_outlined, color: _yellow),
                              ),
                            ],
                          ),
                          const Divider(height: 1, color: Colors.white24),
                          Row(
                            children: [
                              Container(
                                width: 25,
                                height: 25,
                                alignment: Alignment.center,
                                decoration: const BoxDecoration(color: Color(0xFF168CFF), shape: BoxShape.circle),
                                child: const Text('B', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12)),
                              ),
                              const SizedBox(width: 9),
                              Expanded(
                                child: TextField(
                                  controller: _destinationController,
                                  textInputAction: TextInputAction.search,
                                  onTap: () => setState(() => _mapSelectionMode = 'dropoff'),
                                  onSubmitted: (_) => _searchDestination(),
                                  decoration: const InputDecoration(
                                    filled: false,
                                    hintText: 'სად წავიდეთ? ჩაწერე მისამართი',
                                    border: InputBorder.none,
                                    contentPadding: EdgeInsets.symmetric(vertical: 10),
                                  ),
                                ),
                              ),
                              IconButton(
                                tooltip: 'დანიშნულების ძებნა',
                                onPressed: _searchingDestination ? null : _searchDestination,
                                icon: _searchingDestination
                                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                                    : const Icon(Icons.search),
                              ),
                              IconButton(
                                tooltip: 'B წერტილის რუკაზე მონიშვნა',
                                onPressed: () => setState(() => _mapSelectionMode = 'dropoff'),
                                icon: const Icon(Icons.place_outlined, color: _yellow),
                              ),
                            ],
                          ),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton.icon(
                              onPressed: _destination == null || _position == null ? null : _swapRouteDirection,
                              icon: const Icon(Icons.swap_vert, size: 18),
                              label: const Text('მიმართულების შეცვლა'),
                            ),
                          ),
                          if (_resolvingMapPoint)
                            const LinearProgressIndicator(minHeight: 2, color: _yellow),
                          if (_pickupResults.isNotEmpty || _destinationResults.isNotEmpty || _pickupError != null || _destinationError != null)
                            const Divider(height: 1, color: Colors.white24),
                          if (_pickupError != null)
                            Padding(padding: const EdgeInsets.only(top: 6), child: Text(_pickupError!, style: const TextStyle(color: Color(0xFFFF8A8A), fontSize: 11))),
                          if (_destinationError != null)
                            Padding(padding: const EdgeInsets.only(top: 6), child: Text(_destinationError!, style: const TextStyle(color: Color(0xFFFF8A8A), fontSize: 11))),
                          if (_pickupResults.isNotEmpty)
                            ..._pickupResults.take(4).map((place) => _placeResultTile(place, onTap: () => _choosePickup(place))),
                          if (_destinationResults.isNotEmpty)
                            ..._destinationResults.take(4).map((place) => _placeResultTile(place, onTap: () => _chooseDestination(place))),
                          if (_addingStop) ...[
                            const Divider(height: 1, color: Colors.white24),
                            TextField(
                              controller: _stopController,
                              textInputAction: TextInputAction.search,
                              onSubmitted: (_) => _searchIntermediateStop(),
                              decoration: InputDecoration(
                                filled: false,
                                hintText: 'შუალედური გაჩერება',
                                border: InputBorder.none,
                                suffixIcon: IconButton(
                                  onPressed: _searchingStop ? null : _searchIntermediateStop,
                                  icon: const Icon(Icons.search),
                                ),
                              ),
                            ),
                            if (_stopError != null)
                              Text(_stopError!, style: const TextStyle(color: Color(0xFFFF8A8A), fontSize: 11)),
                            ..._stopResults.take(3).map((place) => _placeResultTile(place, onTap: () => _chooseIntermediateStop(place))),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          right: 14,
          bottom: _quoteOptions.isNotEmpty ? 340 : 245,
          child: FloatingActionButton.small(
            heroTag: 'moonride-map-center',
            backgroundColor: _panel,
            foregroundColor: _yellow,
            onPressed: _getLocation,
            child: const Icon(Icons.my_location),
          ),
        ),
        DraggableScrollableSheet(
          initialChildSize: _quoteOptions.isNotEmpty ? 0.46 : 0.22,
          minChildSize: 0.18,
          maxChildSize: 0.78,
          snap: true,
          snapSizes: const [0.22, 0.46, 0.78],
          builder: (context, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: _navy.withValues(alpha: 0.98),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 18, offset: Offset(0, -4))],
              ),
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  Center(
                    child: Container(width: 42, height: 4, decoration: BoxDecoration(color: Colors.white38, borderRadius: BorderRadius.circular(8))),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Expanded(child: Text('მგზავრობის დაგეგმვა', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900))),
                      TextButton.icon(
                        onPressed: () => setState(() {
                          _addingStop = !_addingStop;
                          _stopError = null;
                          _stopResults = [];
                        }),
                        icon: const Icon(Icons.add_location_alt_outlined, size: 18),
                        label: const Text('გაჩერება'),
                      ),
                    ],
                  ),
                  if (_selectedStops.isNotEmpty)
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: _selectedStops.asMap().entries.map((entry) => InputChip(
                        label: Text('გაჩერება ${entry.key + 1}', style: const TextStyle(fontSize: 11)),
                        onDeleted: () => _removeIntermediateStop(entry.key),
                        backgroundColor: _panelLight,
                        side: BorderSide.none,
                      )).toList(),
                    ),
                  if (_quoteDistanceKm != null && _quoteDurationMinutes != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(child: _routeMetric(Icons.route, '${_quoteDistanceKm!.toStringAsFixed(1)} კმ', 'მანძილი')),
                        const SizedBox(width: 8),
                        Expanded(child: _routeMetric(Icons.schedule, '${_quoteDurationMinutes!.round()} წთ', 'დრო')),
                        const SizedBox(width: 8),
                        Expanded(child: _routeMetric(Icons.flag_outlined, _cityName.isEmpty ? 'GO' : _cityName, 'ქალაქი')),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.local_taxi, color: _yellow, size: 17),
                        const SizedBox(width: 7),
                        Text(
                          'ახლომდებარე ონლაინ მძღოლები: $_availableDriversCount',
                          style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ] else ...[
                    Text(
                      'A: $pickupLabel  →  B: $destinationLabel',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    const SizedBox(height: 6),
                    Text(_locationMessage, style: const TextStyle(color: Colors.white54, fontSize: 11, height: 1.3)),
                    const SizedBox(height: 4),
                    Text('აირჩიე A და B მისამართი ძებნით ან პირდაპირ რუკაზე მონიშვნით. TomTom გამოთვლის გზას, დროს და ფასს. აქტიური ტარიფები: ${_tariffs.length}.', style: const TextStyle(color: Colors.white54, fontSize: 12, height: 1.35)),
                  ],
                  const SizedBox(height: 10),
                  if (_quoteOptions.isEmpty)
                    FilledButton.icon(
                      onPressed: _requestingQuote ? null : _requestFareQuote,
                      icon: _requestingQuote
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.route),
                      label: Text(_requestingQuote ? 'მარშრუტი ითვლება...' : 'მარშრუტისა და ფასის გამოთვლა'),
                      style: FilledButton.styleFrom(
                        backgroundColor: _yellow,
                        foregroundColor: _navy,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  if (_quoteOptions.isNotEmpty) ...[
                    const Text('აირჩიე ავტომობილის კატეგორია', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
                    const SizedBox(height: 8),
                    ..._quoteOptions.map((fare) {
                      final matchingTariffs = _tariffs.where((tariff) => tariff.code == fare.categoryCode);
                      final tariff = matchingTariffs.isEmpty ? null : matchingTariffs.first;
                      final label = tariff?.title ?? fare.categoryCode.replaceAll('_GO', '').replaceAll('_', ' ');
                      final seats = tariff?.seats ?? 4;
                      final selected = _selectedCategoryCode == fare.categoryCode;
                      return Card(
                        margin: const EdgeInsets.only(bottom: 7),
                        color: selected ? _panelLight : _panel,
                        child: ListTile(
                          leading: Icon(
                            fare.categoryCode.startsWith('PREMIUM') ? Icons.directions_car_filled
                                : fare.categoryCode.startsWith('XL') ? Icons.airport_shuttle
                                : Icons.local_taxi,
                            color: _yellow,
                          ),
                          title: Text(label, style: const TextStyle(fontWeight: FontWeight.w900)),
                          subtitle: Text('$seats ადგილი • ${fare.ratePerKm.toStringAsFixed(2)} ${fare.currency} / კმ'),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text('${fare.totalFare.toStringAsFixed(2)} ${fare.currency}', style: const TextStyle(color: _yellow, fontWeight: FontWeight.w900, fontSize: 16)),
                              Text(selected ? 'გადახდის არჩევა' : 'არჩევა', style: const TextStyle(color: Colors.white70, fontSize: 10)),
                            ],
                          ),
                          onTap: _selectingCategory ? null : () => _selectQuoteCategory(fare),
                        ),
                      );
                    }),
                  ],
                  if (_quoteMessage != null) ...[
                    const SizedBox(height: 8),
                    Text(_quoteMessage!, style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.4)),
                  ],
                  if (_tariffMessage.isNotEmpty && _quoteOptions.isEmpty) ...[
                    const SizedBox(height: 8),
                    Text(_tariffMessage, style: const TextStyle(color: Colors.white60, fontSize: 11)),
                  ],
                  if (_loadingTariffs)
                    const Padding(padding: EdgeInsets.all(8), child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _routeMetric(IconData icon, String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(color: _panel, borderRadius: BorderRadius.circular(12)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: _yellow, size: 16),
          const SizedBox(width: 5),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900)),
                Text(label, style: const TextStyle(color: Colors.white54, fontSize: 10)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _cancelRideByPassenger(String rideId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: _panel,
        title: const Text('შეკვეთის გაუქმება?'),
        content: const Text(
          'გსურს ტაქსის გამოძახების გაუქმება? გადაწყვეტილება სერვერზე გადამოწმდება.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('დაბრუნება'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(backgroundColor: _yellow, foregroundColor: _navy),
            child: const Text('გაუქმება'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await Supabase.instance.client.rpc(
        'go_update_ride_status',
        params: {
          'p_ride_id': rideId,
          'p_new_status': 'cancelled',
          'p_note': 'Cancelled by passenger from MoonrideGo',
        },
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('გაუქმების მოთხოვნა სერვერს გაეგზავნა.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('შეკვეთა ვერ გაუქმდა: ${error.toString().replaceFirst('Exception: ', '')}'),
          backgroundColor: Colors.red.shade800,
        ),
      );
    }
  }

  String _rideStatusLabel(String status) => switch (status) {
        'requested' => 'შეკვეთა მიღებულია',
        'dispatching' => 'მძღოლს ვეძებთ',
        'accepted' => 'მძღოლმა შეკვეთა მიიღო',
        'driver_arriving' => 'მძღოლი თქვენკენ მოდის',
        'arrived' => 'მძღოლი ადგილზეა',
        'in_progress' => 'მგზავრობა მიმდინარეობს',
        'completed' => 'მგზავრობა დასრულებულია',
        'cancelled' => 'შეკვეთა გაუქმებულია',
        'no_driver' => 'მძღოლი ვერ მოიძებნა',
        _ => status,
      };

  bool _isActiveRideStatus(String status) => const [
        'requested',
        'dispatching',
        'accepted',
        'driver_arriving',
        'arrived',
        'in_progress',
      ].contains(status);

  Widget _ordersTab() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _ridesStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator(color: _yellow));
        }
        if (snapshot.hasError) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(22),
              child: Text('შეკვეთების ისტორია ვერ ჩაიტვირთა. გადაამოწმე კავშირი და სცადე ხელახლა.'),
            ),
          );
        }
        final rows = snapshot.data ?? const <Map<String, dynamic>>[];
        if (rows.isEmpty) {
          return const Center(
            child: _InfoCard(message: 'შეკვეთები ჯერ არ გაქვს. პირველი ტაქსი მთავარი რუკიდან გამოიძახე.'),
          );
        }
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Padding(
              padding: EdgeInsets.only(bottom: 10),
              child: Text(
                'შეკვეთების ისტორია',
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
              ),
            ),
            ...rows.map((row) {
              final id = row['id'].toString();
              final status = (row['status'] ?? 'unknown').toString();
              final active = _isActiveRideStatus(status);
              final statusColor = active
                  ? const Color(0xFF4AA8FF)
                  : status == 'completed'
                      ? const Color(0xFF45D483)
                      : const Color(0xFF9AA9BA);
              final fare = row['fare_amount'];
              final fareLabel = fare is num
                  ? '${fare.toStringAsFixed(2)} ${row['currency_code'] ?? ''}'
                  : 'ფასი —';
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.local_taxi, color: _yellow),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'შეკვეთა #${id.substring(0, math.min(8, id.length)).toUpperCase()}',
                              style: const TextStyle(fontWeight: FontWeight.w900),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              _rideStatusLabel(status),
                              style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.w800),
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 20, color: Colors.white24),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.trip_origin, color: Color(0xFF45D483), size: 18),
                          const SizedBox(width: 8),
                          Expanded(child: Text((row['pickup_address'] ?? 'აყვანის ადგილი').toString())),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.location_on, color: _yellow, size: 18),
                          const SizedBox(width: 8),
                          Expanded(child: Text((row['dropoff_address'] ?? 'დანიშნულება').toString())),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              fareLabel,
                              style: const TextStyle(color: _yellow, fontWeight: FontWeight.w900, fontSize: 17),
                            ),
                          ),
                          Text(
                            (row['payment_method'] ?? '—').toString().toUpperCase(),
                            style: const TextStyle(color: Colors.white60, fontSize: 10, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                      if (active) ...[
                        const SizedBox(height: 8),
                        const Text(
                          'მიმდინარე შეკვეთა',
                          style: TextStyle(color: Colors.white60, fontSize: 11, height: 1.35),
                        ),
                      ],
                      if (status == 'requested' || status == 'dispatching') ...[
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () => _cancelRideByPassenger(id),
                            icon: const Icon(Icons.close),
                            label: const Text('შეკვეთის გაუქმება'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFFFF8A8A),
                              side: const BorderSide(color: Color(0x88FF8A8A)),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }),
          ],
        );
      },
    );
  }

  void _profileNotice(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: _panelLight),
    );
  }

  Widget _profileMenuTile({
    required IconData icon,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
    bool available = true,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      leading: Icon(icon, color: available ? _yellow : Colors.white38),
      title: Text(title, style: TextStyle(color: available ? Colors.white : Colors.white70)),
      subtitle: Text(subtitle, style: const TextStyle(color: Colors.white54, fontSize: 11)),
      trailing: Icon(
        available ? Icons.chevron_right : Icons.lock_outline,
        color: available ? _yellow : Colors.white24,
      ),
      onTap: onTap,
    );
  }

  Future<void> _showPaymentInfo() async {
    await _loadWalletSummary();
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: _panel,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('გადახდის მეთოდები', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
              const SizedBox(height: 12),
              const ListTile(
                leading: Icon(Icons.money, color: _yellow),
                title: Text('ნაღდი ფული'),
                subtitle: Text('აქტიურია'),
                trailing: Icon(Icons.check_circle, color: Colors.lightGreenAccent),
              ),
              ListTile(
                leading: const Icon(Icons.account_balance_wallet_outlined, color: _yellow),
                title: const Text('MOONRIDE Wallet'),
                subtitle: Text('ბალანსი: $_walletBalance $_walletCurrency • შევსება მხოლოდ MASTER ADMIN-ის მიერ'),
                trailing: const Icon(Icons.check_circle, color: Colors.lightGreenAccent),
              ),
              const ListTile(
                leading: Icon(Icons.credit_card, color: Colors.white38),
                title: Text('TBC ბარათი'),
                subtitle: Text('გადახდა ჩაირთვება TBC PSP-ის უსაფრთხო ინტეგრაციის შემდეგ'),
                trailing: Icon(Icons.lock_outline, color: Colors.white38),
              ),
              const ListTile(
                leading: Icon(Icons.credit_card, color: Colors.white38),
                title: Text('Bank of Georgia'),
                subtitle: Text('გადახდა ჩაირთვება BOG PSP-ის უსაფრთხო ინტეგრაციის შემდეგ'),
                trailing: Icon(Icons.lock_outline, color: Colors.white38),
              ),
              ListTile(
                leading: const Icon(Icons.card_giftcard, color: _yellow),
                title: const Text('ლოიალობა'),
                subtitle: Text(_loyaltyProgressLabel),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openStaffGo() async {
    if (_position == null || _cityId == null) {
      await _getLocation();
    }
    if (!mounted || _position == null || _cityId == null) {
      _profileNotice('ჯერ ჩართე GPS და დაადგინე მომსახურების ქალაქი.');
      return;
    }
    final pickup = _pickupPlace ?? _PlaceResult(
      title: 'ჩემი GPS მდებარეობა',
      address: 'GPS ${_position!.latitude.toStringAsFixed(5)}, ${_position!.longitude.toStringAsFixed(5)}',
      latitude: _position!.latitude,
      longitude: _position!.longitude,
    );
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => StaffGoPassengerPage(
        userId: widget.userId,
        cityId: _cityId!,
        currencyCode: _currency,
        pickupLatitude: pickup.latitude,
        pickupLongitude: pickup.longitude,
        pickupAddress: pickup.address,
        tomtomApiKey: AppConfig.tomtomApiKey,
      ),
    ));
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
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20),
                  ),
                ),
                const SizedBox(height: 4),
                const Center(
                  child: Text('მგზავრის ანგარიში', style: TextStyle(color: Colors.white54)),
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
                Text('ანგარიშის სტატუსი: ' + (_accountStatus == 'active' ? 'აქტიური' : 'შეჩერებული')),
                const SizedBox(height: 8),
                Text('ანგარიშის ID: ' + widget.userId, style: const TextStyle(color: Colors.white54, fontSize: 11)),
                const SizedBox(height: 6),
                Text('როლი: ' + _role),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Icon(Icons.account_balance_wallet_outlined, color: _yellow, size: 28),
                const SizedBox(width: 10),
                const Expanded(child: Text('MOONRIDE Wallet', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17))),
                Text(_walletBalance.toStringAsFixed(2) + ' ' + _walletCurrency,
                  style: const TextStyle(color: _yellow, fontWeight: FontWeight.w900, fontSize: 17)),
              ]),
              const SizedBox(height: 6),
              Text(_loadingWallet ? 'ბალანსი იტვირთება...' : 'ბალანსი ივსება მხოლოდ MASTER ADMIN-ის მიერ. Wallet განკუთვნილია მხოლოდ საკუთარი მგზავრობისთვის.',
                style: const TextStyle(color: Colors.white60, fontSize: 11)),
              const Divider(height: 20),
              Row(children: [
                const Icon(Icons.card_giftcard, color: _yellow),
                const SizedBox(width: 8),
                Expanded(child: Text(_loyaltyProgressLabel)),
                IconButton(onPressed: _loadWalletSummary, icon: const Icon(Icons.refresh, color: _yellow), tooltip: 'განახლება'),
              ]),
              if (_walletTransactions.isNotEmpty) ...[
                const Divider(height: 16),
                const Text('ბოლო ოპერაციები', style: TextStyle(fontWeight: FontWeight.bold)),
                for (final transaction in _walletTransactions)
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      transaction['direction'] == 'credit' ? Icons.south_west : Icons.north_east,
                      color: transaction['direction'] == 'credit' ? Colors.lightGreenAccent : _yellow,
                    ),
                    title: Text((transaction['transaction_type'] ?? 'Wallet ოპერაცია').toString()),
                    subtitle: Text((transaction['note'] ?? '').toString()),
                    trailing: Text(
                      (transaction['direction'] == 'credit' ? '+' : '-') +
                        (transaction['amount'] ?? '0').toString() + ' ' +
                        (transaction['currency_code'] ?? _walletCurrency).toString(),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
              ],
            ]),
          ),
        ),
        Card(
          child: Column(
            children: [
              _profileMenuTile(
                icon: Icons.person_outline,
                title: 'პროფილი',
                subtitle: 'პირადი მონაცემების ნახვა და განახლება',
                onTap: () => _profileNotice('პროფილის მონაცემები ზემოთ შეგიძლია შეცვალო.'),
              ),
              const Divider(height: 1),
              _profileMenuTile(
                icon: Icons.credit_card_outlined,
                title: 'გადახდა',
                subtitle: 'ნაღდი და MOONRIDE Wallet; TBC/BOG პროვაიდერის ინტეგრაცია დარჩა',
                onTap: _showPaymentInfo,
              ),
              const Divider(height: 1),
              _profileMenuTile(
                icon: Icons.help_outline,
                title: 'დახმარება',
                subtitle: 'მხარდაჭერის ბილეთების მოდული ჯერ არ არის ჩართული',
                onTap: () => _profileNotice('მხარდაჭერის სერვისი backend-ში დასამატებელია. გადაუდებელ შემთხვევაში გამოიყენე 112.'),
              ),
              const Divider(height: 1),
              _profileMenuTile(
                icon: Icons.shield_outlined,
                title: 'უსაფრთხოება',
                subtitle: 'SOS და გადაუდებელი ზარი — 112',
                onTap: _callEmergency,
              ),
              const Divider(height: 1),
              _profileMenuTile(
                icon: Icons.location_on_outlined,
                title: 'შენახული მისამართები',
                subtitle: 'მისამართების ანგარიშთან სინქრონიზაცია ჯერ დასამატებელია',
                available: false,
              ),
              const Divider(height: 1),
              _profileMenuTile(
                icon: Icons.settings_outlined,
                title: 'პარამეტრები',
                subtitle: 'ენისა და შეტყობინებების შენახვა ჯერ დასამატებელია',
                available: false,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Column(
            children: [
              _profileMenuTile(
                icon: Icons.local_offer_outlined,
                title: 'შეთავაზებები და პრომოკოდები',
                subtitle: 'ყოველ მე-10 დასრულებულ მგზავრობაზე 25% ფასდაკლება; Promo Code შეკვეთისას',
                onTap: _showPaymentInfo,
              ),
              const Divider(height: 1),
              _profileMenuTile(
                icon: Icons.restaurant,
                title: 'MOONRIDE FOOD',
                subtitle: 'დამატებითი სერვისი — სამომავლო მოდული',
                available: false,
              ),
              const Divider(height: 1),
              _profileMenuTile(
                icon: Icons.family_restroom,
                title: 'საოჯახო პროფილი',
                subtitle: 'ოჯახის ანგარიშების მართვა ჯერ დასამატებელია',
                available: false,
              ),
              const Divider(height: 1),
              _profileMenuTile(
                icon: Icons.groups_2_outlined,
                title: 'STAFF GO',
                subtitle: 'კორპორატიული მგზავრობა • ერთი მარშრუტი ან ცალკე ავტომობილები',
                onTap: _openStaffGo,
                available: true,
              ),
              const Divider(height: 1),
              _profileMenuTile(
                icon: Icons.business_outlined,
                title: 'ბიზნეს პროფილი',
                subtitle: 'ორგანიზაციის პროფილის მართვა STAFF GO-ში',
                available: false,
              ),
              const Divider(height: 1),
              _profileMenuTile(
                icon: Icons.directions_car_outlined,
                title: 'გახდი Moonride მძღოლი',
                subtitle: 'მძღოლის ცალკე აპლიკაცია: MoonrideDrive',
                onTap: () => _profileNotice('მძღოლის პროფილისთვის გამოიყენე MoonrideDrive აპლიკაცია.'),
              ),
            ],
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
  String _mapProvider = 'osm';

  @override
  void didUpdateWidget(covariant TomTomMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.routeLines.isNotEmpty && widget.routeLines != oldWidget.routeLines) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final points = widget.routeLines.expand((line) => line).toList();
        if (points.length >= 2) {
          _controller.fitCamera(
            CameraFit.coordinates(
              coordinates: points,
              padding: const EdgeInsets.all(48),
            ),
          );
        }
      });
    }
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
              urlTemplate: _mapProvider == 'tomtom'
                  ? 'https://api.tomtom.com/map/1/tile/basic/main/{z}/{x}/{y}.png?key=${AppConfig.tomtomApiKey}'
                  : _mapProvider == 'mapbox'
                      ? 'https://api.mapbox.com/styles/v1/mapbox/streets-v12/tiles/256/{z}/{x}/{y}?access_token=${AppConfig.mapboxAccessToken}'
                      : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              tileDimension: 256,
              maxNativeZoom: 19,
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
          right: 8,
          top: 8,
          child: PopupMenuButton<String>(
            tooltip: 'რუკის პროვაიდერი',
            initialValue: _mapProvider,
            onSelected: (value) => setState(() => _mapProvider = value),
            color: _panel,
            icon: const Icon(Icons.layers, color: Colors.white),
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'osm', child: Text('OpenStreetMap')),
              if (AppConfig.hasTomtomKey)
                const PopupMenuItem(value: 'tomtom', child: Text('TomTom')),
              if (AppConfig.mapboxAccessToken.isNotEmpty)
                const PopupMenuItem(value: 'mapbox', child: Text('Mapbox')),
            ],
          ),
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
                _mapProvider == 'tomtom'
                    ? '© TomTom'
                    : _mapProvider == 'mapbox'
                        ? '© Mapbox © OpenStreetMap'
                        : '© OpenStreetMap contributors',
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