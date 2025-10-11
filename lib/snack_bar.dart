import 'package:flutter/services.dart';
import 'package:flutter/material.dart';

// Kotlin側で定義されたエラーコードと、それに対応する日本語メッセージのマップ
const Map<String, String> _errorMessages = {
  // スキャン機能のエラーコード
  "DEVICE_NOT_FOUND": "デバイスが見つかりませんでした",
  "APP_ERROR": "アプリケーション内部エラー",
  "BLUETOOTH_OFF": "Bluetoothが無効になっています",
  "NO_PERMISSIONS": "必要な権限（パーミッション）がありません",
  "SCAN_FAILED": "スキャン処理が失敗しました",
  // ... (他のエラーコードも含む)
  "UNKNOWN_STATUS": "予期せぬエラーが発生しました",
};

// SnackBar表示のヘルパー関数（このファイル内でしか使わないので `_` を付けて非公開にしても良い）
void _showSnackbar(BuildContext context, String message, Color color) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: color,
      duration: const Duration(seconds: 3),
    ),
  );
}

//  他のファイルから呼び出す関数
void handleScanResultAndShowSnackbar(dynamic result, BuildContext context) {
  // ... (ここに以前提案した結果処理ロジックを全て記述)
  if (result is String) {
    if (result == "scan_successful") {
      _showSnackbar(context, "スキャン成功", Colors.green);
      return;
    }
    _showSnackbar(context, "処理が完了しました: $result", Colors.blue);
    return;
  }

  if (result is PlatformException) {
    final String errorCode = result.code;
    final String message = _errorMessages[errorCode] ?? "不明なエラーが発生しました";
    _showSnackbar(context, message, Colors.red);
    return;
  }

  _showSnackbar(context, "不明な結果が返されました", Colors.orange);
}
