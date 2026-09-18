part of 'database.dart';

/// Photos and videos attached to a building or room.
extension MediaStoreQueries on AppDatabase {
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
}
