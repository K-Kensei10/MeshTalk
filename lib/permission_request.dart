import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:permission_handler/permission_handler.dart';

final Uri privacyURL = Uri.parse('https://youtube.com');

// ignore: strict_top_level_inference
void checkAndRequestPermissions(context) async {
  final permissions = [
    Permission.bluetooth,
    Permission.bluetoothAdvertise,
    Permission.bluetoothConnect,
    Permission.bluetoothScan,
    Permission.location,
    Permission.notification,
  ];
  bool popShown = false;

  for (final permission in permissions) {
    final status = await permission.status;

    if (!status.isGranted) {
      showPop(context);
      final result = await permission.request();

      if (!result.isGranted && !popShown) {
        showPop(context);
        popShown = true;
      }
    }
  }
}

void showPop(BuildContext context) {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: Text('より良い体験のためBluethoothを使います'),
        content: Text('このアプリではユーザーと通信するためにBluetooth機能が必要です'),
        actions: [
          Column(
            children: [
              Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    //キャンセルボタン
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.all(Radius.circular(100)),
                        ),
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        side: BorderSide(
                          color: Color.fromARGB(255, 219, 219, 219),
                          width: 2,
                        ),
                      ),
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      child: Text('キャンセル'),
                    ),
                    //権限を変更するボタン
                    ElevatedButton(
                      onPressed: () {
                        openAppSettings();
                      },
                      style: ButtonStyle(
                        foregroundColor: WidgetStateProperty.all(Colors.white),
                        backgroundColor: WidgetStateProperty.all(
                          const Color.fromARGB(255, 68, 230, 248),
                        ),
                      ),
                      child: Text('権限の設定'),
                    ),
                  ],
                ),
              ),
              RichText(
                text: TextSpan(
                  text: 'プライバシーポリシー',
                  style: TextStyle(color: Colors.lightBlue),
                  recognizer: TapGestureRecognizer()
                    ..onTap = () {
                      launchUrl(privacyURL);
                    },
                ),
              ),
            ],
          ),
        ],
      );
    },
  );
}
