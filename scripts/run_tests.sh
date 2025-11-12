#!/bin/bash

# MovingBox Test Runner Script
# This script runs tests with the same configuration as CI

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Default values
SIMULATOR="iPhone 17 Pro"
TEST_SUITE="MovingBoxTests"
TEST_CLASS=""
VERBOSE=false
CLEAN=false
CODE_COVERAGE=false

# Function to print usage
usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Options:
    -s, --simulator SIMULATOR   Simulator to use (default: iPhone 17 Pro)
    -t, --test-suite SUITE      Test suite to run (default: MovingBoxTests)
    -c, --test-class CLASS      Specific test class to run (optional)
    -v, --verbose              Verbose output
    --clean                    Clean build before testing
    --coverage                 Enable code coverage
    -h, --help                Display this help message

Examples:
    # Run all tests on default simulator
    $0

    # Run DataManager tests only
    $0 -c DataManagerTests

    # Run on specific simulator with verbose output
    $0 -s "iPhone 15" -v

    # Clean build and run with coverage
    $0 --clean --coverage

EOF
    exit 0
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -s|--simulator)
            SIMULATOR="$2"
            shift 2
            ;;
        -t|--test-suite)
            TEST_SUITE="$2"
            shift 2
            ;;
        -c|--test-class)
            TEST_CLASS="$2"
            shift 2
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        --clean)
            CLEAN=true
            shift
            ;;
        --coverage)
            CODE_COVERAGE=true
            shift
            ;;
        -h|--help)
            usage
            ;;
        *)
            echo "Unknown option: $1"
            usage
            ;;
    esac
done

# Change to project root
cd "$PROJECT_ROOT"

echo -e "${YELLOW}MovingBox Test Runner${NC}"
echo "======================"
echo "Project: $PROJECT_ROOT"
echo "Simulator: $SIMULATOR"
echo "Test Suite: $TEST_SUITE"
[ -n "$TEST_CLASS" ] && echo "Test Class: $TEST_CLASS"
echo ""

# Clean if requested
if [ "$CLEAN" = true ]; then
    echo -e "${YELLOW}Cleaning build artifacts...${NC}"
    xcodebuild clean -project MovingBox.xcodeproj -scheme MovingBox > /dev/null 2>&1
    rm -rf ~/Library/Developer/Xcode/DerivedData/*MovingBox* 2>/dev/null || true
    echo -e "${GREEN}✓ Clean complete${NC}"
    echo ""
fi

# Build test command
TEST_CMD="xcodebuild test"
TEST_CMD="$TEST_CMD -project MovingBox.xcodeproj"
TEST_CMD="$TEST_CMD -scheme MovingBox"
TEST_CMD="$TEST_CMD -destination \"platform=iOS Simulator,name=$SIMULATOR\""

# Add test filtering
if [ -n "$TEST_CLASS" ]; then
    TEST_CMD="$TEST_CMD -only-testing:${TEST_SUITE}/${TEST_CLASS}"
fi

# Add verbose flag
if [ "$VERBOSE" = true ]; then
    TEST_CMD="$TEST_CMD -verbose"
fi

# Add code coverage
if [ "$CODE_COVERAGE" = true ]; then
    TEST_CMD="$TEST_CMD -enableCodeCoverage YES"
fi

# Add result bundle
RESULT_PATH="${PROJECT_ROOT}/test-results.xcresult"
TEST_CMD="$TEST_CMD -resultBundlePath $RESULT_PATH"

echo -e "${YELLOW}Running tests...${NC}"
echo "Command: $TEST_CMD"
echo ""

# Run tests
eval "$TEST_CMD"
TEST_RESULT=$?

echo ""
echo "======================"

if [ $TEST_RESULT -eq 0 ]; then
    echo -e "${GREEN}✓ All tests passed!${NC}"

    # Show coverage info if enabled
    if [ "$CODE_COVERAGE" = true ]; then
        echo ""
        echo "Code coverage report available at:"
        echo "$RESULT_PATH"
    fi

    exit 0
else
    echo -e "${RED}✗ Tests failed!${NC}"
    echo ""
    echo "Test result bundle:"
    echo "$RESULT_PATH"
    echo ""
    echo "To view detailed results:"
    echo "  open $RESULT_PATH"
    exit 1
fi
