import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:anslin/main.dart';

class SafetyCheckPageState extends State<SafetyCheckPage> {
  final TextEditingController _recipientController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();
  static const methodChannel = MethodChannel('anslin.flutter.dev/contact');

  @override
  void dispose() {
    _recipientController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final phone = _recipientController.text;
    final message = _messageController.text;

    if (phone.isNotEmpty && message.isNotEmpty) {
      // BLE送信処理（必要なら methodChannel.invokeMethod を追加）
      methodChannel.invokeMethod<String>('sendMessage', {
        'message': message,
        'phoneNum': "000000000000", // 自分の電話番号（仮）
        'messageType': "safety",
        'targetPhoneNum': phone,
      });

      AppData.receivedMessages.insert(0, {
        'subject': '安否確認',
        'detail': '電話番号$phoneさんから「$message」が届きました',
        'time':
            "${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')}",
      });

      _recipientController.clear();
      _messageController.clear();
      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("メッセージを送信しました")),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("宛先とメッセージを入力してください")),
      );
    }
  }

  void _showMessageModal() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("安否確認メッセージ送信"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
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
                decoration: const InputDecoration(
                  labelText: "メッセージ本文",
                  border: OutlineInputBorder(),
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
              onPressed: _sendMessage,
              child: const Text("送信"),
            ),
                         const SizedBox(height: 20), // ボタンとの間に少し隙間を空ける

            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange, // ボタンの色をオレンジに
              ),
              child: const Text(
                'Kotlin JSON処理テスト実行',
                style: TextStyle(color: Colors.white),
              ),
              onPressed: () async {
                // ボタンが押されたら、Kotlin側の 'runJsonTest' 命令を呼び出す
                try {
                  const String testJson = '{"MD":"Flutterからのテスト","t_p_n":"090-9999-9999","type":"1","f_p_n":"080-1111-2222","TTL":3}';
                  final result = await methodChannel.invokeMethod('routeToMessageBridge', {'data': testJson});
                  // 画面下にメッセージを表示
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(result)),
                  );
                } catch (e) {
                  print('テスト呼び出し中にエラー: $e');
                }
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("安否確認")),
      body: Column(
        children: [
          const SizedBox(height: 10),
          const Text(
            "受信した安否確認メッセージ",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const Divider(),
          Expanded(
            child: AppData.receivedMessages.isEmpty
                ? const Center(child: Text("まだメッセージはありません"))
                : ListView.builder(
                    itemCount: AppData.receivedMessages.length,
                    itemBuilder: (context, index) {
                      final msg = AppData.receivedMessages[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(
                          vertical: 4,
                          horizontal: 8,
                        ),
                        child: ListTile(
                          title: Text(msg['subject'] ?? ''),
                          subtitle: Text(msg['detail'] ?? ''),
                          trailing: Text(msg['time'] ?? ''),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showMessageModal,
        tooltip: '安否確認メッセージ送信',
        child: const Icon(Icons.add),
      ),
    );
  }
}
