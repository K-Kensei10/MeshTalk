import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:meshtalk/permission_request.dart';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(title: 'Mesh Talk', home: MainPage());
  }
}

class MainPage extends StatefulWidget {
  //widgetに分けて書いていく
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  static const platform = MethodChannel('meshtalk.flutter.dev/contact');

  final String _messageContents = 'お水ちょーだい!';
  String _buttonText = '送信';
  @override
  void initState() {
    super.initState();

    // 描画が終わったあとにダイアログを表示
    WidgetsBinding.instance.addPostFrameCallback((_) {
        showPop(context);
    });
  }
  //メッセージを送信するKotlin関数を呼び出している(copilot製)
  //.\android\app\src\main\kotlin\com\example\meshtalk\MainActivity.kt
  void _sendMessage(String messageContents) async {
    String buttonText;
    try {
      buttonText = await platform.invokeMethod<String>('sendMessage', {'message': messageContents}) ?? '送信完了';
    } on PlatformException catch (e) {
      buttonText = "$e";
    }
    setState(() {
      _buttonText = buttonText;
    });
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
                _sendMessage(_messageContents);
                debugPrint("送信ボタンが押されました");
              },
              child: Text(_buttonText),
            ),
          ],
        ),
      ),
    );
  }
}
