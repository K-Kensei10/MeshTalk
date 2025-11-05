import 'package:flutter/material.dart';
import 'package:anslin/main.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:anslin/snack_bar.dart';
import 'package:anslin/main.dart';
import 'databasehelper.dart';
import 'package:intl/intl.dart';

class ShelterSNSPage extends StatefulWidget {
  const ShelterSNSPage({super.key});

  @override
  State<ShelterSNSPage> createState() => _ShelterSNSPageState();
}

class _ShelterSNSPageState extends State<ShelterSNSPage> {
  final TextEditingController _messageController = TextEditingController();

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
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
                  AppData.snsPosts.value.insert(0, {
                    "text": postText,
                    "timestamp": DateTime.now(),
                  });
                  AppData.snsPosts.notifyListeners();
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
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text("避難所SNS"),
      ),
      body: Column(
        children: [
          Expanded(
            child: ValueListenableBuilder<List<Map<String, dynamic>>>(
              valueListenable: AppData.snsPosts,
              builder: (context, posts, _) {
                final recentPosts = posts.where((post) {
                  final postTime = post['timestamp'] as DateTime? ?? DateTime.now();
                  return DateTime.now().difference(postTime).inHours < 3;
                }).toList();

                if (recentPosts.isEmpty) {
                  return const Center(child: Text("まだ投稿はありません"));
                }

                return ListView.builder(
                  itemCount: recentPosts.length,
                  itemBuilder: (context, index) {
                    final post = recentPosts[index];
                    final text = post["text"] as String? ?? "";
                    final time = post["timestamp"] as DateTime? ?? DateTime.now();

                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(text, style: const TextStyle(fontSize: 16)),
                            const SizedBox(height: 8),
                            Text(
                              "投稿時間: ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}",
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                            ),
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
    );
  }
}