#!/usr/bin/env bash
# verify.sh — re-prove the github-mcp-server end-to-end example on every run: compile the real assessment, then
# assert the compiled policy ALLOWS exactly api.github.com + the approved tools and BLOCKS the rest, in BOTH
# engines (pipelock + OPA/Rego). Runtime-agnostic: docker -> podman -> wslc (health-checked); images digest-pinned.
set -uo pipefail
cd "$(dirname "$0")"

PIPE_IMAGE="${PIPELOCK_IMAGE:-ghcr.io/luckypipewrench/pipelock:3.0.0@sha256:49b6ee229941d0d7d0c7431949edeeb878f3bfa6f092f36abff8eed09ac7836b}"
OPA_IMAGE="${OPA_IMAGE:-docker.io/openpolicyagent/opa:1.18.2@sha256:cba27d3c6af2feba1e4d6e6b5e24df5b53db332420d4148a90acccd12efae6ed}"

runtime_ok(){ case "${1##*/}" in docker*|podman*) "$1" info >/dev/null 2>&1;; wslc*) "$1" image ls >/dev/null 2>&1;; *) "$1" info >/dev/null 2>&1;; esac; }
RT=""
for c in docker podman wslc; do command -v "$c" >/dev/null 2>&1 && runtime_ok "$c" && { RT="$c"; break; }; done
if [ -z "$RT" ] && command -v cygpath >/dev/null 2>&1; then
  p="$(cygpath -u "${PROGRAMFILES:-C:\\Program Files}" 2>/dev/null)/WSL/wslc.exe"
  [ -x "$p" ] && runtime_ok "$p" && RT="$p"
fi
[ -n "$RT" ] || { echo "verify: no OCI runtime found (docker/podman/wslc)"; exit 2; }
PY="$(command -v python || command -v python3)"; [ -n "$PY" ] || { echo "verify: python not found"; exit 2; }

WORK="$(mktemp -d)"; chmod 0755 "$WORK"; trap 'rm -rf "$WORK"' EXIT
fail(){ echo "FAIL: $1"; exit 1; }
"$PY" ../../compiler/compile.py assessment.json "$WORK" >/dev/null || fail "compiler errored on the assessment"

run_img(){  # run_img <image> <mount-target> <args...>   (mounts $WORK read-only)
  local img="$1" mt="$2"; shift 2
  case "$(uname -s 2>/dev/null || echo x)" in
    MINGW*|MSYS*|CYGWIN*) local h; h="$(cygpath -w "$WORK")"; MSYS_NO_PATHCONV=1 "$RT" run --rm -v "${h}:${mt}:ro" "$img" "$@" ;;
    *)                    "$RT" run --rm -v "${WORK}:${mt}:ro" "$img" "$@" ;;
  esac
}

# --- pipelock (egress, via explain) — substring match tolerates image-pull noise ---
pexplain(){ run_img "$PIPE_IMAGE" /config explain --config "/config/$1" "$2" 2>&1; }
[[ "$(pexplain gateway.enforce.yaml https://api.github.com/user)"      == *"Verdict: ALLOWED"* ]] || fail "enforce must ALLOW approved egress api.github.com"
[[ "$(pexplain gateway.enforce.yaml https://exfil.attacker.test/x)"    == *"Verdict: BLOCKED"* ]] || fail "enforce must BLOCK unapproved egress"
echo "PASS: pipelock enforce allows api.github.com, blocks unapproved egress"

# --- OPA/Rego (tools + egress, via eval) — stdout-only, last line ---
opa(){ printf '%s' "$1" > "$WORK/input.json"; chmod 0644 "$WORK/input.json"; run_img "$OPA_IMAGE" /w eval -i /w/input.json -d /w/policy.rego "data.mcp.gateway.authz.allow" --format raw | tail -n1 | tr -d '[:space:]'; }
expect(){ local got; got="$(opa "$1")"; [ "$got" = "$2" ] || fail "$3 (expected $2, got '$got')"; }
expect '{"kind":"tool","tool":"get_file_contents"}'        true  "approved tool get_file_contents"
expect '{"kind":"tool","tool":"delete_file"}'              false "denied tool delete_file"
expect '{"kind":"egress","host":"api.github.com"}'         true  "approved egress api.github.com"
expect '{"kind":"egress","host":"exfil.attacker.test"}'    false "unapproved egress"
echo "PASS: OPA/Rego allows approved tools + egress, denies the rest"

echo "ALL github-mcp-server E2E CHECKS PASSED (runtime=${RT##*/})"
