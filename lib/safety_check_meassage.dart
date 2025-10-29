import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

String? myPhoneNumber;

class SafetyCheckPage extends StatefulWidget {
  const SafetyCheckPage({super.key});
  
  @override
  State<SafetyCheckPage> createState() => _SafetyCheckPageState();
}

class _SafetyCheckPageState extends State<SafetyCheckPage> {
  final TextEditingController _recipientController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();
  static const methodChannel = MethodChannel('anslin.flutter.dev/contact');
  List<String> receivedMessages = [];

  @override
  void dispose() {
    _messageController.dispose();
    _recipientController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadPhoneNumber();
  }

  Future<void> _loadPhoneNumber() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      myPhoneNumber = prefs.getString('my_phone_number') ?? "00000000000";
    });
  }

  Future<void> _startCatchMessage() async {
    try {
      final String? rawMessage = await methodChannel.invokeMethod<String>(
        'startCatchMessage',
      );
      if (rawMessage != null && rawMessage.isNotEmpty) {
        final parts = rawMessage.split(';');
        if (parts.length >= 5) {
          final formatted = "電話番号：${parts[3]}, メッセージ：${parts[0]}";
          setState(() {
            receivedMessages.insert(0, "$formatted\n(${DateTime.now()})");
          });
          if (!mounted) return;
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text("メッセージを受信しました")));
        } else {
          debugPrint("メッセージ形式が不正: $rawMessage");
        }
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("メッセージは受信されませんでした")));
      }
    } on PlatformException catch (e) {
      debugPrint("受信エラー: $e");
    }
  }

  //message; to_phone_number; message_type; from_phone_number; TTL
  Future<void> _sendMessage() async {
    final toPhoneNumber = _recipientController.text;
    final message = _messageController.text;

    if (toPhoneNumber.isNotEmpty &&
        message.isNotEmpty &&
        myPhoneNumber!.isNotEmpty) {
      try {
        await methodChannel.invokeMethod<String>('startSendMessage', {
          'message': message,
          'myPhoneNumber': myPhoneNumber,
          'messageType': 'SafetyCheck',
          'toPhoneNumber': toPhoneNumber,
        });
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("メッセージを送信しました")));
        _recipientController.clear();
        _messageController.dispose();
      } on Exception catch (e) {
        debugPrint("送信エラー: $e");
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("エラーが発生しました。もう一度お試しください")));
      }
    } else if (myPhoneNumber == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("エラーが発生しました。アプリを再起動してください")));
    }
  }

  void _showPostModal() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("新しい投稿"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _recipientController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: "宛先（電話番号）"),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _messageController,
                maxLength: 50,
                decoration: const InputDecoration(
                  hintText: "メッセージを入力してください (50文字以内)",
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("キャンセル"),
            ),
            ElevatedButton(
              onPressed: () async {
                final phoneNumber = _recipientController.text.replaceAll(
                  '-',
                  '',
                );
                final message = _messageController.text;
                if ((phoneNumber.length == 10 || phoneNumber.length == 11) &&
                    message.isNotEmpty) {
                  Navigator.of(context).pop();
                  _sendMessage();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("有効な宛先とメッセージを入力してください")),
                  );
                }
              },
              child: const Text("送信"),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("安否確認"),
        actions: [
          IconButton(
            icon: const Icon(Icons.wifi_tethering),
            tooltip: "スキャン",
            onPressed: _startCatchMessage,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showPostModal,
        tooltip: '新しい投稿',
        child: const Icon(Icons.add),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Text(
              "メッセージは暗号化され、中継者には見えません",
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: receivedMessages.isEmpty
                  ? const Center(child: Text("まだメッセージは受信されていません"))
                  : ListView.builder(
                      itemCount: receivedMessages.length,
                      itemBuilder: (context, index) {
                        return Card(
                          child: ListTile(title: Text(receivedMessages[index])),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
