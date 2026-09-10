import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../db/database.dart';
import '../models/models.dart';
import '../models/scoring.dart';
import '../theme.dart';
import 'room_detail_screen.dart';
import 'widgets/confirm_dialog.dart';
import 'widgets/criterion_score_card.dart';
import 'widgets/entry_dialog.dart';
import 'widgets/media_section.dart';
import 'widgets/room_card.dart';

/// 건물 하나. 건물 공통 항목을 여기서 한 번 채점하고, 방 목록을 관리한다.
///
/// 채점 항목과 방 목록을 한 화면에 이어 붙이면, 방을 하나 보려고 매번 채점 항목
/// 전부를 스크롤해서 지나가야 한다. 하는 일이 다르니 탭으로 나눈다.
class BuildingDetailScreen extends StatefulWidget {
  const BuildingDetailScreen({
    super.key,
    required this.project,
    required this.building,
  });

  final Project project;
  final Building building;

  @override
  State<BuildingDetailScreen> createState() => _BuildingDetailScreenState();
}

class _BuildingDetailScreenState extends State<BuildingDetailScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this)
    ..addListener(() => setState(() {}));

  List<Criterion> _buildingCriteria = [];
  List<Criterion> _roomCriteria = [];
  List<RoomScore> _rooms = [];

  ScoreDraft _draft = ScoreDraft.empty();

  bool _loading = true;

  /// 이름·메모를 고칠 수 있으므로 넘겨받은 값을 계속 쓰지 않고 여기서 들고 간다.
  late Building _building = widget.building;

  int get _buildingId => widget.building.id!;
  int get _projectId => widget.project.id!;

  bool get _hasUnsavedChanges => !_loading && _draft.isDirty;

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
    final buildingCriteria = await db.readCriteria(
      _projectId,
      scope: CriterionScope.building,
    );
    final roomCriteria = await db.readCriteria(_projectId, scope: CriterionScope.room);
    final scores = await db.readBuildingScores(_buildingId);
    // 방 카드에 점수를 띄우려면 건물 점수까지 합산한 값이 필요해서 같은 계산을 재사용한다.
    final board = await db.readRoomBoard(_projectId);

    if (!mounted) return;
    setState(() {
      _buildingCriteria = buildingCriteria;
      _roomCriteria = roomCriteria;
      _rooms = board.where((entry) => entry.building.id == _buildingId).toList();
      _draft = ScoreDraft(scores);
      _loading = false;
    });
  }

  Future<void> _saveScores() async {
    await AppDatabase.instance.saveBuildingScores(_buildingId, _draft.values);
    if (!mounted) return;
    HapticFeedback.mediumImpact();
    setState(_draft.markSaved);
    await _refresh();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('건물 점수를 저장했어요')),
    );
  }

  Future<void> _editBuilding() async {
    final entry = await showDialog<EntryResult>(
      context: context,
      builder: (_) => EntryDialog(
        title: '건물 수정',
        nameHint: '건물 · 예: 역삼동 대성빌라',
        memoHint: '메모 (선택) · 예: 역 도보 8분',
        confirmLabel: '저장',
        initialName: _building.name,
        initialMemo: _building.memo,
        nameCheck: (name) async =>
            await AppDatabase.instance.buildingNameExists(
              _projectId,
              name,
              exceptId: _buildingId,
            )
            ? '이 목록에 같은 이름의 건물이 있어요.'
            : null,
      ),
    );
    if (entry == null || !mounted) return;

    await AppDatabase.instance.updateBuilding(_buildingId, entry.name, entry.memo);
    if (!mounted) return;
    HapticFeedback.lightImpact();
    setState(() {
      _building = Building(
        id: _building.id,
        projectId: _building.projectId,
        name: entry.name,
        memo: entry.memo,
        createdAt: _building.createdAt,
      );
    });
  }

  Future<void> _addRoom() async {
    final entry = await showDialog<EntryResult>(
      context: context,
      builder: (_) => EntryDialog(
        title: '방 추가',
        nameHint: '예: 302호',
        memoHint: '메모 (선택) · 예: 65/50, 남향',
        nameCheck: (name) async =>
            await AppDatabase.instance.roomNameExists(_buildingId, name)
            ? '이 건물에 같은 이름의 방이 있어요.'
            : null,
      ),
    );
    if (entry == null || !mounted) return;

    final roomId = await AppDatabase.instance.createRoom(
      _buildingId,
      entry.name,
      entry.memo,
    );
    HapticFeedback.lightImpact();
    await _refresh();
    if (!mounted) return;

    // 방을 추가한 직후엔 곧바로 채점하게 되므로 바로 그 화면으로 넘어간다.
    final created = _rooms.where((item) => item.room.id == roomId).firstOrNull;
    if (created != null) await _openRoom(created.room);
  }

  Future<void> _openRoom(Room room) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => RoomDetailScreen(
          room: room,
          building: _building,
          criteria: _roomCriteria,
        ),
      ),
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
    final scored = _draft.scoredCount;
    final total = _buildingCriteria.length;

    return PopScope(
      canPop: !_hasUnsavedChanges,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (!await confirmDiscardChanges(context) || !context.mounted) return;
        Navigator.of(context).pop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_building.name),
          actions: [
            IconButton(
              onPressed: _editBuilding,
              icon: const Icon(Icons.edit_outlined, size: 20),
              tooltip: '건물 수정',
            ),
            // 채점 항목이 길어서 스크롤을 내리면 하단 버튼이 안 보인다.
            // 저장은 늘 같은 자리에 있어야 해서 앱바에 둔다.
            if (_hasUnsavedChanges)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilledButton(
                  onPressed: _saveScores,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(64, 36),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    textStyle: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  child: const Text('저장'),
                ),
              ),
          ],
          bottom: TabBar(
            controller: _tabs,
            labelColor: palette.textStrong,
            unselectedLabelColor: palette.textMuted,
            indicatorColor: palette.brand,
            indicatorSize: TabBarIndicatorSize.tab,
            dividerColor: palette.border,
            labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            tabs: [
              Tab(text: total == 0 ? '건물 평가' : '건물 평가 $scored/$total'),
              Tab(text: '방 ${_rooms.length}'),
            ],
          ),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                controller: _tabs,
                children: [_buildScoringTab(), _buildRoomsTab()],
              ),
        // 방 탭에서만. 채점하다가 눌릴 자리에 둘 버튼이 아니다.
        floatingActionButton: _loading || _tabs.index != 1
            ? null
            : FloatingActionButton.extended(
                onPressed: _addRoom,
                backgroundColor: palette.brand,
                foregroundColor: Colors.white,
                elevation: 0,
                icon: const Icon(Icons.add),
                label: const Text('방 추가', style: TextStyle(fontWeight: FontWeight.w600)),
              ),
      ),
    );
  }

  Widget _buildScoringTab() {
    final palette = context.palette;

    return ListView(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.page,
        16,
        AppSpacing.page,
        32 + MediaQuery.paddingOf(context).bottom,
      ),
      children: [
        Text(
          '이 건물의 모든 방에 공통으로 적용됩니다.',
          style: TextStyle(fontSize: 13, color: palette.textMuted),
        ),
        const SizedBox(height: 12),
        if (_buildingCriteria.isEmpty)
          Text(
            '건물 평가 기준이 없어요.',
            style: TextStyle(fontSize: 13.5, color: palette.textMuted),
          )
        else
          for (final criterion in _buildingCriteria) ...[
            CriterionScoreCard(
              criterion: criterion,
              value: _draft.valueOf(criterion.id!),
              onChanged: (value) => setState(() => _draft.set(criterion.id!, value)),
              onCleared: () => setState(() => _draft.clear(criterion.id!)),
            ),
            const SizedBox(height: 10),
          ],
        const SizedBox(height: 20),
        MediaSection(building: _building),
      ],
    );
  }

  Widget _buildRoomsTab() {
    final palette = context.palette;
    final anyScore = _rooms.any((entry) => entry.hasScore);

    return ListView(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.page,
        16,
        AppSpacing.page,
        120 + MediaQuery.paddingOf(context).bottom,
      ),
      children: [
        Text(
          _rooms.isEmpty
              ? '아직 넣은 방이 없어요'
              : '방 ${_rooms.length}칸${anyScore ? ' · 점수순' : ''}',
          style: TextStyle(fontSize: 13.5, color: palette.textMuted),
        ),
        const SizedBox(height: 16),
        for (final entry in _rooms) ...[
          // 등수는 프로젝트 순위에서만. 여기서 또 번호를 붙이면 "이 건물 1위"와
          // "전체 4위"가 한 방에 동시에 붙어 어느 쪽이 진짜인지 흐려진다.
          RoomCard(
            entry: entry,
            onTap: () => _openRoom(entry.room),
            onDelete: () => _deleteRoom(entry.room),
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}
