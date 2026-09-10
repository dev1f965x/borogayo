import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/models.dart';
import '../../theme.dart';

String formatScore(double value) =>
    value == value.roundToDouble() ? value.toInt().toString() : value.toStringAsFixed(1);

/// 기준 하나에 점수를 매기는 카드. 건물 채점과 방 채점이 같은 위젯을 쓴다.
class CriterionScoreCard extends StatelessWidget {
  const CriterionScoreCard({
    super.key,
    required this.criterion,
    required this.value,
    required this.onChanged,
    required this.onCleared,
  });

  final Criterion criterion;

  /// 아직 매기지 않았으면 null. 화면에서는 흐린 `0`으로 두어 "안 건드림"이 보이게 한다.
  final double? value;
  final ValueChanged<double> onChanged;

  /// 잘못 건드린 값을 다시 '안 매김'으로 되돌린다.
  final VoidCallback onCleared;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (criterion.emoji != null) ...[
                Text(criterion.emoji!, style: const TextStyle(fontSize: 16)),
                const SizedBox(width: 6),
              ],
              Flexible(
                child: Text(
                  criterion.name,
                  style: TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w600,
                    color: palette.textStrong,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _Pill(text: '중요도 ${criterion.weight}', color: palette.brand),
              const Spacer(),
              // 매긴 뒤에만 나온다. 슬라이더는 스치기만 해도 값이 들어가서
              // 되돌릴 길이 없으면 실수 한 번에 그 방 점수가 계속 막힌다.
              if (value != null)
                GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    onCleared();
                  },
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    child: Text(
                      '지우기',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: palette.textMuted,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          if (criterion.type == CriterionType.binary)
            _BinaryInput(value: value, onChanged: onChanged)
          else
            _ScaleInput(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _BinaryInput extends StatelessWidget {
  const _BinaryInput({required this.value, required this.onChanged});

  final double? value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    Widget option(String label, double optionValue) {
      final selected = value == optionValue;
      return Expanded(
        child: GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            onChanged(optionValue);
          },
          child: Container(
            height: 44,
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: selected ? palette.brand : palette.background,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: selected ? palette.brand : palette.border),
            ),
            alignment: Alignment.center,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : palette.textMuted,
              ),
            ),
          ),
        ),
      );
    }

    return Row(children: [option('없음', 0), option('있음', kMaxScore)]);
  }
}

class _ScaleInput extends StatelessWidget {
  const _ScaleInput({required this.value, required this.onChanged});

  final double? value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final scored = value != null;

    return Row(
      children: [
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: palette.brand,
              inactiveTrackColor: palette.border,
              thumbColor: palette.brand,
              overlayColor: palette.brand.withValues(alpha: 0.12),
              trackHeight: 4,
            ),
            child: Slider(
              value: value ?? 0,
              min: 0,
              max: kMaxScore,
              // 0.5 단위. 현장에서 빠르게 정할 수 있을 만큼만 잘게 나눈다.
              divisions: (kMaxScore * 2).toInt(),
              label: formatScore(value ?? 0),
              onChanged: (next) {
                HapticFeedback.selectionClick();
                onChanged(next);
              },
            ),
          ),
        ),
        // 숫자는 여기 한 곳에만. 카드 위쪽에도 같은 값을 띄우면 눈이 두 군데를 오간다.
        SizedBox(
          width: 32,
          child: Text(
            formatScore(value ?? 0),
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: scored ? palette.textStrong : palette.textMuted,
            ),
          ),
        ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }
}
