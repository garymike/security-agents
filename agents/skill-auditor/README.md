# skill-auditor agent

Review an untrusted agent skill end-to-end: both surfaces a skill can attack from,
including the one no published skill scanner covers.

- **Brains:** the [`skill-security-review`](https://github.com/garymike/skills/tree/main/skills/skill-security-review)
  method, the skill-side sibling of
  [`mcp-security-review`](https://github.com/garymike/skills/tree/main/skills/mcp-security-review). It drives the
  two-surface review, factor scoring, and the schema-valid `assessment.json`; security-workflows
  [`docs/threat-model.md`](https://github.com/garymike/security-workflows/blob/main/docs/threat-model.md) remains
  the standards anchor.
- **Hands:** the signed `skill-audit-toolbox` image (SkillSpector + a first-party
  test-file gate).
- **Body:** an egress-gated, credential-free sandbox to actually execute the skill's
  bundled scripts and observe them. See [`compose.yml`](compose.yml) and [`sandbox/`](sandbox/).

## Two surfaces

A skill is code that runs in two places, and each has its own attack surface:

| Surface | Who executes it | Static tool |
|---|---|---|
| **Agent-execution** | the model, when the skill loads (prompt injection, tool poisoning, data exfil, excessive agency) | `skillspector scan … --no-llm` |
| **Developer-execution** | the developer's machine, when a bundled script/test/hook runs (the Gecko test-file vector) | `skill-testfile-gate` |

The static gates flag these surfaces. This agent adds the dynamic pass: run the
bundled scripts in isolation to catch packed / self-extracting payloads (e.g. SkillCloak)
that evade static scanners.

## Review flow

The `skill-security-review` method drives these steps; this agent wires the tools:

1. **Identify & pin.** Clone the skill into `./targets/<name>` at a specific commit (record
   the SHA).
2. **Static analysis** (no network): the test-file gate (developer surface) + SkillSpector
   `--no-llm` (agent surface). The gate emits SARIF and flags the auto-executed files as
   detonation candidates for step 3, the static-to-dynamic escalation ([ADR-0005](../../docs/adr/0005-static-dynamic-escalation.md)).
3. **Dynamic analysis** (the Tier-2 addition): execute each bundled script the skill ships
   (`scripts/`, hooks, examples) in the sandbox and observe filesystem writes, outbound
   network attempts (blocked, the attempt is the signal), and subprocesses, with no
   egress and no host credentials. Optionally re-run SkillSpector with the LLM analysis
   (drop `--no-llm`) for the fuller read CI can't do.
4. **Report:** feed findings into the method to produce the risk-rated `assessment.json` +
   report.

**Worked example:** [`examples/changelog-helper/`](examples/changelog-helper) runs this chain
end to end against a real (if illustrative) skill, a clean `SKILL.md` bundled with a malicious
git hook, and asserts the gate blocks while SkillSpector only advises, with the resulting
schema-valid `assessment.json` (`verify.sh`, run in CI).

## Run it

```bash
# 1. Clone the skill you want to review (pin to a commit)
git clone --depth 1 <target-repo> targets/example-skill

# 2. Static pass (toolbox, no network)
./review.sh example-skill

# 3. Dynamic pass: run the skill's bundled scripts under observation
docker compose up -d sandbox
docker compose exec sandbox bash -lc '<the skill'\''s bundled script>'   # e.g. scripts/setup.sh
# ... observe, then:
docker compose down
```

## Safety

The sandbox (`compose.yml`) runs on an internal network with no egress, as a non-root
user, `read_only` with `cap_drop: [ALL]` and `no-new-privileges`. The skill is mounted
read-only and never given host credentials. Executing a skill's scripts is exactly the
developer-execution risk under review, so it only ever happens in here, never on the host.

> Pin the toolbox image by digest (`…@sha256:…`) in `compose.yml` for a real review;
> `:latest` here is for readability. Verify it first with `cosign verify …`.
