import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const moonrideSupabaseUrl = String.fromEnvironment(
  'SUPABASE_URL',
  defaultValue: 'https://ewdkhekztkzugrmsknay.supabase.co',
);
const moonridePublishableKey = String.fromEnvironment(
  'SUPABASE_PUBLISHABLE_KEY',
  defaultValue: 'sb_publishable_bshUTophPUo2GGLjJCpe7w_v_F_lzyol',
);

Future<void> initializeMoonride() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: moonrideSupabaseUrl,
    publishableKey: moonridePublishableKey,
  );
}

class MoonrideColors {
  static const navy = Color(0xFF071B34);
  static const navyDeep = Color(0xFF041226);
  static const panel = Color(0xFF102E52);
  static const panelLight = Color(0xFF173F6C);
  static const blue = Color(0xFF247FE5);
  static const blueBright = Color(0xFF43A9FF);
  static const ice = Color(0xFFEAF3FF);
  static const muted = Color(0xFFA9C5E4);
  static const success = Color(0xFF42C99A);
  static const warning = Color(0xFFFFC45C);
  static const danger = Color(0xFFFF7285);
}

ThemeData get moonrideTheme {
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: MoonrideColors.navy,
    colorScheme: ColorScheme.fromSeed(
      seedColor: MoonrideColors.blue,
      brightness: Brightness.dark,
      surface: MoonrideColors.panel,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: MoonrideColors.navy,
      foregroundColor: MoonrideColors.ice,
      elevation: 0,
      centerTitle: false,
    ),
    cardTheme: CardThemeData(
      color: MoonrideColors.panel,
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: MoonrideColors.panelLight,
      labelStyle: const TextStyle(color: MoonrideColors.muted),
      hintStyle: const TextStyle(color: MoonrideColors.muted),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: MoonrideColors.navyDeep,
      indicatorColor: MoonrideColors.blue.withValues(alpha: 0.28),
      labelTextStyle: const WidgetStatePropertyAll(
        TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: MoonrideColors.blue,
        foregroundColor: Colors.white,
        minimumSize: const Size(0, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: MoonrideColors.blueBright,
        side: const BorderSide(color: MoonrideColors.blueBright),
        minimumSize: const Size(0, 44),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
  );
}

class MoonrideBrandMark extends StatelessWidget {
  const MoonrideBrandMark({super.key, this.size = 52});
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
              color: MoonrideColors.ice,
              fontSize: size * 0.82,
              height: 1,
              fontWeight: FontWeight.w900,
            ),
          ),
          Positioned(
            top: 0,
            child: Icon(
              Icons.location_pin,
              color: MoonrideColors.blueBright,
              size: size * 0.43,
            ),
          ),
        ],
      ),
    );
  }
}

typedef MoonrideHomeBuilder = Widget Function(
  BuildContext context,
  User user,
  Map<String, dynamic> profile,
);

class MoonrideApp extends StatelessWidget {
  const MoonrideApp({
    super.key,
    required this.appName,
    required this.expectedRole,
    required this.homeBuilder,
  });

  final String appName;
  final String expectedRole;
  final MoonrideHomeBuilder homeBuilder;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: appName,
      debugShowCheckedModeBanner: false,
      theme: moonrideTheme,
      home: _MoonrideRoleGate(
        appName: appName,
        expectedRole: expectedRole,
        homeBuilder: homeBuilder,
      ),
    );
  }
}

class _MoonrideRoleGate extends StatefulWidget {
  const _MoonrideRoleGate({
    required this.appName,
    required this.expectedRole,
    required this.homeBuilder,
  });

  final String appName;
  final String expectedRole;
  final MoonrideHomeBuilder homeBuilder;

  @override
  State<_MoonrideRoleGate> createState() => _MoonrideRoleGateState();
}

class _MoonrideRoleGateState extends State<_MoonrideRoleGate> {
  StreamSubscription<AuthState>? _authSubscription;
  Map<String, dynamic>? _profile;
  bool _loading = true;
  String? _error;
  int _loadToken = 0;

