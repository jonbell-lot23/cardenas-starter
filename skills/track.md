---
name: track
description: Use when completing meaningful work, when user shares emotional state or mood, when making decisions (even in "routine" tasks), or when insights emerge
---

# Track Activity to Cárdenas

Log activities, decisions, and context to build a rich record of work and life.

## When to Track

**Always track:**
- Emotional state when shared ("feeling scattered", "energized", "frustrated")
- The *reason* behind a task, not just the task itself
- Decisions made (even in "routine" work like refactoring)
- Breakthroughs, insights, realizations
- Completed meaningful work

**The "why" matters more than the "what":**
- BAD: "Refactored function"
- GOOD: "Refactored filterByType - chose functional approach over imperative for clarity"
- BAD: "Built TODO component"
- GOOD: "Built TODO component - user feeling scattered, wanted something concrete to feel grounded"

## When NOT to Track

- Trivial file reads/writes
- Commands run during debugging
- Information already in git history

## Red Flags - You're Rationalizing

| Thought | Reality |
|---------|---------|
| "This is routine work" | Routine work contains decisions worth noting |
| "They didn't ask me to log it" | Emotional context is always worth capturing |
| "It's just a simple task" | The *why* behind simple tasks matters |
| "I'll track when something big happens" | The texture of the day IS the record |

## Command

```bash
CARDENAS_PATH/track "message"
```

One activity per line. Include context, not just outcomes.
