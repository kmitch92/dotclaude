#!/bin/bash

# =============================================================================
# CodeRAG Neo4j Database Backup/Restore
# =============================================================================
# Enables multi-machine synchronization of Neo4j knowledge graph via Docker Hub.
#
# Usage: ./scripts/coderag-db-backup.sh <command> <image-name>
#
# Commands:
#   backup <image>   Save Neo4j data to Docker Hub image
#   restore <image>  Restore Neo4j data from Docker Hub image
#
# Examples:
#   ./scripts/coderag-db-backup.sh backup myuser/coderag-db:myproject
#   ./scripts/coderag-db-backup.sh restore myuser/coderag-db:myproject
# =============================================================================

set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "$DOTFILES_DIR/scripts/utils.sh"

readonly CONTAINER_NAME="coderag-neo4j"

# =============================================================================
# Usage
# =============================================================================

show_usage() {
  cat << EOF
CodeRAG Database Backup/Restore

Usage: $0 <command> <image-name>

Commands:
  backup <image>   Save Neo4j data to Docker Hub image
  restore <image>  Restore Neo4j data from Docker Hub image

Examples:
  $0 backup myuser/coderag-db:myproject
  $0 restore myuser/coderag-db:myproject

Note: You must be logged into Docker Hub (docker login) for push operations.
EOF
}

# =============================================================================
# Helper Functions
# =============================================================================

container_exists() {
  docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"
}

container_running() {
  docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"
}

validate_image_name() {
  local image="$1"
  if [[ -z "$image" ]]; then
    print_error "Image name is required"
    echo ""
    show_usage
    exit 1
  fi

  if [[ ! "$image" =~ ^[a-zA-Z0-9][a-zA-Z0-9._/-]*:[a-zA-Z0-9._-]+$ ]] && \
     [[ ! "$image" =~ ^[a-zA-Z0-9][a-zA-Z0-9._/-]*$ ]]; then
    print_error "Invalid image name format: $image"
    print_info "Expected format: username/repository:tag or username/repository"
    exit 1
  fi
}

# =============================================================================
# Backup Function
# =============================================================================

backup_database() {
  local image="$1"
  validate_image_name "$image"

  print_header "Backing up CodeRAG Database"

  # Check if container exists
  if ! container_exists; then
    print_error "Container '$CONTAINER_NAME' does not exist"
    print_info "Run the Neo4j setup first: ./scripts/setup-coderag.sh"
    exit 1
  fi

  # Check Docker Hub login
  print_info "Verifying Docker Hub authentication..."
  if ! docker info 2>/dev/null | grep -q "Username:"; then
    print_warning "Not logged into Docker Hub"
    print_info "Running 'docker login'..."
    if ! docker login; then
      print_error "Docker Hub login failed"
      exit 1
    fi
  fi
  print_success "Docker Hub authenticated"

  # Stop container if running
  local was_running=false
  if container_running; then
    print_info "Stopping Neo4j container..."
    docker stop "$CONTAINER_NAME" >/dev/null
    was_running=true
    print_success "Container stopped"
  fi

  # Commit container to image
  print_info "Creating image from container..."
  if ! docker commit "$CONTAINER_NAME" "$image"; then
    print_error "Failed to commit container to image"
    if [[ "$was_running" == "true" ]]; then
      print_info "Restarting container..."
      docker start "$CONTAINER_NAME" >/dev/null
    fi
    exit 1
  fi
  print_success "Image created: $image"

  # Push to Docker Hub
  print_info "Pushing image to Docker Hub..."
  if ! docker push "$image"; then
    print_error "Failed to push image to Docker Hub"
    print_info "Check your Docker Hub credentials and repository permissions"
    if [[ "$was_running" == "true" ]]; then
      print_info "Restarting container..."
      docker start "$CONTAINER_NAME" >/dev/null
    fi
    exit 1
  fi
  print_success "Image pushed to Docker Hub"

  # Restart container if it was running
  if [[ "$was_running" == "true" ]]; then
    print_info "Restarting Neo4j container..."
    docker start "$CONTAINER_NAME" >/dev/null
    print_success "Container restarted"
  fi

  echo ""
  print_success "Backup complete!"
  print_info "Image: $image"
  print_info "Restore on another machine with:"
  echo "  $0 restore $image"
}

