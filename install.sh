#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════
# Cárdenas Installer
# A personal activity tracker for conversational logging
# ═══════════════════════════════════════════════════════════════════════════
#
# WHAT THIS SCRIPT DOES:
# 1. Creates the cardenas directory with bash scripts (track, read-activity, etc.)
# 2. Creates Claude Code skills in ~/.claude/commands/ (so /track works)
# 3. Creates Claude Code agents in ~/.claude/agents/
# 4. Adds permissions to ~/.claude/settings.json (so no prompts for track)
#
# REVIEW THIS SCRIPT BEFORE RUNNING. It modifies:
# - ~/cmd/cardenas/ (new directory)
# - ~/.claude/commands/ (new skill files)
# - ~/.claude/agents/ (new agent files)
# - ~/.claude/settings.json (adds permissions)
#
# ═══════════════════════════════════════════════════════════════════════════

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "  Cárdenas Installer"
echo "  A personal activity tracker for conversational logging"
echo "═══════════════════════════════════════════════════════════════"
echo ""

# ─── CONFIGURATION ───────────────────────────────────────────────────────────

INSTALL_DIR="${CARDENAS_DIR:-$HOME/cmd/cardenas}"
CLAUDE_DIR="$HOME/.claude"

echo -e "${BLUE}Install directory:${NC} $INSTALL_DIR"
echo -e "${BLUE}Claude config:${NC} $CLAUDE_DIR"
echo ""

read -p "Proceed with installation? [Y/n] " CONFIRM
if [[ "$CONFIRM" == "n" || "$CONFIRM" == "N" ]]; then
    echo "Cancelled."
    exit 0
fi

echo ""

# ─── CREATE DIRECTORIES ──────────────────────────────────────────────────────

echo -e "${YELLOW}Creating directories...${NC}"

mkdir -p "$INSTALL_DIR"
mkdir -p "$INSTALL_DIR/activity/raw/daily"
mkdir -p "$INSTALL_DIR/activity/summaries/daily"
mkdir -p "$INSTALL_DIR/goals/reflections"
mkdir -p "$INSTALL_DIR/health/daily"
mkdir -p "$INSTALL_DIR/scripts"
mkdir -p "$CLAUDE_DIR/commands"
mkdir -p "$CLAUDE_DIR/agents"

echo -e "${GREEN}✓${NC} Directories created"

# ─── CREATE TRACK SCRIPT ─────────────────────────────────────────────────────

echo -e "${YELLOW}Creating track script...${NC}"

cat > "$INSTALL_DIR/track" << 'TRACKSCRIPT'
#!/bin/bash
# Cárdenas - Activity Tracker
# Usage: track "Your message here"

CARDENAS_DIR="${CARDENAS_DIR:-$HOME/cmd/cardenas}"
TODAY=$(date +%Y-%m-%d)
DAILY_FILE="$CARDENAS_DIR/activity/raw/daily/$TODAY.json"

# Create file with empty array if it doesn't exist
if [[ ! -f "$DAILY_FILE" ]]; then
    echo "[]" > "$DAILY_FILE"
fi

# Get current timestamp
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Get the message
MESSAGE="$*"

if [[ -z "$MESSAGE" ]]; then
    echo "Usage: track \"Your message here\""
    exit 1
fi

# Escape quotes in message for JSON
MESSAGE_ESCAPED=$(echo "$MESSAGE" | sed 's/"/\\"/g')

# Create the new entry
NEW_ENTRY="{\"time\": \"$TIMESTAMP\", \"activity\": \"$MESSAGE_ESCAPED\"}"

# Read existing content, add new entry
if command -v jq &> /dev/null; then
    # Use jq if available
    jq ". += [$NEW_ENTRY]" "$DAILY_FILE" > "$DAILY_FILE.tmp" && mv "$DAILY_FILE.tmp" "$DAILY_FILE"
