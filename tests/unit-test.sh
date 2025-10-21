#!/bin/bash
# Unit tests for docker-rollout script logic (no Docker required)

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

TESTS_PASSED=0
TESTS_FAILED=0

log_pass() {
    echo -e "${GREEN}✓${NC} $1"
    TESTS_PASSED=$((TESTS_PASSED + 1))
}

log_fail() {
    echo -e "${RED}✗${NC} $1"
    TESTS_FAILED=$((TESTS_FAILED + 1))
}

log_test() {
    echo -e "${YELLOW}[TEST]${NC} $1"
}

# Test 1: Check script has correct shebang
log_test "Checking script shebang"
if head -1 ../docker-rollout | grep -q "^#!/bin/sh"; then
    log_pass "Script has correct shebang"
else
    log_fail "Script missing or incorrect shebang"
fi

# Test 2: Check BATCH_SIZE default is set
log_test "Checking BATCH_SIZE default value"
if grep -q "^BATCH_SIZE=0" ../docker-rollout; then
    log_pass "BATCH_SIZE default is set to 0"
else
    log_fail "BATCH_SIZE default not found or incorrect"
fi

# Test 3: Check --batch-size flag is in usage
log_test "Checking --batch-size in usage text"
if grep -q "\-b | --batch-size" ../docker-rollout; then
    log_pass "--batch-size flag documented in usage"
else
    log_fail "--batch-size flag not in usage text"
fi

# Test 4: Check batch-size argument parsing
log_test "Checking batch-size argument parsing"
if grep -A 2 "\-b | --batch-size)" ../docker-rollout | grep -q 'BATCH_SIZE="\$2"'; then
    log_pass "batch-size argument parsing implemented"
else
    log_fail "batch-size argument parsing not found"
fi

# Test 5: Check conditional logic for batch size
log_test "Checking batch size conditional logic"
if grep -q "if \[ \"\$BATCH_SIZE\" -eq 0 \] || \[ \"\$BATCH_SIZE\" -ge \"\$SCALE\" \]; then" ../docker-rollout; then
    log_pass "Batch size conditional logic present"
else
    log_fail "Batch size conditional logic not found"
fi

# Test 6: Check wait_for_health function exists
log_test "Checking wait_for_health function"
if grep -q "^wait_for_health() {" ../docker-rollout; then
    log_pass "wait_for_health function exists"
else
    log_fail "wait_for_health function not found"
fi

# Test 7: Check run_pre_stop_hooks function exists
log_test "Checking run_pre_stop_hooks function"
if grep -q "^run_pre_stop_hooks() {" ../docker-rollout; then
    log_pass "run_pre_stop_hooks function exists"
else
    log_fail "run_pre_stop_hooks function not found"
fi

# Test 8: Check stop_and_remove_containers function exists
log_test "Checking stop_and_remove_containers function"
if grep -q "^stop_and_remove_containers() {" ../docker-rollout; then
    log_pass "stop_and_remove_containers function exists"
else
    log_fail "stop_and_remove_containers function not found"
fi

# Test 9: Check batch update loop exists
log_test "Checking batch update loop"
if grep -q "while \[ -n \"\$REMAINING_OLD_CONTAINERS\" \]; do" ../docker-rollout; then
    log_pass "Batch update loop exists"
else
    log_fail "Batch update loop not found"
fi

# Test 10: Check script syntax is valid
log_test "Checking script syntax"
if sh -n ../docker-rollout 2>/dev/null; then
    log_pass "Script syntax is valid"
else
    log_fail "Script has syntax errors"
fi

# Summary
echo ""
echo "================================"
echo "Test Results:"
echo -e "${GREEN}Passed:${NC} $TESTS_PASSED"
echo -e "${RED}Failed:${NC} $TESTS_FAILED"
echo "================================"

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}All unit tests passed!${NC}"
    exit 0
else
    echo -e "${RED}Some tests failed!${NC}"
    exit 1
fi
