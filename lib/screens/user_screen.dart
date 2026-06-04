import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../main.dart';

const _googleApiKey = 'AIzaSyAfyZSlkFw-y3NT3qwi6mrhTXOKFgrmm9Q';

class UserScreen extends StatefulWidget {
  const UserScreen({super.key});
  @override
  State<UserScreen> createState() => _UserScreenState();
}

class _UserScreenState extends State<UserScreen> {
  final _pickupCtrl = TextEditingController();
  final _destCtrl = TextEditingController();

  String _status = '出発地と目的地を入力してください';
  String _driver = 'まだドライバーはいません';
  String _rideStatus = '待機中';
  String _fare = '';
  String _distance = '';
  String _duration = '';
  String _plan = '未加入';
  String _payment = '未決済';
  String _selectedTier = 'standard';
  String _selectedPremium = 'none';

  List<Map<String, dynamic>> _rideHistory = [];
  List<Map<String, dynamic>> _pickupSuggestions = [];
  List<Map<String, dynamic>> _destSuggestions = [];

  Timer? _moveTimer;

  final _premiumCars = [
    {'id': 'none', 'name': '選択しない'},
    {'id': 'alphard', 'name': 'アルファード'},
    {'id': 'vellfire', 'name': 'ヴェルファイア'},
    {'id': 'bmw', 'name': 'BMW'},
  ];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  @override
  void dispose() {
    _moveTimer?.cancel();
    _pickupCtrl.dispose();
    _destCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    try {
      final data = await supabase
          .from('rides')
          .select()
          .order('requested_at', ascending: false);
      setState(() => _rideHistory = List<Map<String, dynamic>>.from(data));
    } catch (_) {}
  }

  Future<List<Map<String, dynamic>>> _fetchSuggestions(String input) async {
    if (input.length < 2) return [];
    try {
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/autocomplete/json'
        '?input=${Uri.encodeComponent(input)}&key=$_googleApiKey&language=ja&components=country:jp',
      );
      final res = await http.get(url);
      final data = json.decode(res.body);
      if (data['status'] != 'OK') return [];
      return (data['predictions'] as List)
          .map((p) => {'placeId': p['place_id'], 'description': p['description']})
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<Map<String, dynamic>?> _getLocationFromPlaceId(String placeId) async {
    try {
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/details/json'
        '?place_id=$placeId&fields=geometry&key=$_googleApiKey',
      );
      final res = await http.get(url);
      final data = json.decode(res.body);
      return data['result']?['geometry']?['location'];
    } catch (_) {
      return null;
    }
  }

