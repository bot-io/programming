# Regression Testing and CI/CD Pipeline

This document describes the automated testing infrastructure for the Dual Reader project.

## Overview

The CI/CD pipeline is organized into three test tiers:

| Tier | Duration | Trigger | Purpose |
|------|----------|---------|---------|
| **Smoke Tests** | ~5 min | Every PR | Verify critical path functionality |
| **Regression Tests** | ~20 min | Every PR | Comprehensive feature testing |
| **Full Suite** | ~60 min | Nightly | All tests including edge cases and performance |

## GitHub Actions Workflows

### Smoke Tests (`.github/workflows/smoke_tests.yml`)

Runs critical path tests on every pull request and push to main/develop.

**Triggers:**
- Pull requests to main/develop
- Pushes to main/develop
- Manual workflow dispatch

**Test Coverage:**
- App launches successfully
- Can import a book
- Can open and read a book
- Can navigate pages
- Can translate a page
- Can change settings

**Platforms:**
- Android (emulator)
- iOS (simulator)
- Web (Chrome)

### Regression Tests (`.github/workflows/regression_tests.yml`)

Runs all feature tests on every pull request and push to main/develop.

**Triggers:**
- Pull requests to main/develop
- Pushes to main/develop
- Manual workflow dispatch

**Test Coverage:**
- Library management features
- Translation features
- Reading experience features
- Settings features
- Offline functionality
- Book parsing and formats

**Sharding:**
Tests are split into 4 shards per platform for parallel execution.

**Gatekeeping:**
- Blocks merge on test failure
- Can be bypassed with `tests-bypass` label (requires documentation)

### Nightly Tests (`.github/workflows/nightly_tests.yml`)

Runs comprehensive test suite on a nightly schedule.

**Triggers:**
- Scheduled: Daily at 2 AM UTC
- Manual workflow dispatch

**Test Coverage:**
- All regression tests
- Edge case tests
- Large book tests (1000+ pages)
- Performance benchmarks
- Memory leak tests

**Features:**
- Trend analysis (detects flaky tests)
- Creates issues on failures
- Updates test trend data

### Performance Benchmarks (`.github/workflows/performance_benchmarks.yml`)

Runs performance benchmarks on code changes affecting test files.

**Triggers:**
- Pull requests modifying Dart files
- Pushes to main/develop modifying Dart files

**Metrics Tracked:**
- App startup time
- Page load time
- Translation time
- Pagination time
- Memory usage

**Features:**
- Compares with baseline metrics
- Detects regressions (>15% slower)
- Updates trending data
- Comments PR with results

## Test Scripts

### `run_smoke_tests.sh`

Runs critical path smoke tests.

```bash
# Run on all platforms
./scripts/run_smoke_tests.sh

# Run on specific platform
./scripts/run_smoke_tests.sh --platform android

# With coverage
./scripts/run_smoke_tests.sh --coverage

# Verbose output
./scripts/run_smoke_tests.sh --verbose
```

**Test Tag:** `@smoke`

### `run_regression_tests.sh`

Runs comprehensive regression tests.

```bash
# Run on all platforms
./scripts/run_regression_tests.sh

# Run specific shard
./scripts/run_regression_tests.sh --shard 0 --total-shards 4

# Skip coverage
./scripts/run_regression_tests.sh --no-coverage

# Custom tags
./scripts/run_regression_tests.sh --tags "regression,translation"
```

**Test Tag:** `@regression`

### `run_full_suite.sh`

Runs complete test suite with edge cases and performance tests.

```bash
# Run full suite
./scripts/run_full_suite.sh

# Exclude edge cases
./scripts/run_full_suite.sh --exclude-edge-cases

# Set timeout (minutes)
./scripts/run_full_suite.sh --timeout 90
```

**Test Tags:** `@regression`, `@edge-case`, `@performance`

### `generate_test_report.sh`

Generates HTML test reports from test results.

```bash
# Generate report
./scripts/generate_test_report.sh \
  --name "Smoke Tests" \
  --results-dir results/ \
  --output report.html
```

## Test Organization

### Test Tags

Tests are categorized using tags:

| Tag | Description | When Run |
|-----|-------------|----------|
| `@smoke` | Critical path tests | Every PR |
| `@regression` | All feature tests | Every PR |
| `@edge-case` | Edge cases and large books | Nightly |
| `@performance` | Performance benchmarks | Nightly/PR changes |
| `@android` | Android-specific tests | Android runs |
| `@ios` | iOS-specific tests | iOS runs |
| `@web` | Web-specific tests | Web runs |

