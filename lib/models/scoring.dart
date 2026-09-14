import 'models.dart';

/// [percent] is 0–100 once every criterion is scored, and null while any is missing.
typedef ScoreResult = ({double? percent, int scoredCount, int criterionCount});

/// Weights the scores by importance and converts them to 0–100.
///
/// No score until everything is scored. A number on a half-rated place can't tell
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
      criteriaById.isNotEmpty && scoredCount == criteriaById.length;

  return (
    percent: complete ? weighted / maxWeighted * 100 : null,
    scoredCount: scoredCount,
    criterionCount: criteriaById.length,
  );
}
