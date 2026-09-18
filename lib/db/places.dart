part of 'database.dart';

/// Buildings and the rooms inside them.
extension PlaceStore on AppDatabase {
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
}
