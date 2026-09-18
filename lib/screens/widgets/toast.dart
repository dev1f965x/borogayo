import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../db/database.dart';
import '../../theme.dart';

const _visibleFor = Duration(seconds: 4);
const _edgeGap = 16.0;

/// Width a [MainActionButton] takes in the toast's row, gap included.
const _buttonSlot = 56.0 + 12.0;

/// Reports a change that already happened and offers to reverse it.
void showUndo(String message, {required VoidCallback onUndo}) =>
    Toasts.instance.show(message, onUndo: onUndo);

/// Reports a staged deletion and writes it once the toast goes away without an undo.
///
/// Toasts outlive screens, so the deletion still commits after navigating away.
/// [onUndone] refreshes whatever list hid the item.
void showDeletionUndo(
  String message,
  StagedDeletion deletion, {
  VoidCallback? onUndone,
  Future<void> Function()? afterCommit,
}) {
  Toasts.instance.show(
    message,
    onUndo: () {
      deletion.cancel();
      onUndone?.call();
    },
    onClosed: (undone) async {
      if (undone) return;
      await deletion.commit();
      await afterCommit?.call();
    },
  );
}

/// A message with nothing to act on.
void showToast(String message) => Toasts.instance.show(message);

/// The single toast shown along the bottom edge of every screen.
///
/// It sits in the same row as the screen's [MainActionButton] instead of stacking above
/// it, and steps aside while a dialog, sheet, or menu is open.
class Toasts extends ChangeNotifier {
  Toasts._();

  static final instance = Toasts._();

  /// Tracks dialogs, sheets, and menus. Register it with the app's navigator.
  late final NavigatorObserver observer = _PopupObserver(this);

  _Toast? _current;
  Timer? _timer;
  int _openPopups = 0;
  final _buttons = <Object>{};

  void show(
    String message, {
    VoidCallback? onUndo,
    void Function(bool undone)? onClosed,
  }) {
    _close(undone: false);
    _current = _Toast(message, onUndo, onClosed);
    _release();
    notifyListeners();
  }

  /// Keeps the toast up while it is being dragged.
  void _hold() => _timer?.cancel();

  /// Starts the countdown again, after showing or after a drag springs back.
  void _release() {
    _timer?.cancel();
    _timer = Timer(_visibleFor, () => _close(undone: false));
  }

  void _undo() {
    final toast = _current;
    if (toast == null) return;
    _close(undone: true);
    toast.onUndo?.call();
  }

  void _close({required bool undone}) {
    final toast = _current;
    if (toast == null) return;
    _timer?.cancel();
    _current = null;
    notifyListeners();
    toast.onClosed?.call(undone);
  }

  /// Lets a [MainActionButton] reserve its place in the toast.s row.
  void setMainButtonPresent(Object owner, {required bool present}) {
    final changed = present ? _buttons.add(owner) : _buttons.remove(owner);
    if (changed) notifyListeners();
  }

  void _popupOpened(int delta) {
    _openPopups += delta;
    notifyListeners();
  }
}

class _Toast {
  const _Toast(this.message, this.onUndo, this.onClosed);

  final String message;

  /// Null for a toast with nothing to undo.
  final VoidCallback? onUndo;

  /// Runs once when the toast leaves, with whether it was undone.
  final void Function(bool undone)? onClosed;
}

class _PopupObserver extends NavigatorObserver {
  _PopupObserver(this.toasts);

  final Toasts toasts;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is PopupRoute) toasts._popupOpened(1);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is PopupRoute) toasts._popupOpened(-1);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is PopupRoute) toasts._popupOpened(-1);
  }
}

/// Draws [Toasts] above the app. Wrap the navigator with it.
class ToastHost extends StatefulWidget {
  const ToastHost({super.key, required this.child});

  final Widget child;

  @override
  State<ToastHost> createState() => _ToastHostState();
}

class _ToastHostState extends State<ToastHost> {
  Toasts get _toasts => Toasts.instance;

