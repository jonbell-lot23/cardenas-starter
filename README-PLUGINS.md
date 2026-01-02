# Cárdenas Extras

The base install gives you `/track` - that's it. Claude Code handles the rest.

**Want more?** Run the extras installer:

```bash
curl -sL https://raw.githubusercontent.com/jonbell-lot23/cardenas-starter/main/install-extras.sh | bash
```

Or if you cloned the repo:
```bash
./install-extras.sh
```

## What You Get

### Query Scripts
| Script | Description | Slash Command |
|--------|-------------|---------------|
| `read-activity` | Query activity history | `/today`, `/week` |

### Goals System
| Script | Description | Slash Command |
|--------|-------------|---------------|
| `goals` | Add, list, complete goals | `/goals` |
| `goal-reflect` | Log progress on a goal | - |
| `goal-review` | Morning/evening summaries | - |

### Health Tracking
| Script | Description |
|--------|-------------|
| `health-log` | Track mood, energy, symptoms |
| `health-analyze` | Find patterns in health data |

### Daily Rituals
| Script | Description |
|--------|-------------|
| `start-of-day.sh` | Morning briefing |
| `end-of-day.sh` | Evening wrap-up |

## Directory Structure After Extras

```
~/cardenas/
├── track                    # Base install
├── activity/raw/daily/      # Base install
├── scripts/                 # ← Extras go here
│   ├── read-activity
│   ├── goals
│   ├── goal-reflect
│   ├── goal-review
│   ├── health-log
│   ├── health-analyze
│   ├── start-of-day.sh
│   └── end-of-day.sh
├── goals/                   # ← Created by extras
│   ├── active.json
│   └── reflections/
└── health/                  # ← Created by extras
    └── daily/
```

## Usage Examples

```bash
# Goals
~/cardenas/scripts/goals add "Ship the feature" --horizon weekly
~/cardenas/scripts/goals list
~/cardenas/scripts/goal-reflect 1234567890 "Made good progress today"
~/cardenas/scripts/goal-review morning

# Health
~/cardenas/scripts/health-log mood energy=high stress=low focus=medium
~/cardenas/scripts/health-analyze --last 7d

# Query
~/cardenas/scripts/read-activity --today
~/cardenas/scripts/read-activity --week
~/cardenas/scripts/read-activity --days 30
```

## Philosophy

The base install is intentionally minimal. Claude Code can:
- Query your JSON files directly
- Generate summaries on demand
- Create custom scripts when you need them

The extras are for people who want standalone tools that work without Claude Code, or who prefer dedicated scripts over conversational queries.
