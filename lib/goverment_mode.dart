import 'package:flutter/material.dart';
import 'package:meshtalk/main.dart';

class GovernmentHostPageState extends State<GovernmentHostPage> {
  void _showCreateMessageModal() {
    final TextEditingController messageController = TextEditingController();
    int charCount = 0;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text("全体メッセージ作成"),
              content: TextField(
                controller: messageController,
                maxLength: 50,
                decoration: InputDecoration(
                  hintText: "メッセージを入力してください (50文字以内)",
                  counterText: '$charCount/50',
                ),
                onChanged: (text) {
                  setState(() {
                    charCount = text.length;
                  });
                },
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text("キャンセル"),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (messageController.text.isNotEmpty) {
                      AppData.officialAnnouncements.insert(0, {
                        "text": messageController.text,
                        "time":
                            "${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')}",
                      });
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("公式メッセージを送信しました")),
                      );
                    }
                  },
                  child: const Text("送信"),
                ),
              ],
            );
          },
        );
      },
    ).then((_) => setState(() {})); // モーダルが閉じられた後に画面を再描画
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("ホストモード - 自治体管理画面"),
        backgroundColor: Colors.red[800],
      ),
      body: SingleChildScrollView(
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
            const Text(
              "避難者からの受信メッセージ一覧",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const Divider(),
            if (AppData.receivedMessages.isEmpty)
              const Center(child: Text("受信メッセージはありません"))
            else
              ...AppData.receivedMessages.map((msg) {
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    title: Text("件名: ${msg['subject']}"),
                    subtitle: Text(msg['detail'] ?? ""),
                    trailing: Text(msg['time'] ?? ""),
                  ),
                );
              }).toList(),
            const SizedBox(height: 16),
            const Text(
              "中継メッセージ管理 (開発中)",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const Divider(),
            const Center(child: Text("この機能は現在開発中です。")),
          ],
        ),
      ),
    );
  }
}
