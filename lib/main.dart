import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:badges/badges.dart' as badges;
import 'databasehelper.dart';
import 'auto_connection.dart';
import 'package:intl/intl.dart';
import 'dart:async';

import 'package:anslin/phone_number_request.dart';
import 'package:anslin/sns.dart';
import 'package:anslin/safety_check_meassage.dart';
import 'package:anslin/goverment_message.dart';
import 'package:anslin/host_auth.dart';
import 'package:anslin/goverment_mode.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized(); // Flutterの初期化を待つ
  final prefs = await SharedPreferences.getInstance();
  final String? myPhoneNumber = prefs.getString(
    'my_phone_number',
  ); // 保存された電話番号を取得
  await AppData.loadInitialData(); //保存データを読み込む
  runApp(MyApp(myPhoneNumber: myPhoneNumber));
}

// アプリ全体で共有するデータ（シンプルな状態管理として利用）
class AppData {
  //ページデータに通知ベルのデータも付与
  // 自治体からのお知らせ
  static final ValueNotifier<List<Map<String, dynamic>>> officialAnnouncements =
      ValueNotifier([]);
  // 避難者から自治体へのメッセージ
  static final ValueNotifier<List<Map<String, dynamic>>> receivedMessages =
      ValueNotifier([]);
  // 避難所SNSの投稿
  static final ValueNotifier<List<Map<String, dynamic>>> snsPosts =
      ValueNotifier([]);

  // 未読カウント用の数字
  static final ValueNotifier<int> unreadSnsCount = ValueNotifier(0);
  static final ValueNotifier<int> unreadSafetyCheckCount = ValueNotifier(0);
  static final ValueNotifier<int> unreadOfficialCount = ValueNotifier(0);

  //各ページデータ、通知件数
  static Future<void> loadInitialData() async {
    // 1. SNS (Type 1)
    await loadSnsPosts();

    // 2. 安否確認 (Type 2)
    await loadSafetyCheckMessages();

    // 3. 自治体連絡 (Type 4)
    await loadOfficialMessages();

    //カウント更新
    await _updateAllUnreadCounts();
  }

  //受け取ったデータをメッセージごとにデータベースに保存
  static Future<void> addReceivedData(
    List<dynamic> data,
    int currentTabIndex,
  ) async {
    final text = data[0] ?? 'メッセージなし';
    final type = data[1].toString();
    final phone = data[2] ?? "不明";
    final transmissionTimeStr = data.length > 3 ? data[3] as String? ?? "" : "";
    final coordinates = data.length > 4 ? data[4] as String? : null;

    //ListをMapに変換
    final messageDataMap = {
      'type': type,
      'content': text,
      'from': phone,
      'coordinates': coordinates,
    };
    // 送信時間を取得してフォーマット
    if (transmissionTimeStr.isNotEmpty) {
      messageDataMap['transmission_time'] = transmissionTimeStr;
    }

    //データベースにデータを追加
    await DatabaseHelper.instance.insertMessage(messageDataMap);

    if (type == '1' && currentTabIndex != 0) {
      unreadSnsCount.value = await DatabaseHelper.instance.getUnreadCountByType(
        '1',
      );
    } else if (type == '2' && currentTabIndex != 1) {
      unreadSafetyCheckCount.value = await DatabaseHelper.instance
          .getUnreadCountByType('2');
    } else if (type == '4' && currentTabIndex != 2) {
      unreadOfficialCount.value = await DatabaseHelper.instance
          .getUnreadCountByType('4');
    }
  }

  //既読をつけて、バッチを消す関数
  static Future<void> resetUnreadCount(int index) async {
    if (index == 0) {
      // 1. DBの Type 1 を「既読」に更新
      await DatabaseHelper.instance.markMessagesAsRead('1');
      // 2. DBから最新の未読件数を取得し、バッジに反映
      unreadSnsCount.value = await DatabaseHelper.instance.getUnreadCountByType(
        '1',
      );
    } else if (index == 1) {
      await DatabaseHelper.instance.markMessagesAsRead('2');
      unreadSafetyCheckCount.value = await DatabaseHelper.instance
          .getUnreadCountByType('2');
    } else if (index == 2) {
      await DatabaseHelper.instance.markMessagesAsRead('4');
      unreadOfficialCount.value = await DatabaseHelper.instance
          .getUnreadCountByType('4');
    }
  }

  // 全ての未読件数を更新する関数
  static Future<void> _updateAllUnreadCounts() async {
    unreadSnsCount.value = await DatabaseHelper.instance.getUnreadCountByType(
      '1',
    );
    unreadSafetyCheckCount.value = await DatabaseHelper.instance
        .getUnreadCountByType('2');
    unreadOfficialCount.value = await DatabaseHelper.instance
        .getUnreadCountByType('4');
  }

