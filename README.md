# Claude Task Assistant

A cron-based automation that scans `tasks.md` files in your projects, generates actionable suggestions via Claude CLI, and applies approved tasks automatically.

On a schedule you choose, it:
1. Applies tasks you previously approved (with a git backup)
2. Generates suggestions for new tasks
3. Sends a desktop notification

## Requirements

- [Claude CLI](https://claude.ai/download) installed and authenticated
- macOS, Linux, or Windows (WSL)
- `crontab` access (optional — can also run manually)

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
- **Cron** — set up automatic scheduling or skip (macOS/Linux only; on Windows run manually)

**3. Edit `config.sh`** — add your projects to the `PROJECTS` list.

**4. Add a `tasks.md` to your first project:**
```markdown
---
model: sonnet
---

# Tasks

- [ ] Your first task
```

## Usage

Write a task → get a suggestion the next morning → approve with `[x]` → applied the following morning.

## Manual Run

```bash
bash ~/claude-task-assistant/scripts/run.sh           # apply + generate suggestions
bash ~/claude-task-assistant/scripts/run.sh --dry-run # preview what would happen
```

## Technologies

Bash · Python 3 · Claude CLI · cron · osascript / notify-send

---

## Platform Support

| Feature | macOS | Linux | Windows (WSL) |
|---------|-------|-------|---------|
| Core scripts (apply + suggest) | ✅ | ✅ | ✅ |
| Claude CLI | ✅ | ✅ | ✅ |
| Automatic scheduling (cron) | ✅ | ✅ | ⚠️ manual start required |
| Desktop notifications | ✅ | ✅ `notify-send` | ❌ |

**macOS:** Full support, works out of the box.

**Linux:** Full support. Cron runs natively. Notifications use `notify-send` (install with `sudo apt install libnotify-bin` if missing). You can skip notifications during setup — scripts work fine without them.

**Windows:** Requires [WSL](https://learn.microsoft.com/en-us/windows/wsl/install). The installer detects WSL and explains your options: run manually, start cron per session, or use Windows Task Scheduler. Notifications are not supported on Windows.

> Cron and notifications are **optional** — the core workflow (write task → get suggestion → approve → apply) works on any platform via manual runs.

---

📖 For Turkish users: [kullanim-kilavuzu.md](kullanim-kilavuzu.md)
