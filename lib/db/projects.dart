part of 'database.dart';

/// Projects, and the name checks that keep two of anything apart.
extension ProjectStore on AppDatabase {
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
}
