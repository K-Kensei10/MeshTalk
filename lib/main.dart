import 'package:flutter/material.dart';
import 'package:anslin/phone_number_request.dart';
import 'package:anslin/sns.dart';
import 'package:anslin/safety_sheack_meassage.dart';
import 'package:anslin/goverment_message.dart';
import 'package:anslin/host_auth.dart';
import 'package:anslin/goverment_mode.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/services.dart'; // MethodChannel用

void main() {
  runApp(const MyApp());
}

// ================= グローバル状態管理 =================
class AppData {
  static List<Map<String, String>> officialAnnouncements = [];
  static List<Map<String, String>> receivedMessages = [];
  static List<Map<String, dynamic>> snsPosts = [];

  // Kotlinから受け取ったメッセージをtypeごとに振り分ける関数
  static void addReceivedData(Map<String, dynamic> data) {
    final type = data['type'];
    final text = data['message'];
    final phone = data['from'] ?? "不明";
    final time = "${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')}";

    if (type == 1) {
      snsPosts.insert(0, {
        'text': text,
        'timestamp': DateTime.now(),
      });
    } else if (type == 2) {
      receivedMessages.insert(0, {
        'subject': '安否確認',
        'detail': '電話番号$phoneさんから「$text」が届きました',
        'time': time,
      });
    } else if (type == 3) {
      officialAnnouncements.insert(0, {
        'text': text,
        'time': time,
      });
    }
  }
}

// ================= アプリテーマ =================
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

// ================= メインページ（タブ切替） =================
class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _selectedIndex = 0;

  final List<Widget> _pages = [
    const ShelterSNSPage(),
    const SafetyCheckPage(),
    const LocalGovernmentPage(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  // ← 追加：Kotlinからのメッセージを受け取るためのMethodChannel設定
  static const methodChannel = MethodChannel('anslin.flutter.dev/contact');

  void initPlatformListener() {
    methodChannel.setMethodCallHandler((call) async {
      if (call.method == "displayMessage") {
        final data = Map<String, dynamic>.from(call.arguments);
        AppData.addReceivedData(data); // ← 受信データを振り分けて保存
        setState(() {}); // ← 表示更新（必要に応じて）
        print(data); // ← 受信確認のログ
      }
    });
  }

  @override
  void initState() {
    super.initState();

    // ← 追加：Kotlinとの連携を初期化
    initPlatformListener();

    // 権限確認（元の処理）
    WidgetsBinding.instance.addPostFrameCallback((_) {
      checkAndRequestPermissions();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: "避難所SNS"),
          BottomNavigationBarItem(icon: Icon(Icons.security), label: "安否確認"),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_balance),
            label: "自治体連絡",
          ),
        ],
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
    );
  }
}

// ================= 権限要求 =================
void checkAndRequestPermissions() async {
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

// ================= 電話番号入力画面 =================
class PhoneInputPage extends StatefulWidget {
  const PhoneInputPage({super.key});
  @override
  State<PhoneInputPage> createState() => PhoneInputPageState();
}

// ================= タブ1：自治体連絡 =================
class LocalGovernmentPage extends StatefulWidget {
  const LocalGovernmentPage({super.key});
  @override
  State<LocalGovernmentPage> createState() => LocalGovernmentPageState();
}

// ================= タブ2：安否確認 =================
class SafetyCheckPage extends StatefulWidget {
  const SafetyCheckPage({super.key});
  @override
  State<SafetyCheckPage> createState() => SafetyCheckPageState();
}

// ================= タブ3：避難所SNS =================
class ShelterSNSPage extends StatefulWidget {
  const ShelterSNSPage({super.key});
  @override
  State<ShelterSNSPage> createState() => ShelterSNSPageState();
}

// ================= ホストモード認証ページ =================
class HostAuthPage extends StatefulWidget {
  const HostAuthPage({super.key});
  @override
  State<HostAuthPage> createState() => HostAuthPageState();
}

// ================= ホストモード（自治体）ページ =================
class GovernmentHostPage extends StatefulWidget {
  const GovernmentHostPage({super.key});
  @override
  State<GovernmentHostPage> createState() => GovernmentHostPageState();
}
