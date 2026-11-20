import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';

const supabaseUrl = 'https://ewdkhekztkzugrmsknay.supabase.co';
const supabaseKey = 'sb_publishable_bshUTophPUo2GGLjJCpe7w_v_fLzyol';
const appRole = String.fromEnvironment('APP_ROLE', defaultValue: 'passenger');
const appTitle = String.fromEnvironment('APP_NAME', defaultValue: 'MoonrideGo');
const navy = Color(0xFF0A1425);
const yellow = Color(0xFFF4C542);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseKey);
  runApp(const MoonrideApp());
}

class MoonrideApp extends StatelessWidget {
  const MoonrideApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: appTitle,
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: navy,
      colorScheme: ColorScheme.fromSeed(seedColor: yellow, brightness: Brightness.dark),
      appBarTheme: const AppBarTheme(backgroundColor: navy, foregroundColor: Colors.white),
      navigationBarTheme: const NavigationBarThemeData(backgroundColor: Color(0xFF111F35)),
      cardTheme: CardThemeData(color: Color(0xFF14243B)),
    ),
    home: const AuthGate(),
  );
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});
  @override
  Widget build(BuildContext context) => StreamBuilder<AuthState>(
    stream: Supabase.instance.client.auth.onAuthStateChange,
    builder: (context, snapshot) {
      if (Supabase.instance.client.auth.currentSession == null) return const LoginPage();
      return const ProfileGate();
    },
  );
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}
class _LoginPageState extends State<LoginPage> {
  final email = TextEditingController();
  final password = TextEditingController();
  bool busy = false;
  String? error;
  Future<void> signIn() async {
    setState(() { busy = true; error = null; });
    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: email.text.trim(), password: password.text,
      );
    } catch (e) { setState(() => error = e.toString()); }
    finally { if (mounted) setState(() => busy = false); }
  }
  @override
  void dispose() { email.dispose(); password.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(child: SingleChildScrollView(padding: const EdgeInsets.all(24), child: Column(
      mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.local_taxi, size: 76, color: yellow),
        const SizedBox(height: 14),
        Text(appTitle, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6), Text('Secure sign in · $appRole'),
        const SizedBox(height: 24),
        TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder())),
        const SizedBox(height: 12),
        TextField(controller: password, obscureText: true, decoration: const InputDecoration(labelText: 'Password', border: OutlineInputBorder())),
        if (error != null) Padding(padding: const EdgeInsets.all(8), child: Text(error!, style: const TextStyle(color: Colors.redAccent))),
        const SizedBox(height: 12),
        SizedBox(width: double.infinity, child: FilledButton(onPressed: busy ? null : signIn, child: Text(busy ? 'Please wait…' : 'Sign in'))),
      ],
    ))),
  );
}

class ProfileGate extends StatefulWidget {
  const ProfileGate({super.key});
  @override
  State<ProfileGate> createState() => _ProfileGateState();
}
class _ProfileGateState extends State<ProfileGate> {
  bool loading = true;
  String? error;
  String displayName = '';
  @override
  void initState() { super.initState(); loadProfile(); }
  Future<void> loadProfile() async {
    try {
      final user = Supabase.instance.client.auth.currentUser!;
      final row = await Supabase.instance.client.from('profiles')
        .select('role,full_name').eq('id', user.id).single();
      displayName = (row['full_name'] ?? '') as String;
      if (row['role'] != appRole) error = 'This account role is ${row['role']}; this app requires $appRole.';
    } catch (e) { error = 'Could not verify profile: $e'; }
    if (mounted) setState(() => loading = false);
  }
  @override
  Widget build(BuildContext context) {
    if (loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (error != null) return Scaffold(body: Center(child: Padding(
      padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(error!, textAlign: TextAlign.center),
        const SizedBox(height: 16),
        FilledButton(onPressed: () => Supabase.instance.client.auth.signOut(), child: const Text('Sign out')),
      ]),
    )));
    return HomeShell(displayName: displayName);
  }
}

