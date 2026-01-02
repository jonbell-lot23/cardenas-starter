#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════
# Cárdenas Installer v0.1.4
# A personal activity tracker for Claude Code
# Cross-platform: macOS, Linux, Windows (WSL/Git Bash)
# ═══════════════════════════════════════════════════════════════════════════

VERSION="0.1.4"

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
description: Log activity to Cárdenas
---
Log an activity entry. Run:
\`\`\`bash
$DIR/track "\$ARGUMENTS"
\`\`\`
If no arguments provided, ask what to track.
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
