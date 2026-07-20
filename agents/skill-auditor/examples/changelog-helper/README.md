# Worked example: reviewing `changelog-helper`

An end-to-end run of the skill-auditor: a skill goes in, the review chain runs, and a schema-valid
`assessment.json` comes out with a verdict a decision-maker can act on. This is what "assess to
enforce" looks like from the assessment side.

## The target

[`target/`](target) is a small, realistic skill: draft a Keep-a-Changelog entry from the staged
diff. Its `SKILL.md` is honest, on-topic prose with no prompt injection or suspicious instructions.
Bundled alongside it is `.husky/pre-commit`, a git hook that auto-runs on every `git commit`, reads
the developer's SSH private key, and POSTs it out. The payload is defanged: it reads a real path but
sends to a localhost sink, never a real host (a faithful copy of
[security-workflows' `gecko-hook-demo` fixture](https://github.com/garymike/security-workflows/blob/main/tests/fixtures/gecko-hook-demo)).
This is the [Gecko developer-execution vector](https://github.com/garymike/security-workflows/blob/main/docs/threats/developer-execution.md):
a clean `SKILL.md` with the payload riding in a file the agent never touches.

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
| `skill-testfile-gate` | developer-execution | **BLOCKS** (exit 1): credential-file access in `.husky/pre-commit` |
| SkillSpector (`--no-llm`) | agent-execution | **advises only** (exit 0): no fail-on mode, so a CI pipeline gating on exit codes lets this through |
| `skill-security-review` method | both, interpreted | **BLOCK** verdict, 1 critical finding, in [`assessment.json`](assessment.json) |

The gate and SkillSpector are re-run against the freshly pulled toolbox image on every build,
so this table stays true rather than becoming a screenshot.

## Reproduce / verify

```bash
bash verify.sh
```

Runs the pinned `skill-audit-toolbox` image (digest-pinned, docker/podman/wslc, whichever is
available) against `target/`, asserts the gate blocks and SkillSpector only advises, and checks
`assessment.json` against the `skill-assessment/v1` schema. `verify.sh` runs in CI
([`skill-auditor-proof.yml`](../../../../.github/workflows/skill-auditor-proof.yml)), so this
worked example stays true on every change.

`assessment.json`'s `definition_sha256` is reproducible: `hash_skill_definitions.py target` in the
[skill-security-review skill](https://github.com/garymike/skills/tree/main/skills/skill-security-review/scripts)
produces the same hash, the rug-pull anchor if this target ever changes after approval.
