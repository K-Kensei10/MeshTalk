import 'package:flutter/material.dart';
import 'screens/home_screen.dart'; // ホーム画面を別ファイルに分ける前提

void main() {
  runApp(const MeshTalkApp());
}

class MeshTalkApp extends StatelessWidget {
  const MeshTalkApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MeshTalk',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.indigo,
        useMaterial3: true,
      ),
      home: const HomeScreen(), // ホーム画面を表示
    );
  }
}
