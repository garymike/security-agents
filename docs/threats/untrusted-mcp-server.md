# Threat: an untrusted MCP server at runtime

**Grounding:** OWASP MCP Top 10 (tool poisoning, excessive agency, data exfiltration); the runtime
counterpart to the static skill surface. The reviews come from the `mcp-security-review` methodology
in [garymike/skills](https://github.com/garymike/skills).
**Surface:** MCP runtime (the JSON-RPC stream between the agent and an MCP server).
**Status:** Covered, enforced (alert-only by default, block on opt-in).

## The attack
An MCP server the agent connects to can exfiltrate data to an attacker host, or expose destructive
or over-permissioned tools that the agent then calls. A review can flag this, but a review is a
document; nothing stops the server at runtime.

## Why tooling misses it
Reviews and scanners produce findings, not controls. The gap between "we reviewed it" and "it is
constrained at runtime" is where the damage happens.

## How this platform stops it
The [assess-to-enforce gateway](../../agents/mcp-gateway) compiles the review's verdict into a
runtime firewall policy through an engine-neutral [contract](../mcp-policy-contract.md): only the
egress hosts and tools the review approved pass, everything else is blocked (or alerted, by
default), with signed action receipts. Two adapters, pipelock and OPA, reach the same allow/deny, so
the contract is engine-neutral rather than a single-adapter fiction.

## Proof
- End-to-end example against a real pinned server:
  [`github-mcp-server`](../../agents/mcp-gateway/examples/github-mcp-server). Only `api.github.com`
  and the approved tools pass; `exfil.attacker.test` and `delete_file` are blocked, in both engines.
- Proofs, all run in CI: [`verify.sh`](../../agents/mcp-gateway/examples/github-mcp-server/verify.sh),
  [`proof.sh`](../../agents/mcp-gateway/compiler/proof.sh),
  [`rego-proof.sh`](../../agents/mcp-gateway/compiler/rego-proof.sh).
- Decision: [ADR-0007](../adr/0007-runtime-gateway-and-assess-enforce.md).

## Honest residual
The gateway governs a server routed through it; a server the client launches directly bypasses it,
so it pairs with review-before-trust. It runs alert-only by default, so enforcement is an opt-in
posture, not automatic.
