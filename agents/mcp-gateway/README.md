# mcp-gateway agent

Govern an **MCP server at runtime** — a local firewall on the JSON-RPC stream that turns a security
*review* into an *enforced* policy. This is the operations tier the `mcp-reviewer` assessment already
assumes: it closes the ladder **scan → detonate → enforce**.

- **Brains:** the **assess→enforce [compiler](compiler/)** — turns an [`mcp-reviewer`](../mcp-reviewer)
  `assessment.json` into a runtime policy (every rule traceable to a review finding) via the engine-agnostic
  [policy contract](../../docs/mcp-policy-contract.md). The hand-authored [`config/`](config) policies are the
  baseline; `compiler/compile.py` generates them from a review.
- **Hands:** [**pipelock**](https://github.com/luckyPipewrench/pipelock) — an adopted, **pinned, signed**
  firewall engine (Apache-2.0). We wrap it unmodified as separate plumbing; we do not fork it
  (aggregator, not a fork). It scans HTTP/WebSocket/MCP traffic for exfiltration, injection, and SSRF, and
  emits **signed action receipts** — verifiable audit evidence from *outside* the agent.
- **Body:** runs locally on **any OCI runtime** — `docker` → `podman` → **`wslc`** (no Docker Desktop
  required), off one digest-pinned image, via [`gateway.sh`](gateway.sh). pipelock adds its own process
  sandbox (Landlock/seccomp) for containment.

## Posture — alert-only by default, enforce is opt-in

Detection-mode-first, like a WAF or AppArmor: a flagged call is **recorded (signed receipt), not blocked**,
so the gateway earns trust before it can break a workflow.

| File | `action` | Behavior |
| --- | --- | --- |
| [`config/gateway.observe.yaml`](config/gateway.observe.yaml) | `warn` | **Default.** Alert + receipt, nothing blocked. |
| [`config/gateway.enforce.yaml`](config/gateway.enforce.yaml) | `block` | Opt-in. Fail-closed block + receipt. The CI proof-fixture (Milestone C) runs here. |

## Run it

```bash
# Alert-only (default) — validate the policy and show a content-aware block, on any runtime:
./gateway.sh                 # docker -> podman -> wslc, auto-selected
./gateway.sh enforce         # same, in blocking mode

# Docker/Podman users can also use compose (wslc has no compose yet):
docker compose run --rm gateway
```

To actually mediate a **stdio MCP server**, the *client* launches the proxy instead of the server — put this
in the client's MCP config:

```
pipelock mcp proxy --config /config/gateway.observe.yaml -- <server start command>
```

### Compile a review into policy

The [compiler](compiler/) turns an `mcp-reviewer` `assessment.json` into the two policies above — every rule
traceable to a review finding (the [policy contract](../../docs/mcp-policy-contract.md)):

```bash
python compiler/compile.py compiler/example-assessment.json ./config
# -> config/{policy-contract.json, gateway.observe.yaml, gateway.enforce.yaml, policy.rego}
bash compiler/proof.sh        # pipelock: enforce blocks review-unapproved egress, observe alerts-only
bash compiler/rego-proof.sh   # OPA/Rego adapter reaches the SAME allow/deny -> the contract is engine-neutral
```

**Real target:** [`examples/github-mcp-server/`](examples/github-mcp-server) runs a real, pinned server
(`github/github-mcp-server`) end-to-end — the compiled policy allows only `api.github.com` + the approved tools
and blocks the rest, in both engines (`verify.sh`, run in CI).

## Safety & honest residual

- The gateway only governs an MCP server **routed through it**. A server the client launches *directly*
  bypasses it — so this pairs with `mcp-reviewer` (review before you trust) exactly as the skill-gate pairs
  with review-before-install. It closes the mediated path and is honest about the rest.
- **Resolve server launch commands to absolute local paths, never package runners** (`npx`/`uvx`/`bunx`):
  hash-pinning only covers the runner binary, not the code it fetches at runtime. The compiler enforces this.
- The image is **pinned by digest** because pipelock's config schema is **version-coupled** to the binary —
  `:latest` would drift and fail the strict, fail-closed config parser. Verify provenance with
  `gh attestation verify` / `cosign` before trusting a new pin.

## Status

- **Milestone B:** wrap the pinned engine + authored alert-only/enforce policies, runnable on any runtime. ✅
- **Milestone C:** the assess→enforce [compiler](compiler/) (`assessment.json` → policy) + an enforce-mode CI
  [proof-fixture](compiler/proof.sh) asserting *review-unapproved egress → generated policy blocks it*, plus the
  [neutral policy-contract spec](../../docs/mcp-policy-contract.md). ✅
- **Milestone D:** the **OPA/Rego adapter** (ContextForge enterprise tier) — a second adapter of the same
  contract, with [`rego-proof.sh`](compiler/rego-proof.sh) proving OPA reaches the same allow/deny (the contract
  is engine-neutral, not a single-adapter fiction). ✅
- **Next:** wiring a real `mcp-reviewer` run end-to-end (review → assessment.json → compile → enforce).
