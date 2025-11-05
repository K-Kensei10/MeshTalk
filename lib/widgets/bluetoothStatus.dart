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
  static const _eventChannel = EventChannel('bluetoothStatus');

  bool _isBluetoothOn = true; // 現在のBluetooth状態
  StreamSubscription? _bluetoothStateSubscription; //bluetoothのONOFF監視

  @override
  void initState() {
    super.initState();
    //監視を開始
    _bluetoothStateSubscription = _eventChannel
        .receiveBroadcastStream()
        .cast<bool>()
        .listen(
      (bool isBluetoothOn) {
        // 状態変化ごとにUIを更新
        setState(() {
          _isBluetoothOn = isBluetoothOn;
          print(" [Flutter] Bluetoothの状態が変更されました: $_isBluetoothOn");
        });
      },
      onError: (error) {
        print(" [Flutter] Bluetooth監視エラー: $error");
        setState(() {
          _isBluetoothOn = false; // エラー時はOFFとする
        });
      },
    );
  }

  @override
  void dispose() {
    //監視を停止
    _bluetoothStateSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        //BluetoothがOFFなら、バナーを表示
        if (!_isBluetoothOn)
          Material(
            color: Colors.red.shade700, // バナーの背景色
            elevation: 2,
            child: SafeArea(
              bottom: false, 
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  children: [
                    const Icon(Icons.bluetooth_disabled, color: Colors.white, size: 20),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        "Bluetoothがオフになっています",
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        Expanded(
          child: widget.child,
        ),
      ],
    );
  }
}