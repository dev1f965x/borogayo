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

/// 화면에 노출하는 유형 이름. "0~10 점수"처럼 구현을 그대로 읽어주는 말 대신
/// 부르기 쉬운 한 단어로 통일한다.
String criterionTypeLabel(CriterionType type) =>
    type == CriterionType.scale ? '점수형' : '여부형';

/// 유형을 고를 때 옆에 붙이는 한 줄 설명.
String criterionTypeHint(CriterionType type) => type == CriterionType.scale
    ? '0~10점으로 매김 · 채광, 소음처럼 정도가 있는 것'
    : '있음·없음으로 매김 · 엘리베이터처럼 있고 없고가 전부인 것';

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

  /// 목록에서 한눈에 찾으라고 붙이는 그림. 없어도 되는 장식이라 null을 허용한다.
  final String? emoji;

  const Criterion({
    this.id,
    required this.projectId,
    required this.name,
    required this.scope,
    this.type = CriterionType.scale,
    this.weight = 3,
    this.position = 0,
    this.emoji,
  });

  Criterion copyWith({String? name, int? weight, int? position, String? emoji}) =>
      Criterion(
        id: id,
        projectId: projectId,
        name: name ?? this.name,
        scope: scope,
        type: type,
        weight: weight ?? this.weight,
        position: position ?? this.position,
        emoji: emoji ?? this.emoji,
      );

  Map<String, Object?> toMap() => {
    if (id != null) 'id': id,
    'project_id': projectId,
    'name': name,
    'scope': scope.name,
    'type': type.name,
    'weight': weight,
    'position': position,
    'emoji': emoji,
  };

  factory Criterion.fromMap(Map<String, Object?> map) => Criterion(
    id: map['id'] as int,
    projectId: map['project_id'] as int,
    name: map['name'] as String,
    scope: _enumByName(CriterionScope.values, map['scope'] as String?, CriterionScope.room),
    type: _enumByName(CriterionType.values, map['type'] as String?, CriterionType.scale),
    weight: map['weight'] as int,
    position: map['position'] as int,
    emoji: map['emoji'] as String?,
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

/// 사진·영상을 찍은 구역을 고를 때 먼저 보여주는 후보.
/// 현장에서 탭 한 번으로 끝나야 하므로 흔한 곳을 미리 깔아두고,
/// 여기에 없는 곳은 직접 적을 수 있게 한다.
const kBuildingMediaLabels = <String>['외관', '공용부', '주차장', '주변'];
const kRoomMediaLabels = <String>['거실', '방', '주방', '화장실', '베란다', '현관'];

/// 건물이나 방에 붙는 사진·영상. 파일은 앱 저장소에 복사해두고 경로만 들고 있는다.
class MediaItem {
  final int? id;
  final int? buildingId;
  final int? roomId;
  final String path;
  final MediaKind kind;

  /// 어느 구역을 찍은 것인지.
  final String? label;

  /// 영상의 첫 프레임을 미리 뽑아둔 이미지. 사진은 원본을 그대로 쓰므로 null.
  final String? thumbPath;
  final DateTime createdAt;

  const MediaItem({
    this.id,
    this.buildingId,
    this.roomId,
    required this.path,
    required this.kind,
    this.label,
    this.thumbPath,
    required this.createdAt,
  });

  /// 목록에 그릴 이미지 경로. 영상은 뽑아둔 썸네일이 있으면 그것을 쓴다.
  String? get previewPath => kind == MediaKind.photo ? path : thumbPath;

  Map<String, Object?> toMap() => {
    if (id != null) 'id': id,
    'building_id': buildingId,
    'room_id': roomId,
    'path': path,
    'kind': kind.name,
    'label': label,
    'thumb_path': thumbPath,
    'created_at': createdAt.toIso8601String(),
  };

  factory MediaItem.fromMap(Map<String, Object?> map) => MediaItem(
    id: map['id'] as int,
    buildingId: map['building_id'] as int?,
    roomId: map['room_id'] as int?,
    path: map['path'] as String,
    kind: _enumByName(MediaKind.values, map['kind'] as String?, MediaKind.photo),
    label: map['label'] as String?,
    thumbPath: map['thumb_path'] as String?,
    createdAt: DateTime.parse(map['created_at'] as String),
  );
}

/// 목록 화면에서 쓰는 집계값. 저장되는 데이터가 아니라 읽을 때만 만들어진다.
class ProjectSummary {
  final Project project;
  final int buildingCount;
  final int roomCount;

  const ProjectSummary({
    required this.project,
    required this.buildingCount,
    required this.roomCount,
  });
}

/// 방 하나의 채점 결과. **순위에 오르는 단위는 방이다.**
///
/// 실제로 고르는 대상이 "대성빌라"가 아니라 "대성빌라 302호"이기 때문에,
/// 건물에는 점수를 매기지 않는다. 건물은 방들이 공유하는 평가를 한 번만 받아두는
/// 묶음일 뿐이고, 그 값은 여기 [percent]에 이미 합산돼 들어간다.
class RoomScore {
  final Room room;

  /// 어느 건물의 방인지. 순위는 건물을 가로질러 한 줄로 세우므로 늘 함께 보여준다.
  final Building building;

  /// 0~100. 건물 기준까지 **전부** 매겼을 때만 값이 있다.
  final double? percent;

  /// 방 기준 중 실제로 매긴 개수. 카드의 진행률 막대에 쓴다.
  final int scoredCount;
  final int criterionCount;

  /// 방은 다 매겼는데 건물 평가가 남아서 점수가 안 나오는 상태.
  /// 이때 방 카드만 보면 다 한 것 같은데 점수가 `—`라 이유를 알려줘야 한다.
  final bool blockedByBuilding;

  const RoomScore({
    required this.room,
    required this.building,
    required this.percent,
    required this.scoredCount,
    required this.criterionCount,
    required this.blockedByBuilding,
  });

  bool get hasScore => percent != null;

  /// 방 기준만 놓고 봤을 때 다 매겼는지. 진행률 표시용.
  bool get roomScoringDone => criterionCount > 0 && scoredCount >= criterionCount;
}

/// 건물 관리 화면에서 쓰는 집계값. 건물에는 점수가 없으므로 진행 상황만 담는다.
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