else
    # Fallback: simple append
    CONTENT=$(cat "$DAILY_FILE")
    if [[ "$CONTENT" == "[]" ]]; then
        echo "[$NEW_ENTRY]" > "$DAILY_FILE"
    else
        # Remove trailing ] and add new entry
        sed -i.bak 's/]$//' "$DAILY_FILE"
        echo ", $NEW_ENTRY]" >> "$DAILY_FILE"
        rm -f "$DAILY_FILE.bak"
    fi
fi

echo -e "✓ tracked to $TODAY.json : $MESSAGE"
TRACKSCRIPT

chmod +x "$INSTALL_DIR/track"
echo -e "${GREEN}✓${NC} track script created"

# ─── CREATE READ-ACTIVITY SCRIPT ─────────────────────────────────────────────

echo -e "${YELLOW}Creating read-activity script...${NC}"

cat > "$INSTALL_DIR/scripts/read-activity" << 'READSCRIPT'
#!/bin/bash
# Cárdenas - Activity Reader
# Usage: read-activity --today | --week | --days N | --since YYYY-MM-DD | --range START END

CARDENAS_DIR="${CARDENAS_DIR:-$HOME/cmd/cardenas}"
DAILY_DIR="$CARDENAS_DIR/activity/raw/daily"

show_help() {
    echo "Usage: read-activity [option]"
    echo ""
    echo "Options:"
    echo "  --today           Show today's activities"
    echo "  --week            Show last 7 days"
    echo "  --days N          Show last N days"
    echo "  --since DATE      Show from DATE to today"
    echo "  --range START END Show activities between dates"
    echo ""
    echo "Date format: YYYY-MM-DD"
}

format_entry() {
    local time="$1"
    local activity="$2"
    # Extract just the time portion
    local time_only=$(echo "$time" | sed 's/T/ /' | cut -d' ' -f2 | cut -d':' -f1-2)
    echo "  $time_only  $activity"
}

show_day() {
    local date="$1"
    local file="$DAILY_DIR/$date.json"

    if [[ -f "$file" ]]; then
        echo ""
        echo "─── $date ───"
        if command -v jq &> /dev/null; then
            jq -r '.[] | "\(.time)|\(.activity)"' "$file" 2>/dev/null | while IFS='|' read -r time activity; do
                format_entry "$time" "$activity"
            done
        else
            cat "$file"
        fi
    fi
}

get_date_n_days_ago() {
    local n="$1"
    if [[ "$(uname)" == "Darwin" ]]; then
        date -v-${n}d +%Y-%m-%d
    else
        date -d "$n days ago" +%Y-%m-%d
    fi
}

case "$1" in
    --today)
        show_day "$(date +%Y-%m-%d)"
        ;;
    --week)
        for i in {6..0}; do
            show_day "$(get_date_n_days_ago $i)"
        done
        ;;
    --days)
        N="${2:-7}"
        for i in $(seq $((N-1)) -1 0); do
            show_day "$(get_date_n_days_ago $i)"
        done
        ;;
    --since)
        START="$2"
        TODAY=$(date +%Y-%m-%d)
        current="$START"
        while [[ "$current" < "$TODAY" || "$current" == "$TODAY" ]]; do
            show_day "$current"
            if [[ "$(uname)" == "Darwin" ]]; then
                current=$(date -j -v+1d -f "%Y-%m-%d" "$current" +%Y-%m-%d)
            else
                current=$(date -d "$current + 1 day" +%Y-%m-%d)
            fi
        done
        ;;
    --range)
        START="$2"
        END="$3"
        current="$START"
        while [[ "$current" < "$END" || "$current" == "$END" ]]; do
            show_day "$current"
            if [[ "$(uname)" == "Darwin" ]]; then
                current=$(date -j -v+1d -f "%Y-%m-%d" "$current" +%Y-%m-%d)
            else
                current=$(date -d "$current + 1 day" +%Y-%m-%d)
            fi
        done
        ;;
    -h|--help|"")
        show_help
        ;;
    *)
        echo "Unknown option: $1"
        show_help
        exit 1
        ;;
esac

