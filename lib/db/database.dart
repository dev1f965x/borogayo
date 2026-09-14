import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/models.dart';
import '../models/scoring.dart';

/// Criteria a new project starts with until the user edits the defaults.
const _initialPresets = <CriterionDraft>[
  (
    name: '교통',
    scope: CriterionScope.building,
    type: CriterionType.scale,
    emoji: '🚇',
  ),
  (
    name: '주변 편의시설',
    scope: CriterionScope.building,
    type: CriterionType.scale,
    emoji: '🏪',
  ),
  (
    name: '건물 관리 상태',
    scope: CriterionScope.building,
    type: CriterionType.scale,
    emoji: '🧹',
  ),
  (
    name: '주차 가능',
    scope: CriterionScope.building,
    type: CriterionType.binary,
    emoji: '🅿️',
  ),
  (
    name: '엘리베이터',
    scope: CriterionScope.building,
    type: CriterionType.binary,
    emoji: '🛗',
  ),
  (
    name: '채광',
    scope: CriterionScope.room,
    type: CriterionType.scale,
    emoji: '☀️',
  ),
  (
    name: '소음',
    scope: CriterionScope.room,
    type: CriterionType.scale,
    emoji: '🔊',
  ),
  (
    name: '수압',
    scope: CriterionScope.room,
    type: CriterionType.scale,
    emoji: '🚿',
  ),
  (
    name: '곰팡이·결로',
    scope: CriterionScope.room,
    type: CriterionType.scale,
    emoji: '💧',
  ),
  (
    name: '방 크기',
    scope: CriterionScope.room,
    type: CriterionType.scale,
    emoji: '📐',
  ),
  (
    name: '가격',
    scope: CriterionScope.room,
    type: CriterionType.scale,
    emoji: '💰',
  ),
  (
    name: '풀옵션',
    scope: CriterionScope.room,
    type: CriterionType.binary,
    emoji: '🛋️',
  ),
];

/// A deletion that is hidden from every read right away but only written when committed,
/// so it can still be undone. An app killed in between simply keeps the data.
class StagedDeletion {
  StagedDeletion._(this._commit, this._cancel);

  final Future<void> Function() _commit;
  final void Function() _cancel;

  Future<void> commit() => _commit();

  void cancel() => _cancel();
}

/// Scores given with one criterion, kept to undo a type change that rewrote them.
typedef CriterionScores = ({
  Map<int, double> byBuilding,
  Map<int, double> byRoom,
});

/// Local SQLite storage, used through this single instance.
class AppDatabase {
  AppDatabase._();

  static final AppDatabase instance = AppDatabase._();

  Database? _db;

  Future<Database> get database async => _db ??= await _open();

  /// Row ids per table that are staged for deletion and must not appear in reads.
  final _hidden = <String, Set<int>>{};

