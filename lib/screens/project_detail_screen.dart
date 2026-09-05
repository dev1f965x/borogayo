import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../db/database.dart';
import '../models/models.dart';
import '../theme.dart';
import 'building_detail_screen.dart';
import 'criteria_edit_screen.dart';
import 'room_detail_screen.dart';
import 'widgets/card_menu.dart';
import 'widgets/confirm_dialog.dart';
import 'widgets/ranking_view.dart';

/// 목록 하나. 건물을 쌓아가는 탭과, 방 순위를 보는 탭으로 나뉜다.
class ProjectDetailScreen extends StatefulWidget {
  const ProjectDetailScreen({super.key, required this.project});

  final Project project;

  @override
  State<ProjectDetailScreen> createState() => _ProjectDetailScreenState();
}

class _ProjectDetailScreenState extends State<ProjectDetailScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this)
    ..addListener(() => setState(() {}));

  List<BuildingSummary> _buildings = [];
  List<RankedRoom> _ranking = [];
  List<Criterion> _roomCriteria = [];
  bool _loading = true;

  int get _projectId => widget.project.id!;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    final db = AppDatabase.instance;
    final buildings = await db.readBuildingSummaries(_projectId);
    final ranking = await db.readRanking(_projectId);
    final roomCriteria = await db.readCriteria(_projectId, scope: CriterionScope.room);
    if (!mounted) return;
    setState(() {
      _buildings = buildings;
      _ranking = ranking;
      _roomCriteria = roomCriteria;
      _loading = false;
    });
  }

  /// 건물과 첫 방을 한 번에 받는다. 원룸처럼 방이 하나뿐인 경우가 흔해서,
  /// 건물만 만들고 방을 또 추가하게 하면 번거롭다.
  Future<void> _addBuilding() async {
    final nameController = TextEditingController();
    final memoController = TextEditingController();
    final roomController = TextEditingController();

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('건물 추가'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              autofocus: true,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(hintText: '건물 · 예: 역삼동 대성빌라'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: memoController,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(hintText: '메모 (선택) · 예: 역 도보 8분'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: roomController,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => Navigator.pop(context, true),
              decoration: const InputDecoration(hintText: '첫 방 (선택) · 예: 302호'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(minimumSize: const Size(88, 44)),
            child: const Text('추가'),
          ),
        ],
      ),
    );

    final name = nameController.text.trim();
    final memo = memoController.text.trim();
    final room = roomController.text.trim();
    nameController.dispose();
    memoController.dispose();
    roomController.dispose();

    if (saved != true || name.isEmpty) return;

    final buildingId = await AppDatabase.instance.createBuilding(
      _projectId,
      name,
      memo.isEmpty ? null : memo,
      firstRoomName: room.isEmpty ? null : room,
    );
    if (!mounted) return;
    HapticFeedback.lightImpact();
    await _refresh();
    if (!mounted) return;

    // 방금 만든 건물로 바로 들어간다. 현장에서는 추가 직후 곧바로 채점하게 되므로
    // 목록으로 돌아갔다가 다시 눌러 들어가는 단계를 없앤다.
    final created = _buildings
        .where((summary) => summary.building.id == buildingId)
        .firstOrNull;
    if (created != null) await _openBuilding(created.building);
  }

  Future<void> _openBuilding(Building building) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => BuildingDetailScreen(project: widget.project, building: building),
      ),
    );
    await _refresh();
  }

  Future<void> _openRoom(Room room) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => RoomDetailScreen(room: room, criteria: _roomCriteria),
      ),
    );
    await _refresh();
  }

  Future<void> _editCriteria() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => CriteriaEditScreen(projectId: _projectId)),
    );
    await _refresh();
  }

  /// 건물을 지우면 그 안의 방·점수·사진이 전부 사라지므로 확인을 받는다.
  Future<void> _confirmDeleteBuilding(Building building) async {
    final ok = await confirmDestructive(
      context,
      title: '‘${building.name}’ 삭제',
      message: '이 건물의 방과 점수, 사진·영상이 모두 지워집니다.',
    );
    if (!ok || !mounted) return;

    await AppDatabase.instance.deleteBuilding(building.id!);
    if (!mounted) return;
    HapticFeedback.mediumImpact();
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.project.name),
        actions: [
          TextButton.icon(
            onPressed: _editCriteria,
            icon: const Icon(Icons.tune, size: 18),
            label: const Text('평가 기준'),
          ),
          const SizedBox(width: 8),
        ],
        bottom: TabBar(
          controller: _tabs,
          labelColor: palette.textStrong,
          unselectedLabelColor: palette.textMuted,
          indicatorColor: palette.brand,
          indicatorSize: TabBarIndicatorSize.tab,
          dividerColor: palette.border,
          labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          tabs: const [Tab(text: '건물'), Tab(text: '순위')],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabs,
              children: [
                _BuildingList(
                  buildings: _buildings,
                  ranking: _ranking,
                  onOpen: _openBuilding,
                  onDelete: _confirmDeleteBuilding,
                  onAdd: _addBuilding,
                ),
                RankingView(
                  ranking: _ranking,
                  onOpenRoom: (entry) => _openRoom(entry.room),
                ),
              ],
            ),
      floatingActionButton: _tabs.index != 0 || _buildings.isEmpty || _loading
          ? null
          : FloatingActionButton.extended(
              onPressed: _addBuilding,
              backgroundColor: palette.brand,
              foregroundColor: Colors.white,
              elevation: 0,
              icon: const Icon(Icons.add),
              label: const Text('건물 추가', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
    );
  }
}

