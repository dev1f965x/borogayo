import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/models.dart';
import '../../theme.dart';

/// Emoji choices, trimmed to ones that fit house hunting and fit on one screen.
const _emojiChoices = <String>[
  '🚇', '🚌', '🚗', '🅿️', '🛗', '🏪', '🏫', '🏥', //
  '🌳', '🏞️', '🧹', '🔒', '📦', '🧺', '☀️', '🌙',
  '🔊', '🤫', '🚿', '🚽', '💧', '🧊', '🔥', '🪟',
  '🚪', '🛏️', '🛋️', '🍳', '📐', '💰', '📶', '🐕',
];

IconData criterionTypeIcon(CriterionType type) => type == CriterionType.scale
    ? Icons.linear_scale_rounded
    : Icons.toggle_on_outlined;

Future<T?> _showSheet<T>(BuildContext context, WidgetBuilder builder) =>
    showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      builder: builder,
    );

Widget _sheetTitle(BuildContext context, String text) => Padding(
  padding: const EdgeInsets.only(bottom: 16),
  child: Text(
    text,
    style: TextStyle(
      fontSize: 17,
      fontWeight: FontWeight.w700,
      color: context.palette.textStrong,
    ),
  ),
);

/// Emoji grid. Resolves to the chosen emoji, `(emoji: null)` for none, or null when dismissed.
Future<({String? emoji})?> showEmojiPicker(
  BuildContext context, {
  String? current,
}) => _showSheet(context, (sheetContext) {
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
          _sheetTitle(sheetContext, '이모지'),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              tile(
                value: null,
                selected: current == null,
                child: Icon(Icons.block, size: 20, color: palette.textMuted),
              ),
              for (final choice in _emojiChoices)
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

/// Input row for a new criterion: emoji, name, add. The type is chosen right after.
class CriterionComposer extends StatefulWidget {
  const CriterionComposer({
    super.key,
    required this.scope,
    required this.takenNames,
    required this.onAdd,
  });

  final CriterionScope scope;
  final Set<String> takenNames;
  final ValueChanged<CriterionDraft> onAdd;

  @override
  State<CriterionComposer> createState() => _CriterionComposerState();
}

class _CriterionComposerState extends State<CriterionComposer> {
  final _controller = TextEditingController();
  String? _emoji;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String get _name => _controller.text.trim();
  bool get _taken => widget.takenNames.contains(_name);
  bool get _ready => _name.isNotEmpty && !_taken;

  Future<void> _pickEmoji() async {
    final picked = await showEmojiPicker(context, current: _emoji);
    if (picked != null) setState(() => _emoji = picked.emoji);
  }

  Future<void> _submit() async {
    if (!_ready) return;
    final name = _name;
    final type = await showTypeSheet(context, name: name);
    if (type == null || !mounted) return;

    widget.onAdd((name: name, scope: widget.scope, type: type, emoji: _emoji));
    _controller.clear();
    setState(() => _emoji = null);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        EmojiButton(emoji: _emoji, onTap: _pickEmoji),
        const SizedBox(width: 8),
        Expanded(
          child: TextField(
            controller: _controller,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              hintText: '평가 기준 이름',
              errorText: _taken ? '이미 있어요' : null,
            ),
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _submit(),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 52,
          height: 52,
          child: IconButton.filled(
            onPressed: _ready ? _submit : null,
            style: IconButton.styleFrom(
              backgroundColor: palette.brand,
              foregroundColor: Colors.white,
              disabledBackgroundColor: palette.border,
              disabledForegroundColor: palette.textMuted,
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

/// Asks how a new criterion is scored. Tapping a type adds it right away.
Future<CriterionType?> showTypeSheet(
  BuildContext context, {
  required String name,
}) => _showSheet(
  context,
  (sheetContext) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sheetTitle(sheetContext, '‘$name’ 평가 기준을 추가할게요'),
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
}) => _showSheet(
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
            _sheetTitle(context, '평가 기준 수정'),
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
