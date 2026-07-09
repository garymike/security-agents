# mcp-reviewer agent

Assess an **untrusted MCP server** end-to-end — the static surface *and* the dynamic
behavior that Tier-1 static scanning deliberately can't touch.

- **Brains:** the [`mcp-security-review`](https://github.com/garymike/skills) skill (the
  methodology — identify, inspect, score, report).
- **Hands:** the signed `mcp-review-toolbox` image (betterleaks, trufflehog, osv-scanner,
  syft, pip-audit, snyk-agent-scan).
- **Body:** an egress-gated, credential-free sandbox to actually *run* the server and observe
  it — see [`compose.yml`](compose.yml) and [`sandbox/`](sandbox/).

## Review flow

The `mcp-security-review` skill drives these steps; this agent wires the tools:

1. **Identify & pin.** Clone the target into `./targets/<name>` at a specific commit (record
   the SHA — it's the point-in-time anchor).
2. **Static analysis** (no network): run the toolbox scanners over the source — secrets,
   dependency CVEs, the tool-definition surface, SBOM.
3. **Dynamic analysis** (the Tier-2 addition): run the server in the sandbox and observe
   startup behavior, filesystem/network reach, subprocess + dynamic-code use — with **no
   egress and no host credentials**.
4. **Report:** feed findings into the skill to produce the risk-rated `assessment.json` +
   report.

## Run it

```bash
# 1. Clone the target you want to review (pin to a commit)
git clone --depth 1 <target-repo> targets/example-mcp

# 2. Static pass (toolbox, no network)
./review.sh example-mcp

# 3. Dynamic pass — bring up the isolated sandbox and run the server under observation
docker compose up -d sandbox
docker compose exec sandbox <the server's start command>   # e.g. npx <pkg>, python -m server
# ... observe, then:
docker compose down
```

## Safety

The sandbox (`compose.yml`) runs on an **internal network with no egress**, as a **non-root**
user, `read_only` with `cap_drop: [ALL]` and `no-new-privileges`. The target is mounted
**read-only** and never given host credentials. Escaping any of that is a critical finding
(see the repo `SECURITY.md`).

> Pin the toolbox image by **digest** (`…@sha256:…`) in `compose.yml` for a real review;
> `:latest` here is for readability. Verify it first with `cosign verify …`.
