import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'databasehelper.dart';
import 'dart:async';

const methodChannel = MethodChannel('anslin.flutter.dev/contact');

Future<void> autoScan() async {
  await methodChannel.invokeMethod<String>('startCatchMessage');
}

// Future<void> autoAdvertise() async {

//   if ()
//   await methodChannel.invokeListMethod<String>("");
// }
