#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════
# Cárdenas Installer v0.4.0
# A personal activity tracker for Claude Code
# Cross-platform: macOS, Linux, Windows (WSL/Git Bash)
# ═══════════════════════════════════════════════════════════════════════════

set -euo pipefail

VERSION="0.4.0"

# Cleanup on failure
INSTALL_STARTED=false
cleanup() {
  if [[ "$INSTALL_STARTED" == true && $? -ne 0 ]]; then
    echo ""
    echo "Installation failed. Partial files may remain in $DIR"
    echo "You can safely re-run this installer."
  fi
}
trap cleanup EXIT

echo ""
echo "Cárdenas - activity tracker for Claude Code"
echo ""

# -------------------------------------------------------------------
# 1. Choose agent name
# -------------------------------------------------------------------
read -p "Agent name [Cardenas]: " AGENT_NAME || AGENT_NAME=""
AGENT_NAME="${AGENT_NAME:-Cardenas}"
AGENT_NAME_LOWER=$(echo "$AGENT_NAME" | tr '[:upper:]' '[:lower:]')

# -------------------------------------------------------------------
# 2. Determine install directory
# -------------------------------------------------------------------
DIR="$HOME/.${AGENT_NAME_LOWER}"

# Validate directory path (no control characters or dangerous patterns)
if [[ "$DIR" =~ [[:cntrl:]] ]] || [[ "$DIR" == *".."* ]]; then
  echo "Error: Invalid directory path"
  exit 1
fi

# -------------------------------------------------------------------
# 3. Check for existing install (e.g. from Cursor installer)
# -------------------------------------------------------------------
if [[ -f "$DIR/bin/track" ]]; then
  echo ""
  echo "  ${AGENT_NAME} is already installed at $DIR"
  echo "  (bin/track and data directory exist)"
  echo ""
  echo "  Adding Claude Code integration..."
  echo ""

  # Just add the Claude Code skill and permissions
  mkdir -p "$HOME/.claude/commands"

  cat > "$HOME/.claude/commands/track.md" << SKILL
---
name: track
description: Use when completing meaningful work, when user shares emotional state or mood, when making decisions (even in "routine" tasks), or when insights emerge
---

# Track Activity to ${AGENT_NAME}

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

