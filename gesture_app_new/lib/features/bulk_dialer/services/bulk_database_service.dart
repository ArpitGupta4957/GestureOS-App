import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:gesture_app/features/bulk_dialer/models/bulk_dialer_models.dart';

class BulkDatabaseService {
  static final BulkDatabaseService _instance = BulkDatabaseService._internal();
  static Database? _database;

  factory BulkDatabaseService() => _instance;

  BulkDatabaseService._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'bulk_dialer.db');

    return await openDatabase(path, version: 1, onCreate: _onCreate);
  }

  Future<void> _onCreate(Database db, int version) async {
    // 1. Sessions Table
    await db.execute('''
      CREATE TABLE sessions(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT,
        created_at TEXT,
        is_archived INTEGER
      )
    ''');

    // 2. Numbers Table
    await db.execute('''
      CREATE TABLE numbers(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        session_id INTEGER,
        phone_number TEXT,
        name TEXT,
        notes TEXT,
        status TEXT,
        last_called_at TEXT,
        FOREIGN KEY (session_id) REFERENCES sessions (id) ON DELETE CASCADE
      )
    ''');
  }

  // --- Session Operations ---

  /// Create a new session
  Future<int> createSession(String name) async {
    final db = await database;
    final session = DialerSessionModel(
      name: name,
      createdAt: DateTime.now().toIso8601String(),
    );
    return await db.insert('sessions', session.toMap());
  }

  /// Get active sessions (not archived)
  Future<List<DialerSessionModel>> getSessions() async {
    final db = await database;
    final maps = await db.query(
      'sessions',
      where: 'is_archived = ?',
      whereArgs: [0],
      orderBy: 'created_at DESC',
    );
    return List.generate(
      maps.length,
      (i) => DialerSessionModel.fromMap(maps[i]),
    );
  }

  /// Archive session (soft delete)
  Future<int> archiveSession(int id) async {
    final db = await database;
    return await db.update(
      'sessions',
      {'is_archived': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Delete session hard (permanently)
  Future<int> deleteSession(int id) async {
    final db = await database;
    // Cascade delete should handle numbers if enabled, but safest to use delete
    return await db.delete('sessions', where: 'id = ?', whereArgs: [id]);
  }

  /// Clean up sessions older than a specific date (for History Retention)
  Future<int> cleanupOldSessions(DateTime threshold) async {
    final db = await database;
    // Delete sessions where created_at < threshold
    return await db.delete(
      'sessions',
      where: 'created_at < ?',
      whereArgs: [threshold.toIso8601String()],
    );
  }

  // --- Number Operations ---

  /// Add numbers to a session
  Future<void> addNumbers(int sessionId, List<BulkNumberModel> numbers) async {
    final db = await database;
    final batch = db.batch();

    for (var number in numbers) {
      batch.insert('numbers', number.toMap());
    }

    await batch.commit(noResult: true);
  }

  /// Get numbers for a session
  Future<List<BulkNumberModel>> getNumbers(int sessionId) async {
    final db = await database;
    final maps = await db.query(
      'numbers',
      where: 'session_id = ?',
      whereArgs: [sessionId],
    );
    return List.generate(maps.length, (i) => BulkNumberModel.fromMap(maps[i]));
  }

  /// Update a number (e.g., status, notes)
  Future<int> updateNumber(BulkNumberModel number) async {
    final db = await database;
    return await db.update(
      'numbers',
      number.toMap(),
      where: 'id = ?',
      whereArgs: [number.id],
    );
  }

  /// Delete a number
  Future<int> deleteNumber(int id) async {
    final db = await database;
    return await db.delete('numbers', where: 'id = ?', whereArgs: [id]);
  }
}
