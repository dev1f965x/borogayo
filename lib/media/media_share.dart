import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../models/models.dart';

/// 사진·영상은 파일만 넘기고, 설명은 클립보드에 넣어둔다.
///
/// 안드로이드 공유는 파일과 텍스트를 한 인텐트에 같이 실을 수 있지만, 파일이 있으면
/// 텍스트 쪽을 버리는 앱이 많다(카카오톡). 어떤 앱은 받고 어떤 앱은 버리면 보내는 사람이
/// 결과를 예측할 수 없다. 그래서 아예 파일만 보내고 설명은 붙여넣게 한다.
/// 어디로 보내든 동작이 같고, 붙여넣을지 말지는 보내는 사람이 그때 정하면 된다.
Future<void> shareMedia(
  BuildContext context, {
  required String ownerLabel,
  required List<MediaItem> items,
}) async {
  if (items.isEmpty) return;

  final text = buildShareText(ownerLabel, items);
  await Clipboard.setData(ClipboardData(text: text));
  if (!context.mounted) return;

  // 공유창이 열리기 전에 띄워야 눈에 들어온다. 돌아온 뒤에 알려주면 이미 늦다.
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text('설명 복사됨 · $text'),
        duration: const Duration(seconds: 4),
      ),
    );

  await SharePlus.instance.share(
    ShareParams(files: [for (final item in items) XFile(item.path)]),
  );
}

/// 클립보드에 담기는 한 줄. 예) `대성빌라 302호 · 거실`, `대성빌라 302호 · 거실 2, 주방`
String buildShareText(String ownerLabel, List<MediaItem> items) {
  // 넣은 순서를 그대로 쓴다. 구역이 없던 옛 항목은 셀 것이 없으므로 건너뛴다.
  final counts = <String, int>{};
  for (final item in items) {
    final area = item.label;
    if (area == null) continue;
    counts[area] = (counts[area] ?? 0) + 1;
  }
  if (counts.isEmpty) return ownerLabel;

  final parts = counts.entries.map(
    (entry) => entry.value == 1 ? entry.key : '${entry.key} ${entry.value}',
  );
  return '$ownerLabel · ${parts.join(', ')}';
}
