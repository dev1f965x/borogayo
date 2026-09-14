import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/models.dart';
import '../../theme.dart';

/// Area suggestions differ for building and room media.
List<String> areaPresetsFor({required bool isBuilding}) =>
    isBuilding ? kBuildingMediaLabels : kRoomMediaLabels;

/// Holds the chosen area: one of the presets or a custom string.
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

/// Area choices plus custom input, used both when adding media and when moving it.
class AreaPicker extends StatelessWidget {
  const AreaPicker({
    super.key,
    required this.controller,
    required this.onChanged,
  });

  final AreaPickerController controller;

  /// Tells the parent to rebuild when the choice changes.
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
              PillChoice(
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
            PillChoice(
              label: '직접 입력',
              icon: Icons.edit_outlined,
              creates: true,
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
            decoration: const InputDecoration(hintText: '옥상'),
            onChanged: (_) => onChanged(),
          ),
        ],
      ],
    );
  }
}
