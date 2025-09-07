import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:meshtalk/permission_request.dart';
import 'package:meshtalk/phone_number_request.dart';

void main() {
  runApp(const MainApp());
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
class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mesh Talk',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        fontFamily: 'Noto Sans JP',
        useMaterial3: true,
      ),
      home: PhoneInputPage(),
    );
  }
}

// ================= 電話番号入力画面 =================
class PhoneInputPage extends StatefulWidget {
  const PhoneInputPage({super.key});

  @override
  State<PhoneInputPage> createState() => PhoneInputPageState();
}

class MainPage extends StatefulWidget {
  //widgetに分けて書いていく
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  static const platform = MethodChannel('meshtalk.flutter.dev/contact');
  final _myController = TextEditingController();

  String _buttonText = '送信';
  @override
  void initState() {
    super.initState();

    // 描画が終わったあとにダイアログを表示
    WidgetsBinding.instance.addPostFrameCallback((_) {
      checkAndRequestPermissions(context);
    });
  }

  //メッセージを送信するKotlin関数を呼び出している(copilot製)
  //.\android\app\src\main\kotlin\com\example\meshtalk\MainActivity.kt
  void _sendMessage(String? messageContents) async {
    String buttonText;
    String phoneNumContents = '01234567890';
    String messageTypeContent = '1';
    String targetPhoneNumContents = '09876543210';
    if (messageContents == null) {
      //nullをエラーではじくようなコードを作る
    }
    try {
      buttonText =
          await platform.invokeMethod<String>('createMessage', {
            'message': messageContents,
            'phoneNum': phoneNumContents,
            'messageType': messageTypeContent,
            'targetPhoneNum': targetPhoneNumContents,
          }) ??
          '送信完了';
    } on PlatformException catch (e) {
      buttonText = "$e";
    }
    setState(() {
      _buttonText = buttonText;
    });
  }

  @override
  void dispose() {
    _myController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text("Mesh Talk メインページ"),
            ElevatedButton(
              onPressed: () {
                _sendMessage(_myController.text);
                debugPrint("送信ボタンが押されました");
              },
              child: Text(_buttonText),
            ),
            TextField(controller: _myController),
          ],
        ),
      ),
    );
  }
}
