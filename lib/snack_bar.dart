import 'package:flutter/material.dart';

//snackbarを表示する関数
void showSnackbar(BuildContext context, String message, int duration) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      duration: Duration(seconds: duration),
    ),
  );
}
