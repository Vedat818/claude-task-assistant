#!/bin/bash
set -euo pipefail
# apply-tasks.sh
# Applies approved tasks (Approve: [x]). Takes a git backup before each task.

DRY_RUN=false
if [ "${1:-}" = "--dry-run" ]; then
  DRY_RUN=true
fi

source "$(dirname "$0")/../config.sh"
mkdir -p "$LOG_DIR"

notify() {
  local title="$1" message="$2" sound="${3:-}"
  [ "${ENABLE_NOTIFICATIONS:-true}" = "true" ] || return 0
  if [[ "$OSTYPE" == "darwin"* ]]; then
    local s=""; [ -n "$sound" ] && s=" sound name \"$sound\""
    osascript -e "display notification \"$message\" with title \"$title\"$s"
  elif command -v notify-send &>/dev/null; then
    notify-send "$title" "$message"
  fi
}
LOG="$LOG_DIR/apply-$(date +%Y%m%d-%H%M).log"

echo "=== apply-tasks started: $(date) ===" >> "$LOG"

applied_count=0
error_count=0

for PROJECT in "${PROJECTS[@]}"; do
  PROJECT_NAME=$(basename "$PROJECT")
  TASKS_FILE="$PROJECT/tasks.md"

  if [ ! -f "$TASKS_FILE" ]; then
    continue
  fi

  # Check if there are any approved tasks
  if ! grep -q "  - Approve: \[x\]" "$TASKS_FILE" 2>/dev/null; then
    echo "[$PROJECT_NAME] no approved tasks, skipping" >> "$LOG"
    continue
  fi

  APPROVED_COUNT=$(grep -c "  - Approve: \[x\]" "$TASKS_FILE" || true)
  echo "[$PROJECT_NAME] $APPROVED_COUNT approved task(s) found" >> "$LOG"

  # Error and skip if git repo is missing
  if [ ! -d "$PROJECT/.git" ]; then
    echo "[$PROJECT_NAME] ERROR: git repo not found, skipping task" >> "$LOG"
    notify "Async Task - Error" "$PROJECT_NAME: no git repo, task could not be applied."
    continue
  fi

  # Select model
  MODEL=$(grep -m1 "^model:" "$TASKS_FILE" | awk '{print $2}' | tr -d '\r')
  [ -z "$MODEL" ] && MODEL="$DEFAULT_MODEL"

  echo "[$PROJECT_NAME] applying tasks (model: $MODEL)..." >> "$LOG"

  if [ "$DRY_RUN" = true ]; then
    echo "[DRY RUN] [$PROJECT_NAME] would apply $APPROVED_COUNT task(s) (model: $MODEL)" >> "$LOG"
    echo "[DRY RUN] [$PROJECT_NAME] would apply $APPROVED_COUNT task(s) (model: $MODEL)"
    applied_count=$((applied_count + 1))
    continue
  fi

  TASKS_CONTENT=$(cat "$TASKS_FILE")

  if (cd "$PROJECT" && \
  timeout 300 claude --model "$MODEL" --dangerously-skip-permissions --max-turns 6 -p \
"tasks.md content:
$TASKS_CONTENT

Apply tasks that have '  - Approve: [x]' in order.

For each task, follow these steps:
1. Run 'git add . && git commit -m \"backup: before [task name]\"'
2. Apply the change described in the Suggestion line (edit the relevant files)
3. If the project has a test command (npm test, pytest, go test, etc.), run it
4. If the project has a build command (npm run build, etc.), run it
5. If tests or build fail, try to fix them. If you can't, add a note in tasks.md:
   - Warning: [error description]
6. Run 'git add . && git commit -m \"task: [task name]\"'
7. In tasks.md, mark the task as '- [x]' and delete the '  - Suggestion:' and '  - Approve:' lines

ONLY apply the tasks, do not write unnecessary explanations." \
  >> "$LOG" 2>&1); then
    echo "[$PROJECT_NAME] done" >> "$LOG"
    applied_count=$((applied_count + 1))
  else
    echo "[$PROJECT_NAME] ERROR: claude command failed (exit code: $?)" >> "$LOG"
    error_count=$((error_count + 1))
  fi
done

# === NEW-PROJECTS.MD: Create approved project ideas ===
SCRIPT_DIR="$(dirname "$0")"
IDEAS_FILE="$SCRIPT_DIR/../new-projects.md"
CONFIG_FILE="$SCRIPT_DIR/../config.sh"

if [ -f "$IDEAS_FILE" ] && grep -q "  - Approve: \[x\]" "$IDEAS_FILE" 2>/dev/null; then
  IDEAS_MODEL=$(grep -m1 "^model:" "$IDEAS_FILE" | awk '{print $2}')
  [ -z "$IDEAS_MODEL" ] && IDEAS_MODEL="$DEFAULT_MODEL"

  # Write approved ideas to temp variable (to avoid pipe subshell issues)
  IDEA_ITEMS=$(python3 - "$IDEAS_FILE" <<'PYEOF'
import sys, re

with open(sys.argv[1]) as f:
    lines = f.readlines()

i = 0
while i < len(lines):
    line = lines[i]
    if re.match(r'^- \[ \] ', line):
        task_text = line[6:].strip()
        slug_match = re.match(r'^([\w-]+):', task_text)
        slug = slug_match.group(1) if slug_match else task_text.split()[0].lower().replace(' ', '-')
        for j in range(i+1, min(i+6, len(lines))):
            if re.match(r'^- \[', lines[j]):
                break
            if '  - Approve: [x]' in lines[j]:
                print(f"{line.strip()}\x01{slug}")
                break
    i += 1
PYEOF
  )

  # Read IDEAS_FILE content upfront (for use in Claude prompt)
  IDEAS_CONTENT=$(cat "$IDEAS_FILE")

  while IFS=$'\x01' read -r TASK_LINE PROJECT_SLUG; do
    [ -z "$PROJECT_SLUG" ] && continue
    PROJECT_PATH="$PROJECTS_DIR/$PROJECT_SLUG"

    echo "[new-projects] creating project '$PROJECT_SLUG'..." >> "$LOG"

    if [ "$DRY_RUN" = true ]; then
      echo "[DRY RUN] [new-projects] would create $PROJECT_PATH (model: $IDEAS_MODEL)" >> "$LOG"
      echo "[DRY RUN] [new-projects] would create project '$PROJECT_SLUG' (model: $IDEAS_MODEL)"
      applied_count=$((applied_count + 1))
      continue
    fi

    # Create the directory
    mkdir -p "$PROJECT_PATH"

    # Scaffold the project with Claude
    if (cd "$PROJECT_PATH" && \
    timeout 600 claude --model "$IDEAS_MODEL" --dangerously-skip-permissions --max-turns 10 -p \
"You are creating a new project from scratch. Current directory: $PROJECT_PATH

Task: $TASK_LINE

Apply the suggestion written for this task in new-projects.md:
$IDEAS_CONTENT

Follow these steps:
1. Run the STARTING COMMANDS from the suggestion (if any)
2. Set up the base files and folder structure according to ARCHITECTURE
3. Implement ONLY Phase 1 from PHASES (the basic skeleton)
4. Write the remaining phases as tasks in the project's tasks.md file, in this format:

---
model: sonnet
---

# Tasks

- [ ] phase 2 description
- [ ] phase 3 description
...

5. Get the project into a runnable state (required config, starter code, etc.)

NOTE: Only scaffold Phase 1. The other phases will be handled via tasks.md." \
    >> "$LOG" 2>&1); then
      # Git init
      (cd "$PROJECT_PATH" && git init -q && git add . && git commit -q -m "initial commit: project created") 2>> "$LOG"

      # Add to config.sh
      python3 - "$CONFIG_FILE" "$PROJECT_PATH" <<'PYEOF'
import sys
config_file, project_path = sys.argv[1], sys.argv[2]
with open(config_file) as f:
    lines = f.readlines()
result = []
for line in lines:
    if line.strip() == ')':
        result.append(f'  "{project_path}"\n')
    result.append(line)
with open(config_file, 'w') as f:
    f.writelines(result)
PYEOF

      # Mark idea as [x] in new-projects.md and remove sub-lines
      python3 - "$IDEAS_FILE" "$TASK_LINE" <<'PYEOF'
import sys

with open(sys.argv[1]) as f:
    lines = f.readlines()

task_line = sys.argv[2]
result = []
i = 0
while i < len(lines):
    line = lines[i]
    if line.strip() == task_line:
        result.append(line.replace('- [ ] ', '- [x] ', 1))
        # Skip sub-lines (Suggestion, Approve, etc.)
        i += 1
        while i < len(lines) and lines[i].startswith('  - '):
            i += 1
        continue
    result.append(line)
    i += 1

with open(sys.argv[1], 'w') as f:
    f.writelines(result)
PYEOF

      echo "[new-projects] project '$PROJECT_SLUG' created and added to config.sh" >> "$LOG"
      applied_count=$((applied_count + 1))
    else
      echo "[new-projects] ERROR: failed to create '$PROJECT_SLUG' (exit code: $?)" >> "$LOG"
      error_count=$((error_count + 1))
    fi
  done <<< "$IDEA_ITEMS"
fi

# Notifications
if [ "$applied_count" -gt 0 ]; then
  notify "Claude Task Assistant" "Tasks applied in $applied_count project(s)." "Glass"
fi

if [ "$error_count" -gt 0 ]; then
  notify "Async Task - Error" "$error_count project(s) encountered errors. Check the logs." "Basso"
fi

echo "=== apply-tasks finished: $(date) ===" >> "$LOG"
