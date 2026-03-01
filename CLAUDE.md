# CLAUDE.md

This file provides guidance to Claude Code when working with a Cárdenas installation.

## What Is This?

Cárdenas is a personal activity tracker. It logs what you do as JSON entries, one file per day. Named after the first European to witness the Grand Canyon — it helps you witness the vastness of your accomplishments.

## Core Command

```bash
~/cardenas/track "Your message here"
# Appends to: activity/raw/daily/YYYY-MM-DD.json
```

## Data Format

```json
[
  {"time": "2025-01-05T08:30:00+13:00", "activity": "Started morning planning"},
  {"time": "2025-01-05T09:15:00+13:00", "activity": "Completed code review"}
]
```

## Tracking Philosophy

**Capture depth, not just summaries.** Good entries include:
- Mental state and emotional context
- Why certain approaches are being chosen
- Strategic insights and breakthroughs
- Specific frustrations with attribution

Examples:
- BAD: "Wrote comprehensive document"
- GOOD: "Refactored auth module — chose JWT over sessions for stateless scaling. Feeling focused after morning coffee."

## When to Track

- Completed meaningful work
- Decisions made (even in routine tasks)
- Emotional state when shared
- Breakthroughs, insights, realizations
- Don't track trivial file reads or git operations

## Extending

See `plugins/README.md` for optional extensions:
- Query scripts, goals, health tracking, AI summaries, MCP server, and more.

## Directory Structure

```
cardenas/
├── track                    # Logging command
├── activity/raw/daily/      # Daily JSON logs (YYYY-MM-DD.json)
├── plugins/                 # Extension patterns and docs
└── skills/                  # Claude Code skills
```