class HomeShell extends StatefulWidget {
  final String displayName;
  const HomeShell({super.key, required this.displayName});
  @override
  State<HomeShell> createState() => _HomeShellState();
}
class _HomeShellState extends State<HomeShell> {
  final db = Supabase.instance.client;
  int selectedTab = 0;
  bool online = false;
  Future<void> setDriverOnline(bool value) async {
    try {
      if (value) {
        var permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
          throw Exception('Location permission is required to go online.');
        }
        final pos = await Geolocator.getCurrentPosition();
        await db.rpc('go_update_driver_presence', params: {
          'p_latitude': pos.latitude, 'p_longitude': pos.longitude,
          'p_is_online': true, 'p_accuracy_m': pos.accuracy,
          'p_heading_deg': pos.heading, 'p_speed_mps': pos.speed,
        });
      } else {
        await db.rpc('go_update_driver_presence', params: {
          'p_latitude': null, 'p_longitude': null, 'p_is_online': false,
        });
      }
      if (mounted) setState(() => online = value);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not update status: $e')));
    }
  }
  String get roleLabel => appRole == 'master_admin' ? 'Master Admin' : appRole == 'driver' ? 'Driver' : 'Passenger';
  @override
  Widget build(BuildContext context) {
    final ridesStream = db.from('go_rides').stream(primaryKey: ['id']).order('created_at', ascending: false).limit(100);
    return Scaffold(
      appBar: AppBar(title: Text(appTitle), actions: [
        Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: Center(child: Text(roleLabel, style: const TextStyle(color: yellow)))),
        IconButton(onPressed: () => db.auth.signOut(), icon: const Icon(Icons.logout)),
      ]),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: ridesStream,
        builder: (context, snapshot) {
          final rides = snapshot.data ?? <Map<String, dynamic>>[];
          return RefreshIndicator(onRefresh: () async { setState(() {}); }, child: ListView(
            padding: const EdgeInsets.all(16), children: [
              Card(child: ListTile(
                leading: const CircleAvatar(backgroundColor: yellow, child: Icon(Icons.person, color: navy)),
                title: Text('Welcome ${widget.displayName.isEmpty ? roleLabel : widget.displayName}'),
                subtitle: const Text('MOONRIDE GO · connected account'),
              )),
              if (snapshot.hasError) Card(child: Padding(padding: const EdgeInsets.all(12), child: Text('Live feed error: ${snapshot.error}'))),
              if (snapshot.connectionState == ConnectionState.waiting) const LinearProgressIndicator(),
              if (appRole == 'passenger') ...[
                const Text('BOOK A RIDE', style: TextStyle(color: yellow, fontWeight: FontWeight.bold)),
                const Card(child: ListTile(leading: Icon(Icons.location_on), title: Text('Pickup and destination'), subtitle: Text('Ride booking screen — connection to quote/order flow pending'))),
                const Card(child: ListTile(leading: Icon(Icons.directions_car), title: Text('Choose your ride'), subtitle: Text('Vehicle categories and fare quote will appear here'))),
                const Text('MY TRIPS', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
              if (appRole == 'driver') ...[
                SwitchListTile(
                  value: online, onChanged: setDriverOnline,
                  title: const Text('Available for rides'),
                  subtitle: const Text('Online status uses GPS and driver-presence RPC'),
                  activeColor: yellow,
                ),
                const Text('TRIP OFFERS & ACTIVE RIDES', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
              if (appRole == 'master_admin') ...[
                const Text('LIVE OPERATIONS', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                GridView.count(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisCount: 2, childAspectRatio: 1.7, children: [
                  _MetricCard(label: 'Ride records', value: '${rides.length}', icon: Icons.local_taxi),
                  _MetricCard(label: 'Live feed', value: snapshot.hasError ? 'Error' : 'Connected', icon: Icons.sensors),
                ]),
                const Card(child: ListTile(leading: Icon(Icons.admin_panel_settings), title: Text('Admin controls'), subtitle: Text('Passenger, driver, pricing and account management screens are not yet connected'))),
              ],
              ...rides.map((ride) => Card(child: ListTile(
                leading: const Icon(Icons.route, color: yellow),
                title: Text('${ride['pickup_address'] ?? 'Pickup'} → ${ride['dropoff_address'] ?? 'Destination'}'),
                subtitle: Text('${ride['status'] ?? 'Status unavailable'} · ${ride['fare_amount'] ?? '—'} ${ride['currency_code'] ?? ''}'),
              ))),
              if (rides.isEmpty && !snapshot.hasError && snapshot.connectionState == ConnectionState.active)
                const Padding(padding: EdgeInsets.all(24), child: Text('No ride records to display yet.', textAlign: TextAlign.center)),
            ],
          ));
        },
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedTab,
        onDestinationSelected: (index) => setState(() => selectedTab = index),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.receipt_long), label: 'Orders'),
          NavigationDestination(icon: Icon(Icons.person_outline), label: 'Profile'),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label, value;
  final IconData icon;
  const _MetricCard({required this.label, required this.value, required this.icon});
  @override
  Widget build(BuildContext context) => Card(child: Padding(
    padding: const EdgeInsets.all(12), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(icon, color: yellow), Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
      Text(label, textAlign: TextAlign.center),
    ]),
  ));
}
