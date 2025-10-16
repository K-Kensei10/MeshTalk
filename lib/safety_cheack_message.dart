import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:anslin/main.dart';

// ★ 修正点: StatefulWidgetの「設計図」クラスを追加
class SafetyCheckPage extends StatefulWidget {
  const SafetyCheckPage({super.key});

  @override
  State<SafetyCheckPage> createState() => _SafetyCheckPageState();
}

// ★ 修正点: クラス名をアンダースコア付きに変更
class _SafetyCheckPageState extends State<SafetyCheckPage> {
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
      methodChannel.invokeMethod<String>('sendMessage', {
        'message': message,
        'phoneNum': "000000000000",
        'messageType': "safety",
        'targetPhoneNum': phone,
      });

      // ★ 修正点: ベルを鳴らす処理
      final currentList = AppData.receivedMessages.value;
      currentList.insert(0, {
        'subject': '送信済み',
        'detail': '宛先: $phone\n内容: $message',
        'time': "${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')}",
      });
      AppData.receivedMessages.value = List.from(currentList);

      _recipientController.clear();
      _messageController.clear();
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("メッセージを送信しました")));
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("宛先とメッセージを入力してください")));
      }
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
              TextField(controller: _recipientController, decoration: const InputDecoration(labelText: "宛先（電話番号）", border: OutlineInputBorder())),
              const SizedBox(height: 16),
              TextField(controller: _messageController, decoration: const InputDecoration(labelText: "メッセージ本文", border: OutlineInputBorder()), maxLength: 50),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text("キャンセル")),
            ElevatedButton(onPressed: _sendMessage, child: const Text("送信")),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("安否確認")),
      // ★ 修正点: 「ベルの音を聞く担当者 (ValueListenableBuilder)」を配置
      body: ValueListenableBuilder<List<Map<String, String>>>(
        valueListenable: AppData.receivedMessages, // このベルを聞く
        builder: (context, messages, child) {
          // ベルが鳴るたびに、この中が最新の`messages`で再描画される
          return Column(
            children: [
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text("受信した安否確認メッセージ", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              ),
              const Divider(),
              Expanded(
                child: messages.isEmpty
                    ? const Center(child: Text("まだメッセージはありません"))
                    // ★ 修正点: builderから受け取った`messages`を使う
                    : ListView.builder(
                        itemCount: messages.length,
                        itemBuilder: (context, index) {
                          final msg = messages[index];
                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
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
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showMessageModal,
        tooltip: '安否確認メッセージ送信',
        child: const Icon(Icons.add),
      ),
    );
  }
}