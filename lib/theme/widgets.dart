import 'package:flutter/material.dart';

import 'palette.dart';
import 'tokens.dart';

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
