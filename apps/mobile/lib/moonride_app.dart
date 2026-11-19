import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum MoonrideAppRole { passenger, driver, masterAdmin }

Future<void> runMoonride(MoonrideAppRole role) async {
  WidgetsFlutterBinding.ensureInitialized();

  const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  const supabasePublishableKey = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');

  var backendConfigured = false;
  if (supabaseUrl.isNotEmpty && supabasePublishableKey.isNotEmpty) {
    await Supabase.initialize(
      url: supabaseUrl,
      publishableKey: supabasePublishableKey,
    );
    backendConfigured = true;
  }

  runApp(
    MoonrideApp(
      role: role,
      backendConfigured: backendConfigured,
    ),
  );
}

class MoonrideApp extends StatelessWidget {
  const MoonrideApp({
    required this.role,
    required this.backendConfigured,
    super.key,
  });

  final MoonrideAppRole role;
  final bool backendConfigured;

  String get appTitle => switch (role) {
        MoonrideAppRole.passenger => 'MOONRIDE GO',
        MoonrideAppRole.driver => 'MOONRIDE GO Driver',
        MoonrideAppRole.masterAdmin => 'MOONRIDE GO MASTER ADMIN',
      };

  @override
  Widget build(BuildContext context) {
    const navy = Color(0xFF07172B);
    const blue = Color(0xFF102F52);
    const yellow = Color(0xFFFFC928);

    final colorScheme = ColorScheme.fromSeed(
      seedColor: yellow,
      brightness: Brightness.dark,
      surface: const Color(0xFF102238),
    );

    return MaterialApp(
      title: appTitle,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: colorScheme,
        scaffoldBackgroundColor: Colors.transparent,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: false,
        ),
        navigationBarTheme: const NavigationBarThemeData(
          backgroundColor: Color(0xFF07172B),
          indicatorColor: Color(0xFF25476B),
          labelTextStyle: WidgetStatePropertyAll(
            TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        cardTheme: CardThemeData(
          color: const Color(0xE6102A46),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: const BorderSide(color: Color(0x334D83B8)),
          ),
        ),
      ),
      home: MoonrideShell(
        role: role,
        title: appTitle,
        backendConfigured: backendConfigured,
        backgroundStart: navy,
        backgroundEnd: blue,
      ),
    );
  }
}

class MoonrideShell extends StatefulWidget {
  const MoonrideShell({
    required this.role,
    required this.title,
    required this.backendConfigured,
    required this.backgroundStart,
    required this.backgroundEnd,
    super.key,
  });

  final MoonrideAppRole role;
  final String title;
  final bool backendConfigured;
  final Color backgroundStart;
  final Color backgroundEnd;

  @override
  State<MoonrideShell> createState() => _MoonrideShellState();
}

class _MoonrideShellState extends State<MoonrideShell> {
  int selectedIndex = 0;

  List<String> get _labels => switch (widget.role) {
        MoonrideAppRole.passenger => ['მთავარი', 'შეკვეთები', 'პროფილი'],
        MoonrideAppRole.driver => ['მთავარი', 'შეკვეთები', 'პროფილი'],
        MoonrideAppRole.masterAdmin => ['Dashboard', 'შეკვეთები', 'მართვა'],
      };

  List<IconData> get _icons => switch (widget.role) {
        MoonrideAppRole.passenger => [
            Icons.home_rounded,
            Icons.receipt_long_rounded,
            Icons.person_rounded,
          ],
        MoonrideAppRole.driver => [
            Icons.home_work_rounded,
            Icons.directions_car_rounded,
            Icons.person_rounded,
          ],
        MoonrideAppRole.masterAdmin => [
            Icons.dashboard_rounded,
            Icons.receipt_long_rounded,
            Icons.settings_rounded,
          ],
      };

  @override
  Widget build(BuildContext context) {
    final pages = [
      _HomePage(
        role: widget.role,
        title: widget.title,
        backendConfigured: widget.backendConfigured,
      ),
      _NotConnectedPage(
        title: _labels[1],
        detail: 'ეს განყოფილება ჩაირთვება შესაბამისი სერვერული პროცესის დასრულების შემდეგ.',
      ),
      _NotConnectedPage(
        title: _labels[2],
        detail: 'პროფილისა და მართვის მონაცემები ჩაიტვირთება ავტორიზაციის და როლების შემოწმების შემდეგ.',
      ),
    ];

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [widget.backgroundEnd, widget.backgroundStart],
          stops: const [0, 1],
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: IndexedStack(
            index: selectedIndex,
            children: pages,
          ),
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: selectedIndex,
          onDestinationSelected: (value) {
            setState(() => selectedIndex = value);
          },
          destinations: List.generate(
            _labels.length,
            (index) => NavigationDestination(
              icon: Icon(_icons[index]),
              label: _labels[index],
            ),
          ),
        ),
      ),
    );
  }
}

class _HomePage extends StatelessWidget {
  const _HomePage({
    required this.role,
    required this.title,
    required this.backendConfigured,
  });

  final MoonrideAppRole role;
  final String title;
  final bool backendConfigured;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          pinned: true,
          title: Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
            ),
          ),
          actions: [
            if (role == MoonrideAppRole.passenger)
              const IconButton(
                tooltip: 'SOS / 112',
                onPressed: null,
                icon: Icon(Icons.sos_rounded),
              ),
            const SizedBox(width: 8),
          ],
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              _ConnectionStatus(connected: backendConfigured),
              const SizedBox(height: 16),
              if (role == MoonrideAppRole.passenger)
                const _PassengerStarter()
              else if (role == MoonrideAppRole.driver)
                const _DriverStarter()
              else
                const _AdminStarter(),
              const SizedBox(height: 16),
              const _ReadinessNotice(),
            ]),
          ),
        ),
      ],
    );
  }
}

