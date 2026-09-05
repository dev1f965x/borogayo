import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/models.dart';
import '../models/scoring.dart';

/// 새 평가 기준을 만들 때 넘기는 값 묶음. 아직 id가 없는 상태를 나타낸다.
typedef CriterionDraft = ({String name, CriterionScope scope, CriterionType type});

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
      version: 3,
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
        if (oldVersion < 3) {
          // 사진·영상에 구역 라벨이 붙었다. 컬럼만 늘면 되므로 데이터를 지킨다.
          await db.execute('ALTER TABLE media ADD COLUMN label TEXT');
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
        position INTEGER NOT NULL DEFAULT 0
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
        (SELECT COUNT(*) FROM criteria c WHERE c.project_id = p.id) AS criterion_count,
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
            criterionCount: row['criterion_count'] as int,
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
        });
      }
      return projectId;
    });
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

  Future<void> addCriterion(
    int projectId,
    String name,
    CriterionScope scope,
    CriterionType type,
    int weight,
  ) async {
    final db = await database;
    final existing = await readCriteria(projectId);
    await db.insert('criteria', {
      'project_id': projectId,
      'name': name,
      'scope': scope.name,
      'type': type.name,
      'weight': weight,
      'position': existing.length,
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

  Future<void> deleteCriterion(int id) async {
    final db = await database;
    await db.delete('criteria', where: 'id = ?', whereArgs: [id]);
  }

  // ---------- 건물 ----------

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
      ORDER BY b.created_at DESC
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

  /// 건물과 첫 방을 함께 만든다. 원룸처럼 건물↔방이 1:1인 경우가 흔해서,
  /// 건물만 덩그러니 만들어두고 방을 또 추가하게 하면 번거롭다.
  Future<int> createBuilding(
    int projectId,
    String name,
    String? memo, {
    String? firstRoomName,
  }) async {
    final db = await database;
    return db.transaction((txn) async {
      final now = DateTime.now().toIso8601String();
      final buildingId = await txn.insert('buildings', {
        'project_id': projectId,
        'name': name,
        'memo': memo,
        'created_at': now,
      });
      if (firstRoomName != null && firstRoomName.trim().isNotEmpty) {
        await txn.insert('rooms', {
          'building_id': buildingId,
          'name': firstRoomName.trim(),
          'created_at': now,
        });
      }
      return buildingId;
    });
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
      orderBy: 'created_at DESC',
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
      for (final entry in values.entries) {
        await txn.insert(table, {
          ownerColumn: ownerId,
          'criterion_id': entry.key,
          'value': entry.value,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  /// 건물 안 각 방의 채점 진행 상황. {roomId: 채점된 기준 수}
  Future<Map<int, int>> readRoomScoredCounts(int buildingId) async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT r.id AS room_id, COUNT(s.id) AS scored
      FROM rooms r
      LEFT JOIN room_scores s ON s.room_id = r.id
      WHERE r.building_id = ?
      GROUP BY r.id
    ''', [buildingId]);
    return {
      for (final row in rows) row['room_id'] as int: row['scored'] as int,
    };
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
  }) async {
    final db = await database;
    await db.insert('media', {
      'building_id': buildingId,
      'room_id': roomId,
      'path': path,
      'kind': kind.name,
      'label': label,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> deleteMedia(int id) async {
    final db = await database;
    await db.delete('media', where: 'id = ?', whereArgs: [id]);
  }

  // ---------- 순위 ----------

  /// 프로젝트 안 모든 방을 점수순으로 계산해 돌려준다.
  ///
  /// 방의 점수 = 그 방이 속한 건물의 점수 + 방 자체 점수. 건물 기준을 방마다
  /// 다시 매기지 않는 대신, 순위에서는 함께 반영해야 공정하다.
  ///
  /// 아직 덜 매긴 방도 비교는 되도록 **매긴 기준만으로 가중 평균**을 낸다.
  /// (전체 기준으로 나누면 덜 채점했다는 이유만으로 점수가 낮아진다)
  Future<List<RankedRoom>> readRanking(int projectId) async {
    final db = await database;

    final criteria = await readCriteria(projectId);
    final byId = {for (final criterion in criteria) criterion.id!: criterion};

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

    final ranked = <RankedRoom>[];
    for (final row in roomRows) {
      final room = Room.fromMap(row);
      final building = buildings[room.buildingId];
      if (building == null) continue;

      final scores = {...?byBuilding[room.buildingId], ...?byRoom[room.id]};
      final result = computeScore(scores: scores, criteriaById: byId);

      ranked.add(
        RankedRoom(
          room: room,
          building: building,
          percent: result.percent,
          scoredCount: result.scoredCount,
          totalCount: criteria.length,
        ),
      );
    }

    ranked.sort((a, b) => b.percent.compareTo(a.percent));
    return ranked;
  }

  /// 저장소 정리에 쓴다. DB가 아직 참조하고 있는 파일 경로 전체.
  Future<Set<String>> readAllMediaPaths() async {
    final db = await database;
    final rows = await db.query('media', columns: ['path']);
    return rows.map((row) => row['path'] as String).toSet();
  }
}
