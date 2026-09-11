import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../theme.dart';
import 'delete_action.dart';
import 'rank_badge.dart';

/// Card for one room, used in both the project ranking and a building's room list.
///
/// Ranks appear only in the project ranking. Numbering rooms inside a building too would put
/// "#1 in this building" and "#3 overall" on the same room.
class RoomCard extends StatelessWidget {
  const RoomCard({
    super.key,
    required this.entry,
    required this.onTap,
    required this.onDelete,
    this.rank,
    this.showRank = false,
    this.showBuilding = false,
  });

  final RoomScore entry;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  /// Only scored rooms have a rank; null draws a placeholder dot.
  final int? rank;
  final bool showRank;

  /// In lists that span buildings, show which building the room is in.
  final bool showBuilding;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final room = entry.room;
    final medal = showRank ? medalColor(rank) : null;
    final done = entry.roomScoringDone;

    return AppCard(
      onTap: onTap,
      borderColor: medal,
      child: Row(
        children: [
          if (showRank) ...[RankBadge(rank: rank), const SizedBox(width: 12)],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (showBuilding) ...[
                  Text(
                    entry.building.name,
                    style: TextStyle(fontSize: 12.5, color: palette.textMuted),
                  ),
                  const SizedBox(height: 2),
                ],
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        room.name,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: palette.textStrong,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (entry.hasScore) ...[
                      Text(
                        '${entry.percent!.round()}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: medal ?? palette.done,
                        ),
                      ),
                      Text(
                        '점',
                        style: TextStyle(
                          fontSize: 12,
                          color: palette.textMuted,
                        ),
                      ),
                    ] else
                      Text(
                        '—',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: palette.textMuted,
                        ),
                      ),
                  ],
                ),
                if (room.memo != null && room.memo!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    room.memo!,
                    style: TextStyle(fontSize: 13.5, color: palette.textMuted),
                  ),
                ],
                const SizedBox(height: 12),
                ProgressBar(
                  value: entry.criterionCount == 0
                      ? 0
                      : entry.scoredCount / entry.criterionCount,
                  color: done ? palette.done : palette.brand,
                ),
                const SizedBox(height: 8),
                Text(
                  // Fully scored room but still `—`: the building is missing ratings, so say so.
                  entry.blockedByBuilding
                      ? '건물 평가를 마치면 점수가 나와요'
                      : done
                      ? '${entry.criterionCount}개 기준 모두 채점'
                      : '${entry.criterionCount}개 중 ${entry.scoredCount}개 채점',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: entry.blockedByBuilding
                        ? palette.brand
                        : palette.textMuted,
                  ),
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
