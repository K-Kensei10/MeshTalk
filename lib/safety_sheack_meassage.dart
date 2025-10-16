import 'package:flutter/material.dart';
import 'package:anslin/main.dart';
import 'package:flutter/services.dart';

//TEST
final myPhoneNumber = 09012345678;

class SafetyCheckPageState extends State<SafetyCheckPage> {
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
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
    _phoneController.dispose();
    super.dispose();
  }

  //[message,  to_phone_number,  message_type,  from_phone_number,  TTL]
  void _startSendMessage(String message, String phoneNumber, String myphoneNumber, ) async {
    try {
      await methodChannel.invokeMethod<String>('startSendMessage', {
      });
    } on PlatformException catch (e) {
      debugPrint("$e");
    }
  }

  void _sendMessage() {
    final phoneNumber = _phoneController.text.replaceAll('-', '');
    final message = _messageController.text;
    if ( (phoneNumber.length == 10 || phoneNumber.length == 11) &&
        _messageController.text.isNotEmpty) {
      // 実際はBluetooth経由でメッセージを送信
      _phoneController.clear();
      _messageController.clear();
      _startSendMessage(phoneNumber.toString(),message);
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("有効な宛先とメッセージを入力してください")));
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
              controller: _phoneController,
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
