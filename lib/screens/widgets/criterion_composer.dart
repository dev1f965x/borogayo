import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../db/database.dart';
import '../../models/models.dart';
import '../../theme.dart';

/// Emoji choices, trimmed to ones that fit house hunting and fit on one screen.
const _emojiChoices = <String>[
  '🚇',
  '🚌',
  '🚗',
  '🅿️',
  '🛗',
  '🏪',
  '🏫',
  '🏥',
  '🌳',
  '🏞️',
  '🧹',
  '🔒',
  '📦',
  '🧺',
  '☀️',
  '🌙',
  '🔊',
  '🤫',
  '🚿',
  '🚽',
  '💧',
  '🧊',
  '🔥',
  '🪟',
  '🚪',
  '🛏️',
  '🛋️',
  '🍳',
  '📐',
  '💰',
  '📶',
  '🐕',
];

/// Emoji preselected for obvious names, so picking one isn't a chore nobody bothers with.
const _emojiHints = <String, String>{
  '교통': '🚇',
  '지하철': '🚇',
  '버스': '🚌',
  '주차': '🅿️',
  '엘리베이터': '🛗',
  '편의': '🏪',
  '관리': '🧹',
  '보안': '🔒',
  '채광': '☀️',
  '햇': '☀️',
  '소음': '🔊',
  '수압': '🚿',
  '곰팡이': '💧',
  '결로': '💧',
  '단열': '🧊',
  '난방': '🔥',
  '창': '🪟',
  '현관': '🚪',
  '옵션': '🛋️',
  '주방': '🍳',
  '크기': '📐',
  '평': '📐',
  '가격': '💰',
  '월세': '💰',
  '보증금': '💰',
  '인터넷': '📶',
  '반려': '🐕',
};

String? suggestEmoji(String name) {
  for (final entry in _emojiHints.entries) {
    if (name.contains(entry.key)) return entry.value;
  }
  return null;
}

/// Input row for a criterion name; type and emoji are chosen next in [showCriterionSheet].
///
/// A type picker next to the field would ask for a choice before there's even a name.
/// Name, add, then type follows the order people actually think in.
class CriterionComposer extends StatefulWidget {
  const CriterionComposer({
    super.key,
    required this.scope,
    required this.onAdd,
  });

  final CriterionScope scope;

  /// Called after the type is chosen in the sheet.
  final void Function(CriterionDraft draft) onAdd;

  @override
  State<CriterionComposer> createState() => _CriterionComposerState();
}

class _CriterionComposerState extends State<CriterionComposer> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _controller.text.trim();
    if (name.isEmpty) return;

    final picked = await showCriterionSheet(
      context,
      name: name,
      scope: widget.scope,
    );
    if (picked == null || !mounted) return;

    _controller.clear();
    widget.onAdd(picked);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _controller,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(hintText: '기준 직접 추가'),
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
    );
  }
}

/// Bottom sheet for choosing type and emoji. Returns null when cancelled.
///
/// Creating and editing need the same choices, so they share this sheet;
/// editing prefills [initialType] and [initialEmoji].
Future<CriterionDraft?> showCriterionSheet(
  BuildContext context, {
  required String name,
  required CriterionScope scope,
  CriterionType? initialType,
  String? initialEmoji,
  String confirmLabel = '추가',
}) {
  final palette = context.palette;

  var type = initialType ?? CriterionType.scale;
  var emoji = initialEmoji ?? (initialType == null ? suggestEmoji(name) : null);

  return showModalBottomSheet<CriterionDraft>(
    context: context,
    backgroundColor: palette.surface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) => StatefulBuilder(
      builder: (sheetContext, setSheetState) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '‘$name’을(를) 어떻게 볼까요?',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: palette.textStrong,
                ),
              ),
              const SizedBox(height: 16),
              for (final option in CriterionType.values) ...[
                _TypeOption(
                  type: option,
                  selected: type == option,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setSheetState(() => type = option);
                  },
                ),
                const SizedBox(height: 8),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Text(
                    '이모지',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: palette.textMuted,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '선택',
                    style: TextStyle(fontSize: 12, color: palette.textMuted),
                  ),
                  const Spacer(),
                  if (emoji != null)
                    TextButton(
                      onPressed: () => setSheetState(() => emoji = null),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        minimumSize: const Size(0, 32),
                      ),
                      child: const Text(
                        '안 쓸래요',
                        style: TextStyle(fontSize: 12.5),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final choice in _emojiChoices)
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setSheetState(() => emoji = choice);
                      },
                      child: Container(
                        width: 40,
                        height: 40,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: emoji == choice
                              ? palette.brand.withValues(alpha: 0.16)
                              : palette.background,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: emoji == choice
                                ? palette.brand
                                : palette.border,
                          ),
                        ),
                        child: Text(
                          choice,
                          style: const TextStyle(fontSize: 19),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () => Navigator.pop(sheetContext, (
                  name: name,
                  scope: scope,
                  type: type,
                  emoji: emoji,
                )),
                child: Text(confirmLabel),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _TypeOption extends StatelessWidget {
  const _TypeOption({
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

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected
              ? palette.brand.withValues(alpha: 0.1)
              : palette.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? palette.brand : palette.border),
        ),
        child: Row(
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              size: 20,
              color: selected ? palette.brand : palette.textMuted,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    criterionTypeLabel(type),
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: palette.textStrong,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    criterionTypeHint(type),
                    style: TextStyle(
                      fontSize: 12.5,
                      color: palette.textMuted,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
