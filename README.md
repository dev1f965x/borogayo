# borogayo (보러가요)

[English](./README.md) | [한국어](./README.ko.md)

A mobile app for house hunting. Make a list, decide up front what you care about, then score every place you visit against those same criteria — so the choice isn't left to a fading memory of five different apartments.

![Flutter](https://img.shields.io/badge/Flutter-3.47-02569B?logo=flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-3-0175C2?logo=dart&logoColor=white)
![SQLite](https://img.shields.io/badge/DB-SQLite-003B57?logo=sqlite&logoColor=white)

The UI is Korean-only, and the app is deliberately scoped to house hunting rather than being a general-purpose checklist. The built-in criteria (light, noise, water pressure, mold, transit…) are the whole point — a blank "define your own criteria" screen is exactly what makes generic tools go unused.

## Features

- **Lists** — one per house hunt (e.g. "Spring 2026 move"). You name it, then set its criteria, prefilled with the usual things worth checking and editable afterwards.
- **A building groups; a room is what you judge** — you often view several units in the same building, so places are grouped by building, but the building isn't what you pick. So `add room` is the primary action (you choose or create its building inline), and buildings live in their own management screen for scoring the shared criteria and attaching photos.
- **Separate jobs get separate tabs** — building criteria vs. room criteria, building scoring vs. the room list. Stacked on one screen, viewing a room means scrolling past every scoring row first, and it stops being obvious which half you're looking at.
- **Criteria split by scope** — building criteria (transit, parking, elevator) are scored **once per building**; room criteria (light, noise, water pressure) are scored per room. Without the split you'd re-score "8 minutes to the station" for every unit, and the answers would drift.
- **Two criterion kinds** — *점수형* (a 0–10 slider in 0.5 steps) or *여부형* (yes/no). Both store on the same 0–10 scale (no = 0, yes = 10), so one weighted-sum formula covers everything. The kind is chosen after you type the name, not before — a picker sitting next to the input asks you to decide before you have anything to decide about.
- **Weights** — each criterion carries a weight (1–5), so commute can count for more than sunlight.
- **The list *is* the ranking, and it ranks rooms** — the list screen lines up every room across every building, since what you sign for is "unit 302 at Daesung Villa", not the villa. Buildings carry no score of their own; their criteria fold into the scores of the rooms inside them. Top 3 get a medal, ties break by name. A separate "ranking" tab would mean leaving the screen to answer "so which one is winning?", which is the only question this app exists for.
- **Optional emoji** — a criterion can carry an emoji, suggested from its name, so a long scoring screen is scannable.
- **Photos & video** — attach media to a building or a room, tagged by area (exterior, kitchen, bathroom… or one you type), filterable, viewable full-screen. Videos get a thumbnail extracted on the spot.
- **Everything is editable** — names and memos of lists, buildings and rooms; a criterion's name, emoji and kind; where a photo is attached and which area it was tagged as; a score entered by mistake. This is an app you type into while standing in someone's kitchen, so typos and mis-taps are the normal case, and one field that can't be corrected means deleting and starting over. Changes that reinterpret data already entered — scale to yes/no, say — say what will happen before they go through.
- **Sharing** — hands the files to another app and puts one line of context (`대성빌라 302호 · 거실 2, 주방`) on the clipboard. What the recipient can't tell from a photo is which place it was, but attaching that text to the share intent is unreliable: plenty of apps drop it once files are present (KakaoTalk among them). Some honoring it and some not leaves the sender unable to predict the result, so the share carries files only and the line is there to paste. For a batch, the area filter you already set doubles as the selection.
- **Settings** — light/dark/system theme (persisted), app version, and a full data reset.

Deleting a room is undoable from the snackbar — scores and media come back with it. Everything else asks first: destructive buttons arm on the first tap and only delete on the second, and the heavy deletions (a list, a building, a criterion other scores hang off) add a confirmation on top. Leaving a scoring screen with unsaved changes warns first.

Everything is stored locally on the device. No account, no backend, no network.

## Data model

Criteria are user-defined per list, so scores are stored relationally rather than as a blob — weights can be changed later and the ranking recomputed without rewriting stored scores. Building and room scores live in separate tables: a single table would need two nullable owner columns and an "which kind is this?" check on every read.

```
projects ──< criteria (name, scope: building|room, type: scale|binary, weight, emoji)
    │
    └──< buildings ──< building_scores  UNIQUE(building_id, criterion_id)
             │     └──< media
             │
             └──< rooms ──< room_scores  UNIQUE(room_id, criterion_id)
                      └──< media
```

Media files are copied into the app's own storage and only their paths are stored, since the picker hands back temporary paths. A video's thumbnail is extracted once at add time and stored alongside it. Files orphaned by a delete that was never undone are swept up on the next launch.

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

### Icon and splash

Both are drawn in code rather than checked in as artwork from a design tool, so changing the brand colour means editing one file:

```bash
dart run tool/generate_assets.dart
dart run flutter_launcher_icons
dart run flutter_native_splash:create
```

## Scoring

A room's score is a weighted average over **every criterion in the list**, mapped to 0–100.

**No score is produced until everything is scored.** Leave one blank and the room shows `—`; for ordering it counts as 0 and sinks to the bottom.

A number on a half-finished place can't be read: is it what the place is worth, or just how far you got? On a screen where the list *is* the ranking, that ambiguity turns straight into a bad decision. Filling blanks with zeros doesn't fix it either — you still can't tell a bad place from an unfinished one. Withholding the score keeps "can't judge this yet" visible, and the place takes its real position once you've actually looked at it.

Buildings have no score of their own. Their criteria fold into the scores of the rooms inside them, so an unfinished building blocks all of its rooms — the room card says so rather than leaving you guessing.

Both criterion kinds land on the same 0–10 scale (no = 0, yes = 10), so the formula never branches on kind. A "no" is an answer and yields a score; an untouched criterion does not. The math lives in `lib/models/scoring.dart` as a pure function, tested independently of the database.

## Roadmap

- [ ] Housing-specific fields (deposit/rent, floor, direction, walking minutes to transit)
- [ ] Reordering criteria by drag — the `position` column is already there
- [ ] CSV export — local-only storage means nothing survives a lost phone
