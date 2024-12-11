#!/usr/bin/env bash
set -euo pipefail

# Metadata
# Version: 2024.50.123456+abc1234

# Configuration
REPO_URL="https://raw.githubusercontent.com/adam-carbone/microservice-manager/main"
MANAGERW_PATH="$0"
MICROSERVICES_MANAGER_PATH="./microservices-manager.sh"

# Cache configuration
CACHE_DIR="${HOME}/.microservices-manager"
CACHE_FILE="${CACHE_DIR}/manager_cache"
CACHE_TTL=$((60 * 60)) # 1 hour in seconds

# Colors for output
GREEN="\033[1;32m"
RED="\033[1;31m"
RESET="\033[0m"

# Function to print success messages
success() {
  echo -e "${GREEN}$1${RESET}"
}

# Function to print error messages and exit
error() {
  echo -e "${RED}Error:${RESET} $1"
  exit 1
}

# Function to ensure the cache directory exists
ensure_cache_dir() {
  mkdir -p "$CACHE_DIR"
}

# Get local version from a script file
get_local_version() {
  grep '^# Version:' "$1" | cut -d' ' -f3 || echo "0.0.0"
}

# Get remote version from the repository
get_remote_version() {
  curl -sSL "$1" | grep '^# Version:' | cut -d' ' -f3 || echo "0.0.0"
}

# Compare semantic or CalVer versions
version_gt() {
  [ "$(printf '%s\n' "$1" "$2" | sort -V | head -n1)" != "$1" ]
}

# Function to check if cache is valid
is_cache_valid() {
  if [ -f "$CACHE_FILE" ]; then
    local cache_mtime
    cache_mtime=$(stat -c %Y "$CACHE_FILE")
    local now
    now=$(date +%s)
    (( (now - cache_mtime) < CACHE_TTL ))
  else
    return 1
  fi
}

# Update cache with the latest remote versions
update_cache() {
  echo "Fetching latest versions from remote..."
  local remote_managerw_version
  local remote_microservices_manager_version

  remote_managerw_version=$(get_remote_version "${REPO_URL}/managerw.sh")
  remote_microservices_manager_version=$(get_remote_version "${REPO_URL}/microservices-manager.sh")

  cat <<EOF > "$CACHE_FILE"
remote_managerw_version=$remote_managerw_version
remote_microservices_manager_version=$remote_microservices_manager_version
EOF
  success "Version information cached."
}

# Load cached versions
load_cache() {
  if [ -f "$CACHE_FILE" ]; then
    source "$CACHE_FILE"
  fi
}

# Ensure `microservices-manager.sh` is up-to-date
ensure_microservices_manager() {
  echo "Checking for updates to microservices-manager.sh..."
  local local_version remote_version
  local_version="0.0.0"
  remote_version="$remote_microservices_manager_version"

  # Get the local version
  if [ -f "$MICROSERVICES_MANAGER_PATH" ]; then
    local_version=$(get_local_version "$MICROSERVICES_MANAGER_PATH")
  fi

  # Update if needed
  if version_gt "$remote_version" "$local_version"; then
    echo "Updating microservices-manager.sh to version $remote_version..."
    curl -sSL -o "$MICROSERVICES_MANAGER_PATH" "${REPO_URL}/microservices-manager.sh" || error "Failed to download microservices-manager.sh."
    chmod +x "$MICROSERVICES_MANAGER_PATH"
    success "microservices-manager.sh updated to version $remote_version."
  else
    success "microservices-manager.sh is already up to date (version $local_version)."
  fi
}

# Warn the user if managerw.sh is outdated
check_managerw_update() {
  echo "Checking for updates to managerw.sh..."
  local local_version remote_version
  local_version=$(get_local_version "$MANAGERW_PATH")
  remote_version="$remote_managerw_version"

  if version_gt "$remote_version" "$local_version"; then
    echo -e "${RED}Warning:${RESET} A newer version of managerw.sh ($remote_version) is available."
    echo -e "Run the following command to update:"
    echo -e "${GREEN}curl -sSL ${REPO_URL}/managerw.sh -o managerw.sh && chmod +x managerw.sh${RESET}"
  else
    success "managerw.sh is up to date (version $local_version)."
  fi
}

# Main function to handle commands
main() {
  ensure_cache_dir

  # Check if cache is valid; if not, update it
  if ! is_cache_valid; then
    update_cache
  fi

  # Load cached version information
  load_cache

  # Check for updates to both scripts
  check_managerw_update
  ensure_microservices_manager

  # Pass commands to microservices-manager.sh
  exec "$MICROSERVICES_MANAGER_PATH" "$@"
}

main "$@"
