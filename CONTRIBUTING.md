# Contributing to Claude Task Assistant

Thanks for your interest in contributing!

## How to contribute

1. **Fork** the repo and create a branch from `main`
2. **Make your changes** — keep them focused and minimal
3. **Test** your changes: `bash scripts/run.sh --dry-run`
4. **Check syntax**: `bash -n scripts/run.sh scripts/check-tasks.sh scripts/apply-tasks.sh`
5. **Open a Pull Request** with a clear description of what you changed and why

## Guidelines

- Keep scripts POSIX-compatible where possible
- If adding a new feature, update README.md and kullanim-kilavuzu.md accordingly
- If changing task format keywords (`Suggestion:`, `Approve:`, etc.), update both scripts and docs

## Reporting bugs

Use the [bug report template](.github/ISSUE_TEMPLATE/bug_report.md) and include log output from `logs/`.

## Questions

Open a [Discussion](../../discussions) for general questions or ideas.
