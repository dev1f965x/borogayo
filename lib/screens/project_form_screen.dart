import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../db/database.dart';
import '../models/models.dart';
import '../theme.dart';

/// 집 볼 때 흔히 확인하는 것들. 빈 화면에서 시작하지 않도록 미리 채워둔다.
///
/// 건물 항목은 같은 건물의 방 여러 개를 봐도 한 번만 매기면 되는 것들이고,
/// 방 항목은 방마다 달라지는 것들이다.
const _presets = <CriterionDraft>[
  (name: '교통', scope: CriterionScope.building, type: CriterionType.scale),
  (name: '주변 편의시설', scope: CriterionScope.building, type: CriterionType.scale),
  (name: '건물 관리 상태', scope: CriterionScope.building, type: CriterionType.scale),
  (name: '주차 가능', scope: CriterionScope.building, type: CriterionType.binary),
  (name: '엘리베이터', scope: CriterionScope.building, type: CriterionType.binary),
  (name: '채광', scope: CriterionScope.room, type: CriterionType.scale),
  (name: '소음', scope: CriterionScope.room, type: CriterionType.scale),
  (name: '수압', scope: CriterionScope.room, type: CriterionType.scale),
  (name: '곰팡이·결로', scope: CriterionScope.room, type: CriterionType.scale),
  (name: '방 크기', scope: CriterionScope.room, type: CriterionType.scale),
  (name: '가격', scope: CriterionScope.room, type: CriterionType.scale),
  (name: '풀옵션', scope: CriterionScope.room, type: CriterionType.binary),
];

/// 새 목록 만들기. 이름과 평가 기준을 함께 정한다.
class ProjectFormScreen extends StatefulWidget {
  const ProjectFormScreen({super.key});

  @override
  State<ProjectFormScreen> createState() => _ProjectFormScreenState();
}

class _ProjectFormScreenState extends State<ProjectFormScreen> {
  final _nameController = TextEditingController();
  final _criteria = <CriterionDraft>[..._presets];
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _add(String name, CriterionScope scope, CriterionType type) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;

    if (_criteria.any((c) => c.name == trimmed)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('‘$trimmed’은(는) 이미 있어요')),
      );
      return;
    }

    HapticFeedback.lightImpact();
    setState(() => _criteria.add((name: trimmed, scope: scope, type: type)));
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty || _criteria.isEmpty || _saving) return;

    setState(() => _saving = true);
    await AppDatabase.instance.createProject(name, _criteria);
    if (!mounted) return;
    HapticFeedback.mediumImpact();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final canSave = _nameController.text.trim().isNotEmpty && _criteria.isNotEmpty;

    return Scaffold(
      appBar: AppBar(),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.page, 8, AppSpacing.page, 24),
        children: [
          const ScreenTitle(
            title: '새 목록',
            subtitle: '이사 한 번에 목록 하나. 무엇을 볼지 먼저 정해요.',
          ),
          const SizedBox(height: 28),
          Text(
            '목록 이름',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: palette.textStrong,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _nameController,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(hintText: '예: 2026 봄 이사'),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 28),
          _CriteriaSection(
            scope: CriterionScope.building,
            title: '건물 평가 기준',
            description: '같은 건물이면 방이 달라도 똑같은 항목. 건물마다 한 번만 매깁니다.',
            criteria: _criteria.where((c) => c.scope == CriterionScope.building).toList(),
            onAdd: (name, type) => _add(name, CriterionScope.building, type),
            onRemove: (draft) => setState(() => _criteria.remove(draft)),
          ),
          const SizedBox(height: 28),
          _CriteriaSection(
            scope: CriterionScope.room,
            title: '방 평가 기준',
            description: '같은 건물 안에서도 방마다 달라지는 항목.',
            criteria: _criteria.where((c) => c.scope == CriterionScope.room).toList(),
            onAdd: (name, type) => _add(name, CriterionScope.room, type),
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
              onPressed: canSave && !_saving ? _save : null,
              child: const Text('만들기'),
            ),
          ),
        ),
      ),
    );
  }
}

class _CriteriaSection extends StatefulWidget {
  const _CriteriaSection({
    required this.scope,
    required this.title,
    required this.description,
    required this.criteria,
    required this.onAdd,
    required this.onRemove,
  });

  final CriterionScope scope;
  final String title;
  final String description;
  final List<CriterionDraft> criteria;
  final void Function(String name, CriterionType type) onAdd;
  final ValueChanged<CriterionDraft> onRemove;

  @override
  State<_CriteriaSection> createState() => _CriteriaSectionState();
}

class _CriteriaSectionState extends State<_CriteriaSection> {
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
        const SizedBox(height: 6),
        Text(
          widget.description,
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
          child: widget.criteria.isEmpty
              ? Text(
                  '항목을 하나 이상 추가해주세요.',
                  style: TextStyle(fontSize: 13.5, color: palette.textMuted),
                )
              : Wrap(
                  spacing: 8,
                  runSpacing: 2,
                  children: [
                    for (final draft in widget.criteria)
                      InputChip(
                        label: Text(
                          draft.type == CriterionType.binary
                              ? '${draft.name} · 있음/없음'
                              : draft.name,
                        ),
                        labelStyle: TextStyle(fontSize: 13.5, color: palette.textBody),
                        backgroundColor: palette.background,
                        side: BorderSide(color: palette.border),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(99),
                        ),
                        deleteIcon: const Icon(Icons.close, size: 16),
                        deleteIconColor: palette.textMuted,
                        onDeleted: () {
                          HapticFeedback.selectionClick();
                          widget.onRemove(draft);
                        },
                      ),
                  ],
                ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(hintText: '항목 직접 추가'),
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
        // 새로 추가할 항목을 점수(0~10)로 매길지, 있음/없음으로 매길지.
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
