import 'models.dart';

class ScoreResult {
  const ScoreResult({
    required this.percent,
    required this.scoredCount,
    required this.criterionCount,
  });

  /// 0–100 once **every** criterion is scored; null while any is missing.
  final double? percent;

  /// Criteria scored so far.
  final int scoredCount;

  /// Criteria that need a score.
  final int criterionCount;

  bool get hasScore => percent != null;

  /// Sort value. Unfinished results count as 0 and sink to the bottom.
  double get rankValue => percent ?? 0;
}

/// Weights the scores by importance and converts them to 0–100.
///
/// **No score until everything is scored.** A number on a half-rated place can't tell
/// "what this place is worth" from "what was rated so far", and on a screen where the list
/// is the ranking that ambiguity becomes a wrong decision. Unfinished places show `—` and
/// rank as 0 until they are complete.
///
/// Binary criteria are stored as 0 or 10, so types need no special handling here.
ScoreResult computeScore({
  required Map<int, double> scores,
  required Map<int, Criterion> criteriaById,
}) {
  var weighted = 0.0;
  var maxWeighted = 0.0;
  var scoredCount = 0;

  // Iterate criteria, not scores, so scores left over from deleted criteria don't count.
  for (final criterion in criteriaById.values) {
    maxWeighted += kMaxScore * criterion.weight;

    final value = scores[criterion.id];
    if (value == null) continue;

    weighted += value * criterion.weight;
    scoredCount++;
  }

  final complete =
      criteriaById.isNotEmpty && scoredCount >= criteriaById.length;

  return ScoreResult(
    percent: complete && maxWeighted > 0 ? weighted / maxWeighted * 100 : null,
    scoredCount: scoredCount,
    criterionCount: criteriaById.length,
  );
}

/// Scores being edited on a scoring screen.
///
/// Building and room scoring both decide whether to save by comparing the loaded values
/// with the current ones; keeping that rule in one place stops the screens drifting apart.
class ScoreDraft {
  ScoreDraft(Map<int, double> saved)
    : _values = Map.of(saved),
      _saved = Map.of(saved);

  ScoreDraft.empty() : this(const {});

  final Map<int, double> _values;
  Map<int, double> _saved;

  Map<int, double> get values => Map.unmodifiable(_values);

  int get scoredCount => _values.length;

  double? valueOf(int criterionId) => _values[criterionId];

  void set(int criterionId, double value) => _values[criterionId] = value;

  /// Resets a value to unscored. A slider takes a value on the lightest touch, and since
  /// scores need every criterion, a room would otherwise be stuck at `—` after one slip.
  void clear(int criterionId) => _values.remove(criterionId);

  bool get isDirty {
    if (_values.length != _saved.length) return true;
    for (final entry in _values.entries) {
      if (_saved[entry.key] != entry.value) return true;
    }
    return false;
  }

  /// Call after a successful save to make the draft clean again.
  void markSaved() => _saved = Map.of(_values);
}
