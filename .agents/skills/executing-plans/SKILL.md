---
name: executing-plans
description: 在单独 session 中执行书面 implementation plan、并带 review checkpoint 时使用
---

# Executing Plans

## Overview

Load plan，critical review，execute 所有 task，完成时 report。

**Announce at start:** 「I'm using the executing-plans skill to implement this plan.」

**Note:** 告诉 your human partner：有 subagent 访问时 Superpowers 好用得多（Claude Code、Codex CLI、Codex App、Copilot CLI、Gemini CLI 均 qualify；见 `../using-superpowers/references/` 中 per-platform tool refs）。若 subagent 可用，用 superpowers:subagent-driven-development 代替本 skill。

## The Process

### Step 1: Load and Review Plan
1. Ensure isolated workspace：用 superpowers:using-git-worktrees 创建或 verify 现有 worktree
2. Read plan file
3. Review critically - 识别对 plan 的任何 question 或 concern
4. 若有 concern：starting 前与 your human partner 提出
5. 若无 concern：为 plan items 创建 todo 并 proceed

### Step 2: Execute Tasks

For each task:
1. Mark as in_progress
2. Follow each step exactly（plan 有 bite-sized steps）
3. Run verifications as specified
4. Mark as completed

### Step 3: Complete Development

After all tasks complete and verified:
- Announce: 「I'm using the finishing-a-development-branch skill to complete this work.」
- **REQUIRED SUB-SKILL:** Use superpowers:finishing-a-development-branch
- Follow that skill to verify tests, present options, execute choice

## When to Stop and Ask for Help

**STOP executing immediately when:**
- Hit blocker（missing dependency、test fails、instruction unclear）
- Plan 有 critical gap 阻止 starting
- 你不理解某条 instruction
- Verification fails repeatedly

**Ask for clarification rather than guessing.**

## When to Revisit Earlier Steps

**Return to Review (Step 1) when:**
- Partner 根据你的 feedback 更新 plan
- Fundamental approach 需要 rethinking

**Don't force through blockers** - stop and ask.

## Remember
- Review plan critically first
- Follow plan steps exactly
- Don't skip verifications
- Reference skills when plan says to
- Stop when blocked, don't guess
- Never start implementation on main/master branch without explicit user consent
