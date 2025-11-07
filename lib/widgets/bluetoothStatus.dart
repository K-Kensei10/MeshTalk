import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class BluetoothStateBanner extends StatefulWidget {
  final Widget child;

  const BluetoothStateBanner({super.key, required this.child});

  @override
  State<BluetoothStateBanner> createState() => _BluetoothStateBannerState();
}

class _BluetoothStateBannerState extends State<BluetoothStateBanner> {
  // ★ Kotlin側からBluetooth状態を受け取るEventChannel
  static const _eventChannel = EventChannel('bluetoothStatus');

  // ★ 現在のBluetooth状態（true: ON, false: OFF）
  bool _isBluetoothOn = true;

  // ★ Bluetooth状態の監視ストリーム
  StreamSubscription? _bluetoothStateSubscription;

  @override
  void initState() {
    super.initState();

    // ★ Bluetooth状態の監視を開始
    _bluetoothStateSubscription = _eventChannel
      .receiveBroadcastStream()
      .cast<bool>()
      .listen(
        (bool isBluetoothOn) {
          // ★ 状態変化ごとにUIを更新
          setState(() {
            _isBluetoothOn = isBluetoothOn;
            print(" [Flutter] Bluetoothの状態が変更されました: $_isBluetoothOn");
          });
        },
        onError: (error) {
          // ★ エラー時はOFFとみなす
          print(" [Flutter] Bluetooth監視エラー: $error");
          setState(() {
            _isBluetoothOn = false;
          });
        },
      );
  }

  @override
  void dispose() {
    // ★ Bluetooth監視を停止
    _bluetoothStateSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // ★ メイン画面（childを表示）
        Positioned.fill(child: widget.child),

        // ★ BluetoothがOFFのときだけ中央ポップアップを表示
        if (!_isBluetoothOn)
          Center(
            child: Container(
              padding: const EdgeInsets.all(24),
              margin: const EdgeInsets.symmetric(horizontal: 32),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.bluetooth_disabled, size: 48, color: Colors.red),
                  SizedBox(height: 16),
                  Text(
                    "Bluetoothをオンにしてください",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
