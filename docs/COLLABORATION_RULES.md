---
name: collaboration-rules
description: AI assistant collaboration rules — enforced behaviors and prohibitions
metadata:
  type: feedback
---

# AI 助手行为准则

以下规则是**硬性约束**，必须在所有情况下遵循。CLAUDE.md 中的规则文本具有同等效力，本文档澄清和强化。

## 禁止操作

- **禁止提交 (git commit)**：除非用户在当前对话轮次中明确说出
"提交"/"commit"/"帮我提交"等指示，否则绝对不得运行 `git commit`。
包括 `git commit --amend`、`git commit -m`、commit 到子模块等任何变体。

- **禁止推送 (git push)**：除非用户明确说 "推送"/"push"，否则不得运行 `git push`。
包括 `git push --force`、推送到任何远程等任何变体。

- **禁止删除文件**：除非用户明确指示，否则不得删除源代码文件。
重命名、移动文件同理。

- **禁止修改 Git 配置**：不得运行 `git config` 修改仓库配置。

- **禁止破坏性 Git 操作**：`git reset --hard`、`git clean -f` 等必须经用户确认。

## 必须遵循

- **CLAUDE.md 优先**：CLAUDE.md 和 `docs/` 中的项目文档是对本项目的权威指南，
必须在每次决策时参考。

- **进入方案模式**：非平凡的实现任务在动手前必须进入方案模式（EnterPlanMode）并获批准。

- **构建验证**：所有代码修改后必须运行 `xcodebuild build` 验证通过。

- **文档放 `docs/`**：所有新建 `.md` 文件必须放在 `docs/` 目录下，
唯一例外是本文件（`docs/COLLABORATION_RULES.md`）和仓库根的 `CLAUDE.md`、`README.md`。

## 行为风格

- **简洁回复**：直接给出结果和关键信息，不需要每次总结做得怎么样。
- **不猜测**：需要决策信息时直接问，不要假设。
- **忠实于用户意图**：用户说"这是一个实现了一半的重构"即表示已知此状态，
无需反复提醒或标记为 bug。
