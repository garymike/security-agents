# Architecture Decision Records

The key decisions behind `security-agents` (Tier 2, deployable security agents), in the order they
were made. Format: [Michael Nygard's ADRs](https://cognitect.com/blog/2011/11/15/documenting-architecture-decisions.html).
Sibling records for the static tier live in
[security-workflows/docs/adr](https://github.com/garymike/security-workflows/tree/main/docs/adr).

| # | Decision | Status |
|---|---|---|
| [0001](0001-separate-tier-2-repo.md) | A separate Tier-2 repo: isolation is a property of the deployment | Accepted |
| [0002](0002-agent-anatomy.md) | Agent anatomy: skill (brains) + toolbox (hands) + sandbox (body) | Accepted |
| [0003](0003-egress-gated-sandbox.md) | The sandbox is egress-gated, credential-free, and non-root | Accepted |
| [0004](0004-flavor-is-the-unit.md) | The flavor is the unit of packaging | Accepted |
| [0005](0005-static-dynamic-escalation.md) | Static to dynamic escalation, with the tiers kept separate | Accepted |
| [0006](0006-dogfood-and-solo-governance.md) | Dogfood the platform; solo-maintainer governance | Accepted |
| [0007](0007-runtime-gateway-and-assess-enforce.md) | Runtime gateway: adopt pipelock, compile reviews into policy, alert-only by default | Accepted |