echo ""
READSCRIPT

chmod +x "$INSTALL_DIR/scripts/read-activity"
echo -e "${GREEN}✓${NC} read-activity script created"

# ─── CREATE GOALS SCRIPT ─────────────────────────────────────────────────────

echo -e "${YELLOW}Creating goals script...${NC}"

cat > "$INSTALL_DIR/scripts/goals" << 'GOALSSCRIPT'
#!/bin/bash
# Cárdenas - Goals Manager
# Usage: goals list | add "goal" --horizon monthly --category personal

CARDENAS_DIR="${CARDENAS_DIR:-$HOME/cmd/cardenas}"
GOALS_FILE="$CARDENAS_DIR/goals/active.json"

# Initialize if doesn't exist
if [[ ! -f "$GOALS_FILE" ]]; then
    echo "[]" > "$GOALS_FILE"
fi

show_help() {
    echo "Usage: goals [command]"
    echo ""
    echo "Commands:"
    echo "  list                      List all active goals"
    echo "  list --category work      List work goals only"
    echo "  add \"goal\" [options]      Add a new goal"
    echo ""
    echo "Options for add:"
    echo "  --horizon HORIZON         life, yearly, quarterly, monthly, weekly"
    echo "  --category CATEGORY       work, personal"
}

list_goals() {
    local filter_cat="$1"

    if ! command -v jq &> /dev/null; then
        cat "$GOALS_FILE"
        return
    fi

    echo ""
    echo "Active Goals"
    echo "════════════"

    if [[ -n "$filter_cat" ]]; then
        jq -r ".[] | select(.category == \"$filter_cat\") | \"[\(.horizon)] \(.title)\"" "$GOALS_FILE"
    else
        jq -r '.[] | "[\(.horizon)] \(.title)"' "$GOALS_FILE"
    fi
    echo ""
}

add_goal() {
    local title="$1"
    shift

    local horizon="monthly"
    local category="personal"

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --horizon) horizon="$2"; shift 2 ;;
            --category) category="$2"; shift 2 ;;
            *) shift ;;
        esac
    done

    local id=$(date +%s)
    local created=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    if command -v jq &> /dev/null; then
        jq ". += [{\"id\": \"$id\", \"title\": \"$title\", \"horizon\": \"$horizon\", \"category\": \"$category\", \"created\": \"$created\", \"status\": \"active\"}]" "$GOALS_FILE" > "$GOALS_FILE.tmp" && mv "$GOALS_FILE.tmp" "$GOALS_FILE"
    else
        echo "jq required for adding goals"
        exit 1
    fi

    echo -e "✓ Added goal: $title [$horizon, $category]"
}

case "$1" in
    list)
        if [[ "$2" == "--category" ]]; then
            list_goals "$3"
        else
            list_goals
        fi
        ;;
    add)
        shift
        add_goal "$@"
        ;;
    -h|--help|"")
        show_help
        ;;
    *)
        echo "Unknown command: $1"
        show_help
        exit 1
        ;;
esac
GOALSSCRIPT

chmod +x "$INSTALL_DIR/scripts/goals"
echo -e "${GREEN}✓${NC} goals script created"

# ─── CREATE HEALTH-LOG SCRIPT ────────────────────────────────────────────────

echo -e "${YELLOW}Creating health-log script...${NC}"

cat > "$INSTALL_DIR/scripts/health-log" << 'HEALTHSCRIPT'
#!/bin/bash
# Cárdenas - Health/Mood Logger
# Usage: health-log mood stress=high energy=low
#        health-log symptom headache=moderate

CARDENAS_DIR="${CARDENAS_DIR:-$HOME/cmd/cardenas}"
TODAY=$(date +%Y-%m-%d)
HEALTH_FILE="$CARDENAS_DIR/health/daily/$TODAY.json"

# Initialize if doesn't exist
if [[ ! -f "$HEALTH_FILE" ]]; then
    echo "{\"date\": \"$TODAY\", \"mood\": {}, \"symptoms\": {}, \"notes\": []}" > "$HEALTH_FILE"
