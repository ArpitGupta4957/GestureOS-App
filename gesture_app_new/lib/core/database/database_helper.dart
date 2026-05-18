import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

import 'dart:convert';
import 'package:gesture_app/core/models/gesture_model.dart'; // Correct Import
import 'package:gesture_app/features/bulk_dialer/models/bulk_dialer_models.dart'; // Bulk Dialer Models

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(
      dbPath,
      'gesture_app_offline_v5.db', // Bumped name to force schema refresh if needed
    );

    return await openDatabase(
      path,
      version: 5, // Bumped for Contact Photos
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE gestures (
        uuid TEXT PRIMARY KEY, -- Local Unique ID
        id INTEGER,            -- Server ID (Nullable)
        name TEXT NOT NULL,
        description TEXT,
        points TEXT,           -- JSON string
        trigger_text TEXT,
        action_type TEXT NOT NULL,
        action_value TEXT NOT NULL,
        contact_id TEXT,
        photo_uri TEXT,
        local_photo_path TEXT,
        is_favorite INTEGER DEFAULT 0,
        is_deleted INTEGER DEFAULT 0,  -- Soft delete flag
        is_text_enabled INTEGER DEFAULT 1,
        is_shape_enabled INTEGER DEFAULT 1,
        needs_sync INTEGER DEFAULT 1,
        created_at TEXT,
        updated_at TEXT
      )
    ''');

    // --- BULK DIALER TABLES ---
    await _createBulkTables(db);

    await db.execute('CREATE INDEX idx_trigger_text ON gestures(trigger_text)');
    await db.execute('CREATE INDEX idx_needs_sync ON gestures(needs_sync)');
    await db.execute('CREATE INDEX idx_server_id ON gestures(id)');
    await db.execute('CREATE INDEX idx_is_deleted ON gestures(is_deleted)');
  }

  Future<void> _createBulkTables(Database db) async {
    await db.execute('''
      CREATE TABLE bulk_sessions (
        id INTEGER PRIMARY KEY, -- Server ID (or local negative?)
        name TEXT NOT NULL,
        created_at TEXT,
        is_active INTEGER DEFAULT 0 -- To track last open session
      )
    ''');

    await db.execute('''
      CREATE TABLE bulk_numbers (
        id INTEGER PRIMARY KEY, -- Server ID
        session_id INTEGER NOT NULL,
        phone_number TEXT NOT NULL,
        name TEXT,
        notes TEXT,
        status TEXT DEFAULT 'pending', -- pending, called, skipped
        contact_id TEXT,
        photo_uri TEXT,
        local_photo_path TEXT,
        last_called_at TEXT,
        FOREIGN KEY(session_id) REFERENCES bulk_sessions(id) ON DELETE CASCADE
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Check if column already exists before adding
      final tableInfo = await db.rawQuery('PRAGMA table_info(gestures)');
      final hasIsDeleted = tableInfo.any((col) => col['name'] == 'is_deleted');

      if (!hasIsDeleted) {
        // Add is_deleted column for soft delete support
        await db.execute(
          'ALTER TABLE gestures ADD COLUMN is_deleted INTEGER DEFAULT 0',
        );
      }
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_is_deleted ON gestures(is_deleted)',
      );
    }

    if (oldVersion < 3) {
      final tableInfo = await db.rawQuery('PRAGMA table_info(gestures)');
      final hasTextEnabled = tableInfo.any(
        (col) => col['name'] == 'is_text_enabled',
      );
      final hasShapeEnabled = tableInfo.any(
        (col) => col['name'] == 'is_shape_enabled',
      );

      if (!hasTextEnabled) {
        await db.execute(
          'ALTER TABLE gestures ADD COLUMN is_text_enabled INTEGER DEFAULT 1',
        );
      }
      if (!hasShapeEnabled) {
        await db.execute(
          'ALTER TABLE gestures ADD COLUMN is_shape_enabled INTEGER DEFAULT 1',
        );
      }
    }

    // UPGRADE TO V4 (BULK DIALER)
    if (oldVersion < 4) {
      await _createBulkTables(db);
    }

    // UPGRADE TO V5 (CONTACT PHOTOS)
    if (oldVersion < 5) {
      try {
        await db.execute('ALTER TABLE gestures ADD COLUMN contact_id TEXT');
        await db.execute('ALTER TABLE gestures ADD COLUMN photo_uri TEXT');
        await db.execute(
          'ALTER TABLE gestures ADD COLUMN local_photo_path TEXT',
        );

        await db.execute('ALTER TABLE bulk_numbers ADD COLUMN contact_id TEXT');
        await db.execute('ALTER TABLE bulk_numbers ADD COLUMN photo_uri TEXT');
        await db.execute(
          'ALTER TABLE bulk_numbers ADD COLUMN local_photo_path TEXT',
        );
      } catch (e) {
        print("Error upgrading to v5 (adding photo columns): $e");
      }
    }
  }

  // --- CRUD Operations ---

  /// Insert a new gesture from Model
  Future<int> insertGesture(GestureModel gesture) async {
    final db = await database;
    if (gesture.points.isEmpty) {
      print(
        '❌ [DatabaseHelper] WARNING: Inserting gesture "${gesture.name}" with NO POINTS!',
      );
    } else {
      print(
        '💾 [DatabaseHelper] Inserting "${gesture.name}" with ${gesture.points.length} points.',
      );
    }
    return await db.insert(
      'gestures',
      gesture.toDbMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Get all gestures (Converted to Models) - excludes deleted
  Future<List<GestureModel>> getAllGestures() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'gestures',
      where: 'is_deleted = 0 OR is_deleted IS NULL', // Exclude soft-deleted
      orderBy: 'created_at DESC',
    );

    return List.generate(maps.length, (i) {
      final p = maps[i]['points'];
      // DEBUG LOGGING FOR GESTURE POINTS
      if (maps[i]['points'] is String) {
        final s = maps[i]['points'] as String;
        print(
          "🔍 [DB] Loaded '${maps[i]['name']}': points type=String, length=${s.length}",
        );
        if (s.length < 50) print("   -> Content: $s");
      } else {
        print(
          "🔍 [DB] Loaded '${maps[i]['name']}': points type=${maps[i]['points'].runtimeType}",
        );
      }

      if (p == null || (p is String && p.length < 5)) {
        print("⚠️ [DB] Suspicious points for '${maps[i]['name']}': $p");
      }

      try {
        return GestureModel.fromJson(maps[i]);
      } catch (e) {
        print("❌ [DB] Failed to parse gesture '${maps[i]['name']}': $e");
        // Return a dummy to avoid crash, or rethrow?
        // Better to return valid partial model if possible, or skip in list (but List.generate is fixed size)
        // We will return a model with empty points for now and let UI handle it.
        return GestureModel.fromJson({
          ...maps[i],
          'points': [],
          'points_json': [],
        });
      }
    });
  }

  /// Get favorited gestures (Shortcuts) - excludes deleted
  Future<List<GestureModel>> getShortcuts() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'gestures',
      where: 'is_favorite = 1 AND (is_deleted = 0 OR is_deleted IS NULL)',
      orderBy: 'created_at DESC',
    );
    return List.generate(maps.length, (i) => GestureModel.fromJson(maps[i]));
  }

  /// Update a gesture
  Future<int> updateGesture(GestureModel gesture) async {
    final db = await database;
    var row = gesture.toDbMap();
    row['needs_sync'] = 1; // Mark strictly for sync
    row['updated_at'] = DateTime.now().toIso8601String();

    return await db.update(
      'gestures',
      row,
      where: 'uuid = ?',
      whereArgs: [gesture.uuid],
    );
  }

  /// Soft delete a gesture (marks as deleted, needs_sync for server deletion)
  Future<int> softDeleteGesture(String uuid) async {
    final db = await database;
    print('🗑️ [DatabaseHelper] Soft deleting gesture: $uuid');
    return await db.update(
      'gestures',
      {
        'is_deleted': 1,
        'needs_sync': 1, // Will sync delete to server
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'uuid = ?',
      whereArgs: [uuid],
    );
  }

  /// Get all soft-deleted gestures pending server sync
  Future<List<GestureModel>> getDeletedGestures() async {
    final db = await database;
    final maps = await db.query('gestures', where: 'is_deleted = 1');
    return maps.map((e) => GestureModel.fromJson(e)).toList();
  }

  /// Permanently delete a gesture (after server confirms deletion)
  Future<int> permanentlyDelete(String uuid) async {
    final db = await database;
    print('🗑️ [DatabaseHelper] Permanently deleting: $uuid');
    return await db.delete('gestures', where: 'uuid = ?', whereArgs: [uuid]);
  }

  /// Hard delete a gesture - DEPRECATED, use softDeleteGesture
  @Deprecated('Use softDeleteGesture instead for proper sync')
  Future<int> deleteGesture(String uuid) async {
    final db = await database;
    return await db.delete('gestures', where: 'uuid = ?', whereArgs: [uuid]);
  }

  /// Clear ALL gestures (for forcing re-sync)
  Future<int> clearAllGestures() async {
    final db = await database;
    print('🗑️ [DatabaseHelper] Clearing ALL local gestures...');
    return await db.delete('gestures');
  }

  /// Find by Server ID
  Future<GestureModel?> getByServerId(int serverId) async {
    final db = await database;
    final maps = await db.query(
      'gestures',
      where: 'id = ?',
      whereArgs: [serverId],
      limit: 1,
    );
    if (maps.isNotEmpty) {
      return GestureModel.fromJson(maps.first);
    }
    return null;
  }

  // --- Sync Helpers ---

  /// Get pending uploads
  Future<List<GestureModel>> getPendingSync(
      {bool excludeDeleted = false}) async {
    final db = await database;
    final whereClause = excludeDeleted
        ? 'needs_sync = 1 AND (is_deleted = 0 OR is_deleted IS NULL)'
        : 'needs_sync = 1';
    final maps = await db.query('gestures', where: whereClause);
    return maps.map((e) => GestureModel.fromJson(e)).toList();
  }

  /// Mark as synced (and update Server ID if provided)
  Future<void> markAsSynced(String uuid, {int? newServerId}) async {
    final db = await database;
    Map<String, dynamic> updates = {'needs_sync': 0};
    if (newServerId != null) {
      updates['id'] = newServerId;
    }
    await db.update('gestures', updates, where: 'uuid = ?', whereArgs: [uuid]);
  }

  /// Reset sync status of ALL gestures (Force Push)
  Future<void> resetSyncStatus() async {
    final db = await database;
    print("🔄 [DatabaseHelper] Reseting all gestures to needs_sync = 1");
    // Only reset those that are not deleted (or deleted ones too?)
    // If we want to resync everything, we should reset all.
    await db.rawUpdate('UPDATE gestures SET needs_sync = 1');
  }

  /// Upsert from Server (Pull)
  Future<void> upsertFromServer(List<dynamic> serverData) async {
    final db = await database;

    for (var item in serverData) {
      try {
        // 1. Check if we already have this item to prevent overwriting local changes
        final existing = await db.query(
          'gestures',
          where: 'uuid = ?', // Check by UUID first (primary key)
          whereArgs: [
            item['uuid'] ?? item['id'].toString(),
          ], // Fallback to ID as UUID if legacy
          limit: 1,
        );

        // If not found by UUID, try Server ID (legacy sync)
        List<Map<String, Object?>> existingById = [];
        if (existing.isEmpty && item['id'] != null) {
          existingById = await db.query(
            'gestures',
            where: 'id = ?',
            whereArgs: [item['id']],
            limit: 1,
          );
        }

        final localRecord = existing.isNotEmpty
            ? existing.first
            : (existingById.isNotEmpty ? existingById.first : null);

        if (localRecord != null) {
          // CRITICAL: Local Priority Check
          // If local has pending changes (needs_sync=1) OR is deleted (is_deleted=1),
          // we MUST ignore the server's version. Local is Authority.
          final needsSync = localRecord['needs_sync'] == 1;
          final isDeleted = localRecord['is_deleted'] == 1;

          if (needsSync || isDeleted) {
            print(
              "🛡️ [Sync] IGNORING Server update for '${item['name']}' - Local changes/deletion pending.",
            );
            continue;
          }
        }

        // 2. Preserve UUID if exists, matches Server UUID, or generate new
        final String uuid;
        if (existing.isNotEmpty) {
          uuid = existing.first['uuid'] as String;
        } else if (item['uuid'] != null && item['uuid'].toString().isNotEmpty) {
          // Critical Fix: Use the server's echoed UUID to update our local "id=null" record
          uuid = item['uuid'];
        } else {
          uuid = GestureModel.generateUuid();
        }

        // 3. Prepare row with preserved or new UUID
        // Fix: Prioritize points_json as 'points' might be empty legacy field
        final pointsData = item['points_json'] ?? item['points'] ?? [];

        // FIX: Handle Double-Encoding (Server might send String or List)
        String pointsJson;
        if (pointsData is String) {
          pointsJson = pointsData; // Already a JSON string, usage as-is
        } else {
          pointsJson = jsonEncode(pointsData); // Encode List/Map to JSON string
        }

        if (pointsData is List && pointsData.isNotEmpty) {
          print(
            "💾 [Sync] Saving ${pointsData.length} points for ${item['name']}",
          );
        } else if (pointsData is String) {
          print("💾 [Sync] Saving pre-encoded points for '${item['name']}'");
        }

        // PRESERVE LOCAL-ONLY FIELDS (Server doesn't always echo these back, and replace wipes them)
        final preserveContactId = localRecord != null ? localRecord['contact_id'] : item['contact_id'];
        final preservePhotoUri = localRecord != null ? localRecord['photo_uri'] : item['photo_uri'];
        final preserveLocalPhotoPath = localRecord != null ? localRecord['local_photo_path'] : item['local_photo_path'];

        Map<String, dynamic> row = {
          'uuid': uuid,
          'id': item['id'],
          'name': item['name'],
          'points': pointsJson,
          // NOTE: 'points_json' column doesn't exist in schema, only 'points'
          'trigger_text': item['trigger_text'] ?? item['trigger'],
          'action_type': item['action_type'],
          'action_value': item['action_value'],
          'contact_id': preserveContactId,
          'photo_uri': preservePhotoUri,
          'local_photo_path': preserveLocalPhotoPath,
          'is_favorite': item['is_favorite'] == true ? 1 : 0,
          'created_at': item['created_at'],
          'updated_at': item['updated_at'],
          'needs_sync': 0, // Synced!
        };

        // Auto-Heal: Remove any other gestures with the same name (duplicates)
        // This cleans up "ghost" copies from previous sync bugs.
        await db.delete(
          'gestures',
          where: 'name = ? AND uuid != ?',
          whereArgs: [item['name'], uuid],
        );

        // 4. Insert or replace (will match on uuid PK, preventing duplicates)
        await db.insert(
          'gestures',
          row,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      } catch (e) {
        print("❌ [Sync] ERROR processing item '${item['name']}': $e");
      }
    }
  }

  // --- Bulk Dialer CRUD ---

  /// Save or Update Session
  Future<void> upsertBulkSession(
    DialerSessionModel session, {
    bool isActive = false,
  }) async {
    final db = await database;

    // Reset other active sessions if this one is active
    if (isActive) {
      await db.update('bulk_sessions', {'is_active': 0});
    }

    await db.insert(
        'bulk_sessions',
        {
          'id': session.id,
          'name': session.name,
          'created_at': session.createdAt,
          'is_active': isActive ? 1 : 0,
        },
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Get Last Active Session
  Future<DialerSessionModel?> getLastActiveBulkSession() async {
    final db = await database;
    final res = await db.query(
      'bulk_sessions',
      where: 'is_active = 1',
      limit: 1,
    );
    if (res.isNotEmpty) return DialerSessionModel.fromMap(res.first);

    // Fallback: Get most recent
    final recent = await db.query(
      'bulk_sessions',
      orderBy: 'created_at DESC',
      limit: 1,
    );
    if (recent.isNotEmpty) return DialerSessionModel.fromMap(recent.first);

    return null;
  }

  /// Save Bulk Numbers (Batch)
  Future<void> upsertBulkNumbers(
    int sessionId,
    List<BulkNumberModel> numbers,
  ) async {
    final db = await database;
    final batch = db.batch();

    for (var n in numbers) {
      batch.insert(
          'bulk_numbers',
          {
            'id': n.id,
            'session_id': sessionId, // Use passed ID to be safe
            'phone_number': n.phoneNumber,
            'name': n.name,
            'notes': n.notes,
            'status': n.status.name,
            'last_called_at': n.lastCalledAt?.toIso8601String(),
          },
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  /// Get Numbers for Session
  Future<List<BulkNumberModel>> getBulkNumbers(int sessionId) async {
    final db = await database;
    final res = await db.query(
      'bulk_numbers',
      where: 'session_id = ?',
      whereArgs: [sessionId],
      orderBy: 'id ASC', // Maintain order
    );
    return res.map((e) => BulkNumberModel.fromMap(e)).toList();
  }

  /// Update Single Number Status/Note
  Future<void> updateBulkNumber(BulkNumberModel number) async {
    final db = await database;
    await db.update(
      'bulk_numbers',
      {
        'status': number.status.name,
        'notes': number.notes,
        'last_called_at': number.lastCalledAt?.toIso8601String(),
        'name': number.name,
        'phone_number': number.phoneNumber,
      },
      where: 'id = ?',
      whereArgs: [number.id],
    );
  }

  /// Clear all bulk data (e.g. on logout)
  Future<void> clearBulkData() async {
    final db = await database;
    await db.delete('bulk_numbers');
    await db.delete('bulk_sessions');
  }

  /// Clear all data
  Future<void> clearAll() async {
    final db = await database;
    await db.delete('gestures');
    await clearBulkData();
  }
}
