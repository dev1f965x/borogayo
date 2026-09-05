import 'models.dart';

class ScoreResult {
  /// 0~100.
  final double percent;

  /// 실제로 계산에 들어간 기준 개수.
  final int scoredCount;

  const ScoreResult({required this.percent, required this.scoredCount});
}

/// 매긴 점수들을 중요도로 가중해 0~100으로 환산한다.
///
/// 전체 기준 수가 아니라 **매긴 기준만으로** 나눈다. 전체로 나누면 덜 채점했다는
/// 이유만으로 점수가 낮아져서, 절반만 본 방과 다 본 방을 비교할 수 없게 된다.
/// 대신 표본이 적을 수 있으므로 화면에서는 [ScoreResult.scoredCount]를 함께 보여준다.
///
/// 있음/없음 기준도 0과 10으로 저장되므로 여기서 타입을 나눌 필요가 없다.
ScoreResult computeScore({
  required Map<int, double> scores,
  required Map<int, Criterion> criteriaById,
}) {
  var weighted = 0.0;
  var maxWeighted = 0.0;
  var scoredCount = 0;

  for (final entry in scores.entries) {
    final criterion = criteriaById[entry.key];
    // 기준이 지워졌는데 점수만 남아있는 경우는 계산에서 뺀다.
    if (criterion == null) continue;

    weighted += entry.value * criterion.weight;
    maxWeighted += kMaxScore * criterion.weight;
    scoredCount++;
  }

  return ScoreResult(
    percent: maxWeighted == 0 ? 0 : weighted / maxWeighted * 100,
    scoredCount: scoredCount,
  );
}

/// 채점 화면이 들고 있는 '편집 중인 점수'.
///
/// 건물 채점과 방 채점이 똑같이 "불러온 값과 지금 값을 비교해서 저장 여부를 판단"해야 한다.
/// 그 규칙을 화면마다 각자 두면 어긋나기 쉬워서 여기에 모았다.
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

  bool get isDirty {
    if (_values.length != _saved.length) return true;
    for (final entry in _values.entries) {
      if (_saved[entry.key] != entry.value) return true;
    }
    return false;
  }

  /// 저장에 성공한 뒤 호출한다. 이후로는 다시 깨끗한 상태가 된다.
  void markSaved() => _saved = Map.of(_values);
}
