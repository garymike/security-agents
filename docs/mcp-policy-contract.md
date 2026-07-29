# The MCP runtime-policy contract (`mcp-runtime-policy/v0.2`)

A small, engine-agnostic schema that an MCP security review compiles into, and that a runtime gateway
enforces from. It is the ownable core of the [`mcp-gateway`](../agents/mcp-gateway) flavor: the review's
verdict becomes an enforced policy, with every rule traceable to a finding. No gateway vendor
does that, because they all start from hand-authored YAML.

```
assessment.json  ──►  policy contract (this schema)  ──►  adapter  ──►  gateway config
(mcp-reviewer)        (engine-agnostic)                   (pipelock)     (pipelock.yaml)
                                                          (OPA/Rego, built ✓)
```

The contract is why picking an engine costs little (see [ADR-0007](adr/0007-runtime-gateway-and-assess-enforce.md)):
the compiler targets this contract, and a thin per-engine adapter renders it. Two adapters exist:
[pipelock](https://github.com/luckyPipewrench/pipelock) (local firewall) and a self-authored OPA/Rego
adapter (the policy language an enterprise gateway like ContextForge would also use).
[`rego-proof.sh`](../agents/mcp-gateway/compiler/rego-proof.sh) shows OPA reaching the same
allow/deny as pipelock from the same contract, so the neutrality is proven rather than asserted.

## Schema

```jsonc
{
  "contract": "mcp-runtime-policy/v0.2",
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
  "residuals": [                    // review findings NO gateway rule can enforce
    { "finding": "handle_security not established",
      "why_unenforceable": "internal server state; a traffic gateway never observes it",
      "compensating_control": "source review before approval; re-check on version bump" }
  ],
  "provenance": { "assessment_id": "rev-...", "reviewer": "mcp-reviewer", "timestamp": "<iso8601>" }
}
```

- `tools[].action`: `allow` (no rule), `warn` (always alert), `deny` (block in enforce, alert in observe).
- `egress.allow`: the destinations the review observed; least privilege from evidence.
- `provenance`: carried into every generated config's header, so a policy rule traces back to its review.
- `residuals`: findings the review raised that **no rule can enforce**, carried into every generated
  config as header comments. Optional and additive, so a v0.1 assessment compiles unchanged.

## Posture: two renderings from one contract

Alert-only is the shipped default; enforce is the opt-in flip (plan Q4/Q4b). The same contract renders both:

| | observe (default) | enforce (opt-in) |
|---|---|---|
| pipelock `mode` | `balanced` (egress **monitored**) | `strict` (egress **allowlist-enforced**) |
| section `action` | `warn` | `block` |
| a `deny` tool | `warn` (alerts) | `block` |
| a call to an unapproved host | allowed + receipt | **blocked** at the allowlist layer |

## Compiler rules (non-negotiable)

- **Absolute-path launch, never a package runner.** `server.launch.command` may not be `npx`/`uvx`/`bunx`/etc.;
  hash-pinning only covers the runner binary, not the code it fetches at runtime. The compiler errors out.
- **Fail-closed rendering.** Generated configs must pass pipelock's strict, version-coupled schema validator,
  and the image is digest-pinned so the schema and binary move together.

## Proof

[`agents/mcp-gateway/compiler/proof.sh`](../agents/mcp-gateway/compiler/proof.sh) asserts, on every run: the
generated configs validate; in enforce the policy blocks an egress the review never approved while
observe alerts only; and the package-runner guard fires. That is the whole loop, scan to detonate to enforce, proven
continuously.

[`rego-proof.sh`](../agents/mcp-gateway/compiler/rego-proof.sh) asserts the OPA/Rego adapter reaches the
same allow/deny from the same contract (default-deny; review-approved tools + observed egress only), so the
contract is genuinely engine-neutral, not a single-adapter fiction. Both run in CI
([`mcp-gateway-proof.yml`](../.github/workflows/mcp-gateway-proof.yml)).

## Where enforcement stops: the 2026-07-28 surfaces

MCP's 2026-07-28 revision added surfaces the assess tier now scores
([`mcp-security-review`](https://github.com/garymike/skills) records `mcp_apps_status`, `tasks_status`, and
`handle_security`). Not all of them reach the enforcement tier, and saying which is the point of
`residuals`. The triage below was verified against pipelock's own configuration documentation at the
pinned 3.0.0, and re-checked through 3.2.0.

| Assess-tier finding | Enforceable here? | How, or why not |
|---|---|---|
| `mcp_apps_status: reviewed_unsafe` | **Yes, today** | The risky artifact is a `ui://` resource declared by a specific tool via `_meta.ui.resourceUri`. That tool is name-matchable, so give it `action: deny` in `tools[]`. No new vocabulary needed. |
| `tasks_status: verified_unbounded` | **Partly** | Tools that *spawn* tasks are name-matchable and can be denied or warned. Method-granular control over `tasks/get` and `tasks/cancel` is **not** expressible: `mcp_tool_policy` matches tool names (`tool_pattern`), never JSON-RPC methods, and `request_policy` matches HTTP route (host, method, path), while MCP JSON-RPC is uniformly `POST` to one endpoint. Rate limits are per-domain and per-agent, not per-method. Record the unreachable part as a residual. |
| `handle_security: verified_broken` | **No** | Whether cross-call handles are CSPRNG-generated, user-bound and expiring is internal server state. A traffic gateway never sees it. Pure residual: it needs source review or vendor attestation before approval. |

Two things follow, and both are deliberate.

**The contract records what it cannot do.** A generated policy that silently omitted the third row would
read as full coverage of a review that found three problems. Every generated config now carries its
residuals in the header, next to the rules, so an operator reading the policy sees the boundary rather than
inferring it.

**An engine limitation is a residual, not a contract change.** The Tasks gap is pipelock's, not the
contract's: the neutral contract could express a method-level rule the day an adapter can render one. That
is the argument for an engine-agnostic contract in the first place, so it is recorded here as a watch item
rather than worked around.