  Future<Database> _open() async {
    final path = join(await getDatabasesPath(), 'borogayo.db');
    return openDatabase(
      path,
      version: 5,
      onConfigure: (db) async {
        // Deleting a parent also deletes its rooms, scores, and media.
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, version) => _createSchema(db),
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
    await db.execute('''
      CREATE TABLE preset_criteria (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        scope TEXT NOT NULL,
        type TEXT NOT NULL,
        weight INTEGER NOT NULL DEFAULT 3,
        position INTEGER NOT NULL DEFAULT 0,
        emoji TEXT
      )
    ''');
    for (var i = 0; i < _initialPresets.length; i++) {
      await db.insert('preset_criteria', _draftColumns(_initialPresets[i], i));
    }
  }

  static Map<String, Object?> _draftColumns(
    CriterionDraft draft,
    int position,
  ) => {
    'name': draft.name,
    'scope': draft.scope.name,
    'type': draft.type.name,
    'weight': kDefaultWeight,
    'position': position,
    'emoji': draft.emoji,
  };

  // ---------- Staged deletions ----------

  /// SQL condition excluding staged rows of [table], matched on [column].
  String _visible(String table, String column) {
    final ids = _hidden[table];
    return ids == null || ids.isEmpty
        ? '1 = 1'
        : '$column NOT IN (${ids.join(',')})';
  }

  StagedDeletion _stage(
    Map<String, Set<int>> rows,
    Future<void> Function(Database db) write,
  ) {
    void release() {
      for (final entry in rows.entries) {
        _hidden[entry.key]?.removeAll(entry.value);
      }
    }

    for (final entry in rows.entries) {
      (_hidden[entry.key] ??= {}).addAll(entry.value);
    }
    return StagedDeletion._(() async {
      await write(await database);
      release();
    }, release);
  }

  StagedDeletion _stageRow(String table, int id) => _stage({
    table: {id},
  }, (db) => db.delete(table, where: 'id = ?', whereArgs: [id]));

  // ---------- Projects ----------

  Future<List<ProjectSummary>> readProjectSummaries() async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT
        p.id, p.name, p.created_at,
        (SELECT COUNT(*) FROM buildings b
          WHERE b.project_id = p.id AND ${_visible('buildings', 'b.id')}
            AND EXISTS (SELECT 1 FROM rooms r
                         WHERE r.building_id = b.id AND ${_visible('rooms', 'r.id')})
        ) AS building_count,
        (SELECT COUNT(*) FROM rooms r
           JOIN buildings b ON b.id = r.building_id
          WHERE b.project_id = p.id
            AND ${_visible('buildings', 'b.id')} AND ${_visible('rooms', 'r.id')}
        ) AS room_count
      FROM projects p
      WHERE ${_visible('projects', 'p.id')}
      ORDER BY p.created_at DESC
    ''');

    return [
      for (final row in rows)
        ProjectSummary(
          project: Project.fromMap(row),
          buildingCount: row['building_count'] as int,
          roomCount: row['room_count'] as int,
        ),
    ];
  }

  /// Creates a project with a copy of the default criteria.
  Future<int> createProject(String name) async {
    final db = await database;
    final presets = await readPresets();
    return db.transaction((txn) async {
      final projectId = await txn.insert('projects', {
        'name': name,
        'created_at': DateTime.now().toIso8601String(),
      });
      for (final preset in presets) {
        await txn.insert('criteria', {
          ...preset.toColumns(),
          'project_id': projectId,
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

  StagedDeletion stageProjectDeletion(int id) => _stageRow('projects', id);

  /// "Delete all data" in settings. Deleting projects cascades to everything else.
  Future<StagedDeletion> stageAllProjectsDeletion() async {
    final db = await database;
    final ids = {
      for (final row in await db.query(
        'projects',
        columns: ['id'],
        where: _visible('projects', 'id'),
      ))
        row['id'] as int,
    };
    return _stage({'projects': ids}, (db) async {
      if (ids.isEmpty) return;
      await db.delete('projects', where: 'id IN (${ids.join(',')})');
    });
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
    final rows = await db.query(
      table,
      columns: ['id'],
      where: [
        if (ownerColumn != null) '$ownerColumn = ?',
        'name = ?',
        if (exceptId != null) 'id <> ?',
        _visible(table, 'id'),
      ].join(' AND '),
      whereArgs: [?ownerId, name.trim(), ?exceptId],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  // ---------- Criteria ----------

  Future<List<Criterion>> readCriteria(int projectId) =>
      _readCriteria('criteria', projectId: projectId);

  Future<List<Criterion>> readPresets() => _readCriteria('preset_criteria');

  Future<List<Criterion>> _readCriteria(String table, {int? projectId}) async {
    final db = await database;
    final rows = await db.query(
      table,
      where: [
        if (projectId != null) 'project_id = ?',
        _visible(table, 'id'),
      ].join(' AND '),
      whereArgs: [?projectId],
      orderBy: 'position ASC, id ASC',
    );
    return rows.map(Criterion.fromMap).toList();
  }

  Future<int> addCriterion(int projectId, CriterionDraft draft) async {
    final db = await database;
    return db.insert('criteria', {
      ..._draftColumns(draft, await _nextPosition('criteria')),
      'project_id': projectId,
    });
  }

  Future<int> addPreset(CriterionDraft draft) async {
    final db = await database;
    return db.insert(
      'preset_criteria',
      _draftColumns(draft, await _nextPosition('preset_criteria')),
    );
  }

  Future<int> _nextPosition(String table) async {
    final db = await database;
    final rows = await db.rawQuery('SELECT MAX(position) AS last FROM $table');
    return ((rows.first['last'] as int?) ?? -1) + 1;
  }

  Future<void> updateCriterion(Criterion criterion) =>
      _updateCriterion('criteria', criterion);

  Future<void> updatePreset(Criterion criterion) =>
      _updateCriterion('preset_criteria', criterion);

  Future<void> _updateCriterion(String table, Criterion criterion) async {
    final db = await database;
    await db.update(
      table,
      criterion.toColumns(),
      where: 'id = ?',
      whereArgs: [criterion.id],
    );
  }

  StagedDeletion stageCriterionDeletion(int id) => _stageRow('criteria', id);

  StagedDeletion stagePresetDeletion(int id) =>
      _stageRow('preset_criteria', id);

  Future<CriterionScores> readScoresOf(int criterionId) async {
    final db = await database;
    Future<Map<int, double>> read(String table, String owner) async => {
      for (final row in await db.query(
        table,
        where: 'criterion_id = ?',
        whereArgs: [criterionId],
      ))
        row[owner] as int: (row['value'] as num).toDouble(),
    };
    return (
      byBuilding: await read('building_scores', 'building_id'),
      byRoom: await read('room_scores', 'room_id'),
    );
  }

  Future<void> restoreScoresOf(int criterionId, CriterionScores scores) async {
    final db = await database;
    await db.transaction((txn) async {
      for (final (table, owner, values) in [
        ('building_scores', 'building_id', scores.byBuilding),
        ('room_scores', 'room_id', scores.byRoom),
      ]) {
        for (final entry in values.entries) {
          await txn.update(
            table,
            {'value': entry.value},
            where: '$owner = ? AND criterion_id = ?',
            whereArgs: [entry.key, criterionId],
          );
        }
      }
    });
  }

  /// Rounds existing scores to 0 or 10 when a scale criterion becomes yes/no.
  /// A leftover 7.5 would be neither answer, which the UI can't display.
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

  // ---------- Buildings ----------

  Future<Building> readBuilding(int id) async {
    final db = await database;
    final rows = await db.query('buildings', where: 'id = ?', whereArgs: [id]);
    return Building.fromMap(rows.single);
  }

  /// Buildings that still have rooms, newest room's building first,
  /// so the building added to last is the natural default.
  Future<List<Building>> readBuildings(int projectId) async {
    final db = await database;
    final rows = await db.rawQuery(
      '''
      SELECT b.id, b.name, MAX(r.created_at) AS last_room
      FROM buildings b
      JOIN rooms r ON r.building_id = b.id
      WHERE b.project_id = ? AND ${_visible('buildings', 'b.id')} AND ${_visible('rooms', 'r.id')}
      GROUP BY b.id
      ORDER BY last_room DESC
    ''',
      [projectId],
    );
    return rows.map(Building.fromMap).toList();
  }

  Future<void> renameBuilding(int id, String name) async {
    final db = await database;
    await db.update(
      'buildings',
      {'name': name},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ---------- Rooms ----------

  Future<Room> readRoom(int id) async {
    final db = await database;
    final rows = await db.query('rooms', where: 'id = ?', whereArgs: [id]);
    return Room.fromMap(rows.single);
  }

  Future<List<Room>> readRooms(int buildingId) async {
    final db = await database;
    final rows = await db.query(
      'rooms',
      where: 'building_id = ? AND ${_visible('rooms', 'id')}',
      whereArgs: [buildingId],
      orderBy: 'created_at ASC',
    );
    return rows.map(Room.fromMap).toList();
  }

  /// Adds a room, creating its building first when [buildingId] is null.
  Future<({int buildingId, int roomId})> createRoom({
    required int projectId,
    int? buildingId,
    String? newBuildingName,
    required String name,
  }) async {
    final db = await database;
    return db.transaction((txn) async {
      final now = DateTime.now().toIso8601String();
      final building =
          buildingId ??
          await txn.insert('buildings', {
            'project_id': projectId,
            'name': newBuildingName,
            'created_at': now,
          });
      final room = await txn.insert('rooms', {
        'building_id': building,
        'name': name,
        'created_at': now,
      });
      return (buildingId: building, roomId: room);
    });
  }

  Future<void> renameRoom(int id, String name) async {
    final db = await database;
    await db.update('rooms', {'name': name}, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> updateRoomMemo(int id, String? memo) async {
    final db = await database;
    await db.update('rooms', {'memo': memo}, where: 'id = ?', whereArgs: [id]);
  }

  /// Deletes a room right away, and its building if that was the building's last room.
  Future<void> deleteRoom(int id) async {
    final db = await database;
    final room = await readRoom(id);
    final others = await db.query(
      'rooms',
      columns: ['id'],
      where: 'building_id = ? AND id <> ?',
      whereArgs: [room.buildingId, id],
      limit: 1,
    );
    if (others.isEmpty) {
      await db.delete(
        'buildings',
        where: 'id = ?',
        whereArgs: [room.buildingId],
      );
    } else {
      await db.delete('rooms', where: 'id = ?', whereArgs: [id]);
    }
  }

  /// Stages a room deletion. A building exists only for its rooms, so deleting its last
  /// visible room stages the building too.
  Future<StagedDeletion> stageRoomDeletion(int id) async {
    final room = await readRoom(id);
    final remaining = await readRooms(room.buildingId);
    final lastRoom = remaining.every((other) => other.id == id);

    return lastRoom
        ? _stage(
            {
              'rooms': {id},
              'buildings': {room.buildingId},
            },
            (db) => db.delete(
              'buildings',
              where: 'id = ?',
              whereArgs: [room.buildingId],
            ),
          )
        : _stageRow('rooms', id);
  }

  // ---------- Scores ----------

  Future<Map<int, double>> readBuildingScores(int buildingId) =>
      _readScores('building_scores', 'building_id', buildingId);

  Future<Map<int, double>> readRoomScores(int roomId) =>
      _readScores('room_scores', 'room_id', roomId);

  Future<Map<int, double>> _readScores(
    String table,
    String owner,
    int ownerId,
  ) async {
    final db = await database;
    final rows = await db.query(
      table,
      where: '$owner = ?',
      whereArgs: [ownerId],
    );
    return {
      for (final row in rows)
        row['criterion_id'] as int: (row['value'] as num).toDouble(),
    };
  }

  /// Writes one score; null removes it so the criterion counts as unscored again.
  Future<void> setBuildingScore(
    int buildingId,
    int criterionId,
    double? value,
  ) => _setScore(
    'building_scores',
    'building_id',
    buildingId,
    criterionId,
    value,
  );

  Future<void> setRoomScore(int roomId, int criterionId, double? value) =>
      _setScore('room_scores', 'room_id', roomId, criterionId, value);

  Future<void> _setScore(
    String table,
    String owner,
    int ownerId,
    int criterionId,
    double? value,
  ) async {
    final db = await database;
    if (value == null) {
      await db.delete(
        table,
        where: '$owner = ? AND criterion_id = ?',
        whereArgs: [ownerId, criterionId],
      );
    } else {
      await db.insert(table, {
        owner: ownerId,
        'criterion_id': criterionId,
        'value': value,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  // ---------- Photos and videos ----------

  Future<List<MediaItem>> readMedia({int? buildingId, int? roomId}) async {
    final db = await database;
    final rows = await db.query(
      'media',
      where:
          '${buildingId != null ? 'building_id' : 'room_id'} = ? AND ${_visible('media', 'id')}',
      whereArgs: [buildingId ?? roomId],
      orderBy: 'created_at ASC',
    );
    return rows.map(MediaItem.fromMap).toList();
  }

  Future<int> addMedia({
    int? buildingId,
    int? roomId,
    required String path,
    required MediaKind kind,
    required String label,
    String? thumbPath,
  }) async {
    final db = await database;
    return db.insert('media', {
      'building_id': buildingId,
      'room_id': roomId,
      'path': path,
      'kind': kind.name,
      'label': label,
      'thumb_path': thumbPath,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  /// Moves media between a building and a room and sets its area.
  ///
  /// Exactly one owner column may be set (CHECK constraint), so the other is cleared.
  Future<void> placeMedia(
    int id, {
    int? buildingId,
    int? roomId,
    required String? label,
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

  StagedDeletion stageMediaDeletion(int id) => _stageRow('media', id);

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
  /// A room's score combines its building's ratings with its own. Until everything is
  /// scored there is no score and the room sorts as 0. Ties go to rooms with a score,
  /// then building and room name, so the order never shifts between views.
  Future<List<RoomScore>> readRoomBoard(int projectId) async {
    final db = await database;

    final criteria = await readCriteria(projectId);
    final byId = {for (final criterion in criteria) criterion.id: criterion};

    final roomRows = await db.rawQuery(
      '''
      SELECT r.*, b.name AS building_name
      FROM rooms r
      JOIN buildings b ON b.id = r.building_id
      WHERE b.project_id = ? AND ${_visible('buildings', 'b.id')} AND ${_visible('rooms', 'r.id')}
    ''',
      [projectId],
    );
    if (roomRows.isEmpty) return [];

    Future<Map<int, Map<int, double>>> scoresBy(
      String sql,
      String owner,
    ) async {
      final result = <int, Map<int, double>>{};
      for (final row in await db.rawQuery(sql, [projectId])) {
        (result[row[owner] as int] ??= {})[row['criterion_id'] as int] =
            (row['value'] as num).toDouble();
      }
      return result;
    }

    final byBuilding = await scoresBy('''
      SELECT s.building_id, s.criterion_id, s.value FROM building_scores s
      JOIN buildings b ON b.id = s.building_id
      WHERE b.project_id = ?
    ''', 'building_id');
    final byRoom = await scoresBy('''
      SELECT s.room_id, s.criterion_id, s.value FROM room_scores s
      JOIN rooms r ON r.id = s.room_id
      JOIN buildings b ON b.id = r.building_id
      WHERE b.project_id = ?
    ''', 'room_id');

    final board = <RoomScore>[];
    for (final row in roomRows) {
      final room = Room.fromMap(row);
      final result = computeScore(
        scores: {...?byBuilding[room.buildingId], ...?byRoom[room.id]},
        criteriaById: byId,
      );
      board.add(
        RoomScore(
          room: room,
          building: Building(
            id: room.buildingId,
            name: row['building_name'] as String,
          ),
          percent: result.percent,
          scoredCount: result.scoredCount,
          criterionCount: result.criterionCount,
        ),
      );
    }

    board.sort((a, b) {
      final byScore = (b.percent ?? 0).compareTo(a.percent ?? 0);
      if (byScore != 0) return byScore;
      final byHasScore = (b.hasScore ? 1 : 0).compareTo(a.hasScore ? 1 : 0);
      if (byHasScore != 0) return byHasScore;
      return '${a.building.name} ${a.room.name}'.compareTo(
        '${b.building.name} ${b.room.name}',
      );
    });
    return board;
  }
}
