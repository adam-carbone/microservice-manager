#!/usr/bin/env bash
set -euo pipefail

# Configuration
MANAGERW_URL="https://raw.githubusercontent.com/adam-carbone/microservice-manager/main/managerw.sh"
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
  if [ -f "$MANAGERW_PATH" ]; then
    echo "managerw already exists at $MANAGERW_PATH."
    echo -n "Do you want to overwrite it? (y/N): "  # Use echo -n for prompt
    read choice
    if [[ "$choice" != "y" && "$choice" != "Y" ]]; then
      success "Installation aborted."
      exit 0
    fi
  fi

  if ! command -v curl &>/dev/null; then
    error "curl is not installed. Please install curl and try again."
  fi

  echo "Downloading managerw script..."
  curl -sSL -o "$MANAGERW_PATH" "$MANAGERW_URL" || error "Failed to download managerw from $MANAGERW_URL."
  chmod +x "$MANAGERW_PATH"

  # Test if the downloaded script is executable
  if ! bash "$MANAGERW_PATH" --help &>/dev/null; then
    error "Downloaded script is not executable or valid. Please check the URL or the script."
  fi

  success "managerw script installed successfully to $MANAGERW_PATH."
}

# Main function
main() {
  case "${1:-}" in
    install)
      install_managerw
      ;;
    --version|version)
      echo "Bootstrap script version: 1.0.0"
      ;;
    *)
      echo "Usage: $0 install"
      echo ""
      echo "Commands:"
      echo "  install    Download and install the managerw script."
      echo "  version    Display the bootstrap script version."
      exit 1
      ;;
  esac
}

main "$@"
