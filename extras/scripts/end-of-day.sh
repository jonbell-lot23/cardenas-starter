#!/bin/bash
set -euo pipefail

# End of Day - Full System Sync
# Syncs Dayflow + OmniFocus + Rainbow Bridge + Generates Summary

echo "🌙 Running end-of-day sync..."
echo ""

# 1. Sync Dayflow
echo "📊 Syncing Dayflow..."
~/agents/dayflow today
echo ""

# 2. Sync OmniFocus
echo "✅ Syncing OmniFocus..."
~/cmd/cardenas/scripts/omnifocus-quick-sync.js
echo ""

# 3. Generate Summary
echo "📝 Generating daily summary..."
~/cmd/cardenas/scripts/generate-summaries.js
echo ""

# 4. Track completion
echo "🔄 Tracking sync completion..."
~/cmd/cardenas/track "END OF DAY SYNC: Dayflow, OmniFocus, and Rainbow Bridge synced. Summary generated."
echo ""

echo "✨ End-of-day sync complete! Good night! 🌙"
