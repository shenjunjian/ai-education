# 领域文档

Engineering skills 在探索代码库时应如何消费本仓库的领域文档。

## 探索之前，先读这些

- 仓库根目录的 **`CONTEXT.md`**，或
- 若存在，仓库根目录的 **`CONTEXT-MAP.md`** —— 它指向每个上下文各一份 `CONTEXT.md`。读与当前主题相关的每一份。
- **`docs/adr/`** —— 阅读触及你即将工作区域的 ADRs。在 multi-context 仓库中，也检查 `src/<context>/docs/adr/` 里按上下文范围的决策。

若这些文件有任何不存在，**静默继续**。不要标记它们缺失；不要建议事先创建。`/domain-modeling` skill（经 `/grill-with-docs` 和 `/improve-codebase-architecture` 到达）会在术语或决策真正落地时惰性创建它们。

## 文件结构

Single-context 仓库（大多数仓库）：

```
/
├── CONTEXT.md
├── docs/adr/
│   ├── 0001-event-sourced-orders.md
│   └── 0002-postgres-for-write-model.md
└── src/
```

Multi-context 仓库（根目录存在 `CONTEXT-MAP.md`）：

```
/
├── CONTEXT-MAP.md
├── docs/adr/                          ← system-wide decisions
└── src/
    ├── ordering/
    │   ├── CONTEXT.md
    │   └── docs/adr/                  ← context-specific decisions
    └── billing/
        ├── CONTEXT.md
        └── docs/adr/
```

## 使用词汇表里的用语

当你的输出命名一个领域概念时（issue 标题、重构提案、假设、测试名），使用 `CONTEXT.md` 中定义的术语。不要滑向词汇表明确避免的同义词。

若你需要的概念还不在词汇表里，这是一个信号——要么你在发明项目不用的语言（重新考虑），要么存在真正的缺口（记下来交给 `/domain-modeling`）。

## 标出 ADR 冲突

若你的输出与已有 ADR 矛盾，明确提出，而不是静默覆盖：

> _与 ADR-0007 (event-sourced orders) 矛盾——但值得重开，因为…_
