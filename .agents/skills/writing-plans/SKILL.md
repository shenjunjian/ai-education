---
name: writing-plans
description: 当你有 spec 或多步骤任务的 requirements、尚未动 code 时使用
---

# Writing Plans

## Overview

编写 comprehensive implementation plans，假设工程师对 codebase 零 context、品味 questionable。Document 他们需要知道的一切：每个 task 要动哪些 files、code、testing、可能需要查的 docs、如何 test。将整个 plan 作为 bite-sized tasks 给出。DRY。YAGNI。TDD。Frequent commits。

假设他们是 skilled developer，但几乎不了解我们的 toolset 或 problem domain。假设他们不太懂 good test design。

**Announce at start:** "I'm using the writing-plans skill to create the implementation plan."

**Context:** 若在 isolated worktree 中工作，应已在 execution time 通过 `superpowers:using-git-worktrees` skill 创建。

**Save plans to:** `docs/superpowers/plans/YYYY-MM-DD-<feature-name>.md`
- （User 对 plan location 的偏好 override 此 default）

## Scope Check

若 spec 覆盖多个独立 subsystems，brainstorming 期间应已拆成 sub-project specs。若没有，建议拆成 separate plans — 每个 subsystem 一个。每个 plan 应 independently 产出 working、testable software。

## File Structure

定义 tasks 之前，map 将创建或修改的 files 及各自职责。Decomposition decisions 在此锁定。

- Design units 有 clear boundaries 和 well-defined interfaces。每个 file 应 one clear responsibility。
- 你 reason 最好 about 能一次 hold in context 的 code，files focused 时 edits 更可靠。Prefer smaller、focused files over 做太多的 large ones。
- 一起变的 files 应 live together。按 responsibility split，不是 technical layer。
- 在 existing codebases 中 follow established patterns。若 codebase 用大 files，不要 unilaterally restructure — 但若你修改的 file 已 unwieldy，在 plan 中包含 split 合理。

此 structure  inform task decomposition。每个 task 应产出 self-contained changes，independently 有意义。

## Task Right-Sizing

Task 是 carry 自己 test cycle 且 worth fresh reviewer gate 的最小 unit。画 task boundaries 时：将 setup、
configuration、scaffolding、documentation steps fold 进其 deliverable 需要的 task；仅当 reviewer 能 meaningfully
reject 一个 task 而 approve 邻居时才 split。每个 task 以 independently testable deliverable 结束。

## Bite-Sized Task Granularity

**Each step 是一个 action（2-5 minutes）：**
- "Write the failing test" - step
- "Run it to make sure it fails" - step
- "Implement the minimal code to make the test pass" - step
- "Run the tests and make sure they pass" - step
- "Commit" - step

## Plan Document Header

**Every plan MUST 以此 header 开始：**

```markdown
# [Feature Name] Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** [One sentence describing what this builds]

**Architecture:** [2-3 sentences about approach]

**Tech Stack:** [Key technologies/libraries]

**Spec:** [path to the spec/design doc this plan implements — the plan
argues from the spec, so the spec travels with it; executors read both]

## Global Constraints

[The spec's project-wide requirements — version floors, dependency limits,
naming and copy rules, platform requirements — one line each, with exact
values copied verbatim from the spec. Every task's requirements implicitly
include this section.]

---
```

## Task Structure

````markdown
### Task N: [Component Name]

**Files:**
- Create: `exact/path/to/file.py`
- Modify: `exact/path/to/existing.py:123-145`
- Test: `tests/exact/path/to/test.py`

**Interfaces:**
- Consumes: [what this task uses from earlier tasks — exact signatures]
- Produces: [what later tasks rely on — exact function names, parameter
  and return types. A task's implementer sees only their own task; this
  block is how they learn the names and types neighboring tasks use.]

- [ ] **Step 1: Write the failing test**

```python
def test_specific_behavior():
    result = function(input)
    assert result == expected
```

- [ ] **Step 2: Run test to verify it fails**

Run: `pytest tests/path/test.py::test_name -v`
Expected: FAIL with "function not defined"

- [ ] **Step 3: Write minimal implementation**

```python
def function(input):
    return expected
```

- [ ] **Step 4: Run test to verify it passes**

Run: `pytest tests/path/test.py::test_name -v`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add tests/path/test.py src/path/file.py
git commit -m "feat: add specific feature"
```
````

## No Placeholders

每个 step 必须包含工程师需要的 actual content。这些是 **plan failures** — never write them:
- "TBD", "TODO", "implement later", "fill in details"
- "Add appropriate error handling" / "add validation" / "handle edge cases"
- "Write tests for the above"（without actual test code）
- "Similar to Task N"（repeat the code — engineer 可能 out of order 读 tasks）
- 只描述做什么而不展示 how 的 steps（code steps 需要 code blocks）
- 任何 task 未定义的 types、functions 或 methods 的 references

## Self-Review

写完 complete plan 后，fresh eyes 对照 spec 检查 plan。这是你自己跑的 checklist — 不是 subagent dispatch。

**1. Spec coverage:** Skim spec 每个 section/requirement。能否指向实现它的 task？列出 gaps。

**2. Placeholder scan:** 在 plan 中搜索 red flags — "No Placeholders" section 中的任何 pattern。Fix them。

**3. Type consistency:** Later tasks 中的 types、method signatures、property names 是否与 earlier tasks 定义一致？Task 3 中 `clearLayers()` 但 Task 7 中 `clearFullLayers()` 是 bug。

发现问题 inline fix。无需 re-review — fix and move on。若发现 spec requirement 无 task，add the task。

## Execution Handoff

保存 plan 后，offer execution choice：

**"Plan complete and saved to `docs/superpowers/plans/<filename>.md`. Two execution options:**

**1. Subagent-Driven (recommended)** - 每个 task dispatch fresh subagent，tasks 间 review，fast iteration

**2. Inline Execution** - 在本 session 用 executing-plans 执行 tasks，batch execution with checkpoints

**Which approach?"**

**If Subagent-Driven chosen:**
- **REQUIRED SUB-SKILL:** Use superpowers:subagent-driven-development
- Fresh subagent per task + two-stage review

**If Inline Execution chosen:**
- **REQUIRED SUB-SKILL:** Use superpowers:executing-plans
- Batch execution with checkpoints for review
