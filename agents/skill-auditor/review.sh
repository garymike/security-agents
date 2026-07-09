#!/usr/bin/env bash
# skill-auditor — orchestrate the STATIC pass of an agent-skill review with the Tier-1 toolbox.
# Methodology: the skill-security-review method (to be authored, mirrors mcp-security-review);
# until then, security-workflows docs/threat-model.md is the coverage anchor.
# The dynamic pass — EXECUTING the skill's bundled scripts under observation — runs in the
# sandbox (see README.md), never from this script.
#
# Usage: ./review.sh <name>       where the skill is cloned at ./targets/<name>
set -euo pipefail
cd "$(dirname "$0")"

NAME="${1:?usage: ./review.sh <name>  (clone the skill into ./targets/<name> first)}"
[ -d "targets/$NAME" ] || { echo "error: ./targets/$NAME not found — clone the pinned skill there first" >&2; exit 1; }

echo "== Static analysis: ./targets/$NAME (toolbox, no network) =="
tb() { docker compose run --rm toolbox "$@"; }

echo "--- developer-execution surface (test-file gate) ---"
tb skill-testfile-gate "/target/$NAME" || true
echo "--- agent-execution surface (SkillSpector, static) ---"
tb skillspector scan "/target/$NAME" --no-llm || true

cat <<'NEXT'

== Next: dynamic pass (egress-gated sandbox) ==
The static gates flag the surfaces; the sandbox EXECUTES them to catch packed / self-
extracting payloads (e.g. SkillCloak) that evade static scanners:
  docker compose up -d sandbox
  # run each bundled script the skill ships (scripts/*, hooks, examples) and observe:
  docker compose exec sandbox bash -lc '<the skill'\''s bundled script>'
  docker compose down
Observe: filesystem writes, outbound network ATTEMPTS (blocked = the signal), subprocesses.
The sandbox has NO egress and NO host credentials (see compose.yml).

Optional (deployment has model access): re-run SkillSpector WITH the LLM analysis
(drop --no-llm) for the fuller agent-execution-surface read the static CI pass can't do.

== Then: report ==
  Feed the static + dynamic findings into the skill-security-review method to produce the
  risk-rated assessment.json + report.
NEXT