fi

TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

case "$1" in
    mood)
        shift
        for item in "$@"; do
            key="${item%=*}"
            value="${item#*=}"
            if command -v jq &> /dev/null; then
                jq ".mood.$key = \"$value\"" "$HEALTH_FILE" > "$HEALTH_FILE.tmp" && mv "$HEALTH_FILE.tmp" "$HEALTH_FILE"
            fi
            echo -e "✓ Logged mood: $key = $value"
        done
        ;;
    symptom)
        shift
        for item in "$@"; do
            key="${item%=*}"
            value="${item#*=}"
            if command -v jq &> /dev/null; then
                jq ".symptoms.$key = \"$value\"" "$HEALTH_FILE" > "$HEALTH_FILE.tmp" && mv "$HEALTH_FILE.tmp" "$HEALTH_FILE"
            fi
            echo -e "✓ Logged symptom: $key = $value"
        done
        ;;
    note)
        shift
        NOTE="$*"
        if command -v jq &> /dev/null; then
            jq ".notes += [{\"time\": \"$TIMESTAMP\", \"note\": \"$NOTE\"}]" "$HEALTH_FILE" > "$HEALTH_FILE.tmp" && mv "$HEALTH_FILE.tmp" "$HEALTH_FILE"
        fi
        echo -e "✓ Logged note: $NOTE"
        ;;
    *)
        echo "Usage: health-log [mood|symptom|note] ..."
        echo ""
        echo "Examples:"
        echo "  health-log mood stress=high energy=low"
        echo "  health-log symptom headache=moderate"
        echo "  health-log note \"Slept poorly, woke up at 3am\""
        ;;
esac
HEALTHSCRIPT

chmod +x "$INSTALL_DIR/scripts/health-log"
echo -e "${GREEN}✓${NC} health-log script created"

# ─── CREATE CLAUDE SKILLS ────────────────────────────────────────────────────

echo -e "${YELLOW}Creating Claude Code skills...${NC}"

# /track skill
cat > "$CLAUDE_DIR/commands/track.md" << SKILL
---
description: Log activity to Cárdenas
---

Log an activity entry using the track command.

