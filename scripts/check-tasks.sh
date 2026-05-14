#!/bin/bash
set -euo pipefail
# check-tasks.sh
# Scans tasks.md files in projects, calls Claude to generate suggestions for tasks that don't have one yet.

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
LOG="$LOG_DIR/check-$(date +%Y%m%d-%H%M).log"

echo "=== check-tasks started: $(date) ===" >> "$LOG"

suggestion_count=0
error_count=0

for PROJECT in "${PROJECTS[@]}"; do
  PROJECT_NAME=$(basename "$PROJECT")
  TASKS_FILE="$PROJECT/tasks.md"

  # Create tasks.md if it doesn't exist
  if [ ! -f "$TASKS_FILE" ]; then
    cat > "$TASKS_FILE" << 'EOF'
---
model: sonnet
---

# Tasks

EOF
    echo "[$PROJECT_NAME] tasks.md created" >> "$LOG"
  fi

  # Create git repo if it doesn't exist
  if [ ! -d "$PROJECT/.git" ]; then
    echo "[$PROJECT_NAME] git repo not found, initializing..." >> "$LOG"
    printf 'node_modules/\n.env\n*.log\ndist/\nbuild/\n.DS_Store\n' > "$PROJECT/.gitignore" && cd "$PROJECT" && git init -q && git add . && git commit -q -m "initial commit: async task system setup"
    echo "[$PROJECT_NAME] git init complete" >> "$LOG"
  fi

  # Check if there are any pending tasks (starting with [ ])
  if ! grep -q "^- \[ \]" "$TASKS_FILE" 2>/dev/null; then
    echo "[$PROJECT_NAME] no pending tasks, skipping" >> "$LOG"
    continue
  fi

  # Check if any task is missing a suggestion
  HAS_MISSING=$(python3 - "$TASKS_FILE" <<'PYEOF'
import sys, re

with open(sys.argv[1]) as f:
    lines = f.readlines()

for i, line in enumerate(lines):
    if re.match(r'^- \[ \] ', line):
        has_suggestion = False
        has_feedback = False
        for j in range(i+1, min(i+10, len(lines))):
            if re.match(r'^- \[', lines[j]):
                break
            if '  - Suggestion:' in lines[j] or '  - Question:' in lines[j]:
                has_suggestion = True
            if re.match(r'  - Answer: .+', lines[j]):
                has_feedback = True
        if not has_suggestion or has_feedback:
            print("yes")
            sys.exit()
print("no")
PYEOF
  )

  if [ "$HAS_MISSING" != "yes" ]; then
    echo "[$PROJECT_NAME] all tasks have suggestions, skipping" >> "$LOG"
    continue
  fi

  # Select model
  MODEL=$(grep -m1 "^model:" "$TASKS_FILE" | awk '{print $2}' | tr -d '\r')
  [ -z "$MODEL" ] && MODEL="$DEFAULT_MODEL"

  echo "[$PROJECT_NAME] generating suggestions (model: $MODEL)..." >> "$LOG"

  if [ "$DRY_RUN" = true ]; then
    echo "[DRY RUN] [$PROJECT_NAME] would run claude --model $MODEL to generate suggestions" >> "$LOG"
    echo "[DRY RUN] [$PROJECT_NAME] would generate suggestions (model: $MODEL)"
    suggestion_count=$((suggestion_count + 1))
    continue
  fi

  # Create CLAUDE.md in a separate session if it doesn't exist
  if [ ! -f "$PROJECT/CLAUDE.md" ]; then
    echo "[$PROJECT_NAME] creating CLAUDE.md..." >> "$LOG"
    (cd "$PROJECT" && \
    timeout 180 claude --model "$MODEL" --dangerously-skip-permissions --max-turns 3 -p \
"Inspect the project and create a CLAUDE.md file:
- What the project does (1-2 sentences)
- Technologies and frameworks used
- File structure summary
- Important conventions (if any)
ONLY create CLAUDE.md, do nothing else." \
    >> "$LOG" 2>&1) || echo "[$PROJECT_NAME] failed to create CLAUDE.md" >> "$LOG"
  fi

  # Embed tasks.md content in the prompt
  TASKS_CONTENT=$(cat "$TASKS_FILE")

  if (cd "$PROJECT" && \
  timeout 600 claude --model "$MODEL" --dangerously-skip-permissions --max-turns 10 -p \
"tasks.md content:
$TASKS_CONTENT

For tasks starting with '- [ ]' that don't have '  - Suggestion:' or '  - Question:' below them:
1. Identify the task type (bug fix, new feature, refactor, style/UI change)
2. Find the relevant files and inspect existing code
3. Write a concrete, actionable suggestion:
   - Which file(s) will change
   - What will be added/removed/changed (include a code snippet if possible)
   - Any side effects to be aware of
4. If the task is unclear, use 'Question:' to ask the user for clarification

IMPORTANT: Do not use vague language in suggestions (e.g. 'make the necessary changes').
Each suggestion must be specific enough that someone else can read it and apply it directly.

Update tasks.md in this format (ONLY add to tasks that are missing suggestions, don't touch others):

- [ ] task description
  - Suggestion: which file, what to change (specific)
  - Approve: [ ]

For an unclear task:
- [ ] task description
  - Question: what exactly do you want?
  - Answer:

If a task already has '  - Suggestion:' or '  - Question:' but also has a filled '  - Answer: ...' line below it:
The user has given feedback on the suggestion/question. DELETE the old suggestion/question and the answer line, then generate a NEW suggestion taking the answer into account.
Only the new Suggestion + Approve lines should remain.

ONLY update tasks.md, write nothing else." \
  >> "$LOG" 2>&1); then
    echo "[$PROJECT_NAME] done" >> "$LOG"
    suggestion_count=$((suggestion_count + 1))
  else
    echo "[$PROJECT_NAME] ERROR: claude command failed (exit code: $?)" >> "$LOG"
    error_count=$((error_count + 1))
  fi
done

# === IDEAS.MD: Generate suggestions for new project ideas ===
IDEAS_FILE="$(dirname "$0")/../ideas.md"

if [ -f "$IDEAS_FILE" ] && grep -q "^- \[ \]" "$IDEAS_FILE" 2>/dev/null; then
  # Check if any idea is missing a suggestion
  IDEAS_MISSING=$(python3 - "$IDEAS_FILE" <<'PYEOF'
import sys, re

with open(sys.argv[1]) as f:
    lines = f.readlines()

for i, line in enumerate(lines):
    if re.match(r'^- \[ \] ', line):
        has_suggestion = False
        has_feedback = False
        for j in range(i+1, min(i+10, len(lines))):
            if re.match(r'^- \[', lines[j]):
                break
            if '  - Suggestion:' in lines[j] or '  - Question:' in lines[j]:
                has_suggestion = True
            if re.match(r'  - Answer: .+', lines[j]):
                has_feedback = True
        if not has_suggestion or has_feedback:
            print("yes")
            sys.exit()
print("no")
PYEOF
  )

  if [ "$IDEAS_MISSING" = "yes" ]; then
    IDEAS_MODEL=$(grep -m1 "^model:" "$IDEAS_FILE" | awk '{print $2}')
    [ -z "$IDEAS_MODEL" ] && IDEAS_MODEL="$DEFAULT_MODEL"

    echo "[ideas] generating suggestions (model: $IDEAS_MODEL)..." >> "$LOG"

    if [ "$DRY_RUN" = true ]; then
      echo "[DRY RUN] [ideas] would run claude --model $IDEAS_MODEL to generate suggestions" >> "$LOG"
      echo "[DRY RUN] [ideas] would generate suggestions (model: $IDEAS_MODEL)"
      suggestion_count=$((suggestion_count + 1))
    else
      IDEAS_CONTENT=$(cat "$IDEAS_FILE")
      if (cd "$(dirname "$0")" && \
      timeout 600 claude --model "$IDEAS_MODEL" --dangerously-skip-permissions --max-turns 10 -p \
"ideas.md content:
$IDEAS_CONTENT

This file contains ideas for projects to build from scratch.
For ideas starting with '- [ ]' that don't have '  - Suggestion:' or '  - Question:' below them:

1. Understand the project idea description
2. Write a concrete plan under these headings:
   - TECHNOLOGIES: Each tool and why you chose it (one sentence each)
   - ARCHITECTURE: Folder structure and overall flow
   - PHASES: Development roadmap (what to build in which order)
   - THINGS TO KNOW: Important details the user might not think of (API keys, rate limits, deprecated libraries, etc.)
   - STARTING COMMANDS: Commands needed to bootstrap the project
3. If the idea is unclear, write '  - Question:' instead and ask the user for clarification

Update ideas.md in this format (ONLY add to ideas missing suggestions, don't touch others):

- [ ] project-name: description
  - Suggestion:
    - TECHNOLOGIES: ...
    - ARCHITECTURE: ...
    - PHASES: ...
    - THINGS TO KNOW: ...
    - STARTING COMMANDS: ...
  - Approve: [ ]

For an unclear idea:
- [ ] project-name: description
  - Question: what exactly do you want?
  - Answer:

ONLY update ideas.md, write nothing else." \
      >> "$LOG" 2>&1); then
        echo "[ideas] done" >> "$LOG"
        suggestion_count=$((suggestion_count + 1))
      else
        echo "[ideas] ERROR: claude command failed (exit code: $?)" >> "$LOG"
        error_count=$((error_count + 1))
      fi
    fi
  fi
fi

# Notifications
if [ "$suggestion_count" -gt 0 ]; then
  notify "Claude Task Assistant" "Suggestions ready for $suggestion_count project(s). Check your tasks.md files." "default"
fi

if [ "$error_count" -gt 0 ]; then
  notify "Async Task - Error" "$error_count project(s) encountered errors. Check the logs." "Basso"
fi

echo "=== check-tasks finished: $(date) ===" >> "$LOG"
