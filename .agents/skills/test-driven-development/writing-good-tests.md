# Writing Good Tests

**Load this reference when:** 编写或修改 tests、添加 mocks，或为 tests 添加 cleanup/helper methods。

## Overview

Test 的存在是为了 catch 特定 break。两条 principle  govern everything
here:

```
1. Every test names the break it catches
2. Every test exercises the real thing
```

Strict TDD 自然产生两者：先写并 watch failing against real code 的 test 已证明它能 fail，只有 real dependency 证明 slow 或 external 时才 earns mock。

## Principle 1: Name the Break

写 test body 之前，回答：**what production change should
make this test fail — and is that change a bug or a decision?** Test
通过 catch wrong branch、missing side effect、wrong
argument、boundary case 或 broken contract 而 earns 其位置。

**Derive expectations independently.** 使用 literals 和 hand-checked
fixtures；table-driven tests 与 literal `want` values 是 preferred
shape。由 code under test — 或其 helpers —
计算的 expectation 无论 code 做什么都会 pass：

```typescript
// ❌ Mirror assertion: the same builder computes both sides — always true
const expected = buildSearchQuery({ tag: 'urgent' });
expect(buildSearchQuery({ tag: 'urgent' })).toBe(expected);

// ✅ Hand-derived literal
expect(buildSearchQuery({ tag: 'urgent' })).toBe('tag:"urgent"');
```

**No change detectors.** 若只有 intentional decisions 能让 test fail —
constant 的值、exact message wording、private structure — 它在 redesign 时 fire 却对 bugs sleep。Test 依赖该 decision 的 behavior：不是 `expect(MAX_RETRIES).toBe(5)` 而是 "a failing call is
retried 5 times and the 6th attempt never happens."

**Behavior, not text.** Assert script、skill 或 config
包含 exact line 只证明 source 是 source。对 controlled inputs 运行
scripts 并 assert outputs、side effects 或
exit codes。指导 agents 的 documents 通过 consuming
agent 的 behavior 测试（superpowers:writing-skills）；给 human 的 prose 根本不
earn test。

**Your code, not the framework.** Test 你的 code 在
boundaries 上做出的 contract — 你注册的 route、你 emit 的 query、你 produce 的 payload。
Upstream mechanics 是 their maintainers 写的 tests。When upstream behavior genuinely
surprised you，写 one narrow characterization test naming the
assumption。Code 内部同样：constructors、
getters、constants、trivial forwarding 仅在 validate、normalize、default、derive、enforce 或 cause side effects 时 earn tests —
否则 assert 依赖它们的 first consumer-visible result。

### Gate Function

```
BEFORE writing the test body:
  Name the production change that would make this test fail.

  Cannot name one            → redesign around an observable behavior
  "The source text changed"  → run the artifact and assert its effects
  Only intentional decisions → change detector; test the behavior
                               that depends on the decision

  Confirm the expected value is derived without the code under test.
  IF it reuses the code's logic or helpers:
    Replace it with a literal or hand-checked fixture
```

## Principle 2: Exercise the Real Thing

**The mock earns no assertions.** Mock assertion 在 mock
present 时 pass、absent 时 fail — 对 component 无话可说。Assert real component 的 behavior；若 mock 才是你在 check 的，unmock 或 delete assertion。

```typescript
// ✅ Real behavior
expect(screen.getByRole('navigation')).toBeInTheDocument();

// ❌ Mock existence
expect(screen.getByTestId('sidebar-mock')).toBeInTheDocument();
```

**your human partner's correction:** "Are we testing the behavior of a
mock?"

**Mock at the right level.** Replace 之前 learn real method 的 every side effect；mock slow 或 external operation，keep test 依赖的 real。Unsure 时先 against real
implementation 运行 test 并 observe 实际需要什么。

```typescript
// ❌ The mock swallows the config write that duplicate detection reads
vi.mock('ToolCatalog', () => ({
  discoverAndCacheTools: vi.fn().mockResolvedValue(undefined)
}));

// ✅ Mock only the slow server startup; the config write stays real
vi.mock('MCPServerManager');
```

**Make doubles specific.** 当 arguments、call counts 或 ordering 是
contract 的一部分，assert them — 接受 anything 的 fake verifies
nothing。给每个 branch（success、error、malformed）自己的 fixture 或
spy，使 wrong branch 无法满足 expectation。

**Mirror real data completely.** Mock complete structure 如 reality 中存在 —
所有 documented fields — 不只是 test 读的 fields。
Partial mocks 在 downstream 读 omitted field 时 silent fail：
test pass 而 integration break。

**Production classes carry production methods only.** 只有 tests 需要的 cleanup 在 test utilities，never 作为 production class 上的 `destroy()`。Ask：此方法是否 only from tests 调用？此类是否 own 此 resource 的 lifecycle？Wrong answers → test utility。

**Prefer real components over complex mocks.** 当 mock setup 超过
test logic、mocks 缺 real components 有的 methods，或 tests
随 mock 变化而 break，switch 到 real components 的 integration test。**your human partner's question:** "Do we need to be using a
mock here?"

### Gate Function

```
BEFORE adding a mock or test helper:
  List the real method's side effects; keep the ones the test
  depends on real — mock the slow/external level below them.

  Mock responses mirror the complete real structure.

  A method only tests call lives in test utilities, not production.

  About to assert on the mock itself?
    Unmock it or delete the assertion.
```

## Tests Ship With the Implementation

TDD cycle — failing test、minimal implementation、refactor — 是
"complete" 的含义。Ship behavior 需要的 tests 且 only those：
trivial code 和 human prose earn none，为 satisfy
process 写的 test 永远 maintenance cost。

## The Mutation Check

Finish 之前，mentally mutate production code；每个 realistic mutation 至少一个 test 应 fail：

- Wrong constant or argument
- Wrong branch handler
- Missing state change or side effect
- Empty or default return
- Missing validation for zero, empty, nil, unauthorized, or malformed input

Nothing catches 的 mutation 标记 behavior 为 unprotected — 或 test 为 tautological。

## Quick Reference

| When you... | Do |
|-------------|-----|
| Write any test | Name the break it catches — a bug, not a decision |
| Build an expected value | Derive it by hand; never with the code under test |
| Test a script or document | Run it / pressure-test its consumer; never grep its text |
| Reach for a dependency test | Test your boundary contract, not their documented mechanics |
| Want to assert on a mocked element | Test the real component, or unmock it |
| Are about to mock a method | Learn its side effects; mock the slow/external level |
| Build a mock response | Mirror the real structure completely |
| Need cleanup only tests use | Put it in test utilities |
| Watch mock setup balloon | Switch to an integration test with real components |
| Finish a test file | Run the mutation check |

## Warning Signs

- Setup and assertion share the same object, guaranteeing equality
- The test can fail only through a panic, crash, or missing selector
- The test fails on every intentional change, never on accidental breakage
- Expected values are hidden behind loops, builders, or helpers
- The test greps source text, or asserts a removed symbol stays removed
- The test would still matter if only the framework remained
- The test exists for coverage, checking no side effect or outcome
- An assertion checks a `*-mock` test ID, or fails if you remove the mock
- A method is called only from test files
- Mock setup is more than half the test, or you can't explain why the mock is needed
- Mocking "just to be safe"
