part of 'database.dart';

/// Scores given to a building or a room.
extension ScoreStore on AppDatabase {
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
}
