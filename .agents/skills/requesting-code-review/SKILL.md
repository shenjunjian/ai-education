---
name: requesting-code-review
description: 完成任务、实现 major feature 或 merge 前使用，以 verify 工作满足 requirements
---

# Requesting Code Review

Dispatch code reviewer subagent，在问题 cascade 之前捕获它们。Reviewer 获得为 evaluation 精确 crafted 的 context——绝不是你的 session history。

**Core principle:** Review early, review often.

## When to Request Review

**Mandatory:**
- Subagent-driven development 中每个 task 之后
- 完成 major feature 之后
- Merge 到 main 之前

**Optional but valuable:**
- 卡住时（fresh perspective）
- Refactoring 之前（baseline check）
- 修复 complex bug 之后

## How to Request

**1. Get git SHAs:**
```bash
BASE_SHA=$(git rev-parse HEAD~1)  # or origin/main
HEAD_SHA=$(git rev-parse HEAD)
```

**2. Dispatch code reviewer subagent:**

Dispatch `general-purpose` subagent，填写 [code-reviewer.md](code-reviewer.md) 中的 template

**Placeholders:**
- `{DESCRIPTION}` - 你构建内容的 brief summary
- `{PLAN_OR_REQUIREMENTS}` - 它应该做什么
- `{BASE_SHA}` - Starting commit
- `{HEAD_SHA}` - Ending commit

**3. Act on feedback:**
- 立刻 fix Critical issues
- Proceed 前 fix Important issues
- Minor issues 稍后处理
- Reviewer 错了就 push back（带 reasoning）

## Example

```
[Just completed Task 2: Add verification function]

You: Let me request code review before proceeding.

BASE_SHA=$(git log --oneline | grep "Task 1" | head -1 | awk '{print $1}')
HEAD_SHA=$(git rev-parse HEAD)

[Dispatch code reviewer subagent]
  DESCRIPTION: Added verifyIndex() and repairIndex() with 4 issue types
  PLAN_OR_REQUIREMENTS: Task 2 from docs/superpowers/plans/deployment-plan.md
  BASE_SHA: a7981ec
  HEAD_SHA: 3df7661

[Subagent returns]:
  Strengths: Clean architecture, real tests
  Issues:
    Important: Missing progress indicators
    Minor: Magic number (100) for reporting interval
  Assessment: Ready to proceed

You: [Fix progress indicators]
[Continue to Task 3]
```

## Common Rationalizations

| Excuse | Reality |
|--------|---------|
| 「I'll just review the diff myself instead of dispatching a reviewer」 | 你是 coordinator——inline review diff 会 burn 你继续推进工作所需的 context window。Dispatch reviewer subagent：diff 与 evaluation 活在它的 context 里，只有 findings 回到你这里。 |
| 「The reviewer needs my whole session history to understand the change」 | 给它 precisely crafted context，never 你的 session history。这样 reviewer 聚焦 work product，不是你的 thought process。 |

## Red Flags

**Never:**
- 因为「it's simple」而 skip review
- Ignore Critical issues
- Proceed 且有未 fix 的 Important issues
- 与 valid technical feedback 争辩

**If reviewer wrong:**
- Push back with technical reasoning
- Show code/tests that prove it works
- Request clarification

See template at: [code-reviewer.md](code-reviewer.md)
