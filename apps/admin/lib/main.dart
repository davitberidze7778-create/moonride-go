import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:moonride_core/moonride_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'staff_go_admin_page.dart';

const _adminTomTomApiKey = String.fromEnvironment('TOMTOM_API_KEY');

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
  String _mapProvider = 'osm';
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
  List<Map<String, dynamic>> _documents = [];
  List<Map<String, dynamic>> _waitingRules = [];
  List<Map<String, dynamic>> _vouchers = [];
  List<Map<String, dynamic>> _payouts = [];
  Timer? _onlineRefreshTimer;
  final _passengerSearch = TextEditingController();
  final _driverSearch = TextEditingController();
  String _passengerFilter = 'all';
  String _driverFilter = 'all';
  int _totalPassengers = 0;
  int _activePassengers = 0;
  int _newPassengers = 0;
  int _suspendedPassengers = 0;
  int _totalDrivers = 0;
  int _pendingDrivers = 0;
  int _pendingVehicles = 0;
  int _activeRides = 0;

  List<Map<String, dynamic>> _asMaps(dynamic value) =>
      (value as List<dynamic>? ?? const []).whereType<Map<String, dynamic>>().toList();

  @override
  void initState() {
    super.initState();
    _load();
    _onlineRefreshTimer = Timer.periodic(const Duration(seconds: 20), (_) => _refreshOnlineLocations());
  }

  @override
  void dispose() {
    _onlineRefreshTimer?.cancel();
    _passengerSearch.dispose();
    _driverSearch.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (mounted) setState(() { _loading = true; _error = null; });
    try {
      final passengers = await _db.from('profiles')
          .select('id,email,full_name,phone,role,account_status,created_at')
          .eq('role', 'passenger')
          .order('created_at', ascending: false)
          .limit(1000);
      final drivers = await _db.from('driver_profiles')
          .select('*').order('created_at', ascending: false).limit(1000);
      final vehicles = await _db.from('vehicles')
          .select('*').order('created_at', ascending: false).limit(1000);
      final rides = await _db.from('go_rides')
          .select('*').order('requested_at', ascending: false).limit(200);
      final flags = await _db.from('go_app_feature_flags')
          .select('*').order('feature_group').order('label');
      final plans = await _db.from('go_tariff_plans')
          .select('*').order('effective_from', ascending: false);
      final rates = await _db.from('go_tariff_category_rates').select('*');
      final waitingRules = await _db.from('go_tariff_waiting_rules').select('*');
      final categories = await _db.from('vehicle_categories').select('id,code,name,is_active');
      final online = await _db.rpc('go_get_online_driver_map');
      final documents = await _db.from('driver_documents').select('*').eq('is_current', true).order('submitted_at', ascending: false).limit(200);
      final vouchers = await _db.from('go_vouchers').select('*').order('created_at', ascending: false).limit(100);
      final payouts = await _db.rpc('go_admin_get_driver_payout_queue');
      final cutoff = DateTime.now().toUtc().subtract(const Duration(days: 30)).toIso8601String();
      final totalPassengerCount = await _db.from('profiles').select('id')
          .eq('role', 'passenger').count(CountOption.exact);
      final activePassengerCount = await _db.from('profiles').select('id')
          .eq('role', 'passenger').eq('account_status', 'active').count(CountOption.exact);
      final newPassengerCount = await _db.from('profiles').select('id')
          .eq('role', 'passenger').gte('created_at', cutoff).count(CountOption.exact);
      final suspendedPassengerCount = await _db.from('profiles').select('id')
          .eq('role', 'passenger').eq('account_status', 'suspended').count(CountOption.exact);
      final totalDriverCount = await _db.from('profiles').select('id')
          .eq('role', 'driver').count(CountOption.exact);
      final pendingDriverCount = await _db.from('driver_profiles').select('user_id')
          .eq('approval_status', 'pending').count(CountOption.exact);
      final pendingVehicleCount = await _db.from('vehicles').select('id')
          .eq('approval_status', 'pending').count(CountOption.exact);
      final activeRideCount = await _db.from('go_rides').select('id')
          .inFilter('status', const ['requested', 'dispatching', 'accepted', 'driver_arriving', 'arrived', 'in_progress'])
          .count(CountOption.exact);
      if (!mounted) return;
      setState(() {
        _passengers = _asMaps(passengers);
        _drivers = _asMaps(drivers);
        _vehicles = _asMaps(vehicles);
        _rides = _asMaps(rides);
        _flags = _asMaps(flags);
        _plans = _asMaps(plans);
        _rates = _asMaps(rates);
        _waitingRules = _asMaps(waitingRules);
        _categories = _asMaps(categories);
        _online = _asMaps(online);
        _documents = _asMaps(documents);
        _vouchers = _asMaps(vouchers);
        _payouts = _asMaps(payouts);
        _totalPassengers = totalPassengerCount.count ?? 0;
        _activePassengers = activePassengerCount.count ?? 0;
        _newPassengers = newPassengerCount.count ?? 0;
        _suspendedPassengers = suspendedPassengerCount.count ?? 0;
        _totalDrivers = totalDriverCount.count ?? 0;
        _pendingDrivers = pendingDriverCount.count ?? 0;
        _pendingVehicles = pendingVehicleCount.count ?? 0;
        _activeRides = activeRideCount.count ?? 0;
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

  Future<void> _refreshOnlineLocations() async {
    try {
      final result = await _db.rpc('go_get_online_driver_map');
      if (!mounted) return;
      setState(() => _online = _asMaps(result));
    } catch (_) {}
  }

  Future<void> _reviewDocument(Map<String, dynamic> row, String status) async {
    try {
      await _db.from('driver_documents').update({
        'status': status,
        'reviewed_by': widget.user.id,
        'reviewed_at': DateTime.now().toUtc().toIso8601String(),
        'rejection_reason': status == 'rejected' ? 'გთხოვთ ატვირთოთ მკაფიო და მოქმედი დოკუმენტი.' : null,
      }).eq('id', row['id']);
      _message(status == 'approved' ? 'დოკუმენტი დამტკიცდა.' : 'დოკუმენტი უარყოფილია.');
      await _load();
    } catch (e) {
      _message('დოკუმენტის განხილვა ვერ მოხერხდა: $e', error: true);
    }
  }

  Future<void> _openDriverDocument(Map<String, dynamic> row) async {
    try {
      final path = row['storage_path']?.toString();
      if (path == null || path.isEmpty) throw Exception('ფაილის მისამართი არ არის მითითებული.');
      final url = await _db.storage.from('driver-documents').createSignedUrl(path, 300);
      if (!await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication)) {
        throw Exception('დოკუმენტის გახსნა ვერ მოხერხდა.');
      }
    } catch (e) {
      _message('დოკუმენტის გახსნა ვერ მოხერხდა: $e', error: true);
    }
  }

  Future<void> _creditPassengerWallet(Map<String, dynamic> passenger) async {
    final amount = TextEditingController();
    final note = TextEditingController(text: 'MASTER ADMIN Wallet credit');
    try {
      final ok = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('MOONRIDE Wallet-ის შევსება'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Text((passenger['full_name'] ?? passenger['id']).toString()),
            TextField(controller: amount, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'თანხა (GEL)')),
            TextField(controller: note, decoration: const InputDecoration(labelText: 'შენიშვნა')),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('გაუქმება')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('ჩარიცხვა')),
          ],
        ),
      );
      if (ok != true) return;
      final value = double.tryParse(amount.text.replaceAll(',', '.'));
      if (value == null || value <= 0) throw Exception('შეიყვანე სწორი თანხა.');
      await _db.rpc('go_admin_credit_wallet', params: {
        'p_user_id': passenger['id'],
        'p_amount': value,
        'p_currency_code': 'GEL',
        'p_note': note.text.trim(),
      });
      _message('Wallet შეივსო.');
    } catch (e) {
      _message('Wallet-ის შევსება ვერ მოხერხდა: $e', error: true);
    } finally {
      amount.dispose();
      note.dispose();
    }
  }

  Future<void> _creditDriverWallet(Map<String, dynamic> driver) async {
    final amount = TextEditingController();
    final note = TextEditingController(text: 'Driver earning adjustment');
    try {
      final ok = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('მძღოლის შემოსავლის ჩარიცხვა'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Text((driver['legal_first_name'] ?? '').toString() + ' ' + (driver['legal_last_name'] ?? '').toString()),
            TextField(controller: amount, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'თანხა (GEL)')),
            TextField(controller: note, decoration: const InputDecoration(labelText: 'მიზეზი / მგზავრობის ID')),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('გაუქმება')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('ჩარიცხვა')),
          ],
        ),
      );
      if (ok != true) return;
      final value = double.tryParse(amount.text.replaceAll(',', '.'));
      if (value == null || value <= 0 || note.text.trim().isEmpty) throw Exception('შეიყვანე სწორი თანხა და მიზეზი.');
      await _db.rpc('go_admin_credit_driver_wallet', params: {
        'p_driver_user_id': driver['user_id'],
        'p_amount': value,
        'p_currency_code': 'GEL',
        'p_note': note.text.trim(),
      });
      _message('მძღოლის ბალანსი განახლდა.');
    } catch (e) {
      _message('მძღოლის ბალანსი ვერ განახლდა: $e', error: true);
    } finally {
      amount.dispose();
      note.dispose();
    }
  }

  Future<void> _setPayoutStatus(Map<String, dynamic> row, String status) async {
    try {
      await _db.rpc('go_admin_set_driver_payout_status', params: {
        'p_payout_request_id': row['id'],
        'p_status': status,
        'p_note': status == 'paid' ? 'ხელით შესრულებული საბანკო გადარიცხვა დადასტურებულია.' : 'განხილულია MASTER ADMIN-ის მიერ.',
      });
      _message('Payout სტატუსი განახლდა: $status');
      await _load();
    } catch (e) {
      _message('Payout-ის განახლება ვერ მოხერხდა: $e', error: true);
    }
  }

  Future<void> _createVoucher() async {
    final code = TextEditingController();
    final value = TextEditingController();
    final minimum = TextEditingController(text: '0');
    final maxRedemptions = TextEditingController();
    final maxDiscount = TextEditingController();
    bool percentage = true;
    String currency = 'GEL';
    try {
      final ok = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (dialogContext, setDialogState) => AlertDialog(
            title: const Text('ახალი Promo Code'),
            content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: code, textCapitalization: TextCapitalization.characters, decoration: const InputDecoration(labelText: 'კოდი')),
              const SizedBox(height: 8),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: true, label: Text('%')),
                  ButtonSegment(value: false, label: Text('ფიქსირებული')),
                ],
                selected: {percentage},
                onSelectionChanged: (v) => setDialogState(() => percentage = v.first),
              ),
              TextField(controller: value, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: percentage ? 'ფასდაკლება (%)' : 'ფასდაკლება (თანხა)')),
              if (!percentage) DropdownButtonFormField<String>(
                value: currency,
                decoration: const InputDecoration(labelText: 'ვალუტა'),
                items: const [
                  DropdownMenuItem(value: 'GEL', child: Text('GEL')),
                  DropdownMenuItem(value: 'USD', child: Text('USD')),
                  DropdownMenuItem(value: 'EUR', child: Text('EUR')),
                ],
                onChanged: (v) { if (v != null) setDialogState(() => currency = v); },
              ),
              TextField(controller: minimum, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'მინიმალური მგზავრობის ფასი')),
              TextField(controller: maxDiscount, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'მაქს. ფასდაკლება (არასავალდებულო)')),
              TextField(controller: maxRedemptions, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'ჯამური გამოყენების ლიმიტი (არასავალდებულო)')),
            ])),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('გაუქმება')),
              FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('შექმნა')),
            ],
          ),
        ),
      );
      if (ok != true) return;
      final discount = double.tryParse(value.text.replaceAll(',', '.'));
      final minimumFare = double.tryParse(minimum.text.replaceAll(',', '.')) ?? 0;
      final maxDiscountValue = double.tryParse(maxDiscount.text.replaceAll(',', '.'));
      final maxUses = int.tryParse(maxRedemptions.text);
      final normalizedCode = code.text.trim().toUpperCase();
      if (normalizedCode.length < 3 || discount == null || discount <= 0 || (percentage && discount > 100)) {
        throw Exception('კოდი ან ფასდაკლება არასწორია.');
      }
      await _db.from('go_vouchers').insert({
        'code': normalizedCode,
        'discount_type': percentage ? 'percentage' : 'fixed',
        'discount_value': discount,
        'currency_code': percentage ? null : currency,
        'minimum_fare': minimumFare,
        'max_discount_amount': maxDiscountValue,
        'max_redemptions': maxUses,
        'created_by': widget.user.id,
        'is_active': true,
      });
      _message('Promo Code შეიქმნა.');
      await _load();
    } catch (e) {
      _message('Promo Code ვერ შეიქმნა: $e', error: true);
    } finally {
      code.dispose();
      value.dispose();
      minimum.dispose();
      maxRedemptions.dispose();
      maxDiscount.dispose();
    }
  }

  Future<void> _toggleVoucher(Map<String, dynamic> row, bool enabled) async {
    try {
      await _db.from('go_vouchers').update({'is_active': enabled, 'updated_at': DateTime.now().toUtc().toIso8601String()}).eq('id', row['id']);
      _message(enabled ? 'Promo Code გააქტიურდა.' : 'Promo Code გაითიშა.');
      await _load();
    } catch (e) {
      _message('Promo Code-ის სტატუსი ვერ შეიცვალა: $e', error: true);
    }
  }

  Future<void> _editTariffPlan(Map<String, dynamic> plan) async {
    final planId = plan['id'];
    final fields = <String, TextEditingController>{
      'minimum_fare': TextEditingController(text: plan['minimum_fare'].toString()),
      'included_distance_km': TextEditingController(text: plan['included_distance_km'].toString()),
      'included_movement_minutes': TextEditingController(text: plan['included_movement_minutes'].toString()),
      'extra_movement_minute_rate': TextEditingController(text: plan['extra_movement_minute_rate'].toString()),
      'free_wait_minutes': TextEditingController(text: plan['free_wait_minutes'].toString()),
    };
    final planRates = _rates.where((r) => r['tariff_plan_id'] == planId).toList();
    final waiting = _waitingRules.where((r) => r['tariff_plan_id'] == planId).toList();
    final rateFields = <String, TextEditingController>{
      for (final r in planRates) r['id'].toString(): TextEditingController(text: r['rate_per_km'].toString()),
    };
    final waitFields = <String, TextEditingController>{
      for (final w in waiting) w['id'].toString(): TextEditingController(text: w['fee_amount'].toString()),
    };
    String waitingMode = (plan['waiting_fee_mode'] ?? 'manual_points').toString();
    try {
      final ok = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (dialogContext, setDialogState) => AlertDialog(
            title: Text('ტარიფის რედაქტირება: ' + (plan['plan_name'] ?? '').toString()),
            content: SizedBox(width: 520, child: SingleChildScrollView(child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final item in const [
                  ('minimum_fare', 'მინიმალური ფასი'),
                  ('included_distance_km', 'ჩართული კილომეტრები'),
                  ('included_movement_minutes', 'ჩართული წუთები'),
                  ('extra_movement_minute_rate', 'დამატებითი წუთის ფასი'),
                  ('free_wait_minutes', 'უფასო ლოდინი (წუთი)'),
                ]) Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: TextField(
                    controller: fields[item.$1],
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(labelText: item.$2),
                  ),
                ),
                DropdownButtonFormField<String>(
                  value: waitingMode,
                  decoration: const InputDecoration(labelText: 'ლოდინის საფასურის რეჟიმი'),
                  items: const [
                    DropdownMenuItem(value: 'manual_points', child: Text('წერტილოვანი ტარიფი')),
                    DropdownMenuItem(value: 'fixed', child: Text('ფიქსირებული')),
                    DropdownMenuItem(value: 'disabled', child: Text('გამორთული')),
                  ],
                  onChanged: (v) { if (v != null) setDialogState(() => waitingMode = v); },
                ),
                const Divider(height: 22),
                const Align(alignment: Alignment.centerLeft, child: Text('კატეგორიები (GEL / კმ)', style: TextStyle(fontWeight: FontWeight.bold))),
                for (final r in planRates)
                  TextField(
                    controller: rateFields[r['id'].toString()],
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(labelText: _categories.where((c) => c['id'] == r['category_id']).map((c) => c['code'].toString()).firstOrNull ?? 'კატეგორია'),
                  ),
                const Divider(height: 22),
                const Align(alignment: Alignment.centerLeft, child: Text('ლოდინის საფასური', style: TextStyle(fontWeight: FontWeight.bold))),
                for (final w in waiting)
                  TextField(
                    controller: waitFields[w['id'].toString()],
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(labelText: (w['wait_minutes'] ?? '—').toString() + ' წუთი'),
                  ),
              ],
            ))),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('გაუქმება')),
              FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('შენახვა')),
            ],
          ),
        ),
      );
      if (ok != true) return;
      double valueOf(String key) {
        final value = double.tryParse(fields[key]!.text.replaceAll(',', '.'));
        if (value == null || value < 0) throw Exception('ტარიფის მნიშვნელობა არასწორია: ' + key);
        return value;
      }
      final ratesPayload = planRates.map((r) => {
        'id': r['id'],
        'rate_per_km': double.tryParse(rateFields[r['id'].toString()]!.text.replaceAll(',', '.')) ?? -1,
      }).toList();
      final waitingPayload = waiting.map((w) => {
        'id': w['id'],
        'fee_amount': double.tryParse(waitFields[w['id'].toString()]!.text.replaceAll(',', '.')) ?? -1,
      }).toList();
      await _db.rpc('go_admin_update_tariff_plan', params: {
        'p_plan_id': planId,
        'p_values': {
          'minimum_fare': valueOf('minimum_fare'),
          'included_distance_km': valueOf('included_distance_km'),
          'included_movement_minutes': valueOf('included_movement_minutes'),
          'extra_movement_minute_rate': valueOf('extra_movement_minute_rate'),
          'free_wait_minutes': valueOf('free_wait_minutes'),
          'waiting_fee_mode': waitingMode,
        },
        'p_rates': ratesPayload,
        'p_waiting_rules': waitingPayload,
      });
      _message('ტარიფი განახლდა და ცვლილება backend-ში ჩაიწერა.');
      await _load();
    } catch (e) {
      _message('ტარიფის შენახვა ვერ მოხერხდა: $e', error: true);
    } finally {
      for (final controller in fields.values) { controller.dispose(); }
      for (final controller in rateFields.values) { controller.dispose(); }
      for (final controller in waitFields.values) { controller.dispose(); }
    }
  }

  Widget _liveDriverMap() {
    final points = _online.where((d) => d['latitude'] is num && d['longitude'] is num).toList();
    final center = points.isEmpty
        ? const LatLng(41.6168, 41.6367)
        : LatLng((points.first['latitude'] as num).toDouble(), (points.first['longitude'] as num).toDouble());
    return SizedBox(
      height: 290,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Stack(children: [
          FlutterMap(
            options: MapOptions(initialCenter: center, initialZoom: 12),
            children: [
              TileLayer(
                urlTemplate: _mapProvider == 'tomtom'
                    ? 'https://api.tomtom.com/map/1/tile/basic/main/{z}/{x}/{y}.png?key=$moonrideTomTomApiKey'
                    : _mapProvider == 'mapbox'
                        ? 'https://api.mapbox.com/styles/v1/mapbox/streets-v12/tiles/256/{z}/{x}/{y}?access_token=$moonrideMapboxAccessToken'
                        : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                maxNativeZoom: 19, userAgentPackageName: 'ge.moonride.admin'),
              RichAttributionWidget(attributions: [TextSourceAttribution(
                _mapProvider == 'tomtom'
                    ? '© TomTom'
                    : _mapProvider == 'mapbox'
                        ? '© Mapbox © OpenStreetMap'
                        : '© OpenStreetMap contributors',
              )]),
              MarkerLayer(markers: points.map((d) => Marker(
                point: LatLng((d['latitude'] as num).toDouble(), (d['longitude'] as num).toDouble()),
                width: 42,
                height: 46,
                child: const Icon(Icons.local_taxi, size: 35, color: MoonrideColors.blueBright),
              )).toList()),
            ],
          ),
          Positioned(
            right: 6,
            top: 6,
            child: Material(
              color: MoonrideColors.panel,
              borderRadius: BorderRadius.circular(12),
              child: PopupMenuButton<String>(
                tooltip: 'რუკის პროვაიდერი',
                initialValue: _mapProvider,
                onSelected: (value) => setState(() => _mapProvider = value),
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 'osm', child: Text('OpenStreetMap')),
                  if (moonrideTomTomApiKey.isNotEmpty)
                    const PopupMenuItem(value: 'tomtom', child: Text('TomTom')),
                  if (moonrideMapboxAccessToken.isNotEmpty)
                    const PopupMenuItem(value: 'mapbox', child: Text('Mapbox')),
                ],
                icon: const Icon(Icons.layers, color: Colors.white),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _documentReviewCard(Map<String, dynamic> row) => Card(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text((row['document_type'] ?? '').toString(), style: const TextStyle(fontWeight: FontWeight.w800)),
        Text('მძღოლი: ' + row['driver_user_id'].toString(), style: const TextStyle(fontSize: 10, color: MoonrideColors.muted)),
        Text('სტატუსი: ' + (row['status'] ?? 'pending').toString()),
        Wrap(spacing: 6, children: [
          TextButton.icon(onPressed: () => _openDriverDocument(row), icon: const Icon(Icons.visibility_outlined), label: const Text('ნახვა')),
          if (row['status'] == 'pending') OutlinedButton(onPressed: () => _reviewDocument(row, 'approved'), child: const Text('დამტკიცება')),
          if (row['status'] == 'pending') TextButton(onPressed: () => _reviewDocument(row, 'rejected'), child: const Text('უარყოფა')),
        ]),
      ]),
    ),
  );

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
    final pages = [_dashboardPage(), _passengersPage(), _driversPage(), _ridesPage(), StaffGoAdminPage(userId: widget.user.id), _settingsPage()];
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
          NavigationDestination(icon: Icon(Icons.groups_2_outlined), selectedIcon: Icon(Icons.groups_2), label: 'STAFF GO'),
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
          childAspectRatio: 1.55,
          children: [
            _metric('მგზავრები სულ', _totalPassengers, Icons.people_outline),
            _metric('აქტიური მგზავრები', _activePassengers, Icons.person_outline),
            _metric('ახალი • 30 დღე', _newPassengers, Icons.person_add_alt_1),
            _metric('შეჩერებული', _suspendedPassengers, Icons.person_off),
            _metric('მძღოლები სულ', _totalDrivers, Icons.directions_car_outlined),
            _metric('აქტიური შეკვეთები', _activeRides, Icons.route_outlined),
            _metric('ონლაინ მძღოლები', _online.length, Icons.gps_fixed),
            _metric('მძღოლის განაცხადები', _pendingDrivers, Icons.assignment_ind_outlined),
            _metric('მანქანის განაცხადები', _pendingVehicles, Icons.car_repair),
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
              Align(alignment: Alignment.centerRight, child: Wrap(spacing: 7, children: [
                OutlinedButton.icon(
                  onPressed: () => _creditPassengerWallet(row),
                  icon: const Icon(Icons.account_balance_wallet_outlined),
                  label: const Text('Wallet +'),
                ),
                OutlinedButton(
                  onPressed: () => _setPassengerStatus(row),
                  child: Text(suspended ? 'ანგარიშის აღდგენა' : 'ანგარიშის შეჩერება'),
                ),
              ])),
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
              OutlinedButton.icon(onPressed: () => _creditDriverWallet(d), icon: const Icon(Icons.account_balance_wallet_outlined), label: const Text('შემოსავალი +')),
              TextButton(onPressed: () => _reviewDriver(d, 'suspended'), child: const Text('შეჩერება')),
            ]),
          ]),
        ))),
        _heading('მძღოლების დოკუმენტების შემოწმება'),
      if (_documents.where((d) => d['status'] == 'pending').isEmpty) const _InfoCard(text: 'დასამტკიცებელი დოკუმენტი არ არის.'),
      ..._documents.where((d) => d['status'] == 'pending').map(_documentReviewCard),
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
      _heading('მძღოლების Live Map', subtitle: 'მდებარეობა ახლდება ყოველ 20 წამში. რუკა აჩვენებს ბოლო 90 წამში დაფიქსირებულ ავტორიზებულ მძღოლებს.'),
      _liveDriverMap(),
      const SizedBox(height: 8),
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
        activeThumbColor: MoonrideColors.blueBright,
      ))),
      _heading('ტარიფის გეგმები'),
      if (_plans.isEmpty) const _InfoCard(text: 'ტარიფის გეგმები არ მოიძებნა.'),
      ..._plans.map(_planCard),
      _heading('Promo Codes / ვაუჩერები'),
      SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: _createVoucher, icon: const Icon(Icons.discount_outlined), label: const Text('ახალი Promo Code'))),
      if (_vouchers.isEmpty) const _InfoCard(text: 'Promo Code ჯერ არ შექმნილა.'),
      ..._vouchers.map((v) => Card(child: SwitchListTile(
        value: v['is_active'] == true,
        onChanged: (enabled) => _toggleVoucher(v, enabled),
        title: Text((v['code'] ?? '').toString()),
        subtitle: Text((v['discount_type'] == 'percentage' ? v['discount_value'].toString() + '%' : v['discount_value'].toString() + ' ' + (v['currency_code'] ?? '').toString()) + ' • ერთ მგზავრზე ერთხელ'),
      ))),
      _heading('მძღოლის payout მოთხოვნები'),
      if (_payouts.isEmpty) const _InfoCard(text: 'payout მოთხოვნები ჯერ არ არის.'),
      ..._payouts.map((p) => Card(child: Padding(
        padding: const EdgeInsets.all(13),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text((p['driver_name'] ?? p['driver_user_id'] ?? '').toString(), style: const TextStyle(fontWeight: FontWeight.w800)),
          Text((p['amount'] ?? '—').toString() + ' ' + (p['currency_code'] ?? '').toString() + ' • ' + (p['bank_code'] ?? '').toString().toUpperCase() + ' • ' + (p['status'] ?? '').toString()),
          Text('მიმღები: ' + (p['account_holder'] ?? '—').toString()),
          SelectableText('IBAN: ' + (p['iban'] ?? '—').toString()),
          if (p['status'] == 'pending' || p['status'] == 'approved')
            Wrap(spacing: 7, children: [
              OutlinedButton(onPressed: () => _setPayoutStatus(p, 'approved'), child: const Text('დადასტურება')),
              TextButton(onPressed: () => _setPayoutStatus(p, 'rejected'), child: const Text('უარყოფა')),
              FilledButton(onPressed: () => _setPayoutStatus(p, 'paid'), child: const Text('გადახდილი')),
            ]),
        ]),
      ))),
      _heading('ფინანსური ინტეგრაციის სტატუსი'),
      const _InfoCard(text: 'Wallet-ის შიდა გადახდა/დაბრუნება, ვაუჩერები და loyalty აქტიურია. მძღოლის payout მოთხოვნის დამუშავება MASTER ADMIN-ის მიერ სრულდება ხელით. TBC/BOG ბარათით ჩამოჭრა გამორთულია, სანამ პროვაიდერის ოფიციალური ანგარიშის მონაცემები და webhook ხელმოწერის შემოწმება არ იქნება დაყენებული.'),
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
        Align(alignment: Alignment.centerRight, child: OutlinedButton.icon(
          onPressed: () => _editTariffPlan(p),
          icon: const Icon(Icons.edit_outlined),
          label: const Text('ტარიფის რედაქტირება'),
        )),
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
          initialValue: _category,
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
