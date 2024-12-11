#!/usr/bin/env bash

# Metadata
# Version: 2024.49.307322+affac90

set -euo pipefail

# Script to manage the Service application

# Base directory for state files (can be overridden with PAQQETS_BASE_DIR)
base_dir="${PAQQETS_BASE_DIR:-"$HOME/.paqqets"}"

# Directory for log files (can be overridden with PAQQETS_LOG_DIR)
log_dir="${PAQQETS_LOG_DIR:-"$(dirname "$0")"}"

container_port=8443
port_search_range=100
docker_container_name="notification-service"
state_file="$base_dir/${docker_container_name}/_state-file"
open_port_file="$base_dir/${docker_container_name}/_open_port"
lock_file="$base_dir/services.lock"
services_file="$base_dir/services"
default_log_file="$log_dir/${docker_container_name}_$(date +'%Y%m%d_%H%M%S').log"
postman_collection_file="postman_collection.json"

# Function to ensure directories exist
ensure_directory() {
  local dir=$1
  mkdir -p "$dir"
}

# Acquire a lock to safely modify the services file
acquire_lock() {
  while ! mkdir "$lock_file" 2>/dev/null; do
    echo "Another process is modifying the services file. Waiting..."
    sleep 1
  done

  # Set up a trap to release the lock on exit or interruption
  trap release_lock EXIT
}

# Function to release a lock
release_lock() {
  if [ -d "$lock_file" ]; then
    rmdir "$lock_file" 2>/dev/null || echo "Failed to remove lock directory. Another process may have released it."
    echo "Lock released."
  fi
}

# Register a service URL in the centralized services file
register_service() {
  local service_name=$1
  local service_url=$2
  ensure_directory "$(dirname "$services_file")"

  acquire_lock
  {
    # Add or update the service in the file
    grep -v "^${service_name}=" "$services_file" > "${services_file}.tmp" || true
    echo "${service_name}=${service_url}" >> "${services_file}.tmp"
    mv "${services_file}.tmp" "$services_file"
  }
  release_lock
}

# Remove a service entry from the centralized services file
cleanup_service_entry() {
  local service_name=$1
  ensure_directory "$(dirname "$services_file")"

  acquire_lock
  {
    # Remove the service from the file
    grep -v "^${service_name}=" "$services_file" > "${services_file}.tmp" || true
    mv "${services_file}.tmp" "$services_file"
  }
  release_lock
}

# Find a service by name in the centralized services file
find_service() {
  local service_name=$1
  if [ -f "$services_file" ]; then
    grep "^${service_name}=" "$services_file" | cut -d'=' -f2
  fi
}

# Function to read a property from a file
read_property() {
  local file=$1
  local key=$2
  if [ -f "$file" ]; then
    grep "^$key=" "$file" | cut -d'=' -f2
  fi
}

# Function to get the Docker image name
get_image_name() {
  local projectId
  projectId=$(read_property "./gradle.properties" "gcpProjectId") || true
  if [ -z "$projectId" ]; then
    projectId=$(read_property "$HOME/.gradle/gradle.properties" "gcpProjectId") || true
  fi

  if [ -z "$projectId" ]; then
    echo "Error: gcpProjectId is not set in gradle.properties."
    exit 1
  fi

  echo "gcr.io/${projectId}/${docker_container_name}:latest"
}

# Find an open port
find_open_port() {
  local start_port=$container_port
  local end_port=$((start_port + port_search_range))
  for port in $(seq "$start_port" "$end_port"); do
    if ! lsof -i -P -n | grep -q ":$port (LISTEN)"; then
      echo "$port"
      return
    fi
  done
  echo "Error: No open port found between $start_port and $end_port." >&2
  exit 1
}

# Function to build the project
build_project() {
  echo "Building the project..."
  ./gradlew clean build || { echo "Build failed"; exit 1; }
  echo "Build completed."
}

# Function to debug locally
debug_local() {
  echo "Starting application in debug mode..."
  ./gradlew bootRun --debug-jvm || { echo "Debugging failed"; exit 1; }
}

# Function to run locally with Dev profile
run_local_dev() {
  echo "Running application with 'dev' profile..."
  ./gradlew bootRun -Dspring.profiles.active=dev || { echo "Dev mode failed"; exit 1; }
}