# =============================================================================
# Restore Function
# =============================================================================

restore_database() {
  local image="$1"
  validate_image_name "$image"

  print_header "Restoring CodeRAG Database"

  # Pull image from Docker Hub
  print_info "Pulling image from Docker Hub..."
  if ! docker pull "$image"; then
    print_error "Failed to pull image: $image"
    print_info "Check that the image exists and you have access"
    exit 1
  fi
  print_success "Image pulled: $image"

  # Stop and remove existing container if present
  if container_running; then
    print_info "Stopping existing container..."
    docker stop "$CONTAINER_NAME" >/dev/null
    print_success "Container stopped"
  fi

  if container_exists; then
    print_warning "Existing container will be replaced"
    if ! confirm "Continue with restore?"; then
      print_info "Restore cancelled"
      exit 0
    fi
    print_info "Removing existing container..."
    docker rm "$CONTAINER_NAME" >/dev/null
    print_success "Container removed"
  fi

  # Get Neo4j password from environment
  local env_file="$DOTFILES_DIR/.env.mcp.local"
  local neo4j_password=""

  if [[ -f "$env_file" ]]; then
    neo4j_password=$(grep "^CODERAG_NEO4J_PASSWORD=" "$env_file" 2>/dev/null | cut -d'=' -f2- || true)
  fi

  if [[ -z "$neo4j_password" ]] || [[ "$neo4j_password" == "your_neo4j_password_here" ]]; then
    print_error "CODERAG_NEO4J_PASSWORD not configured in .env.mcp.local"
    print_info "Set your Neo4j password before restoring"
    exit 1
  fi

  # Create new container from pulled image
  print_info "Creating new container from restored image..."

  local neo4j_data_dir="${CODERAG_DATA_DIR:-$HOME/neo4j-coderag}"

  if ! docker create \
    --name "$CONTAINER_NAME" \
    --restart unless-stopped \
    -p 7474:7474 \
    -p 7687:7687 \
    -v "$neo4j_data_dir/data:/data" \
    -v "$neo4j_data_dir/logs:/logs" \
    -v "$neo4j_data_dir/plugins:/plugins" \
    --env NEO4J_AUTH="neo4j/$neo4j_password" \
    --env NEO4J_PLUGINS='["apoc"]' \
    "$image" >/dev/null; then
    print_error "Failed to create container from image"
    exit 1
  fi
  print_success "Container created"

  # Start the container
  print_info "Starting Neo4j container..."
  if ! docker start "$CONTAINER_NAME" >/dev/null; then
    print_error "Failed to start container"
    exit 1
  fi
  print_success "Container started"

  echo ""
  print_success "Restore complete!"
  print_info "Neo4j is starting up..."
  print_info "Web interface: http://localhost:7474"
  print_info "Bolt endpoint: bolt://localhost:7687"
  echo ""
  print_info "Wait a moment for Neo4j to fully initialize before using CodeRAG"
}

# =============================================================================
# Main
# =============================================================================

# Check for Docker
if ! command_exists docker; then
  print_error "Docker is not installed"
  print_info "Install Docker from: https://docs.docker.com/get-docker/"
  exit 1
fi

# Check if Docker daemon is running
if ! docker info >/dev/null 2>&1; then
  print_error "Docker daemon is not running"
  print_info "Start Docker Desktop or run: sudo systemctl start docker"
  exit 1
fi

# Parse command
case "${1:-}" in
  backup)
    backup_database "${2:-}"
    ;;
  restore)
    restore_database "${2:-}"
    ;;
  -h|--help)
    show_usage
    exit 0
    ;;
  *)
    show_usage
    exit 1
    ;;
esac
