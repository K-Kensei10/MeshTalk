import 'package:flutter/material.dart';
import 'package:badges/badges.dart' as badges;

class BadgeIcon extends StatelessWidget {
  final IconData iconData;
  final ValueNotifier<int> counter;

  const BadgeIcon({
    super.key,
    required this.iconData, // アイコンデータ
    required this.counter,  // 未読件数を管理する ValueNotifier
  });

  @override
  Widget build(BuildContext context) {
    // ValueListenableBuilder を使って未読件数の変化を監視
    return ValueListenableBuilder<int>(
      valueListenable: counter,
      builder: (context, count, child) {
        return badges.Badge(
          position: badges.BadgePosition.topEnd(top: -10, end: -12),
          showBadge: count > 0, // 未読がなければバッジを非表示
          badgeContent: Text(
            count > 9 ? '9+' : count.toString(), // 9件以上は '9+'
            style: const TextStyle(color: Colors.white, fontSize: 10),
          ),
          child: Icon(iconData), // 元のアイコン
        );
      },
    );
  }
}