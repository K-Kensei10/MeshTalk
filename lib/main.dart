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

void main() {
  runApp(const MyApp());
}

// ==========================================================
//  グローバル状態管理 (データ保管庫)
// ==========================================================
class AppData {
  // ★ 修正点: データを「ベル付きの瓶 (ValueNotifier)」で管理
  static final ValueNotifier<List<Map<String, String>>> officialAnnouncements =
      ValueNotifier([]);
  static final ValueNotifier<List<Map<String, String>>> receivedMessages =
      ValueNotifier([]);
  static final ValueNotifier<List<Map<String, dynamic>>> snsPosts =
      ValueNotifier([]);
 
  // 未読カウント用の数字
  static final ValueNotifier<int> unreadSnsCount = ValueNotifier(0);
  static final ValueNotifier<int> unreadSafetyCheckCount = ValueNotifier(0);
  static final ValueNotifier<int> unreadOfficialCount = ValueNotifier(0);

  // ★ 修正点: データが追加されたら「ベルを鳴らす」関数
  static void addReceivedData(List<dynamic> data) {
    // キー指定 (data['type']) からインデックス指定 (data[0]) に変更
    final text = data[0] ?? 'メッセージなし'; // 2番目 (インデックス 1) に message
    final type = data[1].toString(); // 1番目 (インデックス 0) に type
    final phone = data[2] ?? "不明"; // 3番目 (インデックス 2) に from
    final time =
        "${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')}";

    if (type == '1') {
      final currentList = snsPosts.value;
      currentList.insert(0, {'text': text, 'timestamp': DateTime.now()});
      snsPosts.value = List.from(currentList); // SNSのベルを鳴らす！
      unreadSnsCount.value++; // SNSの未読カウントを増やす
    } else if (type == '2') {
      final currentList = receivedMessages.value;
      currentList.insert(0, {
        'subject': '安否確認',
        'detail': '電話番号$phoneさんから「$text」が届きました',
        'time': time,
      });
      receivedMessages.value = List.from(currentList); // 安否確認のベルを鳴らす！
      unreadSafetyCheckCount.value++; // 安否確認の未読カウントを増やす
    } else if (type == '4') {
      final currentList = officialAnnouncements.value;
      currentList.insert(0, {'text': text, 'time': time});
      officialAnnouncements.value = List.from(currentList); // 自治体連絡のベルを鳴らす！
      unreadOfficialCount.value++; // 自治体連絡の未読カウントを増やす
    }
  }

  //指定されたインデックスの未読カウントをリセット
  static void resetUnreadCount(int index) {
    if (index == 0) {
      unreadSnsCount.value = 0;
    } else if (index == 1) {
      unreadSafetyCheckCount.value = 0;
    } else if (index == 2) {
      unreadOfficialCount.value = 0;
    }
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

  @override
  void initState() {
    super.initState();
    _initPlatformListener();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndRequestPermissions();
      AppData.resetUnreadCount(_selectedIndex); 
    });
  }

  void _initPlatformListener() {
    methodChannel.setMethodCallHandler((call) async {
      if (call.method == "displayMessage") {
        final List<dynamic> data = List<dynamic>.from(call.arguments);
        print('KOTLINからの受信成功: $data');
        // ★ 修正点: データ保管庫にデータを追加（自動でベルが鳴る）
        AppData.addReceivedData(data);
        // ★ 修正点: ベルが仕事をするので、このsetStateは不要
      }
    });
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    AppData.resetUnreadCount(index); // 選択されたタブの未読カウントをリセット
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
