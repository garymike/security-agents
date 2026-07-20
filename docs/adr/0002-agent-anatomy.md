# 2. Agent anatomy: skill (brains) + toolbox (hands) + sandbox (body)

## Status
Accepted

## Context
"A security agent" is easy to say and easy to build badly: a monolith that reimplements methodology, tools,
and isolation in one place, duplicating what the other tiers already do well.

## Decision
A security agent of a flavor composes the three tiers rather than reinventing them:

- **brains**: a skill (methodology and judgment), from [garymike/skills](https://github.com/garymike/skills);
- **hands**: a curated, pinned, signed toolbox image, from garymike/security-workflows;
- **body**: an isolated runtime (a sandbox, this repo).

The skill decides what to do; the toolbox provides pinned tools to do it; the sandbox lets it run
untrusted code safely.

## Consequences
Agents are thin: each is a composition + an isolation boundary, not a new codebase. Improvements to a skill or
a toolbox flow to every agent that uses them. It also makes the boundary of what this repo owns explicit (the
body) and defers brains and hands to the tiers built for them ([ADR-0001](0001-separate-tier-2-repo.md)).
