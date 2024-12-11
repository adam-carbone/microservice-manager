#!/usr/bin/env bash
set -euo pipefail

# Script to update the version of a target script file

# Configuration
SCRIPT_PATH=${1:-""}
if [[ -z "$SCRIPT_PATH" ]]; then
  echo "Usage: $0 <script-path>"
  echo "Example: $0 managerw.sh"
  exit 1
fi

if [[ ! -f "$SCRIPT_PATH" ]]; then
  echo "Error: File '$SCRIPT_PATH' does not exist."
  exit 1
fi

# Generate CalVer version
NOW=$(date +%s)
YEAR=$(date +%Y)

# Calculate the current week of the year
# For macOS `date`, use the format +%U (week number, starting Sunday)
WEEK=$(date +%U)

# Calculate seconds within the current week
# Get the start of the current week (Sunday at 00:00:00)
if [[ "$(uname)" == "Darwin" ]]; then
  START_OF_WEEK=$(date -v-sun -v0H -v0M -v0S +%s)  # macOS date syntax
else
  START_OF_WEEK=$(date -d "last Sunday 00:00:00" +%s)  # GNU date syntax
fi
SECONDS_WITHIN_WEEK=$((NOW - START_OF_WEEK))
TIMESTAMP=$(printf "%06d" "$SECONDS_WITHIN_WEEK")

# Get short commit hash (fallback to "unknown" if not a Git repo)
COMMIT_HASH=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")

NEW_VERSION="${YEAR}.${WEEK}.${TIMESTAMP}+${COMMIT_HASH}"

# Update the version in the target script
if grep -q '^# Version:' "$SCRIPT_PATH"; then
  sed -i.bak "s/^# Version:.*/# Version: $NEW_VERSION/" "$SCRIPT_PATH"
  rm -f "${SCRIPT_PATH}.bak"  # Remove backup file
else
  echo "Error: No '# Version:' metadata found in $SCRIPT_PATH."
  exit 1
fi

echo "Updated version of $SCRIPT_PATH to $NEW_VERSION."
