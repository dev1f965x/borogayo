import 'package:flutter_test/flutter_test.dart';

import 'package:borogayo/text/josa.dart';

void main() {
  test('object particle follows the final consonant', () {
    expect(objectJosa('대성빌라'), '를');
    expect(objectJosa('주방'), '을');
    expect(objectJosa('302호'), '를');
    expect(objectJosa('301'), '을');
    expect(objectJosa('302'), '를');
  });

  test('direction particle treats ㄹ like no final consonant', () {
    expect(directionJosa('주방'), '으로');
    expect(directionJosa('거실'), '로');
    expect(directionJosa('베란다'), '로');
    expect(directionJosa('101'), '로');
    expect(directionJosa('3'), '으로');
  });
}
