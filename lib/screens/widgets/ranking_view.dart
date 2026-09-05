import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../theme.dart';

/// 순위 카드들. 프로젝트 상세의 '순위' 탭 본문.
class RankingView extends StatelessWidget {
  const RankingView({super.key, required this.ranking, required this.onOpenRoom});

  final List<RankedRoom> ranking;
  final void Function(RankedRoom entry) onOpenRoom;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final scored = ranking.where((entry) => entry.hasAnyScore).toList();

    if (scored.isEmpty) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.page, 8, AppSpacing.page, 120),
        children: const [
          EmptyState(
            icon: Icons.emoji_events_outlined,
            title: '아직 순위를 낼 수 없어요',
            description: '방을 하나라도 채점하면\n여기에 순위가 나타납니다.',
          ),
        ],
      );
    }

    final incomplete = scored.where((entry) => !entry.isComplete).length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.page, 8, AppSpacing.page, 120),
      children: [
        Text(
          '건물 점수와 방 점수를 중요도로 가중 합산한 결과입니다.',
          style: TextStyle(fontSize: 13.5, color: palette.textMuted, height: 1.4),
        ),
        if (incomplete > 0) ...[
          const SizedBox(height: 6),
          Text(
            '아직 다 채점하지 않은 방 $incomplete곳이 섞여 있어요. 매긴 항목만으로 계산한 값이라 비교는 되지만, 표본이 적을 수 있습니다.',
            style: TextStyle(fontSize: 12.5, color: palette.textMuted, height: 1.4),
          ),
        ],
        const SizedBox(height: 20),
        for (var index = 0; index < scored.length; index++) ...[
          _RankCard(
            rank: index + 1,
            entry: scored[index],
            onTap: () => onOpenRoom(scored[index]),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

/// 1~3위는 눈에 띄게, 나머지는 담백하게.
class _RankCard extends StatelessWidget {
  const _RankCard({required this.rank, required this.entry, required this.onTap});

  final int rank;
  final RankedRoom entry;
  final VoidCallback onTap;

  static const _medals = <int, Color>{
    1: Color(0xFFD4A017),
    2: Color(0xFF9AA0A6),
    3: Color(0xFFB87333),
  };

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final medal = _medals[rank];
    final isTop = medal != null;

    return AppCard(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: isTop ? 40 : 32,
            height: isTop ? 40 : 32,
            decoration: BoxDecoration(
              color: isTop ? medal.withValues(alpha: 0.16) : palette.background,
              shape: BoxShape.circle,
              border: Border.all(color: isTop ? medal : palette.border),
            ),
            alignment: Alignment.center,
            child: Text(
              '$rank',
              style: TextStyle(
                fontSize: isTop ? 16 : 13,
                fontWeight: FontWeight.w800,
                color: isTop ? medal : palette.textMuted,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.room.name,
                  style: TextStyle(
                    fontSize: isTop ? 17 : 15.5,
                    fontWeight: FontWeight.w700,
                    color: palette.textStrong,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  entry.building.name,
                  style: TextStyle(fontSize: 12.5, color: palette.textMuted),
                ),
                if (!entry.isComplete) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: palette.border,
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      '${entry.totalCount - entry.scoredCount}개 미채점',
                      style: TextStyle(fontSize: 11, color: palette.textMuted),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            entry.percent.toStringAsFixed(0),
            style: TextStyle(
              fontSize: isTop ? 26 : 20,
              fontWeight: FontWeight.w800,
              color: isTop ? medal : palette.textStrong,
              height: 1,
            ),
          ),
          const SizedBox(width: 2),
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              '점',
              style: TextStyle(fontSize: 12, color: palette.textMuted),
            ),
          ),
        ],
      ),
    );
  }
}
