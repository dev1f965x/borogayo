import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../theme.dart';
import 'delete_action.dart';
import 'rank_badge.dart';

/// Card for one room in the ranked list. Its building is shown by the section header above.
class RoomCard extends StatelessWidget {
  const RoomCard({
    super.key,
    required this.entry,
    required this.rank,
    required this.onTap,
    required this.onDelete,
  });

  final RoomScore entry;

  /// Only scored rooms have a rank; null draws a placeholder dot.
  final int? rank;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final room = entry.room;
    final medal = medalColor(rank);
    final memo = room.memo;

    return AppCard(
      onTap: onTap,
      borderColor: medal,
      child: Row(
        children: [
          RankBadge(rank: rank),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        room.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: palette.textStrong,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      entry.hasScore ? '${entry.percent!.round()}' : '—',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: entry.hasScore
                            ? medal ?? palette.done
                            : palette.textMuted,
                      ),
                    ),
                    if (entry.hasScore)
                      Text(
                        '점',
                        style: TextStyle(
                          fontSize: 12,
                          color: palette.textMuted,
                        ),
                      ),
                  ],
                ),
                if (memo != null && memo.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    memo,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13.5, color: palette.textMuted),
                  ),
                ],
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: ProgressBar(
                        value: entry.criterionCount == 0
                            ? 0
                            : entry.scoredCount / entry.criterionCount,
                        color: entry.scoringDone ? palette.done : palette.brand,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '${entry.scoredCount}/${entry.criterionCount}',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: entry.scoringDone
                            ? palette.done
                            : palette.textMuted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          DeleteAction(onConfirm: onDelete),
        ],
      ),
    );
  }
}
