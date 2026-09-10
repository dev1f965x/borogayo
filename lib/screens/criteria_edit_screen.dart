import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../db/database.dart';
import '../models/models.dart';
import '../theme.dart';
import 'widgets/confirm_dialog.dart';
import 'widgets/criterion_composer.dart';
import 'widgets/entry_dialog.dart';
import 'widgets/delete_action.dart';

/// 평가 기준 수정. 건물용/방용을 나눠서 보여주고, 중요도를 조절한다.
class CriteriaEditScreen extends StatefulWidget {
  const CriteriaEditScreen({super.key, required this.projectId});

  final int projectId;

  @override
  State<CriteriaEditScreen> createState() => _CriteriaEditScreenState();
}

class _CriteriaEditScreenState extends State<CriteriaEditScreen> {
  List<Criterion> _criteria = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final criteria = await AppDatabase.instance.readCriteria(widget.projectId);
    if (!mounted) return;
    setState(() {
      _criteria = criteria;
      _loading = false;
    });
  }

  Future<void> _add(CriterionDraft draft) async {
    if (_criteria.any((c) => c.name == draft.name)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('‘${draft.name}’은(는) 이미 있어요')),
      );
      return;
    }

    await AppDatabase.instance.addCriterion(widget.projectId, draft);
    if (!mounted) return;
    HapticFeedback.lightImpact();
    await _refresh();
  }

  /// 이름·이모지·유형을 고친다. 만들 때와 정할 것이 같아서 같은 시트를 쓴다.
  ///
  /// 건물용↔방용(범위)만은 못 바꾼다. 건물 점수는 건물에 하나뿐이고 방 점수는 방마다라
  /// 옮길 곳이 정해지지 않는다. 그건 지우고 새로 만드는 편이 정직하다.
  Future<void> _edit(Criterion criterion) async {
    final db = AppDatabase.instance;

    final name = await showDialog<EntryResult>(
      context: context,
      builder: (_) => EntryDialog(
        title: '평가 기준 수정',
        nameHint: '예: 채광',
        confirmLabel: '다음',
        initialName: criterion.name,
        nameCheck: (value) async =>
            _criteria.any((c) => c.id != criterion.id && c.name == value)
            ? '‘$value’은(는) 이미 있어요.'
            : null,
      ),
    );
    if (name == null || !mounted) return;

    final draft = await showCriterionSheet(
      context,
      name: name.name,
      scope: criterion.scope,
      initialType: criterion.type,
      initialEmoji: criterion.emoji,
      confirmLabel: '저장',
    );
    if (draft == null || !mounted) return;

    // 7.5점처럼 있음/없음으로 옮길 수 없는 값이 남으면 화면이 설명할 수 없는 상태가 된다.
    final toBinary =
        criterion.type == CriterionType.scale && draft.type == CriterionType.binary;
    if (toBinary && await db.hasScoresFor(criterion.id!)) {
      if (!mounted) return;
      final ok = await confirmDestructive(
        context,
        title: '여부형으로 바꿀까요?',
        message: '이미 매긴 점수는 5점 이상이면 ‘있음’, 미만이면 ‘없음’으로 바뀝니다.',
        confirmLabel: '바꾸기',
      );
      if (!ok || !mounted) return;
      await db.snapScoresToBinary(criterion.id!);
    }

    await db.updateCriterion(
      Criterion(
        id: criterion.id,
        projectId: criterion.projectId,
        name: draft.name,
        scope: criterion.scope,
        type: draft.type,
        weight: criterion.weight,
        position: criterion.position,
        emoji: draft.emoji,
      ),
    );
    if (!mounted) return;
    HapticFeedback.lightImpact();
    await _refresh();
  }

  Future<void> _changeWeight(Criterion criterion, int weight) async {
    HapticFeedback.selectionClick();
    await AppDatabase.instance.updateCriterion(criterion.copyWith(weight: weight));
    await _refresh();
  }

  /// 기준을 지우면 그 기준으로 매긴 모든 점수가 함께 사라지므로 확인을 받는다.
  Future<void> _delete(Criterion criterion) async {
    final ok = await confirmDestructive(
      context,
      title: '‘${criterion.name}’ 삭제',
      message: '이 기준으로 매긴 점수도 함께 지워집니다.',
    );
    if (!ok || !mounted) return;

    await AppDatabase.instance.deleteCriterion(criterion.id!);
    if (!mounted) return;
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Scaffold(
      appBar: AppBar(title: const Text('평가 기준')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.page,
                8,
                AppSpacing.page,
                32,
              ),
              children: [
                Text(
                  '중요도가 높은 기준일수록 순위에 더 크게 반영됩니다.',
                  style: TextStyle(fontSize: 13.5, color: palette.textMuted, height: 1.4),
                ),
                const SizedBox(height: 20),
                _ScopeSection(
                  scope: CriterionScope.building,
                  title: '건물 평가 기준',
                  description: '건물마다 한 번만 매깁니다.',
                  criteria: _criteria
                      .where((c) => c.scope == CriterionScope.building)
                      .toList(),
                  onAdd: _add,
                  onEdit: _edit,
                  onWeightChanged: _changeWeight,
                  onDelete: _delete,
                ),
                const SizedBox(height: 28),
                _ScopeSection(
                  scope: CriterionScope.room,
                  title: '방 평가 기준',
                  description: '방마다 매깁니다.',
                  criteria: _criteria.where((c) => c.scope == CriterionScope.room).toList(),
                  onAdd: _add,
                  onEdit: _edit,
                  onWeightChanged: _changeWeight,
                  onDelete: _delete,
                ),
              ],
            ),
    );
  }
}

