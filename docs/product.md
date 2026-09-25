# 보러가요 — product definition

## Problem

Several viewings over a few days blur together. By the evening, one flat is remembered for
one thing and the rest is gone, including whatever ruled another one out.

Estate agents' apps list what is available. None of them records what the viewer thought of
a place while standing in it, and that is what the decision rests on.

## Who it is for

Someone moving house, viewing several places over a few days, usually alone, usually with
an agent waiting. They have a couple of minutes in a room and one hand free.

## What it is

A scoring sheet filled in on site, and a ranking read afterwards.

- **Criteria are set once, up front** — light, noise, water pressure, transit, parking —
  before the first viewing, and are the same for every place. Each carries a weight from 1
  to 5.
- **Each criterion is answered where it belongs.** Transit and parking are the same for
  every unit in a building and are answered once per building; light and water pressure are
  answered per room.
- **Rooms are what the ranking orders.** A building holds only what its rooms have in
  common.

## 2.0.0 scope

- **A hunt** holds the criteria and the places. More than one can be kept.
- **Criteria**: a 0–10 score or a yes/no, weighted 1 to 5, scoped to the building or the
  room, with an emoji for the list. New hunts start from a set of twelve; the edited set
  becomes the starting point for the next hunt.
- **Scoring on site**: one tap per criterion, saved as it is entered, undoable. A criterion
  that cannot be judged in the room is marked **해당 없음** and is excluded from that room's
  total rather than holding it back.
- **The ranking**: every room ordered by weighted percentage, with the rooms of one
  building kept together where they are adjacent.
- **Side by side**: two or three rooms compared criterion by criterion.
- **Photos**: taken on site, labelled by area, resized on the device. Each is re-encoded as
  it is taken, so the location and camera details are not kept.
- **Two places**: a page in the browser and an app on Android, from one code base. Nothing
  leaves the device.

## Acceptance criteria

- A room is scored on every criterion, from opening the app, in under two minutes.
- A criterion marked 해당 없음 is excluded from that room's total, and the room still ranks.
- A room with any criterion neither scored nor excluded shows `—` and ranks below every
  finished room.
- Two rooms of the same building share the building's answers; changing one changes both.
- The ranking is by weighted percentage, and a weight of 5 moves a room further than a
  weight of 1.
- The comparison shows two or three rooms with the higher answer marked per criterion.
- A photo taken on a phone carries no location and no camera details when it is exported.
- Everything survives a restart, and clearing the browser's data is the only way to lose it.

## Non-goals

- No listings, no prices from elsewhere, no map. The app holds judgements, not inventory.
- No account, no sync, no sharing a hunt in 2.0.0.
- No video in 2.0.0 (ADR 6): a walk-through is minutes of footage, which neither the
  browser's storage nor a plain re-encode handles.
- No notifications or reminders.

## Non-functional requirements

- A tap on a score is answered immediately; nothing waits on a network.
- The interface is reachable one-handed, with the scoring controls within the thumb's reach.
- A hundred photos stay within a few megabytes.
- Nothing about the person or the places they are considering leaves the device.

## Roadmap

| Version | Adds |
|---|---|
| 2.0.0 | Criteria, scoring, the ranking, side by side, photos, on web and Android |
| 2.1.0 | Video of a walk-through on Android, with its location stripped |
| later | A shared hunt, if sync ever justifies an account |
