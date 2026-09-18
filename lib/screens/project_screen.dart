import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../db/database.dart';
import '../models/models.dart';
import '../models/ranking.dart';
import '../text/josa.dart';
import '../theme.dart';
import 'criteria_screen.dart';
import 'room_screen.dart';
import 'widgets/inline_name.dart';
import 'widgets/main_action_button.dart';
import 'widgets/room_card.dart';
import 'widgets/room_entry_sheet.dart';
import 'widgets/toast.dart';

/// One project: every visited room, ranked by score.
///
/// Rooms of the same building that sit next to each other share a building header, which
/// stays pinned while its rooms scroll by.
class ProjectScreen extends StatefulWidget {
  const ProjectScreen({super.key, required this.project});

  final Project project;

  @override
  State<ProjectScreen> createState() => _ProjectScreenState();
}

class _ProjectScreenState extends State<ProjectScreen> {
  List<RoomScore> _board = [];
  bool _loading = true;
  late String _name = widget.project.name;

  int get _projectId => widget.project.id;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final board = await AppDatabase.instance.readRoomBoard(_projectId);
    if (!mounted) return;
    setState(() {
      _board = board;
      _loading = false;
    });
  }

  Future<String?> _rename(String name) async {
    final db = AppDatabase.instance;
    if (await db.projectNameExists(name, exceptId: _projectId)) {
      return '같은 이름의 목록이 있어요';
    }

    final previous = _name;
    await db.renameProject(_projectId, name);
    if (!mounted) return null;
    setState(() => _name = name);
    showUndo(
      '이름을 바꿨어요',
      onUndo: () async {
        await db.renameProject(_projectId, previous);
        if (mounted) setState(() => _name = previous);
      },
    );
    return null;
  }

  Future<void> _addRoom() async {
    final db = AppDatabase.instance;
    final buildings = await db.readBuildings(_projectId);
    if (!mounted) return;
    final entry = await showRoomEntrySheet(
      context,
      projectId: _projectId,
      buildings: buildings,
    );
    if (entry == null || !mounted) return;

    final created = await db.createRoom(
      projectId: _projectId,
      buildingId: entry.buildingId,
      newBuildingName: entry.newBuildingName,
      name: entry.name,
    );
    if (!mounted) return;
    HapticFeedback.lightImpact();
    await _refresh();
    if (!mounted) return;

    // A new room is scored right away, so it opens directly.
    final route = _roomRoute(created.roomId);
    final navigator = Navigator.of(context);
    showUndo(
      '‘${entry.name}’${objectJosa(entry.name)} 추가했어요',
      onUndo: () async {
        if (route.isActive) navigator.removeRoute(route);
        await db.deleteRoom(created.roomId);
        await _refresh();
      },
    );
    await navigator.push(route);
    await _refresh();
  }

  MaterialPageRoute<void> _roomRoute(int roomId) => MaterialPageRoute(
    builder: (_) => RoomScreen(projectId: _projectId, roomId: roomId),
  );

  Future<void> _openRoom(Room room) async {
    await Navigator.of(context).push(_roomRoute(room.id));
    await _refresh();
  }

  Future<void> _openCriteria() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) =>
            CriteriaScreen(title: '평가 기준', store: ProjectCriteria(_projectId)),
      ),
    );
    await _refresh();
  }

  Future<void> _deleteRoom(Room room) async {
    final deletion = await AppDatabase.instance.stageRoomDeletion(room.id);
    await _refresh();
    if (!mounted) return;

    showDeletionUndo(
      '‘${room.name}’${objectJosa(room.name)} 삭제했어요',
      deletion,
      onUndone: _refresh,
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final buildingCount = {for (final entry in _board) entry.building.id}
        .length;

    return Scaffold(
      appBar: AppBar(
        title: InlineName(
          name: _name,
          onRename: _rename,
          style: Theme.of(context).appBarTheme.titleTextStyle!,
        ),
        actions: [
          TextButton.icon(
            onPressed: _openCriteria,
            icon: const Icon(Icons.tune, size: 18),
            label: const Text('평가 기준'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _board.isEmpty
          ? ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.page,
                12,
                AppSpacing.page,
                32,
              ),
              children: [
                EmptyState(
                  icon: Icons.meeting_room_outlined,
                  title: '아직 방이 없어요',
                  actionLabel: '방 추가하기',
                  onAction: _addRoom,
                ),
              ],
            )
          : CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.page,
                    4,
                    AppSpacing.page,
                    4,
                  ),
                  sliver: SliverToBoxAdapter(
                    child: Text(
                      '방 ${_board.length} · 건물 $buildingCount',
                      style: TextStyle(fontSize: 13, color: palette.textMuted),
                    ),
                  ),
                ),
                for (final run in groupIntoRuns(_board))
                  SliverMainAxisGroup(
                    slivers: [
                      SliverPersistentHeader(
                        pinned: true,
                        delegate: _BuildingHeader(run.building.name),
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.page,
                        ),
                        sliver: SliverList.separated(
                          itemCount: run.entries.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final entry = run.entries[index];
                            return RoomCard(
                              entry: entry.score,
                              rank: entry.rank,
                              onTap: () => _openRoom(entry.score.room),
                              onDelete: () => _deleteRoom(entry.score.room),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                SliverToBoxAdapter(child: SizedBox(height: 120 + bottomInset)),
              ],
            ),
      // Like the home screen, an empty list offers its own button instead.
      floatingActionButton: _loading || _board.isEmpty
          ? null
          : MainActionButton(
              icon: Icons.add,
              label: '방 추가',
              onPressed: _addRoom,
            ),
    );
  }
}

class _BuildingHeader extends SliverPersistentHeaderDelegate {
  const _BuildingHeader(this.name);

  static const _height = 40.0;

  final String name;

  @override
  double get minExtent => _height;

  @override
  double get maxExtent => _height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final palette = context.palette;
    return Container(
      color: palette.background,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.page,
        14,
        AppSpacing.page,
        6,
      ),
      child: Row(
        children: [
          Icon(Icons.apartment_outlined, size: 15, color: palette.textMuted),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: palette.textBody,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: Divider(height: 1, color: palette.border)),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(_BuildingHeader oldDelegate) => oldDelegate.name != name;
}
