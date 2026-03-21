#!/bin/bash
set -euo pipefail

# Cárdenas — Activity Tracker for Cursor
# Version 0.2.0

INSTALL_VERSION="0.2.0"

echo ""
echo "  Cárdenas v${INSTALL_VERSION}"
echo "  Activity tracker for Cursor"
echo ""

# -------------------------------------------------------------------
# 1. Choose agent name
# -------------------------------------------------------------------
read -r -p "Agent name [Cardenas]: " AGENT_NAME
AGENT_NAME="${AGENT_NAME:-Cardenas}"
AGENT_NAME_LOWER=$(echo "$AGENT_NAME" | tr '[:upper:]' '[:lower:]')

# -------------------------------------------------------------------
# 2. Determine install directory
# -------------------------------------------------------------------
DIR="$HOME/.${AGENT_NAME_LOWER}"

# -------------------------------------------------------------------
# 3. Check for existing install (e.g. from Claude Code installer)
# -------------------------------------------------------------------
if [[ -f "$DIR/bin/track" ]]; then
  echo "  ${AGENT_NAME} is already installed at $DIR"
  echo "  (bin/track and data directory exist)"
  echo ""
  echo "  Adding Cursor integration..."
  echo ""

  # Just add the Cursor rule
  CURSOR_RULES_DIR="$HOME/.cursor/rules"
  mkdir -p "$CURSOR_RULES_DIR"
  RULE_FILE="$CURSOR_RULES_DIR/${AGENT_NAME_LOWER}-track.mdc"

  cat > "$RULE_FILE" << RULE
---
description: Use when completing meaningful work, when user shares emotional state, when making decisions, or when insights emerge
globs:
alwaysApply: true
---

# Track Activity to ${AGENT_NAME}

You have access to an activity tracker. Log entries by running:

\`\`\`bash
${DIR}/bin/track "your message here"
\`\`\`

## When to Track

- Completing a meaningful piece of work
- User shares how they're feeling
- Key decisions made
- Insights or breakthroughs
- Starting or finishing a session
- Context switches between projects

## How to Write Entries

Capture depth, not just summaries:
- Include mental state and emotional context when shared
- Note strategic insights and breakthroughs
- Record why certain approaches are being chosen
- Be specific about what happened, not vague

**Bad**: "Worked on project"
**Good**: "Refactored auth module to use JWT — chose this over session tokens for stateless API compatibility"

## Rules

- Track automatically without asking permission
- One activity per track call (no multi-line)
- Keep entries concise but meaningful
- Don't track trivial actions (opening files, running formatters)
- When in doubt, track it — better to have it than not
RULE

  echo "  Cursor rule created: $RULE_FILE"
  echo "  Open Cursor — it will auto-track your work."
  echo ""
  exit 0
fi

# -------------------------------------------------------------------
# 4. Fresh install
# -------------------------------------------------------------------
echo "Creating: $DIR"

# Create directory structure
mkdir -p "$DIR/bin"
mkdir -p "$DIR/data/activity/raw/daily"
mkdir -p "$DIR/config"

echo "Created directory structure"

# Save agent config
python3 -c "
import json
config = {'name': '$AGENT_NAME', 'greeting': '$AGENT_NAME is ready.'}
with open('$DIR/config/agent.json', 'w') as f:
    json.dump(config, f, indent=2)
    f.write('\n')
"

# -------------------------------------------------------------------
# 5. Write the track script
# -------------------------------------------------------------------
cat > "$DIR/bin/track" << 'TRACK_SCRIPT'
#!/bin/bash
set -euo pipefail

BIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="$(dirname "$BIN_DIR")"
TODAY_FILE="$INSTALL_DIR/data/activity/raw/daily/$(date +%Y-%m-%d).json"

mkdir -p "$(dirname "$TODAY_FILE")"

ts=$(date -Iseconds)
msg="$*"

if [[ -z "$msg" ]]; then
  echo "Usage: track \"your message here\"" >&2
  exit 1
fi

# Use flock to prevent concurrent writes losing entries
LOCK_FILE="/tmp/cardenas-track.lock"

(
    flock -w 5 200 2>/dev/null || true

    echo "$msg" | TODAY_FILE="$TODAY_FILE" TIMESTAMP="$ts" python3 -c "
import json, os, sys, shutil

file_path = os.environ['TODAY_FILE']
timestamp = os.environ['TIMESTAMP']
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
    json.dump(data, f, indent=2)
"
) 200>"$LOCK_FILE" 2>/dev/null

echo "tracked: $msg"
TRACK_SCRIPT

chmod +x "$DIR/bin/track"
echo "Created track script"

# -------------------------------------------------------------------
# 6. Install Cursor rule
# -------------------------------------------------------------------
CURSOR_RULES_DIR="$HOME/.cursor/rules"
mkdir -p "$CURSOR_RULES_DIR"

RULE_FILE="$CURSOR_RULES_DIR/${AGENT_NAME_LOWER}-track.mdc"

cat > "$RULE_FILE" << RULE
---
description: Use when completing meaningful work, when user shares emotional state, when making decisions, or when insights emerge
globs:
alwaysApply: true
---

# Track Activity to ${AGENT_NAME}

You have access to an activity tracker. Log entries by running:

\`\`\`bash
${DIR}/bin/track "your message here"
\`\`\`

## When to Track

- Completing a meaningful piece of work
- User shares how they're feeling
- Key decisions made
- Insights or breakthroughs
- Starting or finishing a session
- Context switches between projects

## How to Write Entries

Capture depth, not just summaries:
- Include mental state and emotional context when shared
- Note strategic insights and breakthroughs
- Record why certain approaches are being chosen
- Be specific about what happened, not vague

**Bad**: "Worked on project"
**Good**: "Refactored auth module to use JWT — chose this over session tokens for stateless API compatibility"

## Rules

- Track automatically without asking permission
- One activity per track call (no multi-line)
- Keep entries concise but meaningful
- Don't track trivial actions (opening files, running formatters)
- When in doubt, track it — better to have it than not
RULE

echo "Created $RULE_FILE"

# Save version
echo "$INSTALL_VERSION" > "$DIR/config/version"

# -------------------------------------------------------------------
# 7. Done
# -------------------------------------------------------------------
echo ""
echo "  ${AGENT_NAME} installed successfully."
echo ""
echo "  Track script: $DIR/bin/track"
echo "  Cursor rule:  $RULE_FILE"
echo "  Data:         $DIR/data/activity/raw/daily/"
echo "  Config:       $DIR/config/agent.json"
echo ""
echo "  Test it:  $DIR/bin/track \"hello from ${AGENT_NAME_LOWER}\""
echo "  Then open Cursor — it will auto-track your work."
echo ""
