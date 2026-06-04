#!/bin/bash
# Regression Test Runner
#
# Runs comprehensive regression tests covering all features.
# These tests run on every PR and should complete within 20 minutes.

set -e

# Default values
PLATFORM="all"
DEVICE="emulator"
COVERAGE=true
VERBOSE=false
SHARD=0
TOTAL_SHARDS=1
OUTPUT_DIR="dual_reader/test_results"
SCREENSHOT_DIR="dual_reader/test_screenshots"
TAGS="regression"

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
    --shard)
      SHARD="$2"
      shift 2
      ;;
    --total-shards)
      TOTAL_SHARDS="$2"
      shift 2
      ;;
    --coverage)
      COVERAGE=true
      shift
      ;;
    --no-coverage)
      COVERAGE=false
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
    --tags)
      TAGS="$2"
      shift 2
      ;;
    --help)
      echo "Usage: $0 [OPTIONS]"
      echo ""
      echo "Options:"
      echo "  --platform PLATFORM      Platform to test: android, ios, web, all (default: all)"
      echo "  --device DEVICE          Device type: emulator, simulator, browser, device"
      echo "  --shard NUM             Shard index (0-based)"
      echo "  --total-shards NUM      Total number of shards"
      echo "  --coverage              Generate coverage report (default: true)"
      echo "  --no-coverage           Skip coverage generation"
      echo "  --verbose               Enable verbose output"
      echo "  --output-dir DIR        Test results output directory"
      echo "  --tags TAGS             Test tags to run (default: regression)"
      echo ""
      echo "Regression tests cover:"
      echo "  - All library management features"
      echo "  - All translation features"
      echo "  - All reading experience features"
      echo "  - All settings features"
      echo "  - Offline functionality"
      echo "  - Book parsing and formats"
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
  echo -e "${GREEN}[INFO]${NC} $1"
}

log_error() {
  echo -e "${RED}[ERROR]${NC} $1"
}

log_warn() {
  echo -e "${YELLOW}[WARN]${NC} $1"
}

log_section() {
  echo -e "${BLUE}[SECTION]${NC} $1"
}

# Create output directories
mkdir -p "$OUTPUT_DIR"
mkdir -p "$SCREENSHOT_DIR"

# Test categories
TEST_CATEGORIES=(
  "library"
  "translation"
  "reading"
  "settings"
  "offline"
  "parsing"
)

