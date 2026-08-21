# Root Cause Tracing

## Overview

Bug 常常深在 call stack 中显现（git init 在 wrong directory、file 创建在 wrong location、database 用 wrong path 打开）。本能是在 error 出现处 fix，那是在 treat symptom。

**Core principle:** 沿 call chain backward trace 直到找到 original trigger，然后在 source 处 fix。

## When to Use

```dot
digraph when_to_use {
    "Bug appears deep in stack?" [shape=diamond];
    "Can trace backwards?" [shape=diamond];
    "Fix at symptom point" [shape=box];
    "Trace to original trigger" [shape=box];
    "BETTER: Also add defense-in-depth" [shape=box];

    "Bug appears deep in stack?" -> "Can trace backwards?" [label="yes"];
    "Can trace backwards?" -> "Trace to original trigger" [label="yes"];
    "Can trace backwards?" -> "Fix at symptom point" [label="no - dead end"];
    "Trace to original trigger" -> "BETTER: Also add defense-in-depth";
}
```

**Use when:**
- Error 深在 execution 中发生（不在 entry point）
- Stack trace 显示 long call chain
- 不清楚 invalid data 从哪来
- 需要找到哪个 test/code 触发问题

## The Tracing Process

### 1. Observe the Symptom
```
Error: git init failed in ~/project/packages/core
```

### 2. Find Immediate Cause
**什么 code 直接造成这个？**
```typescript
await execFileAsync('git', ['init'], { cwd: projectDir });
```

### 3. Ask: What Called This?
```typescript
WorktreeManager.createSessionWorktree(projectDir, sessionId)
  → called by Session.initializeWorkspace()
  → called by Session.create()
  → called by test at Project.create()
```

### 4. Keep Tracing Up
**传入了什么 value？**
- `projectDir = ''` (empty string!)
- Empty string 作为 `cwd` 会 resolve 到 `process.cwd()`
- 那就是 source code directory！

### 5. Find Original Trigger
**empty string 从哪来？**
```typescript
const context = setupCoreTest(); // Returns { tempDir: '' }
Project.create('name', context.tempDir); // Accessed before beforeEach!
```

## Adding Stack Traces

无法手动 trace 时，添加 instrumentation：

```typescript
// Before the problematic operation
async function gitInit(directory: string) {
  const stack = new Error().stack;
  console.error('DEBUG git init:', {
    directory,
    cwd: process.cwd(),
    nodeEnv: process.env.NODE_ENV,
    stack,
  });

  await execFileAsync('git', ['init'], { cwd: directory });
}
```

**Critical:** 在 test 中用 `console.error()`（不是 logger——可能不显示）

**Run and capture:**
```bash
npm test 2>&1 | grep 'DEBUG git init'
```

**Analyze stack traces:**
- 找 test file name
- 找触发调用的 line number
- 识别 pattern（同一 test？同一 parameter？）

## Finding Which Test Causes Pollution

若 test 期间出现某物但不知道哪个 test：

使用本目录 bisection script `find-polluter.sh`：

```bash
./find-polluter.sh '.git' 'src/**/*.test.ts'
```

逐个运行 test，在第一个 polluter 处停止。用法见 script。

## Real Example: Empty projectDir

**Symptom:** `.git` 创建在 `packages/core/`（source code）

**Trace chain:**
1. `git init` 在 `process.cwd()` 运行 ← empty cwd parameter
2. WorktreeManager 以 empty projectDir 调用
3. Session.create() 传入 empty string
4. Test 在 beforeEach 之前访问 `context.tempDir`
5. setupCoreTest() 初始返回 `{ tempDir: '' }`

**Root cause:** Top-level variable initialization 访问 empty value

**Fix:** 将 tempDir 改为 getter，beforeEach 之前访问则 throw

**Also added defense-in-depth:**
- Layer 1: Project.create() validates directory
- Layer 2: WorkspaceManager validates not empty
- Layer 3: NODE_ENV guard refuses git init outside tmpdir
- Layer 4: Stack trace logging before git init

## Key Principle

```dot
digraph principle {
    "Found immediate cause" [shape=ellipse];
    "Can trace one level up?" [shape=diamond];
    "Trace backwards" [shape=box];
    "Is this the source?" [shape=diamond];
    "Fix at source" [shape=box];
    "Add validation at each layer" [shape=box];
    "Bug impossible" [shape=doublecircle];
    "NEVER fix just the symptom" [shape=octagon, style=filled, fillcolor=red, fontcolor=white];

    "Found immediate cause" -> "Can trace one level up?";
    "Can trace one level up?" -> "Trace backwards" [label="yes"];
    "Can trace one level up?" -> "NEVER fix just the symptom" [label="no"];
    "Trace backwards" -> "Is this the source?";
    "Is this the source?" -> "Trace backwards" [label="no - keeps going"];
    "Is this the source?" -> "Fix at source" [label="yes"];
    "Fix at source" -> "Add validation at each layer";
    "Add validation at each layer" -> "Bug impossible";
}
```

**NEVER 只在 error 出现处 fix。** Trace back 找到 original trigger。

## Stack Trace Tips

**In tests:** 用 `console.error()` 不用 logger——logger 可能被 suppress
**Before operation:** 在危险 operation 之前 log，不是 fail 之后
**Include context:** Directory、cwd、environment variables、timestamps
**Capture stack:** `new Error().stack` 显示 complete call chain

## Real-World Impact

来自 debugging session (2025-10-03)：
- 通过 5-level trace 找到 root cause
- 在 source 处 fix（getter validation）
- 添加 4 层 defense
- 1847 tests passed，zero pollution
