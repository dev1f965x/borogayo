import 'models.dart';

typedef RankedRoom = ({RoomScore score, int? rank});

/// Consecutive rooms of the same building in the ranked list, shown under one header.
class RoomRun {
  const RoomRun({required this.building, required this.entries});

  final Building building;
  final List<RankedRoom> entries;
}

/// Splits an already ranked board into runs of the same building.
///
/// The order stays by score, so a building appears again whenever another building's
/// room sits between two of its rooms. Only scored rooms get a rank; sorting puts them
/// first, so the position is the rank.
List<RoomRun> groupIntoRuns(List<RoomScore> board) {
  final runs = <RoomRun>[];
  for (var index = 0; index < board.length; index++) {
    final score = board[index];
    final ranked = (score: score, rank: score.hasScore ? index + 1 : null);
    if (runs.isNotEmpty && runs.last.building.id == score.building.id) {
      runs.last.entries.add(ranked);
    } else {
      runs.add(RoomRun(building: score.building, entries: [ranked]));
    }
  }
  return runs;
}
