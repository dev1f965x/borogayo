import 'package:flutter/material.dart';

/// App colors in light and dark variants. Screens read them as
/// `context.palette.textStrong`, and the active theme decides which set applies.
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.brand,
    required this.background,
    required this.surface,
    required this.border,
    required this.textStrong,
    required this.textBody,
    required this.textMuted,
    required this.star,
    required this.done,
    required this.danger,
    required this.toast,
    required this.onToast,
    required this.toastAction,
  });

  final Color brand;
  final Color background;
  final Color surface;
  final Color border;
  final Color textStrong;
  final Color textBody;
  final Color textMuted;
  final Color star;
  final Color done;
  final Color danger;

  /// Toasts stay dark in both themes, so they read as floating above the page.
  final Color toast;
  final Color onToast;
  final Color toastAction;

  static const light = AppPalette(
    brand: Color(0xFF7B6A8D),
    background: Color(0xFFF5F4F7),
    surface: Color(0xFFFFFFFF),
    border: Color(0xFFEBE9EF),
    textStrong: Color(0xFF1D1B21),
    textBody: Color(0xFF45424C),
    textMuted: Color(0xFF8D8A96),
    star: Color(0xFFF5A623),
    done: Color(0xFF3E9B72),
    danger: Color(0xFFD64545),
    toast: Color(0xFF2B2832),
    onToast: Color(0xFFF3F1F6),
    toastAction: Color(0xFFCDBEDD),
  );

  static const dark = AppPalette(
    brand: Color(0xFFB6A3C9),
    background: Color(0xFF141319),
    surface: Color(0xFF1E1C24),
    border: Color(0xFF2F2C38),
    textStrong: Color(0xFFF3F1F6),
    textBody: Color(0xFFCBC7D3),
    textMuted: Color(0xFF8B8794),
    star: Color(0xFFF5B342),
    done: Color(0xFF54B98C),
    danger: Color(0xFFE86A6A),
    toast: Color(0xFF38343F),
    onToast: Color(0xFFF3F1F6),
    toastAction: Color(0xFFCDBEDD),
  );

  @override
  AppPalette copyWith({
    Color? brand,
    Color? background,
    Color? surface,
    Color? border,
    Color? textStrong,
    Color? textBody,
    Color? textMuted,
    Color? star,
    Color? done,
    Color? danger,
    Color? toast,
    Color? onToast,
    Color? toastAction,
  }) {
    return AppPalette(
      brand: brand ?? this.brand,
      background: background ?? this.background,
      surface: surface ?? this.surface,
      border: border ?? this.border,
      textStrong: textStrong ?? this.textStrong,
      textBody: textBody ?? this.textBody,
      textMuted: textMuted ?? this.textMuted,
      star: star ?? this.star,
      done: done ?? this.done,
      danger: danger ?? this.danger,
      toast: toast ?? this.toast,
      onToast: onToast ?? this.onToast,
      toastAction: toastAction ?? this.toastAction,
    );
  }

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) return this;
    return AppPalette(
      brand: Color.lerp(brand, other.brand, t)!,
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      border: Color.lerp(border, other.border, t)!,
      textStrong: Color.lerp(textStrong, other.textStrong, t)!,
      textBody: Color.lerp(textBody, other.textBody, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      star: Color.lerp(star, other.star, t)!,
      done: Color.lerp(done, other.done, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      toast: Color.lerp(toast, other.toast, t)!,
      onToast: Color.lerp(onToast, other.onToast, t)!,
      toastAction: Color.lerp(toastAction, other.toastAction, t)!,
    );
  }
}

extension AppPaletteX on BuildContext {
  AppPalette get palette => Theme.of(this).extension<AppPalette>()!;
}
