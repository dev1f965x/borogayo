# 3. Ship the rewrite as 2.0.0

Status: accepted
Date: 2026-09-25

## Context

The repository was deleted and written again from nothing, so its history starts at zero.
The app did not: 보러가요 1.0.0 is installed on a phone, under the same package identifier
and signed with the same key, and its data lives in a SQLite database this version cannot
read.

## Options

- **Start at 1.0.0 again.** Matches the fresh repository. But Android refuses to install a
  package whose versionCode is lower than the installed one, so the release would not
  install over what is there — it would have to be uninstalled first, silently losing the
  data anyway.
- **Ship as 2.0.0.** The version says what actually happened: same app, incompatible data.

## Decision

2.0.0, keeping the identifier `io.github.dev1f965x.borogayo` and the existing signing key.

## Consequences

An installed copy updates in place rather than needing a reinstall, and the major version
records that the old hunts do not come across. Keeping the key is what allows a copy
installed from the old release to be updated at all; changing it would end that
permanently.

No migration is written. A hunt is at most a few days of entries, and a migration from a
schema nothing else uses would cost more than re-entering them.
