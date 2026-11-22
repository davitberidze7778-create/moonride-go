import 'package:flutter/material.dart';
import 'package:moonride_core/moonride_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  await initializeMoonride();
  runApp(const MoonrideAdminApp());
}

class MoonrideAdminApp extends StatelessWidget {
  const MoonrideAdminApp({super.key});
  @override
  Widget build(BuildContext context) => MoonrideApp(
    appName: 'moonrideAdmin',
    expectedRole: 'master_admin',
    homeBuilder: (context, user, profile) => AdminHome(user: user, profile: profile),
  );
}

class AdminHome extends StatefulWidget {
  const AdminHome({super.key, required this.user, required this.profile});
  final User user;
  final Map<String, dynamic> profile;
  @override
  State<AdminHome> createState() => _AdminHomeState();
}

class _AdminHomeState extends State<AdminHome> {
  final _db = Supabase.instance.client;
  int _tab = 0;
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _passengers = [];
  List<Map<String, dynamic>> _drivers = [];
  List<Map<String, dynamic>> _vehicles = [];
  List<Map<String, dynamic>> _rides = [];
  List<Map<String, dynamic>> _flags = [];
  List<Map<String, dynamic>> _plans = [];
  List<Map<String, dynamic>> _rates = [];
  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _online = [];
  final _passengerSearch = TextEditingController();
  final _driverSearch = TextEditingController();
  String _passengerFilter = 'all';
  String _driverFilter = 'all';

  List<Map<String, dynamic>> _asMaps(dynamic value) =>
      (value as List<dynamic>? ?? const []).whereType<Map<String, dynamic>>().toList();

  @override
  void initState() { super.initState(); _load(); }

  @override
  void dispose() { _passengerSearch.dispose(); _driverSearch.dispose(); super.dispose(); }

