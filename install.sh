#!/bin/bash
# install.sh — Interactive setup for Claude Task Assistant

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG="$SCRIPT_DIR/config.sh"

echo ""
echo "=== Claude Task Assistant — Setup ==="
echo ""

# --- Notifications ---
echo "Enable desktop notifications? (macOS: built-in / Linux: requires notify-send / Windows: not supported)"
read -rp "Enable notifications? [Y/n]: " notif_answer
notif_answer="${notif_answer:-Y}"

if [[ "$notif_answer" =~ ^[Yy]$ ]]; then
  # Check if notifications can actually work
  if [[ "$OSTYPE" == "darwin"* ]]; then
    echo "  macOS detected — notifications enabled."
  elif command -v notify-send &>/dev/null; then
    echo "  notify-send found — notifications enabled."
  else
    echo "  Warning: notify-send not found. Install it with: sudo apt install libnotify-bin"
    echo "  Notifications will be silently skipped until notify-send is installed."
  fi
  sed -i.bak 's/^ENABLE_NOTIFICATIONS=.*/ENABLE_NOTIFICATIONS=true/' "$CONFIG" && rm -f "$CONFIG.bak"
else
  sed -i.bak 's/^ENABLE_NOTIFICATIONS=.*/ENABLE_NOTIFICATIONS=false/' "$CONFIG" && rm -f "$CONFIG.bak"
  echo "  Notifications disabled."
fi

echo ""

# --- Cron ---
# Detect WSL
IS_WSL=false
if grep -qi microsoft /proc/version 2>/dev/null; then
  IS_WSL=true
fi

if $IS_WSL; then
  echo "Windows (WSL) detected."
  echo "  Cron exists in WSL but does not start automatically."
  echo "  Options:"
  echo "    A) Run manually:  bash $SCRIPT_DIR/scripts/run.sh"
  echo "    B) Start cron manually each session: sudo service cron start"
  echo "    C) Use Windows Task Scheduler to run WSL automatically (advanced):"
  echo "       Action: wsl.exe bash $SCRIPT_DIR/scripts/run.sh"
  echo ""
  read -rp "Add cron entry anyway (requires 'sudo service cron start' each session)? [y/N]: " cron_answer
  cron_answer="${cron_answer:-N}"
elif [[ "$OSTYPE" == "darwin"* ]] || [[ "$OSTYPE" == "linux-gnu"* ]]; then
  echo "Set up automatic scheduling with cron? (runs every morning at 06:00)"
  read -rp "Set up cron? [Y/n]: " cron_answer
  cron_answer="${cron_answer:-Y}"
else
  echo "Cron is not supported on this platform."
  echo "Run the system manually with:"
  echo "  bash $SCRIPT_DIR/scripts/run.sh"
  cron_answer="N"
fi

if [[ "$cron_answer" =~ ^[Yy]$ ]]; then
  read -rp "Run at what hour? [default: 6]: " cron_hour
  cron_hour="${cron_hour:-6}"

  CRON_LINE="0 $cron_hour * * * /bin/bash $SCRIPT_DIR/scripts/run.sh >> $SCRIPT_DIR/logs/cron.log 2>&1"

  if crontab -l 2>/dev/null | grep -qF "$SCRIPT_DIR/scripts/run.sh"; then
    echo "  Cron entry already exists, skipping."
  else
    ( crontab -l 2>/dev/null; echo "$CRON_LINE" ) | crontab -
    echo "  Cron set up: runs daily at ${cron_hour}:00."
    $IS_WSL && echo "  Remember: run 'sudo service cron start' to activate cron in WSL."
  fi
else
  echo "  Cron skipped. Run manually with:"
  echo "    bash $SCRIPT_DIR/scripts/run.sh"
fi

echo ""
echo "=== Setup complete! ==="
echo ""
echo "Next steps:"
echo "  1. Edit config.sh — add your projects to the PROJECTS list"
echo "  2. Add a tasks.md to each project"
echo "  3. Run manually to test: bash $SCRIPT_DIR/scripts/run.sh --dry-run"
echo ""
