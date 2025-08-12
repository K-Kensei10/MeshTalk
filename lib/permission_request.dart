import 'package:flutter/material.dart';

class PermissionRequestMessage extends StatelessWidget {
  const PermissionRequestMessage({super.key});

  @override
  Widget build(BuildContext context) {
    //Bluetoothの権限をリクエストするメッセージウィジェット
    final dialog = AlertDialog(
      title: Text('より良い体験のためBluethoothを使います'),
      content: Text('このアプリではユーザーと通信するためにBluetooth機能が必要です'),
      actions: [
        Column(
          children: [
            Row(
              children: [
                //キャンセルボタン
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.all(Radius.circular(2)),
                    ),
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    side: BorderSide(
                      color: Color.fromARGB(255, 219, 219, 219),
                      width: 2,
                    ),
                  ),
                  onPressed: () {},
                  child: Text('キャンセル'),
                ),
                //権限を変更するボタン
                ElevatedButton(
                  onPressed: () {},
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
            Text(''),
          ],
        ),
      ],
    ); //TODO
    return dialog;
  }
}