  Future<void> _load() async {
    if (mounted) setState(() { _loading = true; _error = null; });
    try {
      final r = await Future.wait([
        _db.from('profiles').select('id,email,full_name,phone,role,account_status,created_at').eq('role', 'passenger').order('created_at', ascending: false).limit(1000),
        _db.from('driver_profiles').select('*').order('created_at', ascending: false).limit(1000),
        _db.from('vehicles').select('*').order('created_at', ascending: false).limit(1000),
        _db.from('go_rides').select('*').order('requested_at', ascending: false).limit(200),
        _db.from('go_app_feature_flags').select('*').order('feature_group').order('label'),
        _db.from('go_tariff_plans').select('*').order('effective_from', ascending: false),
        _db.from('go_tariff_category_rates').select('*'),
        _db.from('vehicle_categories').select('id,code,name,is_active'),
        _db.rpc('go_get_online_driver_map'),
      ]);
      if (!mounted) return;
      setState(() {
        _passengers = _asMaps(r[0]);
        _drivers = _asMaps(r[1]);
        _vehicles = _asMaps(r[2]);
        _rides = _asMaps(r[3]);
        _flags = _asMaps(r[4]);
        _plans = _asMaps(r[5]);
        _rates = _asMaps(r[6]);
        _categories = _asMaps(r[7]);
        _online = _asMaps(r[8]);
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  void _message(String text, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(text),
      backgroundColor: error ? MoonrideColors.danger : MoonrideColors.panelLight,
    ));
  }

  Future<void> _setPassengerStatus(Map<String, dynamic> row) async {
    final current = row['account_status'] ?? 'active';
    final next = current == 'suspended' ? 'active' : 'suspended';
    try {
      await _db.rpc('go_admin_set_account_status', params: {
        'p_user_id': row['id'],
        'p_status': next,
        'p_reason': 'Updated by MOONRIDE master admin app',
      });
      _message(next == 'suspended' ? 'მგზავრის ანგარიში შეჩერდა.' : 'მგზავრის ანგარიში აღდგა.');
      await _load();
    } catch (e) {
      _message('ანგარიშის სტატუსი ვერ შეიცვალა: ' + e.toString(), error: true);
    }
  }

  Future<void> _reviewDriver(Map<String, dynamic> row, String status) async {
    try {
      await _db.rpc('go_admin_review_driver', params: {
        'p_driver_user_id': row['user_id'],
        'p_status': status,
        'p_reason': 'Reviewed by MOONRIDE master admin app',
      });
      _message('მძღოლის სტატუსი შეიცვალა: ' + status);
      await _load();
    } catch (e) {
      _message('მძღოლის სტატუსი ვერ შეიცვალა: ' + e.toString(), error: true);
    }
  }

  Future<void> _reviewVehicle(Map<String, dynamic> row, String status, String category) async {
    try {
      await _db.rpc('go_admin_review_vehicle', params: {
        'p_vehicle_id': row['id'],
        'p_status': status,
        'p_category_code': category,
        'p_reason': 'Reviewed by MOONRIDE master admin app',
      });
      _message('ავტომობილის სტატუსი განახლდა.');
      await _load();
    } catch (e) {
      _message('ავტომობილის შემოწმება ვერ შესრულდა: ' + e.toString(), error: true);
    }
  }

  Future<void> _cancelRide(Map<String, dynamic> row) async {
    try {
      await _db.rpc('go_update_ride_status', params: {
        'p_ride_id': row['id'],
        'p_new_status': 'cancelled',
        'p_note': 'Cancelled by MASTER ADMIN',
      });
      _message('შეკვეთა გაუქმდა.');
      await _load();
    } catch (e) {
      _message('შეკვეთა ვერ გაუქმდა: ' + e.toString(), error: true);
    }
  }

  Future<void> _toggleFlag(Map<String, dynamic> row, bool enabled) async {
    try {
      await _db.from('go_app_feature_flags').update({
        'is_enabled': enabled,
        'updated_by': widget.user.id,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('feature_key', row['feature_key']);
      _message(enabled ? 'ფუნქცია ჩაირთო.' : 'ფუნქცია გამოირთო.');
      await _load();
    } catch (e) {
      _message('ფუნქციის შეცვლა ვერ შესრულდა: ' + e.toString(), error: true);
    }
  }

  Future<void> _signOut() async => _db.auth.signOut();

  @override
  Widget build(BuildContext context) {
    final pages = [_dashboardPage(), _passengersPage(), _driversPage(), _ridesPage(), _settingsPage()];
    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          const MoonrideBrandMark(size: 36),
          const SizedBox(width: 8),
          const Text('moonrideAdmin', style: TextStyle(fontWeight: FontWeight.w800)),
        ]),
        actions: [
          IconButton(onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh)),
          IconButton(onPressed: _signOut, icon: const Icon(Icons.logout)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _errorPage()
              : IndexedStack(index: _tab, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (value) => setState(() => _tab = value),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'მთავარი'),
          NavigationDestination(icon: Icon(Icons.people_outline), selectedIcon: Icon(Icons.people), label: 'მგზავრები'),
          NavigationDestination(icon: Icon(Icons.directions_car_outlined), selectedIcon: Icon(Icons.directions_car), label: 'მძღოლები'),
          NavigationDestination(icon: Icon(Icons.route_outlined), selectedIcon: Icon(Icons.route), label: 'შეკვეთები'),
          NavigationDestination(icon: Icon(Icons.tune_outlined), selectedIcon: Icon(Icons.tune), label: 'მართვა'),
        ],
      ),
    );
  }