class _ScopeSection extends StatelessWidget {
  const _ScopeSection({
    required this.scope,
    required this.title,
    required this.description,
    required this.criteria,
    required this.onAdd,
    required this.onEdit,
    required this.onWeightChanged,
    required this.onDelete,
  });

  final CriterionScope scope;
  final String title;
  final String description;
  final List<Criterion> criteria;
  final void Function(CriterionDraft draft) onAdd;
  final ValueChanged<Criterion> onEdit;
  final void Function(Criterion criterion, int weight) onWeightChanged;
  final ValueChanged<Criterion> onDelete;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: palette.textStrong,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          description,
          style: TextStyle(fontSize: 13, color: palette.textMuted),
        ),
        const SizedBox(height: 12),
        if (criteria.isEmpty)
          Text(
            '아직 없어요.',
            style: TextStyle(fontSize: 13.5, color: palette.textMuted),
          )
        else
          for (final criterion in criteria) ...[
            _CriterionRow(
              criterion: criterion,
              onTap: () => onEdit(criterion),
              onWeightChanged: (weight) => onWeightChanged(criterion, weight),
              onDelete: () => onDelete(criterion),
            ),
            const SizedBox(height: 10),
          ],
        const SizedBox(height: 4),
        CriterionComposer(scope: scope, onAdd: onAdd),
      ],
    );
  }
}

class _CriterionRow extends StatelessWidget {
  const _CriterionRow({
    required this.criterion,
    required this.onTap,
    required this.onWeightChanged,
    required this.onDelete,
  });

  final Criterion criterion;
  final VoidCallback onTap;
  final ValueChanged<int> onWeightChanged;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return AppCard(
      onTap: onTap,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (criterion.emoji != null) ...[
                      Text(criterion.emoji!, style: const TextStyle(fontSize: 16)),
                      const SizedBox(width: 6),
                    ],
                    Expanded(
                      child: Text(
                        criterion.name,
                        style: TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w600,
                          color: palette.textStrong,
                        ),
                      ),
                    ),
                    Text(
                      criterionTypeLabel(criterion.type),
                      style: TextStyle(fontSize: 12, color: palette.textMuted),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      '중요도',
                      style: TextStyle(fontSize: 12.5, color: palette.textMuted),
                    ),
                    const Spacer(),
                    // 1~5 중 하나. 세그먼트로 노출해 한 번의 탭으로 바꾸게 한다.
                    for (var weight = 1; weight <= 5; weight++)
                      GestureDetector(
                        onTap: () => onWeightChanged(weight),
                        child: Container(
                          width: 30,
                          height: 30,
                          margin: const EdgeInsets.only(left: 4),
                          decoration: BoxDecoration(
                            color: criterion.weight == weight
                                ? palette.brand
                                : palette.background,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: criterion.weight == weight
                                  ? palette.brand
                                  : palette.border,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '$weight',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: criterion.weight == weight
                                  ? Colors.white
                                  : palette.textMuted,
                            ),
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
