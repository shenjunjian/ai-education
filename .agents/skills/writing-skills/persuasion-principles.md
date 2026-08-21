# Persuasion Principles for Skill Design

## Overview

LLMs 对与人类相同的说服 principle 有响应。理解这种 psychology 有助于设计更有效的 skills — 不是为了 manipulate，而是为了确保 critical practices 在压力下仍被遵循。

**Research foundation:** Meincke et al. (2025) 用 N=28,000 AI conversations 测试 7 种 persuasion principles。Persuasion techniques 将 compliance rates 提高一倍以上（33% → 72%, p < .001）。

## The Seven Principles

### 1. Authority
**What it is:** 对 expertise、credentials 或 official sources 的 defer。

**How it works in skills:**
- Imperative language: "YOU MUST", "Never", "Always"
- Non-negotiable framing: "No exceptions"
- 消除 decision fatigue 和 rationalization

**When to use:**
- Discipline-enforcing skills（TDD、verification requirements）
- Safety-critical practices
- Established best practices

**Example:**
```markdown
✅ Write code before test? Delete it. Start over. No exceptions.
❌ Consider writing tests first when feasible.
```

### 2. Commitment
**What it is:** 与 prior actions、statements 或 public declarations 一致。

**How it works in skills:**
- Require announcements: "Announce skill usage"
- Force explicit choices: "Choose A, B, or C"
- Use tracking: checklists 的 todos

**When to use:**
- 确保 skills 实际被 follow
- Multi-step processes
- Accountability mechanisms

**Example:**
```markdown
✅ When you find a skill, you MUST announce: "I'm using [Skill Name]"
❌ Consider letting your partner know which skill you're using.
```

### 3. Scarcity
**What it is:** 来自 time limits 或 limited availability 的 urgency。

**How it works in skills:**
- Time-bound requirements: "Before proceeding"
- Sequential dependencies: "Immediately after X"
- 防止 procrastination

**When to use:**
- Immediate verification requirements
- Time-sensitive workflows
- 防止 "I'll do it later"

**Example:**
```markdown
✅ After completing a task, IMMEDIATELY request code review before proceeding.
❌ You can review code when convenient.
```

### 4. Social Proof
**What it is:** 符合他人做法或被视为 normal 的行为。

**How it works in skills:**
- Universal patterns: "Every time", "Always"
- Failure modes: "X without Y = failure"
- 建立 norms

**When to use:**
- Documenting universal practices
- Warning about common failures
- Reinforcing standards

**Example:**
```markdown
✅ Checklists without todo tracking = steps get skipped. Every time.
❌ Some people find a todo list helpful for checklists.
```

### 5. Unity
**What it is:** 共享 identity、"we-ness"、in-group belonging。

**How it works in skills:**
- Collaborative language: "our codebase", "we're colleagues"
- Shared goals: "we both want quality"

**When to use:**
- Collaborative workflows
- Establishing team culture
- Non-hierarchical practices

**Example:**
```markdown
✅ We're colleagues working together. I need your honest technical judgment.
❌ You should probably tell me if I'm wrong.
```

### 6. Reciprocity
**What it is:** 回报所受益处的义务。

**How it works:**
-  sparingly 使用 — 可能 feel manipulative
- 很少在 skills 中需要

**When to avoid:**
- 几乎 always（其他 principles 更有效）

### 7. Liking
**What it is:** 偏好与喜欢的人合作。

**How it works:**
- **DON'T USE for compliance**
- 与 honest feedback culture 冲突
- 产生 sycophancy

**When to avoid:**
- Discipline enforcement 时 always

## Principle Combinations by Skill Type

| Skill Type | Use | Avoid |
|------------|-----|-------|
| Discipline-enforcing | Authority + Commitment + Social Proof | Liking, Reciprocity |
| Guidance/technique | Moderate Authority + Unity | Heavy authority |
| Collaborative | Unity + Commitment | Authority, Liking |
| Reference | Clarity only | All persuasion |

## Why This Works: The Psychology

**Bright-line rules reduce rationalization:**
- "YOU MUST" 移除 decision fatigue
- Absolute language 消除 "is this an exception?" 问题
- Explicit anti-rationalization counters 关闭 specific loopholes

**Implementation intentions create automatic behavior:**
- Clear triggers + required actions = automatic execution
- "When X, do Y" 比 "generally do Y" 更有效
- 降低 compliance 的 cognitive load

**LLMs are parahuman:**
- 在含这些 patterns 的 human text 上训练
- Training data 中 Authority language 先于 compliance
- Commitment sequences（statement → action）频繁 modeled
- Social proof patterns（everyone does X）建立 norms

## Ethical Use

**Legitimate:**
- 确保 critical practices 被 follow
- 创建 effective documentation
- 防止 predictable failures

**Illegitimate:**
- 为 personal gain manipulate
- 制造 false urgency
- 基于 guilt 的 compliance

**The test:** 若 user 完全理解，此 technique 是否 serve 其 genuine interests？

## Research Citations

**Cialdini, R. B. (2021).** *Influence: The Psychology of Persuasion (New and Expanded).* Harper Business.
- Seven principles of persuasion
- Influence research 的 empirical foundation

**Meincke, L., Shapiro, D., Duckworth, A. L., Mollick, E., Mollick, L., & Cialdini, R. (2025).** Call Me A Jerk: Persuading AI to Comply with Objectionable Requests. University of Pennsylvania.
- N=28,000 LLM conversations 测试 7 principles
- Persuasion techniques 下 compliance 从 33% → 72%
- Authority、commitment、scarcity 最有效
- 验证 LLM behavior 的 parahuman model

## Quick Reference

设计 skill 时问：

1. **What type is it?**（Discipline vs. guidance vs. reference）
2. **What behavior am I trying to change?**
3. **Which principle(s) apply?**（Discipline 通常 authority + commitment）
4. **Am I combining too many?**（不要用全部七个）
5. **Is this ethical?**（Serves user's genuine interests?）
