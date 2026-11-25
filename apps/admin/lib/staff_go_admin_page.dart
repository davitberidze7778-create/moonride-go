import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:moonride_core/moonride_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class StaffGoAdminPage extends StatefulWidget {
  const StaffGoAdminPage({super.key, required this.userId});
  final String userId;

  @override
  State<StaffGoAdminPage> createState() => _StaffGoAdminPageState();
}

class _StaffGoAdminPageState extends State<StaffGoAdminPage> {
  final _db = Supabase.instance.client;
  final _search = TextEditingController();
  bool _loading = true;
  bool _busy = false;
  String? _error;
  String _section = 'orders';
  String _orderFilter = 'all';
  Map<String, dynamic>? _feature;
  List<Map<String, dynamic>> _cities = [];
  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _plans = [];
  List<Map<String, dynamic>> _pricing = [];
  List<Map<String, dynamic>> _orders = [];
  List<Map<String, dynamic>> _accounts = [];
  List<Map<String, dynamic>> _members = [];
  List<Map<String, dynamic>> _invoices = [];
  List<Map<String, dynamic>> _creditNotes = [];
  List<Map<String, dynamic>> _daily = [];
  List<Map<String, dynamic>> _corporateReports = [];
  List<Map<String, dynamic>> _driverSettings = [];

