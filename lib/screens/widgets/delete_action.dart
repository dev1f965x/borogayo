import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme.dart';

/// Delete button vertically centered on the right of a card.
///
/// The first tap slides out a red delete button and the second one deletes. Lists get
/// brushed while scrolling, so it takes two taps, but without a dialog in the way.
/// It collapses after a moment or when anything else is touched.
class DeleteAction extends StatefulWidget {
  const DeleteAction({super.key, required this.onConfirm});

  final VoidCallback onConfirm;

  /// Collapses an open delete button when a touch lands outside it. Wraps the whole app.
  static Widget collapseOnOutsideTouch({required Widget child}) => Listener(
    behavior: HitTestBehavior.translucent,
    onPointerDown: _DeleteActionState._collapseUnlessInside,
    child: child,
  );

  @override
  State<DeleteAction> createState() => _DeleteActionState();
}

class _DeleteActionState extends State<DeleteAction> {
  static const _collapsedWidth = 40.0;
  static const _expandedWidth = 76.0;
  static const _height = 36.0;

  /// Only one button is open at a time.
  static _DeleteActionState? _open;

  static void _collapseUnlessInside(PointerDownEvent event) {
    final open = _open;
    if (open == null || !open.mounted) return;
    final box = open.context.findRenderObject() as RenderBox?;
    if (box != null &&
        box.hasSize &&
        (box.localToGlobal(Offset.zero) & box.size).contains(event.position)) {
      return;
    }
    open._collapse();
  }

  bool _armed = false;
  Timer? _collapseTimer;

  @override
  void dispose() {
    _collapseTimer?.cancel();
    if (_open == this) _open = null;
    super.dispose();
  }

  void _arm() {
    HapticFeedback.selectionClick();
    _open?._collapse();
    _open = this;
    setState(() => _armed = true);
    _collapseTimer = Timer(const Duration(seconds: 3), _collapse);
  }

  void _collapse() {
    _collapseTimer?.cancel();
    if (_open == this) _open = null;
    if (mounted && _armed) setState(() => _armed = false);
  }

  void _confirm() {
    _collapse();
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
        // The content takes its final width right away and is centered in it, while the
        // animating container clips it from the left.
        child: OverflowBox(
          alignment: Alignment.centerRight,
          maxWidth: _expandedWidth,
          child: SizedBox(
            width: _armed ? _expandedWidth : _collapsedWidth,
            height: _height,
            child: Center(
              child: _armed
                  ? const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.delete_outline,
                          size: 16,
                          color: Colors.white,
                        ),
                        SizedBox(width: 3),
                        Text(
                          '삭제',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    )
                  : Icon(
                      Icons.delete_outline,
                      size: 20,
                      color: palette.textMuted,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
