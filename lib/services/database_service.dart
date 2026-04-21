import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/diary_entry.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  Database? _db;

  Future<Database> get database async {
    _db ??= await _initDatabase();
    return _db!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    return openDatabase(
      join(dbPath, 'daily_diary.db'),
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE diary_entries (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT NOT NULL,
            content TEXT NOT NULL,
            date TEXT NOT NULL,
            photo_paths TEXT,
            mood TEXT,
            weather TEXT,
            location TEXT,
            latitude REAL,
            longitude REAL,
            battery_level INTEGER,
            device_model TEXT,
            steps INTEGER
          )
        ''');
      },
    );
  }

  Future<int> insertEntry(DiaryEntry entry) async {
    final db = await database;
    return db.insert('diary_entries', entry.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<int> updateEntry(DiaryEntry entry) async {
    final db = await database;
    return db.update(
      'diary_entries',
      entry.toMap(),
      where: 'id = ?',
      whereArgs: [entry.id],
    );
  }

  Future<int> deleteEntry(int id) async {
    final db = await database;
    return db.delete('diary_entries', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<DiaryEntry>> getAllEntries() async {
    final db = await database;
    final maps = await db.query('diary_entries', orderBy: 'date DESC');
    return maps.map(DiaryEntry.fromMap).toList();
  }

  Future<DiaryEntry?> getEntryById(int id) async {
    final db = await database;
    final maps =
        await db.query('diary_entries', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return DiaryEntry.fromMap(maps.first);
  }

  Future<List<DiaryEntry>> getEntriesByMonth(int year, int month) async {
    final db = await database;
    final start = DateTime(year, month, 1).toIso8601String();
    final end = DateTime(year, month + 1, 1).toIso8601String();
    final maps = await db.query(
      'diary_entries',
      where: 'date >= ? AND date < ?',
      whereArgs: [start, end],
      orderBy: 'date DESC',
    );
    return maps.map(DiaryEntry.fromMap).toList();
  }

  Future<List<DiaryEntry>> searchEntries(String query) async {
    final db = await database;
    final maps = await db.query(
      'diary_entries',
      where: 'title LIKE ? OR content LIKE ?',
      whereArgs: ['%$query%', '%$query%'],
      orderBy: 'date DESC',
    );
    return maps.map(DiaryEntry.fromMap).toList();
  }
}
