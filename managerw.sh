#!/usr/bin/env bash
set -euo pipefail

# Metadata
# Version: 2024.49.363726+8e8b4ed

# Configuration
REPO_URL="${REPO_URL_OVERRIDE:-https://raw.githubusercontent.com/adam-carbone/microservice-manager/main}"
MANAGER_URL="${REPO_URL}/microservices-manager.sh"
CACHE_DIR="${HOME}/.microservices-manager"
CACHE_FILE="${CACHE_DIR}/microservices-manager.sh"
CACHE_TTL=$((60 * 60))  # 1 hour in seconds

VERSION_URL="${REPO_URL}/managerw-version"
LOCAL_VERSION="2024.50.123456"

# Colors for output
GREEN="\033[1;32m"
YELLOW="\033[1;33m"
RED="\033[1;31m"
RESET="\033[0m"

# Function to print success messages
success() {
  echo -e "${GREEN}$1${RESET}"
}

# Function to print warning messages
warning() {
  echo -e "${YELLOW}Warning:${RESET} $1"
}

# Function to print error messages and exit
error() {
  echo -e "${RED}Error:${RESET} $1"
  exit 1
}

# Ensure cache directory exists
ensure_cache_dir() {
  mkdir -p "$CACHE_DIR"
}

# Check if the cache file is valid
is_cache_valid() {
  if [[ -f "$CACHE_FILE" ]]; then
    local cache_mtime
    if [[ "$(uname)" == "Darwin" ]]; then
      cache_mtime=$(stat -f %m "$CACHE_FILE")  # macOS-specific
    else
      cache_mtime=$(stat -c %Y "$CACHE_FILE")  # GNU stat
    fi
    local now
    now=$(date +%s)
    (( (now - cache_mtime) < CACHE_TTL ))
  else
    return 1
  fi
}

# Fetch the latest manager script
fetch_manager() {
  echo "Fetching the latest microservices-manager script..."
  curl -sSL -o "$CACHE_FILE" "$MANAGER_URL" || error "Failed to download manager script from $MANAGER_URL."
  chmod +x "$CACHE_FILE"
  success "Fetched and cached the latest manager script."
}

# Check for updates to managerw itself
check_self_update() {
  local remote_version
  remote_version=$(curl -sSL "$VERSION_URL" || echo "unknown")
  if [[ "$remote_version" != "$LOCAL_VERSION" && "$remote_version" != "unknown" ]]; then
    warning "A new version of managerw.sh is available: $remote_version."
    warning "Update by running: curl -sSL ${REPO_URL}/managerw.sh -o managerw.sh && chmod +x managerw.sh"
  fi
}

# Ensure the latest manager script is available
ensure_latest_manager() {
  ensure_cache_dir
  if ! is_cache_valid; then
    fetch_manager
  else
    echo "Using cached microservices-manager script."
  fi
}

# Main function
main() {
  check_self_update
  ensure_latest_manager

  # Execute the cached microservices manager script with passed arguments
  exec "$CACHE_FILE" "$@"
}

main "$@"
