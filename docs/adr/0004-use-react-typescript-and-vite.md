# 4. Use React, TypeScript, and Vite for the interface

Status: accepted
Date: 2026-09-25

## Context

The window is small: a status line, a handful of switches, two text fields. It still has
states that have to be right — watching, waiting, install missing, restart needed.

## Options

- **Plain TypeScript and the DOM.** No dependency, and every state change written by hand.
- **React with TypeScript.** The state maps to what is on screen, Testing Library covers
  it without a browser, and it is the same stack as 4GHz, so one set of habits covers both.
- **Svelte or Solid.** Smaller output, a smaller ecosystem for testing, and nothing here
  that would notice the difference.

## Decision

React 19 with TypeScript, built by Vite, as in 4GHz.

## Consequences

- Vitest and Testing Library cover the window's states; Playwright drives the real page.
- The bundle is larger than it has to be for four switches, which costs nothing here.
