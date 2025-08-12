import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:meshtalk/permission_request.dart';
import 'package:permission_handler/permission_handler.dart';

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
  bool _dialogShown = false;
  @override
  void initState() {
    super.initState();

    // 描画が終わったあとにダイアログを表示
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_dialogShown) {
        show_dialog(context);
        _dialogShown = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: Text("Mesh Talk メインページ")));
  }
}
