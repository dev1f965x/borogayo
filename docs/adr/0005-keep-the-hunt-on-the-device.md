# 5. Keep the hunt on the device

Status: accepted
Date: 2026-09-25

## Context

A hunt holds the addresses someone is considering living at, their opinion of each, and
photos of the inside of other people's homes.

## Options

- **A server.** Sync between phone and laptop, and a shared hunt. It also means an account
  and a database of people's addresses.
- **The device only.** No account and nothing held elsewhere. The phone and the browser
  then hold separate hunts, and clearing site data loses one.

## Decision

Everything stays on the device. The hunts, criteria and scores go in `localStorage` as
JSON; the photos, which are far too big for it, go in IndexedDB as blobs keyed by id.

## Consequences

No account and no network, so there is nothing to leak. The app opens with nothing to wait
for and works without a signal, which is often the case in a basement flat.

Two devices are two hunts, and clearing the browser's data loses one. Sharing a hunt waits
for a version that justifies an account.

Photos are read from IndexedDB only when a list that shows them is on screen, so a hunt
without photos never opens the database.
