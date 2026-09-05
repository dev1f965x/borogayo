import 'package:flutter/material.dart';

import '../../theme.dart';

/// 카드 오른쪽 위의 `⋯` 메뉴.
///
/// 카드마다 삭제 아이콘을 그대로 노출하면 목록이 지저분해지고 잘못 누르기도 쉬워서,
/// 한 단계 안으로 넣었다.
class CardMenu extends StatelessWidget {
  const CardMenu({super.key, required this.onDelete});

  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return SizedBox(
      width: 32,
      height: 32,
      child: PopupMenuButton<String>(
        padding: EdgeInsets.zero,
        icon: Icon(Icons.more_horiz, size: 20, color: palette.textMuted),
        onSelected: (_) => onDelete(),
        itemBuilder: (context) => [
          PopupMenuItem(
            value: 'delete',
            child: Text('삭제', style: TextStyle(color: palette.danger)),
          ),
        ],
      ),
    );
  }
}
