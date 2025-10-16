import 'package:flutter/material.dart';
import 'package:anslin/goverment_mode.dart';

// ★ 修正点: StatefulWidgetの「設計図」クラスを追加
class HostAuthPage extends StatefulWidget {
  const HostAuthPage({super.key});

  @override
  State<HostAuthPage> createState() => _HostAuthPageState();
}

// ★ 修正点: クラス名をアンダースコア付きに変更
class _HostAuthPageState extends State<HostAuthPage> {
  final TextEditingController _passwordController = TextEditingController();
  final String _correctPassword = "1234";
  String? _errorText;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  void _checkPassword() {
    if (_passwordController.text == _correctPassword) {
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const LocalGovernmentPage()),
      );
    } else {
      setState(() {
        _errorText = "パスワードが違います";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("ホストモード認証")),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text("ホストモードに切り替えるにはパスワードを入力してください"),
            const SizedBox(height: 20),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: "パスワード",
                border: const OutlineInputBorder(),
                errorText: _errorText,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(onPressed: _checkPassword, child: const Text("認証")),
          ],
        ),
      ),
    );
  }
}