#!/bin/bash
# Smoke Test Runner
#
# Runs critical path smoke tests to verify basic functionality.
# These tests run on every PR and should complete within 5 minutes.

set -e

# Default values
PLATFORM="all"
DEVICE="emulator"
COVERAGE=false
VERBOSE=false
OUTPUT_DIR="dual_reader/test_results"
SCREENSHOT_DIR="dual_reader/test_screenshots"

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --platform)
      PLATFORM="$2"
      shift 2
      ;;
    --device)
      DEVICE="$2"
      shift 2
      ;;
    --coverage)
      COVERAGE=true
      shift
      ;;
    --verbose)
      VERBOSE=true
      shift
      ;;
    --output-dir)
      OUTPUT_DIR="$2"
      shift 2
      ;;
    --help)
      echo "Usage: $0 [OPTIONS]"
      echo ""
      echo "Options:"
      echo "  --platform PLATFORM    Platform to test: android, ios, web, all (default: all)"
      echo "  --device DEVICE        Device type: emulator, simulator, browser, device (default: emulator)"
      echo "  --coverage             Generate coverage report"
      echo "  --verbose              Enable verbose output"
      echo "  --output-dir DIR       Test results output directory"
      echo ""
      echo "Smoke tests cover:"
      echo "  - App launches successfully"
      echo "  - Can import a book"
      echo "  - Can open and read a book"
      echo "  - Can navigate pages"
      echo "  - Can translate a page"
      echo "  - Can change settings"
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
  echo -e "${GREEN}[INFO]${NC} $1"
}

log_error() {
  echo -e "${RED}[ERROR]${NC} $1"
}

log_warn() {
  echo -e "${YELLOW}[WARN]${NC} $1"
}

# Create output directories
mkdir -p "$OUTPUT_DIR"
mkdir -p "$SCREENSHOT_DIR"

# Test tag for smoke tests
SMOKE_TAG="@smoke"

# Flutter test command builder
build_test_command() {
  local platform=$1
  local cmd="flutter test"

  case $platform in
    android)
      cmd="$cmd --device-id=android"
      cmd="$cmd integration_test/ -t $SMOKE_TAG"
      ;;
    ios)
      cmd="$cmd --device-id=ios"
      cmd="$cmd integration_test/ -t $SMOKE_TAG"
      ;;
    web)
      cmd="$cmd --platform chrome"
      cmd="$cmd integration_test/ -t $SMOKE_TAG"
      ;;
    *)
      log_error "Unknown platform: $platform"
      exit 1
      ;;
  esac

  if [ "$COVERAGE" = true ]; then
    cmd="$cmd --coverage"
  fi

  if [ "$VERBOSE" = true ]; then
    cmd="$cmd --verbose"
  fi

  echo "$cmd"
}

# Run tests for a platform
run_platform_tests() {
  local platform=$1
  log_info "Running smoke tests for platform: $platform"

  cd dual_reader

  # Ensure dependencies are installed
  flutter pub get

  # Build test command
  local test_cmd=$(build_test_command "$platform")

  # Run tests with timeout
  local start_time=$(date +%s)
  local timeout=300  # 5 minutes

  # Set up result file
  local result_file="../$OUTPUT_DIR/smoke_$platform.json"

  if timeout $timeout bash -c "$test_cmd" 2>&1 | tee "../$OUTPUT_DIR/smoke_$platform.log"; then
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))

    log_info "Smoke tests passed for $platform (${duration}s)"

    # Write result JSON
    cat > "$result_file" << EOF
{
  "platform": "$platform",
  "suite": "smoke",
  "status": "passed",
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "duration": $duration,
  "tests": []
}
EOF
  else
    local exit_code=$?
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))

    log_error "Smoke tests failed for $platform (exit code: $exit_code, ${duration}s)"

    # Write result JSON
    cat > "$result_file" << EOF
{
  "platform": "$platform",
  "suite": "smoke",
  "status": "failed",
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "duration": $duration,
  "exit_code": $exit_code
}
EOF

    return 1
  fi

  cd ..
}

# Main execution
log_info "Starting smoke tests..."
log_info "Platform: $PLATFORM"
log_info "Device: $DEVICE"
log_info "Coverage: $COVERAGE"

if [ "$PLATFORM" = "all" ]; then
  platforms=("android" "ios" "web")
else
  platforms=("$PLATFORM")
fi

failed_platforms=()

for platform in "${platforms[@]}"; do
  if ! run_platform_tests "$platform"; then
    failed_platforms+=("$platform")
  fi
done

# Summary
log_info "Smoke tests completed"
log_info "Results directory: $OUTPUT_DIR"

if [ ${#failed_platforms[@]} -gt 0 ]; then
  log_error "Failed platforms: ${failed_platforms[*]}"
  exit 1
else
  log_info "All smoke tests passed!"
  exit 0
fi
