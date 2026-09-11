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

/// One building: scores its shared criteria once and manages its rooms.
///
/// Scoring and the room list do different jobs, and stacking them would mean scrolling
/// past every criterion to reach a room, so they are separate tabs.
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

  /// Kept here rather than read from the widget, since the name and memo can be edited.
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
    final roomCriteria = await db.readCriteria(
      _projectId,
      scope: CriterionScope.room,
    );
    final scores = await db.readBuildingScores(_buildingId);
    // Room cards need scores that include the building's ratings, so reuse the ranking query.
    final board = await db.readRoomBoard(_projectId);

    if (!mounted) return;
    setState(() {
      _buildingCriteria = buildingCriteria;
      _roomCriteria = roomCriteria;
      _rooms = board
          .where((entry) => entry.building.id == _buildingId)
          .toList();
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
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('건물 점수를 저장했어요')));
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

    await AppDatabase.instance.updateBuilding(
      _buildingId,
      entry.name,
      entry.memo,
    );
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

    // A new room is scored right away, so go straight to it.
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
            // The criteria list is long enough to push a bottom button off screen,
            // and save should always be in the same place.
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
            labelStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
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
        // Rooms tab only; it would sit where taps land while scoring.
        floatingActionButton: _loading || _tabs.index != 1
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
              onChanged: (value) =>
                  setState(() => _draft.set(criterion.id!, value)),
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
          // Ranks appear only in the project ranking. Numbering rooms here too would put
          // "#1 in this building" and "#4 overall" on the same room.
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