  @override
  void initState() {
    super.initState();
    _authSubscription =
        Supabase.instance.client.auth.onAuthStateChange.listen((_) {
      _loadProfile();
    });
    _loadProfile();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final token = ++_loadToken;
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      if (!mounted) return;
      setState(() {
        _profile = null;
        _error = null;
        _loading = false;
      });
      return;
    }

    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final row = await Supabase.instance.client
          .from('profiles')
          .select('id,email,full_name,phone,role,account_status')
          .eq('id', user.id)
          .maybeSingle();
      if (!mounted || token != _loadToken) return;
      setState(() {
        _profile = row;
        _loading = false;
      });
    } catch (error) {
      if (!mounted || token != _loadToken) return;
      setState(() {
        _error = 'პროფილის შემოწმება ვერ მოხერხდა: $error';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return _GateMessage(
        appName: widget.appName,
        message: _error!,
        actionLabel: 'ხელახლა შემოწმება',
        onAction: _loadProfile,
      );
    }
    if (user == null) {
      return _MoonrideSignIn(appName: widget.appName);
    }
    if (_profile == null ||
        _profile!['role'] != widget.expectedRole ||
        _profile!['account_status'] == 'suspended') {
      return _GateMessage(
        appName: widget.appName,
        message: _profile == null
            ? 'ამ ანგარიშისთვის MOONRIDE პროფილი ვერ მოიძებნა.'
            : 'ამ აპში შესვლა დაშვებულია მხოლოდ ${widget.expectedRole} როლისთვის. '
                'თქვენი როლია: ${_profile!['role']}.',
        actionLabel: 'სხვა ანგარიშით შესვლა',
        onAction: () async => Supabase.instance.client.auth.signOut(),
      );
    }
    return widget.homeBuilder(context, user, _profile!);
  }
}

class _MoonrideSignIn extends StatefulWidget {
  const _MoonrideSignIn({required this.appName});
  final String appName;

  @override
  State<_MoonrideSignIn> createState() => _MoonrideSignInState();
}

class _MoonrideSignInState extends State<_MoonrideSignIn> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  bool _obscure = true;
  String? _message;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (_email.text.trim().isEmpty || _password.text.isEmpty) {
      setState(() => _message = 'შეიყვანე ელფოსტა და პაროლი.');
      return;
    }
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: _email.text.trim(),
        password: _password.text,
      );
    } on AuthException catch (error) {
      if (mounted) setState(() => _message = error.message);
    } catch (error) {
      if (mounted) setState(() => _message = 'შესვლა ვერ შესრულდა: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resetPassword() async {
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
      await Supabase.instance.client.auth.resetPasswordForEmail(email);
      if (mounted) {
        setState(() => _message = 'პაროლის აღდგენის ინსტრუქცია გაიგზავნა ელფოსტაზე.');
      }
    } on AuthException catch (error) {
      if (mounted) setState(() => _message = error.message);
    } catch (error) {
      if (mounted) setState(() => _message = 'შეცდომა: $error');
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
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Center(child: MoonrideBrandMark(size: 100)),
                      const SizedBox(height: 12),
                      Text(
                        widget.appName,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 25,
                          fontWeight: FontWeight.w900,
                          color: MoonrideColors.ice,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'შესვლა დაცული MOONRIDE ანგარიშით',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: MoonrideColors.muted),
                      ),
                      const SizedBox(height: 22),
                      TextField(
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.username],
                        decoration: const InputDecoration(
                          labelText: 'ელფოსტა',
                          prefixIcon: Icon(Icons.mail_outline),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _password,
                        obscureText: _obscure,
                        autofillHints: const [AutofillHints.password],
                        onSubmitted: (_) => _busy ? null : _signIn(),
                        decoration: InputDecoration(
                          labelText: 'პაროლი',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            onPressed: () =>
                                setState(() => _obscure = !_obscure),
                            icon: Icon(
                              _obscure ? Icons.visibility : Icons.visibility_off,
                            ),
                          ),
                        ),
                      ),
                      if (_message != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          _message!,
                          style: const TextStyle(color: MoonrideColors.warning),
                        ),
                      ],
                      const SizedBox(height: 18),
                      FilledButton(
                        onPressed: _busy ? null : _signIn,
                        child: _busy
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('შესვლა'),
                      ),
                      TextButton(
                        onPressed: _busy ? null : _resetPassword,
                        child: const Text('პაროლის აღდგენა'),
                      ),
                    ],
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

class _GateMessage extends StatelessWidget {
  const _GateMessage({
    required this.appName,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final String appName;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(appName)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.shield_outlined,
                      size: 48, color: MoonrideColors.blueBright),
                  const SizedBox(height: 14),
                  Text(message, textAlign: TextAlign.center),
                  const SizedBox(height: 18),
                  FilledButton(
                    onPressed: onAction,
                    child: Text(actionLabel),
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
