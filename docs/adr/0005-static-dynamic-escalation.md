# 5. Static to dynamic escalation, with the tiers kept separate

## Status
Accepted

## Context
Static scanning (the Tier-1 `skill-testfile-gate`, SkillSpector, etc.) is a cheap, run-everywhere pre-filter,
but it is provably evadable: payload-preserving packing bypasses more than 90% of published skill scanners
([*Cloak and Detonate*, arXiv 2607.02357](https://arxiv.org/abs/2607.02357)). Dynamic detonation does the
real work. The temptation is to fuse them into one pipeline.

## Decision
Model it as an escalation ladder, not a monolith. The Tier-1 gate emits machine-readable findings (SARIF)
and flags opaque/packed artifacts and `WARNING`-severity hits as detonation candidates. A Tier-2 agent
(e.g. `skill-auditor`) consumes those and confirms them dynamically in its sandbox. The handoff is a
documented contract (the shared SARIF), and the tiers stay separate: dynamic execution is never folded
back into the static images ([ADR-0001](0001-separate-tier-2-repo.md)).

## Consequences
The platform reads as a cheap wide net (static, in CI or pre-commit), then deep confirmation (dynamic, on
demand), each in its proper tier. This matches the source paper's own conclusion, that static analysis is a
cheap pre-filter and dynamic execution auditing does the real work, and it preserves the isolation principle:
nothing dynamic leaks into a shared, run-anywhere image.
