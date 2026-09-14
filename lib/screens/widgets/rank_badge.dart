import 'package:flutter/material.dart';

import '../../theme.dart';

/// Medal color for ranks 1–3, otherwise null.
Color? medalColor(int? rank) =>
    rank != null && rank >= 1 && rank <= kMedalColors.length
    ? kMedalColors[rank - 1]
    : null;

/// Rank circle on the left of a list card.
///
/// The top three get medal colors, the rest a number. Pass a null [rank] when ranking
/// isn't meaningful yet to draw a placeholder dot.
class RankBadge extends StatelessWidget {
  const RankBadge({super.key, required this.rank});

  static const _size = 30.0;

  final int? rank;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final medal = medalColor(rank);

    if (rank == null) {
      return SizedBox(
        width: _size,
        height: _size,
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
      width: _size,
      height: _size,
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
