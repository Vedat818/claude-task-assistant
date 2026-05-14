# Claude Task Assistant

A cron-based automation system that scans `tasks.md` files in your projects, generates suggestions via Claude CLI, and automatically applies approved tasks.

## Technologies
- Bash (shell scripting)
- Python3 (inline scripts for tasks.md parsing)
- Claude CLI (`claude --model ... -p`)
- macOS cron + osascript (notifications)

## File Structure
```
config.sh              - project list and settings (PROJECTS array, DEFAULT_MODEL)
scripts/run.sh         - main runner (lock + log rotation + apply + check)
scripts/check-tasks.sh - suggestion generation (calls Claude for tasks without suggestions)
scripts/apply-tasks.sh - applies approved tasks (git backup + Claude execution)
new-projects.md               - ideas for new projects to create from scratch
tasks.md               - tasks for this project itself
kullanim-kilavuzu.md   - user documentation (Turkish)
logs/                  - run logs (kept for 30 days)
```

## Conventions
- tasks.md frontmatter: `model: opus|sonnet|haiku` selects the model per project
- Task format: `- [ ] description` + `  - Suggestion:` + `  - Approve: [ ]`
- A git backup commit is taken before each task is applied
- Lock file (`.run.lock`) prevents concurrent runs
