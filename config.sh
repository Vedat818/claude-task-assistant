#!/bin/bash

# Directory where new projects will be created (set your own path)
PROJECTS_DIR="$HOME/Projeler"

# Projects to track — use absolute paths
PROJECTS=(
  # "$HOME/Projeler/project-name"
)

# Default model (can be overridden per project via tasks.md)
DEFAULT_MODEL="haiku"

# Desktop notifications: true to enable, false to disable
ENABLE_NOTIFICATIONS=true

# Log directory (no need to change)
LOG_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/logs"
