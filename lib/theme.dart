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

const _seedColor = Color(0xFF7B6A8D);

ThemeData buildAppTheme(Brightness brightness) {
  final palette = brightness == Brightness.dark
      ? AppPalette.dark
      : AppPalette.light;
  final scheme = ColorScheme.fromSeed(
    seedColor: _seedColor,
    brightness: brightness,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    extensions: [palette],
    scaffoldBackgroundColor: palette.background,
    appBarTheme: AppBarTheme(
      backgroundColor: palette.background,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: palette.textStrong,
        fontSize: 18,
        fontWeight: FontWeight.w700,
      ),
      iconTheme: IconThemeData(color: palette.textStrong),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: palette.surface,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: TextStyle(
        color: palette.textStrong,
        fontSize: 17,
        fontWeight: FontWeight.w700,
      ),
      contentTextStyle: TextStyle(
        color: palette.textBody,
        fontSize: 14,
        height: 1.4,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: palette.surface,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
    ),
    tabBarTheme: TabBarThemeData(
      labelColor: palette.textStrong,
      unselectedLabelColor: palette.textMuted,
      indicatorColor: palette.brand,
      indicatorSize: TabBarIndicatorSize.tab,
      dividerColor: palette.border,
      labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: palette.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: palette.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: palette.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: palette.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: palette.brand, width: 1.4),
      ),
      hintStyle: TextStyle(color: palette.textMuted, fontSize: 14),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: palette.brand,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: palette.textBody),
    ),
  );
}

/// Large screen title placed in the body instead of an AppBar, for more breathing room.
class ScreenTitle extends StatelessWidget {
  const ScreenTitle({super.key, required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: palette.textStrong,
            height: 1.2,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 6),
          Text(
            subtitle!,
            style: TextStyle(
              fontSize: 14,
              color: palette.textMuted,
              height: 1.4,
            ),
          ),
        ],
      ],
    );
  }
}

/// Card container used throughout the lists.
class AppCard extends StatelessWidget {
  const AppCard({super.key, required this.child, this.onTap, this.borderColor});

  final Widget child;
  final VoidCallback? onTap;

  /// Only for cards that should stand out, such as top ranks. Defaults to the normal border.
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final accented = borderColor != null;

    return Material(
      color: palette.surface,
      borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: borderColor ?? palette.border,
              width: accented ? 1.4 : 1,
            ),
            borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
          ),
          padding: const EdgeInsets.all(16),
          child: child,
        ),
      ),
    );
  }
}

/// Thin rounded scoring progress bar.
class ProgressBar extends StatelessWidget {
  const ProgressBar({super.key, required this.value, this.color});

  /// 0.0 ~ 1.0
  final double value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return ClipRRect(
      borderRadius: BorderRadius.circular(99),
      child: LinearProgressIndicator(
        value: value.clamp(0.0, 1.0),
        minHeight: 6,
        backgroundColor: palette.border,
        valueColor: AlwaysStoppedAnimation(color ?? palette.brand),
      ),
    );
  }
}

/// Placeholder card for empty states, with an optional call-to-action button.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 44, horizontal: 24),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        children: [
          Icon(icon, size: 44, color: palette.textMuted),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: palette.textBody,
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 20),
            OutlinedButton(
              onPressed: onAction,
              style: OutlinedButton.styleFrom(
                foregroundColor: palette.brand,
                side: BorderSide(color: palette.brand.withValues(alpha: 0.5)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
              ),
              child: Text(
                actionLabel!,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Rounded choice used for areas and buildings in sheets.
///
/// [creates] marks the option that makes something new instead of picking an existing one.
/// It is drawn as an outline so it stands apart from the regular choices.
class PillChoice extends StatelessWidget {
  const PillChoice({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    this.creates = false,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;
  final bool creates;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final (background, border, foreground) = switch ((creates, selected)) {
      (true, true) => (
        palette.brand.withValues(alpha: 0.14),
        palette.brand,
        palette.brand,
      ),
      (true, false) => (
        Colors.transparent,
        palette.brand.withValues(alpha: 0.45),
        palette.brand,
      ),
      (false, true) => (palette.brand, palette.brand, Colors.white),
      (false, false) => (palette.background, palette.border, palette.textMuted),
    };

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(
            color: border,
            width: creates && selected ? 1.4 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: foreground),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: foreground,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
