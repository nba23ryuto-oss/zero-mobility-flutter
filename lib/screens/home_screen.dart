import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../main.dart';
import 'login_screen.dart';
import 'user_screen.dart';
import 'admin_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _mode = 'user';

  Future<void> _signOut() async {
    await supabase.auth.signOut();
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = supabase.auth.currentUser?.email ?? '';

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // ── ヘッダー ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                children: [
                  const Text(
                    'ZERO Mobility',
                    style: TextStyle(color: Colors.purple, fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text('ユーザー：$email', style: const TextStyle(color: Colors.black54, fontSize: 12)),
                  const SizedBox(height: 12),

                  // モード切り替えボタン
                  Row(children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _mode = 'user'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: _mode == 'user' ? Colors.purple : Colors.transparent,
                            border: Border.all(color: Colors.purple),
                            borderRadius: const BorderRadius.horizontal(left: Radius.circular(10)),
                          ),
                          child: const Text('お客さん画面', textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _mode = 'admin'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: _mode == 'admin' ? Colors.purple : Colors.transparent,
                            border: Border.all(color: Colors.purple),
                            borderRadius: const BorderRadius.horizontal(right: Radius.circular(10)),
                          ),
                          child: const Text('管理者画面', textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ),
                  ]),
                ],
              ),
            ),

            // ── コンテンツ ──
            Expanded(
              child: _mode == 'user' ? const UserScreen() : const AdminScreen(),
            ),

            // ── ログアウト ──
            Padding(
              padding: const EdgeInsets.all(12),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _signOut,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.grey.shade800),
                  child: const Text('ログアウト'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
