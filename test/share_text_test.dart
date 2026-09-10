import 'package:flutter_test/flutter_test.dart';

import 'package:borogayo/media/media_share.dart';
import 'package:borogayo/models/models.dart';

MediaItem photo(String? label) => MediaItem(
  id: 1,
  roomId: 1,
  path: '/tmp/a.jpg',
  kind: MediaKind.photo,
  label: label,
  createdAt: DateTime(2026),
);

void main() {
  test('한 장이면 구역 이름만 붙인다', () {
    expect(buildShareText('대성빌라 302호', [photo('거실')]), '대성빌라 302호 · 거실');
  });

  test('여러 장이면 구역별로 세어 요약한다', () {
    final text = buildShareText('대성빌라 302호', [
      photo('거실'),
      photo('거실'),
      photo('주방'),
    ]);

    // 한 장뿐인 구역에는 숫자를 붙이지 않는다. 넣은 순서를 그대로 따른다.
    expect(text, '대성빌라 302호 · 거실 2, 주방');
  });

  test('구역이 없으면 이름만 복사한다', () {
    expect(buildShareText('대성빌라', [photo(null)]), '대성빌라');
  });
}
