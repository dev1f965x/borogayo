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

/// 목록 하나. 보러 간 방들이 점수순으로 늘 정렬돼 있는 화면.
///
/// 고르는 대상은 건물이 아니라 방이므로, 여기서는 건물을 가로질러 방을 한 줄로 세운다.
/// 건물은 방들이 공유하는 평가를 담아두는 묶음일 뿐이라 '건물' 화면으로 따로 뺐다.
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

  /// 이름을 고칠 수 있으므로 넘겨받은 값을 계속 쓰지 않고 여기서 들고 간다.
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
    final roomCriteria = await db.readCriteria(_projectId, scope: CriterionScope.room);
    if (!mounted) return;
    setState(() {
      _rooms = rooms;
      _buildings = buildings.map((summary) => summary.building).toList();
      _roomCriteria = roomCriteria;
      _loading = false;
    });
  }

  /// 방을 하나 더 본다는 게 곧 매물을 하나 더 넣는다는 뜻이라, 여기서 건물까지 같이 고른다.
  /// 건물이 아직 없으면 다이얼로그 안에서 바로 만든다.
  Future<void> _addRoom() async {
    final entry = await showDialog<RoomEntryResult>(
      context: context,
      builder: (_) => RoomEntryDialog(projectId: _projectId, buildings: _buildings),
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

    // 방을 추가한 직후엔 곧바로 채점하게 되므로 바로 그 화면으로 넘어간다.
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
            await AppDatabase.instance.projectNameExists(name, exceptId: _projectId)
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
      MaterialPageRoute(builder: (_) => BuildingListScreen(project: widget.project)),
    );
    await _refresh();
  }

  Future<void> _editCriteria() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => CriteriaEditScreen(projectId: _projectId)),
    );
    await _refresh();
  }

  /// 방 삭제는 자주 일어나고 되돌리기 쉬우므로 확인 대신 실행취소를 제공한다.
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
                    // 점수가 나온 방만 등수를 받는다. 정렬이 그들을 앞에 모아두므로
                    // 위에서부터 센 번호가 그대로 등수가 된다.
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
              label: const Text('방 추가', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
    );
  }
}

/// 집계 한 줄과 건물 화면으로 가는 길. 건물은 앱바에 두기엔 자주 쓰지 않고,
/// 아예 숨기면 공통 평가를 매기러 갈 방법이 없어져서 목록 머리에 얹었다.
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
            textStyle: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}
