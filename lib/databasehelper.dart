// lib/database_helper.dart

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:async';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();

  // "Database" は sqflite のもの
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('messages.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  // "Database" は sqflite のもの
  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE messages (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        message_type TEXT NOT NULL,
        content TEXT NOT NULL,
        sender_phone_number TEXT NOT NULL,
        received_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
        transmission_time TEXT NULL,
        is_read INTEGER DEFAULT 0,
        sender_coordinates TEXT NULL
      )
    '''); //UI表示用テーブル-自動採番ID-メッセージタイプ-メッセージ本文-送り主の電話番号-受信時間-送信時間-既読フラグ

    await db.execute(
      '''
      CREATE TABLE relay_messages (                             
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      relay_content TEXT NOT NULL,
      relay_from TEXT NOT NULL,
      relay_type TEXT NOT NULL, 
      relay_target TEXT NOT NULL,
      relay_transmission_time TEXT NULL,
      relay_ttl INTEGER NOT NULL,
      relay_received_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
      relay_sender_coordinates TEXT NULL
      )
    ''',
    ); //中継機用テーブル-自動採番ID-メッセージ本文-送り主の電話番号-メッセージタイプ-宛先の電話番号-送信時間-1減らした新しいTTL-中継機が「受信した時間」
  }

  Future<void> insertMessage(Map<String, dynamic> messageData) async {
    final db = await instance.database;
    final String nowLocalString = DateTime.now().toIso8601String().substring(0, 19).replaceFirst('T', ' ');

    // DBに保存する Map を作成
    final Map<String, dynamic> dataToInsert = {
      'message_type': messageData['type'],
      'content': messageData['content'],
      'sender_phone_number': messageData['from'],
      'is_read': 0,
      'received_at': nowLocalString,
    };

    //「送信時間」キーが存在したら、それも Map に追加
    if (messageData.containsKey('transmission_time')) {
      dataToInsert['transmission_time'] = messageData['transmission_time'];
    }

    //「緯度経度」キーが存在したら、Mapに追加
    if (messageData.containsKey('coordinates')) {// 'coordinates' キーが存在したら
      // DBの列名 'sender_coordinates' に、その値 (null か "緯度|経度") を入れる
      dataToInsert['sender_coordinates'] = messageData['coordinates'];
    }

    //  DBに保存する
    await db.insert(
      "messages",
      dataToInsert,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getMessagesByType(String type) async {
    final db = await instance.database;

    final List<Map<String, dynamic>> maps = await db.query(
      "messages",
      where: 'message_type = ?',
      whereArgs: [type],
      orderBy: 'received_at DESC',
    );
    return maps;
  }

  //特定のタイプで未読件数を取得
  Future<int> getUnreadCountByType(String type) async {
    final db = await instance.database;

    final result = await db.rawQuery(
      'SELECT COUNT(*) FROM messages WHERE message_type = ? AND is_read = 0',
      [type],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<int> markMessagesAsRead(String type) async {
    final db = await instance.database;

    // 'messages' テーブルのデータを「更新 (UPDATE)」する
    return await db.update(
      'messages',
      {'is_read': 1}, //is_read'列を 1 (既読) に
      where: 'message_type = ? AND is_read = 0', //typeが一致して、まだ未読 (0) のもの
      whereArgs: [type],
    );
  }

  Future<void> insertRelayMessage(Map<String, dynamic> relayData) async {
    final db = await instance.database;
    final String nowLocalString = DateTime.now().toIso8601String().substring(0, 19).replaceFirst('T', ' ');

    final Map<String, dynamic> dataToInsert = {
      'relay_content': relayData['content'],
      'relay_from': relayData['from'],
      'relay_type': relayData['type'],
      'relay_target': relayData['target'],
      'relay_transmission_time': relayData['transmission_time'],
      'relay_ttl': relayData['ttl'],
      'relay_received_at': nowLocalString,
    };

    if (relayData.containsKey('coordinates')) {
      // DBの 'relay_sender_coordinates' カラムに、その値を入れる
      dataToInsert['relay_sender_coordinates'] = relayData['coordinates'];
    }
    await db.insert(
      "relay_messages",
      dataToInsert, 
      conflictAlgorithm: ConflictAlgorithm.replace 
    );
  }

  Future<List<Map<String, dynamic>>> getRelayMessagesForDebug() async {
    final db = await instance.database;

    try {
      final List<Map<String, dynamic>> maps = await db.query(
        "relay_messages",
        orderBy: 'relay_received_at DESC',
      );
      return maps;
    } catch (e) {
      print("❌ [DB ERROR] 'relay_messages' テーブルの読み込みに失敗: $e");
      print("   もしかして: 'relay_messages' テーブルが存在しない？");
      return []; // エラーが起きても空のリストを返す
    }
  }

  Future<void> DatabaseCleanup() async {
    print('▶ [DB掃除] 定期クリーンアップを開始...');

    // SNSは8時間より古いものを削除
    await deleteSnsMessages(8);

    // 安否確認は1000件を超えていたら古いものから削除
    await deleteMessagesByCount('2', 1000);

    // 自治体からのお知らせは1000件を超えていたら古いものから削除
    await deleteMessagesByCount('4', 1000);

    print('⏹ [DB掃除] 定期クリーンアップが完了しました。');
  }

  Future<void> deleteSnsMessages(int hoursAgo) async {
    try {
      final db = await instance.database;
      final cutoffDateTime = DateTime.now().subtract(
        Duration(hours: hoursAgo),
      ); // 現在時刻から指定時間を引く
      final cutoffString = cutoffDateTime.toIso8601String().substring(0, 19).replaceFirst('T', ' '); // ISO 8601形式に変換し、SQLiteのDATETIME形式に合わせる
      final count = await db.delete(
        // 'messages' テーブルから削除
        'messages',
        where: 'message_type = ? AND received_at < ?',
        whereArgs: ['1', cutoffString],
      ); // received_at が指定時間より前のものを削除
      print('[DB;SNS] $count 件の古いSNSメッセージを削除しました。');
    } catch (e) {
      print('[DB;SNS] エラー: $e');
    }
  }

  Future<void> deleteMessagesByCount(String types, int keepLimit) async {
    try {
      final db = await instance.database;

      const whereClause = 'message_type = ?'; // メッセージタイプでフィルタリング

      final countResult = await db.rawQuery( // 現在の件数を取得
        'SELECT COUNT(*) FROM messages WHERE $whereClause',  
        [types],
      );

      final currentCount = Sqflite.firstIntValue(countResult) ?? 0; // 現在の件数

      if (currentCount <= keepLimit) {
        print(
          '[DB;安否確認or自治体連絡] タイプ $typesの件数 ($currentCount) は上限 ($keepLimit) 以下。削除なし。',
        );
        return;
      }

      final int numToDelete = currentCount - keepLimit;

      final count = await db.rawDelete(
        '''
        DELETE FROM messages
        WHERE id IN (
            SELECT id FROM messages
            WHERE $whereClause
            ORDER BY received_at ASC
            LIMIT ?
        )
        ''',
        [types, numToDelete],
      ); // 古い順に指定件数を削除
      print(
        '[DB;安否確認or自治体連絡] $count 件の古いメッセージ(タイプ: $types)を削除しました。 (上限 $keepLimit 件)',
      );
    } catch (e) {
      print('[DB;安否確認or自治体連絡] エラー: $e');
    }
  }
  Future<void> deleterelayMessage(int id) async { //中継メッセージ削除
    try {
      final db = await instance.database;

      final count = await db.delete( 
        'relay_messages',
        where: 'id = ?',   // IDで指定
        whereArgs: [id],  
      );

      if (count > 0) {
        print('✅ [DB 中継削除] ID $id の中継メッセージを削除しました。');
      } else {
        print('⚠️ [DB 中継削除] ID $id が見つかりませんでした。削除なし。');
      }

    } catch (e) {
      print('❌ [DB 中継削除] ID $id の削除中にエラー: $e');
    }
  }
}
