# 9. Use Biome for lint and format

Status: accepted
Date: 2026-09-25

## Context

The front end needs one tool that formats and lints, agrees with itself, and is fast
enough to run on every save and in CI.

## Options

- **ESLint and Prettier.** The default pairing, and two configurations that have to be kept
  from fighting each other.
- **Biome.** One binary, one configuration, formatting and linting together, fast.

## Decision

Biome, with `npm run lint` running `biome check .` and CI failing on anything it reports.

## Consequences

One file to configure instead of three, and no formatter-versus-linter arguments. The rule
set is smaller than ESLint's ecosystem; nothing needed here has been missing so far.
