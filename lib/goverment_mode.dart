import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:anslin/main.dart';
import 'package:anslin/host_auth.dart';
// import 'package:anslin/snack_bar.dart'; // snack_bar.dart が存在しないためコメントアウト

// ★ 修正点: StatefulWidgetの「設計図」クラスを追加
class LocalGovernmentPage extends StatefulWidget {
  const LocalGovernmentPage({super.key});

  @override
  State<LocalGovernmentPage> createState() => _LocalGovernmentPageState();
}

// ★ 修正点: クラス名をアンダースコア付きに変更
class _LocalGovernmentPageState extends State<LocalGovernmentPage> {
  static const methodChannel = MethodChannel('anslin.flutter.dev/contact');

  void _sendMessage(String subject, String detail) {
    methodChannel.invokeMethod<String>('sendMessage', {
      'message': detail,
      'phoneNum': "000000000000", // 仮の自分の番号
      'messageType': subject,
      'targetPhoneNum': "09000000000", // 仮の自治体番号
    });

    // ★ 修正点: ベルを鳴らす処理
    final currentList = AppData.officialAnnouncements.value;
    currentList.insert(0, {
      "text": "【送信済み】件名: $subject\n詳細: $detail",
      "time": "${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')}",
    });
    AppData.officialAnnouncements.value = List.from(currentList);

    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("メッセージを送信しました")));
    }
  }

  void _showMessageModal() {
    String? selectedSubject;
    final detailController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("自治体へメッセージを送信"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: "件名", border: OutlineInputBorder()),
                items: ["救助要請", "物資要請", "けが人の報告", "その他"].map((subject) {
                  return DropdownMenuItem<String>(value: subject, child: Text(subject));
                }).toList(),
                onChanged: (String? newValue) {
                  selectedSubject = newValue;
                },
              ),
              const SizedBox(height: 16),
              TextField(controller: detailController, decoration: const InputDecoration(labelText: "詳細", border: OutlineInputBorder()), maxLength: 50),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text("キャンセル")),
            ElevatedButton(
              onPressed: () {
                if (selectedSubject != null && detailController.text.isNotEmpty) {
                  _sendMessage(selectedSubject!, detailController.text);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("件名と詳細を入力してください")));
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
        title: const Text("自治体連絡"),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: "ホストモード設定",
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const HostAuthPage())),
          ),
        ],
      ),
      // ★ 修正点: 「ベルの音を聞く担当者 (ValueListenableBuilder)」を配置
      body: ValueListenableBuilder<List<Map<String, dynamic>>>(
        valueListenable: AppData.officialAnnouncements, // このベルを聞く
        builder: (context, messages, child) {
          // ベルが鳴るたびに、この中が最新の`messages`で再描画される
          return Column(
            children: [
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text("自治体からのお知らせ", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              ),
              const Divider(),
              Expanded(
                child: messages.isEmpty
                    ? const Center(child: Text("まだお知らせはありません"))
                    : ListView.builder(
                        itemCount: messages.length,
                        itemBuilder: (context, index) {
                          final msg = messages[index];
                          return Card(
                            color: Colors.lightBlue[50],
                            margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                            child: Padding(
                              padding: const EdgeInsets.all(10),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(children: [
                                    const Icon(Icons.info, color: Colors.blue),
                                    const SizedBox(width: 8),
                                    const Text("公式情報", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                                    const Spacer(),
                                    Text(msg["time"] ?? "", style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                                  ]),
                                  const SizedBox(height: 8),
                                  Text(msg["text"] ?? ""),
                                ],
                              ),
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
        tooltip: '自治体へメッセージを送る',
        child: const Icon(Icons.add),
      ),
    );
  }
}