# Agent Assets

This directory is the canonical source for repository-owned assets shared by
Codex, Claude Code, and OpenCode. Its contents are public/shared knowledge.

## Structure

- `skills/` contains reusable Agent Skills. Edit skills only here.
- `references/` contains routed project knowledge and cross-workflow guidance.
  Start with `references/README.md`.
- Skill-specific references, scripts, and assets stay inside that skill's
  directory.

Project facts, architecture, testing knowledge, and design records remain in
`docs/`, even when agents are their primary readers.

Private Pro documentation stays inside the `Pro/` submodule. Public Agent
assets may index that documentation for explicitly Pro-scoped work, but must
not copy, summarize, or mirror private architecture, persistence, lifecycle,
feature, or test details.

Use `skills/protect-knowledge-boundary/` whenever a documentation or Agent
asset change mentions Pro or crosses the root/submodule boundary.

## Platform Discovery

- Codex and OpenCode discover `.agents/skills/` directly.
- Claude Code discovers the same skills through relative symbolic links in
  `.claude/skills/`.
- `AGENTS.md` is the canonical repository instruction file. `CLAUDE.md` imports
  the adjacent `AGENTS.md` instead of duplicating it.

Do not copy shared skills into platform-specific directories or add generated
mirrors. Platform-only permissions, hooks, and local settings stay in the
platform's native directory.
