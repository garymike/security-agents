#!/usr/bin/env bash
# gateway.sh — run the mcp-gateway (pipelock) locally with whatever OCI runtime is present.
#
# Milestone B: this WRAPS the adopted, pinned pipelock engine. It validates the policy and demonstrates a
# content-aware block, off the *same* signed, digest-pinned image everywhere — the same runtime-agnostic
# approach as security-workflows `bin/skill-gate` (docker -> podman -> wslc, health-checked). No Docker Desktop
# required. The assess->enforce compiler (Milestone C) will GENERATE the policy this runs; here it's authored.
#
# Usage: ./gateway.sh [observe|enforce]     (default: observe = alert-only, the shipped default)
# Env:   PIPELOCK_IMAGE     override the pinned image
#        GATEWAY_RUNTIME    force runtime: docker | podman | wslc (or a full path)
set -uo pipefail
cd "$(dirname "$0")"

MODE="${1:-observe}"
case "$MODE" in observe|enforce) ;; *) echo "usage: ./gateway.sh [observe|enforce]" >&2; exit 2 ;; esac
CONFIG="/config/gateway.${MODE}.yaml"
IMAGE="${PIPELOCK_IMAGE:-ghcr.io/luckypipewrench/pipelock:3.0.0@sha256:49b6ee229941d0d7d0c7431949edeeb878f3bfa6f092f36abff8eed09ac7836b}"

# A runtime must be present AND functional (installed != running). Health-check before selecting.
runtime_ok() {
  case "${1##*/}" in
    docker*|podman*) "$1" info     >/dev/null 2>&1 ;;
    wslc*)           "$1" image ls >/dev/null 2>&1 ;;
    *)               "$1" info     >/dev/null 2>&1 ;;
  esac
}

RT=""
if [ -n "${GATEWAY_RUNTIME:-}" ]; then
  RT="$GATEWAY_RUNTIME"
else
  for c in docker podman wslc; do
    if command -v "$c" >/dev/null 2>&1 && runtime_ok "$c"; then RT="$c"; break; fi
  done
  # wslc ships at C:\Program Files\WSL but isn't always on the shell PATH.
  if [ -z "$RT" ] && command -v cygpath >/dev/null 2>&1; then
    p="$(cygpath -u "${PROGRAMFILES:-C:\\Program Files}" 2>/dev/null)/WSL/wslc.exe"
    if [ -x "$p" ] && runtime_ok "$p"; then RT="$p"; fi
  fi
fi
if [ -z "$RT" ]; then
  echo "gateway.sh: no OCI runtime found (need docker, podman, or wslc)." >&2
  echo "  See security-workflows docs/local-runner.md (wslc: wsl --update --pre-release)." >&2
  exit 2
fi

cfgdir="$(pwd)/config"
run() {  # run pipelock with the config dir mounted read-only
  case "$(uname -s 2>/dev/null || echo x)" in
    MINGW*|MSYS*|CYGWIN*)
      local host; host="$(cygpath -w "$cfgdir" 2>/dev/null || echo "$cfgdir")"
      MSYS_NO_PATHCONV=1 "$RT" run --rm -v "${host}:/config:ro" "$IMAGE" "$@" ;;
    *)
      "$RT" run --rm -v "${cfgdir}:/config:ro" "$IMAGE" "$@" ;;
  esac
}

echo "gateway.sh: runtime=${RT##*/}  mode=$MODE  image=$IMAGE" >&2
echo "== 1. validate policy ($MODE) =="
run check --config "$CONFIG" --url "https://docs.python.org/3/" 2>&1 | sed -n '/Config validation/p;/Result/p'
echo "== 2. content-aware block: a leaked AWS key in an outbound URL =="
run check --config "$CONFIG" --url "https://evil.example/?k=AKIAIOSFODNN7EXAMPLE" 2>&1 | sed -n '/Result/p;/Reason/p'

cat <<EOF

Alert-only ("observe") is the default: findings are RECORDED, not blocked. Run ./gateway.sh enforce to block.
To mediate a real stdio MCP server (the client launches pipelock instead of the server):
  pipelock mcp proxy --config $CONFIG -- <server start command>
Signed action receipts (audit evidence from outside the agent) are written when flight_recorder.dir is set.
EOF