  @override
  void initState() {
    super.initState();
    _toasts.addListener(_rebuild);
  }

  @override
  void dispose() {
    _toasts.removeListener(_rebuild);
    super.dispose();
  }

  /// Changes can arrive mid-frame (routes, buttons leaving), so those wait for the frame to end.
  void _rebuild() {
    final binding = SchedulerBinding.instance;
    if (binding.schedulerPhase == SchedulerPhase.persistentCallbacks) {
      binding.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
    } else {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final toast = _toasts._current;
    final covered = _toasts._openPopups > 0;

    return Stack(
      children: [
        widget.child,
        AnimatedPositioned(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          left: _edgeGap,
          right: _edgeGap + (_toasts._buttons.isEmpty ? 0 : _buttonSlot),
          // Matches where the Scaffold places its floating button.
          bottom:
              math.max(media.padding.bottom, media.viewInsets.bottom) +
              _edgeGap,
          child: IgnorePointer(
            ignoring: covered,
            child: AnimatedOpacity(
              opacity: covered ? 0 : 1,
              duration: const Duration(milliseconds: 150),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween(
                      begin: const Offset(0, 0.4),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                ),
                child: toast == null
                    ? const SizedBox.shrink()
                    : _ToastBar(
                        key: ObjectKey(toast),
                        toast: toast,
                        onUndo: _toasts._undo,
                        onDragStart: _toasts._hold,
                        onDismiss: () => _toasts._close(undone: false),
                        onRestore: _toasts._release,
                      ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// The toast card. Dragging it left far enough, or flinging it, dismisses it; a short
/// drag springs back.
class _ToastBar extends StatefulWidget {
  const _ToastBar({
    super.key,
    required this.toast,
    required this.onUndo,
    required this.onDragStart,
    required this.onDismiss,
    required this.onRestore,
  });

  final _Toast toast;
  final VoidCallback onUndo;
  final VoidCallback onDragStart;
  final VoidCallback onDismiss;
  final VoidCallback onRestore;

  @override
  State<_ToastBar> createState() => _ToastBarState();
}

class _ToastBarState extends State<_ToastBar>
    with SingleTickerProviderStateMixin {
  /// How far the card has moved left, as a share of its width.
  late final _offset = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 180),
  );

  static const _dismissShare = 0.35;
  static const _flingSpeed = 700.0;

  @override
  void dispose() {
    _offset.dispose();
    super.dispose();
  }

  void _onDragUpdate(DragUpdateDetails details) {
    final width = context.size?.width ?? 1;
    _offset.value -= details.primaryDelta! / width;
  }

  Future<void> _onDragEnd(DragEndDetails details) async {
    final flung = details.primaryVelocity! < -_flingSpeed;
    if (flung || _offset.value > _dismissShare) {
      await _offset.forward();
      widget.onDismiss();
    } else {
      await _offset.reverse();
      widget.onRestore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final toast = widget.toast;

    return GestureDetector(
      onHorizontalDragStart: (_) => widget.onDragStart(),
      onHorizontalDragUpdate: _onDragUpdate,
      onHorizontalDragEnd: _onDragEnd,
      child: AnimatedBuilder(
        animation: _offset,
        builder: (context, child) => FractionalTranslation(
          translation: Offset(-_offset.value, 0),
          child: Opacity(opacity: 1 - _offset.value * 0.7, child: child),
        ),
        child: Material(
          color: palette.toast,
          elevation: 6,
          shadowColor: Colors.black38,
          borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                18,
                6,
                toast.onUndo == null ? 18 : 4,
                6,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      toast.message,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.3,
                        color: palette.onToast,
                      ),
                    ),
                  ),
                  if (toast.onUndo != null)
                    TextButton.icon(
                      onPressed: widget.onUndo,
                      icon: const Icon(Icons.undo_rounded, size: 18),
                      label: const Text('취소'),
                      style: TextButton.styleFrom(
                        foregroundColor: palette.toastAction,
                        minimumSize: const Size(0, 44),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        textStyle: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
