import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/models.dart';
import '../../theme.dart';

String formatScore(double value) => value == value.roundToDouble()
    ? value.toInt().toString()
    : value.toStringAsFixed(1);

/// Card for scoring one criterion, shared by building and room scoring.
class CriterionScoreCard extends StatelessWidget {
  const CriterionScoreCard({
    super.key,
    required this.criterion,
    required this.value,
    required this.onChanged,
    required this.onCleared,
  });

  final Criterion criterion;

  /// Null while unscored, shown as a dimmed `0` so untouched criteria stand out.
  final double? value;
  final ValueChanged<double> onChanged;

  /// Resets an accidental value to unscored.
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
              // Only once scored. A slider takes a value on the lightest touch, and without
              // a way back a single slip would keep the room's score blocked.
              if (value != null)
                GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    onCleared();
                  },
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 2,
                    ),
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
              border: Border.all(
                color: selected ? palette.brand : palette.border,
              ),
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
              // 0.5 steps: fine enough, still quick to set on site.
              divisions: (kMaxScore * 2).toInt(),
              label: formatScore(value ?? 0),
              onChanged: (next) {
                HapticFeedback.selectionClick();
                onChanged(next);
              },
            ),
          ),
        ),
        // The number appears only here; repeating it above would split attention.
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
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
