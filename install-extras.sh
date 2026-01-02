#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════
# Cárdenas Extras Installer
# Additional scripts for goals, health tracking, and more
# ═══════════════════════════════════════════════════════════════════════════

echo ""
echo "Cárdenas Extras"
echo ""

# Find existing installation
if [[ -f "$HOME/.cardenas-version" ]]; then
  # Try to find install dir from the /track skill
  SKILL_FILE="$HOME/.claude/commands/track.md"
  if [[ -f "$SKILL_FILE" ]]; then
    DIR=$(grep -o '/[^"]*track' "$SKILL_FILE" | head -1 | sed 's|/track$||')
  fi
fi

if [[ -z "$DIR" ]] || [[ ! -d "$DIR" ]]; then
  echo "Couldn't find existing Cárdenas installation."
  echo "Please run install.sh first, or enter your install directory:"
  read -p "Directory: " DIR
  DIR="${DIR/#\~/$HOME}"
fi

if [[ ! -d "$DIR" ]]; then
  echo "Directory not found: $DIR"
  exit 1
fi

echo "Installing extras to: $DIR"
echo ""

# Determine where we're running from (for local installs) or fetch from GitHub
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EXTRAS_DIR="$SCRIPT_DIR/extras/scripts"

if [[ -d "$EXTRAS_DIR" ]]; then
  echo "Installing from local extras..."
  SOURCE="local"
else
  echo "Fetching extras from GitHub..."
  SOURCE="github"
  EXTRAS_DIR=$(mktemp -d)
  REPO_URL="https://raw.githubusercontent.com/jonbell-lot23/cardenas-starter/main/extras/scripts"
fi

# Create directories
mkdir -p "$DIR/scripts"
mkdir -p "$DIR/goals/reflections"
mkdir -p "$DIR/health/daily"

# List of extras to install
SCRIPTS=(
  "read-activity:Query your activity history"
  "goals:Manage goals (add, list, complete)"
  "goal-reflect:Log progress on goals"
  "goal-review:Morning/evening goal summaries"
  "health-log:Track mood and symptoms"
  "health-analyze:Analyze health patterns"
  "start-of-day.sh:Morning briefing"
  "end-of-day.sh:Evening wrap-up"
)

install_script() {
  local name="$1"
  local desc="$2"

  if [[ "$SOURCE" == "local" ]]; then
    cp "$EXTRAS_DIR/$name" "$DIR/scripts/$name"
  else
    curl -sL "$REPO_URL/$name" -o "$DIR/scripts/$name"
  fi

  chmod +x "$DIR/scripts/$name"
  echo "  ✓ $name - $desc"
}

echo ""
echo "Installing scripts:"
for item in "${SCRIPTS[@]}"; do
  name="${item%%:*}"
  desc="${item#*:}"
  install_script "$name" "$desc"
done

# Update scripts to use correct paths
for script in "$DIR/scripts"/*; do
  if [[ -f "$script" ]]; then
    # Replace placeholder paths with actual install dir
    sed -i.bak "s|\$CARDENAS_DIR|$DIR|g" "$script" 2>/dev/null || \
    sed "s|\$CARDENAS_DIR|$DIR|g" "$script" > "$script.tmp" && mv "$script.tmp" "$script"
    rm -f "$script.bak"
  fi
done

# Create Claude skills for the extras
echo ""
echo "Creating Claude Code skills:"

cat > "$HOME/.claude/commands/today.md" << SKILL
---
description: Show today's activities
---
Run: $DIR/scripts/read-activity --today
SKILL
echo "  ✓ /today"

cat > "$HOME/.claude/commands/week.md" << SKILL
---
description: Show this week's activities
---
Run: $DIR/scripts/read-activity --week
SKILL
echo "  ✓ /week"

cat > "$HOME/.claude/commands/goals.md" << SKILL
---
description: List active goals
---
Run: $DIR/scripts/goals list
SKILL
echo "  ✓ /goals"

# Cleanup temp dir if we used GitHub
[[ "$SOURCE" == "github" ]] && rm -rf "$EXTRAS_DIR"

echo ""
echo "Done! Extras installed to $DIR/scripts/"
echo ""
echo "New commands available:"
echo "  /today         - Today's activities"
echo "  /week          - This week's activities"
echo "  /goals         - List your goals"
echo ""
echo "Scripts you can run directly:"
echo "  $DIR/scripts/goals add \"My goal\" --horizon monthly"
echo "  $DIR/scripts/health-log mood energy=high stress=low"
echo "  $DIR/scripts/goal-review morning"
echo ""
