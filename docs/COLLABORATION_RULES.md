---
name: collaboration-rules
description: AI assistant collaboration rules — enforced behaviors and prohibitions
metadata:
  type: feedback
---

# AI Assistant Collaboration Rules

The following rules are **hard constraints** and must be followed in all circumstances. The rules in AGENTS.md / CLAUDE.md carry equal weight; this document clarifies and reinforces them.

## Project Language

- **English is the primary language of this project.** All documentation, code comments, commit messages, and communication must be written in English. Localization strings (`.xcstrings`) are the only exception — they support `en`, `ja`, and `zh-Hans`.

## Prohibited Actions

- **No committing (git commit)**: Unless the user explicitly says "commit" or equivalent in the current conversation turn, never run `git commit`. This includes `git commit --amend`, `git commit -m`, committing to submodules, and any other variant.

- **No pushing (git push)**: Unless the user explicitly says "push", never run `git push`. This includes `git push --force`, pushing to any remote, and any other variant.

- **No deleting files**: Never delete source files unless the user explicitly instructs you to. The same applies to renaming and moving files.

- **No modifying Git config**: Never run `git config` to modify repository configuration.

- **No destructive Git operations**: `git reset --hard`, `git clean -f`, and similar must be confirmed by the user.

- **Verify target before editing pbxproj**: OSS and PRO target build settings blocks look nearly identical. Check `baseConfigurationReference` (`OSS.xcconfig` vs `PRO.xcconfig`) before modifying any block. Never use `replace_all` on pbxproj — edit each occurrence individually with enough context.

## Must Follow

- **AGENTS.md / CLAUDE.md takes priority**: AGENTS.md, CLAUDE.md, and the project documentation under `docs/` are the authoritative guides for this project and must be consulted for every decision.

- **Enter plan mode**: Non-trivial implementation tasks must enter plan mode (EnterPlanMode) and receive approval before any code is written.

- **Build verification**: All code changes must be verified by running `xcodebuild build` successfully.

- **No UI tests by default**: Do not run `WiFiLensUITests`, `WiFiLensProUITests`, or full scheme `xcodebuild test` commands that include UI test bundles unless the user explicitly asks for UI tests. Use build verification and unit-test-only verification by default.

- **Docs go in `docs/`**: All new `.md` files must be placed under the `docs/` directory. The only exceptions are this file (`docs/COLLABORATION_RULES.md`) and `AGENTS.md`, `CLAUDE.md`, and `README.md` at the repo root.

## Behavioral Style

- **Concise responses**: Deliver results and key information directly. No need to summarize what was done after every response.
- **Don't guess**: Ask directly when a decision requires more information; don't assume.
- **Respect user intent**: If the user says "this is a half-finished refactor", that means they are aware of that state. Don't repeatedly flag it or mark it as a bug.
