/// Whether a criterion is scored once per building or once per room.
///
/// Things like transit or parking are the same for every room in a building;
/// scoring them per room is repetitive and lets the values drift apart.
enum CriterionScope { building, room }

/// How a criterion is scored.
/// - [scale]: 0–10 slider in 0.5 steps
/// - [binary]: yes/no, stored as 0 or 10 so it shares the scale's range
enum CriterionType { scale, binary }

String criterionTypeLabel(CriterionType type) =>
    type == CriterionType.scale ? '점수' : '예·아니오';

String criterionTypeHint(CriterionType type) =>
    type == CriterionType.scale ? '0~10점으로 매겨요' : '예, 아니오로 답해요';

/// Maximum score. Both types share this range, so one weighted formula covers both.
const double kMaxScore = 10.0;

const kDefaultWeight = 3;

/// One house hunt, e.g. "Spring 2026 move".
class Project {
  const Project({
    required this.id,
    required this.name,
    required this.createdAt,
  });

  factory Project.fromMap(Map<String, Object?> map) => Project(
    id: map['id'] as int,
    name: map['name'] as String,
    createdAt: DateTime.parse(map['created_at'] as String),
  );

  final int id;
  final String name;
  final DateTime createdAt;
}

/// Fields for a criterion that doesn't exist yet.
typedef CriterionDraft = ({
  String name,
  CriterionScope scope,
  CriterionType type,
  String? emoji,
});

/// A scoring criterion, either in a project or in the defaults new projects copy.
class Criterion {
  const Criterion({
    required this.id,
    required this.name,
    required this.scope,
    required this.type,
    required this.weight,
    required this.position,
    this.emoji,
  });

  factory Criterion.fromMap(Map<String, Object?> map) => Criterion(
    id: map['id'] as int,
    name: map['name'] as String,
    scope: CriterionScope.values.byName(map['scope'] as String),
    type: CriterionType.values.byName(map['type'] as String),
    weight: map['weight'] as int,
    position: map['position'] as int,
    emoji: map['emoji'] as String?,
  );

  final int id;
  final String name;
  final CriterionScope scope;
  final CriterionType type;
  final int weight;
  final int position;
  final String? emoji;

  Criterion copyWith({
    String? name,
    CriterionType? type,
    int? weight,
    String? Function()? emoji,
  }) => Criterion(
    id: id,
    name: name ?? this.name,
    scope: scope,
    type: type ?? this.type,
    weight: weight ?? this.weight,
    position: position,
    emoji: emoji == null ? this.emoji : emoji(),
  );

  /// Editable columns, shared by project criteria and default criteria.
  Map<String, Object?> toColumns() => {
    'name': name,
    'scope': scope.name,
    'type': type.name,
    'weight': weight,
    'position': position,
    'emoji': emoji,
  };
}

/// A building grouping several rooms. It exists only while it has rooms.
class Building {
  const Building({required this.id, required this.name});

  factory Building.fromMap(Map<String, Object?> map) =>
      Building(id: map['id'] as int, name: map['name'] as String);

  final int id;
  final String name;
}

/// A room that was actually visited.
class Room {
  const Room({
    required this.id,
    required this.buildingId,
    required this.name,
    this.memo,
  });

  factory Room.fromMap(Map<String, Object?> map) => Room(
    id: map['id'] as int,
    buildingId: map['building_id'] as int,
    name: map['name'] as String,
    memo: map['memo'] as String?,
  );

  final int id;
  final int buildingId;
  final String name;
  final String? memo;
}

enum MediaKind { photo, video }

String mediaKindLabel(MediaKind kind) => kind == MediaKind.photo ? '사진' : '영상';

/// Suggested areas when labeling a photo or video. Tagging on site should take one tap,
/// so common places are preset and anything else can be typed in.
const kBuildingMediaLabels = <String>['외관', '공용부', '주차장', '주변'];
const kRoomMediaLabels = <String>['거실', '방', '주방', '화장실', '베란다', '현관'];

/// A photo or video attached to a building or room. The file is copied into app storage
/// and only its path is kept here.
class MediaItem {
  const MediaItem({
    required this.id,
    this.buildingId,
    this.roomId,
    required this.path,
    required this.kind,
    this.label,
    this.thumbPath,
  });

  factory MediaItem.fromMap(Map<String, Object?> map) => MediaItem(
    id: map['id'] as int,
    buildingId: map['building_id'] as int?,
    roomId: map['room_id'] as int?,
    path: map['path'] as String,
    kind: MediaKind.values.byName(map['kind'] as String),
    label: map['label'] as String?,
    thumbPath: map['thumb_path'] as String?,
  );

  final int id;
  final int? buildingId;
  final int? roomId;
  final String path;
  final MediaKind kind;

  /// The area it shows.
  final String? label;

  /// Pre-extracted first frame of a video. Null for photos, which are shown directly.
  final String? thumbPath;

  /// Image to draw in lists: the photo itself, or a video's thumbnail if one exists.
  String? get previewPath => kind == MediaKind.photo ? path : thumbPath;
}

/// Aggregates for the project list, computed on read and never stored.
class ProjectSummary {
  const ProjectSummary({
    required this.project,
    required this.buildingCount,
    required this.roomCount,
  });

  final Project project;
  final int buildingCount;
  final int roomCount;
}

/// Scoring result for one room. Rooms are what get ranked; a building only holds the
/// ratings its rooms share, and those are included here.
class RoomScore {
  const RoomScore({
    required this.room,
    required this.building,
    required this.percent,
    required this.scoredCount,
    required this.criterionCount,
  });

  final Room room;
  final Building building;

  /// 0–100, only once every criterion, building ones included, is scored.
  final double? percent;

  /// Building and room criteria scored so far, out of [criterionCount].
  final int scoredCount;
  final int criterionCount;

  bool get hasScore => percent != null;

  bool get scoringDone => criterionCount > 0 && scoredCount >= criterionCount;
}
