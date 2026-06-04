#!/bin/bash
# Full Suite Test Runner
#
# Runs the complete test suite including edge cases and performance tests.
# These tests run nightly and may take up to 60 minutes.

set -e

# Default values
PLATFORM="all"
INCLUDE_EDGE_CASES=true
INCLUDE_PERFORMANCE=true
TIMEOUT=60
COVERAGE=true
VERBOSE=false
OUTPUT_DIR="dual_reader/test_results"
SCREENSHOT_DIR="dual_reader/test_screenshots"
PERFORMANCE_DIR="dual_reader/performance_results"

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --platform)
      PLATFORM="$2"
      shift 2
      ;;
    --include-edge-cases)
      INCLUDE_EDGE_CASES=true
      shift
      ;;
    --exclude-edge-cases)
      INCLUDE_EDGE_CASES=false
      shift
      ;;
    --include-performance)
      INCLUDE_PERFORMANCE=true
      shift
      ;;
    --exclude-performance)
      INCLUDE_PERFORMANCE=false
      shift
      ;;
    --timeout)
      TIMEOUT="$2"
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
    --help)
      echo "Usage: $0 [OPTIONS]"
      echo ""
      echo "Options:"
      echo "  --platform PLATFORM            Platform to test: android, ios, web, all (default: all)"
      echo "  --include-edge-cases           Include edge case tests (default: true)"
      echo "  --exclude-edge-cases           Skip edge case tests"
      echo "  --include-performance          Include performance tests (default: true)"
      echo "  --exclude-performance          Skip performance tests"
      echo "  --timeout MINUTES              Maximum test duration in minutes (default: 60)"
      echo "  --coverage                     Generate coverage report (default: true)"
      echo "  --no-coverage                  Skip coverage generation"
      echo "  --verbose                      Enable verbose output"
      echo "  --output-dir DIR               Test results output directory"
      echo ""
      echo "Full suite includes:"
      echo "  - All regression tests"
      echo "  - Edge case tests"
      echo "  - Large book tests"
      echo "  - Performance benchmarks"
      echo "  - Memory leak tests"
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
MAGENTA='\033[0;35m'
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

log_phase() {
  echo -e "${MAGENTA}[PHASE]${NC} $1"
}

# Create output directories
mkdir -p "$OUTPUT_DIR"
mkdir -p "$SCREENSHOT_DIR"
mkdir -p "$PERFORMANCE_DIR"

# Test phases
PHASES=()

# Always run regression tests
PHASES+=("regression")

# Add edge cases if enabled
if [ "$INCLUDE_EDGE_CASES" = true ]; then
  PHASES+=("edge-cases")
fi

# Add performance if enabled
if [ "$INCLUDE_PERFORMANCE" = true ]; then
  PHASES+=("performance")
fi

# Convert timeout to seconds
TIMEOUT_SECONDS=$((TIMEOUT * 60))

# Start time for full suite
FULL_SUITE_START=$(date +%s)

# Run a test phase
run_phase() {
  local phase=$1
  local platform=$2
  local phase_start=$(date +%s)

  log_phase "Running phase: $phase for $platform"

  cd dual_reader

  case $phase in
    regression)
      # Run regression tests
      bash ../scripts/run_regression_tests.sh \
        --platform "$platform" \
        --output-dir "../$OUTPUT_DIR" \
        ${COVERAGE:+--coverage}
      ;;
    edge-cases)
      # Run edge case tests
      log_info "Running edge case tests..."
      flutter test integration_test/features/parsing/edge_cases_test.dart \
        -t edge-case \
        --timeout $TIMEOUT_SECONDS \
        2>&1 | tee "../$OUTPUT_DIR/edge_cases_$platform.log"
      ;;
    performance)
      # Run performance tests
      log_info "Running performance benchmarks..."
      bash ../scripts/run_performance_benchmarks.sh \
        --platform "$platform" \
        --output-dir "../$PERFORMANCE_DIR"
      ;;
  esac

  local phase_end=$(date +%s)
  local phase_duration=$((phase_end - phase_start))

  log_info "Phase $phase completed in ${phase_duration}s"

  cd ..
}

# Run all phases for a platform
run_platform_tests() {
  local platform=$1
  log_section "Running full suite for platform: $platform"

  local platform_start=$(date +%s)
  local platform_output_dir="$OUTPUT_DIR/$platform"
  mkdir -p "$platform_output_dir"

  # Track phase results
  local phase_results=()

  for phase in "${PHASES[@]}"; do
    local phase_start=$(date +%s)

    if run_phase "$phase" "$platform"; then
      phase_results+=("$phase:passed")
    else
      phase_results+=("$phase:failed")
    fi

    local phase_end=$(date +%s)
    local phase_duration=$((phase_end - phase_start))
    local elapsed=$((phase_end - platform_start))

    # Check timeout
    if [ $elapsed -gt $TIMEOUT_SECONDS ]; then
      log_warn "Timeout approaching for $platform (${elapsed}s / ${TIMEOUT_SECONDS}s)"
    fi
  done

  local platform_end=$(date +%s)
  local platform_duration=$((platform_end - platform_start))

  # Write platform summary
  cat > "$platform_output_dir/full_suite_summary.json" << EOF
{
  "platform": "$platform",
  "suite": "full",
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "duration": $platform_duration,
  "phases": [
$(printf '    {"phase":"%s","status":"%s"},\n' ${phase_results[@]} | sed '$ s/,$//')
  ]
}
EOF

  log_info "Full suite for $platform completed in ${platform_duration}s"
}

# Run memory leak detection
run_memory_tests() {
  log_phase "Running memory leak tests..."

  cd dual_reader

  # Run memory profiling tests
  flutter test test/memory_leak_test.dart \
    --timeout=600 \
    2>&1 | tee "../$OUTPUT_DIR/memory_tests.log"

  cd ..
}

# Main execution
log_info "Starting full test suite..."
log_info "Platform: $PLATFORM"
log_info "Phases: ${PHASES[*]}"
log_info "Timeout: ${TIMEOUT} minutes"
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

# Run memory tests (platform-independent)
if [ "$INCLUDE_EDGE_CASES" = true ]; then
  run_memory_tests || true
fi

# Generate final summary
FULL_SUITE_END=$(date +%s)
FULL_SUITE_DURATION=$((FULL_SUITE_END - FULL_SUITE_START))

log_section "Full suite completed in $((FULL_SUITE_DURATION / 60)) minutes"
log_info "Results directory: $OUTPUT_DIR"

# Write final summary
cat > "$OUTPUT_DIR/full_suite_summary.json" << EOF
{
  "suite": "full",
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "duration_seconds": $FULL_SUITE_DURATION,
  "platforms": {
    "android": $(if [[ " ${failed_platforms[@]} " =~ " android " ]]; then echo '"failed"'; else echo '"passed"'; fi),
    "ios": $(if [[ " ${failed_platforms[@]} " =~ " ios " ]]; then echo '"failed"'; else echo '"passed"'; fi),
    "web": $(if [[ " ${failed_platforms[@]} " =~ " web " ]]; then echo '"failed"'; else echo '"passed"'; fi)
  }
}
EOF

if [ ${#failed_platforms[@]} -gt 0 ]; then
  log_error "Failed platforms: ${failed_platforms[*]}"
  exit 1
else
  log_info "All full suite tests passed!"
  exit 0
fi
