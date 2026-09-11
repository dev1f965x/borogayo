import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../db/database.dart';
import '../models/models.dart';
import '../theme.dart';
import 'building_list_screen.dart';
import 'criteria_edit_screen.dart';
import 'room_detail_screen.dart';
import 'widgets/entry_dialog.dart';
import 'widgets/room_card.dart';
import 'widgets/room_entry_dialog.dart';

/// One project: the visited rooms, always sorted by score.
///
/// Rooms are what get chosen, so they're ranked in one list across buildings.
/// Buildings only hold shared ratings and have their own screen.
class ProjectDetailScreen extends StatefulWidget {
  const ProjectDetailScreen({super.key, required this.project});

  final Project project;

  @override
  State<ProjectDetailScreen> createState() => _ProjectDetailScreenState();
}

class _ProjectDetailScreenState extends State<ProjectDetailScreen> {
  List<RoomScore> _rooms = [];
  List<Building> _buildings = [];
  List<Criterion> _roomCriteria = [];
  bool _loading = true;

  /// Kept here rather than read from the widget, since the name can be edited.
  late String _name = widget.project.name;

  int get _projectId => widget.project.id!;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final db = AppDatabase.instance;
    final rooms = await db.readRoomBoard(_projectId);
    final buildings = await db.readBuildingSummaries(_projectId);
    final roomCriteria = await db.readCriteria(
      _projectId,
      scope: CriterionScope.room,
    );
    if (!mounted) return;
    setState(() {
      _rooms = rooms;
      _buildings = buildings.map((summary) => summary.building).toList();
      _roomCriteria = roomCriteria;
      _loading = false;
    });
  }

  /// Adding a room means adding a listing, so the building is chosen in the same dialog
  /// and can be created there if it doesn't exist yet.
  Future<void> _addRoom() async {
    final entry = await showDialog<RoomEntryResult>(
      context: context,
      builder: (_) =>
          RoomEntryDialog(projectId: _projectId, buildings: _buildings),
    );
    if (entry == null || !mounted) return;

    final db = AppDatabase.instance;
    final buildingId =
        entry.buildingId ??
        await db.createBuilding(_projectId, entry.newBuildingName!, null);
    final roomId = await db.createRoom(buildingId, entry.roomName, entry.memo);

    HapticFeedback.lightImpact();
    await _refresh();
    if (!mounted) return;

    // A new room is scored right away, so go straight to it.
    final created = _rooms.where((item) => item.room.id == roomId).firstOrNull;
    if (created != null) await _openRoom(created);
  }

  Future<void> _openRoom(RoomScore entry) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => RoomDetailScreen(
          room: entry.room,
          building: entry.building,
          criteria: _roomCriteria,
        ),
      ),
    );
    await _refresh();
  }

  Future<void> _rename() async {
    final entry = await showDialog<EntryResult>(
      context: context,
      builder: (_) => EntryDialog(
        title: '목록 이름',
        nameHint: '예: 2026 봄 이사',
        confirmLabel: '저장',
        initialName: _name,
        nameCheck: (name) async =>
            await AppDatabase.instance.projectNameExists(
              name,
              exceptId: _projectId,
            )
            ? '같은 이름의 목록이 이미 있어요.'
            : null,
      ),
    );
    if (entry == null || !mounted) return;

    await AppDatabase.instance.renameProject(_projectId, entry.name);
    if (!mounted) return;
    HapticFeedback.lightImpact();
    setState(() => _name = entry.name);
  }

  Future<void> _openBuildings() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => BuildingListScreen(project: widget.project),
      ),
    );
    await _refresh();
  }

  Future<void> _editCriteria() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => CriteriaEditScreen(projectId: _projectId),
      ),
    );
    await _refresh();
  }

  /// Room deletion is common and easy to reverse, so it offers undo instead of a confirmation.
  Future<void> _deleteRoom(Room room) async {
    final snapshot = await AppDatabase.instance.deleteRoom(room.id!);
    if (!mounted || snapshot == null) return;

    await _refresh();
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('‘${room.name}’ 삭제했어요'),
          action: SnackBarAction(
            label: '실행취소',
            textColor: context.palette.brand,
            onPressed: () async {
              await AppDatabase.instance.restoreRoom(snapshot);
              await _refresh();
            },
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final anyScore = _rooms.any((entry) => entry.hasScore);

    return Scaffold(
      appBar: AppBar(
        title: Text(_name),
        actions: [
          IconButton(
            onPressed: _rename,
            icon: const Icon(Icons.edit_outlined, size: 20),
            tooltip: '목록 이름 수정',
          ),
          TextButton.icon(
            onPressed: _editCriteria,
            icon: const Icon(Icons.tune, size: 18),
            label: const Text('평가 기준'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.page,
                12,
                AppSpacing.page,
                120 + MediaQuery.paddingOf(context).bottom,
              ),
              children: [
                _Header(
                  buildingCount: _buildings.length,
                  roomCount: _rooms.length,
                  sorted: anyScore,
                  onOpenBuildings: _openBuildings,
                ),
                const SizedBox(height: 16),
                for (var index = 0; index < _rooms.length; index++) ...[
                  RoomCard(
                    entry: _rooms[index],
                    // Only scored rooms get a rank. Sorting puts them first,
                    // so the index is the rank.
                    rank: _rooms[index].hasScore ? index + 1 : null,
                    showRank: true,
                    showBuilding: true,
                    onTap: () => _openRoom(_rooms[index]),
                    onDelete: () => _deleteRoom(_rooms[index].room),
                  ),
                  const SizedBox(height: 12),
                ],
                if (_rooms.isEmpty)
                  Text(
                    '아직 넣은 방이 없어요',
                    style: TextStyle(fontSize: 13.5, color: palette.textMuted),
                  ),
              ],
            ),
      floatingActionButton: _loading
          ? null
          : FloatingActionButton.extended(
              onPressed: _addRoom,
              backgroundColor: palette.brand,
              foregroundColor: Colors.white,
              elevation: 0,
              icon: const Icon(Icons.add),
              label: const Text(
                '방 추가',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
    );
  }
}

/// Summary line and the way to the building screen. Buildings aren't used often enough
/// for the app bar, but hiding them would leave no way to rate shared criteria.
class _Header extends StatelessWidget {
  const _Header({
    required this.buildingCount,
    required this.roomCount,
    required this.sorted,
    required this.onOpenBuildings,
  });

  final int buildingCount;
  final int roomCount;
  final bool sorted;
  final VoidCallback onOpenBuildings;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Row(
      children: [
        Expanded(
          child: Text(
            roomCount == 0
                ? '방을 추가하면 점수순으로 쌓입니다'
                : '방 $roomCount칸 · 건물 $buildingCount곳${sorted ? ' · 점수순' : ''}',
            style: TextStyle(fontSize: 13.5, color: palette.textMuted),
          ),
        ),
        TextButton.icon(
          onPressed: onOpenBuildings,
          icon: const Icon(Icons.apartment_outlined, size: 17),
          label: const Text('건물'),
          style: TextButton.styleFrom(
            foregroundColor: palette.brand,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            minimumSize: const Size(0, 36),
            textStyle: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
