import 'package:flutter/material.dart';

import 'toast.dart';

/// A name that turns into a text field when tapped, to rename it in place.
///
/// [onRename] saves the new name and returns null, or returns a message when the name
/// can't be used; the name then stays as it was.
class InlineName extends StatefulWidget {
  const InlineName({
    super.key,
    required this.name,
    required this.onRename,
    required this.style,
  });

  final String name;
  final Future<String?> Function(String name) onRename;
  final TextStyle style;

  @override
  State<InlineName> createState() => _InlineNameState();
}

class _InlineNameState extends State<InlineName> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  bool _editing = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (!_focus.hasFocus) _finish();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _start() {
    _controller
      ..text = widget.name
      ..selection = TextSelection(
        baseOffset: 0,
        extentOffset: widget.name.length,
      );
    setState(() => _editing = true);
    _focus.requestFocus();
  }

  Future<void> _finish() async {
    if (!_editing) return;
    setState(() => _editing = false);

    final name = _controller.text.trim();
    if (name.isEmpty || name == widget.name) return;

    final problem = await widget.onRename(name);
    if (problem == null || !mounted) return;
    showToast(problem);
  }

  @override
  Widget build(BuildContext context) {
    if (_editing) {
      return TextField(
        controller: _controller,
        focusNode: _focus,
        style: widget.style,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _focus.unfocus(),
        decoration: const InputDecoration(
          isDense: true,
          filled: false,
          contentPadding: EdgeInsets.symmetric(vertical: 4),
          border: UnderlineInputBorder(),
          enabledBorder: UnderlineInputBorder(),
        ),
      );
    }

    return GestureDetector(
      onTap: _start,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Text(
          widget.name,
          style: widget.style,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}
