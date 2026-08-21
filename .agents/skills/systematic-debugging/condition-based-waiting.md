# Condition-Based Waiting

## Overview

Flaky test 常用 arbitrary delay 猜 timing。这造成 race condition：快机器上 pass，load 或 CI 下 fail。

**Core principle:** 等待你真正关心的 actual condition，而不是猜需要多久。

## When to Use

```dot
digraph when_to_use {
    "Test uses setTimeout/sleep?" [shape=diamond];
    "Testing timing behavior?" [shape=diamond];
    "Document WHY timeout needed" [shape=box];
    "Use condition-based waiting" [shape=box];

    "Test uses setTimeout/sleep?" -> "Testing timing behavior?" [label="yes"];
    "Testing timing behavior?" -> "Document WHY timeout needed" [label="yes"];
    "Testing timing behavior?" -> "Use condition-based waiting" [label="no"];
}
```

**Use when:**
- Test 有 arbitrary delay（`setTimeout`、`sleep`、`time.sleep()`）
- Test flaky（有时 pass，load 下 fail）
- Parallel 运行时 timeout
- 等待 async operation 完成

**Don't use when:**
- 测试 actual timing behavior（debounce、throttle interval）
- 若用 arbitrary timeout，ALWAYS document WHY

## Core Pattern

```typescript
// ❌ BEFORE: Guessing at timing
await new Promise(r => setTimeout(r, 50));
const result = getResult();
expect(result).toBeDefined();

// ✅ AFTER: Waiting for condition
await waitFor(() => getResult() !== undefined);
const result = getResult();
expect(result).toBeDefined();
```

## Quick Patterns

| Scenario | Pattern |
|----------|---------|
| Wait for event | `waitFor(() => events.find(e => e.type === 'DONE'))` |
| Wait for state | `waitFor(() => machine.state === 'ready')` |
| Wait for count | `waitFor(() => items.length >= 5)` |
| Wait for file | `waitFor(() => fs.existsSync(path))` |
| Complex condition | `waitFor(() => obj.ready && obj.value > 10)` |

## Implementation

Generic polling function:
```typescript
async function waitFor<T>(
  condition: () => T | undefined | null | false,
  description: string,
  timeoutMs = 5000
): Promise<T> {
  const startTime = Date.now();

  while (true) {
    const result = condition();
    if (result) return result;

    if (Date.now() - startTime > timeoutMs) {
      throw new Error(`Timeout waiting for ${description} after ${timeoutMs}ms`);
    }

    await new Promise(r => setTimeout(r, 10)); // Poll every 10ms
  }
}
```

完整 implementation 及 domain-specific helpers（`waitForEvent`、`waitForEventCount`、`waitForEventMatch`）见本目录 `condition-based-waiting-example.ts`，来自 actual debugging session。

## Common Mistakes

**❌ Polling too fast:** `setTimeout(check, 1)` - 浪费 CPU
**✅ Fix:** 每 10ms poll 一次

**❌ No timeout:** condition 永远不满足则 loop forever
**✅ Fix:** Always include timeout 与 clear error

**❌ Stale data:** loop 前 cache state
**✅ Fix:** loop 内 call getter 获取 fresh data

## When Arbitrary Timeout IS Correct

```typescript
// Tool ticks every 100ms - need 2 ticks to verify partial output
await waitForEvent(manager, 'TOOL_STARTED'); // First: wait for condition
await new Promise(r => setTimeout(r, 200));   // Then: wait for timed behavior
// 200ms = 2 ticks at 100ms intervals - documented and justified
```

**Requirements:**
1. 先 wait triggering condition
2. 基于 known timing（不是 guessing）
3. Comment 解释 WHY

## Real-World Impact

来自 debugging session (2025-10-03)：
- 修复 3 个 file 中 15 个 flaky test
- Pass rate: 60% → 100%
- Execution time: 快 40%
- 不再有 race condition
