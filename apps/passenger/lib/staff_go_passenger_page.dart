import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

const _staffNavy = Color(0xFF071B34);
const _staffPanel = Color(0xFF102E52);
const _staffBlue = Color(0xFF247FE5);

class StaffGoPassengerPage extends StatefulWidget {
  const StaffGoPassengerPage({
    super.key, required this.userId, required this.cityId, required this.currencyCode,
    required this.pickupLatitude, required this.pickupLongitude, required this.pickupAddress,
    required this.tomtomApiKey,
  });
  final String userId;
  final String cityId;
  final String currencyCode;
  final double pickupLatitude;
  final double pickupLongitude;
  final String pickupAddress;
  final String tomtomApiKey;

  @override
  State<StaffGoPassengerPage> createState() => _StaffGoPassengerPageState();
}

class _StaffGoPassengerPageState extends State<StaffGoPassengerPage> {
  final _db = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _company = TextEditingController();
  final _passengerCount = TextEditingController(text: '1');
  final _passengerNames = TextEditingController();
  final _pickup = TextEditingController();
  final List<_StaffDestination> _destinations = [_StaffDestination()];
  bool _loading = true;
  bool _busy = false;
  bool _enabled = false;
  String? _error;
  String? _requestId;
  String _mode = 'single_vehicle_route';
  String _payment = 'cash';
  String? _categoryId;
  String? _corporateAccountId;
  Map<String, dynamic>? _quote;
  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _corporateAccounts = [];

  List<Map<String, dynamic>> _maps(dynamic value) =>
      (value as List<dynamic>? ?? const []).whereType<Map<String, dynamic>>().toList();

