#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════
# Cárdenas Installer v0.1.0
# A personal activity tracker for conversational logging
# ═══════════════════════════════════════════════════════════════════════════

CARDENAS_VERSION="0.1.0"
VERSION_FILE="$HOME/.cardenas-version"

# Colors
BLUE='\033[0;34m'
CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo ""
echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}  Hi! I'm Cárdenas.${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
echo ""
echo "Before I go wild on your computer, let's be careful."
echo ""
echo -e "${YELLOW}It's dangerous to install stuff off the internet directly!${NC}"
echo ""
echo "I'm going to show you exactly what this script will do."
echo "Then you can decide if you trust it."
echo ""
read -p "Press Enter to see what I'm about to do... "

# ─── SELF-AUDIT ──────────────────────────────────────────────────────────────

echo ""
echo -e "${BLUE}═══ SCRIPT AUDIT ═══${NC}"
echo ""
echo "This script will:"
echo ""
echo "  1. CREATE directories:"
echo "     - ./cardenas/ (or your chosen location)"
echo "     - ~/.claude/commands/ (for slash commands)"
echo "     - ~/.claude/agents/ (for agents)"
echo ""
echo "  2. CREATE files:"
echo "     - track (bash script for logging)"
echo "     - scripts/read-activity (query your history)"
echo "     - scripts/goals (manage goals)"
echo "     - scripts/health-log (mood tracking)"
echo ""
echo "  3. MODIFY:"
echo "     - ~/.claude/settings.json (add permissions for the scripts)"
echo ""
echo "  4. NOT do:"
echo "     - Send any data anywhere"
echo "     - Install any dependencies"
echo "     - Touch anything outside the directories above"
echo ""
echo "Full source: https://github.com/jonbell-lot23/cardenas-starter/blob/main/install.sh"
echo ""

read -p "Does this sound okay? [Y/n] " AUDIT_OK
if [[ "$AUDIT_OK" == "n" || "$AUDIT_OK" == "N" ]]; then
    echo ""
    echo "No worries! Take your time to review the script."
    echo "You can read it at the URL above."
    exit 0
fi

# ─── VERSION CHECK ───────────────────────────────────────────────────────────

if [[ -f "$VERSION_FILE" ]]; then
    INSTALLED_VERSION=$(cat "$VERSION_FILE")
    echo ""
    echo -e "${BLUE}═══ EXISTING INSTALLATION DETECTED ═══${NC}"
    echo ""
    echo "You have Cárdenas v$INSTALLED_VERSION installed."
    echo "This installer is v$CARDENAS_VERSION."
    echo ""

    if [[ "$INSTALLED_VERSION" == "$CARDENAS_VERSION" ]]; then
        echo "You're already on the latest version!"
        read -p "Reinstall anyway? [y/N] " REINSTALL
        if [[ "$REINSTALL" != "y" && "$REINSTALL" != "Y" ]]; then
            echo "Okay, nothing changed."
            exit 0
        fi
    else
        echo "This will upgrade your installation."
        echo "(Your data in activity/, goals/, health/ will be preserved.)"
        read -p "Continue with upgrade? [Y/n] " UPGRADE
        if [[ "$UPGRADE" == "n" || "$UPGRADE" == "N" ]]; then
            exit 0
        fi
    fi
fi

# ─── QUESTIONS ───────────────────────────────────────────────────────────────

echo ""
echo -e "${BLUE}═══ SETUP QUESTIONS ═══${NC}"
echo ""

# Install directory
DEFAULT_DIR="$HOME/cardenas"
echo "Where should I install Cárdenas?"
echo "  Default: $DEFAULT_DIR"
echo "  (You can enter any path, e.g. ~/projects/cardenas)"
echo ""
read -p "Install directory [$DEFAULT_DIR]: " INSTALL_DIR
INSTALL_DIR="${INSTALL_DIR:-$DEFAULT_DIR}"
INSTALL_DIR="${INSTALL_DIR/#\~/$HOME}"

echo ""

