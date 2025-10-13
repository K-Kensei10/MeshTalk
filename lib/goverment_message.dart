import 'package:flutter/material.dart';
import 'package:anslin/main.dart';
import 'package:flutter/services.dart';

class LocalGovernmentPageState extends State<LocalGovernmentPage> {
  static const methodChannel = MethodChannel('anslin.flutter.dev/contact');

  void _sendMessage(String message, String phoneNum, String messageType, String targetPhoneNum) async {
    try {
      await methodChannel.invokeMethod<String>('sendMessage', {
        'message': message,
        'phoneNum': phoneNum,
        'messageType': messageType,
        'targetPhoneNum': targetPhoneNum,
      });
    } on PlatformException catch (e) {
      debugPrint("$e");
    }
  }

  void _showMessageModal() {
    showDialog(
      context: context,
      builder: (context) {
        String? selectedSubject;
        final TextEditingController detailController = TextEditingController();
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
                    items: ["救助要請", "物資要請", "けが人の報告", "その他"].map((
                      String subject,
                    ) {
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
                    controller: detailController,
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
                        detailController.text.isNotEmpty) {
                      //Kotlin呼び出しmessage
                      _sendMessage(
                        detailController.text, // message
                        "000000000000",
                        // AppData.myPhoneNum ?? "", // phoneNum
                        selectedSubject ?? "その他", // messageType
                        // AppData.governmentPhoneNum ?? "", // targetPhoneNum
                        "09000000000"
                      );

                      AppData.receivedMessages.add({
                        "subject": selectedSubject!,
                        "detail": detailController.text,
                        "time":
                            "${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')}",
                      });
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
          const SizedBox(height: 10),
          const Text(
            "自治体からのお知らせ",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const Divider(),
          Expanded(
            child: AppData.officialAnnouncements.isEmpty
                ? const Center(child: Text("まだお知らせはありません"))
                : ListView.builder(
                    itemCount: AppData.officialAnnouncements.length,
                    itemBuilder: (context, index) {
                      final msg = AppData.officialAnnouncements[index];
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
