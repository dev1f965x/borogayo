import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme.dart';

/// 카드 오른쪽에 세로 가운데로 붙는 삭제 버튼.
///
/// 한 번 누르면 빨간 '삭제'가 오른쪽에서 밀려 나오고, 그걸 다시 눌러야 실제로 지운다.
/// 목록에서 스크롤하다 잘못 스치는 일이 잦은 자리라 두 번 누르게 만들되,
/// 확인 다이얼로그처럼 화면을 가로막지는 않는다.
/// 잠깐 두면 알아서 접히므로 '취소'를 따로 누를 필요도 없다.
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
        // 펼칠 때는 "튀어나오는" 느낌으로, 접힐 때는 그 움직임을 조금 빠르게 되감는 느낌으로.
        // 같은 속도로 돌아오면 사라지는 게 아니라 또 하나의 동작처럼 보인다.
        duration: Duration(milliseconds: _armed ? 190 : 130),
        curve: _armed ? Curves.easeOutCubic : Curves.easeOutCubic.flipped,
        width: _armed ? _expandedWidth : _collapsedWidth,
        height: _height,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: _armed ? palette.danger : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        // 폭이 줄어드는 동안 내용이 잘리기만 하도록. 그냥 두면 넘친다고 에러가 난다.
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
                      const Icon(Icons.delete_outline, size: 16, color: Colors.white),
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
