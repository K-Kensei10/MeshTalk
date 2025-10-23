import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:anslin/main.dart';
import 'databasehelper.dart';

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

  void _sendMessage() async {
    final phone = _recipientController.text;
    final message = _messageController.text;

    if (phone.isNotEmpty && message.isNotEmpty) {
      methodChannel.invokeMethod<String>('sendMessage', {
        'message': message,
        'phoneNum': "000000000000",
        'messageType': "safety",
        'targetPhoneNum': phone,
      });

      final messageDataMap = {
        'type': '2',          // 安否確認 (Type 2)
        
        // ★★★ [工夫] 送信メッセージは、内容を「事前」に整形する ★★★
        'content': '宛先: $phone\n内容: $message', 
        
        // ★★★ [工夫] 送信元(from)を「送信済みフラグ」として使う ★★★
        'from': 'SELF_SENT_SAFETY_CHECK', // (自分だとわかる特殊な文字列)
      };

      // 2. ★ データベース係に「保存」を依頼
      await DatabaseHelper.instance.insertMessage(messageDataMap);

      await AppData.loadSafetyCheckMessages();

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
                                     const SizedBox(height: 20), // ボタンとの間に少し隙間を空ける

            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange, // ボタンの色をオレンジに
              ),
              child: const Text(
                '安否確認テスト実行',
                style: TextStyle(color: Colors.white),
              ),
              onPressed: () async {
                // ボタンが押されたら、Kotlin側の 'runJsonTest' 命令を呼び出す
                try {
                  const messagedata ="Flutterからのテスト;01234567890;2;080-1111-2222;3";
                  final result = await methodChannel.invokeMethod('routeToMessageBridge', messagedata);
                  // 画面下にメッセージを表示
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(result)),
                  );
                } catch (e) {
                  print('テスト呼び出し中にエラー: $e');
                }
              },
            ),
                         const SizedBox(height: 20), // ボタンとの間に少し隙間を空ける

            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange, // ボタンの色をオレンジに
              ),
              child: const Text(
                'SNSテスト実行',
                style: TextStyle(color: Colors.white),
              ),
              onPressed: () async {
                // ボタンが押されたら、Kotlin側の 'runJsonTest' 命令を呼び出す
                try {
                  const messagedata ="Flutterからのテスト;01234567890;1;080-1111-2222;3";
                  final result = await methodChannel.invokeMethod('routeToMessageBridge', messagedata);
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
      // ★ 修正点: 「ベルの音を聞く担当者 (ValueListenableBuilder)」を配置
      body: ValueListenableBuilder<List<Map<String, dynamic>>>(
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
                          final bool isSelf = msg['isSelf'] as bool? ?? false; // (送信メッセージかどうかのフラグ)
                          return Card(
                            color: isSelf ? Colors.blue[50] : Colors.white,
                            margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                            child: ListTile(

                              title: Text(msg['subject'] as String? ?? ''),
                              subtitle: Text(msg['detail'] as String? ?? ''),
                              trailing: Text(msg['time'] as String? ?? ''),
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