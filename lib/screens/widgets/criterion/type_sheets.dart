import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../models/models.dart';
import '../../../theme.dart';
import 'criterion_sheet.dart';
import 'emoji_picker.dart';

/// Asks how a new criterion is scored. Tapping a type adds it right away.
Future<CriterionType?> showTypeSheet(
  BuildContext context, {
  required String name,
}) => showCriterionSheet(
  context,
  (sheetContext) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          sheetTitle(sheetContext, '‘$name’ 평가 기준을 추가할게요'),
          for (final type in CriterionType.values) ...[
            TypeOption(
              type: type,
              selected: false,
              onTap: () => Navigator.pop(sheetContext, type),
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    ),
  ),
);

/// Edits a criterion's emoji, name, and type. Resolves to the edited criterion, or null.
Future<Criterion?> showCriterionEditSheet(
  BuildContext context, {
  required Criterion criterion,
  required Set<String> takenNames,
}) => showCriterionSheet(
  context,
  (_) => _CriterionEditSheet(criterion: criterion, takenNames: takenNames),
);

class _CriterionEditSheet extends StatefulWidget {
  const _CriterionEditSheet({
    required this.criterion,
    required this.takenNames,
  });

  final Criterion criterion;
  final Set<String> takenNames;

  @override
  State<_CriterionEditSheet> createState() => _CriterionEditSheetState();
}

class _CriterionEditSheetState extends State<_CriterionEditSheet> {
  late final _controller = TextEditingController(text: widget.criterion.name);
  late String? _emoji = widget.criterion.emoji;
  late CriterionType _type = widget.criterion.type;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String get _name => _controller.text.trim();
  bool get _taken => widget.takenNames.contains(_name);

  bool get _changed =>
      _name != widget.criterion.name ||
      _emoji != widget.criterion.emoji ||
      _type != widget.criterion.type;

  Future<void> _pickEmoji() async {
    final picked = await showEmojiPicker(context, current: _emoji);
    if (picked != null) setState(() => _emoji = picked.emoji);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          20 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            sheetTitle(context, '평가 기준 수정'),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                EmojiButton(emoji: _emoji, onTap: _pickEmoji),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: InputDecoration(
                      hintText: '평가 기준 이름',
                      errorText: _taken ? '이미 있어요' : null,
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            for (final type in CriterionType.values) ...[
              TypeOption(
                type: type,
                selected: _type == type,
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _type = type);
                },
              ),
              const SizedBox(height: 8),
            ],
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _name.isNotEmpty && !_taken && _changed
                  ? () => Navigator.pop(
                      context,
                      widget.criterion.copyWith(
                        name: _name,
                        type: _type,
                        emoji: () => _emoji,
                      ),
                    )
                  : null,
              child: const Text('저장'),
            ),
          ],
        ),
      ),
    );
  }
}

/// A scoring type with its icon and a one-line description.
class TypeOption extends StatelessWidget {
  const TypeOption({
    super.key,
    required this.type,
    required this.selected,
    required this.onTap,
  });

  final CriterionType type;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Material(
      color: selected
          ? palette.brand.withValues(alpha: 0.1)
          : palette.background,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? palette.brand : palette.border,
            ),
          ),
          child: Row(
            children: [
              Icon(
                criterionTypeIcon(type),
                size: 22,
                color: selected ? palette.brand : palette.textBody,
              ),
              const SizedBox(width: 12),
              Text(
                criterionTypeLabel(type),
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: palette.textStrong,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  criterionTypeHint(type),
                  style: TextStyle(fontSize: 13, color: palette.textMuted),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
