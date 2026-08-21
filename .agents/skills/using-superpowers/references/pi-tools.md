# Pi Tool Mapping

Skills 用动作描述（"dispatch a subagent"、"create a todo"、"read a file"）。在 Pi 上，这些动作对应下方 tools。

| Action skills request | Pi equivalent |
| --- | --- |
| Dispatch a subagent (`Subagent (general-purpose):` template) | 使用已安装的 subagent tool，例如 `pi-subagents` 提供的 `subagent`（若可用） |
| Task tracking ("create a todo", "mark complete") | 使用已安装的 todo/task tool（若可用），否则在 plan 或 `TODO.md` 中跟踪任务 |

## Subagents

Pi core 不自带标准 subagent tool。`pi-subagents` 包是强有力的可选 companion，提供 `subagent` tool，支持 single-agent、chain、parallel、async、forked-context 以及 resume/status 工作流。如果没有 subagent tool，不要伪造 `Task` 调用；在当前 session 中顺序执行，或说明未安装可选 subagent 能力。

## Task lists

Pi core 不自带标准 task-list tool。如果安装了 todo/task 扩展，使用其文档中的 tool。否则使用 Superpowers plan 文件、Markdown checklist，或 repo 本地的 `TODO.md` 进行任务跟踪。较旧的 Superpowers 文档可能提到 `TodoWrite`；将其视为上述 task-tracking 动作。
