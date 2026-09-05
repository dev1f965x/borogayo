import 'package:flutter_test/flutter_test.dart';

import 'package:borogayo/models/models.dart';
import 'package:borogayo/models/scoring.dart';

Criterion criterion(int id, {int weight = 3, CriterionType type = CriterionType.scale}) =>
    Criterion(
      id: id,
      projectId: 1,
      name: '기준$id',
      scope: CriterionScope.room,
      type: type,
      weight: weight,
    );

void main() {
  test('아무것도 안 매기면 0점', () {
    final result = computeScore(scores: {}, criteriaById: {1: criterion(1)});

    expect(result.percent, 0);
    expect(result.scoredCount, 0);
  });

  test('전부 만점이면 100점', () {
    final result = computeScore(
      scores: {1: 10, 2: 10},
      criteriaById: {1: criterion(1), 2: criterion(2)},
    );

    expect(result.percent, 100);
    expect(result.scoredCount, 2);
  });

  test('중요도가 높은 기준이 결과를 더 크게 움직인다', () {
    final criteriaById = {
      1: criterion(1, weight: 5),
      2: criterion(2, weight: 1),
    };

    // 중요한 기준에서 만점을 받은 쪽이 더 높아야 한다.
    final important = computeScore(scores: {1: 10, 2: 0}, criteriaById: criteriaById);
    final trivial = computeScore(scores: {1: 0, 2: 10}, criteriaById: criteriaById);

    expect(important.percent, greaterThan(trivial.percent));
    // 가중치 5:1이므로 10 * 5 / (10 * 6) = 83.3%
    expect(important.percent, closeTo(83.3, 0.1));
    expect(trivial.percent, closeTo(16.7, 0.1));
  });

  test('덜 채점해도 매긴 것만으로 평균을 내므로 불리해지지 않는다', () {
    final criteriaById = {1: criterion(1), 2: criterion(2), 3: criterion(3)};

    // 셋 중 하나만 만점으로 매긴 상태.
    final partial = computeScore(scores: {1: 10}, criteriaById: criteriaById);

    expect(partial.percent, 100);
    // 다만 표본이 적다는 사실은 화면에서 알려야 하므로 개수를 함께 돌려준다.
    expect(partial.scoredCount, 1);
  });

  test('있음/없음도 같은 척도라 따로 다루지 않는다', () {
    final result = computeScore(
      scores: {1: 10, 2: 0},
      criteriaById: {
        1: criterion(1, type: CriterionType.binary),
        2: criterion(2, type: CriterionType.binary),
      },
    );

    expect(result.percent, 50);
  });

  test('기준이 지워졌는데 남아있는 점수는 계산에서 뺀다', () {
    final result = computeScore(
      scores: {1: 10, 99: 0}, // 99번 기준은 이미 삭제됨
      criteriaById: {1: criterion(1)},
    );

    expect(result.percent, 100);
    expect(result.scoredCount, 1);
  });
}