  Future<void> _requestRide() async {
    if (_pickupCtrl.text.isEmpty || _destCtrl.text.isEmpty) {
      setState(() => _status = '出発地と目的地を入力してください');
      return;
    }

    setState(() {
      _status = '計算中...';
      _driver = '検索中...';
      _fare = '';
      _rideStatus = '配車準備中';
    });

    // ランダムで料金計算
    final rng = Random();
    final distKm = (rng.nextDouble() * 10 + 2).toStringAsFixed(1);
    final durMin = (double.parse(distKm) * 3 + rng.nextDouble() * 5).toInt();
    int fareBase = 500 + (double.parse(distKm) * 400).toInt();

    double fareRate = _selectedTier == 'premium'
        ? (_selectedPremium == 'bmw' ? 2.0 : 1.5)
        : 1.0;
    int fare = (fareBase * fareRate).toInt();
    if (_plan == 'Basic') fare = (fare * 0.9).toInt();
    if (_plan == 'Standard') fare = (fare * 0.82).toInt();
    if (_plan == 'Premium') fare = (fare * 0.7).toInt();

    final drivers = ['佐藤', '田中', '鈴木', '山田', '伊藤'];
    final driverName = '${drivers[rng.nextInt(drivers.length)]}ドライバー';
    final prefixes = ['品川', '世田谷', '練馬', '横浜'];
    final plate = '${prefixes[rng.nextInt(prefixes.length)]} ${rng.nextInt(900) + 100} あ ${rng.nextInt(90) + 10}-${rng.nextInt(90) + 10}';

    setState(() {
      _fare = '$fare円';
      _distance = '$distKm km';
      _duration = '$durMin分';
      _driver = '$driverName ($plate)';
      _rideStatus = '向かっています';
      _status = '$driverNameが向かっています';
    });

    // 到着シミュレーション
    _moveTimer?.cancel();
    int count = 0;
    _moveTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      count++;
      if (count >= 5) {
        timer.cancel();
        setState(() {
          _status = 'ドライバーが到着しました';
          _rideStatus = '到着しました';
        });
      }
    });

    try {
      await supabase.from('rides').insert({
        'pickup_address': _pickupCtrl.text,
        'destination_address': _destCtrl.text,
        'estimated_fare': fare,
        'final_fare': fare,
        'distance_km': double.parse(distKm),
        'duration_min': durMin,
        'driver_name': driverName,
        'status': 'requested',
        'requested_at': DateTime.now().toIso8601String(),
      });
      _loadHistory();
    } catch (_) {}
  }

  String _statusJp(String s) {
    const map = {
      'requested': '配車待ち', 'accepted': '配車承認済み', 'arriving': '向かっています',
      'arrived': '到着しました', 'riding': '乗車中', 'completed': '運行完了',
    };
    return map[s] ?? s;
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── 出発地入力 ──
          TextField(
            controller: _pickupCtrl,
            decoration: InputDecoration(
              hintText: '出発地',
              prefixIcon: const Icon(Icons.location_on, color: Colors.red),
              filled: true,
              fillColor: Colors.grey.shade100,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
            onChanged: (v) async {
              final s = await _fetchSuggestions(v);
              setState(() => _pickupSuggestions = s);
            },
          ),
          if (_pickupSuggestions.isNotEmpty) _suggestionList(_pickupSuggestions, true),
          const SizedBox(height: 10),

          // ── 目的地入力 ──
          TextField(
            controller: _destCtrl,
            decoration: InputDecoration(
              hintText: '目的地',
              prefixIcon: const Icon(Icons.flag, color: Colors.green),
              filled: true,
              fillColor: Colors.grey.shade100,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
            onChanged: (v) async {
              final s = await _fetchSuggestions(v);
              setState(() => _destSuggestions = s);
            },
          ),
          if (_destSuggestions.isNotEmpty) _suggestionList(_destSuggestions, false),
          const SizedBox(height: 12),

          // ── 配車ボタン ──
          ElevatedButton(
            onPressed: _requestRide,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purple,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('配車する', style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 16),

          // ── ステータス ──
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.purple.withOpacity(0.08), borderRadius: BorderRadius.circular(10)),
            child: Text(_status, textAlign: TextAlign.center, style: const TextStyle(color: Colors.purple, fontWeight: FontWeight.w500)),
          ),
          const SizedBox(height: 12),

          // ── ドライバー情報 ──
          _infoCard('ドライバー情報', [
            _row('ドライバー', _driver),
            _row('状態', _rideStatus),
          ]),

          // ── 料金情報 ──
          _infoCard('料金情報', [
            _row('距離', _distance.isEmpty ? '-' : _distance),
            _row('時間', _duration.isEmpty ? '-' : _duration),
            _row('料金', _fare.isEmpty ? '-' : _fare),
          ]),

          // ── 車種選択 ──
          _carSelectionCard(),

          // ── ZERO PASS ──
          _zeroPASSCard(),

          // ── 支払い ──
          ElevatedButton(
            onPressed: () {
              if (_fare.isEmpty) {
                setState(() => _status = '先に配車してください');
              } else {
                setState(() => _payment = 'ZERO Payで決済済み');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purple,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('ZERO Payで支払う', style: TextStyle(color: Colors.white)),
          ),
          const SizedBox(height: 8),
          Text('プラン：$_plan　決済：$_payment',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.black54, fontSize: 12)),
          const SizedBox(height: 12),

          // ── リセット ──
          OutlinedButton(
            onPressed: () {
              _moveTimer?.cancel();
              setState(() {
                _pickupCtrl.clear(); _destCtrl.clear();
                _fare = ''; _distance = ''; _duration = '';
                _driver = 'まだドライバーはいません';
                _payment = '未決済'; _rideStatus = '待機中';
                _status = '出発地と目的地を入力してください';
              });
            },
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.grey),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('配車リセット', style: TextStyle(color: Colors.grey)),
          ),
          const SizedBox(height: 16),

          // ── 配車履歴 ──
          _infoCard('配車履歴', _rideHistory.isEmpty
            ? [const Center(child: Text('履歴なし', style: TextStyle(color: Colors.grey)))]
            : _rideHistory.take(5).map((r) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.purple.withOpacity(0.3)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${r['pickup_address']} → ${r['destination_address']}',
                  style: const TextStyle(fontSize: 12, color: Colors.black87)),
                Text('料金：${r['estimated_fare']}円　状態：${_statusJp(r['status'] ?? '')}',
                  style: const TextStyle(fontSize: 12, color: Colors.black54)),
              ]),
            )).toList()),
        ],
      ),
    );
  }

  Widget _suggestionList(List<Map<String, dynamic>> suggestions, bool isPickup) {
    return Container(
      margin: const EdgeInsets.only(top: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.purple.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(10),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
      child: Column(
        children: suggestions.map((s) => ListTile(
          dense: true,
          leading: Icon(isPickup ? Icons.location_on : Icons.flag,
            color: isPickup ? Colors.red : Colors.green, size: 18),
          title: Text(s['description'], style: const TextStyle(fontSize: 13)),
          onTap: () async {
            if (isPickup) {
              _pickupCtrl.text = s['description'];
              setState(() => _pickupSuggestions = []);
            } else {
              _destCtrl.text = s['description'];
              setState(() => _destSuggestions = []);
            }
          },
        )).toList(),
      ),
    );
  }

  Widget _infoCard(String title, List<Widget> children) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
        const SizedBox(height: 10),
        ...children,
      ]),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(children: [
        Text('$label：', style: const TextStyle(color: Colors.black54, fontSize: 13)),
        Expanded(child: Text(value, style: const TextStyle(color: Colors.black87, fontSize: 13))),
      ]),
    );
  }

  Widget _carSelectionCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('乗車を選択する', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),

        // タクシー
        GestureDetector(
          onTap: () => setState(() => _selectedTier = 'standard'),
          child: Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              border: Border.all(
                color: _selectedTier == 'standard' ? Colors.purple : Colors.grey.shade300,
                width: _selectedTier == 'standard' ? 3 : 1.5,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(children: [
              Container(
                width: 86, height: 54,
                decoration: BoxDecoration(color: const Color(0xFFF5C518), borderRadius: BorderRadius.circular(10)),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.asset('assets/images/cars/taxi_white.png', fit: BoxFit.contain),
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('タクシー', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                Text('最大4名 · JPN タクシー', style: TextStyle(color: Colors.grey, fontSize: 12)),
              ])),
              if (_selectedTier == 'standard') const Icon(Icons.check_circle, color: Colors.purple),
            ]),
          ),
        ),

        // プレミアム
        GestureDetector(
          onTap: () => setState(() => _selectedTier = 'premium'),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(
                color: _selectedTier == 'premium' ? Colors.purple : Colors.grey.shade300,
                width: _selectedTier == 'premium' ? 3 : 1.5,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(children: [
              Row(children: [
                Container(
                  width: 86, height: 54,
                  decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(10)),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.asset('assets/images/cars/premium_white.png', fit: BoxFit.contain),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('プレミアム', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  Text(
                    _selectedPremium == 'none' ? '車種を選択' :
                    _premiumCars.firstWhere((c) => c['id'] == _selectedPremium)['name']!,
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ])),
                if (_selectedTier == 'premium') const Icon(Icons.check_circle, color: Colors.purple),
              ]),
              if (_selectedTier == 'premium') ...[
                const SizedBox(height: 10),
                SizedBox(
                  height: 100,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: _premiumCars.map((car) => GestureDetector(
                      onTap: () => setState(() => _selectedPremium = car['id']!),
                      child: Container(
                        width: 85,
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.black,
                          border: Border.all(
                            color: _selectedPremium == car['id'] ? Colors.purple : Colors.grey.shade700,
                            width: _selectedPremium == car['id'] ? 3 : 1,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          if (car['id'] == 'none')
                            const Text('✕', style: TextStyle(color: Colors.white, fontSize: 24))
                          else
                            ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: Image.asset(
                                'assets/images/cars/${car['id']}.png',
                                width: 68, height: 46, fit: BoxFit.contain,
                              ),
                            ),
                          const SizedBox(height: 4),
                          Text(car['name']!, style: const TextStyle(color: Colors.white, fontSize: 10), textAlign: TextAlign.center),
                        ]),
                      ),
                    )).toList(),
                  ),
                ),
                const SizedBox(height: 4),
                const Text('※ 近くにいない場合選択できません', style: TextStyle(color: Colors.grey, fontSize: 10)),
              ],
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _zeroPASSCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)],
      ),
      child: Column(children: [
        const Text('ZERO PASS', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        for (final plan in [
          ['Basic', '4,980円/月', '10%OFF'],
          ['Standard', '9,980円/月', '18%OFF'],
          ['Premium', '19,800円/月', '30%OFF'],
        ])
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('${plan[0]} ${plan[1]}：${plan[2]}', style: const TextStyle(fontSize: 13)),
              ElevatedButton(
                onPressed: () => setState(() => _plan = plan[0]),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _plan == plan[0] ? Colors.purple : Colors.grey.shade300,
                  foregroundColor: _plan == plan[0] ? Colors.white : Colors.black87,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: Text('${plan[0]}に加入', style: const TextStyle(fontSize: 12)),
              ),
            ]),
          ),
      ]),
    );
  }
}
