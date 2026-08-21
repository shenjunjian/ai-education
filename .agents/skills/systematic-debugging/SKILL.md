---
name: systematic-debugging
description: 遇到任何 bug、test failure 或意外行为时使用，在提出 fix 之前
---

# Systematic Debugging

## Overview

**Core principle:** 在尝试 fix 之前，必须 ALWAYS 找到 root cause。针对 symptom 的 fix 就是失败。

**违反本流程的字面要求，就是违反 debugging 的精神。**

## The Iron Law

```
NO FIXES WITHOUT ROOT CAUSE INVESTIGATION FIRST
```

如果你还没完成 Phase 1，就不能提出 fix。

## When to Use

适用于 ANY technical issue：
- Test failures
- Production 中的 bug
- Unexpected behavior
- Performance problems
- Build failures
- Integration issues

**ESPECIALLY 在以下情况使用：**
- 时间压力下（紧急情况下更容易靠猜）
- 「就改一个 quick fix」看起来很明显
- 你已经试过多个 fix
- 之前的 fix 没起作用
- 你并不完全理解问题

**不要跳过，即使：**
- 问题看起来简单（简单 bug 也有 root cause）
- 你很赶（匆忙几乎必然导致返工）
- Manager 要求 NOW 就修好（systematic 比反复试错更快）

## The Four Phases

你必须完成每个 phase，才能进入下一个。

### Phase 1: Root Cause Investigation

**在尝试 ANY fix 之前：**

1. **Read Error Messages Carefully**
   - 不要跳过 error 或 warning
   - 它们常常包含确切解法
   - 完整阅读 stack trace
   - 记下 line number、file path、error code

2. **Reproduce Consistently**
   - 能否可靠触发？
   - 确切步骤是什么？
   - 是否每次都会发生？
   - 若无法 reproduce → 收集更多 data，不要猜

3. **Check Recent Changes**
   - 什么变更可能导致此问题？
   - Git diff、recent commits
   - 新 dependency、config 变更
   - 环境差异

4. **Gather Evidence in Multi-Component Systems**

   **WHEN system 有多个 component（CI → build → signing，API → service → database）：**

   **在提出 fix 之前，添加 diagnostic instrumentation：**
   ```
   For EACH component boundary:
     - Log what data enters component
     - Log what data exits component
     - Verify environment/config propagation
     - Check state at each layer

   Run once to gather evidence showing WHERE it breaks
   THEN analyze evidence to identify failing component
   THEN investigate that specific component
   ```

   **Example（multi-layer system）：**
   ```bash
   # Layer 1: Workflow
   echo "=== Secrets available in workflow: ==="
   echo "IDENTITY: ${IDENTITY:+SET}${IDENTITY:-UNSET}"

   # Layer 2: Build script
   echo "=== Env vars in build script: ==="
   env | grep IDENTITY || echo "IDENTITY not in environment"

   # Layer 3: Signing script
   echo "=== Keychain state: ==="
   security list-keychains
   security find-identity -v

   # Layer 4: Actual signing
   codesign --sign "$IDENTITY" --verbose=4 "$APP"
   ```

   **This reveals:** 哪一层失败（secrets → workflow ✓，workflow → build ✗）

5. **Trace Data Flow**

   **WHEN error 深在 call stack 中：**

   完整 backward tracing 技术见本目录 `root-cause-tracing.md`。

   **Quick version:**
   - 坏 value 从哪来？
   - 谁用坏 value 调用了这里？
   - 一直向上 trace 直到找到 source
   - 在 source 处 fix，而不是在 symptom 处

### Phase 2: Pattern Analysis

**在 fix 之前找到 pattern：**

1. **Find Working Examples**
   - 在同一 codebase 中找到类似且能工作的 code
   - 什么能工作，而什么坏了？

2. **Compare Against References**
   - 若实现某种 pattern，COMPLETE 阅读 reference implementation
   - 不要 skim——逐行阅读
   - 在应用前完全理解 pattern

3. **Identify Differences**
   - working 与 broken 有何不同？
   - 列出每一个差异，再小也算
   - 不要假设「那不可能有影响」

4. **Understand Dependencies**
   - 还需要哪些其他 component？
   - 需要哪些 settings、config、environment？
   - 它做了哪些 assumption？

### Phase 3: Hypothesis and Testing

**Scientific method：**

1. **Form Single Hypothesis**
   - 清楚陈述：「I think X is the root cause because Y」
   - 写下来
   - 要具体，不要 vague

2. **Test Minimally**
   - 做 SMALLEST possible change 来 test hypothesis
   - 一次只改一个 variable
   - 不要一次 fix 多件事

3. **Verify Before Continuing**
   - 有效？Yes → Phase 4
   - 无效？Form NEW hypothesis
   - 不要在上面再叠更多 fix

4. **When You Don't Know**
   - 说「I don't understand X」
   - 不要假装知道
   - Ask for help
   - 继续 research

### Phase 4: Implementation

