import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class BluetoothManager {
  static const MethodChannel _methodChannel = MethodChannel('bluetooth_channel');
  static const EventChannel _eventChannel = EventChannel('bluetooth_events');

  final BuildContext context;

  BluetoothManager(this.context);

  // BluetoothがONかどうかチェックして通知
  Future<void> checkBluetoothStatus() async {
    try {
      final bool isOn = await _methodChannel.invokeMethod('isBluetoothOn');
      if (!isOn) {
        _showNotification("BluetoothがOFFです。ONにしてください。");
      }
    } catch (e) {
      print("Bluetoothチェック中にエラー: $e");
    }
  }

  // Bluetoothの状態変化を監視して通知
  void listenBluetoothChanges() {
    _eventChannel.receiveBroadcastStream().listen((event) {
      if (event == "off") {
        _showNotification("BluetoothがOFFになりました。ONにしてください。");
      }
    });
  }

  // 通知表示（SnackBar）
  void _showNotification(String message) {
    final snackBar = SnackBar(
      content: Text(message),
      backgroundColor: Colors.blueAccent,
      duration: Duration(seconds: 4),
    );
    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }
}
