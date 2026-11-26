import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:moonride_core/moonride_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'staff_go_page.dart';

Future<void> main() async {
  await initializeMoonride();
  runApp(const MoonrideDriveApp());
}

class MoonrideDriveApp extends StatelessWidget {
  const MoonrideDriveApp({super.key});
  @override
  Widget build(BuildContext context) => MoonrideApp(
    appName: 'MoonrideDrive',
    expectedRole: 'driver',
    allowGoogleAuth: true,
    homeBuilder: (context, user, profile) => DriverHome(user: user, profile: profile),
  );
}

class DriverHome extends StatefulWidget {
  const DriverHome({super.key, required this.user, required this.profile});
  final User user;
  final Map<String, dynamic> profile;
  @override
  State<DriverHome> createState() => _DriverHomeState();
}

class _DriverHomeState extends State<DriverHome> {
  final _db = Supabase.instance.client;
  int _tab = 0;
  String _mapProvider = 'osm';
  bool _loading = true;
  bool _busy = false;
  String? _error;
  Map<String, dynamic>? _driver;
  Map<String, dynamic>? _presence;
  List<Map<String, dynamic>> _vehicles = [];
  List<Map<String, dynamic>> _offers = [];
  List<Map<String, dynamic>> _offerRides = [];
  List<Map<String, dynamic>> _rides = [];
  List<Map<String, dynamic>> _documents = [];
  List<Map<String, dynamic>> _cities = [];
  List<Map<String, dynamic>> _categories = [];
  StreamSubscription<Position>? _gps;
  String _selectedDocumentType = 'identity_document';
  bool _uploadingDocument = false;
  double _driverWalletBalance = 0;
  List<Map<String, dynamic>> _driverWalletTransactions = [];
  List<Map<String, dynamic>> _payoutRequests = [];
  static const _activeStatuses = ['accepted', 'driver_arriving', 'arrived', 'in_progress'];

  List<Map<String, dynamic>> _asMaps(dynamic value) =>
      (value as List<dynamic>? ?? const []).whereType<Map<String, dynamic>>().toList();

  @override
  void initState() { super.initState(); _load(); }

  @override
  void dispose() { _gps?.cancel(); super.dispose(); }

