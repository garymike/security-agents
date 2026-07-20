# Threat profiles

The runtime proving ground. Each profile is one real attack: what it is, why a review alone does not
stop it, and how the assess-to-enforce gateway blocks it at runtime, with the CI proof. New threats
become new profiles; the platform thesis does not move.

| Threat | Grounding | Status | Enforced by |
|---|---|---|---|
| [Untrusted MCP server at runtime](untrusted-mcp-server.md) | OWASP MCP Top 10 | Covered, enforced | the assess-to-enforce gateway |

Roadmap (the material exists, the profiles are pending): MCP tool-description poisoning at review
time (the `mcp-reviewer` flavor), LLM-app prompt injection (the designed `llm-redteam` flavor). The
static-side profiles (developer-execution, config-injection) live in the
[security-workflows](https://github.com/garymike/security-workflows) catalog.