# Calculate which categories to run for this shard
calculate_shard_categories() {
  local shard=$1
  local total=$2
  local total_cats=${#TEST_CATEGORIES[@]]

  # Calculate start and end indices for this shard
  local cats_per_shard=$((total_cats / total))
  local remainder=$((total_cats % total))
  local start=$((shard * cats_per_shard + (shard < remainder ? shard : remainder)))
  local end=$((start + cats_per_shard + (shard < remainder ? 1 : 0)))

  echo "${TEST_CATEGORIES[@]:$start:$((end - start))}"
}

# Build test command
build_test_command() {
  local platform=$1
  local categories=$2
  local cmd="flutter test"

  case $platform in
    android)
      cmd="$cmd --device-id=android"
      ;;
    ios)
      cmd="$cmd --device-id=ios"
      ;;
    web)
      cmd="$cmd --platform chrome"
      ;;
    *)
      log_error "Unknown platform: $platform"
      exit 1
      ;;
  esac

  # Add test paths based on categories
  local test_paths=""
  for category in $categories; do
    case $category in
      library)
        test_paths="$test_paths integration_test/features/library/"
        ;;
      translation)
        test_paths="$test_paths integration_test/features/translation/"
        ;;
      reading)
        test_paths="$test_paths integration_test/features/reading/"
        ;;
      settings)
        test_paths="$test_paths integration_test/features/settings/"
        ;;
      offline)
        test_paths="$test_paths integration_test/features/offline/"
        ;;
      parsing)
        test_paths="$test_paths integration_test/features/parsing/"
        ;;
    esac
  done

  cmd="$cmd $test_paths"

  # Add tags filter
  cmd="$cmd -t $TAGS"

  # Add shard parameters
  if [ "$TOTAL_SHARDS" -gt 1 ]; then
    cmd="$cmd --shard-index=$SHARD --total-shards=$TOTAL_SHARDS"
  fi

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
  log_section "Running regression tests for platform: $platform"

  cd dual_reader

  # Ensure dependencies
  flutter pub get

  # Calculate categories for this shard
  local shard_categories=($(calculate_shard_categories $SHARD $TOTAL_SHARDS))
  log_info "Shard $((SHARD + 1))/$TOTAL_SHARDS - Categories: ${shard_categories[*]}"

  # Build and run test command
  local test_cmd=$(build_test_command "$platform" "${shard_categories[*]}")

  local start_time=$(date +%s)
  local timeout=1200  # 20 minutes
  local platform_output_dir="../$OUTPUT_DIR/$platform"

  mkdir -p "$platform_output_dir"

  if timeout $timeout bash -c "$test_cmd" 2>&1 | tee "$platform_output_dir/regression.log"; then
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))

    log_info "Regression tests passed for $platform (${duration}s)"

    # Process coverage if enabled
    if [ "$COVERAGE" = true ]; then
      log_info "Generating coverage report for $platform..."
      flutter test --coverage
      mkdir -p "../$platform_output_dir/coverage"
      cp coverage/lcov.info "../$platform_output_dir/coverage/"
    fi

    # Parse test results from log
    parse_test_results "$platform_output_dir/regression.log" "$platform_output_dir/summary.json"

    # Write result JSON
    cat > "$platform_output_dir/result.json" << EOF
{
  "platform": "$platform",
  "suite": "regression",
  "shard": $SHARD,
  "status": "passed",
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "duration": $duration,
  "categories": [$(printf '"%s",' "${shart_categories[@]}" | sed 's/,$//')]
}
EOF
  else
    local exit_code=$?
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))

    log_error "Regression tests failed for $platform (exit code: $exit_code, ${duration}s)"

    # Take screenshots on failure
    take_failure_screenshots "$platform" "$platform_output_dir"

    # Parse partial results
    parse_test_results "$platform_output_dir/regression.log" "$platform_output_dir/summary.json"

    # Write result JSON
    cat > "$platform_output_dir/result.json" << EOF
{
  "platform": "$platform",
  "suite": "regression",
  "shard": $SHARD,
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

# Parse test results from Flutter test output
parse_test_results() {
  local log_file="$1"
  local output_file="$2"

  local passed=0
  local failed=0
  local skipped=0

  # Parse results from log
  if [ -f "$log_file" ]; then
    passed=$(grep -oP '\d+(?= passed)' "$log_file" | head -1 || echo "0")
    failed=$(grep -oP '\d+(?= failed)' "$log_file" | head -1 || echo "0")
    skipped=$(grep -oP '\d+(?= skipped)' "$log_file" | head -1 || echo "0")
  fi

  # Write summary JSON
  cat > "$output_file" << EOF
{
  "passed": ${passed:-0},
  "failed": ${failed:-0},
  "skipped": ${skipped:-0},
  "total": $((passed + failed + skipped))
}
EOF
}

# Take screenshots on failure
take_failure_screenshots() {
  local platform=$1
  local output_dir=$2

  log_warn "Taking failure screenshots for $platform..."

  # In a real implementation, this would:
  # 1. Connect to device/emulator
  # 2. Take screenshots
  # 3. Save to output_dir/screenshots/
}

# Main execution
log_info "Starting regression tests..."
log_info "Platform: $PLATFORM"
log_info "Shard: $((SHARD + 1))/$TOTAL_SHARDS"
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
log_section "Regression tests completed"
log_info "Results directory: $OUTPUT_DIR"

if [ ${#failed_platforms[@]} -gt 0 ]; then
  log_error "Failed platforms: ${failed_platforms[*]}"
  exit 1
else
  log_info "All regression tests passed!"
  exit 0
fi
