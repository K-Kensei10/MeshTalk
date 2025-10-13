import 'package:flutter/material.dart';
import 'package:anslin/main.dart';
import 'package:flutter/services.dart';

class SafetyCheckPageState extends State<SafetyCheckPage> {
  final TextEditingController _recipientController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();
  static const methodChannel = MethodChannel('anslin.flutter.dev/contact');
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
          ],
        ),
      ),
    );
  }
}
