# Issue tracker: GitHub

本仓库的 issues 和 specs 以 GitHub issues 形式存放。所有操作使用 `gh` CLI。

## 约定

- **创建 issue**：`gh issue create --title "..." --body "..."`。多行正文使用 heredoc。
- **读取 issue**：`gh issue view <number> --comments`，用 `jq` 过滤 comments，同时获取 labels。
- **列出 issues**：`gh issue list --state open --json number,title,body,labels,comments --jq '[.[] | {number, title, body, labels: [.labels[].name], comments: [.comments[].body]}]'`，配合适当的 `--label` 和 `--state` 过滤。
- **在 issue 上评论**：`gh issue comment <number> --body "..."`
- **添加 / 移除 labels**：`gh issue edit <number> --add-label "..."` / `--remove-label "..."`
- **关闭**：`gh issue close <number> --comment "..."`

从 `git remote -v` 推断仓库——在 clone 内运行时 `gh` 会自动完成。

## Pull requests 作为分诊入口

**PRs as a request surface: no.** _（若本仓库把外部 PRs 当作功能请求，设为 `yes`；`/triage` 会读取此标志。）_

设为 `yes` 时，PRs 走与 issues 相同的 labels 和状态，使用 `gh pr` 的对应命令：

- **读取 PR**：`gh pr view <number> --comments`，diff 用 `gh pr diff <number>`。
- **列出待分诊的外部 PRs**：`gh pr list --state open --json number,title,body,labels,author,authorAssociation,comments`，然后只保留 `authorAssociation` 为 `CONTRIBUTOR`、`FIRST_TIME_CONTRIBUTOR` 或 `NONE` 的（丢掉 `OWNER`/`MEMBER`/`COLLABORATOR`）。
- **评论 / 打标签 / 关闭**：`gh pr comment`、`gh pr edit --add-label`/`--remove-label`、`gh pr close`。

GitHub 在 issues 和 PRs 之间共享同一套编号空间，所以光秃的 `#42` 可能是二者之一——用 `gh pr view 42` 解析，失败再回退到 `gh issue view 42`。

## 当某个 skill 说「发布到 issue tracker」

创建一个 GitHub issue。

## 当某个 skill 说「拉取相关 ticket」

运行 `gh issue view <number> --comments`。

## Wayfinding 操作

供 `/wayfinder` 使用。**map** 是单个 issue，**child** issues 作为 tickets。

- **Map**：单个打了 `wayfinder:map` 标签的 issue，正文为 Notes / Decisions-so-far / Fog。`gh issue create --label wayfinder:map`。
- **Child ticket**：作为 GitHub sub-issue 链到 map 的 issue（对 sub-issues endpoint 使用 `gh api`）。若未启用 sub-issues，把 child 加到 map 正文的 task list 里，并在 child 正文顶部放 `Part of #<map>`。Labels：`wayfinder:<type>`（`research`/`prototype`/`grilling`/`task`）。一旦认领，ticket 指派给正在驱动的开发者。
- **Blocking**：GitHub 的 **native issue dependencies** —— 规范的、UI 可见的表示。用 `gh api --method POST repos/<owner>/<repo>/issues/<child>/dependencies/blocked_by -F issue_id=<blocker-db-id>` 加一条边，其中 `<blocker-db-id>` 是 blocker 的数字 **database id**（`gh api repos/<owner>/<repo>/issues/<n> --jq .id`，_不是_ `#number` 或 `node_id`）。GitHub 报告 `issue_dependencies_summary.blocked_by`（仅开放的 blockers —— 实时闸门）。若 dependencies 不可用，回退为在 child 正文顶部放一行 `Blocked by: #<n>, #<n>`。当每个 blocker 都已关闭时，ticket 即解除阻塞。
- **Frontier query**：列出 map 的开放 children（`gh issue list --state open`，限定到 map 的 sub-issues / task list），丢掉任何仍有开放 blocker 的（`issue_dependencies_summary.blocked_by > 0`，或 `Blocked by` 行里有开放 issue）或已有 assignee 的；map 顺序中第一个胜出。
- **Claim**：`gh issue edit <n> --add-assignee @me` —— 本会话的第一次写入。
- **Resolve**：`gh issue comment <n> --body "<answer>"`，然后 `gh issue close <n>`，再把上下文指针（gist + 链接）追加到 map 的 Decisions-so-far。
