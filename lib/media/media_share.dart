import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../models/models.dart';

/// Shares only the files and puts the description on the clipboard.
///
/// An Android share intent can carry files and text together, but many apps (KakaoTalk
/// among them) drop the text when files are present. Sending files only behaves the same
/// everywhere, and the sender decides whether to paste the description.
Future<void> shareMedia(
  BuildContext context, {
  required String ownerLabel,
  required List<MediaItem> items,
}) async {
  if (items.isEmpty) return;

  final text = buildShareText(ownerLabel, items);
  await Clipboard.setData(ClipboardData(text: text));
  if (!context.mounted) return;

  // Show this before the share sheet opens; after returning it's too late to notice.
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

/// The clipboard line, e.g. `대성빌라 302호 · 거실` or `대성빌라 302호 · 거실 2, 주방`.
String buildShareText(String ownerLabel, List<MediaItem> items) {
  // Keep insertion order. Older items without an area have nothing to count and are skipped.
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
