import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/models.dart';
import '../../theme.dart';

/// 건물에 붙는 사진인지, 방에 붙는 사진인지에 따라 구역 후보가 다르다.
List<String> areaPresetsFor({required bool isBuilding}) =>
    isBuilding ? kBuildingMediaLabels : kRoomMediaLabels;

/// 고른 구역 이름을 들고 있는다. 미리 깔아둔 것 중 하나이거나, 직접 적은 문자열.
class AreaPickerController {
  AreaPickerController({required this.labels, String? initial})
    : custom = initial != null && !labels.contains(initial),
      selected = labels.contains(initial) ? initial : labels.firstOrNull {
    if (custom) customController.text = initial!;
  }

  final List<String> labels;
  final customController = TextEditingController();

  String? selected;
  bool custom;

  String get label => custom ? customController.text.trim() : (selected ?? '');

  void dispose() => customController.dispose();
}

/// 구역 칩 + '직접 입력'. 사진을 새로 붙일 때와 다른 곳으로 옮길 때 같은 걸 쓴다.
class AreaPicker extends StatelessWidget {
  const AreaPicker({super.key, required this.controller, required this.onChanged});

  final AreaPickerController controller;

  /// 고른 값이 바뀌면 부모가 다시 그리도록 알린다.
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final option in controller.labels)
              AreaChoiceChip(
                label: option,
                selected: !controller.custom && controller.selected == option,
                onTap: () {
                  HapticFeedback.selectionClick();
                  controller
                    ..custom = false
                    ..selected = option;
                  onChanged();
                },
              ),
            AreaChoiceChip(
              label: '직접 입력',
              icon: Icons.edit_outlined,
              selected: controller.custom,
              onTap: () {
                HapticFeedback.selectionClick();
                controller.custom = true;
                onChanged();
              },
            ),
          ],
        ),
        if (controller.custom) ...[
          const SizedBox(height: 12),
          TextField(
            controller: controller.customController,
            autofocus: true,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(hintText: '예: 옥상, 창고, 계단'),
            onChanged: (_) => onChanged(),
          ),
        ],
      ],
    );
  }
}

/// 시트 안에서 쓰는 알약 모양 선택 칩.
class AreaChoiceChip extends StatelessWidget {
  const AreaChoiceChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? palette.brand : palette.background,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: selected ? palette.brand : palette.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: selected ? Colors.white : palette.textMuted),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : palette.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
