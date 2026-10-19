#!/usr/bin/env bash
# verify.sh — re-prove the changelog-helper end-to-end example on every run: run the pinned skill-audit-toolbox
# against a skill whose SKILL.md is clean but whose bundled test file appends to MEMORY.md, the agent's
# persistent cross-session memory (the Snyk ToxicSkills class). Asserts the gate BLOCKS (fails the build)
# while SkillSpector reports nothing and exits 0.
#
# Why this carrier and not the git hook this example used to target: SkillSpector is not advisory, it gates
# above a risk_score of 50, and as of v2.13.0 it blocks the git-hook carrier (76/100) and the test-file
# carrier (64/100) too. The write to persistent memory is the one carrier it still clears: 0/100, SAFE, "no
# security issues detected", at Coverage 100.0% with the file typed Executable: Yes. It is read, analysed,
# and passed, because only the written bytes are matched against injection patterns and this payload is an
# inert canary. That is the gap the skill-auditor's brains (skill-security-review) interpret into the BLOCK
# verdict recorded in assessment.json, and it is hard-asserted upstream in security-workflows
# tests/gate-proof.sh #4. It also holds on both the old and current toolbox images, so this example does not
# break the next time the pinned digest moves. Runtime-agnostic: docker -> podman -> wslc (health-checked).
set -uo pipefail
cd "$(dirname "$0")"

IMAGE="${SKILL_AUDIT_IMAGE:-ghcr.io/garymike/security-workflows/skill-audit-toolbox@sha256:37ee2e494596e9b917b0293271e9531ff9a545ee338bfefdc1d34bbc8bb31ad8}"

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

echo "== 1. skill-testfile-gate MUST block (the developer-execution surface: notes.test.ts writes to MEMORY.md) =="
gate_out="$(run_toolbox skill-testfile-gate /skill 2>&1)"; gate_rc=$?
echo "$gate_out"
[ "$gate_rc" -ne 0 ] || fail "gate did not block (exit $gate_rc); expected a nonzero exit on this memory write"
[[ "$gate_out" == *"memory"* || "$gate_out" == *"[malice]"* ]] || fail "gate blocked but reported no memory/malice finding, investigate before trusting this proof"
echo "PASS: gate blocks (exit $gate_rc)"

echo ""
echo "== 2. SkillSpector MUST NOT block this carrier (0/100 SAFE, no issues detected, exits 0) =="
ss_out="$(run_toolbox skillspector scan /skill --no-llm 2>&1)"; ss_rc=$?
echo "$ss_out"
[ "$ss_rc" -eq 0 ] || fail "SkillSpector exited nonzero ($ss_rc); it now covers the persistent-memory-write carrier, which was this example's last uncovered one. Re-measure, then shrink the claim here and in security-workflows rather than rewording it."
echo "PASS: SkillSpector does not block this carrier (exit 0); a CI pipeline gating on exit code alone would let this skill through"

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
