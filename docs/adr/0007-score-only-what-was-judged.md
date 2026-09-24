# 7. Score only what was judged

Status: accepted
Date: 2026-09-25

## Context

A room's score is the weighted average of its criteria. The question is what to do about a
criterion with no value yet.

The Flutter version answered: no score at all until every criterion is rated, because a
number on a half-rated place cannot distinguish "what this place is worth" from "what has
been rated so far", and on a screen where the list is the ranking, that ambiguity becomes
a wrong decision.

That is right, and it has a gap. Some criteria cannot be judged in the room: the water was
off, the building has no lift to look at, the viewing was after dark. The rule then holds a
place at `—` for something that will never have an answer, and a fully scored place that
is worse ranks above it.

## Options

- **Rate it anyway with a guess.** Silently turns a missing judgement into a real one, which
  is exactly what the app exists to prevent.
- **Drop the criterion from the hunt.** Fixes one room by changing every room.
- **Mark it 해당 없음, per room.** The criterion leaves that room's total, top and bottom.
  The room completes on what was actually judged.

## Decision

Every criterion on a room is scored, excluded as 해당 없음, or still open. A room's
percentage is computed once nothing is open, over the criteria that were not excluded.
A room with anything still open shows `—` and ranks below every finished room.

## Consequences

The original rule survives where it matters: a number never mixes judgement with
ignorance. What changes is that an unanswerable criterion has somewhere to go.

Two rooms can now be scored over different criteria, so the percentages are not strictly
comparable. The side-by-side view shows 해당 없음 in the row rather than an empty cell, so
the difference is visible where the comparison is close enough to matter. A room that
excludes most of its criteria is saying more about the viewing than about the room; the
app does not stop it, because there is no honest number to put there instead.
