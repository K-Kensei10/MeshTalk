import 'package:flutter/material.dart';

//snackbarを表示する関数
ScaffoldFeatureController<SnackBar, SnackBarClosedReason> showSnackbar(
  BuildContext context,
  String message,
  int duration, {
  Widget? leading,
  Color? backgroundColor,
  SnackBarBehavior behavior = SnackBarBehavior.fixed,
}) {
  return ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      duration: Duration(seconds: duration),
      behavior: behavior,
      backgroundColor: backgroundColor,
      content: Row(
        children: [
          if (leading != null) leading,
          if (leading != null) const SizedBox(width: 16),
          Flexible(child: Text(message)),
        ],
      ),
    ),
  );
}

