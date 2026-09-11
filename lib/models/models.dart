/// Whether a criterion is scored once per building or once per room.
///
/// Things like transit or parking are the same for every room in a building;
/// scoring them per room is repetitive and lets the values drift apart.
enum CriterionScope { building, room }

/// How a criterion is scored.
/// - [scale]: 0–10 slider in 0.5 steps
/// - [binary]: yes/no toggle, stored as 0 or 10 so it shares the scale's range
enum CriterionType { scale, binary }

/// Display name for a type: one short word rather than a description of the mechanics.
String criterionTypeLabel(CriterionType type) =>
    type == CriterionType.scale ? '점수형' : '여부형';

/// One-line explanation shown next to the type when choosing it.
String criterionTypeHint(CriterionType type) => type == CriterionType.scale
    ? '0~10점으로 매김 · 채광, 소음처럼 정도가 있는 것'
    : '있음·없음으로 매김 · 엘리베이터처럼 있고 없고가 전부인 것';

/// Maximum score. Both types share this range, so one weighted formula covers both.
const double kMaxScore = 10.0;

T _enumByName<T extends Enum>(List<T> values, String? name, T fallback) {
  for (final value in values) {
    if (value.name == name) return value;
  }
  return fallback;
}

/// One house hunt, e.g. "Spring 2026 move".
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

/// A criterion shared by every building and room in a project.
class Criterion {
  final int? id;
  final int projectId;
  final String name;
  final CriterionScope scope;
  final CriterionType type;
  final int weight;
  final int position;

  /// Optional decoration that makes the criterion easy to spot in lists.
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

  Criterion copyWith({
    String? name,
    int? weight,
    int? position,
    String? emoji,
  }) => Criterion(
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
    scope: _enumByName(
      CriterionScope.values,
      map['scope'] as String?,
      CriterionScope.room,
    ),
    type: _enumByName(
      CriterionType.values,
      map['type'] as String?,
      CriterionType.scale,
    ),
    weight: map['weight'] as int,
    position: map['position'] as int,
    emoji: map['emoji'] as String?,
  );
}

/// A building grouping several rooms.
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

/// A room that was actually visited.
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

/// Suggested areas when labeling a photo or video. Tagging on site should take one tap,
/// so common places are preset and anything else can be typed in.
const kBuildingMediaLabels = <String>['외관', '공용부', '주차장', '주변'];
const kRoomMediaLabels = <String>['거실', '방', '주방', '화장실', '베란다', '현관'];

/// A photo or video attached to a building or room. The file is copied into app storage
/// and only its path is kept here.
class MediaItem {
  final int? id;
  final int? buildingId;
  final int? roomId;
  final String path;
  final MediaKind kind;

  /// The area it shows.
  final String? label;

  /// Pre-extracted first frame of a video. Null for photos, which are shown directly.
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

  /// Image to draw in lists: the photo itself, or a video's thumbnail if one exists.
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
    kind: _enumByName(
      MediaKind.values,
      map['kind'] as String?,
      MediaKind.photo,
    ),
    label: map['label'] as String?,
    thumbPath: map['thumb_path'] as String?,
    createdAt: DateTime.parse(map['created_at'] as String),
  );
}

/// Aggregates for the project list, computed on read and never stored.
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

/// Scoring result for one room. **Rooms are what get ranked.**
///
/// The choice is between "Daesung Villa #302" and other units, not between buildings,
/// so buildings have no score of their own. A building only holds the ratings its rooms
/// share, and those are already included in [percent].
class RoomScore {
  final Room room;

  /// The room's building. The ranking spans buildings, so it's always shown alongside.
  final Building building;

  /// 0–100, only once **every** criterion, building ones included, is scored.
  final double? percent;

  /// Room criteria scored so far, for the card's progress bar.
  final int scoredCount;
  final int criterionCount;

  /// All room criteria are scored but building ones are not, so there's no score yet.
  /// The card looks complete while showing `—`, so the reason has to be shown.
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

  /// Whether every room criterion is scored, for progress display.
  bool get roomScoringDone =>
      criterionCount > 0 && scoredCount >= criterionCount;
}

/// Aggregates for the building list. Buildings have no score, only progress.
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
      buildingCriterionCount > 0 &&
      buildingScoredCount >= buildingCriterionCount;
}
