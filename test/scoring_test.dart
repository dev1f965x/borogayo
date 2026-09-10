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
  test('아무것도 안 매기면 점수가 없다', () {
    final result = computeScore(scores: {}, criteriaById: {1: criterion(1)});

    expect(result.hasScore, isFalse);
    expect(result.percent, isNull);
    expect(result.scoredCount, 0);
  });

  test('하나라도 비어 있으면 점수를 내지 않는다', () {
    final criteriaById = {1: criterion(1), 2: criterion(2), 3: criterion(3)};

    final partial = computeScore(scores: {1: 10, 2: 10}, criteriaById: criteriaById);

    // 매긴 것만 보면 100점이지만, 세 번째를 안 봤으므로 아직 이 집의 점수가 아니다.
    expect(partial.hasScore, isFalse);
    expect(partial.scoredCount, 2);
    expect(partial.criterionCount, 3);
  });

  test('점수가 없는 것은 순위에서 0점으로 내려간다', () {
    final criteriaById = {1: criterion(1), 2: criterion(2)};

    final partial = computeScore(scores: {1: 10}, criteriaById: criteriaById);
    final complete = computeScore(scores: {1: 2, 2: 2}, criteriaById: criteriaById);

    expect(partial.rankValue, 0);
    expect(complete.rankValue, greaterThan(partial.rankValue));
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

    expect(important.rankValue, greaterThan(trivial.rankValue));
    // 가중치 5:1이므로 10 * 5 / (10 * 6) = 83.3%
    expect(important.percent, closeTo(83.3, 0.1));
    expect(trivial.percent, closeTo(16.7, 0.1));
  });

  test('있음/없음도 같은 척도라 따로 다루지 않는다', () {
    final result = computeScore(
      scores: {1: 10, 2: 0},
      criteriaById: {
        1: criterion(1, type: CriterionType.binary),
        2: criterion(2, type: CriterionType.binary),
      },
    );

    // '없음'도 매긴 것이므로 점수가 나온다. 안 건드린 것과는 다르다.
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

  test('기준이 하나도 없으면 점수를 낼 수 없다', () {
    final result = computeScore(scores: {}, criteriaById: {});

    expect(result.hasScore, isFalse);
    expect(result.rankValue, 0);
  });
}
