# 3. The sandbox is egress-gated, credential-free, and non-root

## Status
Accepted

## Context
The **body** ([ADR-0002](0002-agent-anatomy.md)) exists to run an untrusted target — an MCP server, a skill's
bundled scripts. If that target can reach the network, read host credentials, or escalate, the sandbox is
theatre.

## Decision
Every flavor's sandbox is hardened by default in `compose.yml` / `sandbox/`:

- **egress-gated** — runs on an internal Docker network with **no route to the internet**; narrow egress is
  opt-in and only through a logged proxy;
- **credential-free** — no host credentials, no secret env, no bind to the host network;
- **non-root**, `read_only`, `cap_drop: [ALL]`, `no-new-privileges`;
- the **target is mounted read-only**.

Escaping any of these (egress from a "gated" sandbox, a credential read, a write outside the target) is a
**critical finding**, not a warning — see `SECURITY.md`.

## Consequences
An untrusted target run for review cannot exfiltrate, persist, or pivot. Outbound *attempts* become signal
(the network is default-deny with logging). The controls are declared in configuration, so a reviewer can
audit the isolation without reading code, and a new flavor inherits the posture by copying the shape.
