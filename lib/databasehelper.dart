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
        is_read INTEGER DEFAULT 0 
      )
    ''');
  }

  Future<void> insertMessage(Map<String, dynamic> messageData) async {
    final db = await instance.database;

    // DBに保存する Map を作成
    final Map<String, dynamic> dataToInsert = {
      'message_type': messageData['type'],
      'content': messageData['content'],
      'sender_phone_number': messageData['from'],
      'is_read': 0,
    };

    //「送信時間」キーが存在したら、それも Map に追加
    if (messageData.containsKey('transmission_time')) {
      dataToInsert['transmission_time'] = messageData['transmission_time'];
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
}
