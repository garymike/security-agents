# security-agents

The runtime layer of a small security platform with one throughline: most AI-native security
tooling stops at advice, and this platform turns advice into a control that blocks. Here that means
deployable agents that run dynamic analysis of untrusted targets (MCP servers, agent skills, LLM
apps) safely in isolation, and the platform's runtime-enforcement pillar: the assess-to-enforce MCP
gateway, which compiles a security review into a firewall policy that blocks unapproved egress and
tool calls. The static half, a gate that fails the build on auto-run malice, is in
[security-workflows](https://github.com/garymike/security-workflows); the methodology that produces
the reviews is in [garymike/skills](https://github.com/garymike/skills). Assess in the skills,
enforce in workflows and here.

> **Isolation is a property of the deployment, not the tool.** Static scanners can be
> centralized into shared, signed images
> ([security-workflows](https://github.com/garymike/security-workflows)). The moment you
> execute an untrusted target (an MCP server, an agent skill, an LLM app), isolation
> stops being optional. So dynamic capability ships as a deployable unit that runs in the
> caller's own isolation, never baked into a shared image.

## The three tiers

| Tier | Repo | Role |
|---|---|---|
| **1: static** | [security-workflows](https://github.com/garymike/security-workflows) | Pinned, signed scanner images + reusable workflows. The hands (tool-belt). Safe to run anywhere. |
| **1.5: skills** | [garymike/skills](https://github.com/garymike/skills) | The security skills: methodology and judgment. The brains. |
| **2: agents** | **this repo** | Deployable agents = skill + toolbox + isolated sandbox. Where dynamic analysis lives. |

## Where this is ahead of the field

A security review is usually a document. The [assess-to-enforce MCP gateway](agents/mcp-gateway)
compiles one into a running control: an `mcp-reviewer` `assessment.json` becomes a firewall policy,
through an engine-neutral [contract](docs/mcp-policy-contract.md) with swappable adapters (pipelock
locally, OPA for enterprise). It runs alert-only by default and blocks on opt-in, and it is proven
end to end against a real pinned server: only the hosts and tools the review approved get through,
in both engines. This is the runtime half of assess to enforce, and the structural one, since it
depends on no competitor's gap staying open. Worked example with the runnable proof: the
[threat profiles](docs/threats/).

## What's adopted, what's first-party

| | What | Why |
|---|---|---|
| **Adopted** (pinned, signed) | pipelock (the firewall engine), OPA (the enterprise policy engine), and the Tier-1 toolbox images | Do not reinvent a solved problem |
| **First-party** (only at the gaps) | the assess-to-enforce compiler and the engine-neutral `mcp-runtime-policy` contract | Turn a review into runtime enforcement, which nothing off the shelf does |
| **Modular** (the mechanism) | the contract with swappable adapters, flavor-as-the-unit agents, the egress-gated sandbox | So engines and flavors swap without moving the thesis |

## Anatomy of an agent

A security agent of a flavor composes the other tiers with an isolated runtime:

```
brains  = a skill (methodology + judgment)              ← garymike/skills
   +
hands   = a curated, pinned toolbox image               ← garymike/security-workflows
   +
body    = an isolated runtime (sandbox, egress-gated)   ← this repo
```

The skill decides what to do; the toolbox provides pinned tools to do it; the sandbox
lets it run untrusted code safely.

## Flavors

| Flavor | Brains (skill) | Hands (toolbox) | What it does |
|---|---|---|---|
| **mcp-reviewer** | `mcp-security-review` | `mcp-review-toolbox` | Assess an untrusted MCP server end-to-end: static scan → sandboxed run → risk-rated report |
| **skill-auditor** | [`skill-security-review`](https://github.com/garymike/skills/tree/main/skills/skill-security-review) | `skill-audit-toolbox` | Review an agent skill on both surfaces: static gates → sandboxed script execution → risk-rated report |
| **mcp-gateway** | assess→enforce compiler (Milestone C) | `pipelock` (adopted, pinned) | Govern an MCP server at runtime: compile a review into a pipelock policy (alert-only by default, enforce opt-in) |
| llm-redteam | (Promptfoo-driven) | `sast-toolbox` + Promptfoo | Red-team a running LLM app for prompt injection / data exfiltration |
| supply-chain-watchdog | n/a | base + Trivy/osv-scanner | Runtime dependency + egress monitoring inside a pipeline |

## Isolation principles

- The sandbox runs on an internal Docker network with no egress by default; the agent
  opts into narrow, logged egress only when a specific check requires it.
- The untrusted target is pinned to a commit and never handed host credentials.
- Nothing dynamic is centralized into the shared Tier-1 images. Each agent is deployed and
  run in the operator's own isolation.

The key decisions above (the tier boundary, the agent anatomy, the sandbox hardening, the
flavor unit, and the move from static to dynamic escalation) are recorded as [ADRs](docs/adr/).

## Status

Foundation plus three built flavors: mcp-reviewer
([`agents/mcp-reviewer/`](agents/mcp-reviewer/)), skill-auditor
([`agents/skill-auditor/`](agents/skill-auditor/)), and mcp-gateway
([`agents/mcp-gateway/`](agents/mcp-gateway/), now complete: it wraps the pinned `pipelock` engine, compiles a
review into runtime policy, renders a second OPA/Rego adapter, and gates a real pinned server end-to-end).
Both review flavors now have their brains:
[`mcp-security-review`](https://github.com/garymike/skills/tree/main/skills/mcp-security-review) drives
`mcp-reviewer`, and
[`skill-security-review`](https://github.com/garymike/skills/tree/main/skills/skill-security-review) drives
`skill-auditor`. The remaining flavors (llm-redteam, supply-chain-watchdog) are designed but not yet built.

## Relationship to the rest of the platform

- [security-workflows](https://github.com/garymike/security-workflows) (Tier 1) provides
  the signed toolbox images these agents use as their tool-belt, and the reusable workflows
  this repo dogfoods in CI.
- [garymike/skills](https://github.com/garymike/skills) provides the methodology skills
  the agents run.
