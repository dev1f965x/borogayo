# 2. Rewrite as a page and an Android app

Status: accepted
Date: 2026-09-25

## Context

The first 보러가요 was Flutter with SQLite, Android only. It worked, but it sat apart from
every other app here: its own language, its own build, its own release path, and no way to
look at a ranking on a laptop after a day of viewings.

## Options

- **Keep Flutter.** Nothing to rewrite. But the ranking stays locked to the phone, and the
  toolchain is maintained for one app.
- **Tauri 2 with a web front end.** One code base serves a page and an Android app. Shares
  the lint, test, screenshot and release setup already used by the other apps. The rewrite
  is the cost, and anything needing real file access gets harder.
- **A plain web app, no shell.** Simplest, but no installable app on the phone, which is
  where the app is actually used — standing in someone's hallway.

## Decision

Tauri 2 around a React page, shipped as a page on GitHub Pages and an APK. The page is the
whole app; the shell only hosts it.

## Consequences

A day's viewings can be read back on a laptop. Everything the other apps already solved —
CI, signing, screenshots for design review — applies unchanged.

The phone and the browser hold separate hunts, because nothing syncs (ADR 4). Features
that want the file system, video above all, become harder and are deferred (ADR 5).

The stored data has no relation to the old SQLite database, so an installed copy starts
empty. That is why this ships as 2.0.0 (ADR 3).