  List<Map<String, dynamic>> _maps(dynamic value) =>
      (value as List<dynamic>? ?? const []).whereType<Map<String, dynamic>>().toList();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (mounted) setState(() { _loading = true; _error = null; });
    try {
      final r = await Future.wait([
        _db.from('go_app_feature_flags').select('*').eq('feature_key', 'ride.staff_go').maybeSingle(),
        _db.from('cities').select('id,name,is_active,service_enabled').eq('is_active', true).order('name'),
        _db.from('vehicle_categories').select('id,code,name,is_active').eq('is_active', true).order('code'),
        _db.from('go_tariff_plans').select('city_id,currency_code,is_active,effective_from').eq('is_active', true).order('effective_from', ascending: false),
        _db.from('staff_go_pricing_rules').select('*').order('created_at', ascending: false),
        _db.from('staff_go_admin_order_report').select('*').order('request_created_at', ascending: false).limit(500),
        _db.from('staff_go_corporate_accounts').select('*').order('created_at', ascending: false).limit(300),
        _db.from('staff_go_corporate_members').select('*').order('created_at', ascending: false).limit(500),
        _db.from('staff_go_corporate_invoices').select('*').order('created_at', ascending: false).limit(300),
        _db.from('staff_go_corporate_credit_notes').select('*').order('created_at', ascending: false).limit(300),
        _db.from('staff_go_admin_daily_report').select('*').order('completed_day', ascending: false).limit(100),
        _db.from('staff_go_admin_corporate_report').select('*').order('report_month', ascending: false).limit(100),
        _db.from('staff_go_driver_settings').select('driver_user_id,is_enabled_by_driver,updated_at').order('updated_at', ascending: false).limit(300),
      ]);
      if (!mounted) return;
      setState(() {
        _feature = r[0] as Map<String, dynamic>?;
        _cities = _maps(r[1]);
        _categories = _maps(r[2]).where((c) => !['GROUP_RIDE_GO','MINIVAN_GO'].contains(c['code'])).toList();
        _plans = _maps(r[3]);
        _pricing = _maps(r[4]);
        _orders = _maps(r[5]);
        _accounts = _maps(r[6]);
        _members = _maps(r[7]);
        _invoices = _maps(r[8]);
        _creditNotes = _maps(r[9]);
        _daily = _maps(r[10]);
        _corporateReports = _maps(r[11]);
        _driverSettings = _maps(r[12]);
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

  bool get _enabled => _feature?['is_enabled'] == true && _feature?['is_available'] == true;
  String _currencyForCity(String cityId) {
    for (final plan in _plans) {
      if (plan['city_id'].toString() == cityId && plan['currency_code'] != null) {
        return plan['currency_code'].toString();
      }
    }
    return 'GEL';
  }

  Map<String, dynamic>? _findMap(List<Map<String, dynamic>> rows, bool Function(Map<String, dynamic>) test) {\n    for (final row in rows) { if (test(row)) return row; }\n    return null;\n  }\n\n  String _money(dynamic value) =>
      double.tryParse((value ?? '').toString())?.toStringAsFixed(2) ?? '0.00';

  String _cityName(String? id) {
    for (final city in _cities) {
      if (city['id'].toString() == id) return city['name'].toString();
    }
    return id ?? '—';
  }

  Future<void> _setFeature(bool enabled) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await _db.rpc('go_staff_go_admin_configure', params: {
        'p_enabled': enabled,
        'p_available': enabled,
        'p_config': (_feature?['config'] is Map<String, dynamic>) ? _feature!['config'] : <String, dynamic>{},
      });
      _message(enabled ? 'STAFF GO ჩაირთო.' : 'STAFF GO მთლიანად გამოირთო.');
      await _load();
    } catch (e) {
      _message('STAFF GO ვერ შეიცვალა: $e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _editPrice({Map<String, dynamic>? existing}) async {
    if (_cities.isEmpty || _categories.isEmpty) {
      _message('ჯერ საჭიროა აქტიური ქალაქი და კატეგორიები.', error: true);
      return;
    }
    String cityId = (existing?['city_id'] ?? _cities.first['id']).toString();
    String categoryId = (existing?['category_id'] ?? _categories.first['id']).toString();
    String method = (existing?['pricing_method'] ?? 'per_km').toString();
    String currency = (existing?['currency_code'] ?? _currencyForCity(cityId)).toString();
    final rate = TextEditingController(text: (existing?['rate_per_km'] ?? '0').toString());
    final base = TextEditingController(text: (existing?['base_fare'] ?? '0').toString());
    final extra = TextEditingController(text: (existing?['extra_address_fee'] ?? '0').toString());
    final minimum = TextEditingController(text: (existing?['minimum_fare'] ?? '0').toString());
    try {
      final ok = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (dialogContext, setDialogState) => AlertDialog(
            title: Text(existing == null ? 'STAFF GO ტარიფის დამატება' : 'STAFF GO ტარიფის შეცვლა'),
            content: SizedBox(width: 520, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
              DropdownButtonFormField<String>(
                value: cityId,
                decoration: const InputDecoration(labelText: 'ქალაქი'),
                items: _cities.map((c) => DropdownMenuItem(value: c['id'].toString(), child: Text(c['name'].toString()))).toList(),
                onChanged: existing == null ? (v) { if (v != null) setDialogState(() { cityId=v; currency=_currencyForCity(v); }); } : null,
              ),
              DropdownButtonFormField<String>(
                value: categoryId,
                decoration: const InputDecoration(labelText: 'ავტომობილის კატეგორია'),
                items: _categories.map((c) => DropdownMenuItem(value: c['id'].toString(), child: Text(c['code'].toString()))).toList(),
                onChanged: existing == null ? (v) { if (v != null) setDialogState(() => categoryId=v); } : null,
              ),
              DropdownButtonFormField<String>(
                value: method,
                decoration: const InputDecoration(labelText: 'ფასის ფორმულა'),
                items: const [
                  DropdownMenuItem(value: 'per_km', child: Text('მხოლოდ კილომეტრზე')),
                  DropdownMenuItem(value: 'base_plus_km_extra_address', child: Text('საწყისი + კმ + დამატებითი მისამართი')),
                ],
                onChanged: (v) { if (v != null) setDialogState(() => method=v); },
              ),
              Align(alignment: Alignment.centerLeft, child: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('ვალუტა: $currency', style: const TextStyle(color: MoonrideColors.muted)),
              )),
              TextField(controller: rate, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: 'ფასი კილომეტრზე ($currency)')),
              if (method == 'base_plus_km_extra_address') ...[
                TextField(controller: base, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: 'საწყისი ფასი ($currency)')),
                TextField(controller: extra, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: 'დამატებითი მისამართის ფასი ($currency)')),
              ],
              TextField(controller: minimum, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: 'მინიმალური ფასი ($currency)')),
              const SizedBox(height: 8),
              const _InfoCard(text: 'ტარიფი ცალკეა STAFF GO-სთვის. ჩვეულებრივი ECONOM და სხვა ტაქსის ტარიფები არ იცვლება.'),
            ]))),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext,false), child: const Text('გაუქმება')),
              FilledButton(onPressed: () => Navigator.pop(dialogContext,true), child: const Text('შენახვა')),
            ],
          ),
        ),
      );
      if (ok != true) return;
      double read(TextEditingController c,String label) {
        final v=double.tryParse(c.text.replaceAll(',','.'));
        if (v==null || v<0) throw Exception('არასწორი მნიშვნელობა: $label');
        return v;
      }
      final payload = <String,dynamic>{
        'city_id': cityId,
        'category_id': categoryId,
        'pricing_method': method,
        'currency_code': currency,
        'rate_per_km': read(rate,'rate_per_km'),
        'base_fare': method == 'per_km' ? 0 : read(base,'base_fare'),
        'extra_address_fee': method == 'per_km' ? 0 : read(extra,'extra_address_fee'),
        'minimum_fare': read(minimum,'minimum_fare'),
        'is_active': true,
        'effective_from': existing?['effective_from'] ?? DateTime.now().toUtc().toIso8601String(),
        'effective_until': null,
        'updated_by': widget.userId,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };
      if (existing != null) {
        await _db.from('staff_go_pricing_rules').update(payload).eq('id',existing['id']);
      } else {
        payload['created_by']=widget.userId;
        await _db.from('staff_go_pricing_rules').insert(payload);
      }
      _message('STAFF GO ტარიფი შენახულია.');
      await _load();
    } catch (e) {
      _message('ტარიფის შენახვა ვერ მოხერხდა: $e',error:true);
    } finally {
      rate.dispose();base.dispose();extra.dispose();minimum.dispose();
    }
  }

  Future<void> _togglePrice(Map<String,dynamic> row,bool active) async {
    try {
      await _db.from('staff_go_pricing_rules').update({
        'is_active':active,'updated_by':widget.userId,'updated_at':DateTime.now().toUtc().toIso8601String(),
      }).eq('id',row['id']);
      _message(active ? 'STAFF GO ტარიფი გააქტიურდა.' : 'STAFF GO ტარიფი გამოირთო.');
      await _load();
    } catch(e) { _message('ტარიფის სტატუსი ვერ შეიცვალა: $e',error:true); }
  }

  Future<void> _createCorporateAccount() async {
    if (_cities.isEmpty) { _message('აქტიური ქალაქი ვერ მოიძებნა.',error:true); return; }
    final company=TextEditingController();
    final legal=TextEditingController();
    final tax=TextEditingController();
    final email=TextEditingController();
    final phone=TextEditingController();
    final terms=TextEditingController(text:'30');
    String cityId=_cities.first['id'].toString();
    try {
      final ok=await showDialog<bool>(
        context:context,
        builder:(dialogContext)=>StatefulBuilder(builder:(dialogContext,setDialogState)=>AlertDialog(
          title:const Text('კორპორატიული ორგანიზაციის დამატება'),
          content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
            TextField(controller:company,decoration:const InputDecoration(labelText:'ორგანიზაციის სახელი')),
            TextField(controller:legal,decoration:const InputDecoration(labelText:'იურიდიული დასახელება')),
            TextField(controller:tax,decoration:const InputDecoration(labelText:'საიდენტიფიკაციო კოდი')),
            TextField(controller:email,decoration:const InputDecoration(labelText:'ბილინგის ელფოსტა')),
            TextField(controller:phone,decoration:const InputDecoration(labelText:'ტელეფონი')),
            DropdownButtonFormField<String>(
              value:cityId,decoration:const InputDecoration(labelText:'ქალაქი'),
              items:_cities.map((c)=>DropdownMenuItem(value:c['id'].toString(),child:Text(c['name'].toString()))).toList(),
              onChanged:(v){if(v!=null)setDialogState(()=>cityId=v);},
            ),
            TextField(controller:terms,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'გადახდის ვადა (დღე)')),
          ])),
          actions:[
            TextButton(onPressed:()=>Navigator.pop(dialogContext,false),child:const Text('გაუქმება')),
            FilledButton(onPressed:()=>Navigator.pop(dialogContext,true),child:const Text('შექმნა')),
          ],
        )),
      );
      if(ok!=true)return;
      if(company.text.trim().length<2)throw Exception('ორგანიზაციის სახელი აუცილებელია.');
      await _db.from('staff_go_corporate_accounts').insert({
        'company_name':company.text.trim(),
        'legal_name':legal.text.trim().isEmpty?null:legal.text.trim(),
        'tax_id':tax.text.trim().isEmpty?null:tax.text.trim(),
        'billing_email':email.text.trim().isEmpty?null:email.text.trim(),
        'billing_phone':phone.text.trim().isEmpty?null:phone.text.trim(),
        'city_id':cityId,
        'currency_code':_currencyForCity(cityId),
        'settlement_terms_days':int.tryParse(terms.text)??30,
        'status':'pending',
        'created_by':widget.userId,
      });
      _message('კორპორატიული ანგარიში დაემატა და დამტკიცებას ელოდება.');
      await _load();
    } catch(e) { _message('ორგანიზაციის დამატება ვერ მოხერხდა: $e',error:true); }
    finally { company.dispose();legal.dispose();tax.dispose();email.dispose();phone.dispose();terms.dispose(); }
  }

  Future<void> _addCorporateMember(Map<String,dynamic> account) async {
    final userId=TextEditingController();
    String role='requester';
    try {
      final ok=await showDialog<bool>(
        context:context,
        builder:(dialogContext)=>StatefulBuilder(builder:(dialogContext,setDialogState)=>AlertDialog(
          title:Text('წევრის დამატება • ${account['company_name']}'),
          content:Column(mainAxisSize:MainAxisSize.min,children:[
            TextField(controller:userId,decoration:const InputDecoration(labelText:'მომხმარებლის Profile UUID')),
            DropdownButtonFormField<String>(
              value:role,decoration:const InputDecoration(labelText:'უფლება'),
              items:const [
                DropdownMenuItem(value:'requester',child:Text('შეკვეთის შემქმნელი')),
                DropdownMenuItem(value:'manager',child:Text('ორგანიზაციის მენეჯერი')),
              ],
              onChanged:(v){if(v!=null)setDialogState(()=>role=v);},
            ),
          ]),
          actions:[
            TextButton(onPressed:()=>Navigator.pop(dialogContext,false),child:const Text('გაუქმება')),
            FilledButton(onPressed:()=>Navigator.pop(dialogContext,true),child:const Text('დამატება')),
          ],
        )),
      );
      if(ok!=true)return;
      await _db.from('staff_go_corporate_members').insert({
        'corporate_account_id':account['id'],'user_id':userId.text.trim(),
        'member_role':role,'status':'active',
      });
      _message('ორგანიზაციის წევრი დაემატა.');
      await _load();
    } catch(e) { _message('წევრის დამატება ვერ მოხერხდა: $e',error:true); }
    finally { userId.dispose(); }
  }

  Future<void> _reviewCorporate(Map<String,dynamic> account,String status) async {
    try {
      await _db.rpc('go_staff_go_admin_review_corporate_account',params:{
        'p_account_id':account['id'],'p_status':status,'p_note':'Reviewed by MASTER ADMIN',
      });
      _message('კორპორატიული ანგარიში: $status');
      await _load();
    } catch(e) { _message('ორგანიზაციის სტატუსი ვერ შეიცვალა: $e',error:true); }
  }

  Future<void> _setInvoiceStatus(Map<String,dynamic> invoice,String status) async {
    try {
      await _db.rpc('go_staff_go_admin_set_invoice_status',params:{
        'p_invoice_id':invoice['id'],'p_status':status,'p_note':'Updated by MASTER ADMIN',
      });
      _message('ინვოისის სტატუსი: $status');
      await _load();
    } catch(e) { _message('ინვოისი ვერ განახლდა: $e',error:true); }
  }

  Future<void> _cancelOrder(Map<String,dynamic> order) async {
    final reason=TextEditingController(text:'Cancelled by MASTER ADMIN');
    try {
      final ok=await showDialog<bool>(context:context,builder:(dialogContext)=>AlertDialog(
        title:const Text('STAFF GO შეკვეთის გაუქმება'),
        content:TextField(controller:reason,decoration:const InputDecoration(labelText:'მიზეზი')),
        actions:[
          TextButton(onPressed:()=>Navigator.pop(dialogContext,false),child:const Text('უკან')),
          FilledButton(onPressed:()=>Navigator.pop(dialogContext,true),child:const Text('გაუქმება')),
        ],
      ));
      if(ok!=true)return;
      await _db.rpc('go_staff_go_admin_cancel_order',params:{
        'p_order_id':order['order_id'],'p_reason':reason.text.trim(),
      });
      _message('STAFF GO შეკვეთა გაუქმდა.');
      await _load();
    } catch(e) { _message('შეკვეთა ვერ გაუქმდა: $e',error:true); }
    finally { reason.dispose(); }
  }

  Future<void> _exportCsv(List<Map<String,dynamic>> rows,String filename) async {
    if(rows.isEmpty){_message('ექსპორტისთვის ჩანაწერები არ არის.',error:true);return;}
    String cell(dynamic value) {
      final text=(value??'').toString().replaceAll('"','""');
      return '"$text"';
    }
    final keys=rows.first.keys.toList();
    final csv=[
      keys.map(cell).join(','),
      ...rows.map((row)=>keys.map((key)=>cell(row[key])).join(',')),
    ].join('\n');
    await Clipboard.setData(ClipboardData(text:csv));
    _message('$filename CSV დაკოპირდა. ჩასვი Excel-ში ან Google Sheets-ში.');
  }

  @override
  Widget build(BuildContext context) {
    if(_loading)return const Center(child:CircularProgressIndicator());
    if(_error!=null)return ListView(padding:const EdgeInsets.all(16),children:[
      _InfoCard(text:'STAFF GO admin მონაცემები ვერ ჩაიტვირთა: $_error'),
      FilledButton(onPressed:_load,child:const Text('ხელახლა ცდა')),
    ]);
    return RefreshIndicator(onRefresh:_load,child:ListView(padding:const EdgeInsets.all(16),children:[
      Card(child:Padding(padding:const EdgeInsets.all(15),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Row(children:[
          const Icon(Icons.groups_2,size:32,color:MoonrideColors.blueBright),
          const SizedBox(width:9),
          const Expanded(child:Text('STAFF GO • MASTER ADMIN',style:TextStyle(fontWeight:FontWeight.w900,fontSize:17))),
          _Badge(text:_enabled?'აქტიური':'გამორთული'),
        ]),
        const SizedBox(height:6),
        const Text('დამოუკიდებელი კორპორატიული სერვისი. ჩვეულებრივი ტაქსის შეკვეთები და ტარიფები უცვლელია.',
          style:TextStyle(fontSize:11,color:MoonrideColors.muted)),
        SwitchListTile(
          contentPadding:EdgeInsets.zero,
          value:_enabled,
          onChanged:_busy?null:_setFeature,
          title:const Text('STAFF GO გლობალური ჩართვა'),
          subtitle:Text(_enabled?'მგზავრებსა და მძღოლებს სერვისი ხელმისაწვდომი აქვთ.':'ჩართვამდე ექვსივე კატეგორიაზე აქტიური ტარიფი უნდა არსებობდეს.'),
        ),
      ]))),
      SingleChildScrollView(scrollDirection:Axis.horizontal,child:Row(children:[
        _sectionButton('orders','შეკვეთები'),
        _sectionButton('pricing','ტარიფები'),
        _sectionButton('companies','ორგანიზაციები'),
        _sectionButton('invoices','ინვოისები'),
        _sectionButton('reports','ანგარიშები'),
      ])),
      const SizedBox(height:8),
      if(_section=='orders')_ordersSection(),
      if(_section=='pricing')_pricingSection(),
      if(_section=='companies')_companiesSection(),
      if(_section=='invoices')_invoicesSection(),
      if(_section=='reports')_reportsSection(),
    ]));
  }

  Widget _sectionButton(String value,String label)=>Padding(
    padding:const EdgeInsets.only(right:6),
    child: ChoiceChip(label:Text(label),selected:_section==value,onSelected:(_)=>setState(()=>_section=value)),
  );

  Widget _ordersSection() {
    final q=_search.text.trim().toLowerCase();
    final rows=_orders.where((o){
      final status=o['status'].toString();
      final matches=[o['company_name'],o['pickup_address'],o['category_code'],o['driver_first_name'],o['driver_last_name']]
        .any((v)=>(v??'').toString().toLowerCase().contains(q));
      return matches&&(_orderFilter=='all'||status==_orderFilter);
    }).toList();
    return Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      _heading('STAFF GO შეკვეთების მართვა','ცალკე მანქანის შეკვეთები დამოუკიდებელ სტატუსებად ჩანს.'),
      TextField(controller:_search,onChanged:(_)=>setState((){}),decoration:const InputDecoration(prefixIcon:Icon(Icons.search),labelText:'ორგანიზაცია, მისამართი, კატეგორია ან მძღოლი')),
      const SizedBox(height:8),
      SingleChildScrollView(scrollDirection:Axis.horizontal,child:Row(children:[
        for(final item in const [('all','ყველა'),('requested','ახალი'),('dispatching','ძიება'),('accepted','მიღებული'),('in_progress','მიმდინარე'),('completed','დასრულებული'),('no_driver','მძღოლი ვერ მოიძებნა'),('cancelled','გაუქმებული')])
          Padding(padding:const EdgeInsets.only(right:5),child:ChoiceChip(label:Text(item.$2),selected:_orderFilter==item.$1,onSelected:(_)=>setState(()=>_orderFilter=item.$1))),
      ])),
      Align(alignment:Alignment.centerRight,child:TextButton.icon(onPressed:()=>_exportCsv(rows,'STAFF_GO_ORDERS'),icon:const Icon(Icons.download),label:const Text('CSV ექსპორტი'))),
      if(rows.isEmpty)const _InfoCard(text:'STAFF GO შეკვეთები არ მოიძებნა.'),
      ...rows.map((o)=>Card(child:Padding(padding:const EdgeInsets.all(13),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Row(children:[Expanded(child:Text('${o['company_name']} • ${o['category_code']}',style:const TextStyle(fontWeight:FontWeight.w800))),_Badge(text:o['status'].toString())]),
        Text('საიდან: ${o['pickup_address']??'—'}'),
        Text('მისამართები: ${o['destination_addresses']??'—'}'),
        Text('მძღოლი: ${((o['driver_first_name']??'')+' '+(o['driver_last_name']??'')).toString()} • ${o['city_name']}'),
        Text('ფასი: ${_money(o['fare_amount'])} ${o['currency_code']} • გადახდა: ${o['payment_method']} • ${o['payment_status']}',
          style:const TextStyle(color:MoonrideColors.blueBright,fontWeight:FontWeight.w800)),
        if(!['completed','cancelled'].contains(o['status']))Align(alignment:Alignment.centerRight,child:TextButton.icon(
          onPressed:()=>_cancelOrder(o),icon:const Icon(Icons.cancel_outlined,color:MoonrideColors.danger),label:const Text('გაუქმება'))),
      ])))),
    ]);
  }

  Widget _pricingSection() {
    return Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      _heading('STAFF GO ტარიფები','ექვსი კატეგორია • თითო ქალაქზე ცალკე ფასი • ჩვეულებრივი ტარიფებისგან დამოუკიდებლად.'),
      SizedBox(width:double.infinity,child:FilledButton.icon(onPressed:()=>_editPrice(),icon:const Icon(Icons.add),label:const Text('ტარიფის დამატება'))),
      if(_pricing.isEmpty)const _InfoCard(text:'STAFF GO ტარიფები ჯერ არ არის შევსებული. მომსახურების ჩართვა შეუძლებელი იქნება, სანამ ექვსივე კატეგორია არ შეივსება.'),
      ..._pricing.map((p){
        final cat=_findMap(_categories,(c)=>c['id'].toString()==p['category_id'].toString());
        return Card(child:Padding(padding:const EdgeInsets.all(12),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Row(children:[Expanded(child:Text('${_cityName(p['city_id']?.toString())} • ${cat?['code']??'კატეგორია'}',style:const TextStyle(fontWeight:FontWeight.w800))),_Badge(text:p['is_active']==true?'active':'inactive')]),
          Text(p['pricing_method']=='per_km'
            ? '${_money(p['rate_per_km'])} ${p['currency_code']}/კმ • მინ. ${_money(p['minimum_fare'])}'
            : 'საწყისი ${_money(p['base_fare'])} + ${_money(p['rate_per_km'])}/კმ + ${_money(p['extra_address_fee'])} / დამატებითი მისამართი'),
          Wrap(spacing:6,children:[
            TextButton.icon(onPressed:()=>_editPrice(existing:p),icon:const Icon(Icons.edit),label:const Text('რედაქტირება')),
            Switch(value:p['is_active']==true,onChanged:(v)=>_togglePrice(p,v)),
          ]),
        ])));
      }),
    ]);
  }

  Widget _companiesSection() {
    return Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      _heading('კორპორატიული ორგანიზაციები','ანგარიშის დამტკიცება და უფლებამოსილი თანამშრომლების მართვა.'),
      SizedBox(width:double.infinity,child:FilledButton.icon(onPressed:_createCorporateAccount,icon:const Icon(Icons.add_business),label:const Text('ორგანიზაციის დამატება'))),
      if(_accounts.isEmpty)const _InfoCard(text:'ორგანიზაცია ჯერ არ არის დამატებული.'),
      ..._accounts.map((a){
        final members=_members.where((m)=>m['corporate_account_id'].toString()==a['id'].toString()).toList();
        return Card(child:Padding(padding:const EdgeInsets.all(13),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Row(children:[Expanded(child:Text(a['company_name'].toString(),style:const TextStyle(fontWeight:FontWeight.w800))),_Badge(text:a['status'].toString())]),
          Text('ქალაქი: ${_cityName(a['city_id']?.toString())} • ${a['currency_code']} • გადახდის ვადა: ${a['settlement_terms_days']} დღე'),
          Text('წევრები: ${members.length} • საიდენტიფიკაციო კოდი: ${a['tax_id']??'—'}',style:const TextStyle(fontSize:11,color:MoonrideColors.muted)),
          Wrap(spacing:6,children:[
            if(a['status']!='approved')OutlinedButton(onPressed:()=>_reviewCorporate(a,'approved'),child:const Text('დამტკიცება')),
            if(a['status']!='rejected')TextButton(onPressed:()=>_reviewCorporate(a,'rejected'),child:const Text('უარყოფა')),
            if(a['status']!='suspended')TextButton(onPressed:()=>_reviewCorporate(a,'suspended'),child:const Text('შეჩერება')),
            OutlinedButton.icon(onPressed:()=>_addCorporateMember(a),icon:const Icon(Icons.person_add_alt),label:const Text('წევრის დამატება')),
          ]),
          ...members.map((m)=>Text('• ${m['user_id']} • ${m['member_role']} • ${m['status']}',style:const TextStyle(fontSize:10,color:MoonrideColors.muted))),
        ])));
      }),
    ]);
  }

  Widget _invoicesSection() {
    return Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      _heading('კორპორატიული ინვოისები და კრედიტ-ნოტები','ანგარიშსწორება ორგანიზაციების მიხედვით.'),
      if(_invoices.isEmpty)const _InfoCard(text:'ინვოისი ჯერ არ შექმნილა.'),
      ..._invoices.map((i)=>Card(child:Padding(padding:const EdgeInsets.all(12),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Row(children:[Expanded(child:Text(i['invoice_number'].toString(),style:const TextStyle(fontWeight:FontWeight.w800))),_Badge(text:i['status'].toString())]),
        Text('${_money(i['subtotal'])} ${i['currency_code']} • ვადა: ${i['due_at']??'—'}'),
        Wrap(spacing:5,children:[
          if(i['status']!='paid')OutlinedButton(onPressed:()=>_setInvoiceStatus(i,'paid'),child:const Text('გადახდილი')),
          if(i['status']=='issued')TextButton(onPressed:()=>_setInvoiceStatus(i,'overdue'),child:const Text('ვადაგადაცილებული')),
          if(i['status']!='paid'&&i['status']!='void')TextButton(onPressed:()=>_setInvoiceStatus(i,'void'),child:const Text('გაუქმება')),
        ]),
      ])))),
      _heading('კრედიტ-ნოტები'),
      if(_creditNotes.isEmpty)const _InfoCard(text:'კრედიტ-ნოტები არ არის.'),
      ..._creditNotes.map((n)=>Card(child:ListTile(
        leading:const Icon(Icons.receipt_long_outlined,color:MoonrideColors.blueBright),
        title:Text('${_money(n['amount'])} ${n['currency_code']} • ${n['status']}'),
        subtitle:Text(n['reason'].toString()),
      ))),
    ]);
  }

  Widget _reportsSection() {
    return Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      _heading('დღიური ანგარიშები','დასრულებული შეკვეთები და შემოსავალი ქალაქის/კატეგორიის მიხედვით.'),
      Align(alignment:Alignment.centerRight,child:TextButton.icon(onPressed:()=>_exportCsv(_daily,'STAFF_GO_DAILY_REPORT'),icon:const Icon(Icons.download),label:const Text('დღიური CSV'))),
      if(_daily.isEmpty)const _InfoCard(text:'დღიური ანგარიშის მონაცემები ჯერ არ არის.'),
      ..._daily.take(30).map((d)=>Card(child:ListTile(
        title:Text('${d['city_name']} • ${d['category_code']}'),
        subtitle:Text('${d['completed_day']} • ${d['completed_orders']} შეკვეთა'),
        trailing:Text('${_money(d['gross_revenue'])} ${d['currency_code']}',style:const TextStyle(color:MoonrideColors.blueBright,fontWeight:FontWeight.w800)),
      ))),
      _heading('ორგანიზაციების ფინანსური ანგარიში'),
      Align(alignment:Alignment.centerRight,child:TextButton.icon(onPressed:()=>_exportCsv(_corporateReports,'STAFF_GO_CORPORATE_REPORT'),icon:const Icon(Icons.download),label:const Text('ორგანიზაციების CSV'))),
      if(_corporateReports.isEmpty)const _InfoCard(text:'კორპორატიული ანგარიშის მონაცემები ჯერ არ არის.'),
      ..._corporateReports.take(50).map((r)=>Card(child:Padding(padding:const EdgeInsets.all(12),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text(r['organization_name'].toString(),style:const TextStyle(fontWeight:FontWeight.w800)),
        Text('${r['report_month']} • ${r['city_name']} • ${r['currency_code']}'),
        Text('მოთხოვნები: ${r['request_count']} • დასრულებული: ${r['completed_order_count']}'),
        Text('ბრუნვა: ${_money(r['completed_revenue'])} • ინვოისი: ${_money(r['invoiced_amount'])} • გადახდილი: ${_money(r['paid_amount'])} • ვადაგადაცილებული: ${_money(r['overdue_amount'])}'),
        Text('კრედიტ-ნოტები: ${_money(r['credit_note_amount'])}',style:const TextStyle(color:MoonrideColors.muted,fontSize:11)),
      ])))),
      _heading('მძღოლების STAFF GO სტატუსი'),
      if(_driverSettings.isEmpty)const _InfoCard(text:'მძღოლებს STAFF GO ჯერ არ ჩაურთავთ.'),
      ..._driverSettings.take(50).map((d)=>ListTile(
        dense:true,
        leading:Icon(d['is_enabled_by_driver']==true?Icons.toggle_on:Icons.toggle_off,color:d['is_enabled_by_driver']==true?MoonrideColors.blueBright:MoonrideColors.muted),
        title:Text(d['driver_user_id'].toString()),
        subtitle:Text('განახლდა: ${d['updated_at']}'),
        trailing:_Badge(text:d['is_enabled_by_driver']==true?'ჩართულია':'გამორთულია'),
      )),
    ]);
  }

  Widget _heading(String title,String subtitle)=>Padding(
    padding:const EdgeInsets.fromLTRB(2,16,2,8),
    child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Text(title,style:const TextStyle(fontSize:17,fontWeight:FontWeight.w900)),
      Text(subtitle,style:const TextStyle(fontSize:11,color:MoonrideColors.muted)),
    ]),
  );
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text});
  final String text;
  @override
  Widget build(BuildContext context)=>DecoratedBox(
    decoration:BoxDecoration(
      color:MoonrideColors.blue.withValues(alpha:0.18),
      borderRadius:BorderRadius.circular(30),
      border:Border.all(color:MoonrideColors.blueBright.withValues(alpha:0.35)),
    ),
    child:Padding(
      padding:const EdgeInsets.symmetric(horizontal:10,vertical:5),
      child:Text(text,style:const TextStyle(fontSize:10,color:MoonrideColors.ice)),
    ),
  );
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.text});
  final String text;
  @override
  Widget build(BuildContext context)=>Card(child:Padding(
    padding:const EdgeInsets.all(14),
    child:Row(children:[
      const Icon(Icons.info_outline,color:MoonrideColors.muted),
      const SizedBox(width:8),
      Expanded(child:Text(text,style:const TextStyle(color:MoonrideColors.muted))),
    ]),
  ));
}
