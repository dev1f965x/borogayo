# 보러가요 — product definition

## Problem

House hunting is decided by whichever place was seen last. Five viewings in two days, and
by the evening the third one has become "the one with the good light" and nothing else —
while the second one's water pressure, which was the reason it was ruled out, is gone.

Estate agents' apps list what is for rent. None of them holds **what you thought of it
while you were standing in it**, and that is the only record that decides anything.

## Who it is for

Someone moving house, viewing several places over a few days, usually alone, usually with
an agent waiting by the door. They have two minutes in a room and one hand free.

## What it is

A scoring sheet you fill in on site, and a ranking you read afterwards.

- **Criteria set once, up front.** Light, noise, water pressure, transit, parking. Decided
  before the first viewing, while judgement is still cold, and the same for every place —
  which is the whole point. Each one carries a weight from 1 to 5.
- **Scored where it belongs.** Transit and parking are the same for every unit in a
  building, so they are scored once per building. Light and water pressure are scored per
  room.
- **A room is the thing being ranked.** A building is only what its rooms have in common.

## 2.0.0 scope

- **A hunt** holds the criteria and the places. More than one can be kept — people move
  twice.
- **Criteria**: a 0–10 score or a yes/no, weighted 1 to 5, scoped to the building or the
  room, with an emoji so the list reads at a glance. New hunts start from a set of twelve
  that can be edited, and the edited set becomes the starting point for the next hunt.
- **Scoring on site**: one tap per criterion, saved as it is entered, undoable. A criterion
  that cannot be judged here — the water was off — is marked **해당 없음** and leaves that
  room's total instead of blocking it.
- **The ranking**: every scored room, ordered, with the rooms of one building kept
  together where they are adjacent.
- **Side by side**: any two or three rooms compared criterion by criterion, which is what
  actually settles a decision between the final two.
- **Photos**: taken on site and labelled by area, resized on the device. Every photo is
  re-encoded as it is taken, so the location and the camera it came from do not survive.
- **Two places**: a page in the browser and an app on Android, from one code base. Nothing
  leaves the device.

## Acceptance criteria

- A room is scored on every criterion, from opening the app, in under two minutes.
- A criterion marked 해당 없음 is excluded from that room's total, and the room still ranks.
- A room with any criterion neither scored nor excluded shows `—` and ranks below every
  finished room.
- Two rooms of the same building share the building's scores; changing one changes both.
- The ranking is by weighted percentage, and a weight of 5 moves a room further than a
  weight of 1.
- The comparison shows two or three rooms with the higher score marked per criterion.
- A photo taken on a phone carries no location and no camera model when it is exported.
- Everything survives a restart, and clearing the browser's data is the only way to lose it.

## Non-goals

- No listings, no prices pulled from anywhere, no map. The app holds judgements, not
  inventory.
- No account, no sync, no sharing a hunt with a partner in 2.0.0.
- No video in 2.0.0 (ADR 5): a walk-through is minutes of footage, which neither the
  browser's storage nor a plain re-encode can handle honestly.
- No notifications, no reminders.

## Non-functional requirements

- A tap on a score is answered instantly; nothing waits on a network, because there is none.
- The whole interface is reachable one-handed, with the scoring controls in the thumb's
  reach.
- A hundred photos stay within a few megabytes.
- Nothing about the person or the places they are considering leaves the device.

## Roadmap

| Version | Adds |
|---|---|
| 2.0.0 | Criteria, scoring, the ranking, side by side, photos, on web and Android |
| 2.1.0 | Video of a walk-through on Android, with its location stripped |
| later | A hunt shared with whoever is moving too, if sync ever earns an account |