  Future<void> _load() async {
    if (mounted) setState(() { _loading = true; _error = null; });
    try {
      final r = await Future.wait([
        _db.from('driver_profiles').select('*').eq('user_id', widget.user.id).maybeSingle(),
        _db.from('vehicles').select('*').eq('owner_user_id', widget.user.id).order('created_at', ascending: false),
        _db.from('go_driver_offers').select('*').eq('driver_user_id', widget.user.id).eq('status', 'sent').order('offered_at', ascending: false).limit(40),
        _db.from('go_rides').select('*').eq('driver_user_id', widget.user.id).inFilter('status', _activeStatuses).order('requested_at', ascending: false).limit(10),
        _db.from('driver_live_locations').select('latitude,longitude,is_online,updated_at').eq('driver_user_id', widget.user.id).maybeSingle(),
        _db.from('driver_documents').select('id,document_type,status,rejection_reason,expires_at,submitted_at').eq('driver_user_id', widget.user.id).eq('is_current', true).order('submitted_at', ascending: false),
        _db.from('cities').select('id,name').eq('is_active', true).eq('service_enabled', true).order('name'),
        _db.from('vehicle_categories').select('code,name').eq('is_active', true).order('name'),
        _db.from('go_driver_wallet_accounts').select('balance').eq('driver_user_id', widget.user.id).eq('currency_code', 'GEL').maybeSingle(),
        _db.from('go_driver_wallet_transactions').select('direction,transaction_type,amount,note,created_at').eq('driver_user_id', widget.user.id).eq('currency_code', 'GEL').order('created_at', ascending: false).limit(5),
        _db.from('go_driver_payout_requests').select('id,amount,currency_code,bank_code,status,requested_at').eq('driver_user_id', widget.user.id).order('requested_at', ascending: false).limit(10),
      ]);
      final offers = _asMaps(r[2]);
      final offerRideIds = offers.map((row) => row['ride_id']).whereType<String>().toList();
      final offerRides = offerRideIds.isEmpty
          ? <Map<String, dynamic>>[]
          : _asMaps(await _db.from('go_rides')
              .select('id,pickup_address,dropoff_address,fare_amount,currency_code,category_code,payment_method')
              .inFilter('id', offerRideIds));
      if (!mounted) return;
      setState(() {
        _driver = r[0] as Map<String, dynamic>?;
        _vehicles = _asMaps(r[1]);
        _offers = offers;
        _offerRides = offerRides;
        _rides = _asMaps(r[3]);
        _presence = r[4] as Map<String, dynamic>?;
        _documents = _asMaps(r[5]);
        _cities = _asMaps(r[6]);
        _categories = _asMaps(r[7]).where((x) => !['MINIVAN_GO', 'GROUP_RIDE_GO'].contains(x['code'])).toList();
        _driverWalletBalance = ((r[8] as Map<String, dynamic>?)?['balance'] as num?)?.toDouble() ?? 0;
        _driverWalletTransactions = _asMaps(r[9]);
        _payoutRequests = _asMaps(r[10]);
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  bool get _approvedDriver => _driver?['approval_status'] == 'approved';
  bool get _approvedVehicle => _vehicles.any((v) => v['approval_status'] == 'approved');
  bool get _online => _presence?['is_online'] == true;
  Map<String, dynamic>? get _activeRide {
    for (final ride in _rides) {
      if (_activeStatuses.contains(ride['status'])) return ride;
    }
    return null;
  }

  void _message(String value, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(value),
      backgroundColor: error ? MoonrideColors.danger : MoonrideColors.panelLight,
    ));
  }

  Future<Position?> _getPosition() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      _message('ტელეფონის GPS გამორთულია.', error: true);
      return null;
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      _message('ონლაინ რეჟიმისთვის საჭიროა GPS ნებართვა.', error: true);
      return null;
    }
    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );
  }

  Future<void> _writePresence(Position? p, bool online) async {
    await _db.rpc('go_update_driver_presence', params: {
      'p_latitude': p?.latitude,
      'p_longitude': p?.longitude,
      'p_is_online': online,
      'p_accuracy_m': p?.accuracy,
      'p_heading_deg': p?.heading,
      'p_speed_mps': p?.speed,
    });
  }

  Future<void> _toggleOnline() async {
    if (_busy) return;
    if (!_approvedDriver || !_approvedVehicle) {
      _message('ონლაინ რეჟიმისთვის მძღოლი და მინიმუმ ერთი ავტომობილი უნდა იყოს დამტკიცებული.', error: true);
      return;
    }
    setState(() => _busy = true);
    try {
      if (_online) {
        await _gps?.cancel();
        _gps = null;
        await _writePresence(null, false);
        _message('ოფლაინ რეჟიმი ჩაირთო.');
      } else {
        final position = await _getPosition();
        if (position == null) return;
        await _writePresence(position, true);
        await _gps?.cancel();
        _gps = Geolocator.getPositionStream(
          locationSettings: AndroidSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 15,
            intervalDuration: const Duration(seconds: 10),
            foregroundNotificationConfig: const ForegroundNotificationConfig(
              notificationTitle: 'MOONRIDE Drive',
              notificationText: 'მძღოლის GPS აქტიურია ონლაინ რეჟიმში',
              enableWakeLock: true,
            ),
          ),
        ).listen((p) => _writePresence(p, true).catchError((Object _) {}));
        _message('ონლაინ რეჟიმი ჩაირთო. GPS მუშაობს ფონშიც აქტიური შეტყობინებით.');
      }
      await _load();
    } catch (e) {
      _message('ონლაინ სტატუსის შეცვლა ვერ მოხერხდა: ' + e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _requestPayout() async {
    final amount = TextEditingController();
    final holder = TextEditingController();
    final iban = TextEditingController();
    String bankCode = 'tbc';
    try {
      final ok = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (dialogContext, setDialogState) => AlertDialog(
            title: const Text('თანხის გატანის მოთხოვნა'),
            content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text('ხელმისაწვდომი ბალანსი: $_driverWalletBalance GEL'),
              TextField(controller: amount, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'თანხა (GEL)')),
              DropdownButtonFormField<String>(
                value: bankCode,
                decoration: const InputDecoration(labelText: 'ბანკი'),
                items: const [
                  DropdownMenuItem(value: 'tbc', child: Text('TBC Bank')),
                  DropdownMenuItem(value: 'bog', child: Text('Bank of Georgia')),
                ],
                onChanged: (v) { if (v != null) setDialogState(() => bankCode = v); },
              ),
              TextField(controller: holder, decoration: const InputDecoration(labelText: 'ანგარიშის მფლობელი')),
              TextField(controller: iban, decoration: const InputDecoration(labelText: 'IBAN'), textCapitalization: TextCapitalization.characters),
            ])),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('გაუქმება')),
              FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('მოთხოვნა')),
            ],
          ),
        ),
      );
      if (ok != true) return;
      final value = double.tryParse(amount.text.replaceAll(',', '.'));
      if (value == null || value <= 0 || holder.text.trim().length < 3 || iban.text.trim().isEmpty) {
        throw Exception('შეიყვანე თანხა, ანგარიშის მფლობელი და IBAN.');
      }
      await _db.rpc('go_request_driver_payout', params: {
        'p_amount': value,
        'p_currency_code': 'GEL',
        'p_bank_code': bankCode,
        'p_account_holder': holder.text.trim(),
        'p_iban': iban.text.trim().toUpperCase(),
      });
      _message('გატანის მოთხოვნა გაიგზავნა MASTER ADMIN-თან.');
      await _load();
    } catch (e) {
      _message('გატანის მოთხოვნა ვერ გაიგზავნა: $e', error: true);
    } finally {
      amount.dispose();
      holder.dispose();
      iban.dispose();
    }
  }

  Future<void> _uploadDriverDocument() async {
    if (_driver == null) {
      _message('ჯერ შეავსე მძღოლის განაცხადი.', error: true);
      return;
    }
    if (_uploadingDocument) return;
    setState(() => _uploadingDocument = true);
    String? uploadedPath;
    var documentRegistered = false;
    try {
      final picked = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png', 'webp'],
        allowMultiple: false,
        withData: true,
      );
      if (picked == null || picked.files.isEmpty) return;
      final file = picked.files.single;
      final bytes = file.bytes;
      if (bytes == null || bytes.isEmpty) {
        throw Exception('ფაილის წაკითხვა ვერ მოხერხდა.');
      }
      if (bytes.length > 10 * 1024 * 1024) {
        throw Exception('ფაილის მაქსიმალური ზომაა 10 MB.');
      }
      final extension = (file.extension ?? '').toLowerCase();
      final contentType = switch (extension) {
        'pdf' => 'application/pdf',
        'jpg' || 'jpeg' => 'image/jpeg',
        'png' => 'image/png',
        'webp' => 'image/webp',
        _ => throw Exception('დაშვებულია PDF, JPG, PNG ან WEBP.'),
      };
      final safeName = file.name.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
      uploadedPath = '${widget.user.id}/$_selectedDocumentType/${DateTime.now().millisecondsSinceEpoch}_$safeName';
      await _db.storage.from('driver-documents').uploadBinary(
        uploadedPath!,
        bytes,
        fileOptions: FileOptions(
          cacheControl: '3600',
          upsert: false,
          contentType: contentType,
        ),
      );
      await _db.rpc('go_submit_driver_document', params: {
        'p_document_type': _selectedDocumentType,
        'p_storage_path': uploadedPath,
        'p_expires_at': null,
      });
      documentRegistered = true;
      _message('დოკუმენტი უსაფრთხოდ აიტვირთა და შემოწმებას ელოდება.');
      await _load();
    } catch (e) {
      if (uploadedPath != null && !documentRegistered) {
        try {
          await _db.storage.from('driver-documents').remove([uploadedPath]);
        } catch (_) {}
      }
      _message('დოკუმენტის ატვირთვა ვერ მოხერხდა: $e', error: true);
    } finally {
      if (mounted) setState(() => _uploadingDocument = false);
    }
  }

  Future<void> _openNavigation(Map<String, dynamic> ride) async {
    try {
      final quoteId = ride['quote_id']?.toString();
      if (quoteId == null || quoteId.isEmpty) {
        throw Exception('მარშრუტის მონაცემები ვერ მოიძებნა.');
      }
      final points = _asMaps(await _db
          .from('ride_route_points')
          .select('latitude,longitude,address,point_type,sequence_number')
          .eq('quote_id', quoteId)
          .order('sequence_number'));
      if (points.isEmpty) throw Exception('მარშრუტის წერტილები არ არსებობს.');
      final target = ride['status'] == 'in_progress' ? points.last : points.first;
      final lat = (target['latitude'] as num).toDouble();
      final lon = (target['longitude'] as num).toDouble();
      final uri = Uri.https('www.google.com', '/maps/dir/', {
        'api': '1',
        'destination': '$lat,$lon',
        'travelmode': 'driving',
        'dir_action': 'navigate',
      });
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw Exception('ნავიგაციის აპის გახსნა ვერ მოხერხდა.');
      }
    } catch (e) {
      _message('ნავიგაცია ვერ გაიხსნა: $e', error: true);
    }
  }

  Future<void> _respond(String id, bool accept) async {
    try {
      await _db.rpc('go_respond_driver_offer', params: {'p_offer_id': id, 'p_accept': accept});
      _message(accept ? 'შეთავაზებაზე თანხმობა გაიგზავნა.' : 'შეთავაზება უარყოფილია.');
      await _load();
    } catch (e) {
      _message('შეთავაზებაზე პასუხი ვერ შესრულდა: ' + e.toString(), error: true);
    }
  }

  Future<void> _advance(Map<String, dynamic> ride) async {
    final String? next = switch (ride['status']) {
      'accepted' => 'driver_arriving',
      'driver_arriving' => 'arrived',
      'arrived' => 'in_progress',
      'in_progress' => 'completed',
      _ => null,
    };
    if (next == null) return;
    try {
      await _db.rpc('go_update_ride_status', params: {
        'p_ride_id': ride['id'], 'p_new_status': next, 'p_note': null,
      });
      _message('მგზავრობის სტატუსი განახლდა: ' + next);
      await _load();
    } catch (e) {
      _message('სტატუსის განახლება ვერ მოხერხდა: ' + e.toString(), error: true);
    }
  }

  Future<void> _signOut() async {
    await _gps?.cancel();
    _gps = null;
    await _db.auth.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final pages = [_workPage(), _offersPage(), _vehiclePage(), DriverStaffGoPage(userId: widget.user.id), _profilePage()];
    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          const MoonrideBrandMark(size: 38),
          const SizedBox(width: 8),
          const Text('MoonrideDrive', style: TextStyle(fontWeight: FontWeight.w800)),
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
        onDestinationSelected: (v) => setState(() => _tab = v),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'სამუშაო'),
          NavigationDestination(icon: Icon(Icons.notifications_outlined), selectedIcon: Icon(Icons.notifications), label: 'შეთავაზებები'),
          NavigationDestination(icon: Icon(Icons.directions_car_outlined), selectedIcon: Icon(Icons.directions_car), label: 'ავტომობილი'),
          NavigationDestination(icon: Icon(Icons.groups_2_outlined), selectedIcon: Icon(Icons.groups_2), label: 'STAFF GO'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'პროფილი'),
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

  Widget _head(String title) => Padding(
    padding: const EdgeInsets.fromLTRB(2, 18, 2, 8),
    child: Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
  );

  Widget _profileSummary() => Card(child: Padding(
    padding: const EdgeInsets.all(16),
    child: Row(children: [
      const MoonrideBrandMark(size: 48),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('მოგესალმები', style: TextStyle(color: MoonrideColors.muted)),
        Text((widget.profile['full_name'] ?? 'მძღოლი').toString(), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
        Text('მძღოლის სტატუსი: ' + (_driver?['approval_status'] ?? 'განაცხადი არ არის').toString(),
          style: const TextStyle(fontSize: 11, color: MoonrideColors.muted)),
      ])),
    ]),
  ));

  double? _rideNumber(Map<String, dynamic>? ride, List<String> keys) {
    if (ride == null) return null;
    for (final key in keys) {
      final value = ride[key];
      if (value is num) return value.toDouble();
      if (value is String) {
        final parsed = double.tryParse(value);
        if (parsed != null) return parsed;
      }
    }
    return null;
  }

  Widget _driverMap() {
    final lat = (_presence?['latitude'] as num?)?.toDouble();
    final lon = (_presence?['longitude'] as num?)?.toDouble();
    final ride = _activeRide;
    final pickupLat = _rideNumber(ride, ['pickup_latitude', 'pickup_lat']);
    final pickupLon = _rideNumber(ride, ['pickup_longitude', 'pickup_lng']);
    final dropLat = _rideNumber(ride, ['dropoff_latitude', 'destination_latitude', 'dropoff_lat']);
    final dropLon = _rideNumber(ride, ['dropoff_longitude', 'destination_longitude', 'dropoff_lng']);
    final center = lat != null && lon != null
        ? LatLng(lat, lon)
        : pickupLat != null && pickupLon != null
            ? LatLng(pickupLat, pickupLon)
            : const LatLng(41.6168, 41.6367);
    final markers = <Marker>[];
    if (lat != null && lon != null) {
      markers.add(Marker(point: LatLng(lat, lon), width: 42, height: 42,
        child: const Icon(Icons.navigation, color: MoonrideColors.blueBright, size: 34)));
    }
    if (pickupLat != null && pickupLon != null) {
      markers.add(Marker(point: LatLng(pickupLat, pickupLon), width: 42, height: 46,
        child: const Icon(Icons.trip_origin, color: Color(0xFF43C6FF), size: 34)));
    }
    if (dropLat != null && dropLon != null) {
      markers.add(Marker(point: LatLng(dropLat, dropLon), width: 42, height: 46,
        child: const Icon(Icons.location_on, color: Color(0xFFFFC928), size: 36)));
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: SizedBox(height: 280, child: Stack(children: [
        FlutterMap(
          options: MapOptions(initialCenter: center, initialZoom: 14, minZoom: 4, maxZoom: 19),
          children: [
            TileLayer(
              urlTemplate: _mapProvider == 'tomtom'
                  ? 'https://api.tomtom.com/map/1/tile/basic/main/{z}/{x}/{y}.png?key=$moonrideTomTomApiKey'
                  : _mapProvider == 'mapbox'
                      ? 'https://api.mapbox.com/styles/v1/mapbox/streets-v12/tiles/256/{z}/{x}/{y}?access_token=$moonrideMapboxAccessToken'
                      : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              maxNativeZoom: 19, userAgentPackageName: 'ge.moonride.drive'),
            if (markers.isNotEmpty) MarkerLayer(markers: markers),
            RichAttributionWidget(attributions: [
              TextSourceAttribution(_mapProvider == 'tomtom'
                  ? '© TomTom'
                  : _mapProvider == 'mapbox'
                      ? '© Mapbox © OpenStreetMap'
                      : '© OpenStreetMap contributors'),
            ]),
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
      ])),
    );
  }

  Widget _workPage() => RefreshIndicator(
    onRefresh: _load,
    child: ListView(padding: const EdgeInsets.all(16), children: [
      _profileSummary(),
      Card(child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          Row(children: [
            Icon(Icons.circle, size: 12, color: _online ? MoonrideColors.success : MoonrideColors.muted),
            const SizedBox(width: 8),
            Expanded(child: Text(_online ? 'ონლაინ რეჟიმი' : 'ოფლაინ რეჟიმი', style: const TextStyle(fontWeight: FontWeight.w800))),
            Text(_offers.length.toString() + ' შეთავაზება', style: const TextStyle(color: MoonrideColors.muted)),
          ]),
          const SizedBox(height: 14),
          SizedBox(width: double.infinity, child: FilledButton.icon(
            onPressed: (_approvedDriver && _approvedVehicle && !_busy) ? _toggleOnline : null,
            icon: Icon(_online ? Icons.pause_circle_outline : Icons.wifi),
            label: Text(_busy ? 'მუშავდება…' : _online ? 'ოფლაინ რეჟიმზე გადასვლა' : 'ონლაინ GO'),
          )),
          if (!_approvedDriver || !_approvedVehicle)
            const Padding(
              padding: EdgeInsets.only(top: 10),
              child: Text('ონლაინ რეჟიმისთვის საჭიროა დამტკიცებული მძღოლის პროფილი და ავტომობილი.',
                style: TextStyle(fontSize: 12, color: MoonrideColors.warning)),
            ),
        ]),
      )),
      _driverMap(),
      _head('მიმდინარე მგზავრობა'),
      if (_activeRide == null)
        const _InfoCard(text: 'აქტიური მგზავრობა ჯერ არ გაქვს.')
      else
        _rideCard(_activeRide!, action: true),
      _head('შემომავალი შეთავაზებები'),
      if (_offers.isEmpty)
        const _InfoCard(text: 'ახალი შეთავაზება არ არის.')
      else
        ..._offers.take(3).map(_offerCard),
    ]),
  );

  Widget _offersPage() => RefreshIndicator(
    onRefresh: _load,
    child: ListView(padding: const EdgeInsets.all(16), children: [
      _head('შეთავაზებები'),
      if (_offers.isEmpty) const _InfoCard(text: 'აქტიური შეთავაზებები არ არის.'),
      ..._offers.map(_offerCard),
    ]),
  );

  Widget _offerCard(Map<String, dynamic> offer) {
    Map<String, dynamic>? ride;
    for (final candidate in _offerRides) {
      if (candidate['id'] == offer['ride_id']) {
        ride = candidate;
        break;
      }
    }
    return Card(child: Padding(
    padding: const EdgeInsets.all(16),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Icon(Icons.local_taxi, color: MoonrideColors.blueBright),
        const SizedBox(width: 8),
        Expanded(child: Text('შეთავაზება #' + offer['id'].toString().substring(0, 8),
          style: const TextStyle(fontWeight: FontWeight.bold))),
        _Badge(text: (offer['status'] ?? 'sent').toString()),
      ]),
      if (ride != null) ...[
        const Divider(height: 20),
        _address(Icons.trip_origin, 'საიდან', ride['pickup_address']),
        _address(Icons.flag_outlined, 'სად', ride['dropoff_address']),
        const SizedBox(height: 6),
        Text(
          'სისტემის ფასი: ' + _money(ride['fare_amount']) + ' ' + (ride['currency_code'] ?? 'GEL').toString(),
          style: const TextStyle(fontWeight: FontWeight.w900, color: MoonrideColors.blueBright, fontSize: 18),
        ),
        Text('კატეგორია: ' + (ride['category_code'] ?? '—').toString() +
          ' • გადახდა: ' + (ride['payment_method'] ?? '—').toString(),
          style: const TextStyle(color: MoonrideColors.muted, fontSize: 11)),
      ] else
        const Padding(
          padding: EdgeInsets.only(top: 8),
          child: Text('მარშრუტის დეტალები ვერ ჩაიტვირთა.', style: TextStyle(color: MoonrideColors.warning, fontSize: 12)),
        ),
      const SizedBox(height: 7),
      Text('ვადა: ' + _date(offer['expires_at']), style: const TextStyle(color: MoonrideColors.muted, fontSize: 12)),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: OutlinedButton(onPressed: () => _respond(offer['id'].toString(), false), child: const Text('უარყოფა'))),
        const SizedBox(width: 10),
        Expanded(child: FilledButton(onPressed: () => _respond(offer['id'].toString(), true), child: const Text('მიღება'))),
      ]),
    ]),
  ));
  }

  Widget _vehiclePage() => RefreshIndicator(
    onRefresh: _load,
    child: ListView(padding: const EdgeInsets.all(16), children: [
      _head('მძღოლის განაცხადი'),
      if (_driver == null)
        _DriverApplicationForm(cities: _cities, onSubmitted: _load)
      else
        Card(child: ListTile(
          leading: const Icon(Icons.verified_user_outlined, color: MoonrideColors.blueBright),
          title: Text((_driver!['legal_first_name'] ?? '').toString() + ' ' + (_driver!['legal_last_name'] ?? '').toString()),
          subtitle: Text('სტატუსი: ' + (_driver!['approval_status'] ?? '—').toString()),
        )),
      _head('ჩემი ავტომობილები'),
      if (_vehicles.isEmpty) const _InfoCard(text: 'ავტომობილი ჯერ დამატებული არ არის.'),
      ..._vehicles.map((v) => Card(child: ListTile(
        leading: const Icon(Icons.directions_car, color: MoonrideColors.blueBright),
        title: Text((v['make'] ?? '').toString() + ' ' + (v['model'] ?? '').toString()),
        subtitle: Text((v['plate_number'] ?? 'ნომერი არ არის').toString() + ' • ' + (v['category_code'] ?? '').toString()),
        trailing: _Badge(text: (v['approval_status'] ?? 'pending').toString()),
      ))),
      _head('ახალი ავტომობილის განაცხადი'),
      _VehicleApplicationForm(categories: _categories, onSubmitted: _load),
      _head('დოკუმენტების ატვირთვა'),
      DropdownButtonFormField<String>(
        value: _selectedDocumentType,
        decoration: const InputDecoration(labelText: 'დოკუმენტის ტიპი'),
        items: const [
          DropdownMenuItem(value: 'identity_document', child: Text('პირადობის მოწმობა')),
          DropdownMenuItem(value: 'driving_license', child: Text('მართვის მოწმობა')),
          DropdownMenuItem(value: 'vehicle_registration', child: Text('ავტომობილის რეგისტრაცია')),
          DropdownMenuItem(value: 'permit', child: Text('ნებართვა')),
          DropdownMenuItem(value: 'insurance', child: Text('დაზღვევა')),
          DropdownMenuItem(value: 'technical_inspection', child: Text('ტექდათვალიერება')),
        ],
        onChanged: _uploadingDocument ? null : (value) {
          if (value != null) setState(() => _selectedDocumentType = value);
        },
      ),
      const SizedBox(height: 8),
      SizedBox(width: double.infinity, child: FilledButton.icon(
        onPressed: _uploadingDocument ? null : _uploadDriverDocument,
        icon: _uploadingDocument
            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.upload_file),
        label: Text(_uploadingDocument ? 'იტვირთება...' : 'დოკუმენტის არჩევა და ატვირთვა'),
      )),
      const _InfoCard(text: 'მხარდაჭერილია PDF/JPG/PNG/WEBP ფორმატები; მაქსიმუმ 10 MB. დოკუმენტი პირად, დაცულ საცავში ინახება.'),
      _head('დოკუმენტების სტატუსი'),
      if (_documents.isEmpty)
        const _InfoCard(text: 'ატვირთული დოკუმენტები ჯერ არ არის.'),
      ..._documents.map((d) => Card(child: ListTile(
        leading: const Icon(Icons.description_outlined, color: MoonrideColors.blueBright),
        title: Text((d['document_type'] ?? 'დოკუმენტი').toString()),
        subtitle: Text('სტატუსი: ' + (d['status'] ?? 'pending').toString() +
          ((d['rejection_reason'] == null) ? '' : ' • ' + d['rejection_reason'].toString())),
        trailing: Icon(d['status'] == 'approved' ? Icons.check_circle : d['status'] == 'rejected' ? Icons.cancel : Icons.hourglass_top,
          color: d['status'] == 'approved' ? MoonrideColors.success : MoonrideColors.warning),
      ))),
    ]),
  );

  Widget _profilePage() => ListView(padding: const EdgeInsets.all(16), children: [
    _profileSummary(),
    Card(child: Padding(
      padding: const EdgeInsets.all(15),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.account_balance_wallet_outlined, color: MoonrideColors.blueBright, size: 26),
          const SizedBox(width: 8),
          const Expanded(child: Text('მძღოლის Wallet', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17))),
          Text(_driverWalletBalance.toStringAsFixed(2) + ' GEL', style: const TextStyle(color: MoonrideColors.blueBright, fontWeight: FontWeight.w900)),
        ]),
        const SizedBox(height: 6),
        const Text('ბალანსი ირიცხება ადმინისტრატორის მიერ დადასტურებული შემოსავლით. გატანის მოთხოვნა იგზავნება MASTER ADMIN-თან.', style: TextStyle(color: MoonrideColors.muted, fontSize: 11)),
        const SizedBox(height: 8),
        SizedBox(width: double.infinity, child: FilledButton.icon(
          onPressed: _driverWalletBalance > 0 ? _requestPayout : null,
          icon: const Icon(Icons.account_balance),
          label: const Text('თანხის გატანის მოთხოვნა'),
        )),
        if (_payoutRequests.isNotEmpty) ...[
          const Divider(height: 18),
          const Text('ჩემი გატანის მოთხოვნები', style: TextStyle(fontWeight: FontWeight.bold)),
          ..._payoutRequests.map((p) => ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text((p['amount'] ?? '0').toString() + ' ' + (p['currency_code'] ?? 'GEL').toString() + ' • ' + (p['bank_code'] ?? '').toString().toUpperCase()),
            subtitle: Text('სტატუსი: ' + (p['status'] ?? 'pending').toString()),
          )),
        ],
        if (_driverWalletTransactions.isNotEmpty) ...[
          const Divider(height: 18),
          const Text('ბოლო ოპერაციები', style: TextStyle(fontWeight: FontWeight.bold)),
          ..._driverWalletTransactions.map((t) => ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text((t['transaction_type'] ?? '').toString()),
            subtitle: Text((t['note'] ?? '').toString()),
            trailing: Text((t['direction'] == 'credit' ? '+' : '-') + (t['amount'] ?? '0').toString() + ' GEL'),
          )),
        ],
      ]),
    )),
    Card(child: Column(children: [
      _profileTile(Icons.email_outlined, 'ელფოსტა', widget.profile['email']),
      _profileTile(Icons.phone_outlined, 'ტელეფონი', widget.profile['phone']),
      _profileTile(Icons.badge_outlined, 'როლი', widget.profile['role']),
      _profileTile(Icons.verified_user_outlined, 'მძღოლის სტატუსი', _driver?['approval_status']),
    ])),
    const SizedBox(height: 10),
    OutlinedButton.icon(onPressed: _signOut, icon: const Icon(Icons.logout), label: const Text('ანგარიშიდან გამოსვლა')),
  ]);

  Widget _profileTile(IconData icon, String title, dynamic value) => ListTile(
    leading: Icon(icon, color: MoonrideColors.blueBright),
    title: Text(title, style: const TextStyle(fontSize: 12, color: MoonrideColors.muted)),
    subtitle: Text((value ?? '—').toString()),
  );

  Widget _rideCard(Map<String, dynamic> ride, {bool action = false}) {
    final label = switch (ride['status']) {
      'accepted' => 'მძღოლი გზაშია',
      'driver_arriving' => 'ადგილზე ვარ',
      'arrived' => 'მგზავრობა დავიწყე',
      'in_progress' => 'მგზავრობა დავასრულე',
      _ => null,
    };
    return Card(child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.route, color: MoonrideColors.blueBright),
          const SizedBox(width: 8),
          Expanded(child: Text('მგზავრობა #' + ride['id'].toString().substring(0, 8),
            style: const TextStyle(fontWeight: FontWeight.bold))),
          _Badge(text: (ride['status'] ?? '').toString()),
        ]),
        const Divider(height: 20),
        _address(Icons.trip_origin, 'საიდან', ride['pickup_address']),
        _address(Icons.flag_outlined, 'სად', ride['dropoff_address']),
        const SizedBox(height: 8),
        Text(_money(ride['fare_amount']) + ' ' + (ride['currency_code'] ?? 'GEL').toString(),
          style: const TextStyle(fontSize: 20, color: MoonrideColors.blueBright, fontWeight: FontWeight.w900)),
        if (action && label != null) ...[
          const SizedBox(height: 12),
          SizedBox(width: double.infinity, child: OutlinedButton.icon(
            onPressed: () => _openNavigation(ride),
            icon: const Icon(Icons.navigation_outlined),
            label: const Text('ნავიგაციის დაწყება'),
          )),
          const SizedBox(height: 8),
          SizedBox(width: double.infinity, child: FilledButton(onPressed: () => _advance(ride), child: Text(label))),
        ],
      ]),
    ));
  }

  Widget _address(IconData icon, String title, dynamic value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(children: [
      Icon(icon, size: 16, color: MoonrideColors.muted),
      const SizedBox(width: 8),
      Text(title + ': ', style: const TextStyle(color: MoonrideColors.muted)),
      Expanded(child: Text((value ?? '—').toString())),
    ]),
  );

  String _date(dynamic value) {
    if (value == null) return '—';
    final dt = DateTime.tryParse(value.toString());
    return dt == null ? value.toString() : dt.toLocal().toString().substring(0, 16);
  }
  String _money(dynamic value) => double.tryParse((value ?? '').toString())?.toStringAsFixed(2) ?? '—';
}

