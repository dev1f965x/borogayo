# 7. Score only what was judged

Status: accepted
Date: 2026-09-25

## Context

A room's score is the weighted average of its criteria. The open question is what to do
with a criterion that has no value.

The Flutter version withheld the score until every criterion was rated, on the grounds that
a partial total reads the same as a complete one, and the list is the ranking.

That holds, but it leaves a gap. Some criteria cannot be judged in the room: the water was
off, the building has no lift, the viewing was after dark. The rule then keeps a room at
`—` for an answer that will never arrive, and a worse room that happens to be complete
ranks above it.

## Options

- **Rate it with a guess.** Records a judgement that was not made, which is what the app
  exists to avoid.
- **Remove the criterion from the hunt.** Changes every room to fix one.
- **Exclude it for that room only.** The criterion drops out of that room's total, and the
  room completes on what was judged.

## Decision

Every criterion on a room is scored, excluded as 해당 없음, or open. The percentage is
computed once nothing is open, over the criteria that were not excluded. A room with
anything open shows `—` and ranks below every finished room.

## Consequences

The original rule is kept: a total never mixes judgement with absence. What changes is that
an unanswerable criterion has somewhere to go.

Two rooms can now be scored over different criteria, so their percentages are not strictly
comparable. The side-by-side view shows 해당 없음 in the row rather than an empty cell, so
the difference is visible. A room that excludes most of its criteria says more about the
viewing than about the room; the app allows it, since there is no better value to record.
