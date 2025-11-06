import 'package:flutter/material.dart';
import 'package:anslin/snack_bar.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

Future<Position?> getCurrentLocation(BuildContext context) async {
  // 位置情報を取得する関数
  bool serviceEnabled; // 位置情報サービスが有効かどうかのフラグ
  LocationPermission permission; // 位置情報の権限状態

  serviceEnabled =
      await Geolocator.isLocationServiceEnabled(); // 位置情報サービスの有効化確認
  if (!serviceEnabled) {
    // 有効でない場合
    if (context.mounted) {
      showSnackbar(context, "位置情報サービスがオフになっています。オンにしてください。", 3, backgroundColor: Colors.red,);
    }
    return null; // 位置情報が取得できないのでnullを返す
  }

  permission = await Geolocator.checkPermission(); // 現在の権限状態を確認
  if (permission == LocationPermission.denied) {
    // 権限が拒否されている場合
    permission = await Geolocator.requestPermission(); // 権限をリクエスト
    if (permission == LocationPermission.denied) {
      // まだ拒否されている場合
      if (context.mounted) {
        showSnackbar(context, "位置情報サービスがオフになっています。オンにしてください。", 3, backgroundColor: Colors.red,);
      }
      return null;
    }
  }

  if (permission == LocationPermission.deniedForever) {
    // 権限が永久に拒否されている場合
    if (context.mounted) {
      showSnackbar(context, "位置情報サービスがオフになっています。オンにしてください。", 3, backgroundColor: Colors.red,);
    }
    return null;
  }

  try {
    if (context.mounted) {
      showSnackbar(
        context,
        "現在位置を取得中",
        10,
        leading: const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    return await Geolocator.getCurrentPosition(
      // 位置情報を取得
      desiredAccuracy: LocationAccuracy.high, // 高精度の位置情報を要求
      timeLimit: const Duration(seconds: 10), // タイムアウト時間を10秒に設定
    );
  } catch (e) {
    if (context.mounted) {
      showSnackbar(context, "GPSの取得に失敗しました。", 3, backgroundColor: Colors.red,);
    }
    return null;
  }
}

// 距離を「m」または「km」の読みやすい文字列に変換する
String formatDistance(double distanceInMeters) {
  if (distanceInMeters < 1000) {
    // 1000メートル未満の場合
    return "${distanceInMeters.round()} m"; // メートル単位で表示
  } else {
    final double distanceInKm = distanceInMeters / 1000.0; // メートルをキロメートルに変換
    return "${distanceInKm.toStringAsFixed(1)} km"; // 小数点以下1桁まで表示
  }
}

// 角度を 8方位の文字列に変換する
String getDirection(double bearing) {
  // 角度を8方位に変換
  final int index = (((bearing + 22.5) % 360) / 45)
      .floor(); // 角度を45度ごとに区切り、インデックスを計算
  const List<String> directions = [
    '北',
    '北東',
    '東',
    '南東',
    '南',
    '南西',
    '西',
    '北西',
  ];
  return directions[index];
}

Widget buildDistanceInfo(String coordinates) {
    final List<String> parts = coordinates.split('|'); // "緯度|経度" で分割
    if (parts.length != 2) {
      return const Text(
        "座標データが不正です",
        style: TextStyle(color: Colors.red),
      ); // 分割できなかった場合のエラーメッセージ
    }

    final double? theirLat = double.tryParse(parts[0]); // 緯度と経度をパース
    final double? theirLon = double.tryParse(parts[1]); // 緯度と経度をパース

    if (theirLat == null || theirLon == null) {
      return const Text(
        "座標データのパースに失敗",
        style: TextStyle(color: Colors.red),
      ); // パースに失敗した場合のエラーメッセージ
    }

    // 0,0 座標はエラーとして扱う
    if (theirLat == 0.0 && theirLon == 0.0) {
      return const Text(
        "座標データが (0, 0) です",
        style: TextStyle(color: Colors.grey),
      );
    }

    final LatLng theirLatLng = LatLng(theirLat, theirLon); // 相手の座標オブジェクト
    print(
      "相手のLatLng: ${theirLatLng.latitude}, ${theirLatLng.longitude}",
    ); // ★ ログ追加

    // FutureBuilder で「現在地」を取得し、非同期でUIを更新
    return FutureBuilder<Position?>(
      // 位置情報か null を返す
      future: Geolocator.getCurrentPosition(
        // 位置情報を取得
        desiredAccuracy: LocationAccuracy.medium, // 中精度でOK
        timeLimit: const Duration(seconds: 5), // タイムアウト5秒
      ),
      builder: (context, snapshot) {
        // snapshot に取得結果が入る
        if (snapshot.connectionState == ConnectionState.waiting) {
          // まだ取得中
          return const Row(
            children: [
              SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(strokeWidth: 2),
              ), // 小さなローディングアイコン
              SizedBox(width: 8),
              Text(
                "方角・距離を計算中...",
                style: TextStyle(color: Colors.blue, fontSize: 13),
              ), // 読み込み中メッセージ
            ],
          );
        }

        if (snapshot.hasError || !snapshot.hasData || snapshot.data == null) {
          // エラーまたはデータなし
          return const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 16),
              SizedBox(width: 8),
              Text(
                "現在地が取得できず、計算できません",
                style: TextStyle(color: Colors.orange, fontSize: 13),
              ), // エラーメッセージ
            ],
          );
        }

        try {
          final Position myPos = snapshot.data!; // 取得した自分の位置情報
          final LatLng myLatLng = LatLng(
            myPos.latitude,
            myPos.longitude,
          ); // 自分の座標オブジェクト
          print("自分のLatLng: ${myLatLng.latitude}, ${myLatLng.longitude}");
          // 距離と方角を計算
          final calculator = const Distance(); // Distance オブジェクトを作成
          final double distance = calculator.as(
            LengthUnit.Meter,
            myLatLng,
            theirLatLng,
          ); // 距離
          final double bearing = calculator.bearing(
            myLatLng,
            theirLatLng,
          ); // 方角
          print("計算結果 -> 距離: $distance m, 方角: $bearing °");

          // 1m未満は「同じ場所」として扱う
          if (distance < 1.0) {
            return const Row(
              children: [
                Icon(Icons.my_location, color: Colors.green, size: 16),
                SizedBox(width: 8),
                Text(
                  "ほぼ同じ場所にいます",
                  style: TextStyle(
                    color: Colors.green,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            );
          }

          final String direction = getDirection(bearing); // ★ アンダースコア付きに修正済みのはず
          final String formattedDist = formatDistance(distance);
          print("表示 -> 方角: $direction, 距離: $formattedDist");

          return Row(
            children: [
              Icon(Icons.directions, color: Colors.blue, size: 16),
              SizedBox(width: 8), // アイコンとテキストの間に隙間
              Text(
                "相手は ${getDirection(bearing)} に 約 ${formatDistance(distance)}", // 方角と距離を表示
                style: const TextStyle(
                  color: Colors.blue,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          );
        } catch (e) {
          return Text(
            "座標の計算エラー: $e",
            style: const TextStyle(color: Colors.red),
          );
        }
      },
    );
  }