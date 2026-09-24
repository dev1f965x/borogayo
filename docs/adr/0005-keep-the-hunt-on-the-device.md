# 5. Keep the hunt on the device

Status: accepted
Date: 2026-09-25

## Context

A hunt holds where someone is thinking of living, what they thought of it, and photos of
the inside of strangers' homes taken with an agent standing there. It is as private as
anything this app could hold.

## Options

- **A server.** Sync between phone and laptop, and a hunt shared with whoever else is
  moving. It also means an account, a database of people's addresses, and a breach that
  would matter.
- **The device only.** No account and nothing to breach. The phone and the browser then
  hold separate hunts, and clearing site data loses one.

## Decision

Everything stays on the device. The hunts, criteria and scores go in `localStorage` as
JSON; the photos, which are far too big for it, go in IndexedDB as blobs keyed by id.

## Consequences

No account, no network, nothing to leak. The app opens instantly because there is nothing
to wait for, and it works in a basement flat with no signal — which is where it is used.

Two devices are two hunts. Clearing the browser's data is the only way to lose one, and
the app says so rather than pretending otherwise. Sharing a hunt waits for a version that
can justify an account.

Photos are opened from IndexedDB only when a list that shows them is on screen, so a hunt
without photos never touches the database.
