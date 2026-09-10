import 'models.dart';

class ScoreResult {
  const ScoreResult({
    required this.percent,
    required this.scoredCount,
    required this.criterionCount,
  });

  /// 0~100. **모든 기준을 매겼을 때만** 값이 있고, 하나라도 비면 null.
  final double? percent;

  /// 실제로 매긴 기준 개수.
  final int scoredCount;

  /// 매겨야 하는 기준 전체 개수.
  final int criterionCount;

  bool get hasScore => percent != null;

  /// 목록을 세울 때 쓰는 값. 아직 점수가 안 나온 것은 0으로 취급해 아래로 내린다.
  double get rankValue => percent ?? 0;
}

/// 매긴 점수들을 중요도로 가중해 0~100으로 환산한다.
///
/// **전부 매기기 전에는 점수를 내지 않는다.** 절반만 본 집에도 숫자가 붙으면,
/// 그 숫자가 "이 집의 값"인지 "여기까지 본 결과"인지 구분할 수 없다. 목록이 곧 순위인
/// 화면에서는 그 애매함이 그대로 잘못된 판단이 된다. 그래서 다 매기기 전에는 `—`로 두고,
/// 순위에서는 0점 취급해 아래에 남긴다. 다 보고 나면 그때 제자리를 찾는다.
///
/// 있음/없음 기준도 0과 10으로 저장되므로 여기서 타입을 나눌 필요가 없다.
ScoreResult computeScore({
  required Map<int, double> scores,
  required Map<int, Criterion> criteriaById,
}) {
  var weighted = 0.0;
  var maxWeighted = 0.0;
  var scoredCount = 0;

  // 기준을 기준으로 돈다. 점수 쪽을 돌면 지워진 기준에 남은 점수까지 세게 된다.
  for (final criterion in criteriaById.values) {
    maxWeighted += kMaxScore * criterion.weight;

    final value = scores[criterion.id];
    if (value == null) continue;

    weighted += value * criterion.weight;
    scoredCount++;
  }

  final complete = criteriaById.isNotEmpty && scoredCount >= criteriaById.length;

  return ScoreResult(
    percent: complete && maxWeighted > 0 ? weighted / maxWeighted * 100 : null,
    scoredCount: scoredCount,
    criterionCount: criteriaById.length,
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

  /// 잘못 건드린 값을 '아직 안 매김'으로 되돌린다.
  /// 슬라이더는 스치기만 해도 값이 들어가는데, 점수는 전부 매겨야 나오므로
  /// 되돌릴 방법이 없으면 실수 한 번에 그 방이 계속 `—`로 남는다.
  void clear(int criterionId) => _values.remove(criterionId);

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
