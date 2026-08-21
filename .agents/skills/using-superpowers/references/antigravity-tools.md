# Antigravity CLI (`agy`) Tool Mapping

Skills 用动作描述（"dispatch a subagent"、"create a todo"、"read a file"）。在 Antigravity CLI (`agy`) 上，这些动作对应下方 tools。

| Action skills request | Antigravity CLI equivalent |
|----------------------|----------------------|
| Dispatch a subagent (`Subagent (general-purpose):` template) | `invoke_subagent`，使用内置 `TypeName` — `self` 用于 full-capability 工作，`research` 用于 read-only |
| Task tracking ("create a todo", "mark complete") | **task artifact** — `write_to_file`，`IsArtifact: true`，`ArtifactType: "task"`（见 [Task tracking](#task-tracking)）。**不是** `manage_task`，它管理 background processes。 |

## Task tracking

Antigravity **没有 todo tool**（`manage_task` 管理 background
processes — `list`/`kill`/`status`/`send_input` — 它*不是* checklist）。当 skill 要求创建 todo list 或跟踪任务时，维护 **task artifact**：用 `write_to_file`（`IsArtifact: true`、
`ArtifactMetadata.ArtifactType: "task"`）保存的 markdown checklist，进行中用 `replace_file_content` /
`multi_replace_file_content` 编辑。

在任何 multi-step task 开始时，创建 task artifact，列出计划的每一步。完成每步后，编辑 artifact 标记为 done（`- [x]`）。
如果计划变化，更新 checklist。保持最新 — 它是剩余工作的 source of
truth；对话变长后，每步开始前重新阅读它。
