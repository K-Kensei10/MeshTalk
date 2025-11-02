import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:anslin/main.dart';
import 'databasehelper.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:anslin/phone_number_request.dart';

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
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    // ★ 入力チェック（空欄なら警告）
    if (phone.isEmpty || message.isEmpty) {
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          const SnackBar(content: Text("宛先とメッセージを入力してください")),
        );
      }
      return;
    }

    // ★ 通信中SnackBar（グルグル付き）
    scaffoldMessenger.showSnackBar(
      SnackBar(
        duration: const Duration(days: 1), // 明示的に閉じるまで表示
        content: Row(
          children: const [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('通信中…'),
          ],
        ),
      ),
    );

    bool responded = false;

    try {
      // ★ Kotlinとの通信を試みる（120秒タイムアウト付き）
      final result = await methodChannel
        .invokeMethod<String>('sendMessage', {
          'message': message,
          'phoneNum': "000000000000",
          'messageType': "safety",
          'targetPhoneNum': phone,
        })
        .timeout(
          const Duration(seconds: 120),
          onTimeout: () {
            responded = true;
            scaffoldMessenger.hideCurrentSnackBar(); // 通信中SnackBarを閉じる
            scaffoldMessenger.showSnackBar(
              const SnackBar(content: Text('タイムアウトしました')),
            );
            throw TimeoutException("送信タイムアウト"); // catchに飛ばす
          },
        );

      // ★ 通信成功時の処理
      if (!responded) {
        scaffoldMessenger.hideCurrentSnackBar();

        if (result == 'success') {
          // ★ 成功時のみDB保存・入力クリア・モーダル閉じる
          final messageDataMap = {
            'type': '2', // 安否確認 (Type 2)
            'content': '宛先: $phone\n内容: $message',
            'from': 'SELF_SENT_SAFETY_CHECK',
          };
          await DatabaseHelper.instance.insertMessage(messageDataMap);
          await AppData.loadSafetyCheckMessages();
          _recipientController.clear();
          _messageController.clear();
          if (mounted) Navigator.of(context).pop();

          scaffoldMessenger.showSnackBar(
            const SnackBar(content: Text('送信が成功しました')),
          );
        } else {
          scaffoldMessenger.showSnackBar(
            const SnackBar(content: Text('予期せぬエラーが発生しました')),
          );
        }
      }
    } on TimeoutException {
      // ★ タイムアウト時はすでにSnackBar表示済みなので何もしない
    } catch (e) {
      // ★ 最初の送信時など、MethodChannel未初期化などの例外をキャッチ
      scaffoldMessenger.hideCurrentSnackBar();
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text('予期せぬエラーが発生しました: $e')),
      );
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
              TextField(
                controller: _recipientController,
                decoration: const InputDecoration(
                  labelText: "宛先（電話番号）",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _messageController,
                decoration: const InputDecoration(
                  labelText: "メッセージ本文",
                  border: OutlineInputBorder(),
                ),
                maxLength: 50,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("キャンセル"),
            ),
            ElevatedButton(onPressed: _sendMessage, child: const Text("送信")),



          //テストボタン
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
                  const messagedata =
                      "Flutterからのテスト;01234567890;2;080-1111-2222;3;202501010000";
                  final result = await methodChannel.invokeMethod(
                    'routeToMessageBridge',
                    messagedata,
                  );
                  // 画面下にメッセージを表示
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text(result)));
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
                  const messagedata =
                      "Flutterからのテスト;01234567890;1;080-1111-2222;3;202501010000";
                  final result = await methodChannel.invokeMethod(
                    'routeToMessageBridge',
                    messagedata,
                  );
                  // 画面下にメッセージを表示
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text(result)));
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
                '自治体連絡テスト実行',
                style: TextStyle(color: Colors.white),
              ),
              onPressed: () async {
                // ボタンが押されたら、Kotlin側の 'runJsonTest' 命令を呼び出す
                try {
                  const messagedata =
                      "Flutterからのテスト;01234567890;4;080-1111-2222;3;202501010000";
                  final result = await methodChannel.invokeMethod(
                    'routeToMessageBridge',
                    messagedata,
                  );
                  // 画面下にメッセージを表示
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text(result)));
                } catch (e) {
                  print('テスト呼び出し中にエラー: $e');
                }
              },
            ),
            const SizedBox(height: 20),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blueGrey, // (色はなんでもOK)
          ),
          child: const Text(
            '中継DB (relay_messages) 確認',
            style: TextStyle(color: Colors.white),
          ),
          onPressed: () async {
            print("--- 🔍 中継DB (relay_messages) の中身 ---");
            
            // 1. さっき作った「全部読む」関数を呼ぶ
            final relayList = await DatabaseHelper.instance.getRelayMessagesForDebug();
            
            if (relayList.isEmpty) {
              print(" (中身は空っぽです)");
            } else {
              // 2. 1件ずつコンソールに表示する
              for (final row in relayList) {
                print(row);
              }
            }
            print("---------------------------------------");
            
            // (確認するだけなのでダイアログは閉じない)
          },
        ),
        //テスト ボタンここまで
        const SizedBox(height: 20), // 上のボタンとの隙間
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red[700], // お掃除なので赤色
            ),
            child: const Text(
              'DBクリーンアップ実行',
              style: TextStyle(color: Colors.white),
            ),
            onPressed: () async {
              print("▶ 手動でDBクリーンアップを実行します...");
              await DatabaseHelper.instance.DatabaseCleanup();
              print("⏹ DBクリーンアップが完了しました。");
            },
          ),
            const SizedBox(height: 20), 
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[900],
              ),
              child: const Text(
                '中継DB (ID 2) 削除テスト',
                style: TextStyle(color: Colors.white),
              ),
              onPressed: () async {
                final scaffoldMessenger = ScaffoldMessenger.of(context);
                
                try {
                  // 1. ID 2 を指定して削除関数を呼び出す
                  await DatabaseHelper.instance.deleterelayMessage(2);

                  print("--- 📨 ID 2 の削除処理が完了 ---");
                  
                  // 2. 完了を通知
                  scaffoldMessenger.showSnackBar(
                    const SnackBar(content: Text("ID 2 の中継メッセージ削除を実行しました"))
                  );

                } catch (e) {
                  print('中継DB(ID 2)削除テスト中にエラー: $e');
                  scaffoldMessenger.showSnackBar(
                    SnackBar(content: Text("エラー: $e"))
                  );
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
    final Color appBarTextColor = Theme.of(context).appBarTheme.foregroundColor ??
        (Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black);

    return Scaffold(
      appBar: AppBar(
        title: const Text("安否確認"),
      actions: [
          Tooltip(
            message: '電話番号の変更',
            child: TextButton.icon(
              icon: Icon(
                Icons.edit_note, 
                color: appBarTextColor, 
              ), 
              label: Text(
                '番号変更',
                style: TextStyle(color: appBarTextColor), 
              ),
            
            // 確認ダイアログ
            onPressed: _showChangePhoneNumberDialog,
            )
      
      ),
      ],
      ),
      // ★ 修正点: 「ベルの音を聞く担当者 (ValueListenableBuilder)」を配置
      body: ValueListenableBuilder<List<Map<String, dynamic>>>(
        valueListenable: AppData.receivedMessages, // このベルを聞く
        builder: (context, messages, child) {
          // ベルが鳴るたびに、この中が最新の`messages`で再描画される
          return Column(
            children: [
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  "受信した安否確認メッセージ",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
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
                      final bool isSelf = msg['isSelf'] as bool? ?? false;

                      final transmissionTimeStr = msg['transmissionTime'] as String?;
                      
                      String formattedSendTime = ""; // 最終的に表示する文字列

                      if (transmissionTimeStr != null && transmissionTimeStr.isNotEmpty) {
                        try {
                          
                          // 前後の空白を取り除く
                          final cleanTimeStr = transmissionTimeStr.trim();

                          //12文字以上あることを確認
                          if (cleanTimeStr.length >= 12) {
                            
                            //先頭12文字を切り取る
                            final finalTimeStr = cleanTimeStr.substring(0, 12);
                            
                            //正規表現で各パーツを抽出
                            final regex = RegExp(r'^(\d{4})(\d{2})(\d{2})(\d{2})(\d{2})$');
                            final match = regex.firstMatch(finalTimeStr);

                            if (match != null) {
                              //分解したパーツを変換
                              final year = int.parse(match.group(1)!);
                              final month = int.parse(match.group(2)!);
                              final day = int.parse(match.group(3)!);
                              final hour = int.parse(match.group(4)!);
                              final minute = int.parse(match.group(5)!);
                              
                              //オブジェクトを組み直す
                              final dt = DateTime(year, month, day, hour, minute);
                              
                              formattedSendTime = "送信日時: ${DateFormat("yyyy/M/d HH:mm").format(dt)}";
                            
                            } else {
                              formattedSendTime = "送信日時不明 (形式エラー)";
                            }
                          } else {
                            formattedSendTime = "送信日時不明 (文字数エラー)";
                          }
                        
                        } catch (e) {
                          formattedSendTime = "送信日時不明 (Exception)"; 
                          print("Error parsing time (manual): $e");
                        }
                      }

                      return Card(
                        color: isSelf
                            ? const Color.fromARGB(255, 151, 255, 159)
                            : Colors.white,
                        margin: const EdgeInsets.symmetric(
                          vertical: 4,
                          horizontal: 8,
                        ),
                        child: ListTile(
                          title: Text(msg['subject'] as String? ?? ''),
                          
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(msg['detail'] as String? ?? '',
                              style: const TextStyle(fontSize: 15),
                              ),

                              Padding(
                                  padding: const EdgeInsets.only(top: 4.0),
                                child: Text(
                                  msg['time'] as String? ?? '',
                                style: const TextStyle(fontSize: 12, color: Colors.black54, fontWeight: FontWeight.bold),
                                   ),
                                ),

                              if (formattedSendTime.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4.0),
                                  child: Text(
                                    formattedSendTime,
                                    style: const TextStyle(fontSize: 12, color: Colors.black54, fontWeight: FontWeight.bold),
                                  ),
                                ),
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
        tooltip: '安否確認メッセージ送信',
        child: const Icon(Icons.add),
      ), 
    );
  }
  Future<void> _showChangePhoneNumberDialog() async {
    
    // ダイアログを表示する
    return showDialog<void>(
      context: context,
      barrierDismissible: false, // (外側をタップしても閉じないようにする)
      builder: (BuildContext dialogContext) {
        
        return AlertDialog(
          title: const Text('電話番号の変更'),
          content: const Text(
            '本当に変更しますか？\n再度、電話番号の入力が必要になります。',
          ),
          actions: <Widget>[
            
            // 「いいえ」ボタン
            TextButton(
              child: const Text('いいえ'),
              onPressed: () {
                Navigator.of(dialogContext).pop(); // ダイアログだけ閉じる
              },
            ),

            // 「はい」ボタン
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: Colors.red, 
              ),
              child: const Text('はい、変更します'),
              onPressed: () async {
                
                // 保存された電話番号を「削除」
                final prefs = await SharedPreferences.getInstance();
                await prefs.remove('my_phone_number');
                
                print("✅ 電話番号を削除しました。入力画面に戻ります。");

                //このダイアログを閉じる
                if (!mounted) return;
                Navigator.of(dialogContext).pop(); 

                //アプリの「全ページ」を破棄して、電話番号入力ページに飛ばす
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(
                    builder: (context) => const PhoneInputPage(),
                  ),
                  (Route<dynamic> route) => false, 
                );
              },
            ),
          ],
        );
      },
    );
  }
}
