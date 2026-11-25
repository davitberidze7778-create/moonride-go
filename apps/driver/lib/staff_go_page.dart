import 'package:flutter/material.dart';
import 'package:moonride_core/moonride_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DriverStaffGoPage extends StatefulWidget {
  const DriverStaffGoPage({super.key, required this.userId});
  final String userId;

  @override
  State<DriverStaffGoPage> createState() => _DriverStaffGoPageState();
}

class _DriverStaffGoPageState extends State<DriverStaffGoPage> {
  final _db = Supabase.instance.client;
  bool _loading = true;
  bool _busy = false;
  String? _error;
  Map<String, dynamic>? _driver;
  Map<String, dynamic>? _settings;
  Map<String, dynamic>? _feature;
  Map<String, dynamic>? _presence;
  List<Map<String, dynamic>> _vehicles = [];
  List<Map<String, dynamic>> _assignments = [];
  List<Map<String, dynamic>> _availability = [];
  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _offers = [];
  List<Map<String, dynamic>> _orders = [];
  List<Map<String, dynamic>> _requests = [];
  List<Map<String, dynamic>> _addresses = [];

  List<Map<String, dynamic>> _maps(dynamic value) =>
      (value as List<dynamic>? ?? const []).whereType<Map<String, dynamic>>().toList();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() { _loading = true; _error = null; });
    try {
      final base = await Future.wait([
        _db.from('driver_profiles').select('approval_status').eq('user_id', widget.userId).maybeSingle(),
        _db.from('staff_go_driver_settings').select('*').eq('driver_user_id', widget.userId).maybeSingle(),
        _db.from('go_app_feature_flags').select('is_enabled,is_available,config').eq('feature_key', 'ride.staff_go').maybeSingle(),
        _db.from('vehicles').select('id,make,model,plate_number,approval_status,passenger_capacity').eq('owner_user_id', widget.userId).order('created_at', ascending: false),
        _db.from('driver_live_locations').select('active_vehicle_id,is_online,recorded_at').eq('driver_user_id', widget.userId).maybeSingle(),
        _db.from('staff_go_driver_offers').select('*').eq('driver_user_id', widget.userId).eq('status', 'offered').order('offered_at', ascending: false).limit(30),
        _db.from('staff_go_orders').select('*').eq('driver_user_id', widget.userId).inFilter('status', const ['accepted','driver_arriving','arrived','in_progress']).order('requested_at', ascending: false).limit(20),
      ]);

      final vehicles = _maps(base[3]);
      final vehicleIds = vehicles.map((v) => v['id'].toString()).toList();
      final assignments = vehicleIds.isEmpty
          ? <Map<String, dynamic>>[]
          : _maps(await _db.from('vehicle_category_assignments')
              .select('id,vehicle_id,category_id,status')
              .inFilter('vehicle_id', vehicleIds)
              .order('created_at', ascending: false));
      final availability = assignments.isEmpty
          ? <Map<String, dynamic>>[]
          : _maps(await _db.from('driver_vehicle_category_availability')
              .select('*')
              .eq('driver_user_id', widget.userId)
              .inFilter('vehicle_id', vehicleIds));
      final categoryIds = assignments.map((a) => a['category_id'].toString()).toSet().toList();
      final categories = categoryIds.isEmpty
          ? <Map<String, dynamic>>[]
          : _maps(await _db.from('vehicle_categories')
              .select('id,code,name,is_active')
              .inFilter('id', categoryIds));

      final offers = _maps(base[5]).where((offer) {
        final expiry = DateTime.tryParse((offer['expires_at'] ?? '').toString());
        return expiry != null && expiry.isAfter(DateTime.now());
      }).toList();
      final activeOrders = _maps(base[6]);
      final orderIds = <String>{
        ...offers.map((o) => o['staff_go_order_id'].toString()),
        ...activeOrders.map((o) => o['id'].toString()),
      }.where((id) => id.isNotEmpty && id != 'null').toList();
      final orderDetails = orderIds.isEmpty
          ? <Map<String, dynamic>>[]
          : _maps(await _db.from('staff_go_orders').select('*').inFilter('id', orderIds));
      final requestIds = orderDetails.map((o) => o['request_id'].toString()).toSet().toList();
      final requests = requestIds.isEmpty
          ? <Map<String, dynamic>>[]
          : _maps(await _db.from('staff_go_requests').select('*').inFilter('id', requestIds));
      final addresses = requestIds.isEmpty
          ? <Map<String, dynamic>>[]
          : _maps(await _db.from('staff_go_addresses').select('*').inFilter('request_id', requestIds).order('sequence_no'));

      if (!mounted) return;
      setState(() {
        _driver = base[0] as Map<String, dynamic>?;
        _settings = base[1] as Map<String, dynamic>?;
        _feature = base[2] as Map<String, dynamic>?;
        _vehicles = vehicles;
        _presence = base[4] as Map<String, dynamic>?;
        _assignments = assignments;
        _availability = availability;
        _categories = categories;
        _offers = offers;
        _orders = activeOrders;
        _requests = requests;
        _addresses = addresses;
        _loadedOrderDetails = orderDetails;
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  bool get _approvedDriver => _driver?['approval_status'] == 'approved';
  bool get _featureEnabled => _feature?['is_enabled'] == true && _feature?['is_available'] == true;
  bool get _staffGoEnabled => _settings?['is_enabled_by_driver'] == true;
  String? get _activeVehicleId => _presence?['active_vehicle_id']?.toString();

  Map<String, dynamic>? _orderForOffer(Map<String, dynamic> offer) {
    for (final order in _ordersForOffers) {
      if (order['id'].toString() == offer['staff_go_order_id'].toString()) return order;
    }
    return null;
  }

  List<Map<String, dynamic>> get _ordersForOffers {
    // Offer order rows are also loaded into the shared order list below when active.
    return _loadedOrderDetails;
  }

  List<Map<String, dynamic>> _loadedOrderDetails = [];

  Map<String, dynamic>? _requestFor(Map<String, dynamic>? order) {
    if (order == null) return null;
    for (final request in _requests) {
      if (request['id'].toString() == order['request_id'].toString()) return request;
    }
    return null;
  }

  List<Map<String, dynamic>> _destinations(Map<String, dynamic>? request) {
    if (request == null) return [];
    return _addresses.where((a) => a['request_id'].toString() == request['id'].toString()).toList()
      ..sort((a,b) => (a['sequence_no'] as num).compareTo(b['sequence_no'] as num));
  }

  String _money(dynamic value) =>
      double.tryParse((value ?? '').toString())?.toStringAsFixed(2) ?? '—';

  String _date(dynamic value) {
    final date = DateTime.tryParse((value ?? '').toString());
    return date == null ? '—' : date.toLocal().toString().substring(0,16);
  }

  void _message(String value, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(value),
      backgroundColor: error ? MoonrideColors.danger : MoonrideColors.panelLight,
    ));
  }

  Future<void> _toggleStaffGo(bool enabled) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await _db.rpc('go_staff_go_set_driver_enabled', params: {'p_enabled': enabled});
      _message(enabled ? 'STAFF GO ჩართულია. შეთავაზებებს მიიღებ მხოლოდ დამტკიცებული კატეგორიებით.' : 'STAFF GO გამორთულია.');
      await _load();
    } catch (e) {
      _message('STAFF GO-ის სტატუსი ვერ შეიცვალა: $e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _setActiveVehicle(String vehicleId) async {
    try {
      await _db.rpc('go_staff_go_set_active_vehicle', params: {'p_vehicle_id': vehicleId});
      _message('აქტიური ავტომობილი შეირჩა.');
      await _load();
    } catch (e) {
      _message('ავტომობილის არჩევა ვერ მოხერხდა: $e', error: true);
    }
  }

  Future<void> _toggleCategory(Map<String, dynamic> assignment, bool enabled) async {
    try {
      final existing = _availability.where((a) =>
        a['assignment_id'].toString() == assignment['id'].toString()).firstOrNull;
      if (existing == null) {
        await _db.from('driver_vehicle_category_availability').insert({
          'driver_user_id': widget.userId,
          'vehicle_id': assignment['vehicle_id'],
          'assignment_id': assignment['id'],
          'is_enabled_by_driver': enabled,
        });
      } else {
        await _db.from('driver_vehicle_category_availability')
          .update({'is_enabled_by_driver': enabled})
          .eq('driver_user_id', widget.userId)
          .eq('assignment_id', assignment['id']);
      }
      _message(enabled ? 'კატეგორია ჩართულია.' : 'კატეგორია გამორთულია.');
      await _load();
    } catch (e) {
      _message('კატეგორიის შეცვლა ვერ მოხერხდა: $e', error: true);
    }
  }

  Future<void> _respondOffer(Map<String, dynamic> offer, bool accept) async {
    try {
      final result = await _db.rpc('go_staff_go_respond_offer', params: {
        'p_offer_id': offer['id'],
        'p_accept': accept,
      });
      final data = result is Map<String, dynamic> ? result : <String, dynamic>{};
      if (data['success'] == false) {
        _message('შეთავაზება ვეღარ მიიღება: ' + (data['reason'] ?? 'eligibility_changed').toString(), error: true);
      } else {
        _message(accept ? 'STAFF GO შეკვეთა მიღებულია.' : 'შეთავაზება უარყოფილია.');
      }
      await _load();
    } catch (e) {
      _message('შეთავაზებაზე პასუხი ვერ შესრულდა: $e', error: true);
    }
  }

  Future<void> _advanceOrder(Map<String, dynamic> order) async {
    final next = switch (order['status']) {
      'accepted' => 'driver_arriving',
      'driver_arriving' => 'arrived',
      'arrived' => 'in_progress',
      'in_progress' => 'completed',
      _ => null,
    };
    if (next == null) return;
    try {
      await _db.rpc('go_staff_go_update_order_status', params: {
        'p_order_id': order['id'],
        'p_new_status': next,
        'p_note': null,
      });
      _message('STAFF GO შეკვეთის სტატუსი განახლდა.');
      await _load();
    } catch (e) {
      _message('სტატუსი ვერ განახლდა: $e', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return ListView(padding: const EdgeInsets.all(20), children: [
        _header(),
        _InfoCard(text: 'STAFF GO მონაცემები ვერ ჩაიტვირთა: $_error'),
        FilledButton(onPressed: _load, child: const Text('ხელახლა ცდა')),
      ]);
    }

    final approvedVehicles = _vehicles.where((v) => v['approval_status'] == 'approved').toList();
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(padding: const EdgeInsets.all(16), children: [
        _header(),
        Card(child: SwitchListTile(
          value: _staffGoEnabled,
          onChanged: _approvedDriver && _featureEnabled && !_busy ? _toggleStaffGo : null,
          secondary: const Icon(Icons.groups_2_outlined, color: MoonrideColors.blueBright),
          title: const Text('STAFF GO-ის მიღება', style: TextStyle(fontWeight: FontWeight.w900)),
          subtitle: Text(_staffGoEnabled ? 'ჩართულია — მიიღებ STAFF GO შეკვეთებს' :
            (_featureEnabled ? 'გამორთულია — ჩართე სურვილისამებრ' : 'MASTER ADMIN-ს ჯერ არ ჩაურთავს სერვისი')),
        )),
        if (!_approvedDriver)
          const _InfoCard(text: 'STAFF GO-ს ჩართვა შეუძლია მხოლოდ დამტკიცებულ მძღოლს.'),
        _heading('აქტიური ავტომობილი'),
        if (approvedVehicles.isEmpty)
          const _InfoCard(text: 'დამტკიცებული ავტომობილი ჯერ არ გაქვს.')
        else
          Card(child: Padding(
            padding: const EdgeInsets.all(14),
            child: DropdownButtonFormField<String>(
              value: approvedVehicles.any((v) => v['id'].toString() == _activeVehicleId) ? _activeVehicleId : null,
              decoration: const InputDecoration(labelText: 'შეკვეთებისთვის გამოყენებული ავტომობილი'),
              items: approvedVehicles.map((v) => DropdownMenuItem(
                value: v['id'].toString(),
                child: Text('${v['make']} ${v['model']} • ${v['plate_number']}'),
              )).toList(),
              onChanged: (value) { if (value != null) _setActiveVehicle(value); },
            ),
          )),
        _heading('დამტკიცებული კატეგორიები', subtitle: 'თითოეული კატეგორიის ხელმისაწვდომობას თავად მართავ. საწყისი მდგომარეობა გამორთულია.'),
        if (approvedVehicles.isEmpty)
          const _InfoCard(text: 'კატეგორიების მართვა გამოჩნდება ავტომობილის დამტკიცების შემდეგ.'),
        ...approvedVehicles.map((vehicle) {
          final vehicleAssignments = _assignments.where((a) =>
            a['vehicle_id'].toString() == vehicle['id'].toString() && a['status'] == 'approved').toList();
          final categoryRows = vehicleAssignments.map((assignment) {
            final category = _categories.where((c) => c['id'].toString() == assignment['category_id'].toString()).firstOrNull;
            final availability = _availability.where((a) =>
              a['assignment_id'].toString() == assignment['id'].toString()).firstOrNull;
            return SwitchListTile(
              value: availability?['is_enabled_by_driver'] == true,
              onChanged: _approvedDriver ? (value) => _toggleCategory(assignment,value) : null,
              title: Text((category?['name'] ?? category?['code'] ?? 'კატეგორია').toString()),
              subtitle: Text((category?['code'] ?? '').toString()),
              dense: true,
            );
          }).toList();
          return Card(child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${vehicle['make']} ${vehicle['model']} • ${vehicle['plate_number']}', style: const TextStyle(fontWeight: FontWeight.w800)),
              if (categoryRows.isEmpty) const Text('დამტკიცებული კატეგორია არ არის.', style: TextStyle(color: MoonrideColors.muted)),
              ...categoryRows,
            ]),
          ));
        }),
        _heading('შემომავალი STAFF GO შეთავაზებები'),
        if (!_staffGoEnabled) const _InfoCard(text: 'გამორთულ რეჟიმში STAFF GO შეთავაზებებს არ მიიღებ.'),
        if (_offers.isEmpty) const _InfoCard(text: 'აქტიური STAFF GO შეთავაზება არ არის.'),
        ..._offers.map(_offerCard),
        _heading('მიმდინარე STAFF GO შეკვეთები'),
        if (_orders.isEmpty) const _InfoCard(text: 'მიმდინარე STAFF GO შეკვეთა არ გაქვს.'),
        ..._orders.map(_activeOrderCard),
      ]),
    );
  }

  Widget _header() => Card(child: Padding(
    padding: const EdgeInsets.all(16),
    child: Row(children: [
      const Icon(Icons.groups_2, size: 38, color: MoonrideColors.blueBright),
      const SizedBox(width: 12),
      const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('STAFF GO', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
        Text('ცალკე კორპორატიული სერვისი • ჩვეულებრივი ტაქსისგან დამოუკიდებლად',
          style: TextStyle(fontSize: 11, color: MoonrideColors.muted)),
      ])),
      IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
    ]),
  ));

  Widget _offerCard(Map<String, dynamic> offer) {
    final order = _orderForOffer(offer);
    final request = _requestFor(order);
    final stops = _destinations(request);
    return Card(child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.notifications_active_outlined, color: MoonrideColors.blueBright),
          const SizedBox(width: 8),
          Expanded(child: Text('STAFF GO • #${offer['id'].toString().substring(0,8)}',
            style: const TextStyle(fontWeight: FontWeight.w800))),
          _Badge(text: (offer['status'] ?? 'offered').toString()),
        ]),
        if (request != null) ...[
          Text(request['company_name'].toString(), style: const TextStyle(color: MoonrideColors.muted)),
          Text('საიდან: ${request['pickup_address']}'),
          ...stops.map((a) => Text('${a['sequence_no']}. ${a['address_text']}')),
        ],
        if (order != null) ...[
          Text('კატეგორია: ${order['category_code']} • ${_money(order['fare_amount'])} ${order['currency_code']}',
            style: const TextStyle(color: MoonrideColors.blueBright,fontWeight: FontWeight.w900)),
          Text('ვადა: ${_date(offer['expires_at'])}', style: const TextStyle(fontSize: 11,color: MoonrideColors.muted)),
        ],
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: OutlinedButton(onPressed: () => _respondOffer(offer,false), child: const Text('უარყოფა'))),
          const SizedBox(width: 8),
          Expanded(child: FilledButton(onPressed: _staffGoEnabled ? () => _respondOffer(offer,true) : null, child: const Text('მიღება'))),
        ]),
      ]),
    ));
  }

  Widget _activeOrderCard(Map<String, dynamic> order) {
    final request = _requestFor(order);
    final stops = _destinations(request);
    final label = switch (order['status']) {
      'accepted' => 'მძღოლი გზაშია',
      'driver_arriving' => 'ადგილზე ვარ',
      'arrived' => 'მგზავრობა დავიწყე',
      'in_progress' => 'მგზავრობა დავასრულე',
      _ => null,
    };
    return Card(child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.route, color: MoonrideColors.blueBright),
          const SizedBox(width: 8),
          Expanded(child: Text('შეკვეთა #${order['id'].toString().substring(0,8)}', style: const TextStyle(fontWeight: FontWeight.w800))),
          _Badge(text: order['status'].toString()),
        ]),
        if (request != null) ...[
          Text(request['company_name'].toString()),
          Text('საიდან: ${request['pickup_address']}'),
          ...stops.map((a) => Text('${a['sequence_no']}. ${a['address_text']}')),
        ],
        Text('${_money(order['fare_amount'])} ${order['currency_code']} • ${order['category_code']}',
          style: const TextStyle(color: MoonrideColors.blueBright,fontWeight: FontWeight.w900)),
        if (label != null) SizedBox(width: double.infinity, child: FilledButton(
          onPressed: () => _advanceOrder(order), child: Text(label))),
      ]),
    ));
  }

  Widget _heading(String title, {String? subtitle}) => Padding(
    padding: const EdgeInsets.fromLTRB(2,18,2,8),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(fontSize:17,fontWeight: FontWeight.w900)),
      if (subtitle != null) Text(subtitle, style: const TextStyle(fontSize:11,color:MoonrideColors.muted)),
    ]),
  );
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Card(child: Padding(
    padding: const EdgeInsets.all(14),
    child: Row(children: [
      const Icon(Icons.info_outline,color:MoonrideColors.muted),
      const SizedBox(width:8),
      Expanded(child: Text(text,style:const TextStyle(color:MoonrideColors.muted))),
    ]),
  ));
}
