import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme.dart';

/// Delete button vertically centered on the right of a card.
///
/// The first tap slides out a red delete button and the second one deletes. Lists get
/// brushed while scrolling, so it takes two taps, but without a dialog in the way.
/// It collapses by itself after a moment, so there's no cancel button.
class DeleteAction extends StatefulWidget {
  const DeleteAction({super.key, required this.onConfirm, this.label = '삭제'});

  final VoidCallback onConfirm;
  final String label;

  @override
  State<DeleteAction> createState() => _DeleteActionState();
}

class _DeleteActionState extends State<DeleteAction> {
  static const _collapsedWidth = 40.0;
  static const _expandedWidth = 78.0;
  static const _height = 36.0;

  bool _armed = false;
  Timer? _disarmTimer;

  @override
  void dispose() {
    _disarmTimer?.cancel();
    super.dispose();
  }

  void _arm() {
    HapticFeedback.selectionClick();
    setState(() => _armed = true);
    _disarmTimer?.cancel();
    _disarmTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _armed = false);
    });
  }

  void _confirm() {
    _disarmTimer?.cancel();
    setState(() => _armed = false);
    HapticFeedback.mediumImpact();
    widget.onConfirm();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return GestureDetector(
      onTap: _armed ? _confirm : _arm,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        // Pops out when opening and rewinds a little faster when closing.
        // At the same speed, closing reads as another action rather than a dismissal.
        duration: Duration(milliseconds: _armed ? 190 : 130),
        curve: _armed ? Curves.easeOutCubic : Curves.easeOutCubic.flipped,
        width: _armed ? _expandedWidth : _collapsedWidth,
        height: _height,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: _armed ? palette.danger : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        // Lets the content clip while the width shrinks instead of throwing an overflow error.
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          reverse: true,
          physics: const NeverScrollableScrollPhysics(),
          child: _armed
              ? Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.delete_outline,
                        size: 16,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        widget.label,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                )
              : SizedBox(
                  width: _collapsedWidth,
                  height: _height,
                  child: Icon(
                    Icons.delete_outline,
                    size: 20,
                    color: palette.textMuted,
                  ),
                ),
        ),
      ),
    );
  }
}
