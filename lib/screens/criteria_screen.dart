import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../db/database.dart';
import '../models/models.dart';
import '../text/josa.dart';
import '../theme.dart';
import 'widgets/criterion_editor.dart';
import 'widgets/delete_action.dart';
import 'widgets/toast.dart';

/// Where a set of criteria lives: one project, or the defaults new projects copy.
abstract interface class CriteriaStore {
  Future<List<Criterion>> read();

  Future<int> add(CriterionDraft draft);

  Future<void> save(Criterion criterion);

  /// Saves [edited] and returns how to put [original] back.
  Future<Future<void> Function()> edit(Criterion original, Criterion edited);

  StagedDeletion stageDeletion(int id);
}

class ProjectCriteria implements CriteriaStore {
  const ProjectCriteria(this.projectId);

  final int projectId;

  AppDatabase get _db => AppDatabase.instance;

  @override
  Future<List<Criterion>> read() => _db.readCriteria(projectId);

  @override
  Future<int> add(CriterionDraft draft) => _db.addCriterion(projectId, draft);

  @override
  Future<void> save(Criterion criterion) => _db.updateCriterion(criterion);

  /// Turning a score into yes/no rounds existing scores, so those are kept for undo too.
  @override
  Future<Future<void> Function()> edit(
    Criterion original,
    Criterion edited,
  ) async {
    final toBinary =
        original.type == CriterionType.scale &&
        edited.type == CriterionType.binary;
    final scores = toBinary ? await _db.readScoresOf(original.id) : null;

    if (toBinary) await _db.snapScoresToBinary(original.id);
    await _db.updateCriterion(edited);

    return () async {
      await _db.updateCriterion(original);
      if (scores != null) await _db.restoreScoresOf(original.id, scores);
    };
  }

  @override
  StagedDeletion stageDeletion(int id) => _db.stageCriterionDeletion(id);
}

class DefaultCriteria implements CriteriaStore {
  const DefaultCriteria();

  AppDatabase get _db => AppDatabase.instance;

  @override
  Future<List<Criterion>> read() => _db.readPresets();

  @override
  Future<int> add(CriterionDraft draft) => _db.addPreset(draft);

  @override
  Future<void> save(Criterion criterion) => _db.updatePreset(criterion);

  @override
  Future<Future<void> Function()> edit(
    Criterion original,
    Criterion edited,
  ) async {
    await _db.updatePreset(edited);
    return () => _db.updatePreset(original);
  }

  @override
  StagedDeletion stageDeletion(int id) => _db.stagePresetDeletion(id);
}

/// Building and room criteria with their weights, for a project or for the defaults.
class CriteriaScreen extends StatefulWidget {
  const CriteriaScreen({super.key, required this.title, required this.store});

  final String title;
  final CriteriaStore store;

  @override
  State<CriteriaScreen> createState() => _CriteriaScreenState();
}

class _CriteriaScreenState extends State<CriteriaScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this);
  List<Criterion> _criteria = [];
  bool _loading = true;

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
    final criteria = await widget.store.read();
    if (!mounted) return;
    setState(() {
      _criteria = criteria;
      _loading = false;
    });
  }

  List<Criterion> _of(CriterionScope scope) =>
      _criteria.where((criterion) => criterion.scope == scope).toList();

  Set<String> _namesExcept(int? id) => {
    for (final criterion in _criteria)
      if (criterion.id != id) criterion.name,
  };

  Future<void> _add(CriterionDraft draft) async {
    final id = await widget.store.add(draft);
    if (!mounted) return;
    HapticFeedback.lightImpact();
    await _refresh();
    if (!mounted) return;

    showUndo(
      '‘${draft.name}’${objectJosa(draft.name)} 추가했어요',
      onUndo: () async {
        await widget.store.stageDeletion(id).commit();
        await _refresh();
      },
    );
  }

  Future<void> _edit(Criterion criterion) async {
    final edited = await showCriterionEditSheet(
      context,
      criterion: criterion,
      takenNames: _namesExcept(criterion.id),
    );
    if (edited == null || !mounted) return;

    final undo = await widget.store.edit(criterion, edited);
    if (!mounted) return;
    HapticFeedback.lightImpact();
    await _refresh();
    if (!mounted) return;

    showUndo(
      '‘${edited.name}’${objectJosa(edited.name)} 수정했어요',
      onUndo: () async {
        await undo();
        await _refresh();
      },
    );
  }

  Future<void> _setWeight(Criterion criterion, int weight) async {
    HapticFeedback.selectionClick();
    await widget.store.save(criterion.copyWith(weight: weight));
    await _refresh();
  }

  Future<void> _delete(Criterion criterion) async {
    final deletion = widget.store.stageDeletion(criterion.id);
    await _refresh();
    if (!mounted) return;

    showDeletionUndo(
      '‘${criterion.name}’${objectJosa(criterion.name)} 삭제했어요',
      deletion,
      onUndone: _refresh,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        bottom: TabBar(
          controller: _tabs,
          tabs: [
            Tab(text: '건물 ${_of(CriterionScope.building).length}'),
            Tab(text: '방 ${_of(CriterionScope.room).length}'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabs,
              children: [
                _scopeTab(CriterionScope.building, '같은 건물의 방에 모두 적용돼요'),
                _scopeTab(CriterionScope.room, '방마다 따로 매겨요'),
              ],
            ),
    );
  }

  Widget _scopeTab(CriterionScope scope, String caption) {
    final palette = context.palette;
    final criteria = _of(scope);

    return ListView(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.page,
        14,
        AppSpacing.page,
        24 + MediaQuery.paddingOf(context).bottom,
      ),
      children: [
        Text(caption, style: TextStyle(fontSize: 13, color: palette.textMuted)),
        const SizedBox(height: 14),
        for (final criterion in criteria) ...[
          _CriterionRow(
            criterion: criterion,
            onTap: () => _edit(criterion),
            onWeightChanged: (weight) => _setWeight(criterion, weight),
            onDelete: () => _delete(criterion),
          ),
          const SizedBox(height: 10),
        ],
        const SizedBox(height: 4),
        CriterionComposer(
          scope: scope,
          takenNames: _namesExcept(null),
          onAdd: _add,
        ),
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
                    SizedBox(
                      width: 26,
                      child: Text(
                        criterion.emoji ?? '',
                        style: const TextStyle(fontSize: 17),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        criterion.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w600,
                          color: palette.textStrong,
                        ),
                      ),
                    ),
                    Tooltip(
                      message: criterionTypeLabel(criterion.type),
                      child: Icon(
                        criterionTypeIcon(criterion.type),
                        size: 20,
                        color: palette.textMuted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      '중요도',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: palette.textMuted,
                      ),
                    ),
                    const Spacer(),
                    // Weight 1–5 as segments, so changing it takes one tap.
                    for (var weight = 1; weight <= 5; weight++)
                      GestureDetector(
                        onTap: () => onWeightChanged(weight),
                        child: Container(
                          width: 30,
                          height: 30,
                          margin: const EdgeInsets.only(left: 4),
                          alignment: Alignment.center,
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
