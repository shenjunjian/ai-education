## Subagent dispatch 需要 multi-agent 支持

添加到你的 Codex config（`~/.codex/config.toml`）：

```toml
[features]
multi_agent = true
```

这会启用 `dispatching-parallel-agents` 和 `subagent-driven-development` 等 skills 使用的 multi-agent tools。
你获得的 tools 取决于 model preset 选择的 multi-agent 版本（当前 presets 运行 V2；较旧的运行 V1）。当与任何表格（包括本表）不一致时，以实际 tool 列表为准。

- **Spawning：** 用 `spawn_agent {fork_turns: "none"}` 给 child 干净的 context；默认 `"all"` 会把整个 transcript 复制到 child。在 Codex 0.145+ 上，`~/.codex/agents/` 下的 role 文件通过 `agent_type` 附加到 isolated forks。Full-history forks 接受 `model` 和 `reasoning_effort` 覆盖（那里只拒绝 `agent_type`）— isolated forks 是 SDD 的默认选择，是为了 context hygiene，不是因为 override 需要它们。
- **Fix rounds：** 用 `followup_task` resume implementer — 它会传递你的消息、触发一轮，并在 harness 驱逐 child 后透明地重新加载。不要基于「spawned agent 无法再次接收消息」的理论 dispatch 新的 implementer；在 V2 上始终可以。
- **Lifecycle：** V2 没有 `close_agent`。Finished children 在需要 slot 时自动 evict；不 close 也没有成本。只有 V1 sessions 有 `close_agent` — 在那里，review 返回后 close reviewers，每个 task 的 review 通过后 close 对应的 implementer。
- **Model names：** 不要将 skill、表格或旧 session 中的 model name 复制到 `spawn_agent`，除非对照当前 spawn allowlist 验证 — V2 只接受 V2-capable presets，其余会 hard-error。

## Waiting on children

`wait_agent` 是 event subscription，不是 poll：long wait 在 child 产生 mailbox activity 的瞬间唤醒，延迟与 short wait 相同。Short-timeout polling 没有好处，每次 poll 还要消耗一次 tool call — 以及 context rebill。在实测 session 中，大约三分之二的 wait 调用是超时的 short polls。

- 当你仍有本地工作时，根本不要 wait。Completed child 的最终答案会推入你的 mailbox，并在下一轮随 turn 到达。
- 当你真正 idle 且仍有 outstanding children 时，以 bounded stretches 等待：`wait_agent`，`timeout_ms` 300000-600000（5-10 分钟）。每段 stretch 之后 — wake 或 timeout — 发一行 status，运行 `list_agents`，追查任何已完成但未报告的 child。Never stack polls shorter than five minutes；event subscription 唤醒 bounded stretch 与 short one 一样快。
- Completion mail 无法唤醒 idle controller（delivered 时不触发 turn）；覆盖该 idle window 是 `wait_agent` 的唯一职责。stretch timeout 且无 activity 是你 reconcile 的信号，不是缩短下一段 stretch 的信号。

## Model routing on spawns

你发出的每个 `spawn_agent` — 包括当你自己是 spawned child 运行 fan-out 时 — 都按你正在执行的 skill 的 Model Selection 规则显式设置 `model` AND `reasoning_effort`。只设置 `model` 是陷阱：child 的 effort 会静默重置为该 model 的 default，而不是你的。

请你的 human partner 在 `~/.codex/config.toml` 中添加 machine-level backstop，使任何漏网的 spawn 仍路由到 deliberate tier，而不是静默继承 session 中最贵的 model：

```toml
[agents]
default_subagent_model = "<a mid-tier model from your spawn allowlist>"
default_subagent_reasoning_effort = "medium"
```

## Environment Detection

创建 worktrees 或 finish branches 的 skills 在继续之前应通过只读 git 命令检测环境：

```bash
GIT_DIR=$(cd "$(git rev-parse --git-dir)" 2>/dev/null && pwd -P)
GIT_COMMON=$(cd "$(git rev-parse --git-common-dir)" 2>/dev/null && pwd -P)
BRANCH=$(git branch --show-current)
```

- `GIT_DIR != GIT_COMMON` → 已在 linked worktree 中（跳过创建）
- `BRANCH` 为空 → detached HEAD（无法从 sandbox branch/push/PR）

见 `using-git-worktrees` Step 0 和 `finishing-a-development-branch` Step 1，了解各 skill 如何使用这些信号。

## Codex App Finishing

当 sandbox 阻止 branch/push 操作（externally managed worktree 中的 detached HEAD）时，agent 提交所有工作并告知用户使用 App 的原生控件：

- **"Create branch"** — 命名 branch，然后通过 App UI commit/push/PR
- **"Hand off to local"** — 将工作转移到用户的 local checkout

agent 仍可运行 tests、stage 文件，并输出建议的 branch names、commit messages 和 PR descriptions 供用户复制。
