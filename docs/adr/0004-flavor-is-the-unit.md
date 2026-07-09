# 4. The flavor is the unit of packaging

## Status
Accepted

## Context
The repo will hold several agent types — `mcp-reviewer`, `skill-auditor`, and planned `llm-redteam` /
`supply-chain-watchdog`. They share a shape but differ in skill, toolbox, and what they detonate. A shared
framework with per-type config would couple them; ad-hoc scripts would drift.

## Decision
Each flavor is a **self-contained `agents/<flavor>/` directory**: a `README.md`, a `compose.yml` (the pinned
toolbox plane + the egress-gated sandbox plane), a `sandbox/Dockerfile`, and a `review.sh` runbook. One flavor
is one **deployable unit** that composes a specific skill + toolbox + sandbox for a specific task. New flavors
are copy-and-adapt, not extend-a-framework.

## Consequences
Flavors are independently deployable and legible — you can read one directory top to bottom and run it. Adding
or changing a flavor never touches another. The small amount of duplication between sandboxes is deliberate: a
self-contained artifact is worth more here than DRY, and if a third flavor repeats a sandbox exactly, that is
the signal to extract a shared base — not before.