  Widget _errorPage() => Center(child: Padding(
    padding: const EdgeInsets.all(24),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.cloud_off, size: 44, color: MoonrideColors.warning),
      const SizedBox(height: 12),
      Text(_error!, textAlign: TextAlign.center),
      const SizedBox(height: 12),
      FilledButton(onPressed: _load, child: const Text('ხელახლა ცდა')),
    ]),
  ));

  Widget _heading(String title, {String? subtitle}) => Padding(
    padding: const EdgeInsets.fromLTRB(2, 18, 2, 8),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
      if (subtitle != null) Text(subtitle, style: const TextStyle(fontSize: 11, color: MoonrideColors.muted)),
    ]),
  );

  Widget _dashboardPage() {
    final active = _rides.where((r) => ['requested', 'dispatching', 'accepted', 'driver_arriving', 'arrived', 'in_progress'].contains(r['status'])).length;
    final pendingDrivers = _drivers.where((d) => d['approval_status'] == 'pending').length;
    final pendingVehicles = _vehicles.where((v) => v['approval_status'] == 'pending').length;
    final activePlans = _plans.where((p) => p['is_active'] == true).length;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(padding: const EdgeInsets.all(16), children: [
        Card(child: Padding(
          padding: const EdgeInsets.all(17),
          child: Row(children: [
            const MoonrideBrandMark(size: 52),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('MASTER ADMIN', style: TextStyle(color: MoonrideColors.blueBright, fontSize: 11, letterSpacing: 1.2)),
              Text((widget.profile['full_name'] ?? 'მართვის ცენტრი').toString(), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
              const Text('MOONRIDE GO • Classic Blue', style: TextStyle(color: MoonrideColors.muted, fontSize: 11)),
            ])),
          ]),
        )),
        _heading('ოპერაციების მიმოხილვა', subtitle: 'მონაცემები Supabase-ის მიმდინარე წაკითხვიდან'),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 9,
          crossAxisSpacing: 9,
          childAspectRatio: 1.65,
          children: [
            _metric('მგზავრები', _passengers.length, Icons.people_outline),
            _metric('მძღოლები', _drivers.length, Icons.directions_car_outlined),
            _metric('აქტიური შეკვეთები', active, Icons.route_outlined),
            _metric('ონლაინ მძღოლები', _online.length, Icons.gps_fixed),
            _metric('მძღოლის განაცხადები', pendingDrivers, Icons.assignment_ind_outlined),
            _metric('მანქანის განაცხადები', pendingVehicles, Icons.car_repair),
          ],
        ),
        const SizedBox(height: 5),
        Card(child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.payments_outlined, color: MoonrideColors.blueBright),
              const SizedBox(width: 9),
              const Expanded(child: Text('ტარიფები და სისტემის მდგომარეობა', style: TextStyle(fontWeight: FontWeight.bold))),
              _Badge(text: '$activePlans აქტიური გეგმა'),
            ]),
            const SizedBox(height: 8),
            Text('მოქმედი ტარიფის გეგმები: ' + activePlans.toString(), style: const TextStyle(color: MoonrideColors.muted)),
            Text('ფუნქციის კონტროლი: ' + _flags.length.toString() + ' ჩანაწერი', style: const TextStyle(color: MoonrideColors.muted)),
          ]),
        )),
        _heading('ბოლო შეკვეთები'),
        if (_rides.isEmpty) const _InfoCard(text: 'შეკვეთები ჯერ არ არის.'),
        ..._rides.take(5).map(_rideCard),
        const Padding(
          padding: EdgeInsets.only(top: 12),
          child: Text('შენიშვნა: ეკრანზე ნაჩვენებია ბოლო წაკითხული ჩანაწერები; ფინანსური ბრუნვა არ გამოითვლება, რადგან გადახდის ledger ჯერ არ არის დაკავშირებული.',
            style: TextStyle(fontSize: 11, color: MoonrideColors.muted)),
        ),
      ]),
    );
  }

  Widget _metric(String title, int value, IconData icon) => Card(
    child: Padding(
      padding: const EdgeInsets.all(13),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Icon(icon, color: MoonrideColors.blueBright),
        Text(value.toString(), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
        Text(title, style: const TextStyle(fontSize: 11, color: MoonrideColors.muted)),
      ]),
    ),
  );

  Widget _passengersPage() {
    final q = _passengerSearch.text.trim().toLowerCase();
    final rows = _passengers.where((p) {
      final matches = [p['full_name'], p['email'], p['phone']]
          .any((v) => (v ?? '').toString().toLowerCase().contains(q));
      final status = p['account_status'] ?? 'active';
      return matches && (_passengerFilter == 'all' || status == _passengerFilter);
    }).toList();
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 2),
        child: TextField(
          controller: _passengerSearch,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(prefixIcon: Icon(Icons.search), labelText: 'მგზავრის ძებნა სახელით, ელფოსტით ან ტელეფონით'),
        ),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'all', label: Text('ყველა')),
            ButtonSegment(value: 'active', label: Text('აქტიური')),
            ButtonSegment(value: 'suspended', label: Text('შეჩერებული')),
          ],
          selected: {_passengerFilter},
          onSelectionChanged: (v) => setState(() => _passengerFilter = v.first),
        ),
      ),
      Expanded(child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: rows.length,
        itemBuilder: (context, index) {
          final row = rows[index];
          final suspended = row['account_status'] == 'suspended';
          return Card(child: Padding(
            padding: const EdgeInsets.all(13),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Icon(Icons.person_outline, color: MoonrideColors.blueBright),
                const SizedBox(width: 8),
                Expanded(child: Text((row['full_name'] ?? 'სახელი უცნობია').toString(), style: const TextStyle(fontWeight: FontWeight.w800))),
                _Badge(text: suspended ? 'suspended' : 'active'),
              ]),
              Text((row['email'] ?? '—').toString(), style: const TextStyle(color: MoonrideColors.muted, fontSize: 12)),
              Text((row['phone'] ?? '—').toString(), style: const TextStyle(color: MoonrideColors.muted, fontSize: 12)),
              const SizedBox(height: 9),
              Align(alignment: Alignment.centerRight, child: OutlinedButton(
                onPressed: () => _setPassengerStatus(row),
                child: Text(suspended ? 'ანგარიშის აღდგენა' : 'ანგარიშის შეჩერება'),
              )),
            ]),
          ));
        },
      )),
    ]);
  }

  Widget _driversPage() {
    final q = _driverSearch.text.trim().toLowerCase();
    final rows = _drivers.where((d) {
      final name = (d['legal_first_name'] ?? '').toString() + ' ' + (d['legal_last_name'] ?? '').toString();
      final matches = name.toLowerCase().contains(q) || d['user_id'].toString().toLowerCase().contains(q);
      final status = (d['approval_status'] ?? 'pending').toString();
      return matches && (_driverFilter == 'all' || status == _driverFilter);
    }).toList();
    final pendingVehicles = _vehicles.where((v) => v['approval_status'] == 'pending').toList();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TextField(controller: _driverSearch, onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(prefixIcon: Icon(Icons.search), labelText: 'მძღოლის ძებნა')),
        const SizedBox(height: 8),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'all', label: Text('ყველა')),
            ButtonSegment(value: 'pending', label: Text('მოლოდინში')),
            ButtonSegment(value: 'approved', label: Text('დამტკიცებული')),
          ],
          selected: {_driverFilter},
          onSelectionChanged: (v) => setState(() => _driverFilter = v.first),
        ),
        _heading('მძღოლების განაცხადები'),
        if (rows.isEmpty) const _InfoCard(text: 'მძღოლის განაცხადები არ მოიძებნა.'),
        ...rows.map((d) => Card(child: Padding(
          padding: const EdgeInsets.all(13),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.person_pin_circle_outlined, color: MoonrideColors.blueBright),
              const SizedBox(width: 8),
              Expanded(child: Text((d['legal_first_name'] ?? '').toString() + ' ' + (d['legal_last_name'] ?? '').toString(),
                style: const TextStyle(fontWeight: FontWeight.w800))),
              _Badge(text: (d['approval_status'] ?? 'pending').toString()),
            ]),
            Text('ID: ' + d['user_id'].toString(), style: const TextStyle(color: MoonrideColors.muted, fontSize: 10)),
            Wrap(spacing: 7, children: [
              OutlinedButton(onPressed: () => _reviewDriver(d, 'approved'), child: const Text('დამტკიცება')),
              OutlinedButton(onPressed: () => _reviewDriver(d, 'rejected'), child: const Text('უარყოფა')),
              TextButton(onPressed: () => _reviewDriver(d, 'suspended'), child: const Text('შეჩერება')),
            ]),
          ]),
        ))),
        _heading('ავტომობილების მოლოდინის რიგი'),
        if (pendingVehicles.isEmpty) const _InfoCard(text: 'დასამტკიცებელი ავტომობილი არ არის.'),
        ...pendingVehicles.map((v) => _VehicleReviewCard(
          vehicle: v,
          categories: _categories.where((c) => !['MINIVAN_GO', 'GROUP_RIDE_GO'].contains(c['code'])).toList(),
          onReview: (status, category) => _reviewVehicle(v, status, category),
        )),
      ],
    );
  }

  Widget _ridesPage() => RefreshIndicator(
    onRefresh: _load,
    child: ListView(padding: const EdgeInsets.all(16), children: [
      _heading('რეალური შეკვეთები', subtitle: 'go_rides — არა ფასის შეთავაზებები'),
      if (_rides.isEmpty) const _InfoCard(text: 'რეალური შეკვეთები ჯერ არ არის.'),
      ..._rides.map((r) => _rideCard(r, allowCancel: ['requested', 'dispatching', 'accepted', 'driver_arriving', 'arrived', 'in_progress'].contains(r['status']))),
      _heading('ონლაინ მძღოლები', subtitle: 'go_get_online_driver_map RPC-ის პასუხი'),
      if (_online.isEmpty) const _InfoCard(text: 'ამჟამად ონლაინ მძღოლი არ ფიქსირდება.'),
      ..._online.map((d) => Card(child: ListTile(
        leading: const Icon(Icons.gps_fixed, color: MoonrideColors.success),
        title: Text('მძღოლი ' + d['driver_user_id'].toString().substring(0, 8)),
        subtitle: Text('კოორდინატები: ' + (d['latitude'] ?? '—').toString() + ', ' + (d['longitude'] ?? '—').toString()),
        trailing: Text((d['updated_at'] ?? '').toString().split('T').first, style: const TextStyle(fontSize: 10, color: MoonrideColors.muted)),
      ))),
    ]),
  );

  Widget _settingsPage() => RefreshIndicator(
    onRefresh: _load,
    child: ListView(padding: const EdgeInsets.all(16), children: [
      _heading('ფუნქციების მართვა', subtitle: 'მოქმედებს მხოლოდ არსებული feature flag ჩანაწერებზე'),
      if (_flags.isEmpty) const _InfoCard(text: 'Feature flags ვერ ჩაიტვირთა ან არ არსებობს.'),
      ..._flags.map((f) => Card(child: SwitchListTile(
        value: f['is_enabled'] == true,
        onChanged: f['is_available'] == true ? (value) => _toggleFlag(f, value) : null,
        title: Text((f['label'] ?? f['feature_key']).toString()),
        subtitle: Text((f['feature_group'] ?? '').toString() + ' • ' + ((f['is_available'] == true) ? 'ხელმისაწვდომი' : 'backend setup საჭიროა'),
          style: const TextStyle(fontSize: 11, color: MoonrideColors.muted)),
        activeColor: MoonrideColors.blueBright,
      ))),
      _heading('ტარიფის გეგმები'),
      if (_plans.isEmpty) const _InfoCard(text: 'ტარიფის გეგმები არ მოიძებნა.'),
      ..._plans.map(_planCard),
      _heading('გადახდები და Wallet'),
      const _InfoCard(text: 'ამჟამად ნაღდი გადახდის კონტროლი არსებობს შეკვეთის დონეზე. ბარათის PSP, Wallet ledger, თანხის დაბრუნება და payout ცალკე backend ინტეგრაციას საჭიროებს; ამ ეკრანზე თანხა არ იჭრება და არ ირიცხება.'),
    ]),
  );

  Widget _planCard(Map<String, dynamic> p) {
    final planId = p['id'];
    final planRates = _rates.where((r) => r['tariff_plan_id'] == planId).toList();
    return Card(child: Padding(
      padding: const EdgeInsets.all(15),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text((p['plan_name'] ?? 'Tariff plan').toString(), style: const TextStyle(fontWeight: FontWeight.w800))),
          _Badge(text: p['is_active'] == true ? 'active' : 'inactive'),
        ]),
        Text('ვალუტა: ' + (p['currency_code'] ?? '—').toString() + ' • ვერსია: ' + (p['rule_version'] ?? '—').toString(),
          style: const TextStyle(color: MoonrideColors.muted, fontSize: 11)),
        Text('მინ. ფასი: ' + (p['minimum_fare'] ?? '—').toString() + ' • უფასო ლოდინი: ' + (p['free_wait_minutes'] ?? '—').toString() + ' წთ',
          style: const TextStyle(color: MoonrideColors.muted, fontSize: 11)),
        const SizedBox(height: 8),
        ...planRates.map((r) {
          final cat = _categories.where((c) => c['id'] == r['category_id']).toList();
          final name = cat.isEmpty ? r['category_id'].toString() : (cat.first['code'] ?? cat.first['name']).toString();
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(children: [
              Expanded(child: Text(name, style: const TextStyle(fontSize: 12))),
              Text((r['rate_per_km'] ?? '—').toString() + ' ' + (p['currency_code'] ?? 'GEL').toString() + '/კმ',
                style: const TextStyle(color: MoonrideColors.blueBright, fontWeight: FontWeight.bold)),
            ]),
          );
        }),
      ]),
    ));
  }

  Widget _rideCard(Map<String, dynamic> ride, {bool allowCancel = false}) => Card(
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.route, color: MoonrideColors.blueBright),
          const SizedBox(width: 8),
          Expanded(child: Text('შეკვეთა #' + ride['id'].toString().substring(0, 8), style: const TextStyle(fontWeight: FontWeight.w800))),
          _Badge(text: (ride['status'] ?? '—').toString()),
        ]),
        const SizedBox(height: 8),
        Text('საიდან: ' + (ride['pickup_address'] ?? '—').toString(), style: const TextStyle(fontSize: 12)),
        Text('სად: ' + (ride['dropoff_address'] ?? '—').toString(), style: const TextStyle(fontSize: 12)),
        Text('ფასი: ' + (ride['fare_amount'] ?? '—').toString() + ' ' + (ride['currency_code'] ?? 'GEL').toString(),
          style: const TextStyle(color: MoonrideColors.blueBright, fontWeight: FontWeight.bold)),
        if (allowCancel) Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: () => _cancelRide(ride),
            icon: const Icon(Icons.cancel_outlined, color: MoonrideColors.danger),
            label: const Text('შეკვეთის გაუქმება'),
          ),
        ),
      ]),
    ),
  );
}

