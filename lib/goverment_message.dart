import 'package:flutter/material.dart';
import 'package:anslin/main.dart';

// ★ 修正点: StatefulWidgetの「設計図」クラスを追加
class GovernmentHostPage extends StatefulWidget {
  const GovernmentHostPage({super.key});

  @override
  State<GovernmentHostPage> createState() => _GovernmentHostPageState();
}

// ★ 修正点: クラス名をアンダースコア付きに変更
class _GovernmentHostPageState extends State<GovernmentHostPage> {
  void _showCreateMessageModal() {
    final messageController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("全体メッセージ作成"),
          content: TextField(
            controller: messageController,
            maxLength: 50,
            decoration: const InputDecoration(hintText: "メッセージを入力してください (50文字以内)"),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text("キャンセル")),
            ElevatedButton(
              onPressed: () {
                if (messageController.text.isNotEmpty) {
                  // ★ 修正点: ベルを鳴らす処理
                  final currentList = AppData.officialAnnouncements.value;
                  currentList.insert(0, {
                    "text": messageController.text,
                    "time": "${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')}",
                  });
                  AppData.officialAnnouncements.value = List.from(currentList);

                  if (mounted) {
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("公式メッセージを送信しました")));
                  }
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
        title: const Text("ホストモード - 自治体管理画面"),
        backgroundColor: Colors.red[800],
      ),
      // ★ 修正点: 「ベルの音を聞く担当者 (ValueListenableBuilder)」を配置
      body: ValueListenableBuilder<List<Map<String, dynamic>>>(
        valueListenable: AppData.receivedMessages, // 安否確認のベルを聞く
        builder: (context, receivedMessages, child) {
          // ベルが鳴るたびに、この中が最新の`receivedMessages`で再描画される
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Card(
                  elevation: 4,
                  child: ListTile(
                    leading: const Icon(Icons.send),
                    title: const Text("全体メッセージ作成"),
                    onTap: _showCreateMessageModal,
                  ),
                ),
                const SizedBox(height: 16),
                const Text("避難者からの受信メッセージ一覧", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const Divider(),
                if (receivedMessages.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Center(child: Text("受信メッセージはありません")),
                  )
                else
                  // ★ 修正点: builderから受け取った`receivedMessages`を使う
                  Column(
                    children: receivedMessages.map((msg) {
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          title: Text("件名: ${msg['subject']}"),
                          subtitle: Text(msg['detail'] ?? ""),
                          trailing: Text(msg['time'] ?? ""),
                        ),
                      );
                    }).toList(),
                  ),
                const SizedBox(height: 16),
                const Text("中継メッセージ管理 (開発中)", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const Divider(),
                const Center(child: Text("この機能は現在開発中です。")),
              ],
            ),
          );
        },
      ),
    );
  }
}