class _DriverApplicationForm extends StatefulWidget {
  const _DriverApplicationForm({required this.cities, required this.onSubmitted});
  final List<Map<String, dynamic>> cities;
  final Future<void> Function() onSubmitted;
  @override
  State<_DriverApplicationForm> createState() => _DriverApplicationFormState();
}

class _DriverApplicationFormState extends State<_DriverApplicationForm> {
  final _first = TextEditingController();
  final _last = TextEditingController();
  final _birth = TextEditingController();
  final _license = TextEditingController();
  final _permit = TextEditingController();
  String? _city;
  bool _busy = false;
  @override
  void dispose() { _first.dispose(); _last.dispose(); _birth.dispose(); _license.dispose(); _permit.dispose(); super.dispose(); }

  Future<void> _submit() async {
    final year = int.tryParse(_birth.text);
    if (_first.text.trim().isEmpty || _last.text.trim().isEmpty || year == null || _city == null || _license.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('შეავსე ყველა აუცილებელი ველი.')));
      return;
    }
    setState(() => _busy = true);
    try {
      await Supabase.instance.client.rpc('go_submit_driver_application', params: {
        'p_first_name': _first.text.trim(),
        'p_last_name': _last.text.trim(),
        'p_birth_year': year,
        'p_work_city_id': _city,
        'p_license_number': _license.text.trim(),
        'p_permit_number': _permit.text.trim().isEmpty ? null : _permit.text.trim(),
      });
      await widget.onSubmitted();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('მძღოლის განაცხადი გაიგზავნა.')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('შეცდომა: ' + e.toString())));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Card(child: Padding(
    padding: const EdgeInsets.all(16),
    child: Column(children: [
      TextField(controller: _first, decoration: const InputDecoration(labelText: 'სახელი')),
      const SizedBox(height: 8),
      TextField(controller: _last, decoration: const InputDecoration(labelText: 'გვარი')),
      const SizedBox(height: 8),
      TextField(controller: _birth, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'დაბადების წელი')),
      const SizedBox(height: 8),
      TextField(controller: _license, decoration: const InputDecoration(labelText: 'მართვის მოწმობის ნომერი')),
      const SizedBox(height: 8),
      TextField(controller: _permit, decoration: const InputDecoration(labelText: 'ნებართვის ნომერი (არასავალდებულო)')),
      const SizedBox(height: 8),
      DropdownButtonFormField<String>(
        value: _city,
        decoration: const InputDecoration(labelText: 'სამუშაო ქალაქი'),
        items: widget.cities.map((c) => DropdownMenuItem(value: c['id'].toString(), child: Text(c['name'].toString()))).toList(),
        onChanged: (v) => setState(() => _city = v),
      ),
      const SizedBox(height: 14),
      SizedBox(width: double.infinity, child: FilledButton(
        onPressed: _busy ? null : _submit,
        child: Text(_busy ? 'იგზავნება…' : 'განაცხადის გაგზავნა'),
      )),
    ]),
  ));
}

