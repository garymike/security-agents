# mcp-gateway agent

Govern an **MCP server at runtime** — a local firewall on the JSON-RPC stream that turns a security
*review* into an *enforced* policy. This is the operations tier the `mcp-reviewer` assessment already
assumes: it closes the ladder **scan → detonate → enforce**.

- **Brains:** an **assess→enforce compiler** (Milestone C) that turns an [`mcp-reviewer`](../mcp-reviewer)
  `assessment.json` into a runtime policy — every rule traceable to a review finding. *Until it lands, the
  policy in [`config/`](config) is hand-authored.*
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

- **Milestone B (this):** wrap the pinned engine + authored alert-only/enforce policies, runnable on any
  runtime. ✅
- **Milestone C (next):** the assess→enforce compiler (`assessment.json` → policy) + an enforce-mode CI
  proof-fixture asserting *review-flagged X → generated policy blocks X*, and the neutral policy-contract spec.