### Test Categories

Tests are organized by feature:

```
integration_test/features/
├── library/
│   ├── library_import_test.dart
│   ├── library_display_test.dart
│   └── library_management_test.dart
├── translation/
│   ├── mobile_translation_test.dart
│   ├── web_translation_test.dart
│   ├── translation_cache_test.dart
│   └── language_detection_test.dart
├── reading/
│   ├── dual_panel_test.dart
│   ├── pagination_test.dart
│   └── touch_controls_test.dart
├── settings/
│   ├── theme_test.dart
│   ├── font_settings_test.dart
│   └── layout_settings_test.dart
├── offline/
│   ├── offline_reading_test.dart
│   ├── offline_translation_test.dart
│   └── network_transition_test.dart
└── parsing/
    ├── epub_parsing_test.dart
    ├── mobi_parsing_test.dart
    └── edge_cases_test.dart
```

## Test Reporting

### Result Artifacts

Each workflow produces:

1. **Test Results** (JSON format)
   - Pass/fail status
   - Test counts
   - Duration
   - Platform breakdown

2. **Screenshots** (on failure)
   - Captured at failure point
   - Stored for 7 days

3. **Coverage Reports** (LCOV format)
   - Line coverage
   - Branch coverage
   - Uploaded to Codecov

4. **HTML Report**
   - Visual summary
   - Platform breakdown
   - Trend analysis

### Notifications

**Pull Request Comments:**
- Smoke test results (pass/fail per platform)
- Regression test results (summary)
- Performance benchmark comparison

**Issues Created:**
- Nightly test failures (if any)
- Performance regressions (>15% slower)
- Flaky test detection alerts

## Flaky Test Management

### Detection

Flaky tests are detected by:
1. Comparing results across multiple runs
2. Identifying inconsistent pass/fail patterns
3. Analyzing timing-related failures

### Handling

Flaky tests are:
1. Logged to `flaky_tests.json`
2. Quarantined (skipped in normal runs)
3. Reported as issues for investigation

### Retry Mechanism

Tests are automatically retried on failure:
- First attempt
- Retry after 5 seconds
- Final attempt after 10 seconds

## Performance Baselines

### Baseline Files

Performance baselines are stored in `.github/baselines/`:

```
.github/baselines/
├── android-performance.json
├── ios-performance.json
└── web-performance.json
```

### Thresholds

Performance regressions are flagged when:
- Metric degraded by >10% (PR checks)
- Metric degraded by >15% (blocks merge)
- Consistent degradation over 3 runs

### Trending

Performance trends are tracked in `.github/trends/`:
- Historical data
- Regression detection
- Improvement tracking

## Local Testing

### Run Smoke Tests Locally

```bash
cd dual_reader
flutter test integration_test/ -t @smoke
```

### Run All Tests Locally

```bash
cd dual_reader
flutter test integration_test/
```

### Run Specific Category

```bash
cd dual_reader
flutter test integration_test/features/library/
```

### Generate Coverage

```bash
cd dual_reader
flutter test --coverage
genhtml coverage/lcov.info -o coverage/html
```

## CI/CD Best Practices

### For Developers

1. **Always run smoke tests before pushing**
   ```bash
   ./scripts/run_smoke_tests.sh
   ```

2. **Check test results on PR**
   - Smoke tests should pass within 10 minutes
   - Regression tests should pass within 30 minutes

3. **Investigate failures promptly**
   - Check logs in workflow run
   - View screenshots if available
   - Run tests locally to reproduce

4. **Update baselines when appropriate**
   - After performance improvements
   - After feature additions
   - Document reason for change

### For Reviewers

1. **Don't merge with failing tests**
   - Unless `tests-bypass` label is applied
   - Bypass requires explanation in PR

2. **Check performance impact**
   - Look for benchmark comments
   - Verify regressions are intentional
   - Ask for investigation if not

3. **Monitor flaky tests**
   - Flaky tests should be fixed, not ignored
   - Create issues for persistent flakiness

## Troubleshooting

### Common Issues

**Tests timeout:**
- Increase timeout in workflow
- Check for resource leaks
- Investigate slow operations

**Platform-specific failures:**
- Check SDK version
- Verify dependencies
- Test on local device/emulator

**Flaky tests:**
- Add retry logic
- Investigate timing dependencies
- Stabilize test environment

**Performance regression:**
- Verify baseline is current
- Check for code changes
- Profile to identify bottleneck
