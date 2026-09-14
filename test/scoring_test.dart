import 'package:flutter_test/flutter_test.dart';

import 'package:borogayo/models/models.dart';
import 'package:borogayo/models/scoring.dart';

Criterion criterion(
  int id, {
  int weight = 3,
  CriterionType type = CriterionType.scale,
}) => Criterion(
  id: id,
  name: '기준$id',
  scope: CriterionScope.room,
  type: type,
  weight: weight,
  position: id,
);

void main() {
  test('no score when nothing is rated', () {
    final result = computeScore(scores: {}, criteriaById: {1: criterion(1)});

    expect(result.percent, isNull);
    expect(result.scoredCount, 0);
  });

  test('no score while any criterion is unrated', () {
    final criteriaById = {1: criterion(1), 2: criterion(2), 3: criterion(3)};

    final partial = computeScore(
      scores: {1: 10, 2: 10},
      criteriaById: criteriaById,
    );

    // The scored criteria alone give 100, but the third wasn't rated, so there's no score yet.
    expect(partial.percent, isNull);
    expect(partial.scoredCount, 2);
    expect(partial.criterionCount, 3);
  });

  test('full marks everywhere is 100', () {
    final result = computeScore(
      scores: {1: 10, 2: 10},
      criteriaById: {1: criterion(1), 2: criterion(2)},
    );

    expect(result.percent, 100);
    expect(result.scoredCount, 2);
  });

  test('heavier criteria move the result more', () {
    final criteriaById = {
      1: criterion(1, weight: 5),
      2: criterion(2, weight: 1),
    };

    final important = computeScore(
      scores: {1: 10, 2: 0},
      criteriaById: criteriaById,
    );
    final trivial = computeScore(
      scores: {1: 0, 2: 10},
      criteriaById: criteriaById,
    );

    // Weights 5:1, so 10 * 5 / (10 * 6) = 83.3%
    expect(important.percent, closeTo(83.3, 0.1));
    expect(trivial.percent, closeTo(16.7, 0.1));
  });

  test('binary criteria share the same scale', () {
    final result = computeScore(
      scores: {1: 10, 2: 0},
      criteriaById: {
        1: criterion(1, type: CriterionType.binary),
        2: criterion(2, type: CriterionType.binary),
      },
    );

    // "No" is still an answer, unlike an untouched criterion, so a score comes out.
    expect(result.percent, 50);
  });

  test('scores for deleted criteria are ignored', () {
    final result = computeScore(
      scores: {1: 10, 99: 0}, // criterion 99 was deleted
      criteriaById: {1: criterion(1)},
    );

    expect(result.percent, 100);
    expect(result.scoredCount, 1);
  });

  test('no score without criteria', () {
    final result = computeScore(scores: {}, criteriaById: {});

    expect(result.percent, isNull);
  });
}
