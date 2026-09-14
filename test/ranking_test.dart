import 'package:flutter_test/flutter_test.dart';

import 'package:borogayo/models/models.dart';
import 'package:borogayo/models/ranking.dart';

const _daesung = Building(id: 1, name: '대성빌라');
const _hanbit = Building(id: 2, name: '한빛빌라');

RoomScore room(int id, Building building, double? percent) => RoomScore(
  room: Room(id: id, buildingId: building.id, name: '$id호'),
  building: building,
  percent: percent,
  scoredCount: 0,
  criterionCount: 0,
);

void main() {
  test('consecutive rooms of one building share a run', () {
    final runs = groupIntoRuns([
      room(301, _daesung, 90),
      room(302, _daesung, 80),
      room(101, _hanbit, 70),
    ]);

    expect(runs.map((run) => run.building.name), ['대성빌라', '한빛빌라']);
    expect(runs.first.entries.map((entry) => entry.score.room.id), [301, 302]);
  });

  test('a building reappears when another building sits between its rooms', () {
    final runs = groupIntoRuns([
      room(301, _daesung, 90),
      room(101, _hanbit, 80),
      room(302, _daesung, 70),
    ]);

    expect(runs.map((run) => run.building.name), ['대성빌라', '한빛빌라', '대성빌라']);
  });

  test('ranks follow the overall order and skip unscored rooms', () {
    final runs = groupIntoRuns([
      room(301, _daesung, 90),
      room(101, _hanbit, 80),
      room(302, _daesung, null),
    ]);

    final ranks = [
      for (final run in runs)
        for (final entry in run.entries) entry.rank,
    ];
    expect(ranks, [1, 2, null]);
  });
}
