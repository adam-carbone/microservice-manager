#!/usr/bin/env bash
set -euo pipefail

# Configuration
MANAGERW_URL="https://raw.githubusercontent.com/adam-carbone/microservice-manager/main/managerw"
MANAGERW_PATH="./managerw"

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

# Function to download the managerw script
install_managerw() {
  echo "Downloading managerw script..."
  curl -sSL -o "$MANAGERW_PATH" "$MANAGERW_URL" || error "Failed to download managerw from $MANAGERW_URL."
  chmod +x "$MANAGERW_PATH"
  success "managerw script installed successfully to $MANAGERW_PATH."
}

# Main function
main() {
  if [ "${1:-}" = "install" ]; then
    install_managerw
  else
    echo "Usage: $0 install"
    echo ""
    echo "Commands:"
    echo "  install    Download and install the managerw script."
    exit 1
  fi
}

main "$@"
