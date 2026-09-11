import 'package:flutter/material.dart';

import '../../theme.dart';

/// Asks once before a deletion that can't be undone.
///
/// Light deletions (a single room) use undo instead; only deletions that take child data
/// with them go through this. One implementation keeps it identical across the app.
Future<bool> confirmDestructive(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = '삭제',
}) async {
  final palette = context.palette;

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('취소'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          style: FilledButton.styleFrom(
            backgroundColor: palette.danger,
            minimumSize: const Size(88, 44),
          ),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );

  return confirmed ?? false;
}

/// When leaving a screen with unsaved scores.
Future<bool> confirmDiscardChanges(BuildContext context) => confirmDestructive(
  context,
  title: '저장하지 않고 나갈까요?',
  message: '방금 매긴 점수가 사라집니다.',
  confirmLabel: '나가기',
);
