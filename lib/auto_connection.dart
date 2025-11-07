import 'package:flutter/services.dart';
import 'databasehelper.dart';
import 'dart:async';

const methodChannel = MethodChannel('anslin.flutter.dev/contact');

Future<void> autoScan() async {
  await methodChannel.invokeMethod<String>('startCatchMessage');
}

Future<void> autoAdvertise() async {
  String? relayMessage = await DatabaseHelper.instance.getRelayMessage();
  if (relayMessage == null) {
    return;
  }
  final String? result = await methodChannel.invokeMethod<String>(
    "autoAdvertise",
    {"message": relayMessage},
  );
  if (result != null && result.isNotEmpty) {
    DatabaseHelper.instance.deleteOldestRelayMessage();
  }
}
