import 'package:flutter/material.dart';

import '../../../models/models.dart';
import '../../../theme.dart';

/// Emoji choices, trimmed to ones that fit house hunting and fit on one screen.
const emojiChoices = <String>[
  '🚇', '🚌', '🚗', '🅿️', '🛗', '🏪', '🏫', '🏥', //
  '🌳', '🏞️', '🧹', '🔒', '📦', '🧺', '☀️', '🌙',
  '🔊', '🤫', '🚿', '🚽', '💧', '🧊', '🔥', '🪟',
  '🚪', '🛏️', '🛋️', '🍳', '📐', '💰', '📶', '🐕',
];

IconData criterionTypeIcon(CriterionType type) => type == CriterionType.scale
    ? Icons.linear_scale_rounded
    : Icons.toggle_on_outlined;

Future<T?> showCriterionSheet<T>(BuildContext context, WidgetBuilder builder) =>
    showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      builder: builder,
    );

Widget sheetTitle(BuildContext context, String text) => Padding(
  padding: const EdgeInsets.only(bottom: 16),
  child: Text(
    text,
    style: TextStyle(
      fontSize: 17,
      fontWeight: FontWeight.w700,
      color: context.palette.textStrong,
    ),
  ),
);
