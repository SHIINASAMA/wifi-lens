---
name: protect-knowledge-boundary
description: Use when editing, moving, reviewing, or preparing to commit WiFi Lens documentation and Agent assets that mention Pro, paid editions, private modules, cross-repository references, AGENTS.md, CLAUDE.md, .agents/, or docs/.
---

# Protect Knowledge Boundary

Keep private Pro implementation knowledge inside the `Pro/` submodule while
allowing the public repository to index approved private entrypoints.

## Required context

Read [references/boundary-policy.md](references/boundary-policy.md) completely
before reviewing or changing knowledge-boundary content. Do not load private
Pro documentation into Agent context unless the task is explicitly Pro-scoped.
The deterministic scanner may compare private documents locally; it reports
only paths and violation categories, never private passages.

## Workflow

When this workflow is being used to gate a requested commit, first follow the
per-commit consent protocol in `.agents/references/collaboration-rules.md`. Do
not run steps 3 or 4 until the user chooses checks for that commit.

1. Treat the root repository as public and `Pro/` as a separate private
   repository. Inspect their Git status and diffs separately.
2. Review every new public Pro reference against the policy. Existence and
   approved entrypoint paths are allowed; implementation knowledge is not.
3. Run the deterministic public-content scan:

   ```sh
   python3 .agents/skills/protect-knowledge-boundary/scripts/check_public_knowledge.py
   ```

4. Run the independent integrity check:

   ```sh
   python3 .agents/skills/protect-knowledge-boundary/scripts/verify_integrity.py
   ```

5. Report root and Pro results separately. Do not claim completion while either
   checker fails or a semantic boundary question remains unresolved.

## Decision rules

- `PASS`: deterministic checks pass and manual review finds no private detail.
- `REVIEW`: a new reference is ambiguous. Stop and ask the user; do not infer
  permission to expose more context.
- `FAIL`: private detail, copied private text, invalid private path, missing
  protection, broken Claude link, or integrity mismatch exists.

Never fix a failure by weakening a rule, excluding a new path, updating hashes,
or rewriting the instruction anchor as part of an ordinary check. Changes to
protected assets require explicit user approval and a focused review. Generate
new hashes only after that review, then run all Skill tests and both checks.

## Integrity limits

Local hashes make tampering visible during normal work; they cannot stop a
committer who deliberately changes every local anchor. Trusted CI plus
CODEOWNERS approval is required for merge-level enforcement.
