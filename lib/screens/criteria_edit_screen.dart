import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../db/database.dart';
import '../models/models.dart';
import '../theme.dart';
import 'widgets/card_menu.dart';
import 'widgets/confirm_dialog.dart';

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

  Future<void> _add(String name, CriterionScope scope, CriterionType type) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;

    if (_criteria.any((c) => c.name == trimmed)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('‘$trimmed’은(는) 이미 있어요')),
      );
      return;
    }

    await AppDatabase.instance.addCriterion(widget.projectId, trimmed, scope, type, 3);
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
    HapticFeedback.mediumImpact();
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
                  title: '건물 평가 기준',
                  description: '건물마다 한 번만 매깁니다.',
                  criteria: _criteria
                      .where((c) => c.scope == CriterionScope.building)
                      .toList(),
                  onAdd: (name, type) => _add(name, CriterionScope.building, type),
                  onWeightChanged: _changeWeight,
                  onDelete: _delete,
                ),
                const SizedBox(height: 28),
                _ScopeSection(
                  title: '방 평가 기준',
                  description: '방마다 매깁니다.',
                  criteria: _criteria.where((c) => c.scope == CriterionScope.room).toList(),
                  onAdd: (name, type) => _add(name, CriterionScope.room, type),
                  onWeightChanged: _changeWeight,
                  onDelete: _delete,
                ),
              ],
            ),
    );
  }
}

class _ScopeSection extends StatefulWidget {
  const _ScopeSection({
    required this.title,
    required this.description,
    required this.criteria,
    required this.onAdd,
    required this.onWeightChanged,
    required this.onDelete,
  });

  final String title;
  final String description;
  final List<Criterion> criteria;
  final void Function(String name, CriterionType type) onAdd;
  final void Function(Criterion criterion, int weight) onWeightChanged;
  final ValueChanged<Criterion> onDelete;

  @override
  State<_ScopeSection> createState() => _ScopeSectionState();
}

class _ScopeSectionState extends State<_ScopeSection> {
  final _controller = TextEditingController();
  CriterionType _type = CriterionType.scale;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    widget.onAdd(_controller.text, _type);
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.title,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: palette.textStrong,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          widget.description,
          style: TextStyle(fontSize: 13, color: palette.textMuted),
        ),
        const SizedBox(height: 12),
        for (final criterion in widget.criteria) ...[
          _CriterionRow(
            criterion: criterion,
            onWeightChanged: (weight) => widget.onWeightChanged(criterion, weight),
            onDelete: () => widget.onDelete(criterion),
          ),
          const SizedBox(height: 10),
        ],
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(hintText: '기준 추가'),
                onSubmitted: (_) => _submit(),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 52,
              height: 52,
              child: IconButton.filled(
                onPressed: _submit,
                style: IconButton.styleFrom(
                  backgroundColor: palette.brand,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.add),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            for (final type in CriterionType.values)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(type == CriterionType.scale ? '0~10 점수' : '있음/없음'),
                  labelStyle: TextStyle(
                    fontSize: 12.5,
                    color: _type == type ? Colors.white : palette.textMuted,
                  ),
                  selected: _type == type,
                  showCheckmark: false,
                  backgroundColor: palette.surface,
                  selectedColor: palette.brand,
                  side: BorderSide(color: palette.border),
                  onSelected: (_) => setState(() => _type = type),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _CriterionRow extends StatelessWidget {
  const _CriterionRow({
    required this.criterion,
    required this.onWeightChanged,
    required this.onDelete,
  });

  final Criterion criterion;
  final ValueChanged<int> onWeightChanged;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
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
                criterion.type == CriterionType.binary ? '있음/없음' : '0~10',
                style: TextStyle(fontSize: 12, color: palette.textMuted),
              ),
              CardMenu(onDelete: onDelete),
            ],
          ),
          const SizedBox(height: 6),
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
    );
  }
}
