import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:anslin/snack_bar.dart';
import 'package:anslin/main.dart';
import 'databasehelper.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';

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

  //位置情報の送信有無
  bool _sendLocationInModal = false;

  //位置情報の取得
  Future<Position?> _getCurrentLocation(BuildContext context) async {
    bool serviceEnabled;
    LocationPermission permission;

    //位置情報サービスの有効化確認
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        showSnackbar(context, '位置情報サービスがオフになっています。オンにしてください。', 3,
            backgroundColor: Colors.red);
      }
      return null; 
    }

    //位置情報権限の確認
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) {
          showSnackbar(
            context,
            '位置情報の権限が拒否されました。',
            3,
            backgroundColor: Colors.red,
          );
        }
        return null;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if(mounted) {
        showSnackbar(
            context, '位置情報の権限が永久に拒否されました。設定から許可してください。', 3,
            backgroundColor: Colors.red);
      }
      return null;
    }

    try {
      if (mounted) {
        showSnackbar(context, '現在地を取得中...', 2);
      }
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
    } catch (e) {
      print("❌ GPSの取得に失敗: $e");
      if (mounted) {
        showSnackbar(
          context,
          'GPSの取得に失敗しました: $e',
          3,
          backgroundColor: Colors.red,
        );
      }
      return null;
    }
  }

  Future<void> _sendMessage(
    BuildContext dialogContext,
    TextEditingController recipientController,
    TextEditingController messageController,
  ) async {
    final toPhoneNumber = _recipientController.text;
    final message = _messageController.text;
    String? coordinatesString;

    if (toPhoneNumber.isNotEmpty &&
        message.isNotEmpty &&
        myPhoneNumber!.isNotEmpty) {
      //message; to_phone_number; message_type; from_phone_number; TTL

      if (_sendLocationInModal) {
      // 位置情報取得
      final Position? pos = await _getCurrentLocation(context);
      if (pos == null) {
        // GPS取得失敗
        if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("GPS取得に失敗したため、送信を中止しました。"), backgroundColor: Colors.red),
          );
        }
         return; 
      }
      // 緯度|経度 の文字列にする
      coordinatesString = "${pos.latitude}|${pos.longitude}";
    }
    String messageToSend = message;
    if (coordinatesString != null) {
      // スイッチONで座標が取れていたら; で結合
      messageToSend = "$message;$coordinatesString";
    }

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
            .invokeMethod<String>('startSendMessage', {
              'message': messageToSend,
              'myPhoneNumber': myPhoneNumber,
              'messageType': 'SafetyCheck',
              'toPhoneNumber': toPhoneNumber,
            });
        final messageDataMap = {
          'type': '2', // 安否確認 (Type 2)
          'content': '宛先: $toPhoneNumber\n内容: $message',
          'coordinates': coordinatesString,
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
    final TextEditingController recipientController = TextEditingController();
    final TextEditingController messageController = TextEditingController();
    _sendLocationInModal = false;
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext dialogContext, StateSetter setModalState) {
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
                    decoration: const InputDecoration(
                      hintText: "メッセージを入力してください (50文字以内)",
                    ),
                    maxLength: _sendLocationInModal ? 40 : 50,
                  ),
                  SwitchListTile(
                    title: const Text('位置情報を送信'),
                    subtitle: Text(
                      _sendLocationInModal ? '(残り40文字)' : '(残り50文字)',
                    ),
                    value: _sendLocationInModal, // 変数と連動
                    onChanged: (bool value) {
                      setModalState(() {
                        _sendLocationInModal = value;
                        if (_messageController.text.length > (_sendLocationInModal ? 40 : 50)) {
                         _messageController.text = _messageController.text.substring(0, (_sendLocationInModal ? 40 : 50));
                      }
                      });
                    },
                    contentPadding: EdgeInsets.zero,
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
                    if ((phoneNumber.length == 10 ||
                            phoneNumber.length == 11) &&
                        message.isNotEmpty) {
                      Navigator.of(context).pop();
                      _sendMessage(
                        dialogContext,
                        recipientController,
                        messageController,
                      );
                    } else {
                      showSnackbar(context, "有効な宛先とメッセージを入力してください", 3);
                    }
                  },
                  child: const Text("送信"),
                ),
                const SizedBox(height: 20), // 上のボタンとの隙間

                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal, 
                    ),
                    child: const Text(
                      '中継DBテスト (1件取得 )',
                      style: TextStyle(color: Colors.white),
                    ),
                    onPressed: () async {
                      final String? messageData =
                          await DatabaseHelper.instance.getRelayMessage();
                       if (messageData != null) {
                        print("取得したデータ: $messageData");
                      } else {
                        print("中継DBは空でした。");
                      }
                    },
                  ),
                const SizedBox(height: 20,),

                ElevatedButton(
                  onPressed: () async{
                  await methodChannel.invokeMethod<String>('routeMessageBridge', {
              'message': "SNSテスト",
              'myPhoneNumber': myPhoneNumber,
              'messageType': 'SNS',
              'toPhoneNumber': "00000000000",
            });
                },
                child: const Text("SNSテスト")
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