class _ConnectionStatus extends StatelessWidget {
  const _ConnectionStatus({required this.connected});

  final bool connected;

  @override
  Widget build(BuildContext context) {
    final text = connected
        ? 'Supabase კონფიგურაცია მიღებულია'
        : 'სერვერული კავშირი ჯერ არ არის კონფიგურირებული';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(
              connected ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
              color: connected ? Colors.lightGreenAccent : Colors.orangeAccent,
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(text)),
          ],
        ),
      ),
    );
  }
}

class _PassengerStarter extends StatelessWidget {
  const _PassengerStarter();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'გამარჯობა!',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          'სად მივდივართ?',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 14),
        const _InputPreview(
          icon: Icons.my_location_rounded,
          label: 'საიდან — GPS მდებარეობა',
        ),
        const SizedBox(height: 10),
        const _InputPreview(
          icon: Icons.location_on_rounded,
          label: 'სად მივდივართ?',
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: null,
          icon: const Icon(Icons.add_rounded),
          label: const Text('გაჩერების დამატება'),
        ),
        const SizedBox(height: 14),
        const _FeatureCard(
          icon: Icons.map_rounded,
          title: '2GIS რუკა',
          detail: 'რუკა ჩაირთვება 2GIS-ის აპლიკაციის გასაღების დაყენებისა და SDK-ის ინტეგრაციის შემდეგ.',
        ),
        const SizedBox(height: 10),
        const _FeatureCard(
          icon: Icons.local_taxi_rounded,
          title: 'ავტომობილის კატეგორიები',
          detail: 'კატეგორიები და ფასები ჩაიტვირთება მოქმედი Supabase GO ტარიფიდან; აპში ფასები ფიქსირებულად არ ჩაიწერება.',
        ),
        const SizedBox(height: 10),
        const _FeatureCard(
          icon: Icons.payments_rounded,
          title: 'გადახდა',
          detail: 'საბოლოო არჩევანი: ნაღდი ან უსაფრთხო tokenized ბარათი. Wallet GO არ გამოიყენება.',
        ),
      ],
    );
  }
}

class _DriverStarter extends StatelessWidget {
  const _DriverStarter();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('მძღოლის სამუშაო სივრცე', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
        SizedBox(height: 14),
        _FeatureCard(
          icon: Icons.toggle_on_rounded,
          title: 'ONLINE / OFFLINE',
          detail: 'ონლაინ სტატუსი ჩაირთვება ავტორიზაციის, დამტკიცებული მძღოლის პროფილისა და GPS ნებართვების შემდეგ.',
        ),
        SizedBox(height: 10),
        _FeatureCard(
          icon: Icons.notifications_active_rounded,
          title: 'შეკვეთების შეთავაზებები',
          detail: 'შეთავაზების მიღება და ავტომატური განაწილება ჩაირთვება სერვერული dispatch პროცესის დასრულების შემდეგ.',
        ),
        SizedBox(height: 10),
        _FeatureCard(
          icon: Icons.account_balance_wallet_rounded,
          title: 'შემოსავალი და ანგარიშსწორება',
          detail: 'ფინანსური ინფორმაცია ჩაიტვირთება მხოლოდ სერვერზე დადასტურებული შესრულებული შეკვეთებიდან.',
        ),
      ],
    );
  }
}

class _AdminStarter extends StatelessWidget {
  const _AdminStarter();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('MASTER ADMIN', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
        SizedBox(height: 14),
        _FeatureCard(
          icon: Icons.analytics_rounded,
          title: 'Dashboard',
          detail: 'მაჩვენებლები უნდა ჩაიტვირთოს რეალური მონაცემებიდან და არა სატესტო რიცხვებიდან.',
        ),
        SizedBox(height: 10),
        _FeatureCard(
          icon: Icons.people_alt_rounded,
          title: 'Passengers / Drivers',
          detail: 'პროფილები, ძებნა, სტატუსები და დოკუმენტები გამოჩნდება მხოლოდ Master Admin-ის სერვერული უფლებების დადასტურების შემდეგ.',
        ),
        SizedBox(height: 10),
        _FeatureCard(
          icon: Icons.map_rounded,
          title: 'Live Map',
          detail: '2GIS MapGL-ზე გამოჩნდება მხოლოდ ონლაინ მძღოლების მიმდინარე მდებარეობა.',
        ),
      ],
    );
  }
}

class _InputPreview extends StatelessWidget {
  const _InputPreview({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFFFFC928)),
            const SizedBox(width: 12),
            Expanded(child: Text(label)),
          ],
        ),
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.detail,
  });

  final IconData icon;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: const Color(0xFFFFC928), size: 25),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  Text(
                    detail,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white70,
                          height: 1.35,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReadinessNotice extends StatelessWidget {
  const _ReadinessNotice();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          'ეს არის საწყისი Flutter shell და ვიზუალური ფონის საფუძველი — არა დასრულებული სატაქსო აპი. რეალური შეკვეთები, რუკა, ავტორიზაცია, გადახდები და ადმინისტრირება ჩაირთვება მხოლოდ შესაბამისი backend/API ტესტების გავლის შემდეგ.',
          style: TextStyle(color: Colors.white70, height: 1.4),
        ),
      ),
    );
  }
}

class _NotConnectedPage extends StatelessWidget {
  const _NotConnectedPage({
    required this.title,
    required this.detail,
  });

  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: _FeatureCard(
          icon: Icons.construction_rounded,
          title: title,
          detail: detail,
        ),
      ),
    );
  }
}
