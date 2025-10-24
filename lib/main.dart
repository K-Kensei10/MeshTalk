import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

// 各ページのファイルをインポート
import 'package:anslin/phone_number_request.dart';
import 'package:anslin/sns.dart';
import 'package:anslin/safety_check_message.dart';
import 'package:anslin/goverment_message.dart';
import 'package:anslin/host_auth.dart';
import 'package:anslin/goverment_mode.dart';
import 'package:badges/badges.dart' as badges;
import 'databasehelper.dart';
import 'package:intl/intl.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppData.loadInitialData();
  runApp(const MyApp());
}

// ==========================================================
//  グローバル状態管理 (データ保管庫)
// ==========================================================
class AppData {
  // ★ 修正点: データを「ベル付きの瓶 (ValueNotifier)」で管理
  static final ValueNotifier<List<Map<String, dynamic>>> officialAnnouncements =
      ValueNotifier([]);
  static final ValueNotifier<List<Map<String, dynamic>>> receivedMessages =
      ValueNotifier([]);
  static final ValueNotifier<List<Map<String, dynamic>>> snsPosts =
      ValueNotifier([]);

  // 未読カウント用の数字
  static final ValueNotifier<int> unreadSnsCount = ValueNotifier(0);
  static final ValueNotifier<int> unreadSafetyCheckCount = ValueNotifier(0);
  static final ValueNotifier<int> unreadOfficialCount = ValueNotifier(0);

  static Future<void> loadInitialData() async {
    // 1. SNS (Type 1)
    await loadSnsPosts();

    // 2. 安否確認 (Type 2)
    await loadSafetyCheckMessages();

    // 3. 自治体連絡 (Type 4)
    await loadOfficialMessages();

    await _updateAllUnreadCounts();
  }

  // ★ 修正点: データが追加されたら「ベルを鳴らす」関数
  static Future<void> addReceivedData(
    List<dynamic> data,
    int currentTabIndex,
  ) async {
    final text = data[0] ?? 'メッセージなし';
    final type = data[1].toString();
    final phone = data[2] ?? "不明";
    final transmissionTimeStr = data.length > 5 ? data[5] as String? ?? "" : "";

    //ListをMapに変換
    final messageDataMap = {'type': type, 'content': text, 'from': phone};
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

    const String selfSentFlag = 'SELF_SENT_SNS'; // さっき決めたフラグ

    AppData.snsPosts.value = snsData.map((dbRow) {
      final timestamp = DateTime.parse(dbRow['received_at'] as String);
      final sender = dbRow['sender_phone_number'] as String;
      final content = dbRow['content'] as String;

      // ★ フラグを見て、自分が投稿したかどうかの Boolean を追加 ★
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
      final time = DateTime.parse(dbRow['received_at'] as String);

      final transmissionTimeStr = dbRow['transmission_time'] as String?;

      String displayTime; // UIに表示する最終的な時間

      if (transmissionTimeStr != null && transmissionTimeStr.isNotEmpty) {
        //「送信時間」がある場合 (他人から受信した)
        try {
          // "yyyyMMddHHmm" 形式の12桁の数字を DateTime オブジェクトに変換
          final dt = DateFormat("yyyyMMddHHmm").parse(transmissionTimeStr);
          // "M/d HH:mm" 形式 (例: "1/1 00:00") に変換
          displayTime = "送信: ${DateFormat("M/d HH:mm").format(dt)}";
        } catch (e) {
          displayTime = "受信: ${DateFormat("M/d HH:mm").format(time)}";
        }
      } else {
        // (B) 「送信時間」がない場合 (自分が送信した)
        displayTime = "受信: ${DateFormat("M/d HH:mm").format(time)}";
      }

      final sender = dbRow['sender_phone_number'] as String;
      final content = dbRow['content'] as String;

      if (sender == selfSentFlag) {
        // 自分が送信したメッセージ
        return {
          'subject': '送信済み',
          'detail': content,
          'time': displayTime,
          'isSelf': true,
          'transmissionTime': null,
        };
      } else {
        // 他人から受信したメッセージ
        return {
          'subject': '安否確認 (受信)',
          'detail': '電話番号 $sender さんから「$content」が届きました',
          'time': displayTime,
          'isSelf': false,
          'transmissionTime': transmissionTimeStr,
        };
      }
    }).toList();
  }

  // 自治体連絡メッセージを読み込む関数
  static Future<void> loadOfficialMessages() async {
    final officialData = await DatabaseHelper.instance.getMessagesByType('4');
    AppData.officialAnnouncements.value = officialData.map((dbRow) {
      final time = DateTime.parse(dbRow['received_at'] as String);
      final timeStr =
          "${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}";
      final content = dbRow['content'] as String;
      return {
        'text': content,
        'time': timeStr,
        'isSelf': false, // (「自分フラグ」はとりあえず false にしておく)
      };
    }).toList();
  }
}

// ==========================================================
//  アプリ本体 (変更なし)
// ==========================================================
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ANSLIN',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        fontFamily: 'Noto Sans JP',
        useMaterial3: true,
      ),
      home: const PhoneInputPage(),
    );
  }
}

// ==========================================================
//  メインページ (タブの司令塔)
// ==========================================================
class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _selectedIndex = 0;
  static const methodChannel = MethodChannel('anslin.flutter.dev/contact');

  // 各ページへの参照 (変更なし)
  final List<Widget> _pages = [
    const ShelterSNSPage(),
    const SafetyCheckPage(),
    const LocalGovernmentPage(),
    const HostAuthPage(),
    const GovernmentHostPage(),
  ];
  void _resetIfVisible() {
    // 現在表示中のタブに対応するカウンターを0にする
    AppData.resetUnreadCount(_selectedIndex);
  }

  @override
  void initState() {
    super.initState();
    _initPlatformListener();
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
    super.dispose();
  }

  void _initPlatformListener() {
    methodChannel.setMethodCallHandler((call) async {
      if (call.method == "displayMessage") {
        final List<dynamic> data = List<dynamic>.from(call.arguments);
        print('KOTLINからの受信成功: $data');

        await AppData.addReceivedData(data, _selectedIndex);

        // 表示中のタブはデータ受信時に更新
        final type = data[1].toString();
        if (type == '1' && _selectedIndex == 0) {
          await AppData.loadSnsPosts();
        } else if (type == '2' && _selectedIndex == 1) {
          await AppData.loadSafetyCheckMessages();
        } else if (type == '4' && _selectedIndex == 2) {
          await AppData.loadOfficialMessages();
        }
      }
    });
  }

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
            icon: _buildIconWithBadge(
              Icons.home,
              AppData.unreadSnsCount,
            ), // バッジ付きアイコンに変更
            label: "避難所SNS",
          ),
          BottomNavigationBarItem(
            icon: _buildIconWithBadge(
              Icons.security,
              AppData.unreadSafetyCheckCount,
            ), // バッジ付きアイコンに変更
            label: "安否確認",
          ),
          BottomNavigationBarItem(
            icon: _buildIconWithBadge(
              Icons.account_balance,
              AppData.unreadOfficialCount,
            ), // バッジ付きアイコンに変更
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

// ==========================================================
//  権限要求 (変更なし)
// ==========================================================
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
    if (await permission.isDenied) {
      await permission.request();
    }
  }
}
