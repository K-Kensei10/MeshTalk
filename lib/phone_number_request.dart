import 'package:flutter/material.dart';
import 'package:anslin/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PhoneInputPage extends StatefulWidget {
  const PhoneInputPage({super.key});

  @override
  State<PhoneInputPage> createState() => _PhoneInputPageState();
}

class _PhoneInputPageState extends State<PhoneInputPage> {
  final TextEditingController _phoneController = TextEditingController();
  String? _errorText;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  // チェック＆ダイアログ表示
  void _validateAndShowDialog() { 
    final phoneNumber = _phoneController.text.replaceAll('-', '');
    // 電話番号のフォーマットをチェック
    if (phoneNumber.length >= 10 &&
        phoneNumber.length <= 11 &&
        int.tryParse(phoneNumber) != null) {
      //確認ダイアログ
      setState(() {
        _errorText = null; 
      });
      _showConfirmationDialog(phoneNumber); 
    } else {
      setState(() {
        _errorText = "有効な電話番号を入力してください（10-11桁）";
      });
    }
  }

  //確認ダイアログ
  Future<void> _showConfirmationDialog(String phoneNumber) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false, 
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('確認'),
          content: Text(
            '電話番号「$phoneNumber」で登録します。\nよろしいですか？',
          ),
          actions: <Widget>[
            //キャンセルボタン
            TextButton(
              child: const Text('キャンセル'),
              onPressed: () {
                Navigator.of(dialogContext).pop(); 
              },
            ),
            //OKボタン
            TextButton(
              child: const Text('OK'),
              onPressed: () {
                Navigator.of(dialogContext).pop();
                // 電話番号保存関数
                _saveAndNavigate(phoneNumber); 
              },
            ),
          ],
        );
      },
    );
  }

  // 電話番号保存関数
  Future<void> _saveAndNavigate(String phoneNumber) async { 
    try {
      // 1. 保存する
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('my_phone_number', phoneNumber);
      print("電話番号 $phoneNumber を保存しました");
      // 2. MainPage に移動する
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const MainPage()),
        );
      }
    } catch (e) {
      print("❌ 電話番号の保存に失敗: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("エラー: 電話番号を保存できませんでした。\n もう一度お試しください。")),
        );
      }
    }
  }

  //入力画面
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
              onPressed: _validateAndShowDialog,
              child: const Text("ログイン"),
            ),
          ],
        ),
      ),
    );
  }
}
