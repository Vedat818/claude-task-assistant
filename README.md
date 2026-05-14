# Claude Task Assistant

A cron-based automation that scans `tasks.md` files in your projects, generates actionable suggestions via Claude CLI, and applies approved tasks automatically.

On a schedule you choose, it:
1. Applies tasks you previously approved (with a git backup)
2. Generates suggestions for new tasks
3. Sends a desktop notification

## Requirements

- [Claude CLI](https://claude.ai/download) installed and authenticated
- macOS, Linux, or Windows (WSL)
- Python 3
- `crontab` access (optional — can also run manually)

---

## Setup

**1. Clone the repo:**
```bash
git clone https://github.com/Vedat818/claude-task-assistant.git ~/claude-task-assistant
cd ~/claude-task-assistant
```

**2. Run the installer:**
```bash
bash install.sh
```

The installer will ask:
- **Notifications** — enable or skip (macOS: built-in, Linux: requires `notify-send`, Windows: not supported)
- **Cron** — set up automatic scheduling or skip; if yes, choose the hour

**3. Edit `config.sh`** — add your projects to the `PROJECTS` list (see [Configuration](#configuration)).

**4. Add a `tasks.md` to each project** (see [tasks.md Format](#tasksmd-format)).

---

## Configuration

All settings are in `config.sh`:

```bash
# Root directory where new projects will be scaffolded via new-projects.md
PROJECTS_DIR="$HOME/Projects"

# Projects to track — use absolute paths
PROJECTS=(
  "$HOME/Projects/my-app"
  "$HOME/Projects/another-project"
)

# Default Claude model — used when tasks.md doesn't specify one
DEFAULT_MODEL="haiku"

# Desktop notifications: true or false
ENABLE_NOTIFICATIONS=true
```

**Adding a new project:** append its absolute path to the `PROJECTS` array and add a `tasks.md` to the project root.

---

## tasks.md Format

Each tracked project needs a `tasks.md` in its root:

```markdown
---
model: sonnet
---

# Tasks

- [ ] Your task description
- [x] A completed task
```

### Model Selection

The `model:` line in the frontmatter sets the Claude model for that project:

| Value | Model | When to use |
|-------|-------|-------------|
| `haiku` | Claude Haiku | Simple changes (color, text, small fixes) — fastest, cheapest |
| `sonnet` | Claude Sonnet | Most tasks — default |
| `opus` | Claude Opus | Complex refactors, architecture changes |

If omitted, `DEFAULT_MODEL` from `config.sh` is used.

---

## How It Works

### The Task Cycle

**1. Write a task:**
```
- [ ] Make the login button red
```

**2. On the next run, Claude adds a suggestion:**
```
- [ ] Make the login button red
  - Suggestion: In Button.jsx, change bg-blue-500 to bg-red-500
  - Approve: [ ]
```

**3. You approve it** by changing `[ ]` to `[x]`:
```
  - Approve: [x]
```

**4. On the next run, Claude applies it** — takes a git backup first, edits the file, runs tests if available, commits the result, and marks the task done:
```
- [x] Make the login button red
```

---

### Feedback Loop

If you don't like a suggestion, add an `Answer:` line below it:
```
- [ ] Make the login button red
  - Suggestion: Change bg-blue-500 to bg-red-500
  - Approve: [ ]
  - Answer: I want to use a custom CSS variable, not a Tailwind class
```

On the next run, Claude reads your answer, discards the old suggestion, and generates a new one.

---

### Unclear Tasks

If your task is ambiguous, Claude asks a question instead of guessing:
```
- [ ] Improve performance
  - Question: Which page and which metric? (load time, animation, etc.)
  - Answer:
```

Fill in the `Answer:` line and Claude will generate a concrete suggestion on the next run.

---

## new-projects.md — Build New Projects from Scratch

`new-projects.md` (in the root of this repo) lets you create brand-new projects using the same workflow.

**1. Write an idea:**
```
- [ ] project-name: Short description of what you want to build
```

**2. On the next run, Claude generates a full plan:**
```
- [ ] project-name: Short description
  - Suggestion:
    - TECHNOLOGIES: ...
    - ARCHITECTURE: ...
    - PHASES: ...
    - THINGS TO KNOW: ...
    - STARTING COMMANDS: ...
  - Approve: [ ]
```

**3. Approve it** (`Approve: [x]`) and on the next run Claude will:
- Create `~/Projects/project-name/`
- Scaffold Phase 1 of the project
- Write the remaining phases as tasks in the new project's `tasks.md`
- Run `git init` and make the initial commit
- Add the project to `config.sh` automatically

From that point on, the new project is tracked like any other.

---

## Running Manually

```bash
bash ~/claude-task-assistant/scripts/run.sh           # apply approved + generate suggestions
bash ~/claude-task-assistant/scripts/run.sh --dry-run # preview without making any changes
```

Run specific scripts:
```bash
bash ~/claude-task-assistant/scripts/check-tasks.sh   # only generate suggestions
bash ~/claude-task-assistant/scripts/apply-tasks.sh   # only apply approved tasks
```

---

## Rollback

Before applying any task, Claude commits a backup:
```
backup: before [task name]
```

To undo a task:
```bash
cd ~/Projects/my-app
git log --oneline   # find the backup commit
git revert HEAD     # undo the last change
```

---

## Logs

Every run writes a log file to `~/claude-task-assistant/logs/`. Logs older than 30 days are deleted automatically.

```
logs/
  check-20260514-0600.log
  apply-20260514-0600.log
  cron.log
```

---

## Platform Support

| Feature | macOS | Linux | Windows (WSL) |
|---------|-------|-------|---------------|
| Core scripts (apply + suggest) | ✅ | ✅ | ✅ |
| Claude CLI | ✅ | ✅ | ✅ |
| Automatic scheduling (cron) | ✅ | ✅ | ⚠️ manual start required |
| Desktop notifications | ✅ | ✅ `notify-send` | ❌ |

**macOS:** Full support, works out of the box.

**Linux:** Full support. Cron runs natively. Notifications use `notify-send` (install with `sudo apt install libnotify-bin` if missing). You can skip notifications during setup — scripts work fine without them.

**Windows:** Requires [WSL](https://learn.microsoft.com/en-us/windows/wsl/install). The installer detects WSL and explains your options: run manually, start cron per session, or use Windows Task Scheduler. Notifications are not supported on Windows.

> Cron and notifications are **optional** — the core workflow (write task → get suggestion → approve → apply) works on any platform via manual runs.

---

## Technologies

Bash · Python 3 · Claude CLI · cron · osascript / notify-send

---

📖 For Turkish users: [kullanim-kilavuzu.md](kullanim-kilavuzu.md)
