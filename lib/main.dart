import 'package:flutter/material.dart';
import 'package:meshtalk/phone_number_request.dart';
import 'package:meshtalk/sns.dart';
import 'package:meshtalk/safety_sheack_meassage.dart';
import 'package:meshtalk/goverment_message.dart';
import 'package:meshtalk/host_auth.dart';
import 'package:meshtalk/goverment_mode.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  runApp(const MyApp());
}

// アプリ全体で共有するデータ（シンプルな状態管理として利用）
class AppData {
  // 自治体からのお知らせ
  static List<Map<String, String>> officialAnnouncements = [];
  // 避難者から自治体へのメッセージ
  static List<Map<String, String>> receivedMessages = [];
  // 避難所SNSの投稿
  static List<Map<String, dynamic>> snsPosts = [];
}

//テーマ調整
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '避難所アプリ',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        fontFamily: 'Noto Sans JP',
        useMaterial3: true,
      ),
      home: PhoneInputPage(),
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

  @override
  void initState() {
    super.initState();

    // 描画が終わったあとにダイアログを表示
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
          BottomNavigationBarItem(icon: Icon(Icons.account_balance),label: "自治体連絡",),
        ],
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
    );
  }
}

//権限要求
void checkAndRequestPermissions() async{
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
    print("a");

    if (!status.isGranted) {
      await permission.request();
      print("askd");
    }
  }
}


// ================= 電話番号入力画面 =================
class PhoneInputPage extends StatefulWidget {
  const PhoneInputPage({super.key});

  //lib\phone_number_request.dart
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