# Function to run locally with Production profile
run_local_prod() {
  echo "Running application with 'prod' profile..."
  ./gradlew bootRun -Dspring.profiles.active=prod || { echo "Production mode failed"; exit 1; }
}

# Function to package for production
package_for_production() {
  echo "Packaging application for production deployment..."
  ./gradlew clean bootJar || { echo "Packaging failed"; exit 1; }
  echo "Application packaged successfully."
}

# Function to build and push Docker image using Jib
build_docker_image() {
  echo "Building and pushing Docker image using Jib..."
  ./gradlew jib || { echo "Docker image build and push failed"; exit 1; }
  echo "Docker image built and pushed successfully."
}

# Function to build Docker image locally using Jib
build_docker_image_local() {
  echo "Building Docker image locally using Jib..."
  ./gradlew jibDockerBuild || { echo "Docker image build failed"; exit 1; }
  echo "Docker image built successfully."
}

# Function to run the Docker container locally and register it
run_docker_local() {
  ensure_directory "$(dirname "$state_file")"
  ensure_directory "$log_dir"
  local imageName
  local open_port

  imageName=$(get_image_name)
  open_port=$(find_open_port)

  echo "Running the Docker container in the background on port $open_port..."
  local containerId
  containerId=$(docker run --rm -d -p "${open_port}:${container_port}" "$imageName")

  echo "$containerId" > "$state_file"

  docker logs -f "$containerId" > "$default_log_file" 2>&1 &
  local log_pid=$!
  echo "$log_pid" >> "$state_file"

  # Register the service in the centralized services file
  local service_url
  service_url="http://localhost:${open_port}"
  register_service "$docker_container_name" "$service_url"

  echo "Docker container is running on port $open_port. Logs: $default_log_file"
  # Save the open port to the container-specific open port state file
  echo "$open_port" > "$open_port_file"
}

# Stop Docker container
stop_docker_container() {
  ensure_directory "$(dirname "$state_file")"
  if [ -f "$state_file" ]; then
    local containerId
    local log_pid
    containerId=$(head -n 1 "$state_file")
    log_pid=$(tail -n 1 "$state_file")
    if [ -n "$containerId" ]; then
      echo "Stopping Docker container with ID: $containerId..."
      docker stop "$containerId" || echo "Docker container already stopped."
      rm -f "$state_file"
    fi
    if [ -n "$log_pid" ]; then
      echo "Stopping log process with PID: $log_pid..."
      kill "$log_pid" 2>/dev/null || echo "Log process already stopped."
    fi
    cleanup_service_entry "$docker_container_name"
  else
    echo "State file not found. No container to stop."
  fi
}

# Wait for application readiness
wait_for_application() {
  local max_attempts=20
  local delay=5
  local attempts=0

  if [ -f "$open_port_file" ]; then
    container_port=$(cat "$open_port_file")
  fi

  while [ $attempts -lt $max_attempts ]; do
    if curl -s -o /dev/null http://localhost:${container_port}/v3/api-docs; then
      echo "Application is ready."
      return 0
    fi
    echo "Waiting for application... Attempt $((++attempts))"
    sleep $delay
  done

  echo "Application did not become ready in time."
  exit 1
}

# Function to generate the Postman collection
generate_postman_collection() {
  echo "Generating Postman collection..."
  if [ -f "$open_port_file" ]; then
    container_port=$(cat "$open_port_file")
  fi

  local temp_file
  temp_file=$(mktemp)

  # Fetch the OpenAPI spec
  curl -k -o "$temp_file" "https://localhost:${container_port}/pricequote/v3/api-docs/public" || {
    echo "Failed to fetch OpenAPI spec"; rm -f "$temp_file"; exit 1;
  }

  # Generate Postman collection with a custom collection name
  npx openapi-to-postmanv2 \
    --pretty \
    -s "$temp_file" \
    -o "./postman/postman_collection.json" \
    --options '{"collectionName": "Authentication Service API Collection"}' || {
    echo "Failed to generate Postman collection"; rm -f "$temp_file"; exit 1;
  }

  rm -f "$temp_file"

  # Update collection name and description using jq
  if command -v jq &>/dev/null; then
    jq '.info.name = "Authentication Service API Collection" | .info.description.content = "This collection contains the endpoints for the PriceQuote API."' \
      "./postman/postman_collection.json" > "./postman/postman_collection_updated.json" && \
      mv "./postman/postman_collection_updated.json" "./postman/postman_collection.json"
    echo "Updated collection name and description."
  else
    echo "jq is not installed. Postman collection name and description were not updated."
  fi

  echo "Postman collection generated at ./postman/postman_collection.json"
}

