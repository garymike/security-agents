#!/usr/bin/env bash
# proof.sh — CI proof-fixture for the assess->enforce compiler (security-agents ADR-0007).
#
# Proves, on every run, the claim no gateway vendor makes: a security REVIEW compiles into an ENFORCED policy.
#   1. the compiler emits pipelock-VALID policy (strict, fail-closed parser);
#   2. in ENFORCE the generated policy BLOCKS an egress the review never approved, while OBSERVE only alerts
#      (scan -> detonate -> enforce, continuously proven — alert-only stays the default);
#   3. the compiler REJECTS a package-runner (npx/uvx) launch — the absolute-path supply-chain guard.
#
# Runtime-agnostic: docker -> podman -> wslc (health-checked), off the same digest-pinned image as everywhere.
set -uo pipefail
cd "$(dirname "$0")"

IMAGE="${PIPELOCK_IMAGE:-ghcr.io/luckypipewrench/pipelock:3.0.0@sha256:49b6ee229941d0d7d0c7431949edeeb878f3bfa6f092f36abff8eed09ac7836b}"
# A host the review never observed. `.test` is reserved + non-resolving; `explain` is DNS-free, so the verdict
# comes from the allowlist layer, not SSRF — a deterministic, network-independent proof.
NONAPPROVED="https://exfil.attacker.test/steal?data=1"

runtime_ok(){ case "${1##*/}" in docker*|podman*) "$1" info >/dev/null 2>&1;; wslc*) "$1" image ls >/dev/null 2>&1;; *) "$1" info >/dev/null 2>&1;; esac; }
RT=""
for c in docker podman wslc; do command -v "$c" >/dev/null 2>&1 && runtime_ok "$c" && { RT="$c"; break; }; done
if [ -z "$RT" ] && command -v cygpath >/dev/null 2>&1; then
  p="$(cygpath -u "${PROGRAMFILES:-C:\\Program Files}" 2>/dev/null)/WSL/wslc.exe"
  [ -x "$p" ] && runtime_ok "$p" && RT="$p"
fi
[ -n "$RT" ] || { echo "proof: no OCI runtime found (docker/podman/wslc)"; exit 2; }

PY="$(command -v python || command -v python3)"; [ -n "$PY" ] || { echo "proof: python not found"; exit 2; }

WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT
fail(){ echo "FAIL: $1"; exit 1; }

# The compiler must succeed on a valid assessment.
"$PY" compile.py example-assessment.json "$WORK" >/dev/null || fail "compiler errored on a valid assessment"

# Run pipelock with the generated policy dir mounted read-only.
plk(){
  case "$(uname -s 2>/dev/null || echo x)" in
    MINGW*|MSYS*|CYGWIN*) local h; h="$(cygpath -w "$WORK")"; MSYS_NO_PATHCONV=1 "$RT" run --rm -v "${h}:/config:ro" "$IMAGE" "$@" ;;
    *)                    "$RT" run --rm -v "${WORK}:/config:ro" "$IMAGE" "$@" ;;
  esac
}

# 1. Both generated configs must pass pipelock's strict validator. (Capture output, then match — piping into
#    `grep -q` under `set -o pipefail` would SIGPIPE the container command and report a false failure.)
for m in observe enforce; do
  out="$(plk check --config "/config/gateway.$m.yaml" --url "https://docs.python.org/3/" 2>&1)"
  [[ "$out" == *"Config validation: OK"* ]] || fail "generated gateway.$m.yaml failed pipelock validation"
done
echo "PASS 1/3: generated observe + enforce configs validate against pinned pipelock"

# 2. ENFORCE blocks the review-unapproved egress (allowlist layer); OBSERVE alerts-only (allows).
enf="$(plk explain --config /config/gateway.enforce.yaml "$NONAPPROVED" 2>&1)"
[[ "$enf" == *"Verdict: BLOCKED"* ]]   || fail "ENFORCE did not block a review-unapproved egress"
[[ "$enf" == *"Scanner: allowlist"* ]] || fail "ENFORCE block did not come from the allowlist (review) layer"
obs="$(plk explain --config /config/gateway.observe.yaml "$NONAPPROVED" 2>&1)"
[[ "$obs" == *"Verdict: ALLOWED"* ]]   || fail "OBSERVE should alert-only (allow), not block"
echo "PASS 2/3: ENFORCE blocks review-unapproved egress; OBSERVE alerts-only  ->  scan->enforce proven"

# 3. The npx/uvx supply-chain guard: reject a package-runner launch.
echo '{"server":{"name":"bad","launch":{"command":"npx","args":["evil"]}},"tools":[],"egress":{"observed":[]}}' > "$WORK/bad.json"
if "$PY" compile.py "$WORK/bad.json" "$WORK/bad-out" 2>/dev/null; then
  fail "compiler accepted an npx package-runner launch (should require an absolute path)"
fi
echo "PASS 3/3: compiler rejects a package-runner (npx) launch  ->  absolute-path supply-chain guard"

echo "ALL PROOFS PASSED (runtime=${RT##*/})"