If the user provided arguments, run:
\`\`\`bash
$INSTALL_DIR/track "\$ARGUMENTS"
\`\`\`

If no arguments provided, ask the user what they want to track.
SKILL

# /today skill
cat > "$CLAUDE_DIR/commands/today.md" << SKILL
---
description: Show today's Cárdenas activities
---

Show today's activity log:

\`\`\`bash
$INSTALL_DIR/scripts/read-activity --today
\`\`\`
SKILL

# /week skill
cat > "$CLAUDE_DIR/commands/week.md" << SKILL
---
description: Show this week's Cárdenas activities
---

Show the last 7 days of activities:

\`\`\`bash
$INSTALL_DIR/scripts/read-activity --week
\`\`\`
SKILL

# /goals skill
cat > "$CLAUDE_DIR/commands/goals.md" << SKILL
---
description: Show or manage Cárdenas goals
---

If the user wants to see goals, run:
\`\`\`bash
$INSTALL_DIR/scripts/goals list
\`\`\`

If the user wants to add a goal, parse their request and run:
\`\`\`bash
$INSTALL_DIR/scripts/goals add "goal title" --horizon [life|yearly|quarterly|monthly|weekly] --category [work|personal]
\`\`\`
SKILL

echo -e "${GREEN}✓${NC} Claude skills created (/track, /today, /week, /goals)"

# ─── CREATE CLAUDE AGENT ─────────────────────────────────────────────────────

echo -e "${YELLOW}Creating Claude Code agent...${NC}"

cat > "$CLAUDE_DIR/agents/health-and-mood.md" << AGENT
---
description: Track health metrics, mood patterns, and personal well-being
tools:
  - Read
  - Bash
  - Edit
---

You are a health and mood tracking agent for Cárdenas.

Your job is to help the user:
1. Log mood states (stress, energy, focus)
2. Track symptoms
3. Add health notes
4. Review patterns over time

Use the health-log script:
\`\`\`bash
$INSTALL_DIR/scripts/health-log mood stress=low energy=high
$INSTALL_DIR/scripts/health-log symptom headache=none
$INSTALL_DIR/scripts/health-log note "Slept well, 8 hours"
\`\`\`

Health data is stored in: $INSTALL_DIR/health/daily/

Be supportive and non-judgmental. Help the user notice patterns without being preachy.
AGENT

echo -e "${GREEN}✓${NC} Claude agent created (health-and-mood)"

# ─── UPDATE CLAUDE PERMISSIONS ───────────────────────────────────────────────

echo -e "${YELLOW}Updating Claude Code permissions...${NC}"

SETTINGS_FILE="$CLAUDE_DIR/settings.json"

# Create settings file if it doesn't exist
if [[ ! -f "$SETTINGS_FILE" ]]; then
    echo '{"permissions": {"allow": [], "deny": []}}' > "$SETTINGS_FILE"
fi

if command -v jq &> /dev/null; then
    # Add permissions for Cardenas scripts
    PERMISSIONS=(
        "Bash($INSTALL_DIR/track:*)"
        "Bash($INSTALL_DIR/scripts/*:*)"
        "Read($INSTALL_DIR/**)"
        "Edit($INSTALL_DIR/**)"
    )

    for perm in "${PERMISSIONS[@]}"; do
        # Check if permission already exists
        EXISTS=$(jq -r ".permissions.allow | index(\"$perm\")" "$SETTINGS_FILE")
        if [[ "$EXISTS" == "null" ]]; then
            jq ".permissions.allow += [\"$perm\"]" "$SETTINGS_FILE" > "$SETTINGS_FILE.tmp" && mv "$SETTINGS_FILE.tmp" "$SETTINGS_FILE"
        fi
    done

    echo -e "${GREEN}✓${NC} Permissions added to settings.json"
else
    echo -e "${YELLOW}!${NC} jq not found - please manually add permissions to $SETTINGS_FILE"
fi

# ─── CREATE README ───────────────────────────────────────────────────────────

echo -e "${YELLOW}Creating README...${NC}"

cat > "$INSTALL_DIR/README.md" << 'README'
# Cárdenas

A personal activity tracker for conversational logging.

## Quick Start

```bash
# Log an activity
~/cmd/cardenas/track "Starting work on the new feature"

# See today's activities
~/cmd/cardenas/scripts/read-activity --today

# See the week
~/cmd/cardenas/scripts/read-activity --week
```

## Claude Code Skills

After installation, restart Claude Code. You'll have:

- `/track` - Log an activity
- `/today` - See today's entries
- `/week` - See the last 7 days
- `/goals` - Manage goals

## Philosophy

Capture **depth**, not just summaries:
- Mental state and emotional context
- Strategic insights and breakthroughs
- Why certain approaches are being chosen

**BAD:** "Wrote document"
**GOOD:** "Mental state: Using work momentum as self-soothing—creating control when system feels chaotic"

## Files

- `activity/raw/daily/` - Daily JSON logs
- `goals/active.json` - Your goals
- `health/daily/` - Mood and health data

## The Name

Named after García López de Cárdenas, the first European to see the Grand Canyon in 1540.
He saw the scale but couldn't comprehend it fully—which perfectly captures the feeling
of looking at your own activity data.
README

echo -e "${GREEN}✓${NC} README created"

# ─── DONE ────────────────────────────────────────────────────────────────────

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo -e "${GREEN}  Installation complete!${NC}"
echo "═══════════════════════════════════════════════════════════════"
echo ""
echo "Next steps:"
echo "  1. Restart Claude Code (quit and reopen)"
echo "  2. Try: /track \"Just installed Cárdenas\""
echo "  3. Try: /today"
echo ""
echo "Location: $INSTALL_DIR"
echo ""
