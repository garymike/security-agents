#!/usr/bin/env bash
# rego-proof.sh — proves the OPA/Rego adapter (the ContextForge / enterprise-tier rendering) enforces the SAME
# neutral contract as the pipelock adapter: default-deny, allow only a review-approved tool or an observed egress
# host. Two engines, one mcp-runtime-policy/v0.1 contract, same allow/deny -> the contract is engine-neutral, not
# a single-adapter fiction. The egress case is the cross-engine equivalence (pipelock strict-mode allowlist blocks
# the same unapproved host; see proof.sh).
#
# Runtime-agnostic: docker -> podman -> wslc (health-checked), OPA pinned by digest.
set -uo pipefail
cd "$(dirname "$0")"

OPA_IMAGE="${OPA_IMAGE:-docker.io/openpolicyagent/opa:1.18.2@sha256:cba27d3c6af2feba1e4d6e6b5e24df5b53db332420d4148a90acccd12efae6ed}"
QUERY="data.mcp.gateway.authz.allow"

runtime_ok(){ case "${1##*/}" in docker*|podman*) "$1" info >/dev/null 2>&1;; wslc*) "$1" image ls >/dev/null 2>&1;; *) "$1" info >/dev/null 2>&1;; esac; }
RT=""
for c in docker podman wslc; do command -v "$c" >/dev/null 2>&1 && runtime_ok "$c" && { RT="$c"; break; }; done
if [ -z "$RT" ] && command -v cygpath >/dev/null 2>&1; then
  p="$(cygpath -u "${PROGRAMFILES:-C:\\Program Files}" 2>/dev/null)/WSL/wslc.exe"
  [ -x "$p" ] && runtime_ok "$p" && RT="$p"
fi
[ -n "$RT" ] || { echo "rego-proof: no OCI runtime found (docker/podman/wslc)"; exit 2; }

PY="$(command -v python || command -v python3)"; [ -n "$PY" ] || { echo "rego-proof: python not found"; exit 2; }

WORK="$(mktemp -d)"; chmod 0755 "$WORK"; trap 'rm -rf "$WORK"' EXIT  # 0755: OPA runs non-root and must read the mount
fail(){ echo "FAIL: $1"; exit 1; }

"$PY" compile.py example-assessment.json "$WORK" >/dev/null || fail "compiler errored on a valid assessment"
[ -f "$WORK/policy.rego" ] || fail "compiler did not emit policy.rego"

# Evaluate the generated Rego with OPA. --format raw prints just the boolean.
opa_eval(){  # opa_eval <input-json> -> prints true|false
  printf '%s' "$1" > "$WORK/input.json"; chmod 0644 "$WORK/input.json"
  # Capture only stdout (the verdict); pull progress + any errors go to stderr (visible, not captured).
  case "$(uname -s 2>/dev/null || echo x)" in
    MINGW*|MSYS*|CYGWIN*) local h; h="$(cygpath -w "$WORK")"; MSYS_NO_PATHCONV=1 "$RT" run --rm -v "${h}:/w:ro" "$OPA_IMAGE" eval -i /w/input.json -d /w/policy.rego "$QUERY" --format raw ;;
    *)                    "$RT" run --rm -v "${WORK}:/w:ro" "$OPA_IMAGE" eval -i /w/input.json -d /w/policy.rego "$QUERY" --format raw ;;
  esac
}

expect(){  # expect <input-json> <true|false> <label>
  local got; got="$(opa_eval "$1" | tail -n1 | tr -d '[:space:]')"
  [ "$got" = "$2" ] || fail "$3 (expected allow=$2, got allow='$got')"
}

expect '{"kind":"egress","host":"exfil.attacker.test"}' false "egress to a review-UNAPPROVED host must be DENIED"
expect '{"kind":"egress","host":"registry.npmjs.org"}'  true  "egress to a review-approved host must be ALLOWED"
expect '{"kind":"tool","tool":"run_shell"}'             false "a review-DENIED tool must be DENIED"
expect '{"kind":"tool","tool":"read_note"}'             true  "a review-approved tool must be ALLOWED"

echo "PASS: the OPA/Rego adapter enforces the same contract as pipelock (default-deny; review-approved only)"
echo "ALL REGO PROOFS PASSED (runtime=${RT##*/})"
