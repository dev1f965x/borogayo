import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/models.dart';
import '../models/scoring.dart';

/// 새 평가 기준을 만들 때 넘기는 값 묶음. 아직 id가 없는 상태를 나타낸다.
typedef CriterionDraft = ({
  String name,
  CriterionScope scope,
  CriterionType type,
  String? emoji,
});

/// 지운 방을 되돌리기 위해 잠깐 들고 있는 사본. 저장되지 않는다.
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

/// 로컬 SQLite 저장소. 앱 전체에서 이 싱글턴 하나만 사용한다.
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
        // 상위를 지우면 하위(방·점수·미디어)도 같이 지워지도록.
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, version) async => _createSchema(db),
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          // 건물 계층이 생기면서 구조가 통째로 바뀌었다. 그 시절 데이터는 형태가
          // 달라 옮길 수 없어서 새로 만든다.
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
        // 여기서부터는 컬럼만 느는 변경이라 데이터를 지킨다.
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
    // 건물 점수와 방 점수를 한 테이블에 담으면 소유자 컬럼이 둘 다 널 허용이 되어
    // 어느 쪽 점수인지 매번 확인해야 한다. 나눠두면 조회가 단순해진다.
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

  // ---------- 프로젝트 ----------

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

  /// 프로젝트와 평가 기준을 한 트랜잭션으로 함께 만든다. 기준 없는 프로젝트는 의미가 없다.
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
    await db.update('projects', {'name': name}, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteProject(int id) async {
    final db = await database;
    await db.delete('projects', where: 'id = ?', whereArgs: [id]);
  }

  /// 설정의 '데이터 초기화'. projects만 지우면 나머지는 CASCADE로 따라 지워진다.
  Future<void> deleteAllProjects() async {
    final db = await database;
    await db.delete('projects');
  }

  // ---------- 이름 중복 ----------
  //
  // 같은 이름이 둘 있으면 목록에서 어느 쪽이 어느 쪽인지 알 수 없다. 특히 순위가
  // 섞여 보이는 화면에서는 잘못된 집을 고르게 되므로 입력 단계에서 막는다.

  /// [exceptId]는 이름을 고치는 중인 자기 자신. 안 빼면 제 이름과 부딪힌다.
  Future<bool> projectNameExists(String name, {int? exceptId}) =>
      _nameExists('projects', null, null, name, exceptId);

  Future<bool> buildingNameExists(int projectId, String name, {int? exceptId}) =>
      _nameExists('buildings', 'project_id', projectId, name, exceptId);

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
    final conditions = [if (ownerColumn != null) '$ownerColumn = ?', 'name = ?'];
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

  // ---------- 평가 기준 ----------

  Future<List<Criterion>> readCriteria(int projectId, {CriterionScope? scope}) async {
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

  /// 이 기준으로 매겨둔 점수가 하나라도 있는지. 유형을 바꾸기 전에 경고할지 판단하는 데 쓴다.
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

  /// 점수형을 여부형으로 바꿀 때, 이미 매긴 값을 있음/없음 둘 중 하나로 밀어 넣는다.
  /// 7.5점 같은 값이 그대로 남으면 있음도 없음도 아닌 상태가 되어 화면이 설명할 수 없다.
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

  // ---------- 건물 ----------

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

  // ---------- 방 ----------

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

  /// 방을 지우되 되돌릴 수 있도록 점수·미디어까지 담은 사본을 돌려준다.
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

  /// 되돌리기. id는 새로 부여되지만 사용자에게는 같은 방으로 보인다.
  Future<void> restoreRoom(RoomSnapshot snapshot) async {
    final db = await database;
    // 되돌리는 사이에 기준이 지워졌을 수 있으므로 살아있는 기준의 점수만 되살린다.
    final aliveIds = (await db.query('criteria', columns: ['id']))
        .map((row) => row['id'] as int)
        .toSet();

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

  // ---------- 점수 ----------

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
    final rows = await db.query('room_scores', where: 'room_id = ?', whereArgs: [roomId]);
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
      // 지운 점수는 행까지 없애야 '아직 안 매김'으로 돌아간다.
      // 남겨두면 화면에서만 지워지고 순위 계산에는 계속 끼어든다.
      // (키는 DB에서 온 정수라 그대로 넣어도 안전하다)
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

  // ---------- 사진 · 영상 ----------

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

  /// 붙인 곳을 옮긴다. 건물에 찍어둔 걸 방으로, 또는 그 반대로.
  ///
  /// 소유자 컬럼은 둘 중 하나만 채워져야 하므로(CHECK 제약) 반대쪽은 반드시 비운다.
  /// 구역 이름은 건물용·방용 목록이 달라서 옮길 때 다시 정해 받는다.
  Future<void> moveMedia(
    int id, {
    int? buildingId,
    int? roomId,
    required String label,
  }) async {
    assert((buildingId == null) != (roomId == null), '건물이나 방 중 하나여야 한다');
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

  /// 저장소 정리에 쓴다. DB가 아직 참조하고 있는 파일 경로 전체.
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


  // ---------- 순위 ----------

  /// 프로젝트의 **모든 방**을 건물 구분 없이 한 줄로 세워 돌려준다.
  ///
  /// 고르는 대상이 방이므로 순위도 방 단위다. 건물은 그 방들이 공유하는 평가를
  /// 한 번만 받아두는 묶음일 뿐이라 따로 점수를 갖지 않는다.
  ///
  /// - 방의 점수 = 그 방이 속한 건물의 점수 + 방 자체 점수.
  /// - 다 매기기 전에는 점수를 내지 않고, 정렬에서만 0점으로 취급해 아래에 둔다.
  ///   동점이면 점수가 나온 쪽이 먼저, 그래도 같으면 건물·방 이름 가나다순.
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

    final roomRows = await db.rawQuery('''
      SELECT r.* FROM rooms r
      JOIN buildings b ON b.id = r.building_id
      WHERE b.project_id = ?
    ''', [projectId]);
    if (roomRows.isEmpty) return [];

    final buildingScoreRows = await db.rawQuery('''
      SELECT s.building_id, s.criterion_id, s.value FROM building_scores s
      JOIN buildings b ON b.id = s.building_id
      WHERE b.project_id = ?
    ''', [projectId]);

    final roomScoreRows = await db.rawQuery('''
      SELECT s.room_id, s.criterion_id, s.value FROM room_scores s
      JOIN rooms r ON r.id = s.room_id
      JOIN buildings b ON b.id = r.building_id
      WHERE b.project_id = ?
    ''', [projectId]);

    Map<int, Map<int, double>> group(List<Map<String, Object?>> rows, String ownerColumn) {
      final result = <int, Map<int, double>>{};
      for (final row in rows) {
        result
            .putIfAbsent(row[ownerColumn] as int, () => {})[row['criterion_id'] as int] =
            (row['value'] as num).toDouble();
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
          // 진행률 막대는 방 기준만 센다. 건물 기준은 건물 화면에서 따로 보여준다.
          scoredCount: roomScores.length,
          criterionCount: roomCriterionCount,
          blockedByBuilding:
              (roomCriterionCount == 0 || roomScores.length >= roomCriterionCount) &&
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

  /// 건물 관리 화면용. 건물에는 점수가 없으므로 진행 상황만 세어 이름순으로 돌려준다.
  Future<List<BuildingSummary>> readBuildingSummaries(int projectId) async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT
        b.id, b.project_id, b.name, b.memo, b.created_at,
        (SELECT COUNT(*) FROM rooms r WHERE r.building_id = b.id) AS room_count,
        (SELECT COUNT(*) FROM building_scores s WHERE s.building_id = b.id) AS scored_count,
        (SELECT COUNT(*) FROM criteria c
          WHERE c.project_id = b.project_id AND c.scope = 'building') AS criterion_count
      FROM buildings b
      WHERE b.project_id = ?
      ORDER BY b.name ASC
    ''', [projectId]);

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

  /// 점수 내림차순. 아직 점수가 안 나온 것은 0점으로 보고 아래에 둔다.
  /// 값이 같으면 점수가 나온 쪽이 먼저, 그래도 같으면 이름 가나다순.
  /// 목록 순서가 볼 때마다 흔들리지 않도록 동점 처리까지 못박아둔다.
  static int Function(T, T) _byScore<T>(
    double? Function(T) score,
    String Function(T) name,
  ) {
    return (a, b) {
      final byScore = (score(b) ?? 0).compareTo(score(a) ?? 0);
      if (byScore != 0) return byScore;

      final byHasScore = (score(b) != null ? 1 : 0).compareTo(score(a) != null ? 1 : 0);
      return byHasScore != 0 ? byHasScore : name(a).compareTo(name(b));
    };
  }
}
