import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../db/database.dart';
import '../models/models.dart';
import '../models/scoring.dart';
import '../theme.dart';
import 'widgets/confirm_dialog.dart';
import 'widgets/criterion_score_card.dart';
import 'widgets/media_section.dart';

/// 방 하나를 방 평가 기준대로 채점하고, 사진·영상을 붙인다.
class RoomDetailScreen extends StatefulWidget {
  const RoomDetailScreen({super.key, required this.room, required this.criteria});

  final Room room;
  final List<Criterion> criteria;

  @override
  State<RoomDetailScreen> createState() => _RoomDetailScreenState();
}

class _RoomDetailScreenState extends State<RoomDetailScreen> {
  ScoreDraft _draft = ScoreDraft.empty();

  bool _loading = true;
  bool _saving = false;

  bool get _hasUnsavedChanges => !_loading && _draft.isDirty;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final values = await AppDatabase.instance.readRoomScores(widget.room.id!);
    if (!mounted) return;
    setState(() {
      _draft = ScoreDraft(values);
      _loading = false;
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    await AppDatabase.instance.saveRoomScores(widget.room.id!, _draft.values);
    if (!mounted) return;
    HapticFeedback.mediumImpact();
    Navigator.of(context).pop();
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
        appBar: AppBar(title: Text(widget.room.name)),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.page,
                  8,
                  AppSpacing.page,
                  24,
                ),
                children: [
                  if (widget.room.memo != null && widget.room.memo!.isNotEmpty) ...[
                    Text(
                      widget.room.memo!,
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
                      ),
                      const SizedBox(height: 10),
                    ],
                  const SizedBox(height: 20),
                  MediaSection(roomId: widget.room.id),
                ],
              ),
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: palette.background,
            border: Border(top: BorderSide(color: palette.border)),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.page,
                12,
                AppSpacing.page,
                12,
              ),
              child: FilledButton(
                onPressed: _loading || _saving ? null : _save,
                child: Text(_hasUnsavedChanges ? '저장' : '저장됨'),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