# Check for existing agents
AGENTS_DIR="$HOME/.claude/agents"
OTHER_AGENTS=""
if [[ -d "$AGENTS_DIR" ]] && [[ -n "$(ls -A "$AGENTS_DIR" 2>/dev/null)" ]]; then
    AGENT_COUNT=$(ls -1 "$AGENTS_DIR"/*.md 2>/dev/null | wc -l | tr -d ' ')
    if [[ "$AGENT_COUNT" -gt 0 ]]; then
        echo "I notice you have $AGENT_COUNT other agent(s) in ~/.claude/agents/"
        echo "Mind if I take a look to see if there are any conflicts or"
        echo "opportunities to work better together?"
        echo ""
        read -p "Can I analyze your existing agents? [Y/n] " ANALYZE_AGENTS
        if [[ "$ANALYZE_AGENTS" != "n" && "$ANALYZE_AGENTS" != "N" ]]; then
            echo ""
            echo "Found agents:"
            for agent in "$AGENTS_DIR"/*.md; do
                [[ -f "$agent" ]] && echo "  - $(basename "$agent" .md)"
            done
            OTHER_AGENTS=$(ls -1 "$AGENTS_DIR"/*.md 2>/dev/null | xargs -I {} basename {} .md | tr '\n' ',' | sed 's/,$//')
            echo ""
        fi
    fi
fi

echo ""

# ─── CONFIRMATION ────────────────────────────────────────────────────────────

echo -e "${BLUE}═══ READY TO INSTALL ═══${NC}"
echo ""
echo "  Location: $INSTALL_DIR"
[[ -n "$OTHER_AGENTS" ]] && echo "  Other agents: $OTHER_AGENTS"
echo "  Version: $CARDENAS_VERSION"
echo ""
read -p "Install now? [Y/n] " CONFIRM
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
mkdir -p "$HOME/.claude/commands"
mkdir -p "$HOME/.claude/agents"

echo -e "${GREEN}✓${NC} Directories created"

# ─── CREATE TRACK SCRIPT ─────────────────────────────────────────────────────

echo -e "${YELLOW}Creating track script...${NC}"

cat > "$INSTALL_DIR/track" << 'TRACKSCRIPT'
#!/bin/bash
# Cárdenas - Activity Tracker
# Usage: track "Your message here"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CARDENAS_DIR="${CARDENAS_DIR:-$SCRIPT_DIR}"
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
    jq ". += [$NEW_ENTRY]" "$DAILY_FILE" > "$DAILY_FILE.tmp" && mv "$DAILY_FILE.tmp" "$DAILY_FILE"
else
    CONTENT=$(cat "$DAILY_FILE")
    if [[ "$CONTENT" == "[]" ]]; then
        echo "[$NEW_ENTRY]" > "$DAILY_FILE"
    else
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
# Usage: read-activity --today | --week | --days N

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CARDENAS_DIR="${CARDENAS_DIR:-$(dirname "$SCRIPT_DIR")}"
DAILY_DIR="$CARDENAS_DIR/activity/raw/daily"

get_date_n_days_ago() {
    local n="$1"
    if [[ "$(uname)" == "Darwin" ]]; then
        date -v-${n}d +%Y-%m-%d
    else
        date -d "$n days ago" +%Y-%m-%d
    fi
}

show_day() {
    local date="$1"
    local file="$DAILY_DIR/$date.json"
    if [[ -f "$file" ]]; then
        echo ""
        echo "─── $date ───"
        if command -v jq &> /dev/null; then
            jq -r '.[] | "  \(.time | split("T")[1] | split(":")[0:2] | join(":"))  \(.activity)"' "$file" 2>/dev/null
        else
            cat "$file"
        fi
    fi
}

case "$1" in
    --today) show_day "$(date +%Y-%m-%d)" ;;
    --week) for i in {6..0}; do show_day "$(get_date_n_days_ago $i)"; done ;;
    --days) for i in $(seq $((${2:-7}-1)) -1 0); do show_day "$(get_date_n_days_ago $i)"; done ;;
    *) echo "Usage: read-activity --today | --week | --days N" ;;
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

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CARDENAS_DIR="${CARDENAS_DIR:-$(dirname "$SCRIPT_DIR")}"
GOALS_FILE="$CARDENAS_DIR/goals/active.json"

[[ ! -f "$GOALS_FILE" ]] && echo "[]" > "$GOALS_FILE"

case "$1" in
    list)
        echo ""; echo "Active Goals"; echo "════════════"
        if command -v jq &> /dev/null; then
            jq -r '.[] | "[\(.horizon)] \(.title)"' "$GOALS_FILE"
        else
            cat "$GOALS_FILE"
        fi
        echo ""
        ;;
    add)
        shift; TITLE="$1"; HORIZON="${3:-monthly}"; CATEGORY="${5:-personal}"
        ID=$(date +%s); CREATED=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
        if command -v jq &> /dev/null; then
            jq ". += [{\"id\": \"$ID\", \"title\": \"$TITLE\", \"horizon\": \"$HORIZON\", \"category\": \"$CATEGORY\", \"created\": \"$CREATED\"}]" "$GOALS_FILE" > "$GOALS_FILE.tmp" && mv "$GOALS_FILE.tmp" "$GOALS_FILE"
            echo "✓ Added: $TITLE [$HORIZON]"
        fi
        ;;
    *) echo "Usage: goals list | goals add \"title\" --horizon monthly --category personal" ;;
esac
GOALSSCRIPT

chmod +x "$INSTALL_DIR/scripts/goals"
echo -e "${GREEN}✓${NC} goals script created"

# ─── CREATE HEALTH-LOG SCRIPT ────────────────────────────────────────────────

echo -e "${YELLOW}Creating health-log script...${NC}"

cat > "$INSTALL_DIR/scripts/health-log" << 'HEALTHSCRIPT'
#!/bin/bash
# Cárdenas - Health/Mood Logger

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CARDENAS_DIR="${CARDENAS_DIR:-$(dirname "$SCRIPT_DIR")}"
TODAY=$(date +%Y-%m-%d)
HEALTH_FILE="$CARDENAS_DIR/health/daily/$TODAY.json"

[[ ! -f "$HEALTH_FILE" ]] && echo "{\"date\": \"$TODAY\", \"mood\": {}, \"symptoms\": {}, \"notes\": []}" > "$HEALTH_FILE"

case "$1" in
    mood)
        shift
        for item in "$@"; do
            key="${item%=*}"; value="${item#*=}"
            if command -v jq &> /dev/null; then
                jq ".mood.$key = \"$value\"" "$HEALTH_FILE" > "$HEALTH_FILE.tmp" && mv "$HEALTH_FILE.tmp" "$HEALTH_FILE"
            fi
            echo "✓ Logged mood: $key = $value"
        done
        ;;
    *) echo "Usage: health-log mood stress=low energy=high" ;;
esac
HEALTHSCRIPT

chmod +x "$INSTALL_DIR/scripts/health-log"
echo -e "${GREEN}✓${NC} health-log script created"

# ─── CREATE CLAUDE SKILLS ────────────────────────────────────────────────────

echo -e "${YELLOW}Creating Claude Code skills...${NC}"

cat > "$HOME/.claude/commands/track.md" << SKILL
---
description: Log activity to Cárdenas
---

Log an activity entry. Run:

\`\`\`bash
$INSTALL_DIR/track "\$ARGUMENTS"
\`\`\`

If no arguments, ask what to track.
SKILL

cat > "$HOME/.claude/commands/today.md" << SKILL
---
description: Show today's activities
---

\`\`\`bash
$INSTALL_DIR/scripts/read-activity --today
\`\`\`
SKILL

cat > "$HOME/.claude/commands/week.md" << SKILL
---
description: Show this week's activities
---

\`\`\`bash
$INSTALL_DIR/scripts/read-activity --week
\`\`\`
SKILL

echo -e "${GREEN}✓${NC} Claude skills created (/track, /today, /week)"

# ─── UPDATE CLAUDE PERMISSIONS ───────────────────────────────────────────────

echo -e "${YELLOW}Updating Claude Code permissions...${NC}"

SETTINGS_FILE="$HOME/.claude/settings.json"

if [[ ! -f "$SETTINGS_FILE" ]]; then
    echo '{"permissions": {"allow": [], "deny": []}}' > "$SETTINGS_FILE"
fi

if command -v jq &> /dev/null; then
    PERMS=("Bash($INSTALL_DIR/track:*)" "Bash($INSTALL_DIR/scripts/*:*)" "Read($INSTALL_DIR/**)" "Edit($INSTALL_DIR/**)")
    for perm in "${PERMS[@]}"; do
        EXISTS=$(jq -r ".permissions.allow | index(\"$perm\")" "$SETTINGS_FILE")
        if [[ "$EXISTS" == "null" ]]; then
            jq ".permissions.allow += [\"$perm\"]" "$SETTINGS_FILE" > "$SETTINGS_FILE.tmp" && mv "$SETTINGS_FILE.tmp" "$SETTINGS_FILE"
        fi
    done
    echo -e "${GREEN}✓${NC} Permissions added"
else
    echo -e "${YELLOW}!${NC} jq not found - add permissions manually"
fi

# ─── SAVE VERSION ────────────────────────────────────────────────────────────

echo "$CARDENAS_VERSION" > "$VERSION_FILE"

# ─── SAVE CONFIG ─────────────────────────────────────────────────────────────

cat > "$INSTALL_DIR/.cardenas-config" << CONFIG
CARDENAS_VERSION=$CARDENAS_VERSION
INSTALL_DIR=$INSTALL_DIR
OTHER_AGENTS=$OTHER_AGENTS
INSTALLED_AT=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
CONFIG

# ─── DONE ────────────────────────────────────────────────────────────────────

echo ""
echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}  Installation complete! (v$CARDENAS_VERSION)${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
echo ""
echo "Next steps:"
echo "  1. Restart Claude Code"
echo "  2. Try: /track \"Just installed Cárdenas\""
echo "  3. Try: /today"
echo ""
echo "Location: $INSTALL_DIR"
echo ""
