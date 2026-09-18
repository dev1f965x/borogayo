import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../theme.dart';
import 'criterion_sheet.dart';

/// Emoji grid. Resolves to the chosen emoji, `(emoji: null)` for none, or null when dismissed.
Future<({String? emoji})?> showEmojiPicker(
  BuildContext context, {
  String? current,
}) => showCriterionSheet(context, (sheetContext) {
  final palette = sheetContext.palette;

  Widget tile({
    required Widget child,
    required bool selected,
    required String? value,
  }) => GestureDetector(
    onTap: () {
      HapticFeedback.selectionClick();
      Navigator.pop(sheetContext, (emoji: value));
    },
    child: Container(
      width: 44,
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: selected
            ? palette.brand.withValues(alpha: 0.16)
            : palette.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: selected ? palette.brand : palette.border),
      ),
      child: child,
    ),
  );

  return SafeArea(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          sheetTitle(sheetContext, '이모지'),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              tile(
                value: null,
                selected: current == null,
                child: Icon(Icons.block, size: 20, color: palette.textMuted),
              ),
              for (final choice in emojiChoices)
                tile(
                  value: choice,
                  selected: current == choice,
                  child: Text(choice, style: const TextStyle(fontSize: 20)),
                ),
            ],
          ),
        ],
      ),
    ),
  );
});

/// Square button showing the chosen emoji, or a placeholder when there is none.
class EmojiButton extends StatelessWidget {
  const EmojiButton({super.key, required this.emoji, required this.onTap});

  final String? emoji;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Material(
      color: palette.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 52,
          height: 52,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: palette.border),
          ),
          child: emoji == null
              ? Icon(
                  Icons.add_reaction_outlined,
                  size: 22,
                  color: palette.textMuted,
                )
              : Text(emoji!, style: const TextStyle(fontSize: 22)),
        ),
      ),
    );
  }
}
