part of 'database.dart';

/// Criteria of a project, and the defaults new projects copy.
extension CriterionStore on AppDatabase {
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
      ...AppDatabase._draftColumns(draft, await _nextPosition('criteria')),
      'project_id': projectId,
    });
  }

  Future<int> addPreset(CriterionDraft draft) async {
    final db = await database;
    return db.insert(
      'preset_criteria',
      AppDatabase._draftColumns(draft, await _nextPosition('preset_criteria')),
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
}
