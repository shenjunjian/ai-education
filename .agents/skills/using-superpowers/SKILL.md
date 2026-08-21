---
name: using-superpowers
description: 在开启任何对话时使用 — 说明如何查找和使用 skills，要求在任何回复（包括澄清问题）之前先 invoke skill
---

<SUBAGENT-STOP>
If you were dispatched as a subagent to execute a specific task, ignore this skill.
</SUBAGENT-STOP>

<EXTREMELY-IMPORTANT>
If you think there is even a 1% chance a skill might apply to what you are doing, you ABSOLUTELY MUST invoke the skill.

IF A SKILL APPLIES TO YOUR TASK, YOU DO NOT HAVE A CHOICE. YOU MUST USE IT.

This is not negotiable. You cannot rationalize your way out of this.
</EXTREMELY-IMPORTANT>

## 规则

**在给出任何回复或采取行动之前，先 invoke 相关或被请求的 skills** — 包括澄清问题、探索 codebase 或查看文件。如果后来发现不适合当前情况，可以不使用它。

**进入 plan mode 之前：** 如果尚未进行 brainstorming，先 invoke brainstorming skill。

然后宣布 "Using [skill] to [purpose]"，并严格按 skill 执行。如果 skill 有 checklist，为每一项创建一个 todo。

## Skill 优先级

当多个 skills 适用时，process skills 优先 — 它们设定方法，然后 implementation skills（frontend-design 等）再执行。Brainstorming 和 systematic-debugging 是 Superpowers 最常见的 process skills，但这条规则适用于所有这类 skills。

- "Let's build X" → 先 superpowers:brainstorming，再 implementation skills。
- "Fix this bug" → 先 superpowers:systematic-debugging，再 domain skills。

## Red Flags

这些想法意味着 STOP — 你在合理化：

| Thought | Reality |
|---------|---------|
| "This is just a simple question" | 问题也是任务。检查 skills。 |
| "I need more context first" | Skill 检查在澄清问题之前。 |
| "Let me explore the codebase first" | Skills 会告诉你如何探索。先检查。 |
| "I can check git/files quickly" | 文件缺少对话上下文。检查 skills。 |
| "Let me gather information first" | Skills 会告诉你如何收集信息。 |
| "This doesn't need a formal skill" | 如果 skill 存在，就使用它。 |
| "I remember this skill" | Skills 会演进。阅读当前版本。 |
| "This doesn't count as a task" | 行动 = 任务。检查 skills。 |
| "The skill is overkill" | 简单的事也会变复杂。使用它。 |
| "I'll just do this one thing first" | 在做任何事之前先检查。 |
| "This feels productive" | 无纪律的行动浪费时间。Skills 能防止这一点。 |
| "I know what that means" | 知道概念 ≠ 使用 skill。Invoke 它。 |

## 平台适配

如果你的 harness 出现在下方，请阅读其 reference 文件以获取特殊说明：

- Codex: `references/codex-tools.md`
- Pi: `references/pi-tools.md`
- Antigravity: `references/antigravity-tools.md`
- Hermes Agent: `references/hermes-tools.md`

## 用户指令

用户指令（CLAUDE.md、AGENTS.md、GEMINI.md 等，以及直接请求）优先于 skills，skills 又优先于默认行为。仅当你的 human partner 明确告诉你跳过 skill 工作流或指令时才跳过。
