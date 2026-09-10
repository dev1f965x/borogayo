import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../db/database.dart';
import '../../models/models.dart';
import '../../theme.dart';

/// 이모지 후보. 집을 볼 때 실제로 쓸 만한 것들만 추려서 한 화면에 담기게 둔다.
const _emojiChoices = <String>[
  '🚇', '🚌', '🚗', '🅿️', '🛗', '🏪', '🏫', '🏥',
  '🌳', '🏞️', '🧹', '🔒', '📦', '🧺', '☀️', '🌙',
  '🔊', '🤫', '🚿', '🚽', '💧', '🧊', '🔥', '🪟',
  '🚪', '🛏️', '🛋️', '🍳', '📐', '💰', '📶', '🐕',
];

/// 이름만 봐도 뻔한 것들은 미리 골라준다. 이모지 고르기가 귀찮아서
/// 결국 아무도 안 쓰게 되는 걸 막는 정도의 장치다.
const _emojiHints = <String, String>{
  '교통': '🚇',
  '지하철': '🚇',
  '버스': '🚌',
  '주차': '🅿️',
  '엘리베이터': '🛗',
  '편의': '🏪',
  '관리': '🧹',
  '보안': '🔒',
  '채광': '☀️',
  '햇': '☀️',
  '소음': '🔊',
  '수압': '🚿',
  '곰팡이': '💧',
  '결로': '💧',
  '단열': '🧊',
  '난방': '🔥',
  '창': '🪟',
  '현관': '🚪',
  '옵션': '🛋️',
  '주방': '🍳',
  '크기': '📐',
  '평': '📐',
  '가격': '💰',
  '월세': '💰',
  '보증금': '💰',
  '인터넷': '📶',
  '반려': '🐕',
};

String? suggestEmoji(String name) {
  for (final entry in _emojiHints.entries) {
    if (name.contains(entry.key)) return entry.value;
  }
  return null;
}

/// 기준 이름을 받고, 유형과 이모지는 [showCriterionSheet]에서 이어서 고르게 하는 입력줄.
///
/// 유형 선택을 입력줄 옆에 늘 띄워두면, 이름을 적기도 전에 고르라는 셈이라
/// 매번 눈에 걸린다. 이름 → 추가 → 그때 유형, 순서가 실제 생각의 순서다.
class CriterionComposer extends StatefulWidget {
  const CriterionComposer({super.key, required this.scope, required this.onAdd});

  final CriterionScope scope;

  /// 시트에서 유형까지 고른 뒤 호출된다.
  final void Function(CriterionDraft draft) onAdd;

  @override
  State<CriterionComposer> createState() => _CriterionComposerState();
}

class _CriterionComposerState extends State<CriterionComposer> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _controller.text.trim();
    if (name.isEmpty) return;

    final picked = await showCriterionSheet(context, name: name, scope: widget.scope);
    if (picked == null || !mounted) return;

    _controller.clear();
    widget.onAdd(picked);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _controller,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(hintText: '기준 직접 추가'),
            onSubmitted: (_) => _submit(),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 52,
          height: 52,
          child: IconButton.filled(
            onPressed: _submit,
            style: IconButton.styleFrom(
              backgroundColor: palette.brand,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.add),
          ),
        ),
      ],
    );
  }
}

/// 유형과 이모지를 고르는 하단 시트. 취소하면 null.
///
/// 새로 만들 때와 고칠 때가 정할 것이 같아서 한 시트를 같이 쓴다.
/// 고칠 때는 [initialType]·[initialEmoji]로 지금 값을 채워 넣는다.
Future<CriterionDraft?> showCriterionSheet(
  BuildContext context, {
  required String name,
  required CriterionScope scope,
  CriterionType? initialType,
  String? initialEmoji,
  String confirmLabel = '추가',
}) {
  final palette = context.palette;

  var type = initialType ?? CriterionType.scale;
  var emoji = initialEmoji ?? (initialType == null ? suggestEmoji(name) : null);

  return showModalBottomSheet<CriterionDraft>(
    context: context,
    backgroundColor: palette.surface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) => StatefulBuilder(
      builder: (sheetContext, setSheetState) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '‘$name’을(를) 어떻게 볼까요?',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: palette.textStrong,
                ),
              ),
              const SizedBox(height: 16),
              for (final option in CriterionType.values) ...[
                _TypeOption(
                  type: option,
                  selected: type == option,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setSheetState(() => type = option);
                  },
                ),
                const SizedBox(height: 8),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Text(
                    '이모지',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: palette.textMuted,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '선택',
                    style: TextStyle(fontSize: 12, color: palette.textMuted),
                  ),
                  const Spacer(),
                  if (emoji != null)
                    TextButton(
                      onPressed: () => setSheetState(() => emoji = null),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        minimumSize: const Size(0, 32),
                      ),
                      child: const Text('안 쓸래요', style: TextStyle(fontSize: 12.5)),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final choice in _emojiChoices)
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setSheetState(() => emoji = choice);
                      },
                      child: Container(
                        width: 40,
                        height: 40,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: emoji == choice
                              ? palette.brand.withValues(alpha: 0.16)
                              : palette.background,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: emoji == choice ? palette.brand : palette.border,
                          ),
                        ),
                        child: Text(choice, style: const TextStyle(fontSize: 19)),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () => Navigator.pop(
                  sheetContext,
                  (name: name, scope: scope, type: type, emoji: emoji),
                ),
                child: Text(confirmLabel),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _TypeOption extends StatelessWidget {
  const _TypeOption({required this.type, required this.selected, required this.onTap});

  final CriterionType type;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? palette.brand.withValues(alpha: 0.1) : palette.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? palette.brand : palette.border),
        ),
        child: Row(
          children: [
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
              size: 20,
              color: selected ? palette.brand : palette.textMuted,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    criterionTypeLabel(type),
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: palette.textStrong,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    criterionTypeHint(type),
                    style: TextStyle(
                      fontSize: 12.5,
                      color: palette.textMuted,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
