import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../db/database.dart';
import '../models/models.dart';
import '../theme.dart';
import 'building_detail_screen.dart';
import 'widgets/confirm_dialog.dart';
import 'widgets/delete_action.dart';
import 'widgets/entry_dialog.dart';

/// 건물 관리 화면.
///
/// 건물은 점수를 갖지 않으므로 순위에 낄 자리가 없고, 한 번 만들어두면 공통 평가를
/// 매길 때 말고는 거의 건드리지 않는다. 그래서 상시 화면에서 빼 여기로 모았다.
class BuildingListScreen extends StatefulWidget {
  const BuildingListScreen({super.key, required this.project});

  final Project project;

  @override
  State<BuildingListScreen> createState() => _BuildingListScreenState();
}

class _BuildingListScreenState extends State<BuildingListScreen> {
  List<BuildingSummary> _buildings = [];
  bool _loading = true;

  int get _projectId => widget.project.id!;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final buildings = await AppDatabase.instance.readBuildingSummaries(_projectId);
    if (!mounted) return;
    setState(() {
      _buildings = buildings;
      _loading = false;
    });
  }

  Future<void> _addBuilding() async {
    final entry = await showDialog<EntryResult>(
      context: context,
      builder: (_) => EntryDialog(
        title: '건물 추가',
        nameHint: '건물 · 예: 역삼동 대성빌라',
        memoHint: '메모 (선택) · 예: 역 도보 8분',
        nameCheck: (name) async =>
            await AppDatabase.instance.buildingNameExists(_projectId, name)
            ? '이 목록에 같은 이름의 건물이 있어요.'
            : null,
      ),
    );
    if (entry == null || !mounted) return;

    final buildingId = await AppDatabase.instance.createBuilding(
      _projectId,
      entry.name,
      entry.memo,
    );
    HapticFeedback.lightImpact();
    await _refresh();
    if (!mounted) return;

    // 건물을 만들었다면 공통 평가를 매기러 온 것이므로 바로 그 화면으로 넘어간다.
    final created = _buildings
        .where((summary) => summary.building.id == buildingId)
        .firstOrNull;
    if (created != null) await _open(created.building);
  }

  Future<void> _open(Building building) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => BuildingDetailScreen(project: widget.project, building: building),
      ),
    );
    await _refresh();
  }

  /// 건물을 지우면 그 안의 방·점수·사진이 전부 사라지므로 확인을 받는다.
  Future<void> _confirmDelete(Building building) async {
    final ok = await confirmDestructive(
      context,
      title: '‘${building.name}’ 삭제',
      message: '이 건물의 방과 점수, 사진·영상이 모두 지워집니다.',
    );
    if (!ok || !mounted) return;

    await AppDatabase.instance.deleteBuilding(building.id!);
    if (!mounted) return;
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Scaffold(
      appBar: AppBar(title: const Text('건물')),
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
                Text(
                  _buildings.isEmpty
                      ? '아직 넣은 건물이 없어요'
                      : '건물마다 공통 평가를 한 번씩 매겨두면, 그 안의 모든 방 점수에 함께 반영됩니다.',
                  style: TextStyle(
                    fontSize: 13.5,
                    color: palette.textMuted,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),
                for (final summary in _buildings) ...[
                  _BuildingCard(
                    summary: summary,
                    onTap: () => _open(summary.building),
                    onDelete: () => _confirmDelete(summary.building),
                  ),
                  const SizedBox(height: 12),
                ],
              ],
            ),
      floatingActionButton: _loading
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

class _BuildingCard extends StatelessWidget {
  const _BuildingCard({
    required this.summary,
    required this.onTap,
    required this.onDelete,
  });

  final BuildingSummary summary;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final building = summary.building;

    return AppCard(
      onTap: onTap,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  building.name,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: palette.textStrong,
                  ),
                ),
                if (building.memo != null && building.memo!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    building.memo!,
                    style: TextStyle(fontSize: 13.5, color: palette.textMuted),
                  ),
                ],
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(
                      Icons.meeting_room_outlined,
                      size: 15,
                      color: palette.textMuted,
                    ),
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
                      color: summary.buildingScoringDone
                          ? palette.done
                          : palette.textMuted,
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        summary.buildingScoringDone
                            ? '건물 채점 완료'
                            : '건물 ${summary.buildingCriterionCount}개 중 '
                                  '${summary.buildingScoredCount}개',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: summary.buildingScoringDone
                              ? palette.done
                              : palette.textMuted,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          DeleteAction(onConfirm: onDelete),
        ],
      ),
    );
  }
}
