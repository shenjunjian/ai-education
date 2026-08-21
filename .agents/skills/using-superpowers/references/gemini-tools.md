# Gemini CLI Tool Mapping

Skills 用动作描述（"dispatch a subagent"、"create a todo"、"read a file"）。在 Gemini CLI 上，这些动作对应下方 tools。

| Action skills request | Gemini CLI equivalent |
|----------------------|----------------------|
| Read a file | `read_file` |
| Read multiple files at once | `read_many_files` |
| Create a new file | `write_file` |
| Edit a file | `replace` |
| Run a shell command | `run_shell_command` |
| Search file contents | `grep_search` |
| Find files by name | `glob` |
| List files and subdirectories | `list_directory` |
| Fetch a URL | `web_fetch` |
| Search the web | `google_web_search` |
| Invoke a skill | `activate_skill` |
| Dispatch a subagent (`Subagent (general-purpose):` template) | `invoke_agent`，`agent_name: "generalist"`（可通过 `@generalist` chat syntax 调用 — 见 [Subagent support](#subagent-support)） |
| Multiple parallel dispatches | 同一响应中多次 `invoke_agent` 调用 |
| Task tracking ("create a todo", "mark complete") | `write_todos`（statuses: pending, in_progress, completed, cancelled, blocked） |

## Instructions file

当 skill 提到 "your instructions file" 时，在 Gemini CLI 上这是 **`GEMINI.md`**。Gemini CLI 分层加载 `GEMINI.md`：全局位于 `~/.gemini/GEMINI.md`，workspace 目录及其祖先中的项目级文件，以及 tool 访问子目录文件时的子目录 `GEMINI.md`。

## Personal skills directory

用户级 skills 位于 **`~/.gemini/skills/`**，**`~/.agents/skills/`** 作为跨 runtime 别名（与 Codex 和 Copilot CLI 共享）。当同一 scope 下两个目录都存在时，`.agents/skills/` 优先。每个 skill 是一个包含 `SKILL.md`（带 `name` 和 `description` frontmatter）的子目录。

## Subagent support

Gemini CLI 通过 `invoke_agent` tool 调度 subagents，该 tool 接受 `agent_name` 和 `prompt` 参数。同样的 dispatch 也作为 chat-syntax 快捷方式：输入 `@generalist <prompt>` 等价于调用 `agent_name: "generalist"` 的 `invoke_agent`。内置 agent 名称包括 `generalist`、`cli_help`、`codebase_investigator`，以及（启用 browser tooling 时）`browser_agent`。

Skills 使用 `Subagent (general-purpose):` 进行 dispatch，并引用 prompt-template 文件（例如 `superpowers:subagent-driven-development` 的 `./implementer-prompt.md`）或提供 inline prompt。在 Gemini CLI 上：

| Skill dispatch form | Gemini CLI equivalent |
|---------------------|----------------------|
| 引用 `*-prompt.md` template（implementer、task-reviewer、code-reviewer 等） | 填充 template，然后 `invoke_agent`，`agent_name: "generalist"`，传入填充后的 prompt |
| 引用 `superpowers:requesting-code-review` 的 `./code-reviewer.md` | `invoke_agent`，`agent_name: "generalist"`，传入填充后的 review template |
| Inline prompt（无 template 引用） | `invoke_agent`，`agent_name: "generalist"`，传入 inline prompt |

### Prompt filling

Skills 提供带占位符的 prompt templates，如 `{WHAT_WAS_IMPLEMENTED}` 或 `[FULL TEXT of task]`。在将完整 prompt 传给 `invoke_agent` 之前，填充所有占位符。prompt template 本身包含 agent 的角色、review 标准和预期输出格式 — subagent 会遵循它。

### Parallel dispatch

Gemini CLI 支持 parallel subagent dispatch。在同一响应中发出多次 `invoke_agent` 调用（或在一个 prompt 中多次 `@generalist` 调用）以并行运行独立的 subagent 工作。有依赖的任务保持顺序，但不要为了简化 history 而串行化独立的 subagent 任务。

## Additional Gemini CLI tools

这些 tools 为 Gemini CLI 独有：

| Tool | Purpose |
|------|---------|
| `save_memory` (legacy) | 当 `experimental.memoryV2 = false` 时跨 session 持久化事实 |
| `get_internal_docs` | 查找 Gemini CLI 内置文档 |
| `ask_user` | 向用户提出结构化问题（text / single-select / multi-select） |
| `enter_plan_mode` / `exit_plan_mode` | 进入/退出只读 plan mode |
| `update_topic` | 更新当前对话的 topic / strategic-intent metadata |
| `complete_task` | 信号 Gemini subagent 已完成并将其结果返回给 parent agent |
| `tracker_create_task`, `tracker_update_task`, `tracker_get_task`, `tracker_list_tasks`, `tracker_add_dependency`, `tracker_visualize` | 带依赖和可视化支持的 rich task tracker |
| `read_mcp_resource`, `list_mcp_resources` | MCP resource 访问 |
