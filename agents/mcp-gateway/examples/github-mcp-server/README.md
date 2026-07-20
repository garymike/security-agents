# End-to-end example: gating `github-mcp-server`

A real, pinned MCP server run through the whole chain (review, then `assessment.json`, then compile, then
enforce), showing the gate allow exactly what the server legitimately needs and block the rest, across
both engines.

## The target (pinned)

- **[github/github-mcp-server](https://github.com/github/github-mcp-server)** @ `c36e4e4493c7` (2026-07-10), MIT, ~31k★.
- **Legitimate egress:** `api.github.com` (the default GitHub API host, `pkg/utils/api.go`).
- **Integrity pin:** the distributed container image digest `ghcr.io/github/github-mcp-server@sha256:e25564dc…`.
- **Tools:** ~100; [`assessment.json`](assessment.json) reviews a representative subset (reads are `allow`,
  mutations are `warn`, destructive or autonomous are `deny`).

> Manifest-based: verdicts come from reviewing the server's documented tools and known egress, not a live
> sandbox detonation (that is the `mcp-reviewer` dynamic pass; it needs `docker compose`).

## The chain

```
assessment.json ──► compile.py ──► mcp-runtime-policy/v0.1 ──► pipelock (gateway.{observe,enforce}.yaml)
(a review of a                                            └─► OPA/Rego  (policy.rego)
 real pinned server)
```

The compiler emits (from the 11 reviewed tools + 1 approved host):

```rego
# policy.rego  (OPA / ContextForge adapter)
default allow := false
approved_tools := {"get_me", "get_file_contents", "get_commit", "get_commits", "get_repository_tree",
                   "get_diff", "create_branch", "create_or_update_file", "create_pull_request"}
allowed_hosts  := {"api.github.com"}
```
```yaml
# gateway.enforce.yaml  (pipelock adapter)
api_allowlist: ["api.github.com"]
mcp_tool_policy:
  rules:
    - { tool_pattern: "(?i)^delete_file$",                    action: block }   # destructive
    - { tool_pattern: "(?i)^create_pull_request_with_copilot$", action: block } # autonomous agent action
    - { tool_pattern: "(?i)^create_or_update_file$",          action: warn }    # mutation, alerted
```

## Measured verdicts (this is what actually happens)

**pipelock** (egress, via `pipelock explain`, DNS-free):

| Request | observe (default, alert-only) | enforce |
|---|---|---|
| egress to `api.github.com` (approved) | allowed | **ALLOWED** |
| egress to `exfil.attacker.test` (not approved) | allowed + signed receipt | **BLOCKED** (`allowlist`) |

**OPA/Rego** (default-deny PDP, via `opa eval`):

| Query | Verdict |
|---|---|
| tool `get_file_contents` (approved) | `allow = true` |
| tool `delete_file` (denied) | `allow = false` |
| egress `api.github.com` | `allow = true` |
| egress `exfil.attacker.test` | `allow = false` |

One review, two engines, the same least-privilege outcome, and only `api.github.com` gets through, because
that is the only host the review observed. Everything traces back to a finding in [`assessment.json`](assessment.json).

## Reproduce / verify

```bash
bash verify.sh          # regenerates the policies and re-asserts every verdict above (docker/podman/wslc)

# or by hand:
python ../../compiler/compile.py assessment.json /tmp/gh
docker run --rm -v /tmp/gh:/config:ro ghcr.io/luckypipewrench/pipelock:3.0.0 \
  explain --config /config/gateway.enforce.yaml https://exfil.attacker.test/x     # -> BLOCKED (allowlist)
```

`verify.sh` runs in CI ([`mcp-gateway-proof.yml`](../../../../.github/workflows/mcp-gateway-proof.yml)), so this
real-target example stays true on every change.
