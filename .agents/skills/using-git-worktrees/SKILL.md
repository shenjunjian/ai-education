---
name: using-git-worktrees
description: 当开始需要与当前 workspace 隔离的 feature work，或在执行 implementation plans 之前使用 — 通过 native tools 或 git worktree fallback 确保存在 isolated workspace
---

# Using Git Worktrees

## Overview

确保工作在 isolated workspace 中进行。Prefer platform 的 native worktree tools。仅当无 native tool 时 fall back 到 manual git worktrees。

**Core principle:** 先 detect existing isolation。Then use native tools。Then fall back to git。Never fight the harness。

**Announce at start:** "I'm using the using-git-worktrees skill to set up an isolated workspace."

## Step 0: Detect Existing Isolation

**Before creating anything，检查是否已在 isolated workspace 中。**

```bash
GIT_DIR=$(cd "$(git rev-parse --git-dir)" 2>/dev/null && pwd -P)
GIT_COMMON=$(cd "$(git rev-parse --git-common-dir)" 2>/dev/null && pwd -P)
BRANCH=$(git branch --show-current)
```

**Submodule guard:** `GIT_DIR != GIT_COMMON` 在 git submodules 内也为 true。在 conclude "already in a worktree" 之前，verify 不在 submodule 中：

```bash
# If this returns a path, you're in a submodule, not a worktree — treat as normal repo
git rev-parse --show-superproject-working-tree 2>/dev/null
```

**If `GIT_DIR != GIT_COMMON`（且 not a submodule）：** 已在 linked worktree 中。Skip to Step 2 (Project Setup)。Do NOT create another worktree。

Report with branch state:
- On a branch: "Already in isolated workspace at `<path>` on branch `<name>`."
- Detached HEAD: "Already in isolated workspace at `<path>` (detached HEAD, externally managed). Branch creation needed at finish time."

**If `GIT_DIR == GIT_COMMON`（或在 submodule 中）：** 在 normal repo checkout 中。

User 是否已在 instructions 中表明 worktree preference？若没有，创建 worktree 前 ask for consent：

> "Would you like me to set up an isolated worktree? It protects your current branch from changes."

Honor 任何已 declared preference 无需再问。若 user declines consent，work in place 并 skip to Step 2。

## Step 1: Create Isolated Workspace

**You have two mechanisms. Try them in this order.**

### 1a. Native Worktree Tools (preferred)

User 已请求 isolated workspace（Step 0 consent）。是否已有创建 worktree 的方式？可能是名为 `EnterWorktree`、`WorktreeCreate` 的 tool、`/worktree` command 或 `--worktree` flag。若有，使用并 skip to Step 2。

Native tools 自动处理 directory placement、branch creation 和 cleanup。有 native tool 时仍用 `git worktree add` 会创建 harness 看不见或管不了的 phantom state。

Only proceed to Step 1b if you have no native worktree tool available.

### 1b. Git Worktree Fallback

**Only use this if Step 1a does not apply** — 无 native worktree tool。用 git 手动创建 worktree。

#### Directory Selection

Follow 此 priority order。Explicit user preference 始终 beats observed filesystem state。

1. **Check your instructions for a declared worktree directory preference.** 若 user 已指定，使用无需再问。

2. **Check for an existing project-local worktree directory:**
   ```bash
   ls -d .worktrees 2>/dev/null     # Preferred (hidden)
   ls -d worktrees 2>/dev/null      # Alternative
   ```
   若 found，使用。若 both exist，`.worktrees` wins。

3. **If there is no other guidance available**，default 到 project root 的 `.worktrees/`。

#### Safety Verification (project-local directories only)

**MUST verify directory is ignored before creating worktree:**

```bash
git check-ignore -q .worktrees 2>/dev/null || git check-ignore -q worktrees 2>/dev/null
```

**If NOT ignored:** Add to .gitignore，commit the change，then proceed。

**Why critical:** 防止 accidentally 将 worktree contents commit 到 repository。

#### Create the Worktree

```bash
# Determine path based on chosen location
path="$LOCATION/$BRANCH_NAME"

git worktree add "$path" -b "$BRANCH_NAME"
cd "$path"
```

**Sandbox fallback:** 若 `git worktree add` 因 permission error（sandbox denial）失败，告知 user sandbox 阻止 worktree creation，改在当前 directory work。Then run setup and baseline tests in place。

## Step 2: Project Setup

Auto-detect 并 run appropriate setup:

```bash
# Node.js
if [ -f package.json ]; then npm install; fi

# Rust
if [ -f Cargo.toml ]; then cargo build; fi

# Python
if [ -f requirements.txt ]; then pip install -r requirements.txt; fi
if [ -f pyproject.toml ]; then poetry install; fi

# Go
if [ -f go.mod ]; then go mod download; fi
```

## Step 3: Verify Clean Baseline

Run tests 确保 workspace 以 clean 状态开始:

```bash
# Use project-appropriate command
npm test / cargo test / pytest / go test ./...
```

**If tests fail:** Report failures，ask whether to proceed or investigate。

**If tests pass:** Report ready。

### Report

```
Worktree ready at <full-path>
Tests passing (<N> tests, 0 failures)
Ready to implement <feature-name>
```

## Quick Reference

| Situation | Action |
|-----------|--------|
| Already in linked worktree | Skip creation (Step 0) |
| In a submodule | Treat as normal repo (Step 0 guard) |
| Native worktree tool available | Use it (Step 1a) |
| No native tool | Git worktree fallback (Step 1b) |
| `.worktrees/` exists | Use it (verify ignored) |
| `worktrees/` exists | Use it (verify ignored) |
| Both exist | Use `.worktrees/` |
| Neither exists | Check instruction file, then default `.worktrees/` |
| Directory not ignored | Add to .gitignore + commit |
| Permission error on create | Sandbox fallback, work in place |
| Tests fail during baseline | Report failures + ask |
| No package.json/Cargo.toml | Skip dependency install |

## Common Rationalizations

| Excuse | Reality |
|--------|---------|
| "I'm obviously not in a worktree — no need to check" | Run Step 0。Harness-created isolation 和 submodules 都会 fool eyeballing；detection commands 能定论。 |
| "`git worktree add` is quicker than hunting for a native tool" | Native tool（例如 `EnterWorktree`）own placement、branching 和 cleanup。Bypassing 是 #1 mistake — 创建 harness 看不见或管不了的 phantom state。 |
| "The worktree directory is surely ignored already" | Run `git check-ignore`。Unignored worktree directory 会把整棵树 commit 进 repo。 |
| "Any directory name works" | Explicit instructions beat existing project-local directory，后者 beat `.worktrees/` default。 |
| "The workspace is fresh — baseline tests can wait" | Dirty baseline 使之后每个 failure ambiguous。Now run tests；proceeding past failures 是 human partner 的决定。 |
