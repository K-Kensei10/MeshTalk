import 'package:flutter/material.dart';
import 'package:anslin/main.dart';
import 'databasehelper.dart';

// ★ 修正点: StatefulWidgetの「設計図」クラスを追加
class ShelterSNSPage extends StatefulWidget {
  const ShelterSNSPage({super.key});

  @override
  State<ShelterSNSPage> createState() => _ShelterSNSPageState();
}

// ★ 修正点: クラス名をアンダースコア付きに変更
class _ShelterSNSPageState extends State<ShelterSNSPage> {
  final TextEditingController _postController = TextEditingController();

  Future<void> _addPost(String postText) async {

    //DBに保存するMap
    final messageDataMap = {
      'type': '1',        // SNS (Type 1)
      'content': postText,
      'from': 'SELF_SENT_SNS', // ★ 自分が投稿したフラグ
    };
    // データベースに「保存」
    await DatabaseHelper.instance.insertMessage(messageDataMap);
    // SNS投稿を読み込み
    await AppData.loadSnsPosts();

    // ★ 修正点: ベルを鳴らす処理をここに集約
    final currentList = AppData.snsPosts.value;
    currentList.insert(0, {
      "text": postText,
      "timestamp": DateTime.now(),
    });
    AppData.snsPosts.value = List.from(currentList);
  }

  void _showPostModal() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("新しい投稿"),
          content: TextField(
            controller: _postController,
            maxLength: 50,
            decoration: const InputDecoration(
              hintText: "メッセージを入力してください (50文字以内)",
            ),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                _postController.clear();
                Navigator.of(context).pop();
              },
              child: const Text("キャンセル"),
            ),
            ElevatedButton(
              onPressed: () async {
                if (_postController.text.isNotEmpty) {
                  await _addPost(_postController.text);
                  _postController.clear();
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
      appBar: AppBar(title: const Text("避難所SNS")),
      // ★ 修正点: 「ベルの音を聞く担当者 (ValueListenableBuilder)」を配置
      body: ValueListenableBuilder<List<Map<String, dynamic>>>(
        valueListenable: AppData.snsPosts, // このベルを聞く
        builder: (context, allPosts, child) {
          // ベルが鳴るたびに、この中が最新の`allPosts`で再描画される
          final recentPosts = allPosts.where((post) {
            final postTime = post['timestamp'] as DateTime;
            return DateTime.now().difference(postTime).inHours < 3;
          }).toList();

return recentPosts.isEmpty
              ? const Center(child: Text("まだ投稿はありません"))
              : ListView.builder(
                  itemCount: recentPosts.length,
                  itemBuilder: (context, index) {
                    final post = recentPosts[index];
                    final timestamp = post['timestamp'] as DateTime;
                    
                    // ★★★ [追加] 自分が投稿したかどうかのフラグを取得 ★★★
                    final bool isSelf = post['isSelf'] as bool? ?? false;

                    return Card(
                      // 自分の投稿なら色を変える
                      color: isSelf ? Colors.blue[50] : Colors.white, 
                      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 自分の投稿かどうかを表示
                            if (isSelf)
                              Text(
                                "あなたの投稿",
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue[800],
                                ),
                              ),
                            if (isSelf) const SizedBox(height: 4),
                            
                            Text(post["text"] as String? ?? "", style: const TextStyle(fontSize: 16)),
                            const SizedBox(height: 8),
                            Text(
                              "投稿時間: ${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}",
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
      floatingActionButton: FloatingActionButton(
        onPressed: _showPostModal,
        tooltip: '新しい投稿',
        child: const Icon(Icons.add),
      ),
    );
  }
}