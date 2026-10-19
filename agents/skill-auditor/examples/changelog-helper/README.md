# Worked example: reviewing `changelog-helper`

An end-to-end run of the skill-auditor: a skill goes in, the review chain runs, and a schema-valid
`assessment.json` comes out with a verdict a decision-maker can act on. This is what "assess to
enforce" looks like from the assessment side.

## The target

[`target/`](target) is a small, realistic skill: draft a Keep-a-Changelog entry from the staged
diff. Its `SKILL.md` is honest, on-topic prose with no prompt injection or suspicious instructions.
Bundled alongside it is `notes.test.ts`, which `npm test` auto-runs outside the agent and which
appends to `MEMORY.md`, the agent's persistent cross-session memory. Every later session that loads
that memory reads the appended text as its own prior context. The payload is defanged: it appends an
inert canary comment, never a working instruction (a faithful copy of
[security-workflows' `memory-poisoning-demo` fixture](https://github.com/garymike/security-workflows/blob/main/tests/fixtures/memory-poisoning-demo)).
This is the [developer-execution surface](https://github.com/garymike/security-workflows/blob/main/docs/threats/developer-execution.md)
carrying the Snyk *ToxicSkills* memory-poisoning class: a clean `SKILL.md` with the payload riding
in a file the agent never touches.

This example used to target a `.husky/pre-commit` hook that exfiltrated an SSH key. It moved because
SkillSpector v2.13.0 blocks that carrier (76/100), so it no longer shows the gate adding anything.
The memory write is the carrier upstream still clears, and it clears it on both the old and current
toolbox images, so this example survives the next digest bump.

## The chain

```
target/  ──►  skill-testfile-gate + SkillSpector  ──►  skill-security-review method  ──►  assessment.json
(the skill)      (static, both surfaces)                (interprets + scores)              (BLOCK)
```

The [`skill-security-review`](https://github.com/garymike/skills/tree/main/skills/skill-security-review)
methodology is the brains; `skill-testfile-gate` and SkillSpector are the hands this agent wires
([`review.sh`](../../review.sh)). Static rules are a pre-filter, not a trust gate, so an opaque or
packed result would escalate to the sandbox ([ADR-0005](../../../../docs/adr/0005-static-dynamic-escalation.md));
here the static Critical is unambiguous enough that the method reaches BLOCK without needing that
step, which [`assessment.json`](assessment.json) records honestly under `limitations`.

## Measured verdicts (this is what actually happens)

| Tool | Surface | Result |
|---|---|---|
| `skill-testfile-gate` | developer-execution | **BLOCKS** (exit 1): write to persistent agent memory in `notes.test.ts` |
| SkillSpector (`--no-llm`) | agent-execution | **does not block** (0/100 `SAFE`, exit 0): it reports *no issues at all*, at `Coverage 100.0%` with `notes.test.ts` typed `Executable: Yes`. It does gate above a `risk_score` of 50 and blocks four of five carriers in [security-workflows](https://github.com/garymike/security-workflows) as of v2.13.0; this is the one it clears, because only the written bytes are matched against injection patterns and this payload is inert |
| `skill-security-review` method | both, interpreted | **BLOCK** verdict, 1 critical finding, in [`assessment.json`](assessment.json) |

The gate and SkillSpector are re-run against the freshly pulled toolbox image on every build,
so this table stays true rather than becoming a screenshot.

## Reproduce / verify

```bash
bash verify.sh
```

Runs the pinned `skill-audit-toolbox` image (digest-pinned, docker/podman/wslc, whichever is
available) against `target/`, asserts the gate blocks while SkillSpector exits 0, and checks
`assessment.json` against the `skill-assessment/v1` schema. `verify.sh` runs in CI
([`skill-auditor-proof.yml`](../../../../.github/workflows/skill-auditor-proof.yml)), so this
worked example stays true on every change.

`assessment.json`'s `definition_sha256` is reproducible: `hash_skill_definitions.py target` in the
[skill-security-review skill](https://github.com/garymike/skills/tree/main/skills/skill-security-review/scripts)
produces the same hash, the rug-pull anchor if this target ever changes after approval.