# Function to check Docker container status
docker_status() {
  ensure_directory "$(dirname "$state_file")"
  if [ -f "$state_file" ]; then
    local containerId
    containerId=$(head -n 1 "$state_file")
    if [ -n "$containerId" ]; then
      if docker ps -q -f id="$containerId" &>/dev/null; then
        echo "Docker container is running. Container ID: $containerId"
        echo "Logs can be found in: $default_log_file"
        return 0
      else
        echo "Docker container with ID $containerId is not running."
        return 1
      fi
    else
      echo "No container ID found in the state file."
      return 1
    fi
  else
    echo "State file not found. Docker container is not running."
    return 1
  fi
}

# Function to display help information
show_help() {
  cat <<EOF
Usage: $0 [COMMAND]

Commands:
  build                Build the project using Gradle.
  debug                Start the application in debug mode.
  dev                  Run the application locally with the 'dev' profile.
  prod                 Run the application locally with the 'prod' profile.
  package              Package the application for production deployment.
  docker-build         Build and push the Docker image using Jib.
  docker-local         Build the Docker image locally using Jib.
  docker-run           Run the Docker container locally and register it for service discovery.
  docker-stop          Stop the running Docker container and clean up resources.
  docker-status        Check the status of the running Docker container.
  postman-collection   Generate a Postman collection based on the OpenAPI specification.
  exit                 Exit the script.

Options:
  --help               Show this help message.

Environment Variables:
  PAQQETS_BASE_DIR     Base directory for state files (default: $HOME/.paqqets).
  PAQQETS_LOG_DIR      Directory for log files (default: location of the script).

Examples:
  $0 build
  $0 docker-run
  $0 postman-collection
EOF
  exit 0
}

# Menu options
if [ -n "$1" ]; then
  case "$1" in
    --help|help) show_help ;;
    build) build_project ;;
    debug) debug_local ;;
    dev) run_local_dev ;;
    prod) run_local_prod ;;
    package) package_for_production ;;
    docker-build) build_docker_image ;;
    docker-local) build_docker_image_local ;;
    docker-run) run_docker_local ;;
    postman-collection)
      build_docker_image_local
      # Register a trap to ensure cleanup on exit or interruption
      trap stop_docker_container EXIT
      run_docker_local
      wait_for_application
      generate_postman_collection
      stop_docker_container
      ;;
    docker-stop) stop_docker_container ;;
    docker-status) docker_status ;;
    exit) echo "Exiting."; exit 0 ;;
    *) echo "Invalid argument. Use --help to see available commands."; exit 1 ;;
  esac
else
  echo "Please choose an option:"
  echo "1. Build Project"
  echo "2. Debug Locally"
  echo "3. Run Locally (Dev Profile)"
  echo "4. Run Locally (Production Profile)"
  echo "5. Package for Production"
  echo "6. Build and Push Docker Image (Jib)"
  echo "7. Build Docker Image Locally (Jib)"
  echo "8. Run Docker Container Locally"
  echo "9. Generate Postman Collection"
  echo "10. Stop Docker Container"
  echo "11. Check Docker Container Status"
  echo "12. Show Help"
  echo "13. Exit"
  read -p "Enter choice [1-13]: " choice

  case $choice in
    1) build_project ;;
    2) debug_local ;;
    3) run_local_dev ;;
    4) run_local_prod ;;
    5) package_for_production ;;
    6) build_docker_image ;;
    7) build_docker_image_local ;;
    8) run_docker_local ;;
    9)
      build_docker_image_local
      run_docker_local
      wait_for_application
      generate_postman_collection
      stop_docker_container
      ;;
    10) stop_docker_container ;;
    11) docker_status ;;
    12) show_help ;;
    13) echo "Exiting."; exit 0 ;;
    *) echo "Invalid choice. Exiting."; exit 1 ;;
  esac
fi