class _VehicleApplicationForm extends StatefulWidget {
  const _VehicleApplicationForm({required this.categories, required this.onSubmitted});
  final List<Map<String, dynamic>> categories;
  final Future<void> Function() onSubmitted;
  @override
  State<_VehicleApplicationForm> createState() => _VehicleApplicationFormState();
}

class _VehicleApplicationFormState extends State<_VehicleApplicationForm> {
  final _make = TextEditingController();
  final _model = TextEditingController();
  final _year = TextEditingController();
  final _color = TextEditingController();
  final _plate = TextEditingController();
  final _capacity = TextEditingController(text: '4');
  String? _category;
  bool _busy = false;
  @override
  void dispose() { _make.dispose(); _model.dispose(); _year.dispose(); _color.dispose(); _plate.dispose(); _capacity.dispose(); super.dispose(); }

  Future<void> _submit() async {
    final year = int.tryParse(_year.text);
    final capacity = int.tryParse(_capacity.text);
    if (_make.text.trim().isEmpty || _model.text.trim().isEmpty || year == null || _plate.text.trim().isEmpty || capacity == null || _category == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('შეავსე ავტომობილის აუცილებელი ველები.')));
      return;
    }
    setState(() => _busy = true);
    try {
      await Supabase.instance.client.rpc('go_submit_vehicle_application', params: {
        'p_make': _make.text.trim(),
        'p_model': _model.text.trim(),
        'p_year': year,
        'p_color': _color.text.trim(),
        'p_plate_number': _plate.text.trim(),
        'p_category_code': _category,
        'p_passenger_capacity': capacity,
      });
      await widget.onSubmitted();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ავტომობილის განაცხადი გაიგზავნა.')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('შეცდომა: ' + e.toString())));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Card(child: Padding(
    padding: const EdgeInsets.all(16),
    child: Column(children: [
      TextField(controller: _make, decoration: const InputDecoration(labelText: 'მარკა')),
      const SizedBox(height: 8),
      TextField(controller: _model, decoration: const InputDecoration(labelText: 'მოდელი')),
      const SizedBox(height: 8),
      TextField(controller: _year, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'გამოშვების წელი')),
      const SizedBox(height: 8),
      TextField(controller: _color, decoration: const InputDecoration(labelText: 'ფერი')),
      const SizedBox(height: 8),
      TextField(controller: _plate, decoration: const InputDecoration(labelText: 'სახელმწიფო ნომერი')),
      const SizedBox(height: 8),
      TextField(controller: _capacity, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'ადგილების რაოდენობა')),
      const SizedBox(height: 8),
      DropdownButtonFormField<String>(
        value: _category,
        decoration: const InputDecoration(labelText: 'კატეგორია'),
        items: widget.categories.map((c) => DropdownMenuItem(value: c['code'].toString(), child: Text(c['name'].toString()))).toList(),
        onChanged: (v) => setState(() => _category = v),
      ),
      const SizedBox(height: 14),
      SizedBox(width: double.infinity, child: FilledButton(
        onPressed: _busy ? null : _submit,
        child: Text(_busy ? 'იგზავნება…' : 'ავტომობილის განაცხადის გაგზავნა'),
      )),
    ]),
  ));
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
    padding: const EdgeInsets.all(17),
    child: Row(children: [
      const Icon(Icons.info_outline, color: MoonrideColors.muted),
      const SizedBox(width: 10),
      Expanded(child: Text(text, style: const TextStyle(color: MoonrideColors.muted))),
    ]),
  ));
}
