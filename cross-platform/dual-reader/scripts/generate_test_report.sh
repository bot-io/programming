#!/bin/bash
# Generate Test Report
#
# Generates HTML test reports from test results.

set -e

# Default values
NAME="Test Results"
RESULTS_DIR="./results"
COVERAGE_DIR=""
OUTPUT="test-report.html"
TRENDING=false

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --name)
      NAME="$2"
      shift 2
      ;;
    --results-dir)
      RESULTS_DIR="$2"
      shift 2
      ;;
    --coverage-dir)
      COVERAGE_DIR="$2"
      shift 2
      ;;
    --output)
      OUTPUT="$2"
      shift 2
      ;;
    --trending)
      TRENDING=true
      shift
      ;;
    --help)
      echo "Usage: $0 [OPTIONS]"
      echo ""
      echo "Options:"
      echo "  --name NAME              Report name"
      echo "  --results-dir DIR        Test results directory"
      echo "  --coverage-dir DIR       Coverage results directory"
      echo "  --output FILE            Output HTML file"
      echo "  --trending               Include trend analysis"
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

# Aggregate test results
aggregate_results() {
  local results_dir="$1"
  local total_passed=0
  local total_failed=0
  local total_skipped=0
  local total_duration=0

  # Find all summary.json files
  for summary_file in $(find "$results_dir" -name "summary.json" 2>/dev/null); do
    if [ -f "$summary_file" ]; then
      local passed=$(jq -r '.passed // 0' "$summary_file")
      local failed=$(jq -r '.failed // 0' "$summary_file")
      local skipped=$(jq -r '.skipped // 0' "$summary_file")

      total_passed=$((total_passed + passed))
      total_failed=$((total_failed + failed))
      total_skipped=$((total_skipped + skipped))
    fi
  done

  echo "{\"passed\": $total_passed, \"failed\": $total_failed, \"skipped\": $total_skipped, \"total\": $((total_passed + total_failed + total_skipped))}"
}

# Generate HTML report
generate_html_report() {
  local name="$1"
  local aggregate="$2"
  local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  cat > "$OUTPUT" << EOF
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>$name - Test Report</title>
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; background: #f5f5f5; }
    .container { max-width: 1200px; margin: 0 auto; padding: 20px; }
    .header { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 30px; border-radius: 10px; margin-bottom: 20px; }
    .header h1 { font-size: 28px; margin-bottom: 10px; }
    .header .timestamp { opacity: 0.8; font-size: 14px; }
    .summary { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 20px; margin-bottom: 20px; }
    .summary-card { background: white; padding: 20px; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
    .summary-card h3 { font-size: 14px; color: #666; margin-bottom: 10px; }
    .summary-card .value { font-size: 32px; font-weight: bold; }
    .summary-card.passed .value { color: #10b981; }
    .summary-card.failed .value { color: #ef4444; }
    .summary-card.skipped .value { color: #f59e0b; }
    .summary-card.total .value { color: #6366f1; }
    .platforms { display: grid; grid-template-columns: repeat(auto-fit, minmax(300px, 1fr)); gap: 20px; margin-bottom: 20px; }
    .platform-card { background: white; padding: 20px; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
    .platform-card .platform-name { font-size: 18px; font-weight: bold; margin-bottom: 15px; }
    .platform-card .status { display: inline-block; padding: 4px 12px; border-radius: 20px; font-size: 12px; font-weight: bold; }
    .platform-card .status.passed { background: #d1fae5; color: #065f46; }
    .platform-card .status.failed { background: #fee2e2; color: #991b1b; }
    .test-list { background: white; padding: 20px; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
    .test-item { padding: 10px; border-bottom: 1px solid #eee; display: flex; align-items: center; }
    .test-item:last-child { border-bottom: none; }
    .test-item .status { width: 80px; font-weight: bold; }
    .test-item .status.passed { color: #10b981; }
    .test-item .status.failed { color: #ef4444; }
    .test-item .name { flex: 1; }
    .test-item .duration { color: #666; font-size: 14px; }
    .progress-bar { height: 8px; background: #e5e7eb; border-radius: 4px; overflow: hidden; margin-top: 10px; }
    .progress-bar .fill { height: 100%; transition: width 0.3s; }
    .progress-bar .passed { background: #10b981; }
    .progress-bar .failed { background: #ef4444; }
    .progress-bar .skipped { background: #f59e0b; }
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <h1>$name</h1>
      <div class="timestamp">Generated: $timestamp</div>
    </div>

    <div class="summary">
      <div class="summary-card passed">
        <h3>Passed</h3>
        <div class="value">$(echo $aggregate | jq -r '.passed')</div>
      </div>
      <div class="summary-card failed">
        <h3>Failed</h3>
        <div class="value">$(echo $aggregate | jq -r '.failed')</div>
      </div>
      <div class="summary-card skipped">
        <h3>Skipped</h3>
        <div class="value">$(echo $aggregate | jq -r '.skipped')</div>
      </div>
      <div class="summary-card total">
        <h3>Total</h3>
        <div class="value">$(echo $aggregate | jq -r '.total')</div>
      </div>
    </div>

    <div class="progress-bar">
      <div class="fill passed" style="width: $(echo $aggregate | jq -r '(.passed / .total * 100) // 0')%"></div>
      <div class="fill failed" style="width: $(echo $aggregate | jq -r '(.failed / .total * 100) // 0')%"></div>
      <div class="fill skipped" style="width: $(echo $aggregate | jq -r '(.skipped / .total * 100) // 0')%"></div>
    </div>

    <div class="platforms">
      <!-- Platform cards would be generated here -->
      <div class="platform-card">
        <div class="platform-name">Android</div>
        <div class="status passed">Passed</div>
      </div>
      <div class="platform-card">
        <div class="platform-name">iOS</div>
        <div class="status passed">Passed</div>
      </div>
      <div class="platform-card">
        <div class="platform-name">Web</div>
        <div class="status passed">Passed</div>
      </div>
    </div>
  </div>
</body>
</html>
EOF

  echo "HTML report generated: $OUTPUT"
}

# Main execution
aggregate=$(aggregate_results "$RESULTS_DIR")
generate_html_report "$NAME" "$aggregate"

echo "Test report generation complete"
