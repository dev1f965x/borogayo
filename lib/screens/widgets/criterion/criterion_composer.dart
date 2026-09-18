import 'package:flutter/material.dart';

import '../../../models/models.dart';
import '../../../theme.dart';
import 'emoji_picker.dart';
import 'type_sheets.dart';

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
