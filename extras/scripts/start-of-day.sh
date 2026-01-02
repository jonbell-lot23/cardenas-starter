#!/bin/bash
set -euo pipefail

# Start of Day - Morning Health Check
# Runs path checks, cardenas health, and surfaces any issues before you start

ROOT="${HOME}/cmd/common/cardenas"
ISSUES=()

echo "=== Morning System Check ==="
echo ""

# 1. Run path health check (broken symlinks, config paths, launchd jobs)
echo "Checking paths and configs..."
if ! ~/cmd/common/scripts/nightly-health-check.sh > /tmp/morning-path-check.log 2>&1; then
    ISSUES+=("PATH: $(grep -c 'BROKEN' /tmp/morning-path-check.log 2>/dev/null || echo '?') broken paths detected")
    echo "  ⚠️  Path issues found - see /tmp/path-health-check.log"
else
    echo "  ✓ All paths OK"
fi

# 2. Run cardenas health check
echo "Checking cardenas tracker..."
if ! "$ROOT/scripts/health-check.sh" > /tmp/morning-cardenas-check.log 2>&1; then
    ISSUES+=("CARDENAS: Health check failed")
    echo "  ⚠️  Cardenas issues - see /tmp/morning-cardenas-check.log"
else
    echo "  ✓ Cardenas healthy"
fi

# 3. Check if any launchd jobs failed recently
echo "Checking launchd job status..."
failed_jobs=$(launchctl list 2>/dev/null | awk '$1 != "-" && $1 != "0" && $1 != "PID" {print $3}' | grep -E '^com\.(cardenas|lot23|kaching|grandgallery)' || true)
if [ -n "$failed_jobs" ]; then
    ISSUES+=("LAUNCHD: Jobs with non-zero exit: $failed_jobs")
    echo "  ⚠️  Some jobs have errors: $failed_jobs"
else
    echo "  ✓ All launchd jobs OK"
fi

# 4. Check disk space (APFS purgeable space means Finder shows more than df)
echo "Checking disk space..."
disk_pct=$(df -h ~ | awk 'NR==2 {gsub(/%/,"",$5); print $5}')
disk_avail=$(df -h ~ | awk 'NR==2 {print $4}')
if [ "$disk_pct" -gt 95 ]; then
    ISSUES+=("DISK: ${disk_pct}% full (${disk_avail} free) - critically low")
    echo "  ⚠️  Disk ${disk_pct}% full (${disk_avail} free)!"
elif [ "$disk_pct" -gt 90 ]; then
    echo "  ⚡ Disk ${disk_pct}% full (${disk_avail} free)"
else
    echo "  ✓ Disk ${disk_pct}% used (${disk_avail} free)"
fi

echo ""

# 5. Show morning goal briefing
echo "=== Active Goals ==="
"$ROOT/scripts/goal-review" morning 2>/dev/null || echo "  (No goals set yet)"
echo ""

# Summary
if [ ${#ISSUES[@]} -gt 0 ]; then
    echo "=== ISSUES TO ADDRESS ==="
    for issue in "${ISSUES[@]}"; do
        echo "  - $issue"
    done
    echo ""

    # Log to cardenas for visibility
    ~/cmd/common/cardenas/track "MORNING CHECK: ${#ISSUES[@]} issues found - ${ISSUES[*]}"

    exit 1
else
    echo "=== ALL SYSTEMS GO ==="
    echo "No issues detected. Ready to start the day."
    echo ""

    # Log clean start
    ~/cmd/common/cardenas/track "MORNING CHECK: All systems healthy"

    exit 0
fi