class _VehicleReviewCard extends StatefulWidget {
  const _VehicleReviewCard({required this.vehicle, required this.categories, required this.onReview});
  final Map<String, dynamic> vehicle;
  final List<Map<String, dynamic>> categories;
  final Future<void> Function(String status, String category) onReview;
  @override
  State<_VehicleReviewCard> createState() => _VehicleReviewCardState();
}

class _VehicleReviewCardState extends State<_VehicleReviewCard> {
  String? _category;
  @override
  Widget build(BuildContext context) {
    final v = widget.vehicle;
    final categories = widget.categories;
    _category ??= categories.isEmpty ? null : categories.first['code'].toString();
    return Card(child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text((v['make'] ?? '').toString() + ' ' + (v['model'] ?? '').toString() + ' • ' + (v['plate_number'] ?? '').toString(),
          style: const TextStyle(fontWeight: FontWeight.w800)),
        Text('მძღოლი: ' + v['owner_user_id'].toString(), style: const TextStyle(fontSize: 10, color: MoonrideColors.muted)),
        DropdownButtonFormField<String>(
          value: _category,
          decoration: const InputDecoration(labelText: 'დადასტურებული კატეგორია'),
          items: categories.map((c) => DropdownMenuItem(value: c['code'].toString(), child: Text(c['code'].toString()))).toList(),
          onChanged: (value) => setState(() => _category = value),
        ),
        const SizedBox(height: 8),
        SizedBox(width: double.infinity, child: FilledButton(
          onPressed: _category == null ? null : () => widget.onReview('approved', _category!),
          child: const Text('ავტომობილის დამტკიცება'),
        )),
        const SizedBox(height: 2),
      ]),
    ));
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: MoonrideColors.blue.withValues(alpha: 0.18),
      borderRadius: BorderRadius.circular(30),
      border: Border.all(color: MoonrideColors.blueBright.withValues(alpha: 0.35)),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      child: Text(text, style: const TextStyle(fontSize: 10, color: MoonrideColors.ice)),
    ),
  );
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Card(child: Padding(
    padding: const EdgeInsets.all(16),
    child: Row(children: [
      const Icon(Icons.info_outline, color: MoonrideColors.muted),
      const SizedBox(width: 9),
      Expanded(child: Text(text, style: const TextStyle(color: MoonrideColors.muted))),
    ]),
  ));
}
