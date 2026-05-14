#!/bin/bash
set -euo pipefail
# run.sh
# Run by cron. First applies approved tasks, then generates new suggestions.

SCRIPT_DIR="$(dirname "$0")"
DRY_RUN="${1:-}"

# Environment variables that may be missing in cron context
export HOME="${HOME:-$(eval echo ~$(whoami))}"
export PATH="$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:$PATH"

source "$SCRIPT_DIR/../config.sh"

# Lock file — prevent concurrent runs
LOCK_FILE="$SCRIPT_DIR/../.run.lock"

if ! ( set -o noclobber; echo $$ > "$LOCK_FILE" ) 2>/dev/null; then
  LOCK_PID=$(cat "$LOCK_FILE" 2>/dev/null || true)
  if [ -n "$LOCK_PID" ] && kill -0 "$LOCK_PID" 2>/dev/null; then
    echo "Another run.sh process is already running (PID: $LOCK_PID). Exiting."
    exit 1
  else
    # Stale/invalid lock file, clean up and retry
    rm -f "$LOCK_FILE"
    ( set -o noclobber; echo $$ > "$LOCK_FILE" ) 2>/dev/null || exit 1
  fi
fi
trap 'rm -f "$LOCK_FILE"' EXIT

# Log rotation — delete logs older than 30 days
find "$LOG_DIR" -name "*.log" -mtime +30 -delete 2>/dev/null || true

bash "$SCRIPT_DIR/apply-tasks.sh" $DRY_RUN
bash "$SCRIPT_DIR/check-tasks.sh" $DRY_RUN
