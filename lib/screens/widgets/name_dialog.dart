import 'package:flutter/material.dart';

/// Checks a name, returning a message for the user or null when it can be used.
typedef NameCheck = Future<String?> Function(String name);

/// Dialog that asks for a name. Returns the trimmed name, or null when cancelled.
///
/// The dialog's own State owns the controller. A controller created outside and disposed
/// as soon as `showDialog` returns would still be read by the TextField during the closing
/// animation, flashing the red error screen.
class NameDialog extends StatefulWidget {
  const NameDialog({
    super.key,
    required this.title,
    required this.hint,
    required this.confirmLabel,
    required this.check,
  });

  final String title;
  final String hint;
  final String confirmLabel;
  final NameCheck check;

  @override
  State<NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<NameDialog> {
  final _controller = TextEditingController();
  String? _error;
  bool _checking = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_checking) return;

    final name = _controller.text.trim();
    if (name.isEmpty) {
      setState(() => _error = '이름을 입력해 주세요');
      return;
    }

    setState(() => _checking = true);
    final problem = await widget.check(name);
    if (!mounted) return;
    if (problem != null) {
      setState(() {
        _error = problem;
        _checking = false;
      });
      return;
    }
    Navigator.pop(context, name);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textInputAction: TextInputAction.done,
        decoration: InputDecoration(hintText: widget.hint, errorText: _error),
        onChanged: (_) {
          if (_error != null) setState(() => _error = null);
        },
        onSubmitted: (_) => _submit(),
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
