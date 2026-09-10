import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../db/database.dart';
import '../models/models.dart';
import '../models/scoring.dart';
import '../theme.dart';
import 'widgets/confirm_dialog.dart';
import 'widgets/entry_dialog.dart';
import 'widgets/criterion_score_card.dart';
import 'widgets/media_section.dart';

/// 방 하나를 방 평가 기준대로 채점하고, 사진·영상을 붙인다.
class RoomDetailScreen extends StatefulWidget {
  const RoomDetailScreen({
    super.key,
    required this.room,
    required this.building,
    required this.criteria,
  });

  final Room room;

  /// 사진을 공유할 때 "어느 건물의 방인지"까지 붙여야 받는 쪽이 알아본다.
  final Building building;

  final List<Criterion> criteria;

  @override
  State<RoomDetailScreen> createState() => _RoomDetailScreenState();
}

class _RoomDetailScreenState extends State<RoomDetailScreen> {
  ScoreDraft _draft = ScoreDraft.empty();

  bool _loading = true;
  bool _saving = false;

  /// 이름·메모를 고칠 수 있으므로 넘겨받은 값을 계속 쓰지 않고 여기서 들고 간다.
  late Room _room = widget.room;

  bool get _hasUnsavedChanges => !_loading && _draft.isDirty;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final values = await AppDatabase.instance.readRoomScores(_room.id!);
    if (!mounted) return;
    setState(() {
      _draft = ScoreDraft(values);
      _loading = false;
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    await AppDatabase.instance.saveRoomScores(_room.id!, _draft.values);
    if (!mounted) return;
    HapticFeedback.mediumImpact();
    setState(() {
      _draft.markSaved();
      _saving = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('방 점수를 저장했어요')),
    );
  }

  Future<void> _editRoom() async {
    final entry = await showDialog<EntryResult>(
      context: context,
      builder: (_) => EntryDialog(
        title: '방 수정',
        nameHint: '예: 302호',
        memoHint: '메모 (선택) · 예: 65/50, 남향',
        confirmLabel: '저장',
        initialName: _room.name,
        initialMemo: _room.memo,
        nameCheck: (name) async =>
            await AppDatabase.instance.roomNameExists(
              _room.buildingId,
              name,
              exceptId: _room.id,
            )
            ? '이 건물에 같은 이름의 방이 있어요.'
            : null,
      ),
    );
    if (entry == null || !mounted) return;

    await AppDatabase.instance.updateRoom(_room.id!, entry.name, entry.memo);
    if (!mounted) return;
    HapticFeedback.lightImpact();
    setState(() {
      _room = Room(
        id: _room.id,
        buildingId: _room.buildingId,
        name: entry.name,
        memo: entry.memo,
        createdAt: _room.createdAt,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final scored = _draft.scoredCount;
    final total = widget.criteria.length;
    final allDone = total > 0 && scored >= total;

    return PopScope(
      canPop: !_hasUnsavedChanges,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (!await confirmDiscardChanges(context) || !context.mounted) return;
        Navigator.of(context).pop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_room.name),
          actions: [
            IconButton(
              onPressed: _editRoom,
              icon: const Icon(Icons.edit_outlined, size: 20),
              tooltip: '방 수정',
            ),
            // 건물 채점과 같은 자리에 같은 모양으로. 스크롤을 내려도 계속 보인다.
            if (_hasUnsavedChanges)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilledButton(
                  onPressed: _saving ? null : _save,
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
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.page,
                  8,
                  AppSpacing.page,
                  // 하단 저장 바를 앱바로 옮기면서 화면 맨 아래를 가려주던 것이 없어졌다.
                  // 제스처 바 높이만큼 더 띄우지 않으면 마지막 카드가 잘린다.
                  32 + MediaQuery.paddingOf(context).bottom,
                ),
                children: [
                  if (_room.memo != null && _room.memo!.isNotEmpty) ...[
                    Text(
                      _room.memo!,
                      style: TextStyle(fontSize: 13.5, color: palette.textMuted),
                    ),
                    const SizedBox(height: 14),
                  ],
                  Row(
                    children: [
                      Text(
                        '$total개 중 $scored개 채점',
                        style: TextStyle(fontSize: 13.5, color: palette.textMuted),
                      ),
                      const Spacer(),
                      if (allDone)
                        Text(
                          '모두 채점했어요',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: palette.done,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ProgressBar(
                    value: total == 0 ? 0 : scored / total,
                    color: allDone ? palette.done : palette.brand,
                  ),
                  const SizedBox(height: 20),
                  if (widget.criteria.isEmpty)
                    Text(
                      '방 평가 기준이 없어요. 목록 화면의 ‘평가 기준’에서 추가할 수 있어요.',
                      style: TextStyle(fontSize: 13.5, color: palette.textMuted),
                    )
                  else
                    for (final criterion in widget.criteria) ...[
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
                  MediaSection(building: widget.building, room: _room),
                ],
              ),
      ),
    );
  }
}
