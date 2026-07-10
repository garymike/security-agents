# security-agents

**Tier 2 of a layered security platform** — deployable *security agents* that run
**dynamic** analysis (executing untrusted targets) safely, in isolation.

> **Isolation is a property of the deployment, not the tool.** Static scanners can be
> centralized into shared, signed images
> ([security-workflows](https://github.com/garymike/security-workflows)). The moment you
> *execute* an untrusted target — an MCP server, an agent skill, an LLM app — isolation
> stops being optional. So dynamic capability ships as a **deployable unit that runs in the
> caller's own isolation**, never baked into a shared image.

## The three tiers

| Tier | Repo | Role |
|---|---|---|
| **1 — static** | [security-workflows](https://github.com/garymike/security-workflows) | Pinned, signed scanner images + reusable workflows. The **hands** (tool-belt). Safe to run anywhere. |
| **1.5 — skills** | [garymike/skills](https://github.com/garymike/skills) | The security **skills** — methodology and judgment. The **brains**. |
| **2 — agents** | **this repo** | Deployable agents = skill + toolbox + isolated sandbox. Where **dynamic** analysis lives. |

## Anatomy of an agent

A *security agent of a flavor* composes the other tiers with an isolated runtime:

```
brains  = a skill (methodology + judgment)              ← garymike/skills
   +
hands   = a curated, pinned toolbox image               ← garymike/security-workflows
   +
body    = an isolated runtime (sandbox, egress-gated)   ← this repo
```

The skill decides *what to do*; the toolbox provides *pinned tools to do it*; the sandbox
lets it *run untrusted code safely*.

## Flavors

| Flavor | Brains (skill) | Hands (toolbox) | What it does |
|---|---|---|---|
| **mcp-reviewer** | `mcp-security-review` | `mcp-review-toolbox` | Assess an untrusted MCP server end-to-end: static scan → sandboxed run → risk-rated report |
| **skill-auditor** | `skill-security-review` *(to author)* | `skill-audit-toolbox` | Review an agent skill on both surfaces: static gates → sandboxed script execution → risk-rated report |
| **mcp-gateway** | assess→enforce compiler *(Milestone C)* | `pipelock` *(adopted, pinned)* | Govern an MCP server at runtime: compile a review into a pipelock policy — alert-only by default, enforce opt-in |
| llm-redteam | *(Promptfoo-driven)* | `sast-toolbox` + Promptfoo | Red-team a running LLM app for prompt injection / data exfiltration |
| supply-chain-watchdog | — | base + Trivy/osv-scanner | Runtime dependency + egress monitoring inside a pipeline |

## Isolation principles

- The sandbox runs on an **internal Docker network with no egress** by default; the agent
  opts into narrow, logged egress only when a specific check requires it.
- The untrusted target is **pinned to a commit** and never handed host credentials.
- Nothing dynamic is centralized into the shared Tier-1 images — each agent is deployed and
  run in the operator's own isolation.

The load-bearing decisions above — the tier boundary, the agent anatomy, the sandbox hardening, the
flavor unit, and the static→dynamic escalation — are recorded as [ADRs](docs/adr/).

## Status

Foundation + three flavor scaffolds — **mcp-reviewer**
([`agents/mcp-reviewer/`](agents/mcp-reviewer/)), **skill-auditor**
([`agents/skill-auditor/`](agents/skill-auditor/)), and **mcp-gateway**
([`agents/mcp-gateway/`](agents/mcp-gateway/) — Milestone B wraps the pinned `pipelock` engine; the
assess→enforce compiler is Milestone C). The remaining flavors (llm-redteam,
supply-chain-watchdog) are designed but not yet built. The `skill-security-review` method
that skill-auditor calls is not yet authored (see its README) — the next brains-side piece.

## Relationship to the rest of the platform

- **[security-workflows](https://github.com/garymike/security-workflows)** (Tier 1) provides
  the signed toolbox images these agents use as their tool-belt — and the reusable workflows
  this repo dogfoods in CI.
- **[garymike/skills](https://github.com/garymike/skills)** provides the methodology skills
  the agents run.
