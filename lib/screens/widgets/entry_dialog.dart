import 'package:flutter/material.dart';

/// 다이얼로그가 돌려주는 값. 메모는 선택이라 비면 null.
typedef EntryResult = ({String name, String? memo});

/// 이름이 쓸 수 있는지 확인한다. 문제가 있으면 사용자에게 보여줄 문구를, 없으면 null.
typedef NameCheck = Future<String?> Function(String name);

/// 목록·건물·방처럼 이름을 받아 무언가를 만들기 시작할 때 쓰는 다이얼로그.
///
/// 컨트롤러를 다이얼로그 자신의 State가 들고 있는 게 핵심이다. 바깥에서 만들어
/// `showDialog`가 끝나자마자 dispose하면, 닫히는 애니메이션이 도는 동안 아직 살아있는
/// TextField가 죽은 컨트롤러를 읽어서 빨간 에러 화면이 번쩍인다.
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

  /// 고칠 때 채워 넣을 값. 새로 만들 때는 비어 있다.
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
            decoration: InputDecoration(hintText: widget.nameHint, errorText: _error),
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
