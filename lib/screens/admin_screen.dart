import 'package:flutter/material.dart';
import '../main.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  List<Map<String, dynamic>> _rides = [];
  String _status = '';

  @override
  void initState() {
    super.initState();
    _loadRides();
  }

  Future<void> _loadRides() async {
    final data = await supabase.from('rides').select().order('requested_at', ascending: false);
    setState(() => _rides = List<Map<String, dynamic>>.from(data));
  }

  Future<void> _updateStatus(String id, String newStatus) async {
    final update = {'status': newStatus};
    if (newStatus == 'accepted') update['accepted_at'] = DateTime.now().toIso8601String();
    if (newStatus == 'arrived') update['arrived_at'] = DateTime.now().toIso8601String();
    if (newStatus == 'riding') update['started_at'] = DateTime.now().toIso8601String();
    if (newStatus == 'completed') update['completed_at'] = DateTime.now().toIso8601String();

    await supabase.from('rides').update(update).eq('id', id);
    setState(() => _status = 'ステータスを更新しました');
    _loadRides();
  }

  String _statusJp(String s) {
    const map = {
      'requested': '配車待ち', 'accepted': '配車承認済み', 'arriving': '向かっています',
      'arrived': '到着しました', 'riding': '乗車中', 'completed': '運行完了', 'cancelled': 'キャンセル',
    };
    return map[s] ?? s;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          if (_status.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(_status, style: const TextStyle(color: Colors.white)),
            ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _loadRides,
                icon: const Icon(Icons.refresh),
                label: const Text('配車一覧を更新'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  side: const BorderSide(color: Colors.purple),
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: _rides.length,
              itemBuilder: (context, i) {
                final ride = _rides[i];
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.purple),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${ride['pickup_address']} → ${ride['destination_address']}',
                          style: const TextStyle(color: Colors.white)),
                      Text('料金：${ride['estimated_fare']}円　状態：${_statusJp(ride['status'] ?? '')}',
                          style: const TextStyle(color: Colors.white70)),
                      Text('ドライバー：${ride['driver_name'] ?? '未割り当て'}',
                          style: const TextStyle(color: Colors.white70)),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final s in ['accepted', 'arriving', 'arrived', 'riding'])
                            ElevatedButton(
                              onPressed: () => _updateStatus(ride['id'], s),
                              style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6)),
                              child: Text(_statusJp(s), style: const TextStyle(fontSize: 12)),
                            ),
                          ElevatedButton(
                            onPressed: () => _updateStatus(ride['id'], 'completed'),
                            style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6)),
                            child: const Text('運行完了', style: TextStyle(fontSize: 12)),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
