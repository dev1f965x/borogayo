/// 평가 기준이 건물에 붙는지 방에 붙는지.
///
/// 같은 건물의 방 여러 개를 볼 때, 교통·주차처럼 건물이면 다 같은 항목을
/// 방마다 반복해서 매기면 낭비이고 값도 미묘하게 달라진다. 그래서 건물에서
/// 한 번만 매기는 항목과 방마다 매기는 항목을 나눈다.
enum CriterionScope { building, room }

/// 채점 방식.
/// - [scale]  : 0~10 슬라이더 (0.5 단위)
/// - [binary] : 없음/있음 토글. 저장은 0 또는 10으로 해서 scale과 같은 척도에 놓는다.
enum CriterionType { scale, binary }

/// 점수의 최대값. 두 타입 모두 이 척도를 공유하므로 가중합산 공식이 하나로 유지된다.
const double kMaxScore = 10.0;

T _enumByName<T extends Enum>(List<T> values, String? name, T fallback) {
  for (final value in values) {
    if (value.name == name) return value;
  }
  return fallback;
}

/// 집 찾기 한 건. 예: "2026 봄 이사"
class Project {
  final int? id;
  final String name;
  final DateTime createdAt;

  const Project({this.id, required this.name, required this.createdAt});

  Map<String, Object?> toMap() => {
    if (id != null) 'id': id,
    'name': name,
    'created_at': createdAt.toIso8601String(),
  };

  factory Project.fromMap(Map<String, Object?> map) => Project(
    id: map['id'] as int,
    name: map['name'] as String,
    createdAt: DateTime.parse(map['created_at'] as String),
  );
}

/// 프로젝트 안의 모든 건물/방에 공통으로 적용되는 평가 기준.
class Criterion {
  final int? id;
  final int projectId;
  final String name;
  final CriterionScope scope;
  final CriterionType type;
  final int weight;
  final int position;

  const Criterion({
    this.id,
    required this.projectId,
    required this.name,
    required this.scope,
    this.type = CriterionType.scale,
    this.weight = 3,
    this.position = 0,
  });

  Criterion copyWith({String? name, int? weight, int? position}) => Criterion(
    id: id,
    projectId: projectId,
    name: name ?? this.name,
    scope: scope,
    type: type,
    weight: weight ?? this.weight,
    position: position ?? this.position,
  );

  Map<String, Object?> toMap() => {
    if (id != null) 'id': id,
    'project_id': projectId,
    'name': name,
    'scope': scope.name,
    'type': type.name,
    'weight': weight,
    'position': position,
  };

  factory Criterion.fromMap(Map<String, Object?> map) => Criterion(
    id: map['id'] as int,
    projectId: map['project_id'] as int,
    name: map['name'] as String,
    scope: _enumByName(CriterionScope.values, map['scope'] as String?, CriterionScope.room),
    type: _enumByName(CriterionType.values, map['type'] as String?, CriterionType.scale),
    weight: map['weight'] as int,
    position: map['position'] as int,
  );
}

/// 건물 한 채. 방 여러 개를 묶는다.
class Building {
  final int? id;
  final int projectId;
  final String name;
  final String? memo;
  final DateTime createdAt;

  const Building({
    this.id,
    required this.projectId,
    required this.name,
    this.memo,
    required this.createdAt,
  });

  Map<String, Object?> toMap() => {
    if (id != null) 'id': id,
    'project_id': projectId,
    'name': name,
    'memo': memo,
    'created_at': createdAt.toIso8601String(),
  };

  factory Building.fromMap(Map<String, Object?> map) => Building(
    id: map['id'] as int,
    projectId: map['project_id'] as int,
    name: map['name'] as String,
    memo: map['memo'] as String?,
    createdAt: DateTime.parse(map['created_at'] as String),
  );
}

/// 실제로 보러 간 방 한 칸.
class Room {
  final int? id;
  final int buildingId;
  final String name;
  final String? memo;
  final DateTime createdAt;

  const Room({
    this.id,
    required this.buildingId,
    required this.name,
    this.memo,
    required this.createdAt,
  });

