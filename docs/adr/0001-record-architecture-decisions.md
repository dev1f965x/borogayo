# 1. Record architecture decisions

Status: accepted
Date: 2026-09-25

## Context

Decisions made while building are forgotten within weeks. Reading the code later tells
what was built, never which alternatives were weighed or why they lost.

## Decision

Every decision that is expensive to reverse gets a numbered file in `docs/adr`, in the
format used here: context, options, decision, consequences. Superseded decisions stay
in place and are marked as superseded by the newer file.

## Consequences

Choosing a library or a data shape now costs a short document. In exchange, the reason
survives, and a decision can be revisited on its merits instead of from memory.