\`\`\`bash
$DIR/bin/track "\$ARGUMENTS"
\`\`\`

One activity per line. Include context, not just outcomes.
SKILL

  # Add permissions
  SETTINGS="$HOME/.claude/settings.json"
  PERM1="Bash($DIR/bin/track:*)"
  PERM2="Read($DIR/**)"

  add_permission() {
    local perm="$1"
    local file="$2"
    if grep -q "$perm" "$file" 2>/dev/null; then
      return 0
    fi
    if command -v jq &>/dev/null; then
      jq ".permissions.allow += [\"$perm\"]" "$file" > "$file.tmp" && mv "$file.tmp" "$file"
    else
      if grep -q '"allow":\[\]' "$file"; then
        sed "s|\"allow\":\[\]|\"allow\":[\"$perm\"]|" "$file" > "$file.tmp" && mv "$file.tmp" "$file"
      elif grep -q '"allow":\[' "$file"; then
        sed "s|\"allow\":\[|\"allow\":[\"$perm\",|" "$file" > "$file.tmp" && mv "$file.tmp" "$file"
      fi
    fi
  }

  if [[ ! -f "$SETTINGS" ]]; then
    echo '{"permissions":{"allow":[],"deny":[]}}' > "$SETTINGS"
  fi

  add_permission "$PERM1" "$SETTINGS"
  add_permission "$PERM2" "$SETTINGS"

  echo "  Claude Code integration added."
  echo "  Restart Claude Code, then try: /track \"Just connected Claude Code to ${AGENT_NAME}\""
  echo ""
  exit 0
fi

# -------------------------------------------------------------------
# 4. Fresh install
# -------------------------------------------------------------------
echo ""
echo "Creating: $DIR"
INSTALL_STARTED=true

# Create directory structure
mkdir -p "$DIR/bin"
mkdir -p "$DIR/data/activity/raw/daily"
mkdir -p "$DIR/config"
mkdir -p "$HOME/.claude/commands"

# Save agent config
python3 -c "
import json
config = {'name': '$AGENT_NAME', 'greeting': '$AGENT_NAME is ready.'}
with open('$DIR/config/agent.json', 'w') as f:
    json.dump(config, f, indent=2)
    f.write('\n')
"

# Create the track script
cat > "$DIR/bin/track" << 'TRACKSCRIPT'
#!/bin/bash
set -euo pipefail

BIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="$(dirname "$BIN_DIR")"
FILE="$INSTALL_DIR/data/activity/raw/daily/$(date +%Y-%m-%d).json"
MSG="$*"
[[ -z "$MSG" ]] && { echo "Usage: track \"message\""; exit 1; }

mkdir -p "$(dirname "$FILE")"
TIMESTAMP=$(date -Iseconds 2>/dev/null || date +%Y-%m-%dT%H:%M:%S%z)
LOCK_FILE="/tmp/cardenas-track.lock"

# Use Python for safe JSON handling — message passed via stdin to avoid quote issues
(
    flock -w 5 200 2>/dev/null || true  # flock may not exist on all systems

    echo "$MSG" | python3 -c "
import json, os, sys, shutil

file_path = '$FILE'
timestamp = '$TIMESTAMP'
activity = sys.stdin.read().strip()

if os.path.exists(file_path) and os.path.getsize(file_path) > 0:
    shutil.copy2(file_path, file_path + '.backup')
    try:
        with open(file_path, 'r') as f:
            data = json.load(f)
        if not isinstance(data, list):
            data = []
    except (json.JSONDecodeError, IOError, ValueError):
        data = []
else:
    data = []

data.append({'time': timestamp, 'activity': activity})

with open(file_path, 'w') as f:
    json.dump(data, f, separators=(',', ':'))
"
) 200>"$LOCK_FILE" 2>/dev/null

echo "tracked to $(basename "$FILE") : $MSG"
TRACKSCRIPT
chmod +x "$DIR/bin/track"

# Create /track skill for Claude Code
cat > "$HOME/.claude/commands/track.md" << SKILL
---
name: track
description: Use when completing meaningful work, when user shares emotional state or mood, when making decisions (even in "routine" tasks), or when insights emerge
---

# Track Activity to ${AGENT_NAME}

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

\`\`\`bash
$DIR/bin/track "\$ARGUMENTS"
\`\`\`

One activity per line. Include context, not just outcomes.
SKILL

# Add permissions to Claude settings (with jq-free fallback)
SETTINGS="$HOME/.claude/settings.json"
PERM1="Bash($DIR/bin/track:*)"
PERM2="Read($DIR/**)"

add_permission() {
  local perm="$1"
  local file="$2"

  # Check if permission already exists
  if grep -q "$perm" "$file" 2>/dev/null; then
    return 0
  fi

  if command -v jq &>/dev/null; then
    jq ".permissions.allow += [\"$perm\"]" "$file" > "$file.tmp" && mv "$file.tmp" "$file"
  else
    # Fallback: simple string replacement
    # Find "allow":[ and insert after it
    if grep -q '"allow":\[\]' "$file"; then
      # Empty array - replace with our permission
      sed "s|\"allow\":\[\]|\"allow\":[\"$perm\"]|" "$file" > "$file.tmp" && mv "$file.tmp" "$file"
    elif grep -q '"allow":\[' "$file"; then
      # Non-empty array - add to beginning
      sed "s|\"allow\":\[|\"allow\":[\"$perm\",|" "$file" > "$file.tmp" && mv "$file.tmp" "$file"
    fi
  fi
}

# Create settings file if it doesn't exist
if [[ ! -f "$SETTINGS" ]]; then
  echo '{"permissions":{"allow":[],"deny":[]}}' > "$SETTINGS"
fi

add_permission "$PERM1" "$SETTINGS"
add_permission "$PERM2" "$SETTINGS"

# Save version
echo "$VERSION" > "$DIR/config/version"

echo ""
echo "Done! Structure created:"
echo ""
echo "  $DIR/"
echo "  ├── bin/track"
echo "  ├── data/activity/raw/daily/"
echo "  └── config/agent.json"
echo ""
echo "Permissions added to ~/.claude/settings.json"
echo ""
echo "Next steps:"
echo "  1. Restart Claude Code"
echo "  2. Try: /track \"Just installed ${AGENT_NAME}\""
echo ""
echo "Claude Code can query your activity files directly."
echo "Ask things like \"what did I do today?\" or \"show me last week\""
echo ""
echo "Want more? See the plugins directory for patterns:"
echo "  Goals, health tracking, query scripts, MCP server, and more."
echo "  https://github.com/jonbell-lot23/cardenas-starter/tree/main/plugins"
echo ""
