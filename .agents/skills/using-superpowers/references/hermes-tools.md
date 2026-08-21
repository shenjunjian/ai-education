# Hermes Agent Tool Mapping

Skills 用动作描述（"dispatch a subagent"、"create a todo"、"read a file"）。在 Hermes Agent 上，这些动作对应下方 tools。

## Tools

| Action skills request | Hermes tool |
|---|---|
| Read a file | `read_file` |
| Create a new file | `write_file` |
| Edit a file (targeted patch) | `patch` |
| Run a shell command | `terminal` |
| Search file contents | `search_files` |
| Find files by name | `terminal` with `find` |
| Fetch a URL / read a webpage | `web_extract(urls=[...])` |
| Search the web | `web_search(query=...)` |
| Dispatch a subagent | `delegate_task(goal=..., context=..., toolsets=[...], role="leaf")` |
| Task tracking | `todo` tool |
| Invoke a skill | `skill_view("skill-name")` |

## Instructions file

当 skill 提到 "your instructions file" 时，在 Hermes Agent 上这是项目目录中的 **`AGENTS.md`**，或全局的 **`SOUL.md`**（位于 `~/.hermes/SOUL.md`）。

## Invoking a skill

Hermes Agent 有 `skills` toolset，包含 `skill_view` 和 `skills_list` tools。
要 invoke superpowers skill，使用：

```
skill_view("brainstorming")
skill_view("test-driven-development")
```

如果 `skill_view` 找不到 superpowers skill（在 plugin 完全注册前可能不会出现在 catalog 中），回退为直接读取 SKILL.md：

```
read_file(path="~/.hermes/plugins/superpowers/skills/<skill-name>/SKILL.md")
```

此回退机制与其他没有原生 skill loading 的 harnesses 相同。

## Subagent dispatch

使用 `delegate_task` 启动隔离 subagents 以并行或顺序处理工作流：

```
delegate_task(goal="...", context="...", toolsets=[...], role="leaf")
```

如果 `delegate_task` 不可用，inline 完成工作，不要编造 tool 调用。

## Task tracking

在 session 内使用 `todo` tool 进行任务跟踪。对于 multi-agent task boards，若可用则使用 `hermes kanban` CLI。将较旧的 `TodoWrite` 引用视为 task-tracking 动作。