  // SNS投稿を読み込む関数
  static Future<void> loadSnsPosts() async {
    final snsData = await DatabaseHelper.instance.getMessagesByType('1');

    const String selfSentFlag = 'SELF_SENT_SNS';

    AppData.snsPosts.value = snsData.map((dbRow) {
      final timestamp = DateTime.parse(dbRow['received_at'] as String);
      final sender = dbRow['sender_phone_number'] as String;
      final content = dbRow['content'] as String;

      // フラグを見て、自分が投稿したかどうかの Boolean
      return {
        'text': content,
        'timestamp': timestamp,
        'isSelf': (sender == selfSentFlag),
      };
    }).toList();
  }

  // 安否確認メッセージを読み込む関数
  static Future<void> loadSafetyCheckMessages() async {
    final safetyData = await DatabaseHelper.instance.getMessagesByType('2');

    // 自分の送信フラグ
    const String selfSentFlag = 'SELF_SENT_SAFETY_CHECK';

    AppData.receivedMessages.value = safetyData.map((dbRow) {
      final time = DateTime.parse(dbRow['received_at'] as String); // 受信時間

      final transmissionTimeStr =
          dbRow['transmission_time'] as String?; // 送信時間 (他人から受信した場合にのみ存在)

      final sender = dbRow['sender_phone_number'] as String;
      final content = dbRow['content'] as String;

      final String? coordinates =
          dbRow['sender_coordinates'] as String?; // 送信者の座標情報 (null か "緯度|経度")

      if (sender == selfSentFlag) {
        final timeStr =
            "送信日時: ${DateFormat("yyyy/M/d HH:mm").format(time)}"; //自分が送ったメッセージの送信日時

        // 自分が送信したメッセージ
        return {
          'subject': '送信済み',
          'detail': content,
          'time': timeStr,
          'isSelf': true,
          'transmissionTime': null,
          'coordinates': coordinates,
        };
      } else {
        // 他人から受信したメッセージ

        final timeStr =
            "受信日時: ${DateFormat("yyyy/M/d HH:mm").format(time)}"; //受信日時

        return {
          'subject': '安否確認 (受信)',
          'detail': '電話番号 $sender さんから「$content」が届きました',
          'time': timeStr,
          'isSelf': false,
          'transmissionTime': transmissionTimeStr,
          'coordinates': coordinates,
        };
      }
    }).toList();
  }

  // 自治体連絡メッセージを読み込む関数
  static Future<void> loadOfficialMessages() async {
    // 1. Type 3 (自分が送信) をDBから取得
    final type3Data = await DatabaseHelper.instance.getMessagesByType('3');
    // 2. Type 4 (自治体から受信) をDBから取得
    final type4Data = await DatabaseHelper.instance.getMessagesByType('4');

    final List<Map<String, dynamic>> allMessages = [];

    // Type 3 (自分が送信) の処理
    for (final dbRow in type3Data) {
      final time = DateTime.parse(dbRow['received_at'] as String);
      final timeStr = "送信: ${DateFormat("yyyy/M/d HH:mm").format(time)}";
      allMessages.add({
        'text': dbRow['content'] as String,
        'time': timeStr,
        'isSelf': true, // ★ Type 3 は「自分」
        'received_at_raw': time,
      });
    }

    // Type 4 (自治体から受信) の処理
    for (final dbRow in type4Data) {
      final time = DateTime.parse(dbRow['received_at'] as String);
      final timeStr = "受信: ${DateFormat("yyyy/M/d HH:mm").format(time)}";
      allMessages.add({
        'text': dbRow['content'] as String,
        'time': timeStr,
        'isSelf': false,
        'received_at_raw': time,
      });
    }

    allMessages.sort((a, b) {
      final aTime = a['received_at_raw'] as DateTime;
      final bTime = b['received_at_raw'] as DateTime;
      return bTime.compareTo(aTime); // 新しい順
    });

    // 5. ベルを鳴らす
    AppData.officialAnnouncements.value = allMessages;
  }
}

//テーマ調整
class MyApp extends StatelessWidget {
  final String? myPhoneNumber;
  const MyApp({super.key, this.myPhoneNumber});

  @override
  Widget build(BuildContext context) {
    final bool hasPhoneNumber = myPhoneNumber?.isNotEmpty ?? false;
    return MaterialApp(
      title: 'ANSLIN',
      theme: ThemeData(
        primarySwatch: Colors.blue, // アクセントカラー（AppBarやボタンなど）
        scaffoldBackgroundColor: const Color(0xFFf5f5f5), // 背景色（画面全体）
        fontFamily: 'Noto Sans JP',
        useMaterial3: true,
      ),
      home: hasPhoneNumber
          ? const MainPage() // hasPhoneNumber=true -> メインページ
          : const PhoneInputPage(), // hasPhoneNumber=false -> 電話番号入力ページ
    );
  }
}

