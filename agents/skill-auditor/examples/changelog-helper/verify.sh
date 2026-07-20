#!/usr/bin/env bash
# verify.sh — re-prove the changelog-helper end-to-end example on every run: run the pinned skill-audit-toolbox
# against a skill whose SKILL.md is clean but whose bundled git hook reads an SSH key and exfiltrates it (the
# Gecko developer-execution vector). Asserts the gate BLOCKS (fails the build) while SkillSpector only ADVISES
# (reports, exits 0), the enforce-vs-advise gap the skill-auditor's brains (skill-security-review) interprets into
# the BLOCK verdict recorded in assessment.json. Runtime-agnostic: docker -> podman -> wslc (health-checked).
set -uo pipefail
cd "$(dirname "$0")"

IMAGE="${SKILL_AUDIT_IMAGE:-ghcr.io/garymike/security-workflows/skill-audit-toolbox@sha256:401087f31bbb739d790091e16588f8c5f3e05ba18643e004935f1c2e8a7fc9a7}"

runtime_ok(){ case "${1##*/}" in docker*|podman*) "$1" info >/dev/null 2>&1;; wslc*) "$1" image ls >/dev/null 2>&1;; *) "$1" info >/dev/null 2>&1;; esac; }
RT=""
for c in docker podman wslc; do command -v "$c" >/dev/null 2>&1 && runtime_ok "$c" && { RT="$c"; break; }; done
if [ -z "$RT" ] && command -v cygpath >/dev/null 2>&1; then
  p="$(cygpath -u "${PROGRAMFILES:-C:\\Program Files}" 2>/dev/null)/WSL/wslc.exe"
  [ -x "$p" ] && runtime_ok "$p" && RT="$p"
fi
[ -n "$RT" ] || { echo "verify: no OCI runtime found (docker/podman/wslc)"; exit 2; }
PY="$(command -v python || command -v python3)"; [ -n "$PY" ] || { echo "verify: python not found"; exit 2; }

fail(){ echo "FAIL: $1"; exit 1; }

run_toolbox(){  # mounts ./target read-only, runs the given command in the toolbox
  case "$(uname -s 2>/dev/null || echo x)" in
    MINGW*|MSYS*|CYGWIN*) local h; h="$(cygpath -w "$PWD/target")"; MSYS_NO_PATHCONV=1 "$RT" run --rm -v "${h}:/skill:ro" "$IMAGE" "$@" ;;
    *)                    "$RT" run --rm -v "$PWD/target:/skill:ro" "$IMAGE" "$@" ;;
  esac
}

echo "== 1. skill-testfile-gate MUST block (the developer-execution surface: .husky/pre-commit reads ~/.ssh) =="
gate_out="$(run_toolbox skill-testfile-gate /skill 2>&1)"; gate_rc=$?
echo "$gate_out"
[ "$gate_rc" -ne 0 ] || fail "gate did not block (exit $gate_rc); expected a nonzero exit on this malicious hook"
[[ "$gate_out" == *"credential"* || "$gate_out" == *"[malice]"* ]] || fail "gate blocked but reported no credential/malice finding, investigate before trusting this proof"
echo "PASS: gate blocks (exit $gate_rc)"

echo ""
echo "== 2. SkillSpector MUST only advise (reports, but exits 0, no fail-on mode) =="
ss_out="$(run_toolbox skillspector scan /skill --no-llm 2>&1)"; ss_rc=$?
echo "$ss_out"
[ "$ss_rc" -eq 0 ] || fail "SkillSpector exited nonzero ($ss_rc); if it now gates, the enforce-vs-advise framing needs revisiting"
echo "PASS: SkillSpector advises only (exit 0); a CI pipeline gating on exit code alone would let this skill through"

echo ""
echo "== 3. assessment.json MUST be schema-valid and record the BLOCK verdict =="
"$PY" - "$PWD/assessment.json" <<'PYEOF' || fail "assessment.json failed validation"
import json, sys
d = json.load(open(sys.argv[1]))
assert d["schema"] == "skill-assessment/v1", "wrong schema tag"
assert d["verdict"] == "BLOCK", f"expected BLOCK, got {d['verdict']}"
assert d["severity_counts"]["critical"] >= 1, "expected at least one critical finding"
assert any(f["surface"] == "developer_execution" and f["severity"] == "critical" for f in d["findings"]), \
    "expected a critical developer_execution finding"
print("assessment.json: schema tag, verdict, and findings check out")
PYEOF

echo ""
echo "ALL changelog-helper E2E CHECKS PASSED (runtime=${RT##*/})"
