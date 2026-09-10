import 'package:flutter/material.dart';

/// 앱에서 쓰는 색을 라이트/다크 두 벌로 들고 다닌다.
/// 화면 코드는 `context.palette.textStrong` 처럼 읽기만 하고,
/// 어느 쪽이 적용될지는 테마가 결정한다.
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
    );
  }
}

extension AppPaletteX on BuildContext {
  AppPalette get palette => Theme.of(this).extension<AppPalette>()!;
}

class AppSpacing {
  const AppSpacing._();

  /// 화면 좌우 기본 여백.
  static const page = 20.0;
  static const cardRadius = 16.0;
}

/// 1·2·3위에 얹는 색. 금·은·동.
const kMedalColors = <Color>[
  Color(0xFFD4A017),
  Color(0xFF9AA0A6),
  Color(0xFFB87333),
];

/// 카드에 얹는 날짜. 요일이나 시각까지는 필요 없고 "언제 만든 것인지"만 보면 된다.
String formatDate(DateTime value) {
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '${value.year}.$month.$day';
}

const _seedColor = Color(0xFF7B6A8D);

ThemeData buildAppTheme(Brightness brightness) {
  final palette = brightness == Brightness.dark ? AppPalette.dark : AppPalette.light;
  final scheme = ColorScheme.fromSeed(seedColor: _seedColor, brightness: brightness);

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
      contentTextStyle: TextStyle(color: palette.textBody, fontSize: 14, height: 1.4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: palette.textStrong,
      contentTextStyle: TextStyle(color: palette.surface, fontSize: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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

/// 화면 상단의 큰 제목. AppBar 대신 본문에 두어 여백을 넉넉히 준다.
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
            style: TextStyle(fontSize: 14, color: palette.textMuted, height: 1.4),
          ),
        ],
      ],
    );
  }
}

/// 목록에서 반복적으로 쓰는 카드 껍데기.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.borderColor,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// 상위권 카드처럼 눈에 띄어야 할 때만 넣는다. 없으면 기본 테두리.
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
        onLongPress: onLongPress,
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

/// 채점 진행률 막대. 얇고 둥글게.
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

/// 아무것도 없을 때 보여주는 안내 카드. 행동 유도 버튼까지 함께 둔다.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String description;
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
          const SizedBox(height: 6),
          Text(
            description,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13.5, color: palette.textMuted, height: 1.5),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 20),
            OutlinedButton(
              onPressed: onAction,
              style: OutlinedButton.styleFrom(
                foregroundColor: palette.brand,
                side: BorderSide(color: palette.brand.withValues(alpha: 0.5)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
