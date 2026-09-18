import 'package:flutter/material.dart';

class AppSpacing {
  const AppSpacing._();

  /// Default horizontal page padding.
  static const page = 20.0;
  static const cardRadius = 16.0;
}

/// Gold, silver, and bronze for the top three.
const kMedalColors = <Color>[
  Color(0xFFD4A017),
  Color(0xFF9AA0A6),
  Color(0xFFB87333),
];

/// Date shown on cards. Only the day matters, not the weekday or time.
String formatDate(DateTime value) {
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '${value.year}.$month.$day';
}
