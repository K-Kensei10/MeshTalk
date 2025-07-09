// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import '../styles/text_styles.dart'; 

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'MeshTalk',
          style:  AppTextStyles.appBarTitle,
        ),
      ),
      body: const Center(child: Text('coming soon',
      style: AppTextStyles.bodyText,
      )),
    );
  }
}
