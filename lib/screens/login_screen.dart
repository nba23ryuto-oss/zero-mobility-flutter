import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../main.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  String _status = '';
  bool _loading = false;

  Future<void> _signIn() async {
    setState(() { _loading = true; _status = ''; });
    try {
      await supabase.auth.signInWithPassword(
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text,
      ).timeout(const Duration(seconds: 15));
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      }
    } catch (e) {
      setState(() => _status = 'ログインに失敗しました。メールとパスワードを確認してください。');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _signUp() async {
    setState(() { _loading = true; _status = ''; });
    try {
      await supabase.auth.signUp(
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text,
      ).timeout(const Duration(seconds: 15));
      setState(() => _status = 'アカウント作成完了。メールを確認してください。');
    } catch (e) {
      setState(() => _status = '登録に失敗しました。');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(28),
          children: [
            const SizedBox(height: 60),
            const Text(
              'ZERO Mobility',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.purple, fontSize: 34, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              '地方向けタクシーサブスク',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black54, fontSize: 14),
            ),
            const SizedBox(height: 48),
            TextField(
              controller: _emailCtrl,
              style: const TextStyle(color: Colors.black87),
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                hintText: 'メールアドレス',
                hintStyle: const TextStyle(color: Colors.grey),
                filled: true,
                fillColor: Colors.grey.shade100,
                prefixIcon: const Icon(Icons.email_outlined, color: Colors.grey),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _passCtrl,
              style: const TextStyle(color: Colors.black87),
              obscureText: true,
              decoration: InputDecoration(
                hintText: 'パスワード',
                hintStyle: const TextStyle(color: Colors.grey),
                filled: true,
                fillColor: Colors.grey.shade100,
                prefixIcon: const Icon(Icons.lock_outline, color: Colors.grey),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: _loading ? null : _signIn,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _loading
                    ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                    : const Text('ログイン', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 52,
              child: OutlinedButton(
                onPressed: _loading ? null : _signUp,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.purple, width: 1.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('新規登録', style: TextStyle(color: Colors.purple, fontSize: 16)),
              ),
            ),
            if (_status.isNotEmpty) ...[
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.purple.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(_status, style: const TextStyle(color: Colors.purple), textAlign: TextAlign.center),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
