#!/usr/bin/env bash
# skill-auditor — orchestrate a skill review: STATIC triage with the Tier-1 toolbox, then a DYNAMIC
# pass that detonates the exact files the static gate flagged, in the egress-gated sandbox.
#
# The escalation ladder (ADR-0005): static rules are a cheap pre-filter and are evadable (SkillCloak,
# arXiv 2607.02357), so the gate's flagged files become the *detonation candidates* the sandbox
# confirms by execution. Methodology: the skill-security-review method (to be authored, mirrors
# mcp-security-review); until then, security-workflows docs/threat-model.md is the coverage anchor.
#
# Usage: ./review.sh <name>       where the skill is cloned at ./targets/<name>
set -euo pipefail
cd "$(dirname "$0")"

NAME="${1:?usage: ./review.sh <name>  (clone the skill into ./targets/<name> first)}"
[ -d "targets/$NAME" ] || { echo "error: ./targets/$NAME not found — clone the pinned skill there first" >&2; exit 1; }
mkdir -p out && chmod 777 out 2>/dev/null || true

echo "== 1. Static triage: ./targets/$NAME (toolbox, no network) =="
tb() { docker compose run --rm "$@"; }

echo "--- developer-execution surface (test-file gate) — emits SARIF, flags detonation candidates ---"
gate_out=$(tb -v "$PWD/out:/out" -e GATE_SARIF=/out/gate.sarif toolbox skill-testfile-gate "/target/$NAME" 2>&1) || true
echo "$gate_out"

echo "--- agent-execution surface (SkillSpector, static) ---"
tb toolbox skillspector scan "/target/$NAME" --no-llm || true

# The static gate's flagged files (malice + suspicious) ARE the escalation set (ADR-0005).
candidates=$(printf '%s\n' "$gate_out" | sed -nE 's/.*\[(malice|suspicious)\] ([^ :]+):[0-9]+.*/\2/p' | sort -u)

echo ""
echo "== 2. Escalation: detonation candidates from the static pass =="
if [ -n "$candidates" ]; then
  echo "The gate flagged these auto-executed files. Static rules are evadable, so CONFIRM each"
  echo "dynamically in the sandbox (step 3):"
  printf '  %s\n' $candidates
else
  echo "No malice/suspicious static findings. Still worth a sandbox run for packed / self-extracting"
  echo "payloads the static layer cannot read (opaque blobs) before trusting the skill."
fi
[ -s out/gate.sarif ] && echo "(machine-readable findings: ./out/gate.sarif — SARIF)"

cat <<'NEXT'

== 3. Dynamic pass (egress-gated sandbox) ==
  docker compose up -d sandbox
  # detonate each candidate above (or every bundled script the skill ships) and observe:
  docker compose exec sandbox bash -lc '<run the candidate / the skill'\''s script>'
  docker compose down
Observe: filesystem writes, outbound network ATTEMPTS (blocked = the signal), subprocesses.
The sandbox has NO egress and NO host credentials (see compose.yml).

Optional (deployment has model access): re-run SkillSpector WITH the LLM (drop --no-llm).

== 4. Report ==
  Feed the static findings (./out/gate.sarif) + the dynamic observations into the
  skill-security-review method to produce the risk-rated assessment.json + report.
NEXT