  @override
  void initState() {
    super.initState();
    _pickup.text = widget.pickupAddress;
    _load();
  }

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _company.dispose();
    _passengerCount.dispose();
    _passengerNames.dispose();
    _pickup.dispose();
    for (final item in _destinations) { item.dispose(); }
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        _db.from('profiles').select('full_name').eq('id', widget.userId).maybeSingle(),
        _db.from('go_app_feature_flags').select('is_enabled,is_available').eq('feature_key','ride.staff_go').maybeSingle(),
        _db.from('vehicle_categories').select('id,code,name').eq('is_active',true).order('code'),
        _db.from('staff_go_corporate_members').select('corporate_account_id').eq('user_id',widget.userId).eq('status','active'),
      ]);
      final profile = results[0] as Map<String,dynamic>?;
      final feature = results[1] as Map<String,dynamic>?;
      final categories = _maps(results[2]).where((c)=>!['GROUP_RIDE_GO','MINIVAN_GO'].contains(c['code'])).toList();
      final memberRows = _maps(results[3]);
      final accountIds = memberRows.map((m)=>m['corporate_account_id'].toString()).toSet().toList();
      final accounts = accountIds.isEmpty ? <Map<String,dynamic>>[] : _maps(
        await _db.from('staff_go_corporate_accounts')
          .select('id,company_name,currency_code,status').inFilter('id',accountIds).eq('status','approved')
      );
      if(!mounted)return;
      final name=(profile?['full_name']??'').toString().trim().split(' ');
      setState((){
        if(name.isNotEmpty)_firstName.text=name.first;
        if(name.length>1)_lastName.text=name.skip(1).join(' ');
        _enabled=feature?['is_enabled']==true&&feature?['is_available']==true;
        _categories=categories;
        _corporateAccounts=accounts;
        if(_categories.isNotEmpty)_categoryId=_categories.first['id'].toString();
        _loading=false;
      });
    }catch(e){
      if(mounted)setState(()=>_error=e.toString());
      if(mounted)setState(()=>_loading=false);
    }
  }

  void _message(String text,{bool error=false}){
    if(!mounted)return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content:Text(text),backgroundColor:error?Colors.red.shade800:_staffPanel,
    ));
  }

  void _invalidateQuote(){
    if(_quote!=null||_requestId!=null)setState(()=>_quote=null);
  }

  Future<void> _searchDestination(_StaffDestination item) async {
    final query=item.controller.text.trim();
    if(query.length<3){setState(()=>item.error='შეიყვანე მინიმუმ 3 სიმბოლო.');return;}
    if(widget.tomtomApiKey.isEmpty){setState(()=>item.error='TomTom API key არ არის დაყენებული.');return;}
    setState(()=>item.searching=true);
    try{
      final uri=Uri.https('api.tomtom.com','/search/2/search/$query.json',{
        'key':widget.tomtomApiKey,'limit':'5','language':'ka',
        'lat':widget.pickupLatitude.toString(),'lon':widget.pickupLongitude.toString(),'radius':'50000',
      });
      final response=await http.get(uri).timeout(const Duration(seconds:15));
      if(response.statusCode!=200)throw Exception('TomTom მისამართის ძებნა ვერ შესრულდა.');
      final decoded=jsonDecode(response.body) as Map<String,dynamic>;
      final rows=decoded['results'] as List<dynamic>? ?? [];
      final results=< _StaffPlace >[];
      for(final raw in rows.take(5)){
        if(raw is! Map)continue;
        final data=Map<String,dynamic>.from(raw);
        final position=data['position'];
        if(position is! Map)continue;
        final pos=Map<String,dynamic>.from(position);
        final addressValue=data['address'];
        final address=addressValue is Map?Map<String,dynamic>.from(addressValue):<String,dynamic>{};
        final poiValue=data['poi'];
        final poi=poiValue is Map?Map<String,dynamic>.from(poiValue):<String,dynamic>{};
        final lat=pos['lat'];final lon=pos['lon'];
        if(lat is! num||lon is! num)continue;
        final title=(poi['name']??address['freeformAddress']??query).toString();
        final full=(address['freeformAddress']??title).toString();
        results.add(_StaffPlace(title:title,address:full,latitude:lat.toDouble(),longitude:lon.toDouble()));
      }
      if(!mounted)return;
      setState(()=>item.results=results);
      if(results.isEmpty)setState(()=>item.error='მისამართი ვერ მოიძებნა.');
    }catch(e){
      if(mounted)setState(()=>item.error=e.toString().replaceFirst('Exception: ',''));
    }finally{
      if(mounted)setState(()=>item.searching=false);
    }
  }

  void _chooseDestination(_StaffDestination item,_StaffPlace place){
    setState((){
      item.place=place;item.controller.text=place.title;item.results=[];item.error=null;
      _quote=null;_requestId=null;
    });
  }

  void _addDestination(){
    if(_destinations.length>=5)return;
    setState(()=>_destinations.add(_StaffDestination()));
  }

  void _removeDestination(int index){
    if(_destinations.length<=1)return;
    setState((){
      final item=_destinations.removeAt(index);item.dispose();_quote=null;_requestId=null;
    });
  }

  Future<void> _createAndQuote() async {
    if(!_formKey.currentState!.validate())return;
    if(!_enabled){_message('STAFF GO ჯერ არ არის ჩართული MASTER ADMIN-ის მიერ.',error:true);return;}
    if(_destinations.any((d)=>d.place==null)){
      _message('აირჩიე ყველა მისამართი TomTom-ის ძებნის შედეგებიდან.',error:true);return;
    }
    if(_payment=='corporate'&&_corporateAccountId==null){
      _message('კორპორატიული ანგარიშსწორებისთვის დამტკიცებული ორგანიზაციაა საჭირო.',error:true);return;
    }
    if(_categoryId==null){_message('აირჩიე ავტომობილის კატეგორია.',error:true);return;}

    setState(()=>_busy=true);
    try{
      if(_requestId==null){
        final account=_corporateAccounts.where((a)=>a['id'].toString()==_corporateAccountId).firstOrNull;
        final companyName=account?['company_name']?.toString()??_company.text.trim();
        final names=_passengerNames.text.split('\n').map((s)=>s.trim()).where((s)=>s.isNotEmpty).toList();
        final payload=<String,dynamic>{
          'requester_first_name':_firstName.text.trim(),
          'requester_last_name':_lastName.text.trim(),
          'company_name':companyName,
          'request_mode':_mode,
          'pickup_address':_pickup.text.trim(),
          'pickup_latitude':widget.pickupLatitude,
          'pickup_longitude':widget.pickupLongitude,
          'city_id':widget.cityId,
          'currency_code':widget.currencyCode,
          'payment_method':_payment,
          'passenger_count':int.tryParse(_passengerCount.text.trim())??1,
          'passenger_names':names,
          'corporate_account_id':_payment=='corporate'?_corporateAccountId:null,
          'destinations':_destinations.map((d)=>({
            'address_label':d.place!.title,
            'address_text':d.place!.address,
            'latitude':d.place!.latitude,
            'longitude':d.place!.longitude,
          })).toList(),
        };
        final requestResult=await _db.rpc('go_staff_go_create_request',params:{'p_payload':payload});
        final requestData=requestResult is Map?Map<String,dynamic>.from(requestResult):<String,dynamic>{};
        _requestId=requestData['request_id']?.toString();
        if(_requestId==null)throw Exception('STAFF GO request_id არ დაბრუნდა.');
      }

      final quoteResponse=await _db.functions.invoke('staff-go-quote',body:{
        'requestId':_requestId,'categoryId':_categoryId,
      });
      final quotePayload=quoteResponse.data;
      if(quoteResponse.status<200||quoteResponse.status>=300||quotePayload is! Map){
        final detail=quotePayload is Map?(quotePayload['error']??'TomTom quote failed').toString():'TomTom quote failed';
        throw Exception(detail);
      }
      if(!mounted)return;
      setState(()=>_quote=Map<String,dynamic>.from(quotePayload as Map));
      _message('STAFF GO ფასი გამოითვალა. გადაამოწმე და დაადასტურე შეკვეთა.');
    }catch(e){
      _message('STAFF GO შეთავაზება ვერ შეიქმნა: $e',error:true);
    }finally{
      if(mounted)setState(()=>_busy=false);
    }
  }

  Future<void> _confirmQuote() async {
    final quoteId=_quote?['quoteId']?.toString();
    if(quoteId==null)return;
    setState(()=>_busy=true);
    try{
      final result=await _db.rpc('go_staff_go_accept_quote',params:{'p_quote_id':quoteId});
      final data=result is Map?Map<String,dynamic>.from(result):<String,dynamic>{};
      if(data['success']!=true)throw Exception('შეკვეთის დადასტურება ვერ მოხერხდა.');
      if(!mounted)return;
      final invoice=data['invoice_number']?.toString();
      setState(()=>_quote=null);
      _message(invoice==null?'STAFF GO შეკვეთა მიღებულია.':'STAFF GO შეკვეთა მიღებულია. ინვოისი: $invoice');
      Navigator.of(context).pop(true);
    }catch(e){
      _message('შეკვეთა ვერ დადასტურდა: $e',error:true);
    }finally{
      if(mounted)setState(()=>_busy=false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if(_loading)return const Scaffold(backgroundColor:_staffNavy,body:Center(child:CircularProgressIndicator()));
    return Scaffold(
      backgroundColor:_staffNavy,
      appBar:AppBar(backgroundColor:_staffNavy,title:const Text('STAFF GO',style:TextStyle(fontWeight:FontWeight.w900))),
      body:SafeArea(child:RefreshIndicator(onRefresh:_load,child:ListView(padding:const EdgeInsets.all(16),children:[
        Card(child:Padding(padding:const EdgeInsets.all(15),child:Row(children:[
          const Icon(Icons.groups_2,size:34,color:_staffBlue),const SizedBox(width:10),
          const Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Text('კორპორატიული მგზავრობა',style:TextStyle(fontSize:17,fontWeight:FontWeight.w900)),
            Text('დამოუკიდებელი სერვისი • 1–5 მისამართი',style:TextStyle(color:Colors.white60,fontSize:11)),
          ])),
          Icon(_enabled?Icons.check_circle:Icons.lock_outline,color:_enabled?Colors.lightGreenAccent:Colors.white54),
        ]))),
        if(!_enabled)const _InfoCard(text:'STAFF GO ამჟამად გამორთულია. MASTER ADMIN ჯერ ამზადებს ტარიფებს და სერვისს.'),
        if(_error!=null)_InfoCard(text:'მონაცემების ჩატვირთვა: $_error'),
        Form(key:_formKey,child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          _heading('მთავარი საკონტაქტო პირი'),
          TextFormField(controller:_firstName,decoration:const InputDecoration(labelText:'სახელი'),validator:(v)=>v==null||v.trim().isEmpty?'სახელი აუცილებელია.':null,onChanged:(_){_requestId=null;_quote=null;}),
          const SizedBox(height:8),
          TextFormField(controller:_lastName,decoration:const InputDecoration(labelText:'გვარი'),validator:(v)=>v==null||v.trim().isEmpty?'გვარი აუცილებელია.':null,onChanged:(_){_requestId=null;_quote=null;}),
          const SizedBox(height:8),
          TextFormField(controller:_company,decoration:const InputDecoration(labelText:'ორგანიზაცია / კომპანია'),validator:(v)=>_payment=='corporate'?null:(v==null||v.trim().length<2?'ორგანიზაციის სახელი აუცილებელია.':null),onChanged:(_){_requestId=null;_quote=null;}),
          _heading('აყვანის ადგილი'),
          TextFormField(controller:_pickup,readOnly:true,decoration:const InputDecoration(prefixIcon:Icon(Icons.my_location),labelText:'აყვანის მისამართი')),
          const SizedBox(height:8),
          _heading('მისამართები • მაქსიმუმ 5'),
          ..._destinations.asMap().entries.map((entry)=>_destinationEditor(entry.key,entry.value)),
          if(_destinations.length<5)Align(alignment:Alignment.centerLeft,child:TextButton.icon(onPressed:_quote==null?_addDestination:null,icon:const Icon(Icons.add_location_alt),label:const Text('დამატებითი მისამართის დამატება'))),
          _heading('შეკვეთის რეჟიმი'),
          SegmentedButton<String>(
            segments:const [
              ButtonSegment(value:'single_vehicle_route',label:Text('ერთი ავტომობილი'),icon:Icon(Icons.route)),
              ButtonSegment(value:'separate_vehicle_per_address',label:Text('ცალკე მანქანები'),icon:Icon(Icons.directions_car)),
            ],
            selected:{_mode},
            onSelectionChanged:_quote==null?(v)=>setState(()=>_mode=v.first):null,
          ),
          _heading('ავტომობილი და მგზავრები'),
          DropdownButtonFormField<String>(
            value:_categoryId,decoration:const InputDecoration(labelText:'კატეგორია'),
            items:_categories.map((c)=>DropdownMenuItem(value:c['id'].toString(),child:Text(c['code'].toString()))).toList(),
            onChanged:_quote==null?(v)=>setState(()=>_categoryId=v):null,
          ),
          const SizedBox(height:8),
          TextFormField(controller:_passengerCount,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'მგზავრების რაოდენობა (1–20)'),validator:(v){final n=int.tryParse(v??'');return n==null||n<1||n>20?'შეიყვანე 1-დან 20-მდე.':null;}),
          const SizedBox(height:8),
          TextField(controller:_passengerNames,maxLines:2,decoration:const InputDecoration(labelText:'მგზავრების სახელები (არასავალდებულო)',hintText:'თითო სახელი ცალკე ხაზზე')),
          _heading('გადახდა'),
          DropdownButtonFormField<String>(
            value:_payment,decoration:const InputDecoration(labelText:'გადახდის მეთოდი'),
            items:[
              const DropdownMenuItem(value:'cash',child:Text('ნაღდი ფული')),
              const DropdownMenuItem(value:'wallet',child:Text('MOONRIDE Wallet')),
              if(_corporateAccounts.isNotEmpty)const DropdownMenuItem(value:'corporate',child:Text('კორპორატიული ანგარიშსწორება')),
            ],
            onChanged:_quote==null?(v)=>setState(()=>_payment=v??'cash'):null,
          ),
          if(_payment=='corporate'&&_corporateAccounts.isNotEmpty)DropdownButtonFormField<String>(
            value:_corporateAccountId,decoration:const InputDecoration(labelText:'დამტკიცებული ორგანიზაცია'),
            items:_corporateAccounts.map((a)=>DropdownMenuItem(value:a['id'].toString(),child:Text(a['company_name'].toString()))).toList(),
            onChanged:_quote==null?(v)=>setState(()=>_corporateAccountId=v):null,
          ),
          const SizedBox(height:12),
          if(_quote==null)SizedBox(width:double.infinity,child:FilledButton.icon(
            onPressed:_busy||!_enabled?null:_createAndQuote,
            icon:_busy?const SizedBox(width:18,height:18,child:CircularProgressIndicator(strokeWidth:2)):const Icon(Icons.calculate_outlined),
            label:Text(_busy?'მარშრუტი და ფასი ითვლება':'მარშრუტისა და ფასის გამოთვლა'),
          )),
          if(_quote!=null)...[
            _heading('STAFF GO ფასის შეთავაზება'),
            Card(child:Padding(padding:const EdgeInsets.all(14),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
              Text('მანძილი: ${_quote!['totalDistanceKm']} კმ • დრო: ${_quote!['totalDurationMinutes']} წთ'),
              Text('ჯამური ფასი: ${_quote!['totalFare']} ${_quote!['currencyCode']}',style:const TextStyle(color:_staffBlue,fontWeight:FontWeight.w900,fontSize:20)),
              Text('მოქმედებს: ${_quote!['expiresAt']}',style:const TextStyle(color:Colors.white60,fontSize:10)),
              const Divider(height:18),
              ...(((_quote!['items'] as List<dynamic>?)??[]).whereType<Map>().map((item)=>ListTile(
                dense:true,contentPadding:EdgeInsets.zero,leading:const Icon(Icons.route,color:_staffBlue),
                title:Text(_mode=='single_vehicle_route'?'ერთი მარშრუტი':'მისამართი #${item['order_sequence']}'),
                subtitle:Text('${item['distance_km']} კმ • ${item['duration_minutes']} წთ'),
                trailing:Text('${item['fare_amount']} ${item['currency_code']}',style:const TextStyle(fontWeight:FontWeight.w900)),
              ))),
              const SizedBox(height:8),
              SizedBox(width:double.infinity,child:FilledButton(onPressed:_busy?null:_confirmQuote,child:Text(_busy?'იგზავნება...':'STAFF GO შეკვეთის დადასტურება'))),
              TextButton(onPressed:()=>setState(()=>_quote=null),child:const Text('შეთავაზების თავიდან გამოთვლა')),
            ]))),
          ],
        ])),
      ]))),
    );
  }

  Widget _destinationEditor(int index,_StaffDestination item)=>Card(
    child:Padding(padding:const EdgeInsets.all(11),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Row(children:[
        Expanded(child:Text(index==0?'მთავარი მისამართი':'დამატებითი მისამართი #$index',style:const TextStyle(fontWeight:FontWeight.w800))),
        if(index>0)IconButton(onPressed:_quote==null?()=>_removeDestination(index):null,icon:const Icon(Icons.delete_outline,color:Colors.white54)),
      ]),
      Row(children:[
        Expanded(child:TextField(controller:item.controller,enabled:_quote==null,decoration:InputDecoration(labelText:'მისამართი ${index+1}',hintText:'მაგ. ბათუმი, ...'),onChanged:(_){setState((){item.place=null;_requestId=null;_quote=null;});})),
        IconButton(onPressed:_quote==null&&!item.searching?()=>_searchDestination(item):null,icon:item.searching?const SizedBox(width:18,height:18,child:CircularProgressIndicator(strokeWidth:2)):const Icon(Icons.search,color:_staffBlue)),
      ]),
      if(item.error!=null)Text(item.error!,style:const TextStyle(color:Colors.redAccent,fontSize:11)),
      ...item.results.map((place)=>ListTile(
        dense:true,leading:const Icon(Icons.location_on_outlined,color:_staffBlue),
        title:Text(place.title),subtitle:Text(place.address),
        onTap:_quote==null?()=>_chooseDestination(item,place):null,
      )),
      if(item.place!=null)Text('არჩეულია: ${item.place!.address}',style:const TextStyle(color:Colors.lightGreenAccent,fontSize:11)),
    ])),
  );

  Widget _heading(String title)=>Padding(
    padding:const EdgeInsets.fromLTRB(2,16,2,8),
    child:Text(title,style:const TextStyle(fontSize:16,fontWeight:FontWeight.w900)),
  );
}

class _StaffDestination {
  final controller=TextEditingController();
  _StaffPlace? place;
  List<_StaffPlace> results=[];
  bool searching=false;
  String? error;
  void dispose()=>controller.dispose();
}

class _StaffPlace {
  const _StaffPlace({required this.title,required this.address,required this.latitude,required this.longitude});
  final String title;
  final String address;
  final double latitude;
  final double longitude;
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.text});
  final String text;
  @override
  Widget build(BuildContext context)=>Card(child:Padding(
    padding:const EdgeInsets.all(14),
    child:Row(children:[
      const Icon(Icons.info_outline,color:Colors.white54),const SizedBox(width:8),
      Expanded(child:Text(text,style:const TextStyle(color:Colors.white70))),
    ]),
  ));
}
