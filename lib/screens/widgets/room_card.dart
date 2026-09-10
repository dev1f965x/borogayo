import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../theme.dart';
import 'delete_action.dart';
import 'rank_badge.dart';

/// 방 한 칸을 보여주는 카드. 프로젝트 순위와 건물 안 방 목록이 같은 카드를 쓴다.
///
/// 등수는 프로젝트 순위에서만 붙인다. 건물 안에서도 번호를 매기면 "이 건물 1위"와
/// "전체 3위"라는 두 숫자가 같은 방에 붙어서 어느 쪽이 진짜인지 헷갈린다.
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

  /// 점수가 나온 방만 등수를 받는다. null이면 자리만 지키는 점으로 그려진다.
  final int? rank;
  final bool showRank;

  /// 건물을 가로질러 세운 목록에서는 어느 건물의 방인지 함께 보여준다.
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
          if (showRank) ...[
            RankBadge(rank: rank),
            const SizedBox(width: 12),
          ],
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
                        style: TextStyle(fontSize: 12, color: palette.textMuted),
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
                  // 방을 다 매겼는데도 점수가 `—`면 이유가 건물 쪽이다. 그 말을 여기서 해준다.
                  entry.blockedByBuilding
                      ? '건물 평가를 마치면 점수가 나와요'
                      : done
                      ? '${entry.criterionCount}개 기준 모두 채점'
                      : '${entry.criterionCount}개 중 ${entry.scoredCount}개 채점',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: entry.blockedByBuilding ? palette.brand : palette.textMuted,
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
