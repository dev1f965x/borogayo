import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../db/database.dart';
import '../models/models.dart';
import '../theme.dart';
import 'widgets/criterion_composer.dart';

/// Common things to check when viewing a place, so a new project doesn't start empty.
///
/// Building criteria are rated once for all rooms in a building; room criteria differ per room.
const _presets = <CriterionDraft>[
  (
    name: '교통',
    scope: CriterionScope.building,
    type: CriterionType.scale,
    emoji: '🚇',
  ),
  (
    name: '주변 편의시설',
    scope: CriterionScope.building,
    type: CriterionType.scale,
    emoji: '🏪',
  ),
  (
    name: '건물 관리 상태',
    scope: CriterionScope.building,
    type: CriterionType.scale,
    emoji: '🧹',
  ),
  (
    name: '주차 가능',
    scope: CriterionScope.building,
    type: CriterionType.binary,
    emoji: '🅿️',
  ),
  (
    name: '엘리베이터',
    scope: CriterionScope.building,
    type: CriterionType.binary,
    emoji: '🛗',
  ),
  (
    name: '채광',
    scope: CriterionScope.room,
    type: CriterionType.scale,
    emoji: '☀️',
  ),
  (
    name: '소음',
    scope: CriterionScope.room,
    type: CriterionType.scale,
    emoji: '🔊',
  ),
  (
    name: '수압',
    scope: CriterionScope.room,
    type: CriterionType.scale,
    emoji: '🚿',
  ),
  (
    name: '곰팡이·결로',
    scope: CriterionScope.room,
    type: CriterionType.scale,
    emoji: '💧',
  ),
  (
    name: '방 크기',
    scope: CriterionScope.room,
    type: CriterionType.scale,
    emoji: '📐',
  ),
  (
    name: '가격',
    scope: CriterionScope.room,
    type: CriterionType.scale,
    emoji: '💰',
  ),
  (
    name: '풀옵션',
    scope: CriterionScope.room,
    type: CriterionType.binary,
    emoji: '🛋️',
  ),
];

/// Sets up a new project's criteria. The name was already entered in the preceding dialog.
///
/// Building and room criteria are separate tabs; one long list makes it hard to tell
/// which section you're in.
class ProjectFormScreen extends StatefulWidget {
  const ProjectFormScreen({super.key, required this.name});

  final String name;

  @override
  State<ProjectFormScreen> createState() => _ProjectFormScreenState();
}

class _ProjectFormScreenState extends State<ProjectFormScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this);
  final _criteria = <CriterionDraft>[..._presets];

  bool _saving = false;

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  List<CriterionDraft> _of(CriterionScope scope) =>
      _criteria.where((c) => c.scope == scope).toList();

  void _add(CriterionDraft draft) {
    if (_criteria.any((c) => c.name == draft.name)) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('‘${draft.name}’은(는) 이미 있어요')));
      return;
    }

    HapticFeedback.lightImpact();
    setState(() => _criteria.add(draft));
  }

  Future<void> _save() async {
    if (_criteria.isEmpty || _saving) return;

    setState(() => _saving = true);
    await AppDatabase.instance.createProject(widget.name, _criteria);
    if (!mounted) return;
    HapticFeedback.mediumImpact();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.name),
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
            Tab(text: '건물 기준 ${_of(CriterionScope.building).length}'),
            Tab(text: '방 기준 ${_of(CriterionScope.room).length}'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _CriteriaTab(
            scope: CriterionScope.building,
            description: '같은 건물이면 방이 달라도 똑같은 항목.\n건물마다 한 번만 매깁니다.',
            criteria: _of(CriterionScope.building),
            onAdd: _add,
            onRemove: (draft) => setState(() => _criteria.remove(draft)),
          ),
          _CriteriaTab(
            scope: CriterionScope.room,
            description: '같은 건물 안에서도 방마다 달라지는 항목.',
            criteria: _of(CriterionScope.room),
            onAdd: _add,
            onRemove: (draft) => setState(() => _criteria.remove(draft)),
          ),
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
              onPressed: _criteria.isNotEmpty && !_saving ? _save : null,
              child: const Text('만들기'),
            ),
          ),
        ),
      ),
    );
  }
}

class _CriteriaTab extends StatelessWidget {
  const _CriteriaTab({
    required this.scope,
    required this.description,
    required this.criteria,
    required this.onAdd,
    required this.onRemove,
  });

  final CriterionScope scope;
  final String description;
  final List<CriterionDraft> criteria;
  final void Function(CriterionDraft draft) onAdd;
  final ValueChanged<CriterionDraft> onRemove;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.page,
        16,
        AppSpacing.page,
        24,
      ),
      children: [
        Text(
          description,
          style: TextStyle(fontSize: 13, color: palette.textMuted, height: 1.4),
        ),
        const SizedBox(height: 14),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
            border: Border.all(color: palette.border),
          ),
          child: criteria.isEmpty
              ? Text(
                  '항목을 하나 이상 추가해주세요.',
                  style: TextStyle(fontSize: 13.5, color: palette.textMuted),
                )
              : Wrap(
                  spacing: 8,
                  runSpacing: 2,
                  children: [
                    for (final draft in criteria)
                      InputChip(
                        label: Text(
                          [
                            ?draft.emoji,
                            draft.name,
                            if (draft.type == CriterionType.binary) '· 여부형',
                          ].join(' '),
                        ),
                        labelStyle: TextStyle(
                          fontSize: 13.5,
                          color: palette.textBody,
                        ),
                        backgroundColor: palette.background,
                        side: BorderSide(color: palette.border),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(99),
                        ),
                        deleteIcon: const Icon(Icons.close, size: 16),
                        deleteIconColor: palette.textMuted,
                        onDeleted: () {
                          HapticFeedback.selectionClick();
                          onRemove(draft);
                        },
                      ),
                  ],
                ),
        ),
        const SizedBox(height: 10),
        CriterionComposer(scope: scope, onAdd: onAdd),
      ],
    );
  }
}
