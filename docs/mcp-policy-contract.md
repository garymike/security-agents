# The MCP runtime-policy contract (`mcp-runtime-policy/v0.1`)

A small, **engine-agnostic** schema that an MCP security *review* compiles into, and that a runtime gateway
*enforces from*. It is the ownable core of the [`mcp-gateway`](../agents/mcp-gateway) flavor: the review's
verdict becomes an enforced policy, **every rule traceable to a finding** — the one thing no gateway vendor
does, because they all start from hand-authored YAML.

```
assessment.json  ──►  policy contract (this schema)  ──►  adapter  ──►  gateway config
(mcp-reviewer)        (engine-agnostic)                   (pipelock)     (pipelock.yaml)
                                                          (ContextForge) (OPA/Rego — built ✓)
```

The contract is why picking an engine costs little (see [ADR-0007](adr/0007-runtime-gateway-and-assess-enforce.md)):
the compiler targets *this*, and a thin per-engine adapter renders it. **Two adapters exist:**
[pipelock](https://github.com/luckyPipewrench/pipelock) (local firewall) and **OPA/Rego** (the ContextForge
enterprise tier). [`rego-proof.sh`](../agents/mcp-gateway/compiler/rego-proof.sh) shows OPA reaching the *same*
allow/deny as pipelock from the same contract — so the neutrality is **proven, not asserted**.

## Schema

```jsonc
{
  "contract": "mcp-runtime-policy/v0.1",
  "server": {
    "name":     "acme-notes-mcp",
    "launch":   { "command": "node", "args": ["/opt/acme-notes-mcp/dist/server.js"] },
    "sha256":   "<hex>",           // integrity pin; the gateway verifies before spawn
    "approved": true
  },
  "tools":  [                       // per-tool verdict from the review
    { "name": "run_shell", "action": "deny",  "reason": "arbitrary command execution" },
    { "name": "http_fetch","action": "warn",  "reason": "outbound requests" },
    { "name": "read_note", "action": "allow", "reason": "" }
  ],
  "egress": { "allow": ["api.acme.example"], "deny_private": true, "block_metadata": true },
  "dlp":    { "block_on": ["aws-access-key", "github-token", "private-key"] },
  "provenance": { "assessment_id": "rev-...", "reviewer": "mcp-reviewer", "timestamp": "<iso8601>" }
}
```

- **`tools[].action`** — `allow` (no rule), `warn` (always alert), `deny` (block in enforce, alert in observe).
- **`egress.allow`** — the destinations the review *observed*; least privilege from evidence.
- **`provenance`** — carried into every generated config's header, so a policy rule traces back to its review.

## Posture: two renderings from one contract

Alert-only is the shipped default; enforce is the opt-in flip (plan Q4/Q4b). The **same contract** renders both:

| | observe (default) | enforce (opt-in) |
|---|---|---|
| pipelock `mode` | `balanced` (egress **monitored**) | `strict` (egress **allowlist-enforced**) |
| section `action` | `warn` | `block` |
| a `deny` tool | `warn` (alerts) | `block` |
| a call to an unapproved host | allowed + receipt | **blocked** at the allowlist layer |

## Compiler rules (non-negotiable)

- **Absolute-path launch, never a package runner.** `server.launch.command` may not be `npx`/`uvx`/`bunx`/etc.;
  hash-pinning only covers the runner binary, not the code it fetches at runtime. The compiler errors out.
- **Fail-closed rendering.** Generated configs must pass pipelock's strict, version-coupled schema validator —
  the image is digest-pinned so the schema and binary move together.

## Proof

[`agents/mcp-gateway/compiler/proof.sh`](../agents/mcp-gateway/compiler/proof.sh) asserts, on every run: the
generated configs validate; in **enforce** the policy **blocks an egress the review never approved** while
**observe alerts-only**; and the package-runner guard fires. That is *scan → detonate → **enforce***, proven
continuously.

[`rego-proof.sh`](../agents/mcp-gateway/compiler/rego-proof.sh) asserts the **OPA/Rego adapter** reaches the
*same* allow/deny from the *same* contract (default-deny; review-approved tools + observed egress only) — so the
contract is genuinely engine-neutral, not a single-adapter fiction. Both run in CI
([`mcp-gateway-proof.yml`](../.github/workflows/mcp-gateway-proof.yml)).
