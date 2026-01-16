#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════
# Cárdenas Installer v0.2.0
# A personal activity tracker for Claude Code
# Cross-platform: macOS, Linux, Windows (WSL/Git Bash)
# ═══════════════════════════════════════════════════════════════════════════

VERSION="0.2.0"

echo ""
echo "Cárdenas - activity tracker for Claude Code"
echo ""
read -p "Install directory [~/cardenas]: " DIR
DIR="${DIR:-$HOME/cardenas}"
DIR="${DIR/#\~/$HOME}"

echo ""
echo "Creating: $DIR"

# Create directory structure
mkdir -p "$DIR/activity/raw/daily"
mkdir -p "$HOME/.claude/commands"

# Create the track script
cat > "$DIR/track" << 'TRACKSCRIPT'
#!/bin/bash
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FILE="$DIR/activity/raw/daily/$(date +%Y-%m-%d).json"
[[ ! -f "$FILE" ]] && echo "[]" > "$FILE"
MSG="$*"
[[ -z "$MSG" ]] && { echo "Usage: track \"message\""; exit 1; }

# Escape quotes and backslashes for JSON
MSG_ESCAPED=$(printf '%s' "$MSG" | sed 's/\\/\\\\/g; s/"/\\"/g')
TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)
ENTRY="{\"time\":\"$TIMESTAMP\",\"activity\":\"$MSG_ESCAPED\"}"

if command -v jq &>/dev/null; then
  jq ". += [$ENTRY]" "$FILE" > "$FILE.tmp" && mv "$FILE.tmp" "$FILE"
else
  # Fallback without jq
  CONTENT=$(cat "$FILE")
  if [[ "$CONTENT" == "[]" ]]; then
    echo "[$ENTRY]" > "$FILE"
  else
    printf '%s' "${CONTENT%]}" > "$FILE"
    printf ',%s]' "$ENTRY" >> "$FILE"
  fi
fi
echo "✓ $MSG"
TRACKSCRIPT
chmod +x "$DIR/track"

# Create /track skill for Claude Code
cat > "$HOME/.claude/commands/track.md" << SKILL
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

\`\`\`bash
$DIR/track "\$ARGUMENTS"
\`\`\`

One activity per line. Include context, not just outcomes.
SKILL

# Add permissions to Claude settings (with jq-free fallback)
SETTINGS="$HOME/.claude/settings.json"
PERM1="Bash($DIR/track:*)"
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
echo "$VERSION" > "$HOME/.cardenas-version"

echo ""
echo "Done! Structure created:"
echo ""
echo "  $DIR/"
echo "  ├── track"
echo "  └── activity/raw/daily/"
echo ""
echo "Permissions added to ~/.claude/settings.json"
echo ""
echo "Next steps:"
echo "  1. Restart Claude Code"
echo "  2. Try: /track \"Just installed Cárdenas\""
echo ""
echo "Claude Code can query your activity files directly."
echo "Ask things like \"what did I do today?\" or \"show me last week\""
echo ""
echo "Want more? Install extras (goals, health tracking, query scripts):"
echo "  curl -sL https://raw.githubusercontent.com/jonbell-lot23/cardenas-starter/main/install-extras.sh | bash"
echo ""
