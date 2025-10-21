# Docker Rollout Tests

This directory contains tests for the docker-rollout tool.

## Test Types

### Unit Tests
Basic logic validation without Docker (runs anywhere):
```bash
cd tests
./unit-test.sh
```

### Simulation Test
Visual demonstration of batch logic without Docker (runs anywhere):
```bash
cd tests
./test-simulation.sh
```

This simulation walks through different batch-size scenarios step-by-step,
showing exactly how containers are scaled, health-checked, and removed.
Perfect for understanding the batch logic without needing Docker.

### Integration Tests
Full end-to-end tests with Docker Compose (requires Docker):
```bash
cd tests
./test.sh
```

**Note:** Integration tests require Docker and Docker Compose to be installed
and running. If Docker is not available, use the simulation test instead to
see how the batch logic works.

## Prerequisites

### Unit Tests
- Bash shell

### Integration Tests
- Docker with Docker Compose support
- Bash shell

## Test Scenarios

The test suite covers the following scenarios:

### 1. Initial Deployment
- Builds and deploys version 1 of the test service
- Verifies that 2 containers are running

### 2. Rollout Without Batch Size
- Updates all containers at once (default behavior)
- Verifies all containers are updated to the new version

### 3. Rollout With Batch Size = 1
- Updates containers one at a time
- Verifies incremental updates work correctly

### 4. Rollout With Batch Size = Scale
- Updates with batch size equal to total container count
- Should behave like default (all at once)

### 5. Rollout With Multiple Batches
- Scales to 4 containers
- Updates 2 containers at a time
- Verifies batch-based updates with multiple iterations

## Test Service

The tests use a simple nginx-based service with:
- Healthcheck configured (2s interval)
- Version labels for verification
- Lightweight Alpine base image

## Cleanup

The test script automatically cleans up all created containers and images on exit.

## Expected Output

Successful test runs will show:
- Green `[INFO]` messages for informational output
- Yellow `[TEST]` messages for each test case
- ✓ marks for passed tests
- Final "All tests passed! ✓" message
