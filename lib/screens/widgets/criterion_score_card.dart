import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/models.dart';
import '../../theme.dart';

String _formatScore(double value) => value == value.roundToDouble()
    ? value.toInt().toString()
    : value.toStringAsFixed(1);

/// Card for scoring one criterion. Every committed change is saved by the caller right away.
class CriterionScoreCard extends StatefulWidget {
  const CriterionScoreCard({
    super.key,
    required this.criterion,
    required this.value,
    required this.onChanged,
  });

  final Criterion criterion;

  /// Null while unscored.
  final double? value;

  /// Called with the new value when a change is finished, or null to clear it.
  final ValueChanged<double?> onChanged;

  @override
  State<CriterionScoreCard> createState() => _CriterionScoreCardState();
}

class _CriterionScoreCardState extends State<CriterionScoreCard> {
  /// Slider position while dragging; only the final value is committed.
  double? _dragging;

  void _commit(double? value) {
    HapticFeedback.selectionClick();
    widget.onChanged(value);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final criterion = widget.criterion;
    final value = widget.value;

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
              _WeightPill(criterion.weight),
              const Spacer(),
              // A slider takes a value on the lightest touch, so a scored criterion can
              // always go back to unscored.
              if (value != null)
                GestureDetector(
                  onTap: () => _commit(null),
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
            _binaryInput(palette, value)
          else
            _scaleInput(palette, value),
        ],
      ),
    );
  }

  Widget _binaryInput(AppPalette palette, double? value) {
    Widget option(String label, double optionValue) {
      final selected = value == optionValue;
      return Expanded(
        child: GestureDetector(
          onTap: () => _commit(optionValue),
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

    return Row(children: [option('아니오', 0), option('예', kMaxScore)]);
  }

  Widget _scaleInput(AppPalette palette, double? value) {
    final shown = _dragging ?? value ?? 0;
    final scored = _dragging != null || value != null;

    return Row(
      children: [
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: scored ? palette.brand : palette.border,
              inactiveTrackColor: palette.border,
              thumbColor: scored ? palette.brand : palette.textMuted,
              overlayColor: palette.brand.withValues(alpha: 0.12),
              trackHeight: 4,
            ),
            child: Slider(
              value: shown,
              max: kMaxScore,
              // 0.5 steps: fine enough, still quick to set on site.
              divisions: (kMaxScore * 2).toInt(),
              onChanged: (next) {
                HapticFeedback.selectionClick();
                setState(() => _dragging = next);
              },
              // Also fires for a tap that doesn't move the thumb, so tapping at 0 scores 0.
              onChangeEnd: (end) {
                setState(() => _dragging = null);
                widget.onChanged(end);
              },
            ),
          ),
        ),
        SizedBox(
          width: 32,
          child: Text(
            _formatScore(shown),
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

class _WeightPill extends StatelessWidget {
  const _WeightPill(this.weight);

  final int weight;

  @override
  Widget build(BuildContext context) {
    final color = context.palette.brand;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        '중요도 $weight',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
