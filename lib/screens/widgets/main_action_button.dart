import 'package:flutter/material.dart';

import '../../theme.dart';
import 'toast.dart';

/// The screen's main floating button: an icon only, with [label] as its tooltip.
///
/// Toasts always sit in the space to its left.
class MainActionButton extends StatefulWidget {
  const MainActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  State<MainActionButton> createState() => _MainActionButtonState();
}

class _MainActionButtonState extends State<MainActionButton> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Only the button of the screen in front makes room in the toast's row.
    final inFront = ModalRoute.of(context)?.isCurrent ?? true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Toasts.instance.setMainButtonPresent(this, present: inFront && mounted);
    });
  }

  @override
  void dispose() {
    Toasts.instance.setMainButtonPresent(this, present: false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return FloatingActionButton(
      onPressed: widget.onPressed,
      backgroundColor: palette.brand,
      foregroundColor: Colors.white,
      elevation: 0,
      tooltip: widget.label,
      child: Icon(widget.icon),
    );
  }
}
