# 7. The runtime gateway: adopt pipelock, compile reviews into policy, alert-only by default

## Status
Accepted

## Context
The escalation ladder ([ADR-0005](0005-static-dynamic-escalation.md)) ends at dynamic detonation, a review
verdict. But an MCP server you keep using needs governance at runtime, not just at review time; the
`mcp-security-review` methodology already assumes gateway logs exist. The MCP-gateway space is crowded (Docker
MCP Gateway, IBM ContextForge, Lasso, pipelock, GitHub-native allowlists), so building a gateway would break the
aggregator principle: adopt pinned upstream tools, never re-implement.

## Decision
Add a runtime tier as the `mcp-gateway` flavor ([ADR-0004](0004-flavor-is-the-unit.md)) that completes the
ladder from scan to detonate to enforce. Three sub-decisions:

1. **Adopt, don't build.** Wrap [pipelock](https://github.com/luckyPipewrench/pipelock) (Apache-2.0,
   local-first, CNCF-Landscape, signed + SLSA/SBOM) as unmodified plumbing, pinned by digest. It consumes
   a declarative YAML policy, the compile target. Chosen over ressl/mcp-firewall (abandoned, AGPL), Bifrost (an
   LLM routing gateway, not a firewall), and ContextForge (K8s-heavy, kept as a future enterprise Rego/Cedar
   adapter behind the same contract).
2. **The ownable layer is the compiler, not the gateway.** An assess-to-enforce compiler turns an
   [`mcp-reviewer`](../../agents/mcp-reviewer) `assessment.json` into the policy, with every rule traceable to a
   review finding, behind a neutral, engine-agnostic policy contract so the adapter is swappable. No vendor
   ships scan-to-enforce as a closed loop; they all start from hand-authored YAML.
3. **Alert-only by default; enforce is opt-in.** A `mode`/`action` dial (`warn` vs `block`). Detection-mode
   first, like a WAF or AppArmor complain-mode, earning trust before blocking. The CI proof-fixture still runs in
   enforce mode, so scan-to-enforce stays demonstrable even though nothing blocks by default.

## Consequences
The gateway is a deployment and operations component that reuses the `mcp-reviewer` egress-gated sandbox
([ADR-0003](0003-egress-gated-sandbox.md)) for its observe phase, and stays a true aggregator: we author the
compiler, not the proxy. It governs only servers routed through it, so it pairs with
review-before-trust exactly as the skill-gate pairs with review-before-install. Because pipelock's config schema
is version-coupled to the binary, the image is digest-pinned and the policy targets the matching release
tag; a drifting `:latest` would fail the strict, fail-closed config parser.
