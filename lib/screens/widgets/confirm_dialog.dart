import 'package:flutter/material.dart';

import '../../theme.dart';

/// 되돌릴 수 없는 삭제 앞에서 한 번 물어본다.
///
/// 가벼운 삭제(방 하나)는 실행취소로 처리하고, 하위 데이터까지 날아가는 삭제만
/// 이 확인을 거친다. 앱 곳곳에서 같은 모양이어야 해서 한 곳에 모아뒀다.
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

/// 저장하지 않은 채점을 두고 화면을 벗어나려 할 때.
Future<bool> confirmDiscardChanges(BuildContext context) => confirmDestructive(
  context,
  title: '저장하지 않고 나갈까요?',
  message: '방금 매긴 점수가 사라집니다.',
  confirmLabel: '나가기',
);
