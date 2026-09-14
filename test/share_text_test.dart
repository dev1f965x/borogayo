import 'package:flutter_test/flutter_test.dart';

import 'package:borogayo/media/media_share.dart';
import 'package:borogayo/models/models.dart';

MediaItem photo(String? label) => MediaItem(
  id: 1,
  roomId: 1,
  path: '/tmp/a.jpg',
  kind: MediaKind.photo,
  label: label,
);

void main() {
  test('a single item adds just the area name', () {
    expect(buildShareText('대성빌라 302호', [photo('거실')]), '대성빌라 302호 · 거실');
  });

  test('multiple items are counted per area', () {
    final text = buildShareText('대성빌라 302호', [
      photo('거실'),
      photo('거실'),
      photo('주방'),
    ]);

    // Areas with a single item get no count, and insertion order is kept.
    expect(text, '대성빌라 302호 · 거실 2, 주방');
  });

  test('items without an area copy just the name', () {
    expect(buildShareText('대성빌라', [photo(null)]), '대성빌라');
  });
}