class _BuildingList extends StatelessWidget {
  const _BuildingList({
    required this.buildings,
    required this.ranking,
    required this.onOpen,
    required this.onDelete,
    required this.onAdd,
  });

  final List<BuildingSummary> buildings;
  final List<RankedRoom> ranking;
  final void Function(Building building) onOpen;
  final void Function(Building building) onDelete;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final roomTotal = buildings.fold<int>(0, (sum, b) => sum + b.roomCount);

    // 건물 카드에 "이 건물에서 가장 좋았던 방" 점수를 얹어준다.
    final bestByBuilding = <int, RankedRoom>{};
    for (final entry in ranking) {
      if (!entry.hasAnyScore) continue;
      final current = bestByBuilding[entry.building.id];
      if (current == null || entry.percent > current.percent) {
        bestByBuilding[entry.building.id!] = entry;
      }
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.page, 12, AppSpacing.page, 120),
      children: [
        Text(
          buildings.isEmpty
              ? '건물을 추가하고, 그 안에 본 방을 넣으세요'
              : '건물 ${buildings.length}곳 · 방 $roomTotal칸',
          style: TextStyle(fontSize: 13.5, color: palette.textMuted),
        ),
        const SizedBox(height: 16),
        if (buildings.isEmpty)
          EmptyState(
            icon: Icons.apartment_outlined,
            title: '아직 넣은 건물이 없어요',
            description: '같은 건물의 방을 여러 개 볼 수 있어서\n건물로 먼저 묶습니다.',
            actionLabel: '첫 건물 추가하기',
            onAction: onAdd,
          )
        else
          for (final summary in buildings) ...[
            _BuildingCard(
              summary: summary,
              best: bestByBuilding[summary.building.id],
              onTap: () => onOpen(summary.building),
              onDelete: () => onDelete(summary.building),
            ),
            const SizedBox(height: 12),
          ],
      ],
    );
  }
}

class _BuildingCard extends StatelessWidget {
  const _BuildingCard({
    required this.summary,
    required this.best,
    required this.onTap,
    required this.onDelete,
  });

  final BuildingSummary summary;
  final RankedRoom? best;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final building = summary.building;

    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  building.name,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: palette.textStrong,
                  ),
                ),
              ),
              if (best != null) ...[
                Text(
                  '최고 ${best!.percent.toStringAsFixed(0)}점',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: palette.brand,
                  ),
                ),
                const SizedBox(width: 4),
              ],
              CardMenu(onDelete: onDelete),
            ],
          ),
          if (building.memo != null && building.memo!.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              building.memo!,
              style: TextStyle(fontSize: 13.5, color: palette.textMuted),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.meeting_room_outlined, size: 15, color: palette.textMuted),
              const SizedBox(width: 4),
              Text(
                '방 ${summary.roomCount}칸',
                style: TextStyle(fontSize: 12.5, color: palette.textMuted),
              ),
              const SizedBox(width: 12),
              Icon(
                summary.buildingScoringDone
                    ? Icons.check_circle_outline
                    : Icons.checklist_outlined,
                size: 15,
                color: summary.buildingScoringDone ? palette.done : palette.textMuted,
              ),
              const SizedBox(width: 4),
              Text(
                summary.buildingScoringDone
                    ? '건물 채점 완료'
                    : '건물 기준 ${summary.buildingCriterionCount}개 중 ${summary.buildingScoredCount}개',
                style: TextStyle(
                  fontSize: 12.5,
                  color: summary.buildingScoringDone ? palette.done : palette.textMuted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
