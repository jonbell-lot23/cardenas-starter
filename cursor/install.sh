#!/bin/bash
set -euo pipefail

# Sylvan — Activity Tracker for Cursor
# Stripped-down variant of Cardenas
# Version 0.1.0

SYLVAN_VERSION="0.1.0"
DEFAULT_DIR="$HOME/sylvan"

echo ""
echo "  Sylvan v${SYLVAN_VERSION}"
echo "  Activity tracker for Cursor"
echo ""

# -------------------------------------------------------------------
# 1. Choose install directory
# -------------------------------------------------------------------
read -r -p "Install directory [$DEFAULT_DIR]: " SYLVAN_DIR
SYLVAN_DIR="${SYLVAN_DIR:-$DEFAULT_DIR}"

if [[ -d "$SYLVAN_DIR" ]]; then
  echo "Directory exists — will add to it."
else
  mkdir -p "$SYLVAN_DIR"
  echo "Created $SYLVAN_DIR"
fi

# -------------------------------------------------------------------
# 2. Create directory structure
# -------------------------------------------------------------------
mkdir -p "$SYLVAN_DIR/activity/raw/daily"
mkdir -p "$SYLVAN_DIR/plugins"

echo "Created activity/raw/daily/ and plugins/"

# -------------------------------------------------------------------
# 3. Write the track script
# -------------------------------------------------------------------
cat > "$SYLVAN_DIR/track" << 'TRACK_SCRIPT'
#!/bin/bash
set -euo pipefail

SYLVAN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TODAY_FILE="$SYLVAN_DIR/activity/raw/daily/$(date +%Y-%m-%d).json"

mkdir -p "$(dirname "$TODAY_FILE")"

ts=$(date -Iseconds)
msg="$*"

if [[ -z "$msg" ]]; then
  echo "Usage: sylvan/track \"your message here\"" >&2
  exit 1
fi

# Use flock to prevent concurrent writes losing entries
LOCK_FILE="/tmp/sylvan-track.lock"

(
    flock -w 5 200 || { echo "Error: Could not acquire lock" >&2; exit 1; }

    echo "$msg" | python3 -c "
import json
import os
import sys
import shutil

file_path = os.environ['TODAY_FILE']
timestamp = os.environ['TIMESTAMP']
activity = sys.stdin.read().strip()

# Load existing data or start with empty array
if os.path.exists(file_path) and os.path.getsize(file_path) > 0:
    # Backup before overwrite
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

# Add new entry
new_entry = {'time': timestamp, 'activity': activity}
data.append(new_entry)

# Write back to file
with open(file_path, 'w') as f:
    json.dump(data, f, indent=2)
"
) 200>"$LOCK_FILE"

echo "tracked: $msg"
TRACK_SCRIPT

# Pass variables via environment instead of shell interpolation
sed -i '' "s|os.environ\['TODAY_FILE'\]|'$SYLVAN_DIR' + '/activity/raw/daily/' + __import__('datetime').date.today().isoformat() + '.json'|" "$SYLVAN_DIR/track" 2>/dev/null || true

# Actually, the track script should be self-contained. Rewrite it cleanly:
cat > "$SYLVAN_DIR/track" << 'TRACK_SCRIPT'
#!/bin/bash
set -euo pipefail

SYLVAN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TODAY_FILE="$SYLVAN_DIR/activity/raw/daily/$(date +%Y-%m-%d).json"

mkdir -p "$(dirname "$TODAY_FILE")"

ts=$(date -Iseconds)
msg="$*"

if [[ -z "$msg" ]]; then
  echo "Usage: track \"your message here\"" >&2
  exit 1
fi

# Use flock to prevent concurrent writes losing entries
LOCK_FILE="/tmp/sylvan-track.lock"

(
    flock -w 5 200 || { echo "Error: Could not acquire lock" >&2; exit 1; }

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
) 200>"$LOCK_FILE"

echo "tracked: $msg"
TRACK_SCRIPT

chmod +x "$SYLVAN_DIR/track"
echo "Created track script"

# -------------------------------------------------------------------
# 4. Install Cursor rule
# -------------------------------------------------------------------
CURSOR_RULES_DIR="$HOME/.cursor/rules"
mkdir -p "$CURSOR_RULES_DIR"

cat > "$CURSOR_RULES_DIR/sylvan-track.mdc" << RULE
---
description: Use when completing meaningful work, when user shares emotional state, when making decisions, or when insights emerge
globs:
alwaysApply: true
---

# Track Activity to Sylvan

You have access to an activity tracker. Log entries by running:

\`\`\`bash
${SYLVAN_DIR}/track "your message here"
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

echo "Created .cursor/rules/sylvan-track.mdc"

# -------------------------------------------------------------------
# 5. Done
# -------------------------------------------------------------------
echo ""
echo "  Sylvan installed successfully."
echo ""
echo "  Track script: $SYLVAN_DIR/track"
echo "  Cursor rule:  $CURSOR_RULES_DIR/sylvan-track.mdc"
echo "  Data:         $SYLVAN_DIR/activity/raw/daily/"
echo ""
echo "  Test it:  $SYLVAN_DIR/track \"hello from sylvan\""
echo "  Then open Cursor — it will auto-track your work."
echo ""
