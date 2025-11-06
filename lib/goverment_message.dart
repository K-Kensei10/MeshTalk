import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:anslin/host_auth.dart';
import 'package:anslin/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

String? myPhoneNumber;

class LocalGovernmentPage extends StatefulWidget {
  const LocalGovernmentPage({super.key});

  @override
  State<LocalGovernmentPage> createState() => _LocalGovernmentPageState();
}

class _LocalGovernmentPageState extends State<LocalGovernmentPage> {
  final TextEditingController _messageController = TextEditingController();
  static const methodChannel = MethodChannel('anslin.flutter.dev/contact');

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

  Future<void> _sendMessage() async {
    final message = _messageController.text;

    if (message.isNotEmpty && myPhoneNumber!.isNotEmpty) {
      try {
        await methodChannel.invokeMethod<String>('startSendMessage', {
          'message': message,
          'myPhoneNumber': myPhoneNumber,
          'messageType': 'ToLocalGovernment',
          'toPhoneNumber': "00000000000",
        });
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("メッセージを送信しました")),
        );
      } on Exception catch (e) {
        debugPrint("送信エラー: $e");
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("エラーが発生しました。もう一度お試しください")),
        );
      }
    } else if (myPhoneNumber == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("エラーが発生しました。アプリを再起動してください")),
      );
    }
  }

  void _showMessageModal() {
    showDialog(
      context: context,
      builder: (context) {
        String? selectedSubject;
        int charCount = 0;

        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text("自治体へメッセージを送信"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      labelText: "件名",
                      border: OutlineInputBorder(),
                    ),
                    items: ["救助要請", "物資要請", "けが人の報告", "その他"]
                        .map((String subject) {
                      return DropdownMenuItem<String>(
                        value: subject,
                        child: Text(subject),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      selectedSubject = newValue;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _messageController,
                    maxLength: 50,
                    decoration: InputDecoration(
                      labelText: "詳細",
                      border: const OutlineInputBorder(),
                      counterText: '$charCount/50',
                    ),
                    onChanged: (text) {
                      setState(() {
                        charCount = text.length;
                      });
                    },
                  ),
                ],
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
                    if (selectedSubject != null &&
                        _messageController.text.isNotEmpty) {
                      _sendMessage();

                      AppData.receivedMessages.value.add({
                        "subject": selectedSubject!,
                        "detail": _messageController.text,
                        "time":
                            "${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')}",
                      });
                      AppData.receivedMessages.notifyListeners();

                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("メッセージを送信しました")),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("件名と詳細を入力してください")),
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
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("自治体からのお知らせ"),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: "ホストモード設定",
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const HostAuthPage()),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ValueListenableBuilder<List<Map<String, dynamic>>>(
              valueListenable: AppData.officialAnnouncements,
              builder: (context, announcements, _) {
                if (announcements.isEmpty) {
                  return const Center(child: Text("まだお知らせはありません"));
                }

                return ListView.builder(
                  itemCount: announcements.length,
                  itemBuilder: (context, index) {
                    final msg = announcements[index];
                    return Card(
                      color: Colors.lightBlue[50],
                      margin: const EdgeInsets.symmetric(
                        vertical: 4,
                        horizontal: 8,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.info, color: Colors.blue),
                                const SizedBox(width: 8),
                                const Text(
                                  "公式情報",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  msg["time"] ?? "",
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(msg["text"] ?? ""),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showMessageModal,
        tooltip: '自治体へメッセージを送る',
        child: const Icon(Icons.add),
      ),
    );
  }
}