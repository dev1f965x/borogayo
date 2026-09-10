import 'package:flutter/material.dart';

import '../../theme.dart';

/// 1~3위에만 쓰는 메달 색. 그 밖에는 null.
Color? medalColor(int? rank) =>
    rank != null && rank >= 1 && rank <= kMedalColors.length
    ? kMedalColors[rank - 1]
    : null;

/// 목록 카드 왼쪽에 붙는 등수 동그라미.
///
/// 상위 세 곳은 색으로, 나머지는 숫자만. 아직 아무 점수도 없어 순위가 의미 없을 때는
/// [rank]에 null을 넘기면 자리만 지키는 점으로 그린다.
class RankBadge extends StatelessWidget {
  const RankBadge({super.key, required this.rank, this.size = 30});

  final int? rank;
  final double size;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final medal = medalColor(rank);

    if (rank == null) {
      return SizedBox(
        width: size,
        height: size,
        child: Center(
          child: Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: palette.border,
              shape: BoxShape.circle,
            ),
          ),
        ),
      );
    }

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: medal ?? palette.background,
        shape: BoxShape.circle,
        border: medal == null ? Border.all(color: palette.border) : null,
      ),
      child: Text(
        '$rank',
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w800,
          color: medal != null ? Colors.white : palette.textMuted,
        ),
      ),
    );
  }
}
