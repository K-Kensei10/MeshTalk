import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:anslin/main.dart';

class ShelterSNSPage extends StatefulWidget {
  const ShelterSNSPage({super.key});
  
  @override
  State<ShelterSNSPage> createState() => _ShelterSNSPageState();
}

class _ShelterSNSPageState extends State<ShelterSNSPage> {
  final TextEditingController _messageController = TextEditingController();
  static const methodChannel = MethodChannel('anslin.flutter.dev/contact');

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
  }

  //message; to_phone_number; message_type; from_phone_number; TTL
  Future<void> _sendMessage() async {//Unused
    final message = _messageController.text;

    if (message.isNotEmpty) {
      try {
        await methodChannel.invokeMethod<String>('startSendMessage', {
          'message': message,
          'myPhoneNumber': "00000000000",
          'messageType': 'SafetyCheck',
          'toPhoneNumber': "00000000000",
        });
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("メッセージを送信しました")));
        _messageController.dispose();
      } on Exception catch (e) {
        debugPrint("送信エラー: $e");
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("エラーが発生しました。もう一度お試しください")));
      }
    }
  }

  void _showPostModal() {
    showDialog(
      context: context,
      builder: (context) {
        String postText = "";
        return AlertDialog(
          title: const Text("新しい投稿"),
          content: TextField(
            controller: _messageController,
            maxLength: 50,
            decoration: const InputDecoration(
              hintText: "メッセージを入力してください (50文字以内)",
            ),
            onChanged: (text) {
              postText = text;
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
                if (postText.isNotEmpty) {
                  setState(() {
                    AppData.snsPosts.insert(0, {
                      "text": postText,
                      "timestamp": DateTime.now(),
                    });
                  });
                  _messageController.clear();
                  Navigator.of(context).pop();
                }
              },
              child: const Text("投稿"),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // 3時間以上前の投稿をフィルタリング
    final recentPosts = AppData.snsPosts.where((post) {
      final postTime = post['timestamp'] as DateTime;
      return DateTime.now().difference(postTime).inHours < 3;
    }).toList();

    return Scaffold(
      appBar: AppBar(title: const Text("避難所SNS")),
      body: recentPosts.isEmpty
          ? const Center(child: Text("まだ投稿はありません"))
          : ListView.builder(
              itemCount: recentPosts.length,
              itemBuilder: (context, index) {
                final post = recentPosts[index];
                return Card(
                  margin: const EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 16,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          post["text"],
                          style: const TextStyle(fontSize: 16),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "投稿時間: ${post['timestamp'].hour.toString().padLeft(2, '0')}:${post['timestamp'].minute.toString().padLeft(2, '0')}",
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showPostModal,
        tooltip: '新しい投稿',
        child: const Icon(Icons.add),
      ),
    );
  }
}
