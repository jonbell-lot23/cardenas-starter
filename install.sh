#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════
# Cárdenas Installer v0.1.2
# A personal activity tracker for Claude Code
# ═══════════════════════════════════════════════════════════════════════════

VERSION="0.1.2"

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
ENTRY="{\"time\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",\"activity\":\"$(echo "$MSG" | sed 's/"/\\"/g')\"}"
if command -v jq &>/dev/null; then
  jq ". += [$ENTRY]" "$FILE" > "$FILE.tmp" && mv "$FILE.tmp" "$FILE"
else
  [[ "$(cat "$FILE")" == "[]" ]] && echo "[$ENTRY]" > "$FILE" || { sed -i '' 's/]$//' "$FILE"; echo ",$ENTRY]" >> "$FILE"; }
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

# Add permissions to Claude settings
SETTINGS="$HOME/.claude/settings.json"
if [[ ! -f "$SETTINGS" ]]; then
  echo '{"permissions":{"allow":[],"deny":[]}}' > "$SETTINGS"
fi
if command -v jq &>/dev/null; then
  PERM="Bash($DIR/track:*)"
  if ! jq -e ".permissions.allow | index(\"$PERM\")" "$SETTINGS" >/dev/null 2>&1; then
    jq ".permissions.allow += [\"$PERM\"]" "$SETTINGS" > "$SETTINGS.tmp" && mv "$SETTINGS.tmp" "$SETTINGS"
  fi
  PERM="Read($DIR/**)"
  if ! jq -e ".permissions.allow | index(\"$PERM\")" "$SETTINGS" >/dev/null 2>&1; then
    jq ".permissions.allow += [\"$PERM\"]" "$SETTINGS" > "$SETTINGS.tmp" && mv "$SETTINGS.tmp" "$SETTINGS"
  fi
fi

# Save version
echo "$VERSION" > "$HOME/.cardenas-version"

echo ""
echo "Done! Structure created:"
echo ""
echo "  $DIR/"
echo "  ├── track"
echo "  └── activity/raw/daily/"
echo ""
echo "Next steps:"
echo "  1. Restart Claude Code"
echo "  2. Try: /track \"Just installed Cárdenas\""
echo ""
echo "Claude Code can query your activity files directly."
echo "Ask things like \"what did I do today?\" or \"show me last week\""
echo ""
