import 'package:flutter/material.dart';
import 'package:meshtalk/main.dart';
import 'package:flutter/services.dart';

class SafetyCheckPageState extends State<SafetyCheckPage> {
  final TextEditingController _recipientController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();
  static const methodChannel = MethodChannel('meshtalk.flutter.dev/contact');
  int _charCount = 0;

  @override
  void initState() {
    super.initState();
    _messageController.addListener(() {
      setState(() {
        _charCount = _messageController.text.length;
      });
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _recipientController.dispose();
    super.dispose();
  }

  void _advertising() async {
    try {
      await methodChannel.invokeMethod<String>('startAdvertising', {
      });
    } on PlatformException catch (e) {
      debugPrint("$e");
    }
  }

  void _sendMessage() {
    
    if (_recipientController.text.isNotEmpty &&
        _messageController.text.isNotEmpty) {
      // 実際はBluetooth経由でメッセージを送信
      _recipientController.clear();
      _messageController.clear();
      //TEST
      _advertising();
      // 送信完了のフィードバックなし（仕様通り）
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("宛先とメッセージを入力してください")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("安否確認")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Text(
              "メッセージは暗号化され、中継者には見えません",
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _recipientController,
              decoration: const InputDecoration(
                labelText: "宛先（電話番号）",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _messageController,
              maxLength: 50,
              decoration: InputDecoration(
                labelText: "メッセージ本文",
                border: const OutlineInputBorder(),
                counterText: '$_charCount/50',
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(onPressed: _sendMessage, child: const Text("送信")),
              const SizedBox(height: 10), // ボタンの間に少し隙間を空ける

            ElevatedButton(
              // Kotlinの'runJsonTest'を呼び出す関数
              onPressed: _runJsonTest, 
              // 通常の送信ボタンと区別できるように色を変える
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange, 
              ),
              child: const Text(
                'Kotlin JSON処理テスト実行',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
   void _runJsonTest() async {
    try {
      // Kotlin側の 'runJsonTest' という名前の処理を呼び出す
      final String result = await methodChannel.invokeMethod('runJsonTest');
      debugPrint('Flutter側で受け取った結果: $result');

      // 画面下部に成功メッセージを表示
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result),
            backgroundColor: Colors.green, // 成功は緑色
          ),
        );
      }
    } on PlatformException catch (e) {
      debugPrint('テスト呼び出し中にエラー: $e');
      // 画面下部にエラーメッセージを表示
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('テストエラー: ${e.message}'),
            backgroundColor: Colors.red, // エラーは赤色
          ),
        );
      }
    }
  }
}
