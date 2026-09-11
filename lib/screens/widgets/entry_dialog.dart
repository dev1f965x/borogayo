import 'package:flutter/material.dart';

/// Dialog result. The memo is optional and null when empty.
typedef EntryResult = ({String name, String? memo});

/// Validates a name, returning a message for the user or null when it's fine.
typedef NameCheck = Future<String?> Function(String name);

/// Dialog that asks for a name to create or rename a project, building, or room.
///
/// The dialog's own State owns the controllers. Controllers created outside and disposed
/// as soon as `showDialog` returns would still be read by the TextField during the closing
/// animation, flashing the red error screen.
class EntryDialog extends StatefulWidget {
  const EntryDialog({
    super.key,
    required this.title,
    required this.nameHint,
    required this.nameCheck,
    this.memoHint,
    this.confirmLabel = '추가',
    this.initialName,
    this.initialMemo,
  });

  final String title;
  final String nameHint;
  final String? memoHint;
  final String confirmLabel;
  final NameCheck nameCheck;

  /// Prefilled when editing; empty when creating.
  final String? initialName;
  final String? initialMemo;

  @override
  State<EntryDialog> createState() => _EntryDialogState();
}

class _EntryDialogState extends State<EntryDialog> {
  late final _nameController = TextEditingController(text: widget.initialName);
  late final _memoController = TextEditingController(text: widget.initialMemo);

  String? _error;
  bool _checking = false;

  @override
  void dispose() {
    _nameController.dispose();
    _memoController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_checking) return;

    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = '이름을 입력해주세요.');
      return;
    }

    setState(() => _checking = true);
    final problem = await widget.nameCheck(name);
    if (!mounted) return;

    if (problem != null) {
      setState(() {
        _error = problem;
        _checking = false;
      });
      return;
    }

    final memo = _memoController.text.trim();
    Navigator.pop(context, (name: name, memo: memo.isEmpty ? null : memo));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameController,
            autofocus: true,
            textInputAction: widget.memoHint == null
                ? TextInputAction.done
                : TextInputAction.next,
            decoration: InputDecoration(
              hintText: widget.nameHint,
              errorText: _error,
            ),
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
            onSubmitted: widget.memoHint == null ? (_) => _submit() : null,
          ),
          if (widget.memoHint != null) ...[
            const SizedBox(height: 10),
            TextField(
              controller: _memoController,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(hintText: widget.memoHint),
              onSubmitted: (_) => _submit(),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('취소'),
        ),
        FilledButton(
          onPressed: _checking ? null : _submit,
          style: FilledButton.styleFrom(minimumSize: const Size(88, 44)),
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}
