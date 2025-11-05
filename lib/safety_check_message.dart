import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:anslin/main.dart';
import 'databasehelper.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:anslin/phone_number_request.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

// ★ 修正点: StatefulWidgetの「設計図」クラスを追加
class SafetyCheckPage extends StatefulWidget {
  const SafetyCheckPage({super.key});

  @override
  State<SafetyCheckPage> createState() => _SafetyCheckPageState();
}

// ★ 修正点: クラス名をアンダースコア付きに変更
class _SafetyCheckPageState extends State<SafetyCheckPage> {
  static const methodChannel = MethodChannel('anslin.flutter.dev/contact');

  bool _sendLocationInModal = true;

  @override
  void dispose() {
    super.dispose();
  }

  Future<Position?> _getCurrentLocation(BuildContext context) async {
    // 位置情報を取得する関数
    bool serviceEnabled; // 位置情報サービスが有効かどうかのフラグ
    LocationPermission permission; // 位置情報の権限状態

    serviceEnabled =
        await Geolocator.isLocationServiceEnabled(); // 位置情報サービスの有効化確認
    if (!serviceEnabled) {
      // 有効でない場合
      if (mounted) {
        // ウィジェットがまだマウントされているか確認
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            // スナックバーで通知
            content: Text('位置情報サービスがオフになっています。オンにしてください。'),
          ),
        );
      }
      return null; // 位置情報が取得できないのでnullを返す
    }

    permission = await Geolocator.checkPermission(); // 現在の権限状態を確認
    if (permission == LocationPermission.denied) {
      // 権限が拒否されている場合
      permission = await Geolocator.requestPermission(); // 権限をリクエスト
      if (permission == LocationPermission.denied) {
        // まだ拒否されている場合
        if (mounted) {
          // ウィジェットがまだマウントされているか確認
          ScaffoldMessenger.of(context).showSnackBar(
            // スナックバーで通知
            const SnackBar(content: Text('位置情報の権限が拒否されました。')),
          ); // 権限がない場合
        }
        return null;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      // 権限が永久に拒否されている場合
      if (mounted) {
        // ウィジェットがまだマウントされているか確認
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            // スナックバーで通知
            content: Text('位置情報の権限が永久に拒否されました。設定から許可してください。'),
          ),
        );
      }
      return null;
    }

    try {
      if (mounted) {
        // ウィジェットがまだマウントされているか確認
        ScaffoldMessenger.of(context).showSnackBar(
          // スナックバーで通知
          const SnackBar(
            content: Text('現在地を取得中...'),
            duration: Duration(seconds: 2),
          ),
        );
      }
      return await Geolocator.getCurrentPosition(
        // 位置情報を取得
        desiredAccuracy: LocationAccuracy.high, // 高精度の位置情報を要求
        timeLimit: const Duration(seconds: 10), // タイムアウト時間を10秒に設定
      );
    } catch (e) {
      print("❌ GPSの取得に失敗: $e");
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('GPSの取得に失敗しました: $e')));
      }
      return null;
    }
  }

  /// 角度を 8方位の文字列に変換する
  String getDirection(double bearing) {
    // 角度を8方位に変換
    final int index = (((bearing + 22.5) % 360) / 45)
        .floor(); // 角度を45度ごとに区切り、インデックスを計算
    const List<String> directions = [
      '北',
      '北東',
      '東',
      '南東',
      '南',
      '南西',
      '西',
      '北西',
    ];
    return directions[index];
  }

  /// 距離を「m」または「km」の読みやすい文字列に変換する
  String _formatDistance(double distanceInMeters) {
    if (distanceInMeters < 1000) {
      // 1000メートル未満の場合
      return "${distanceInMeters.round()} m"; // メートル単位で表示
    } else {
      final double distanceInKm = distanceInMeters / 1000.0; // メートルをキロメートルに変換
      return "${distanceInKm.toStringAsFixed(1)} km"; // 小数点以下1桁まで表示
    }
  }

  void _sendMessage(
    BuildContext dialogContext,
    TextEditingController recipientController,
    TextEditingController messageController,
  ) async {
    final phone = recipientController.text;
    final message = messageController.text;

    if (phone.isEmpty || message.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("宛先とメッセージを入力してください")));
      }
      return;
    }

    double? latToSend = null;
    double? lonToSend = null;

    // 位置情報を取得 (必要なら)
    if (_sendLocationInModal) {
      final Position? pos = await _getCurrentLocation(context);
      if (pos == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("GPS取得に失敗したため、送信を中止しました。")),
          );
        }
        return; // 送信を中止
      }
      latToSend = pos.latitude;
      lonToSend = pos.longitude;
    }

    // メッセージ送信処理
    try {
      final String result = await MainPage.methodChannel.invokeMethod(
        'sendMessage',
        {
          'message': message,
          'messageType': "2",
          'targetPhoneNum': phone,
          'latitude': latToSend, //null か緯度の double 値
          'longitude': lonToSend, // null か経度の double 値
        },
      );
      print("Kotlinからの送信結果: $result");

      // 自分のDBに保存
      final messageDataMap = {
        'type': '2',
        'content': '宛先: $phone\n内容: $message',
        'from': 'SELF_SENT_SAFETY_CHECK',
        'coordinates': (latToSend != null)
            ? "$latToSend;$lonToSend" // "緯度;経度"
            : null, // null
      };
      await DatabaseHelper.instance.insertMessage(messageDataMap);
      await AppData.loadSafetyCheckMessages(); // リストを再読み込み

      // 4. 成功
      if (mounted) {
        Navigator.of(context).pop(); //ダイアログを閉じる
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("メッセージを送信しました")));
      }
    } catch (e) {
      print(" 送信エラー: $e");
      if (mounted) {
        final errorMessage = (e is PlatformException)
            ? e.message
            : e.toString();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("送信失敗: $errorMessage")));
      }
    }
  }

  void _showMessageModal() {
    final TextEditingController recipientController = TextEditingController();
    final TextEditingController messageController = TextEditingController();

    _sendLocationInModal = true; // モーダル表示時に初期化

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext dialogContext, StateSetter setModalState) {
            // モーダル内で状態を管理するためのStatefulBuilder
            bool sendLocation = _sendLocationInModal; // モーダル内のローカル変数

            return AlertDialog(
              title: const Text("安否確認メッセージ送信"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: recipientController,
                    decoration: const InputDecoration(
                      labelText: "宛先（電話番号）",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: messageController,
                    decoration: const InputDecoration(
                      labelText: "メッセージ本文",
                      border: OutlineInputBorder(),
                    ),
                    maxLength: sendLocation
                        ? 40
                        : 50, // 位置情報を送る場合は40文字、送らない場合は50文字に制限
                  ),
                  SwitchListTile(
                    title: Text('位置情報を送信 (${sendLocation ? 40 : 50}文字)'),
                    value: sendLocation,
                    onChanged: (bool value) {
                      // 1. ダイアログのUIを更新
                      setModalState(() {
                        sendLocation = value;
                      });
                      // 2. クラスの「連絡用」変数も更新
                      _sendLocationInModal = value;
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text("キャンセル"),
                ),
                ElevatedButton(
                  onPressed: () => _sendMessage(
                    dialogContext,
                    recipientController,
                    messageController,
                  ),
                  child: const Text("送信"),
                ),

                //テストボタン
                const SizedBox(height: 20), // ボタンとの間に少し隙間を空ける
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange, // ボタンの色をオレンジに
                  ),
                  child: const Text(
                    '安否確認テスト実行座標あり',
                    style: TextStyle(color: Colors.white),
                  ),
                  onPressed: () async {
                    // ボタンが押されたら、Kotlin側の 'runJsonTest' 命令を呼び出す
                    try {
                      const messagedata =
                          "Flutterからのテスト;37.423717|-122.076796;01234567890;2;080-1111-2222;3;202501010000";
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
                    '安否確認テスト実行座標なし',
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
                    final relayList = await DatabaseHelper.instance
                        .getRelayMessagesForDebug();

                    if (relayList.isEmpty) {
                      print(" (中身は空っぽです)");
                    } else {
                      // 2. 1件ずつコンソールに表示する
                      for (final row in relayList) {
                        print(row);
                      }
                    }
                    print("---------------------------------------");
                  },
                ),
                //テスト ボタンここまで
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final Color appBarTextColor =
        Theme.of(context).appBarTheme.foregroundColor ??
        (Theme.of(context).brightness == Brightness.dark
            ? Colors.white
            : Colors.black);

    return Scaffold(
      appBar: AppBar(
        title: const Text("安否確認"),
        actions: [
          Tooltip(
            message: '電話番号の変更',
            child: TextButton.icon(
              icon: Icon(Icons.edit_note, color: appBarTextColor),
              label: Text('番号変更', style: TextStyle(color: appBarTextColor)),

              // 確認ダイアログ
              onPressed: _showChangePhoneNumberDialog,
            ),
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
                          final String? coords =
                              msg['coordinates'] as String?; // "緯度|経度" か null

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
                                  if (coords != null)
                                    Padding(
                                      padding: const EdgeInsets.only(
                                        top: 8.0,
                                        bottom: 4.0,
                                      ),
                                      child: _buildDistanceInfo(coords),
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
          content: const Text('本当に変更しますか？\n再度、電話番号の入力が必要になります。'),
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
              style: TextButton.styleFrom(foregroundColor: Colors.red),
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

  Widget _buildDistanceInfo(String coordinates) {
    final List<String> parts = coordinates.split('|'); // "緯度|経度" で分割
    if (parts.length != 2) {
      return const Text(
        "座標データが不正です",
        style: TextStyle(color: Colors.red),
      ); // 分割できなかった場合のエラーメッセージ
    }

    final double? theirLat = double.tryParse(parts[0]); // 緯度と経度をパース
    final double? theirLon = double.tryParse(parts[1]); // 緯度と経度をパース

    if (theirLat == null || theirLon == null) {
      return const Text(
        "座標データのパースに失敗",
        style: TextStyle(color: Colors.red),
      ); // パースに失敗した場合のエラーメッセージ
    }

    // 0,0 座標はエラーとして扱う
    if (theirLat == 0.0 && theirLon == 0.0) {
      return const Text(
        "座標データが (0, 0) です",
        style: TextStyle(color: Colors.grey),
      );
    }

    final LatLng theirLatLng = LatLng(theirLat, theirLon); // 相手の座標オブジェクト
    print(
      "相手のLatLng: ${theirLatLng.latitude}, ${theirLatLng.longitude}",
    ); // ★ ログ追加

    // FutureBuilder で「現在地」を取得し、非同期でUIを更新
    return FutureBuilder<Position?>(
      // 位置情報か null を返す
      future: Geolocator.getCurrentPosition(
        // 位置情報を取得
        desiredAccuracy: LocationAccuracy.medium, // 中精度でOK
        timeLimit: const Duration(seconds: 60), // タイムアウト60秒
      ),
      builder: (context, snapshot) {
        // snapshot に取得結果が入る
        if (snapshot.connectionState == ConnectionState.waiting) {
          // まだ取得中
          return const Row(
            children: [
              SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(strokeWidth: 2),
              ), // 小さなローディングアイコン
              SizedBox(width: 8),
              Text(
                "方角・距離を計算中...",
                style: TextStyle(color: Colors.blue, fontSize: 13),
              ), // 読み込み中メッセージ
            ],
          );
        }

        if (snapshot.hasError || !snapshot.hasData || snapshot.data == null) {
          // エラーまたはデータなし
          return const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 16),
              SizedBox(width: 8),
              Text(
                "現在地が取得できず、計算できません",
                style: TextStyle(color: Colors.orange, fontSize: 13),
              ), // エラーメッセージ
            ],
          );
        }

        try {
          final Position myPos = snapshot.data!; // 取得した自分の位置情報
          final LatLng myLatLng = LatLng(
            myPos.latitude,
            myPos.longitude,
          ); // 自分の座標オブジェクト
          print("自分のLatLng: ${myLatLng.latitude}, ${myLatLng.longitude}");
          // 距離と方角を計算
          final calculator = const Distance(); // Distance オブジェクトを作成
          final double distance = calculator.as(
            LengthUnit.Meter,
            myLatLng,
            theirLatLng,
          ); // 距離
          final double bearing = calculator.bearing(
            myLatLng,
            theirLatLng,
          ); // 方角
          print("計算結果 -> 距離: $distance m, 方角: $bearing °");

          // 1m未満は「同じ場所」として扱う
          if (distance < 1.0) {
            return const Row(
              children: [
                Icon(Icons.my_location, color: Colors.green, size: 16),
                SizedBox(width: 8),
                Text(
                  "ほぼ同じ場所にいます",
                  style: TextStyle(
                    color: Colors.green,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            );
          }

          final String direction = getDirection(bearing); // ★ アンダースコア付きに修正済みのはず
          final String formattedDist = _formatDistance(distance);
          print("表示 -> 方角: $direction, 距離: $formattedDist");

          return Row(
            children: [
              Icon(Icons.directions, color: Colors.blue, size: 16),
              SizedBox(width: 8), // アイコンとテキストの間に隙間
              Text(
                "相手は ${getDirection(bearing)} に 約 ${_formatDistance(distance)}", // 方角と距離を表示
                style: const TextStyle(
                  color: Colors.blue,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          );
        } catch (e) {
          return Text(
            "座標の計算エラー: $e",
            style: const TextStyle(color: Colors.red),
          );
        }
      },
    );
  }
}
