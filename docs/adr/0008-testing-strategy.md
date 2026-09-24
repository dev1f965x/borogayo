# 8. Testing strategy

Status: accepted
Date: 2026-09-25

## Context

The risky parts are the arithmetic and the rules around it — what a weighted percentage
comes to, when a room counts as finished, how 해당 없음 changes the total, how the ranking
orders rooms and keeps a building's rooms together. None of them needs a phone, a camera,
or a building to be tested.

The rest of the risk is in the states the screen shows: a room half scored, a hunt with no
places yet, a comparison where one room is unfinished.

## Decision

- **Vitest and Testing Library** for the domain — scoring, completeness, ranking, grouping —
  and for the screens, with the stored hunt handed in by the test.
- **Playwright** against the real page for the flows that cross components: set the
  criteria, score two rooms in one building, watch the ranking reorder, put them side by
  side.
- The photo store is tested against a stand-in, since IndexedDB is the browser's and not
  this app's to prove.
- Every one of them runs in CI on each pull request.

## Consequences

- Scoring is a pure function over criteria and values, so every rule in ADR 7 is a test
  that reads like the rule.
- The camera and the APK are checked by hand on a phone before a release.
