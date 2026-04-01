import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'walk_model.dart';
import 'package:flutter/foundation.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('pawprint.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);
    
    debugPrint('Initializing Database at: $path');

    return await openDatabase(
      path,
      version: 3,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future _createDB(Database db, int version) async {
    const idType = 'INTEGER PRIMARY KEY AUTOINCREMENT';
    const intType = 'INTEGER NOT NULL';
    const doubleType = 'REAL NOT NULL';
    const textType = 'TEXT NOT NULL';

    await db.execute('''
CREATE TABLE walks ( 
  id $idType, 
  startTime $textType,
  durationSeconds $intType,
  distanceMeters $doubleType,
  routePoints TEXT,
  dogNames TEXT
  )
''');
  }

  Future _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE walks ADD COLUMN routePoints TEXT');
      debugPrint('Database upgraded: added routePoints column');
    }
    if (oldVersion < 3) {
      await db.execute('ALTER TABLE walks ADD COLUMN dogNames TEXT');
      debugPrint('Database upgraded: added dogNames column');
    }
  }

  Future<int> create(Walk walk) async {
    final db = await instance.database;
    final id = await db.insert('walks', walk.toMap());
    debugPrint('Walk saved with ID: $id');
    return id;
  }

  Future<Walk> readWalk(int id) async {
    final db = await instance.database;
    final maps = await db.query(
      'walks',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      return Walk.fromMap(maps.first);
    } else {
      throw Exception('ID $id not found');
    }
  }

  Future<List<Walk>> readAllWalks() async {
    final db = await instance.database;
    final orderBy = 'startTime DESC';
    final result = await db.query('walks', orderBy: orderBy);

    return result.map((json) => Walk.fromMap(json)).toList();
  }

  /// Read walks for a specific date (matches by year-month-day)
  Future<List<Walk>> readWalksByDate(DateTime date) async {
    final db = await instance.database;
    final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    final result = await db.query(
      'walks',
      where: "startTime LIKE ?",
      whereArgs: ['$dateStr%'],
      orderBy: 'startTime DESC',
    );
    return result.map((json) => Walk.fromMap(json)).toList();
  }

  Future<int> delete(int id) async {
    final db = await instance.database;
    return await db.delete(
      'walks',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteAllWalks() async {
    final db = await instance.database;
    final count = await db.delete('walks');
    debugPrint('Deleted all $count walks from local database');
    return count;
  }
  
  Future<void> close() async {
    final db = await instance.database;
    db.close();
  }
}