  Map<String, Object?> toMap() => {
    if (id != null) 'id': id,
    'building_id': buildingId,
    'name': name,
    'memo': memo,
    'created_at': createdAt.toIso8601String(),
  };

  factory Room.fromMap(Map<String, Object?> map) => Room(
    id: map['id'] as int,
    buildingId: map['building_id'] as int,
    name: map['name'] as String,
    memo: map['memo'] as String?,
    createdAt: DateTime.parse(map['created_at'] as String),
  );
}

enum MediaKind { photo, video }

/// 사진·영상이 어디를 찍은 것인지. 현장에서 탭 한 번으로 고를 수 있게 미리 정해둔다.
/// 자유 입력으로 두면 타이핑이 부담스러워 결국 아무도 안 적는다.
const kBuildingMediaLabels = <String>['외관', '공용부', '주차장', '주변', '기타'];
const kRoomMediaLabels = <String>['거실', '방', '주방', '화장실', '베란다', '현관', '기타'];

/// 건물이나 방에 붙는 사진·영상. 파일은 앱 저장소에 복사해두고 경로만 들고 있는다.
class MediaItem {
  final int? id;
  final int? buildingId;
  final int? roomId;
  final String path;
  final MediaKind kind;

  /// 어느 구역을 찍은 것인지. 예전에 저장한 항목은 없을 수 있다.
  final String? label;
  final DateTime createdAt;

  const MediaItem({
    this.id,
    this.buildingId,
    this.roomId,
    required this.path,
    required this.kind,
    this.label,
    required this.createdAt,
  });

  Map<String, Object?> toMap() => {
    if (id != null) 'id': id,
    'building_id': buildingId,
    'room_id': roomId,
    'path': path,
    'kind': kind.name,
    'label': label,
    'created_at': createdAt.toIso8601String(),
  };

  factory MediaItem.fromMap(Map<String, Object?> map) => MediaItem(
    id: map['id'] as int,
    buildingId: map['building_id'] as int?,
    roomId: map['room_id'] as int?,
    path: map['path'] as String,
    kind: _enumByName(MediaKind.values, map['kind'] as String?, MediaKind.photo),
    label: map['label'] as String?,
    createdAt: DateTime.parse(map['created_at'] as String),
  );
}

/// 목록 화면에서 쓰는 집계값. 저장되는 데이터가 아니라 읽을 때만 만들어진다.
class ProjectSummary {
  final Project project;
  final int criterionCount;
  final int buildingCount;
  final int roomCount;

  const ProjectSummary({
    required this.project,
    required this.criterionCount,
    required this.buildingCount,
    required this.roomCount,
  });
}

/// 순위에 올릴 방 하나의 계산 결과.
///
/// 방의 점수는 **그 방이 속한 건물 점수 + 방 자체 점수**를 합쳐서 낸다.
/// 건물 기준을 방마다 다시 매기지 않는 대신, 순위에서는 함께 반영해야 하기 때문.
class RankedRoom {
  final Room room;
  final Building building;

  /// 0~100. 매긴 기준만으로 계산한 가중 평균이라, 덜 채점한 방과도 비교는 된다.
  /// 다만 표본이 적을 수 있으므로 [isComplete]를 함께 보여준다.
  final double percent;
  final int scoredCount;
  final int totalCount;

  const RankedRoom({
    required this.room,
    required this.building,
    required this.percent,
    required this.scoredCount,
    required this.totalCount,
  });

  bool get isComplete => totalCount > 0 && scoredCount >= totalCount;
  bool get hasAnyScore => scoredCount > 0;
}

/// 건물 목록에서 쓰는 집계값.
class BuildingSummary {
  final Building building;
  final int roomCount;
  final int buildingScoredCount;
  final int buildingCriterionCount;

  const BuildingSummary({
    required this.building,
    required this.roomCount,
    required this.buildingScoredCount,
    required this.buildingCriterionCount,
  });

  bool get buildingScoringDone =>
      buildingCriterionCount > 0 && buildingScoredCount >= buildingCriterionCount;
}
