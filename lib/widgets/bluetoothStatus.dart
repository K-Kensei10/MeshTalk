import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

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

  // ★ 設定アプリを開く関数（Android/iOS両対応）
  Future<void> _openAppSettings() async {
    const url = 'app-settings:'; // iOS/Android共通で設定アプリを開く
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // ★ メイン画面（childを表示）
        Positioned.fill(child: widget.child),

        // ★ BluetoothがOFFのときだけ中央ポップアップ＋暗背景を表示
        if (!_isBluetoothOn) ...[
          // ★ 背景を暗くして操作不可にする
          const ModalBarrier(
            dismissible: false,
            color: Colors.black54,
          ),

          // ★ 中央ポップアップ
          Center(
            child: SizedBox(
              width: MediaQuery.of(context).size.width * 0.8,
              height: 300, // ★ 少し縦長に
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50, // ★ 青系の背景色
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.bluetooth_disabled, size: 64, color: Colors.blue),
                    const SizedBox(height: 24),
                    const Text(
                      "Bluetoothをオンにしてください",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),

                    // ★ 設定を開くボタン
                    ElevatedButton(
                      onPressed: _openAppSettings,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text("設定を開く"),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
