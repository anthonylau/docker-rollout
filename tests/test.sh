#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test configuration
COMPOSE_FILE="docker-compose.yml"
SERVICE_NAME="web"
PROJECT_NAME="dockerrollout_test"
DOCKER_ROLLOUT="../docker-rollout"

# Helper functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_test() {
    echo -e "${YELLOW}[TEST]${NC} $1"
}

cleanup() {
    log_info "Cleaning up..."
    docker compose -f "$COMPOSE_FILE" -p "$PROJECT_NAME" down -v 2>/dev/null || true
    docker rmi docker-rollout-test:v1 docker-rollout-test:v2 2>/dev/null || true
}

count_containers() {
    docker compose -f "$COMPOSE_FILE" -p "$PROJECT_NAME" ps -q "$SERVICE_NAME" | wc -l | tr -d ' '
}

get_container_versions() {
    docker compose -f "$COMPOSE_FILE" -p "$PROJECT_NAME" ps -q "$SERVICE_NAME" | while read cid; do
        docker inspect "$cid" --format='{{index .Config.Labels "test.version"}}' 2>/dev/null || echo "unknown"
    done | sort | uniq -c
}

wait_for_containers() {
    local expected=$1
    local timeout=30
    local elapsed=0

    while [ $elapsed -lt $timeout ]; do
        local current=$(count_containers)
        if [ "$current" -eq "$expected" ]; then
            log_info "Container count is correct: $current"
            return 0
        fi
        sleep 1
        elapsed=$((elapsed + 1))
    done

    log_error "Timeout waiting for $expected containers, got $(count_containers)"
    return 1
}

# Trap to ensure cleanup on exit
trap cleanup EXIT

log_info "Starting docker-rollout test suite"
log_info "Project: $PROJECT_NAME"
log_info "Service: $SERVICE_NAME"
echo ""

# Test 1: Initial deployment
log_test "Test 1: Initial deployment (v1)"
log_info "Building and starting initial service..."
VERSION=v1 docker compose -f "$COMPOSE_FILE" -p "$PROJECT_NAME" build --quiet
VERSION=v1 docker compose -f "$COMPOSE_FILE" -p "$PROJECT_NAME" up -d --scale "$SERVICE_NAME=2"

wait_for_containers 2
log_info "Version distribution:"
get_container_versions
echo ""

# Test 2: Rollout without batch size (all at once)
log_test "Test 2: Rollout without batch size (all at once)"
log_info "Building v2..."
VERSION=v2 docker compose -f "$COMPOSE_FILE" -p "$PROJECT_NAME" build --quiet

log_info "Running rollout without batch size..."
$DOCKER_ROLLOUT -f "$COMPOSE_FILE" -p "$PROJECT_NAME" "$SERVICE_NAME"

wait_for_containers 2
log_info "Version distribution after rollout:"
get_container_versions

# Verify all containers are v2
v2_count=$(docker compose -f "$COMPOSE_FILE" -p "$PROJECT_NAME" ps -q "$SERVICE_NAME" | while read cid; do
    docker inspect "$cid" --format='{{index .Config.Labels "test.version"}}'
done | grep -c "v2" || true)

if [ "$v2_count" -eq 2 ]; then
    log_info "✓ All containers successfully updated to v2"
else
    log_error "✗ Not all containers updated to v2 (expected 2, got $v2_count)"
    exit 1
fi
echo ""

# Test 3: Rollout with batch size = 1
log_test "Test 3: Rollout with batch size = 1"
log_info "Building v1 again for batch test..."
VERSION=v1 docker compose -f "$COMPOSE_FILE" -p "$PROJECT_NAME" build --quiet

log_info "Running rollout with --batch-size 1..."
$DOCKER_ROLLOUT -f "$COMPOSE_FILE" -p "$PROJECT_NAME" --batch-size 1 "$SERVICE_NAME"

wait_for_containers 2
log_info "Version distribution after batch rollout:"
get_container_versions

# Verify all containers are v1
v1_count=$(docker compose -f "$COMPOSE_FILE" -p "$PROJECT_NAME" ps -q "$SERVICE_NAME" | while read cid; do
    docker inspect "$cid" --format='{{index .Config.Labels "test.version"}}'
done | grep -c "v1" || true)

if [ "$v1_count" -eq 2 ]; then
    log_info "✓ All containers successfully updated to v1 using batch-size=1"
else
    log_error "✗ Not all containers updated to v1 (expected 2, got $v1_count)"
    exit 1
fi
echo ""

# Test 4: Rollout with batch size = 2 (should behave like no batch)
log_test "Test 4: Rollout with batch size = 2 (equal to scale)"
log_info "Building v2 again..."
VERSION=v2 docker compose -f "$COMPOSE_FILE" -p "$PROJECT_NAME" build --quiet

log_info "Running rollout with --batch-size 2..."
$DOCKER_ROLLOUT -f "$COMPOSE_FILE" -p "$PROJECT_NAME" --batch-size 2 "$SERVICE_NAME"

wait_for_containers 2
log_info "Version distribution after batch rollout:"
get_container_versions

# Verify all containers are v2
v2_count=$(docker compose -f "$COMPOSE_FILE" -p "$PROJECT_NAME" ps -q "$SERVICE_NAME" | while read cid; do
    docker inspect "$cid" --format='{{index .Config.Labels "test.version"}}'
done | grep -c "v2" || true)

if [ "$v2_count" -eq 2 ]; then
    log_info "✓ All containers successfully updated to v2 using batch-size=2"
else
    log_error "✗ Not all containers updated to v2 (expected 2, got $v2_count)"
    exit 1
fi
echo ""

# Test 5: Scale to 4 and test batch size = 2
log_test "Test 5: Scale to 4 containers and rollout with batch size = 2"
log_info "Scaling to 4 containers..."
docker compose -f "$COMPOSE_FILE" -p "$PROJECT_NAME" up -d --scale "$SERVICE_NAME=4" --no-recreate

wait_for_containers 4
log_info "Current container count: $(count_containers)"

log_info "Building v1 again..."
VERSION=v1 docker compose -f "$COMPOSE_FILE" -p "$PROJECT_NAME" build --quiet

log_info "Running rollout with --batch-size 2..."
$DOCKER_ROLLOUT -f "$COMPOSE_FILE" -p "$PROJECT_NAME" --batch-size 2 "$SERVICE_NAME"

wait_for_containers 4
log_info "Version distribution after batch rollout:"
get_container_versions

# Verify all containers are v1
v1_count=$(docker compose -f "$COMPOSE_FILE" -p "$PROJECT_NAME" ps -q "$SERVICE_NAME" | while read cid; do
    docker inspect "$cid" --format='{{index .Config.Labels "test.version"}}'
done | grep -c "v1" || true)

if [ "$v1_count" -eq 4 ]; then
    log_info "✓ All 4 containers successfully updated to v1 using batch-size=2"
else
    log_error "✗ Not all containers updated to v1 (expected 4, got $v1_count)"
    exit 1
fi
echo ""

log_info "All tests passed! ✓"
exit 0
