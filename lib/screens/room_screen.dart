import 'dart:async';

import 'package:flutter/material.dart';

import '../db/database.dart';
import '../models/models.dart';
import '../theme.dart';
import 'widgets/criterion_score_card.dart';
import 'widgets/inline_name.dart';
import 'widgets/media_section.dart';
import 'widgets/toast.dart';

/// Everything about one room, in two tabs: the building's shared ratings and photos, and
/// the room's own memo, ratings, and photos. Every change is saved as it happens.
class RoomScreen extends StatefulWidget {
  const RoomScreen({super.key, required this.projectId, required this.roomId});

  final int projectId;
  final int roomId;

  @override
  State<RoomScreen> createState() => _RoomScreenState();
}

class _RoomScreenState extends State<RoomScreen>
    with SingleTickerProviderStateMixin {
  final _memo = TextEditingController();
  Timer? _memoSave;

  /// Created on first load, since the starting tab depends on what is left to rate.
  TabController? _tabs;

  Room? _room;
  Building? _building;
  List<Criterion> _buildingCriteria = [];
  List<Criterion> _roomCriteria = [];
  Map<int, double> _buildingScores = {};
  Map<int, double> _roomScores = {};
  int _mediaRevision = 0;

  AppDatabase get _db => AppDatabase.instance;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    if (_memoSave?.isActive ?? false) {
      _memoSave!.cancel();
      _saveMemo();
    }
    _memo.dispose();
    _tabs?.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final room = await _db.readRoom(widget.roomId);
    final building = await _db.readBuilding(room.buildingId);
    final criteria = await _db.readCriteria(widget.projectId);
    final buildingScores = await _db.readBuildingScores(building.id);
    final roomScores = await _db.readRoomScores(room.id);
    if (!mounted) return;

    final buildingCriteria = [
      for (final criterion in criteria)
        if (criterion.scope == CriterionScope.building) criterion,
    ];
    // Only on first load, so a reload never overwrites a memo being typed.
    if (_room == null) _memo.text = room.memo ?? '';

    setState(() {
      _room = room;
      _building = building;
      _buildingCriteria = buildingCriteria;
      _roomCriteria = [
        for (final criterion in criteria)
          if (criterion.scope == CriterionScope.room) criterion,
      ];
      _buildingScores = buildingScores;
      _roomScores = roomScores;
      // The building is usually rated once, by its first room; later rooms start on their own tab.
      _tabs ??= TabController(
        length: 2,
        vsync: this,
        initialIndex:
            _scoredCount(buildingCriteria, buildingScores) <
                buildingCriteria.length
            ? 0
            : 1,
      );
    });
  }

  int _scoredCount(List<Criterion> criteria, Map<int, double> scores) =>
      criteria.where((criterion) => scores.containsKey(criterion.id)).length;

  void _scheduleMemoSave() {
    _memoSave?.cancel();
    _memoSave = Timer(const Duration(milliseconds: 500), _saveMemo);
  }

  void _saveMemo() {
    final memo = _memo.text.trim();
    _db.updateRoomMemo(widget.roomId, memo.isEmpty ? null : memo);
  }

  Future<String?> _renameRoom(String name) async {
    final room = _room!;
    if (await _db.roomNameExists(room.buildingId, name, exceptId: room.id)) {
      return '이 건물에 같은 이름의 방이 있어요';
    }
    await _db.renameRoom(room.id, name);
    await _load();
    showUndo(
      '이름을 바꿨어요',
      onUndo: () async {
        await _db.renameRoom(room.id, room.name);
        await _load();
      },
    );
    return null;
  }

  Future<String?> _renameBuilding(String name) async {
    final building = _building!;
    if (await _db.buildingNameExists(
      widget.projectId,
      name,
      exceptId: building.id,
    )) {
      return '같은 이름의 건물이 있어요';
    }
    await _db.renameBuilding(building.id, name);
    await _load();
    showUndo(
      '이름을 바꿨어요',
      onUndo: () async {
        await _db.renameBuilding(building.id, building.name);
        await _load();
      },
    );
    return null;
  }

  void _setBuildingScore(Criterion criterion, double? value) {
    setState(() => _setOrRemove(_buildingScores, criterion.id, value));
    _db.setBuildingScore(_building!.id, criterion.id, value);
  }

  void _setRoomScore(Criterion criterion, double? value) {
    setState(() => _setOrRemove(_roomScores, criterion.id, value));
    _db.setRoomScore(widget.roomId, criterion.id, value);
  }

  static void _setOrRemove(Map<int, double> scores, int id, double? value) {
    if (value == null) {
      scores.remove(id);
    } else {
      scores[id] = value;
    }
  }

  void _onPlacementChanged() => setState(() => _mediaRevision++);

  @override
  Widget build(BuildContext context) {
    final room = _room;
    final building = _building;
    final tabs = _tabs;
    if (room == null || building == null || tabs == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final palette = context.palette;

    return Scaffold(
      appBar: AppBar(
        title: InlineName(
          name: room.name,
          onRename: _renameRoom,
          style: Theme.of(context).appBarTheme.titleTextStyle!,
        ),
        bottom: TabBar(
          controller: tabs,
          tabs: [
            _ProgressTab(
              label: '건물',
              scored: _scoredCount(_buildingCriteria, _buildingScores),
              total: _buildingCriteria.length,
            ),
            _ProgressTab(
              label: '방',
              scored: _scoredCount(_roomCriteria, _roomScores),
              total: _roomCriteria.length,
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: tabs,
        children: [
          _page([
            Row(
              children: [
                Icon(
                  Icons.apartment_outlined,
                  size: 18,
                  color: palette.textMuted,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: InlineName(
                    name: building.name,
                    onRename: _renameBuilding,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: palette.textStrong,
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(left: 26),
              child: Text(
                '같은 건물의 방에 모두 적용돼요',
                style: TextStyle(fontSize: 12.5, color: palette.textMuted),
              ),
            ),
            const SizedBox(height: 16),
            ..._scoreCards(
              _buildingCriteria,
              _buildingScores,
              _setBuildingScore,
            ),
            MediaSection(
              building: building,
              revision: _mediaRevision,
              onPlacementChanged: _onPlacementChanged,
            ),
          ]),
          _page([
            TextField(
              controller: _memo,
              minLines: 1,
              maxLines: 4,
              textInputAction: TextInputAction.newline,
              decoration: const InputDecoration(hintText: '메모'),
              onChanged: (_) => _scheduleMemoSave(),
            ),
            const SizedBox(height: 16),
            ..._scoreCards(_roomCriteria, _roomScores, _setRoomScore),
            MediaSection(
              building: building,
              room: room,
              revision: _mediaRevision,
              onPlacementChanged: _onPlacementChanged,
            ),
          ]),
        ],
      ),
    );
  }

  Widget _page(List<Widget> children) => ListView(
    padding: EdgeInsets.fromLTRB(
      AppSpacing.page,
      16,
      AppSpacing.page,
      32 + MediaQuery.paddingOf(context).bottom,
    ),
    children: children,
  );

  /// A tab without criteria shows only its photos.
  List<Widget> _scoreCards(
    List<Criterion> criteria,
    Map<int, double> scores,
    void Function(Criterion criterion, double? value) onChanged,
  ) => [
    for (final criterion in criteria) ...[
      CriterionScoreCard(
        criterion: criterion,
        value: scores[criterion.id],
        onChanged: (value) => onChanged(criterion, value),
      ),
      const SizedBox(height: 10),
    ],
    if (criteria.isNotEmpty) const SizedBox(height: 8),
  ];
}

/// Tab label with how many of its criteria are rated, green once all are.
class _ProgressTab extends StatelessWidget {
  const _ProgressTab({
    required this.label,
    required this.scored,
    required this.total,
  });

  final String label;
  final int scored;
  final int total;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final done = total > 0 && scored >= total;

    return Tab(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          if (total > 0) ...[
            const SizedBox(width: 6),
            Text(
              '$scored/$total',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: done ? palette.done : palette.textMuted,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