//メインページ
class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  static const methodChannel = MethodChannel('anslin.flutter.dev/contact');
  int _selectedIndex = 0;
  Timer? _timer;

  final List<Widget> _pages = [
    const ShelterSNSPage(),
    const SafetyCheckPage(),
    const LocalGovernmentPage(),
    const HostAuthPage(),
    const GovernmentHostPage(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    AppData.resetUnreadCount(index); // 選択されたタブの未読カウントをリセット

    // 選択されたタブのデータを再読み込み
    if (index == 0) {
      AppData.loadSnsPosts();
    } else if (index == 1) {
      AppData.loadSafetyCheckMessages();
    } else if (index == 2) {
      AppData.loadOfficialMessages();
    }
  }

  @override
  void initState() {
    super.initState();

    _startGlobalTimer();
    _initPlatformListener();

    // 描画が終わったあとにダイアログを表示
    //TEST用
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndRequestPermissions();
      AppData.resetUnreadCount(_selectedIndex);
    });
    AppData.unreadSnsCount.addListener(_resetIfVisible);
    AppData.unreadSafetyCheckCount.addListener(_resetIfVisible);
    AppData.unreadOfficialCount.addListener(_resetIfVisible);
  }

  @override
  void dispose() {
    AppData.unreadSnsCount.removeListener(_resetIfVisible);
    AppData.unreadSafetyCheckCount.removeListener(_resetIfVisible);
    AppData.unreadOfficialCount.removeListener(_resetIfVisible);
    _timer?.cancel();
    super.dispose();
  }

  //定期実行する関数
  void _startGlobalTimer() {
    _timer = Timer.periodic(Duration(seconds: 10), (Timer t) {
      print('定期実行');
      DatabaseHelper.instance.DatabaseCleanup();
      if (connectedDeviceCount() <= 3) {
        autoScan();
        autoAdvertise();
      }
    });
  }

  //現在のタブのカウンターを0にする関数
  void _resetIfVisible() {
    // 現在表示中のタブに対応するカウンターを0にする
    AppData.resetUnreadCount(_selectedIndex);
  }

  void _initPlatformListener() {
    methodChannel.setMethodCallHandler((call) async {
      if (call.method == "displayMessage") {
        final List<dynamic> data = List<dynamic>.from(call.arguments);
        print('KOTLINからの受信成功: $data');

        await AppData.addReceivedData(data, _selectedIndex);

        final type = data[1].toString();

        if (type == '1' && _selectedIndex == 0) {
          await AppData.loadSnsPosts();
          await AppData.resetUnreadCount(0);
        } else if (type == '2' && _selectedIndex == 1) {
          await AppData.loadSafetyCheckMessages();
          await AppData.resetUnreadCount(1);
        } else if (type == '4' && _selectedIndex == 2) {
          await AppData.loadOfficialMessages();
          await AppData.resetUnreadCount(2);
        }
      }
      if (call.method == "saveRelayMessage") {
        try {
          //Kotlinから渡された引数をMapに変換
          final String relayString = call.arguments as String;

          //DBに中継メッセージを保存
          await DatabaseHelper.instance.insertRelayMessage(relayString);
          print(" [Dart] 中継メッセージをDBに保存しました: $relayString");
        } catch (e) {
          print("[Dart] 中継メッセージのDB保存に失敗: $e");
        }
      }
    });
  }

  //バッジ付きアイコンを作成する関数
  Widget _buildIconWithBadge(IconData iconData, ValueNotifier<int> counter) {
    return ValueListenableBuilder<int>(
      valueListenable: counter,
      builder: (context, count, child) {
        return badges.Badge(
          position: badges.BadgePosition.topEnd(top: -10, end: -12), // バッジの位置調整
          showBadge: count > 0, // 未読がなければバッジを非表示
          badgeContent: Text(
            count > 9 ? '9+' : count.toString(), // 9件以上は '9+'
            style: const TextStyle(color: Colors.white, fontSize: 10),
          ),
          child: Icon(iconData), // 元のアイコン
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        //各アイコンにバッジを追加
        items: [
          BottomNavigationBarItem(
            icon: _buildIconWithBadge(Icons.home, AppData.unreadSnsCount),
            label: "避難所SNS",
          ),
          BottomNavigationBarItem(
            icon: _buildIconWithBadge(
              Icons.security,
              AppData.unreadSafetyCheckCount,
            ),
            label: "安否確認",
          ),
          BottomNavigationBarItem(
            icon: _buildIconWithBadge(
              Icons.account_balance,
              AppData.unreadOfficialCount,
            ),
            label: "自治体連絡",
          ),
        ],
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
      ),
    );
  }
}

//権限要求
void _checkAndRequestPermissions() async {
  final permissions = [
    Permission.bluetooth,
    Permission.bluetoothAdvertise,
    Permission.bluetoothConnect,
    Permission.bluetoothScan,
    Permission.location,
    Permission.notification,
  ];

  for (final permission in permissions) {
    final status = await permission.status;

    if (!status.isGranted) {
      await permission.request();
    }
  }
}

int connectedDeviceCount() {
  return 3;
}
