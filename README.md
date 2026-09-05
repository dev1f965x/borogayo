# borogayo (보러가요)

[English](./README.md) | [한국어](./README.ko.md)

A mobile app for house hunting. Make a list, decide up front what you care about, then score every place you visit against those same criteria — so the choice isn't left to a fading memory of five different apartments.

![Flutter](https://img.shields.io/badge/Flutter-3.47-02569B?logo=flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-3-0175C2?logo=dart&logoColor=white)
![SQLite](https://img.shields.io/badge/DB-SQLite-003B57?logo=sqlite&logoColor=white)

The UI is Korean-only, and the app is deliberately scoped to house hunting rather than being a general-purpose checklist. The built-in criteria (light, noise, water pressure, mold, transit…) are the whole point — a blank "define your own criteria" screen is exactly what makes generic tools go unused.

## Features

- **Lists** — one per house hunt (e.g. "Spring 2026 move"). Criteria are set when the list is created, prefilled with the usual things worth checking, and editable afterwards.
- **Buildings → rooms** — you often view several units in the same building, so places are grouped by building and rooms hang off them.
- **Criteria split by scope** — building criteria (transit, parking, elevator) are scored **once per building**; room criteria (light, noise, water pressure) are scored per room. Without the split you'd re-score "8 minutes to the station" for every unit, and the answers would drift.
- **Two input types** — a 0–10 slider in 0.5 steps, or a yes/no toggle. Both store on the same 0–10 scale (no = 0, yes = 10), so one weighted-sum formula covers everything.
- **Weights** — each criterion carries a weight (1–5), so commute can count for more than sunlight.
- **Ranking** — rooms across the whole list, sorted by score, top 3 highlighted. A room's score is **its building's score plus its own**, since building criteria aren't re-scored per room.
- **Photos & video** — attach media to a building or a room, tagged by area (exterior, kitchen, bathroom…), filterable, viewable full-screen.
- **Settings** — light/dark/system theme (persisted), app version, and a full data reset.

Deleting a room is undoable from the snackbar — scores and media come back with it. Heavier deletions (a list, a building, or a criterion other scores hang off) ask for confirmation instead. Leaving a scoring screen with unsaved changes warns first.

Everything is stored locally on the device. No account, no backend, no network.

## Data model

Criteria are user-defined per list, so scores are stored relationally rather than as a blob — weights can be changed later and the ranking recomputed without rewriting stored scores. Building and room scores live in separate tables: a single table would need two nullable owner columns and an "which kind is this?" check on every read.

```
projects ──< criteria (name, scope: building|room, type: scale|binary, weight)
    │
    └──< buildings ──< building_scores  UNIQUE(building_id, criterion_id)
             │     └──< media
             │
             └──< rooms ──< room_scores  UNIQUE(room_id, criterion_id)
                      └──< media
```

Media files are copied into the app's own storage and only their paths are stored, since the picker hands back temporary paths. Files orphaned by a delete that was never undone are swept up on the next launch.

## Getting Started

Flutter needs a real device, so this can't run in Docker — install the SDK on your host.

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install)
- Android SDK command-line tools + a JDK (Android Studio not required)
- A physical Android device with USB debugging enabled, or an emulator

### Run

```bash
git clone https://github.com/dev1f965x/borogayo.git
cd borogayo
flutter pub get
flutter run
```

### Test

```bash
flutter analyze
flutter test
```

## Scoring

A room's score is a weighted average over **only the criteria that were actually scored**, mapped to 0–100. Dividing by every criterion would punish a half-scored room for being half-scored, making a place you glanced at incomparable to one you went through carefully. The trade-off is that a room scored on one generous criterion can top the list, so the ranking shows how many criteria are still unscored.

Both input types land on the same 0–10 scale (no = 0, yes = 10), so the formula never branches on criterion type. The math lives in `lib/models/scoring.dart` as a pure function, tested independently of the database.

## Roadmap

- [ ] Housing-specific fields (deposit/rent, floor, direction, walking minutes to transit)
- [ ] Video thumbnails — videos currently show a generic play tile
- [ ] CSV export — local-only storage means nothing survives a lost phone
