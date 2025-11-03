import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:anslin/snack_bar.dart';
import 'package:anslin/main.dart';
import 'databasehelper.dart';
import 'package:intl/intl.dart';

String? myPhoneNumber;

class SafetyCheckPage extends StatefulWidget {
  const SafetyCheckPage({super.key});

  @override
  State<SafetyCheckPage> createState() => _SafetyCheckPageState();
}

class _SafetyCheckPageState extends State<SafetyCheckPage> {
  final TextEditingController _recipientController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();
  static const methodChannel = MethodChannel('anslin.flutter.dev/contact');
  List<String> receivedMessages = [];

  @override
  void dispose() {
    _messageController.dispose();
    _recipientController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadPhoneNumber();
  }

  //電話番後を取得する関数
  Future<void> _loadPhoneNumber() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      myPhoneNumber = prefs.getString('my_phone_number') ?? "00000000000";
    });
  }

  //メッセージを受信する関数
  ScaffoldFeatureController<SnackBar, SnackBarClosedReason>? _receivingSnackBar;

  Future<void> _startCatchMessage({required bool isManual}) async {
    try {
      if (isManual) {
        if (!mounted) return;
        // 「受信中」スナックバーを表示
        _receivingSnackBar = showSnackbar(
          context,
          'メッセージを受信中…',
          120,
          leading: const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        );
      }
      final String? result = await methodChannel.invokeMethod<String>(
        'startCatchMessage',
      );
      if (!mounted) return;
      if (isManual) {
        if (result != null && result.isNotEmpty) {
          // 「受信中」スナックバーを閉じる
          _receivingSnackBar?.close();
          showSnackbar(
            context,
            "メッセージを受信しました。",
            3,
            backgroundColor: Colors.green,
          );
        } else {
          _receivingSnackBar?.close();
          showSnackbar(
            context,
            "メッセージを受信できませんでした。",
            3,
            backgroundColor: Colors.red,
          );
        }
      }
    } on PlatformException catch (e) {
      if (!mounted) return;
      _receivingSnackBar?.close(); // エラー時も閉じる
      if (isManual) {
        showSnackbar(
          context,
          "エラー: ${e.message}",
          3,
          backgroundColor: Colors.red,
        );
      }
    }
  }

  Future<void> _sendMessage() async {
    final toPhoneNumber = _recipientController.text;
    final message = _messageController.text;

    if (toPhoneNumber.isNotEmpty &&
        message.isNotEmpty &&
        myPhoneNumber!.isNotEmpty) {
      //message; to_phone_number; message_type; from_phone_number; TTL
      try {
        // 通信中SnackBar（グルグル付き）
        _receivingSnackBar = showSnackbar(
          context,
          'メッセージを送信中…',
          120,
          leading: const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        );
        final String? result = await methodChannel
            .invokeMethod<String>('routeMessageBridge', {
              'message': message,
              'myPhoneNumber': myPhoneNumber,
              'messageType': 'SafetyCheck',
              'toPhoneNumber': toPhoneNumber,
            });
        final messageDataMap = {
          'type': '2', // 安否確認 (Type 2)
          'content': '宛先: $toPhoneNumber\n内容: $message',
          'from': 'SELF_SENT_SAFETY_CHECK', // (自分だとわかる特殊な文字列)
        };
        if (!mounted) return;
        if (result != null && result.isNotEmpty) {
          _receivingSnackBar?.close();
          showSnackbar(
            context,
            "メッセージを送信しました。",
            3,
            backgroundColor: Colors.green,
          );
          // データベースに保存
          await DatabaseHelper.instance.insertMessage(messageDataMap);
          await AppData.loadSafetyCheckMessages();
          //入力文字リセット
          _recipientController.clear();
          _messageController.dispose();
        } else {
          _receivingSnackBar?.close();
          showSnackbar(
            context,
            "メッセージを送信できませんでした。",
            3,
            backgroundColor: Colors.red,
          );
        }
      } on PlatformException catch (e) {
        if (!mounted) return;
        _receivingSnackBar?.close();
        showSnackbar(
          context,
          "エラー: ${e.message}",
          3,
          backgroundColor: Colors.red,
        );
      }
    } else if (myPhoneNumber == null) {
      if (!mounted) return;
      showSnackbar(
        context,
        "エラーが発生しました。アプリを再起動してください。",
        3,
        backgroundColor: Colors.red,
      );
    }
  }

  void _showPostModal() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("新しい投稿"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _recipientController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: "宛先（電話番号）"),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _messageController,
                maxLength: 50,
                decoration: const InputDecoration(
                  hintText: "メッセージを入力してください (50文字以内)",
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("キャンセル"),
            ),
            ElevatedButton(
              onPressed: () async {
                final phoneNumber = _recipientController.text.replaceAll(
                  '-',
                  '',
                );
                final message = _messageController.text;
                if ((phoneNumber.length == 10 || phoneNumber.length == 11) &&
                    message.isNotEmpty) {
                  Navigator.of(context).pop();
                  _sendMessage();
                } else {
                  showSnackbar(context, "有効な宛先とメッセージを入力してください", 3);
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
        title: const Text("安否確認"),
        actions: [
          IconButton(
            icon: const Icon(Icons.wifi_tethering),
            tooltip: "スキャン",
            onPressed: () => _startCatchMessage(isManual: true),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showPostModal,
        tooltip: '新しい投稿',
        child: const Icon(Icons.add),
      ),
      body: ValueListenableBuilder<List<Map<String, dynamic>>>(
        valueListenable: AppData.receivedMessages, //メッセージを取得
        builder: (context, messages, child) {
          //メッセージを再描画する
          return Column(
            children: [
              Expanded(
                child: messages.isEmpty
                    ? const Center(child: Text("まだメッセージはありません"))
                    //メッセージがあった場合
                    : ListView.builder(
                        itemCount: messages.length,
                        itemBuilder: (context, index) {
                          final msg = messages[index];
                          final bool isSelf = msg['isSelf'] as bool? ?? false;

                          final transmissionTimeStr =
                              msg['transmissionTime'] as String?;

                          String formattedSendTime = ""; // 最終的に表示する文字列

                          if (transmissionTimeStr != null &&
                              transmissionTimeStr.isNotEmpty) {
                            try {
                              // 前後の空白を取り除く
                              final cleanTimeStr = transmissionTimeStr.trim();

                              //12文字以上あることを確認
                              if (cleanTimeStr.length >= 12) {
                                //先頭12文字を切り取る
                                final finalTimeStr = cleanTimeStr.substring(
                                  0,
                                  12,
                                );

                                //正規表現で各パーツを抽出
                                final regex = RegExp(
                                  r'^(\d{4})(\d{2})(\d{2})(\d{2})(\d{2})$',
                                );
                                final match = regex.firstMatch(finalTimeStr);

                                if (match != null) {
                                  //分解したパーツを変換
                                  final year = int.parse(match.group(1)!);
                                  final month = int.parse(match.group(2)!);
                                  final day = int.parse(match.group(3)!);
                                  final hour = int.parse(match.group(4)!);
                                  final minute = int.parse(match.group(5)!);

                                  //オブジェクトを組み直す
                                  final dt = DateTime(
                                    year,
                                    month,
                                    day,
                                    hour,
                                    minute,
                                  );

                                  formattedSendTime =
                                      "送信日時: ${DateFormat("yyyy/M/d HH:mm").format(dt)}";
                                } else {
                                  formattedSendTime = "送信日時不明 (形式エラー)";
                                }
                              } else {
                                formattedSendTime = "送信日時不明 (文字数エラー)";
                              }
                            } catch (e) {
                              formattedSendTime = "送信日時不明 (Exception)";
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
                                  Text(
                                    msg['detail'] as String? ?? '',
                                    style: const TextStyle(fontSize: 15),
                                  ),

                                  Padding(
                                    padding: const EdgeInsets.only(top: 4.0),
                                    child: Text(
                                      msg['time'] as String? ?? '',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.black54,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),

                                  if (formattedSendTime.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4.0),
                                      child: Text(
                                        formattedSendTime,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.black54,
                                          fontWeight: FontWeight.bold,
                                        ),
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
    );
  }
}
