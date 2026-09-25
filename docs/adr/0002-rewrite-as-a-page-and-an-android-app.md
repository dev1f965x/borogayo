# 2. Rewrite as a page and an Android app

Status: accepted
Date: 2026-09-25

## Context

The first 보러가요 was Flutter with SQLite, Android only. It worked, but it shared nothing
with the other apps here — its own language, build and release path — and the ranking could
only be read on the phone.

## Options

- **Keep Flutter.** Nothing to rewrite, but the ranking stays on the phone and a toolchain
  is maintained for one app.
- **Tauri 2 with a web front end.** One code base serves a page and an Android app, and the
  lint, test, screenshot and release setup of the other apps applies. The rewrite is the
  cost, and anything needing file access becomes harder.
- **A plain web app, no shell.** Simplest, but no installable app on the phone, which is
  where it is used.

## Decision

Tauri 2 around a React page, shipped as a page on GitHub Pages and an APK. The page is the
whole app; the shell only hosts it.

## Consequences

A day's viewings can be read back on a laptop, and the CI, signing and screenshot setup of
the other apps applies unchanged.

The phone and the browser hold separate hunts, since nothing syncs (ADR 5). Features that
need the file system, video in particular, are deferred (ADR 6).

The stored data is unrelated to the old SQLite database, so an installed copy starts empty.
That is why this ships as 2.0.0 (ADR 3).
