---
name: finishing-a-development-branch
description: implementation 完成、所有 test pass、需要决定如何 integrate 工作时使用
---

# Finishing a Development Branch

## Overview

**Core principle:** Verify tests → Detect environment → Present options → Execute choice → Clean up.

**Announce at start:** 「I'm using the finishing-a-development-branch skill to complete this work.」

## Step 1: Verify Tests

Run 项目的 full test suite（`npm test` / `cargo test` / `pytest` / `go test ./...`）。

**If tests fail**，report failures 并 stop——menu 在 green suite 之后：

```
Tests failing (<N> failures). Must fix before completing:

[Show failures]
```

**If tests pass:** continue to Step 2.

## Step 2: Detect Environment

```bash
GIT_DIR=$(cd "$(git rev-parse --git-dir)" 2>/dev/null && pwd -P)
GIT_COMMON=$(cd "$(git rev-parse --git-common-dir)" 2>/dev/null && pwd -P)
# Capture now, while still inside the workspace — Step 5 changes directory
# before cleanup (Step 6) needs this value
WORKTREE_PATH=$(git rev-parse --show-toplevel)
```

这决定显示哪个 menu 以及 cleanup 如何工作：

| State | Menu | Cleanup |
|-------|------|---------|
| `GIT_DIR == GIT_COMMON` (normal repo) | Standard 3 options | No worktree to clean up |
| `GIT_DIR != GIT_COMMON`, named branch | Standard 3 options | Provenance-based (see Step 6) |
| `GIT_DIR != GIT_COMMON`, detached HEAD | Reduced 2 options (no merge) | Externally managed — leave in place |

## Step 3: Determine Base Branch

Base branch 是本工作 fork 自的分支——通常在 plan、conversation 或 branch upstream 中命名。若尚不清楚，问：「This branch split from <your best guess> - is that correct?」
Merge 前 confirm：merge 到 wrong base 代价高。

## Step 4: Present Options

**Normal repo and named-branch worktree — present exactly these 3 options:**

```
Implementation complete. What would you like to do?

1. Merge back to <base-branch> locally
2. Push and create a Pull Request
3. Keep the branch as-is (I'll handle it later)

Which option?
```

**Detached HEAD — present exactly these 2 options:**

```
Implementation complete. You're on a detached HEAD (externally managed workspace).

1. Push as new branch and create a Pull Request
2. Keep as-is (I'll handle it later)

Which option?
```

Present menu exactly as written——简洁，每个 option 来自上方 list。Discard 工作仅当 your human partner explicitly 要求时（见下方 「If your human partner asks to discard the work」）。Wait for answer；integration 决定是他们的。

## Step 5: Execute Choice

### Option 1: Merge Locally

```bash
# Get main repo root for CWD safety
MAIN_ROOT=$(git -C "$(git rev-parse --git-common-dir)/.." rev-parse --show-toplevel)
cd "$MAIN_ROOT"

# Merge first — verify success before removing anything
git checkout <base-branch>
git pull
git merge <feature-branch>

# Verify tests on merged result
<test command>
```

若 merged result 上 test fail：stop，leave worktree 与 branch，investigate——未 push，merge 是 local 且 recoverable。

Once merged result green：clean up worktree (Step 6)，然后 delete branch：

```bash
git branch -d <feature-branch>
```

### Option 2: Push and Create PR

```bash
git push -u origin <feature-branch>
# From a detached HEAD, name the new branch on the remote:
# git push origin HEAD:refs/heads/<new-branch>
```

Then 用 forge tooling 创建 pull/merge request against <base-branch>——可用 CLI，或 push 时 forge 打印的 creation URL——遵循 repo PR template 与 conventions（若有），并向 your human partner report URL。

Keep worktree——your human partner 在 PR feedback 上 iterate。

### Option 3: Keep As-Is

Report: 「Keeping branch <name>. Worktree preserved at <path>.」

### If your human partner asks to discard the work

此路径仅作为 explicit 丢弃请求的响应。先 confirm：

```
This will permanently delete:
- Branch <name>
- All commits: <commit-list>
- Worktree at <path>

Type 'discard' to confirm.
```

Wait for that exact confirmation. When it arrives:

```bash
MAIN_ROOT=$(git -C "$(git rev-parse --git-common-dir)/.." rev-parse --show-toplevel)
cd "$MAIN_ROOT"
```

Then clean up worktree (Step 6) 并 force-delete branch：

```bash
git branch -D <feature-branch>
```

## Step 6: Cleanup Workspace

**Runs for Option 1 and confirmed discards.** Options 2 and 3 always preserve worktree。两个 caller 已 cd 到 main repo root——worktree removal 必须从 worktree 外运行——并使用 Step 2 在 directory change 前捕获的 `GIT_DIR`/`GIT_COMMON`/`WORKTREE_PATH`。

**If `GIT_DIR == GIT_COMMON`:** Normal repo，无 worktree cleanup。Done.

**If `WORKTREE_PATH` is under `.worktrees/` or `worktrees/`:** Superpowers 创建此 worktree——我们负责 cleanup：

```bash
git worktree remove "$WORKTREE_PATH"
git worktree prune  # Self-healing: clean up any stale registrations
```

**If removal is refused** (`contains modified or untracked files`)：worktree 有仅存在于其中的 file——uncommitted plan、note 或 scratch。Never 自行 `--force`。Show your human partner 风险并 ask：

```bash
git -C "$WORKTREE_PATH" status --porcelain -uall
```

```
Worktree removal refused — these files were never committed:

<file list>

1. Commit them to <branch> before cleanup
2. Move them into <main repo root>
3. Delete them (unrecoverable)

Which?
```

Carry out choice，then remove worktree.

**Otherwise:** Host environment 拥有此 workspace——leave in place。若 platform 提供 workspace-exit tool，使用它。

## Quick Reference

| Option | Merge | Push | Keep Worktree | Cleanup Branch |
|--------|-------|------|---------------|----------------|
| 1. Merge locally | yes | - | - | yes |
| 2. Create PR | - | yes | yes | - |
| 3. Keep as-is | - | - | yes | - |
| Discard (explicit request only) | - | - | - | yes (force) |

## Common Rationalizations

| Excuse | Reality |
|--------|---------|
| 「Tests passed earlier this session」 | 在即将 integrate 的 tree 上 run suite。Green run 只证明它跑过的 tree。 |
| 「They obviously want it merged」 | Integration 是 your human partner 的决定。Present menu 并 wait。 |
| 「They seem done with this feature — I'll offer to discard it」 | Menu 已完整。Discard 仅当 partner 明确要求。 |
| 「'Yeah, get rid of it' counts as confirmation」 | 只有 typed word `discard` 授权 deletion。 |
| 「The PR is up, so the worktree is clutter now」 | PR feedback 在该 worktree 修复。直到 work land 前保留。 |
| 「This other worktree looks stale — I'll clean it too」 | 只 cleanup `.worktrees/` 或 `worktrees/` 下的 worktree。其余属于 host。 |
| 「Removal refused — `--force` is just finishing the cleanup」 | Refusal 表示 file 只在该 worktree。`--force` 永久销毁。Show partner 并 ask。 |
| 「The merged-result failure is probably flaky」 | Failing merged result 停止一切。Branch 与 worktree 保留 while investigate。 |
| 「The base branch is obviously main」 | Confirm fork point 或 ask。Merge 到 wrong base 代价高。 |
| 「The push was rejected — force-push will fix it」 | Rejected push 表示 remote moved。Investigate；force-push 仅 partner explicit 请求时。 |
