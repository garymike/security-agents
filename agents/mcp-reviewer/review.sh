#!/usr/bin/env bash
# mcp-reviewer — orchestrate the STATIC pass of an MCP-server review with the Tier-1 toolbox.
# The mcp-security-review skill (garymike/skills) is the methodology; this wires the tools.
# The dynamic pass runs in the sandbox (see README.md) — never from this script.
#
# Usage: ./review.sh <name>       where the target is cloned at ./targets/<name>
set -euo pipefail
cd "$(dirname "$0")"

NAME="${1:?usage: ./review.sh <name>  (clone the target into ./targets/<name> first)}"
[ -d "targets/$NAME" ] || { echo "error: ./targets/$NAME not found — clone the pinned target there first" >&2; exit 1; }
mkdir -p out

echo "== Static analysis: ./targets/$NAME (toolbox, no network) =="
tb() { docker compose run --rm toolbox "$@"; }

echo "--- secrets (betterleaks) ---";        tb betterleaks dir "/target/$NAME" --no-banner --redact || true
echo "--- dependency CVEs (osv-scanner) ---"; tb osv-scanner scan --recursive "/target/$NAME" || true
echo "--- MCP tool-surface (snyk-agent-scan) ---"; tb snyk-agent-scan "/target/$NAME" || true
echo "--- SBOM (syft) ---";                   tb syft "dir:/target/$NAME" -o spdx-json > "out/$NAME.sbom.spdx.json" || true
echo "SBOM written to out/$NAME.sbom.spdx.json"

cat <<'NEXT'

== Next: dynamic pass (egress-gated sandbox) ==
  docker compose up -d sandbox
  docker compose exec sandbox <the server's start command>   # observe startup, fs/network reach, subprocesses
  docker compose down
The sandbox has NO egress and NO host credentials (see compose.yml).

== Then: report ==
  Feed the static + dynamic findings into the mcp-security-review skill to produce the
  risk-rated assessment.json + report.
NEXT
