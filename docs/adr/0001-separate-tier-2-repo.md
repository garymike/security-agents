# 1. A separate Tier-2 repo: isolation is a property of the deployment

## Status
Accepted

## Context
The platform's static tier ([garymike/security-workflows](https://github.com/garymike/security-workflows))
centralizes scanners into shared, signed, pinned images that are safe to run anywhere. But real security
review eventually needs to *execute* an untrusted target — an MCP server, an agent skill's bundled scripts,
an LLM app. The moment you run untrusted code, isolation stops being optional. Where should that dynamic
capability live?

## Decision
Dynamic analysis lives in a **separate repo** (this one), not folded into the static images. The governing
principle: **isolation is a property of the deployment, not the tool.** A static scanner can be a shared
image because it only reads. Anything that executes an untrusted target must run in the caller's own
isolation, so it ships as a **deployable unit** (skill + toolbox + sandbox), never baked into a shared image.

## Consequences
security-workflows stays static-only and safe-to-run-anywhere; security-agents is where the sandboxes and the
dynamic tier live. The two cross-reference (the agents consume the static toolbox images and dogfood the
static workflows) but never merge. This keeps the blast radius of "we run untrusted code here" contained to
the repo whose entire job is to contain it.
