# 6. Dogfood the platform; solo-maintainer governance

## Status
Accepted

## Context
A repo that builds security tooling has no standing to ship unless it holds itself to the same bar. And as a
solo-maintained public repo, it needs governance that prevents drive-by tampering without inventing an
approval process of one.

## Decision
- **Dogfood the Tier-1 platform.** CI (`.github/workflows/security.yml`) runs
  [garymike/security-workflows](https://github.com/garymike/security-workflows) (`@v1.x`) against this repo —
  scan / gha-security / sast / iac / audit — so the agents' own supply chain is held to the platform they
  extend.
- **Solo governance, mirroring the ecosystem.** Branch protection requires **signed commits**, a **PR with 0
  approvals** (solo), **linear history**, and the required dogfood status checks — the same posture as
  security-workflows [ADR-0009](https://github.com/garymike/security-workflows/blob/main/docs/adr/0009-solo-branch-protection.md).
  Commits are signed and authored as the maintainer's noreply identity, with no external attribution.

## Consequences
The platform proves itself on its own Tier-2 repo on every change; a regression in the reusable workflows
surfaces here too. Governance is consistent across the ecosystem, so contributors and reviewers meet the same
rules everywhere. (Deliberately *not* strict-status-checks or required-conversation-resolution, which
dead-lock a zero-approval solo PR — the lesson from the security-workflows rollout.)
