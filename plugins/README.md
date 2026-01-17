# Extending Cárdenas

The starter installation gives you activity tracking. This document shows what's possible when you extend it. Think of these as building blocks you can add when you need them.

---

## Extension Points

### 1. Query Scripts
**What:** Tools to search and analyze your activity history
**Why:** "What did I work on last week?" or "Show me everything about project X"

**Pattern:**
```
scripts/
├── read-activity    # Query by date range (--today, --week, --since)
├── search          # Keyword search across all activities
└── stats           # Patterns and trends
```

**Example query:**
```bash
./scripts/read-activity --week
./scripts/search "bug fix"
```

---

### 2. Goals System
**What:** Track goals across time horizons (life → yearly → quarterly → monthly → weekly)
**Why:** Connect daily work to bigger picture. See momentum over time.

**Pattern:**
```
goals/
├── active.json       # Current goals with metadata
├── archive.json      # Completed/paused goals
└── reflections/      # Daily progress entries
    └── YYYY-MM-DD.json
```

**Example goal structure:**
```json
{
  "id": "g-2025-q1-launch-product",
  "title": "Launch v1.0",
  "horizon": "quarterly",
  "category": "work",
  "created": "2025-01-01",
  "status": "active"
}
```

**Horizons:** `life` → `yearly` → `quarterly` → `monthly` → `weekly`
**Categories:** `work`, `personal`, or whatever you need

**Scripts you might add:**
- `scripts/goals` - Manage goals (add/list/complete/pause)
- `scripts/goal-reflect` - Log progress: "Shipped auth today"
- `scripts/goal-review` - Morning/evening summaries

---

### 3. Health & Mood Tracking
**What:** Integrate health data (sleep, heart rate, exercise) with mood check-ins
**Why:** Spot patterns between how you feel and what you do

**Pattern:**
```
health/
├── daily/           # Unified daily records
├── imports/         # Raw data from Apple Health, etc.
└── parsed/          # Processed metrics
```

**Example daily record:**
```json
{
  "date": "2025-01-02",
  "vitals": {"resting_hr": 58, "steps": 8234},
  "sleep": {"hours": 7.2},
  "mood": {"energy": "medium", "stress": "low"}
}
```

**Scripts you might add:**
- `scripts/health-import` - Parse Apple Health exports
- `scripts/health-log` - Manual entry: "mood energy=low stress=high"
- `scripts/health-query` - Trends: "show me sleep patterns"

---

### 4. AI Summaries
**What:** Auto-generate narrative summaries of your days
**Why:** Turn raw activity logs into readable stories

**Pattern:**
```
activity/
├── raw/daily/         # Your JSON logs
└── summaries/daily/   # AI-generated markdown
    └── 2025-01-02.md
```

**Example summary output:**
```markdown
## 2025-01-02

**Themes:** Testing new systems, documentation

**Completed:**
- Installed activity tracker
- Tested UTF-8 encoding
- Documented extension patterns

**On Mind:** How to make this easy for others to extend
```

**Implementation:** Script that reads daily JSON, calls Claude API, writes markdown

---

### 5. MCP Server (Claude Desktop Integration)
**What:** Make your Cárdenas data accessible to Claude Desktop via Model Context Protocol
**Why:** Ask Claude "what did I work on yesterday?" and it reads your actual data

**Pattern:**
```
mcp-server/
├── package.json
└── src/
    ├── index.ts      # MCP server implementation
    └── data.ts       # Read your Cárdenas files
```

**Tools you might expose:**
- `get_activities` - Fetch entries by date/range
- `get_goals` - List active goals
- `track_activity` - Log new entry from Claude
- `get_summary` - Read AI-generated summary
- `search_activities` - Keyword search

**Configure in Claude Desktop:**
```json
{
  "mcpServers": {
    "cardenas": {
      "command": "node",
      "args": ["/path/to/mcp-server/dist/index.js"]
    }
  }
}
```

---

### 6. Automated Sync
**What:** Auto-commit and push to GitHub on a schedule
**Why:** Automatic backup, access from anywhere

**Pattern:**
- Shell script that git commits + pushes
- LaunchAgent (macOS) or cron job runs it hourly
- File locking prevents overlapping syncs

**Example script:**
```bash
#!/bin/bash
cd "$CARDENAS_ROOT"
git add -A
git commit -m "Auto-sync $(date +%Y-%m-%d\ %H:%M)"
git push
```

---

### 7. Configuration System
**What:** Central config file for paths and integrations
**Why:** Make scripts portable and customizable

**Pattern:**
```
scripts/lib/config.sh    # Export environment variables
config/cardenas.env      # User settings
```

**Example config:**
```bash
export CARDENAS_ROOT="/Users/you/cardenas"
export CARDENAS_ACTIVITY_DIR="$CARDENAS_ROOT/activity/raw/daily"
export ENABLE_SUMMARIES=true
export ENABLE_GITHUB_SYNC=true
```

**Usage in scripts:**
```bash
#!/bin/bash
source "$(dirname $0)/lib/config.sh"
# Now use $CARDENAS_ACTIVITY_DIR
```

---

## Design Principles

### Start Small
Don't build everything at once. Add one extension when you need it:
1. Use basic tracking for a week
2. Add query scripts when you want to look back
3. Add goals when you want to track progress
4. Add health when you want to see patterns

### Keep It Simple
- One JSON file per day (easy to debug)
- Shell scripts + Python (no fancy frameworks)
- Git for backup (simple, reliable)
- Flat file structure (easy to understand)

### Make It Yours
These are patterns, not prescriptions:
- Different goal horizons? Change them
- Track mood differently? Adjust the schema
- Want weekly summaries instead of daily? Do it
- Use SQLite instead of JSON? Go ahead

---

## Example: Adding a Simple Query Script

Here's how you might add your first extension:

**Create `scripts/read-activity`:**
```bash
#!/bin/bash
DIR="$HOME/cardenas"

case "$1" in
  --today)
    FILE="$DIR/activity/raw/daily/$(date +%Y-%m-%d).json"
    cat "$FILE" | jq -r '.[] | "[\(.time)] \(.activity)"'
    ;;
  --week)
    # Loop through last 7 days and cat their files
    ;;
esac
```

**Make it executable:**
```bash
chmod +x scripts/read-activity
```

**Use it:**
```bash
./scripts/read-activity --today
```

Start there. When you need more, build more.

---

## Full Extension Map

When fully extended, a Cárdenas installation might look like:

```
cardenas/
├── track                    # Core tracker (you have this)
├── activity/
│   ├── raw/daily/          # Daily logs (you have this)
│   └── summaries/daily/    # AI summaries (add if you want)
├── goals/                  # Goal tracking (add if you want)
├── health/                 # Health data (add if you want)
├── scripts/                # Query tools (add as needed)
├── mcp-server/            # Claude integration (add if you want)
├── config/                # Settings (add when scripts get complex)
└── plugins/               # This directory
```

Each piece is optional. Build what serves you.

---

## Getting Help

When adding extensions:

1. **Tell Claude what you want:** "I want to track goals with quarterly and monthly horizons"
2. **Claude can read this file** to understand the patterns
3. **Start with the simplest version** that works
4. **Iterate** - make it better over time

The patterns here are tested in production but **not prescriptive**. Your needs might be different. That's fine.
