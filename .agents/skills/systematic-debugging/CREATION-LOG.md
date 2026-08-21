# Creation Log: Systematic Debugging Skill

提取、结构化并加固 critical skill 的 reference example。

## Source Material

从 `~/.claude/CLAUDE.md` 提取 debugging framework：
- 4-phase systematic process（Investigation → Pattern Analysis → Hypothesis → Implementation）
- Core mandate: ALWAYS find root cause, NEVER fix symptoms
- 为抵抗 time pressure 和 rationalization 而设计的 rules

## Extraction Decisions

**What to include:**
- Complete 4-phase framework 及全部 rules
- Anti-shortcuts（「NEVER fix symptom」、「STOP and re-analyze」）
- Pressure-resistant language（「even if faster」、「even if I seem in a hurry」）
- 每个 phase 的具体步骤

**What to leave out:**
- Project-specific context
- 同一 rule 的重复变体
- Narrative explanations（ condensed 为 principles）

## Structure Following skill-creation/SKILL.md

1. **Rich when_to_use** - 包含 symptom 与 anti-pattern
2. **Type: technique** - 带步骤的具体 process
3. **Keywords** - 「root cause」、「symptom」、「workaround」、「debugging」、「investigation」
4. **Flowchart** - 「fix failed」决策点 → re-analyze vs add more fixes
5. **Phase-by-phase breakdown** - 可扫读的 checklist 格式
6. **Anti-patterns section** - 不要做什么（对本 skill 至关重要）

## Bulletproofing Elements

Framework 设计为在压力下抵抗 rationalization：

### Language Choices
- 「ALWAYS」/「NEVER」（不是 「should」/「try to」）
- 「even if faster」/「even if I seem in a hurry」
- 「STOP and re-analyze」（explicit pause）
- 「Don't skip past」（捕获实际行为）

### Structural Defenses
- **Phase 1 required** - 不能 skip 到 implementation
- **Single hypothesis rule** - 强制思考，防止 shotgun fixes
- **Explicit failure mode** - 「IF your first fix doesn't work」及 mandatory action
- **Anti-patterns section** - 精确展示 shortcut 长什么样

### Redundancy
- Root cause mandate 出现在 overview + when_to_use + Phase 1 + implementation rules
- 「NEVER fix symptom」在不同 context 出现 4 次
- 每个 phase 有 explicit 「don't skip」guidance

## Testing Approach

按 skills/meta/testing-skills-with-subagents 创建 4 个 validation test：

### Test 1: Academic Context (No Pressure)
- 简单 bug，无 time pressure
- **Result:** Perfect compliance，complete investigation

### Test 2: Time Pressure + Obvious Quick Fix
- User 「in a hurry」，symptom fix 看起来 easy
- **Result:** 抵抗 shortcut，follow full process，找到 real root cause

### Test 3: Complex System + Uncertainty
- Multi-layer failure， unclear 能否找到 root cause
- **Result:** Systematic investigation，trace 所有 layer，找到 source

### Test 4: Failed First Fix
- Hypothesis 不 work， temptation 加更多 fix
- **Result:** Stopped，re-analyzed，formed new hypothesis（no shotgun）

**All tests passed.** No rationalizations found.

## Iterations

### Initial Version
- Complete 4-phase framework
- Anti-patterns section
- Flowchart for 「fix failed」decision

### Enhancement 1: TDD Reference
- Added link to skills/testing/test-driven-development
- Note explaining TDD's 「simplest code」≠ debugging's 「root cause」
- Prevents confusion between methodologies

## Final Outcome

Bulletproof skill that:
- ✅ Clearly mandates root cause investigation
- ✅ Resists time pressure rationalization
- ✅ Provides concrete steps for each phase
- ✅ Shows anti-patterns explicitly
- ✅ Tested under multiple pressure scenarios
- ✅ Clarifies relationship to TDD
- ✅ Ready for use

## Key Insight

**Most important bulletproofing:** Anti-patterns section 展示 moment 里 feel justified 的 exact shortcut。当 Claude 想「I'll just add this one quick fix」，看到 listed as wrong 的 exact pattern 会产生 cognitive friction。

## Usage Example

When encountering a bug:
1. Load skill: skills/debugging/systematic-debugging
2. Read overview (10 sec) - reminded of mandate
3. Follow Phase 1 checklist - forced investigation
4. If tempted to skip - see anti-pattern, stop
5. Complete all phases - root cause found

**Time investment:** 5-10 minutes
**Time saved:** Hours of symptom-whack-a-mole

---

*Created: 2025-10-03*
*Purpose: Reference example for skill extraction and bulletproofing*
