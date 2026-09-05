import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../db/database.dart';
import '../models/models.dart';
import '../models/scoring.dart';
import '../theme.dart';
import 'room_detail_screen.dart';
import 'widgets/card_menu.dart';
import 'widgets/confirm_dialog.dart';
import 'widgets/criterion_score_card.dart';
import 'widgets/media_section.dart';

/// 건물 하나. 건물 공통 항목을 여기서 한 번 채점하고, 방 목록을 관리한다.
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

class _BuildingDetailScreenState extends State<BuildingDetailScreen> {
  List<Criterion> _buildingCriteria = [];
  List<Criterion> _roomCriteria = [];
  List<Room> _rooms = [];
  Map<int, int> _roomScoredCounts = {};
  Map<int, double> _percentByRoom = {};

  ScoreDraft _draft = ScoreDraft.empty();

  bool _loading = true;

  int get _buildingId => widget.building.id!;

  bool get _hasUnsavedChanges => !_loading && _draft.isDirty;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final db = AppDatabase.instance;
    final projectId = widget.project.id!;
    final buildingCriteria = await db.readCriteria(projectId, scope: CriterionScope.building);
    final roomCriteria = await db.readCriteria(projectId, scope: CriterionScope.room);
    final rooms = await db.readRooms(_buildingId);
    final counts = await db.readRoomScoredCounts(_buildingId);
    final scores = await db.readBuildingScores(_buildingId);
    // 방 카드에 점수를 띄우려면 건물 점수까지 합산된 값이 필요해서 순위 계산을 재사용한다.
    final ranking = await db.readRanking(projectId);

    if (!mounted) return;
    setState(() {
      _percentByRoom = {
        for (final entry in ranking)
          if (entry.building.id == _buildingId && entry.hasAnyScore)
            entry.room.id!: entry.percent,
      };
      _buildingCriteria = buildingCriteria;
      _roomCriteria = roomCriteria;
      _rooms = rooms;
      _roomScoredCounts = counts;
      _draft = ScoreDraft(scores);
      _loading = false;
    });
  }

  Future<void> _saveScores() async {
    await AppDatabase.instance.saveBuildingScores(_buildingId, _draft.values);
    if (!mounted) return;
    HapticFeedback.mediumImpact();
    setState(_draft.markSaved);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('건물 점수를 저장했어요')),
    );
  }

  Future<void> _addRoom() async {
    final nameController = TextEditingController();
    final memoController = TextEditingController();

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('방 추가'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              autofocus: true,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(hintText: '예: 302호'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: memoController,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => Navigator.pop(context, true),
              decoration: const InputDecoration(hintText: '메모 (선택) · 예: 65/50, 남향'),
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
    nameController.dispose();
    memoController.dispose();

    if (saved != true || name.isEmpty) return;
    final roomId = await AppDatabase.instance.createRoom(
      _buildingId,
      name,
      memo.isEmpty ? null : memo,
    );
    if (!mounted) return;
    HapticFeedback.lightImpact();
    await _refresh();
    if (!mounted) return;

    // 방을 추가한 직후엔 곧바로 채점하게 되므로 바로 그 화면으로 넘어간다.
    final created = _rooms.where((room) => room.id == roomId).firstOrNull;
    if (created != null) await _openRoom(created);
  }

  Future<void> _openRoom(Room room) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => RoomDetailScreen(room: room, criteria: _roomCriteria),
      ),
    );
    await _refresh();
  }

  /// 방 삭제는 자주 일어나고 되돌리기 쉬우므로 확인 대신 실행취소를 제공한다.
  Future<void> _deleteRoom(Room room) async {
    final snapshot = await AppDatabase.instance.deleteRoom(room.id!);
    if (!mounted || snapshot == null) return;

    HapticFeedback.mediumImpact();
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
        appBar: AppBar(title: Text(widget.building.name)),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.page,
                  8,
                  AppSpacing.page,
                  120,
                ),
                children: [
                  // ----- 건물 채점 -----
                  Row(
                    children: [
                      Text(
                        '건물 평가',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: palette.textStrong,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '$total개 중 $scored개',
                        style: TextStyle(fontSize: 12.5, color: palette.textMuted),
                      ),
                      const Spacer(),
                      if (_hasUnsavedChanges)
                        TextButton(
                          onPressed: _saveScores,
                          child: const Text('저장'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
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
                      ),
                      const SizedBox(height: 10),
                    ],

                  const SizedBox(height: 20),
                  MediaSection(buildingId: _buildingId),

                  // ----- 방 목록 -----
                  const SizedBox(height: 28),
                  Row(
                    children: [
                      Text(
                        '방',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: palette.textStrong,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${_rooms.length}',
                        style: TextStyle(fontSize: 13, color: palette.textMuted),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_rooms.isEmpty)
                    EmptyState(
                      icon: Icons.meeting_room_outlined,
                      title: '아직 넣은 방이 없어요',
                      description: '같은 건물에서 본 방을 하나씩 추가하세요.',
                      actionLabel: '첫 방 추가하기',
                      onAction: _addRoom,
                    )
                  else
                    for (final room in _rooms) ...[
                      _RoomCard(
                        room: room,
                        scored: _roomScoredCounts[room.id] ?? 0,
                        total: _roomCriteria.length,
                        percent: _percentByRoom[room.id],
                        onTap: () => _openRoom(room),
                        onDelete: () => _deleteRoom(room),
                      ),
                      const SizedBox(height: 12),
                    ],
                ],
              ),
        floatingActionButton: _rooms.isEmpty && !_loading
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
}

class _RoomCard extends StatelessWidget {
  const _RoomCard({
    required this.room,
    required this.scored,
    required this.total,
    required this.percent,
    required this.onTap,
    required this.onDelete,
  });

  final Room room;
  final int scored;
  final int total;

  /// 건물 점수까지 합산한 0~100 값. 아직 아무것도 안 매겼으면 null.
  final double? percent;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final done = total > 0 && scored >= total;

    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  room.name,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: palette.textStrong,
                  ),
                ),
              ),
              if (percent != null) ...[
                Text(
                  '${percent!.toStringAsFixed(0)}점',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: done ? palette.done : palette.brand,
                  ),
                ),
                const SizedBox(width: 6),
              ],
              CardMenu(onDelete: onDelete),
            ],
          ),
          if (room.memo != null && room.memo!.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              room.memo!,
              style: TextStyle(fontSize: 13.5, color: palette.textMuted),
            ),
          ],
          const SizedBox(height: 14),
          ProgressBar(
            value: total == 0 ? 0 : scored / total,
            color: done ? palette.done : palette.brand,
          ),
          const SizedBox(height: 8),
          Text(
            done ? '$total개 기준 모두 채점' : '$total개 중 $scored개 채점',
            style: TextStyle(fontSize: 12.5, color: palette.textMuted),
          ),
        ],
      ),
    );
  }
}
