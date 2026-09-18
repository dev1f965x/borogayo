import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/models.dart';
import '../models/scoring.dart';

part 'board.dart';
part 'criteria.dart';
part 'media.dart';
part 'places.dart';
part 'projects.dart';
part 'scores.dart';

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
}
