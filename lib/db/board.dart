part of 'database.dart';

/// Every room of a project, ranked in one list.
extension RoomBoard on AppDatabase {
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