**Fix root cause，不是 symptom：**

1. **Create Failing Test Case**
   - 最简单的 reproduction
   - 可能的话用 automated test
   - 没有 framework 时用 one-off test script
   - 在 fix 之前 MUST 有
   - 写 proper failing test 用 `superpowers:test-driven-development` skill

2. **Implement Single Fix**
   - 针对已识别的 root cause
   - ONE change at a time
   - 不要「顺便」改进
   - 不要 bundled refactoring

3. **Verify Fix**
   - Test 现在 pass？
   - 没有其他 test broken？
   - 问题真的解决了？
   - 在声称 success 之前用 `superpowers:verification-before-completion` skill

4. **If Fix Doesn't Work**
   - STOP
   - Count：你试过几个 fix？
   - 若 < 3：Return to Phase 1，用新信息 re-analyze
   - **若 ≥ 3：STOP 并质疑 architecture（见下方 step 5）**
   - 没有 architectural discussion 不要尝试 Fix #4

5. **If 3+ Fixes Failed: Question Architecture**

   **表明 architectural problem 的 pattern：**
   - 每个 fix 在不同位置暴露新的 shared state/coupling/problem
   - Fix 需要「massive refactoring」才能实现
   - 每个 fix 在其他地方产生新 symptom

   **STOP 并质疑 fundamentals：**
   - 这个 pattern 从根本上是否合理？
   - 我们是否「靠惯性硬撑」？
   - 应该 refactor architecture，还是继续 fix symptom？

   **在尝试更多 fix 之前与 your human partner 讨论**

   这不是 failed hypothesis——这是 wrong architecture。

## Red Flags - STOP and Follow Process

若你发现自己这样想：
- 「Quick fix for now, investigate later」
- 「Just try changing X and see if it works」
- 「Add multiple changes, run tests」
- 「Skip the test, I'll manually verify」
- 「It's probably X, let me fix that」
- 「I don't fully understand but this might work」
- 「Pattern says X but I'll adapt it differently」
- 「Here are the main problems: [lists fixes without investigation]」
- 在 trace data flow 之前就提出 solution
- **「One more fix attempt」（已经试过 2+ 次）**
- **每个 fix 在不同位置暴露新问题**

**ALL of these mean: STOP. Return to Phase 1.**

**If 3+ fixes failed:** Question the architecture（见 Phase 4.5）

## your human partner's Signals You're Doing It Wrong

**Watch for these redirections:**
- 「Is that not happening?」—— 你 assumed 而没有 verify
- 「Will it show us...?」—— 你应该已添加 evidence gathering
- 「Stop guessing」—— 你在不理解的情况下提出 fix
- 「Ultra-think this」—— 质疑 fundamentals，不只是 symptom
- 「We're stuck?」（frustrated）—— 你的方法不起作用

**When you see these:** STOP. Return to Phase 1.

## Common Rationalizations

| Excuse | Reality |
|--------|---------|
| 「Issue is simple, don't need process」 | 简单 issue 也有 root cause。Process 对简单 bug 也很快。 |
| 「Emergency, no time for process」 | Systematic debugging 比 guess-and-check thrashing 更快。 |
| 「Just try this first, then investigate」 | 第一个 fix 定下 pattern。从一开始就做对。 |
| 「I'll write test after confirming fix works」 | 未 test 的 fix 站不住。Test first 才能证明。 |
| 「Multiple fixes at once saves time」 | 无法 isolate 什么有效。会引入新 bug。 |
| 「Reference too long, I'll adapt the pattern」 | 部分理解必然带来 bug。Complete 阅读。 |
| 「I see the problem, let me fix it」 | 看到 symptom ≠ 理解 root cause。 |
| 「One more fix attempt」（2+ failures 后） | 3+ failures = architectural problem。质疑 pattern，不要再 fix。 |

## Quick Reference

| Phase | Key Activities | Success Criteria |
|-------|---------------|------------------|
| **1. Root Cause** | Read errors, reproduce, check changes, gather evidence | 理解 WHAT 和 WHY |
| **2. Pattern** | Find working examples, compare | Identify differences |
| **3. Hypothesis** | Form theory, test minimally | Confirmed or new hypothesis |
| **4. Implementation** | Create test, fix, verify | Bug resolved, tests pass |

## When Process Reveals "No Root Cause"

若 systematic investigation 表明 issue 真是 environmental、timing-dependent 或 external：

1. 你已完成 process
2. Document 你调查了什么
3. Implement appropriate handling（retry、timeout、error message）
4. Add monitoring/logging 供未来 investigation

**But:** 95% 的「no root cause」是 investigation 不完整。

## Supporting Techniques

这些 technique 属于 systematic debugging，在本目录可用：

- **`root-cause-tracing.md`** - 沿 call stack backward trace bug，找到 original trigger
- **`defense-in-depth.md`** - 找到 root cause 后在多层添加 validation
- **`condition-based-waiting.md`** - 用 condition polling 替换 arbitrary timeout
