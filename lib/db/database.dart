import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/models.dart';
import '../models/scoring.dart';

/// Fields for a criterion that doesn't have an id yet.
typedef CriterionDraft = ({
  String name,
  CriterionScope scope,
  CriterionType type,
  String? emoji,
});

/// In-memory copy of a deleted room, kept so the deletion can be undone.
class RoomSnapshot {
  final Room room;
  final Map<int, double> scores;
  final List<MediaItem> media;

  const RoomSnapshot({
    required this.room,
    required this.scores,
    required this.media,
  });
}

/// Local SQLite storage, used through this single instance.
class AppDatabase {
  AppDatabase._();

  static final AppDatabase instance = AppDatabase._();

  Database? _db;

  Future<Database> get database async => _db ??= await _open();

  Future<Database> _open() async {
    final path = join(await getDatabasesPath(), 'borogayo.db');
    return openDatabase(
      path,
      version: 4,
      onConfigure: (db) async {
        // Deleting a parent also deletes its rooms, scores, and media.
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, version) async => _createSchema(db),
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          // Version 2 introduced buildings and changed every table's shape.
          // Older data can't be carried over, so the tables are recreated.
          for (final table in const [
            'media',
            'room_scores',
            'building_scores',
            'rooms',
            'buildings',
            'scores',
            'houses',
            'criteria',
            'projects',
          ]) {
            await db.execute('DROP TABLE IF EXISTS $table');
          }
          await _createSchema(db);
          return;
        }
        // Later versions only add columns, so data is kept.
        if (oldVersion < 3) {
          await db.execute('ALTER TABLE media ADD COLUMN label TEXT');
        }
        if (oldVersion < 4) {
          await db.execute('ALTER TABLE criteria ADD COLUMN emoji TEXT');
          await db.execute('ALTER TABLE media ADD COLUMN thumb_path TEXT');
        }
      },
    );
  }

  Future<void> _createSchema(Database db) async {
    await db.execute('''
      CREATE TABLE projects (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE criteria (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        project_id INTEGER NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
        name TEXT NOT NULL,
        scope TEXT NOT NULL,
        type TEXT NOT NULL,
        weight INTEGER NOT NULL DEFAULT 3,
        position INTEGER NOT NULL DEFAULT 0,
        emoji TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE buildings (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        project_id INTEGER NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
        name TEXT NOT NULL,
        memo TEXT,
        created_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE rooms (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        building_id INTEGER NOT NULL REFERENCES buildings(id) ON DELETE CASCADE,
        name TEXT NOT NULL,
        memo TEXT,
        created_at TEXT NOT NULL
      )
    ''');
    // Separate tables for building and room scores. One table would need two nullable
    // owner columns and a check on every query.
    await db.execute('''
      CREATE TABLE building_scores (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        building_id INTEGER NOT NULL REFERENCES buildings(id) ON DELETE CASCADE,
        criterion_id INTEGER NOT NULL REFERENCES criteria(id) ON DELETE CASCADE,
        value REAL NOT NULL,
        UNIQUE(building_id, criterion_id)
      )
    ''');
    await db.execute('''
      CREATE TABLE room_scores (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        room_id INTEGER NOT NULL REFERENCES rooms(id) ON DELETE CASCADE,
        criterion_id INTEGER NOT NULL REFERENCES criteria(id) ON DELETE CASCADE,
        value REAL NOT NULL,
        UNIQUE(room_id, criterion_id)
      )
    ''');
    await db.execute('''
      CREATE TABLE media (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        building_id INTEGER REFERENCES buildings(id) ON DELETE CASCADE,
        room_id INTEGER REFERENCES rooms(id) ON DELETE CASCADE,
        path TEXT NOT NULL,
        kind TEXT NOT NULL,
        label TEXT,
        thumb_path TEXT,
        created_at TEXT NOT NULL,
        CHECK ((building_id IS NULL) <> (room_id IS NULL))
      )
    ''');
  }

  // ---------- Projects ----------

  Future<List<ProjectSummary>> readProjectSummaries() async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT
        p.id, p.name, p.created_at,
        (SELECT COUNT(*) FROM buildings b WHERE b.project_id = p.id) AS building_count,
        (SELECT COUNT(*) FROM rooms r
           JOIN buildings b2 ON b2.id = r.building_id
          WHERE b2.project_id = p.id) AS room_count
      FROM projects p
      ORDER BY p.created_at DESC
    ''');

    return rows
        .map(
          (row) => ProjectSummary(
            project: Project.fromMap(row),
            buildingCount: row['building_count'] as int,
            roomCount: row['room_count'] as int,
          ),
        )
        .toList();
  }

  /// Creates a project and its criteria in one transaction; a project without criteria is useless.
  Future<int> createProject(String name, List<CriterionDraft> criteria) async {
    final db = await database;
    return db.transaction((txn) async {
      final projectId = await txn.insert('projects', {
        'name': name,
        'created_at': DateTime.now().toIso8601String(),
      });
      for (var i = 0; i < criteria.length; i++) {
        final draft = criteria[i];
        await txn.insert('criteria', {
          'project_id': projectId,
          'name': draft.name,
          'scope': draft.scope.name,
          'type': draft.type.name,
          'weight': 3,
          'position': i,
          'emoji': draft.emoji,
        });
      }
      return projectId;
    });
  }

  Future<void> renameProject(int id, String name) async {
    final db = await database;
    await db.update(
      'projects',
      {'name': name},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteProject(int id) async {
    final db = await database;
    await db.delete('projects', where: 'id = ?', whereArgs: [id]);
  }

  /// "Reset data" in settings. Deleting projects cascades to everything else.
  Future<void> deleteAllProjects() async {
    final db = await database;
    await db.delete('projects');
  }

  // ---------- Name uniqueness ----------
  //
  // Two entries with the same name can't be told apart, which on a ranking screen means
  // picking the wrong place, so duplicates are rejected on input.

  /// [exceptId] is the entry being renamed, which would otherwise collide with itself.
  Future<bool> projectNameExists(String name, {int? exceptId}) =>
      _nameExists('projects', null, null, name, exceptId);

  Future<bool> buildingNameExists(
    int projectId,
    String name, {
    int? exceptId,
  }) => _nameExists('buildings', 'project_id', projectId, name, exceptId);

  Future<bool> roomNameExists(int buildingId, String name, {int? exceptId}) =>
      _nameExists('rooms', 'building_id', buildingId, name, exceptId);

  Future<bool> _nameExists(
    String table,
    String? ownerColumn,
    int? ownerId,
    String name,
    int? exceptId,
  ) async {
    final db = await database;
    final conditions = [
      if (ownerColumn != null) '$ownerColumn = ?',
      'name = ?',
    ];
    final args = <Object?>[if (ownerColumn != null) ownerId, name.trim()];
    if (exceptId != null) {
      conditions.add('id <> ?');
      args.add(exceptId);
    }

    final rows = await db.query(
      table,
      columns: ['id'],
      where: conditions.join(' AND '),
      whereArgs: args,
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  // ---------- Criteria ----------

  Future<List<Criterion>> readCriteria(
    int projectId, {
    CriterionScope? scope,
  }) async {
    final db = await database;
    final rows = await db.query(
      'criteria',
      where: scope == null ? 'project_id = ?' : 'project_id = ? AND scope = ?',
      whereArgs: scope == null ? [projectId] : [projectId, scope.name],
      orderBy: 'position ASC, id ASC',
    );
    return rows.map(Criterion.fromMap).toList();
  }

  Future<void> addCriterion(int projectId, CriterionDraft draft) async {
    final db = await database;
    final existing = await readCriteria(projectId);
    await db.insert('criteria', {
      'project_id': projectId,
      'name': draft.name,
      'scope': draft.scope.name,
      'type': draft.type.name,
      'weight': 3,
      'position': existing.length,
      'emoji': draft.emoji,
    });
  }

  Future<void> updateCriterion(Criterion criterion) async {
    final db = await database;
    await db.update(
      'criteria',
      criterion.toMap(),
      where: 'id = ?',
      whereArgs: [criterion.id],
    );
  }

  /// Whether any score uses this criterion; decides whether to warn before changing its type.
  Future<bool> hasScoresFor(int criterionId) async {
    final db = await database;
    for (final table in const ['building_scores', 'room_scores']) {
      final rows = await db.query(
        table,
        columns: ['id'],
        where: 'criterion_id = ?',
        whereArgs: [criterionId],
        limit: 1,
      );
      if (rows.isNotEmpty) return true;
    }
    return false;
  }

  /// Rounds existing scores to 0 or 10 when a scale criterion becomes binary.
  /// A leftover 7.5 would be neither yes nor no, which the UI can't display.
  Future<void> snapScoresToBinary(int criterionId) async {
    final db = await database;
    for (final table in const ['building_scores', 'room_scores']) {
      await db.rawUpdate(
        'UPDATE $table SET value = CASE WHEN value >= ? THEN ? ELSE 0 END '
        'WHERE criterion_id = ?',
        [kMaxScore / 2, kMaxScore, criterionId],
      );
    }
  }

  Future<void> deleteCriterion(int id) async {
    final db = await database;
    await db.delete('criteria', where: 'id = ?', whereArgs: [id]);
  }

  // ---------- Buildings ----------

  Future<int> createBuilding(int projectId, String name, String? memo) async {
    final db = await database;
    return db.insert('buildings', {
      'project_id': projectId,
      'name': name,
      'memo': memo,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> updateBuilding(int id, String name, String? memo) async {
    final db = await database;
    await db.update(
      'buildings',
      {'name': name, 'memo': memo},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteBuilding(int id) async {
    final db = await database;
    await db.delete('buildings', where: 'id = ?', whereArgs: [id]);
  }

  // ---------- Rooms ----------

  Future<List<Room>> readRooms(int buildingId) async {
    final db = await database;
    final rows = await db.query(
      'rooms',
      where: 'building_id = ?',
      whereArgs: [buildingId],
      orderBy: 'created_at ASC',
    );
    return rows.map(Room.fromMap).toList();
  }

  Future<int> createRoom(int buildingId, String name, String? memo) async {
    final db = await database;
    return db.insert('rooms', {
      'building_id': buildingId,
      'name': name,
      'memo': memo,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> updateRoom(int id, String name, String? memo) async {
    final db = await database;
    await db.update(
      'rooms',
      {'name': name, 'memo': memo},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Deletes a room and returns a snapshot with its scores and media for undo.
  Future<RoomSnapshot?> deleteRoom(int id) async {
    final db = await database;
    final rows = await db.query('rooms', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;

    final snapshot = RoomSnapshot(
      room: Room.fromMap(rows.first),
      scores: await readRoomScores(id),
      media: await readMedia(roomId: id),
    );
    await db.delete('rooms', where: 'id = ?', whereArgs: [id]);
    return snapshot;
  }

  /// Undoes a deletion. The room gets a new id but looks the same to the user.
  Future<void> restoreRoom(RoomSnapshot snapshot) async {
    final db = await database;
    // Criteria may have been deleted in the meantime; restore only scores for existing ones.
    final aliveIds = (await db.query(
      'criteria',
      columns: ['id'],
    )).map((row) => row['id'] as int).toSet();

    await db.transaction((txn) async {
      final roomId = await txn.insert('rooms', {
        'building_id': snapshot.room.buildingId,
        'name': snapshot.room.name,
        'memo': snapshot.room.memo,
        'created_at': snapshot.room.createdAt.toIso8601String(),
      });
      for (final entry in snapshot.scores.entries) {
        if (!aliveIds.contains(entry.key)) continue;
        await txn.insert('room_scores', {
          'room_id': roomId,
          'criterion_id': entry.key,
          'value': entry.value,
        });
      }
      for (final item in snapshot.media) {
        await txn.insert('media', {
          'room_id': roomId,
          'path': item.path,
          'kind': item.kind.name,
          'label': item.label,
          'thumb_path': item.thumbPath,
          'created_at': item.createdAt.toIso8601String(),
        });
      }
    });
  }

  // ---------- Scores ----------

  Future<Map<int, double>> readBuildingScores(int buildingId) async {
    final db = await database;
    final rows = await db.query(
      'building_scores',
      where: 'building_id = ?',
      whereArgs: [buildingId],
    );
    return {
      for (final row in rows)
        row['criterion_id'] as int: (row['value'] as num).toDouble(),
    };
  }

  Future<Map<int, double>> readRoomScores(int roomId) async {
    final db = await database;
    final rows = await db.query(
      'room_scores',
      where: 'room_id = ?',
      whereArgs: [roomId],
    );
    return {
      for (final row in rows)
        row['criterion_id'] as int: (row['value'] as num).toDouble(),
    };
  }

  Future<void> saveBuildingScores(int buildingId, Map<int, double> values) =>
      _saveScores('building_scores', 'building_id', buildingId, values);

  Future<void> saveRoomScores(int roomId, Map<int, double> values) =>
      _saveScores('room_scores', 'room_id', roomId, values);

  Future<void> _saveScores(
    String table,
    String ownerColumn,
    int ownerId,
    Map<int, double> values,
  ) async {
    final db = await database;
    await db.transaction((txn) async {
      // Removed scores must lose their rows to count as unscored again;
      // otherwise they'd vanish from the screen but still affect the ranking.
      // The keys are integers from the database, so joining them is safe.
      final keep = values.keys.join(',');
      await txn.delete(
        table,
        where: values.isEmpty
            ? '$ownerColumn = ?'
            : '$ownerColumn = ? AND criterion_id NOT IN ($keep)',
        whereArgs: [ownerId],
      );

      for (final entry in values.entries) {
        await txn.insert(table, {
          ownerColumn: ownerId,
          'criterion_id': entry.key,
          'value': entry.value,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  // ---------- Photos and videos ----------

  Future<List<MediaItem>> readMedia({int? buildingId, int? roomId}) async {
    final db = await database;
    final rows = await db.query(
      'media',
      where: buildingId != null ? 'building_id = ?' : 'room_id = ?',
      whereArgs: [buildingId ?? roomId],
      orderBy: 'created_at ASC',
    );
    return rows.map(MediaItem.fromMap).toList();
  }

  Future<void> addMedia({
    int? buildingId,
    int? roomId,
    required String path,
    required MediaKind kind,
    String? label,
    String? thumbPath,
  }) async {
    final db = await database;
    await db.insert('media', {
      'building_id': buildingId,
      'room_id': roomId,
      'path': path,
      'kind': kind.name,
      'label': label,
      'thumb_path': thumbPath,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  /// Moves media between a building and a room.
  ///
  /// Exactly one owner column may be set (CHECK constraint), so the other is cleared.
  /// Buildings and rooms use different area names, so a new label is passed in.
  Future<void> moveMedia(
    int id, {
    int? buildingId,
    int? roomId,
    required String label,
  }) async {
    assert(
      (buildingId == null) != (roomId == null),
      'exactly one of buildingId and roomId must be set',
    );
    final db = await database;
    await db.update(
      'media',
      {'building_id': buildingId, 'room_id': roomId, 'label': label},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteMedia(int id) async {
    final db = await database;
    await db.delete('media', where: 'id = ?', whereArgs: [id]);
  }

  /// Every file path still referenced by the database, for storage cleanup.
  Future<Set<String>> readAllMediaPaths() async {
    final db = await database;
    final rows = await db.query('media', columns: ['path', 'thumb_path']);
    return {
      for (final row in rows) ...[
        row['path'] as String,
        ?(row['thumb_path'] as String?),
      ],
    };
  }

  // ---------- Ranking ----------

  /// Every room in the project, ranked in one list regardless of building.
  ///
  /// Rooms are what get chosen, so rooms are ranked. Buildings only hold ratings their
  /// rooms share and have no score of their own.
  ///
  /// - A room's score combines its building's ratings with its own.
  /// - Until everything is scored there is no score, and the room sorts as 0.
  ///   Ties go to rooms with a score, then building and room name.
  Future<List<RoomScore>> readRoomBoard(int projectId) async {
    final db = await database;

    final criteria = await readCriteria(projectId);
    final byId = {for (final criterion in criteria) criterion.id!: criterion};
    final roomCriterionCount = criteria
        .where((criterion) => criterion.scope == CriterionScope.room)
        .length;
    final buildingCriterionCount = criteria.length - roomCriterionCount;

    final buildingRows = await db.query(
      'buildings',
      where: 'project_id = ?',
      whereArgs: [projectId],
    );
    if (buildingRows.isEmpty) return [];
    final buildings = {
      for (final row in buildingRows) row['id'] as int: Building.fromMap(row),
    };

    final roomRows = await db.rawQuery(
      '''
      SELECT r.* FROM rooms r
      JOIN buildings b ON b.id = r.building_id
      WHERE b.project_id = ?
    ''',
      [projectId],
    );
    if (roomRows.isEmpty) return [];

    final buildingScoreRows = await db.rawQuery(
      '''
      SELECT s.building_id, s.criterion_id, s.value FROM building_scores s
      JOIN buildings b ON b.id = s.building_id
      WHERE b.project_id = ?
    ''',
      [projectId],
    );

    final roomScoreRows = await db.rawQuery(
      '''
      SELECT s.room_id, s.criterion_id, s.value FROM room_scores s
      JOIN rooms r ON r.id = s.room_id
      JOIN buildings b ON b.id = r.building_id
      WHERE b.project_id = ?
    ''',
      [projectId],
    );

    Map<int, Map<int, double>> group(
      List<Map<String, Object?>> rows,
      String ownerColumn,
    ) {
      final result = <int, Map<int, double>>{};
      for (final row in rows) {
        result.putIfAbsent(
          row[ownerColumn] as int,
          () => {},
        )[row['criterion_id'] as int] = (row['value'] as num)
            .toDouble();
      }
      return result;
    }

    final byBuilding = group(buildingScoreRows, 'building_id');
    final byRoom = group(roomScoreRows, 'room_id');

    final board = <RoomScore>[];
    for (final row in roomRows) {
      final room = Room.fromMap(row);
      final building = buildings[room.buildingId];
      if (building == null) continue;

      final buildingScores = byBuilding[building.id] ?? const <int, double>{};
      final roomScores = byRoom[room.id] ?? const <int, double>{};
      final result = computeScore(
        scores: {...buildingScores, ...roomScores},
        criteriaById: byId,
      );

      board.add(
        RoomScore(
          room: room,
          building: building,
          percent: result.percent,
          // The progress bar counts room criteria only; building progress is shown on the building screen.
          scoredCount: roomScores.length,
          criterionCount: roomCriterionCount,
          blockedByBuilding:
              (roomCriterionCount == 0 ||
                  roomScores.length >= roomCriterionCount) &&
              buildingCriterionCount > 0 &&
              buildingScores.length < buildingCriterionCount,
        ),
      );
    }

    board.sort(
      _byScore(
        (entry) => entry.percent,
        (entry) => '${entry.building.name} ${entry.room.name}',
      ),
    );
    return board;
  }

  /// For the building list: progress only, since buildings have no score, sorted by name.
  Future<List<BuildingSummary>> readBuildingSummaries(int projectId) async {
    final db = await database;
    final rows = await db.rawQuery(
      '''
      SELECT
        b.id, b.project_id, b.name, b.memo, b.created_at,
        (SELECT COUNT(*) FROM rooms r WHERE r.building_id = b.id) AS room_count,
        (SELECT COUNT(*) FROM building_scores s WHERE s.building_id = b.id) AS scored_count,
        (SELECT COUNT(*) FROM criteria c
          WHERE c.project_id = b.project_id AND c.scope = 'building') AS criterion_count
      FROM buildings b
      WHERE b.project_id = ?
      ORDER BY b.name ASC
    ''',
      [projectId],
    );

    return rows
        .map(
          (row) => BuildingSummary(
            building: Building.fromMap(row),
            roomCount: row['room_count'] as int,
            buildingScoredCount: row['scored_count'] as int,
            buildingCriterionCount: row['criterion_count'] as int,
          ),
        )
        .toList();
  }

  /// Descending score, with unfinished entries as 0 at the bottom.
  /// Ties go to entries with a score, then by name, so the order never shifts between views.
  static int Function(T, T) _byScore<T>(
    double? Function(T) score,
    String Function(T) name,
  ) {
    return (a, b) {
      final byScore = (score(b) ?? 0).compareTo(score(a) ?? 0);
      if (byScore != 0) return byScore;

      final byHasScore = (score(b) != null ? 1 : 0).compareTo(
        score(a) != null ? 1 : 0,
      );
      return byHasScore != 0 ? byHasScore : name(a).compareTo(name(b));
    };
  }
}
