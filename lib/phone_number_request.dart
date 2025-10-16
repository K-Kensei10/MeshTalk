import 'package:flutter/material.dart';
import 'package:anslin/main.dart';

// ★ 修正点: StatefulWidgetの「設計図」クラスを追加
class PhoneInputPage extends StatefulWidget {
  const PhoneInputPage({super.key});

  @override
  State<PhoneInputPage> createState() => _PhoneInputPageState();
}

// ★ 修正点: クラス名をアンダースコア付きに変更
class _PhoneInputPageState extends State<PhoneInputPage> {
  final TextEditingController _phoneController = TextEditingController();
  String? _errorText;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  void _validateAndNavigate() {
    final phoneNumber = _phoneController.text.replaceAll('-', '');
    if (phoneNumber.length >= 10 &&
        phoneNumber.length <= 11 &&
        int.tryParse(phoneNumber) != null) {
      // mountedチェックを追加して安全性を高める
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const MainPage()),
      );
    } else {
      setState(() {
        _errorText = "有効な電話番号を入力してください（10-11桁）";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("電話番号入力")),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              "災害時の安否確認のため、電話番号を入力してください。",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: "電話番号",
                hintText: "例:09012345678",
                border: const OutlineInputBorder(),
                errorText: _errorText,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _validateAndNavigate,
              child: const Text("ログイン"),
            ),
          ],
        ),
      ),
    );
  }
}