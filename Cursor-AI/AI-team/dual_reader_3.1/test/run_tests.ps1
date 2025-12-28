# Dual Reader 3.1 - Test Execution Script
# Tester: AI Dev Team

param(
    [string]$TestType = "all",
    [switch]$Coverage = $false,
    [switch]$Verbose = $false,
    [string]$Platform = ""
)

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Dual Reader 3.1 - Test Suite Runner" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$coverageFlag = if ($Coverage) { "--coverage" } else { "" }
$verboseFlag = if ($Verbose) { "--verbose" } else { "" }
$platformFlag = if ($Platform) { "--platform $Platform" } else { "" }

switch ($TestType.ToLower()) {
    "all" {
        Write-Host "Running ALL tests..." -ForegroundColor Yellow
        $command = "flutter test $coverageFlag $verboseFlag $platformFlag"
    }
    "unit" {
        Write-Host "Running UNIT tests..." -ForegroundColor Yellow
        $command = "flutter test test/models test/services test/providers test/utils $coverageFlag $verboseFlag $platformFlag"
    }
    "widget" {
        Write-Host "Running WIDGET tests..." -ForegroundColor Yellow
        $command = "flutter test test/widgets test/screens $coverageFlag $verboseFlag $platformFlag"
    }
    "integration" {
        Write-Host "Running INTEGRATION tests..." -ForegroundColor Yellow
        $command = "flutter test test/integration $coverageFlag $verboseFlag $platformFlag"
    }
    "models" {
        Write-Host "Running MODEL tests..." -ForegroundColor Yellow
        $command = "flutter test test/models $coverageFlag $verboseFlag $platformFlag"
    }
    "services" {
        Write-Host "Running SERVICE tests..." -ForegroundColor Yellow
        $command = "flutter test test/services $coverageFlag $verboseFlag $platformFlag"
    }
    "providers" {
        Write-Host "Running PROVIDER tests..." -ForegroundColor Yellow
        $command = "flutter test test/providers $coverageFlag $verboseFlag $platformFlag"
    }
    "widgets" {
        Write-Host "Running WIDGET tests..." -ForegroundColor Yellow
        $command = "flutter test test/widgets $coverageFlag $verboseFlag $platformFlag"
    }
    default {
        Write-Host "Unknown test type: $TestType" -ForegroundColor Red
        Write-Host "Available types: all, unit, widget, integration, models, services, providers, widgets" -ForegroundColor Yellow
        exit 1
    }
}

Write-Host ""
Write-Host "Command: $command" -ForegroundColor Gray
Write-Host ""

try {
    Invoke-Expression $command
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host ""
        Write-Host "========================================" -ForegroundColor Green
        Write-Host "Tests completed successfully!" -ForegroundColor Green
        Write-Host "========================================" -ForegroundColor Green
        
        if ($Coverage) {
            Write-Host ""
            Write-Host "Coverage report generated in: coverage/lcov.info" -ForegroundColor Cyan
            Write-Host "To view HTML report, run: genhtml coverage/lcov.info -o coverage/html" -ForegroundColor Cyan
        }
    } else {
        Write-Host ""
        Write-Host "========================================" -ForegroundColor Red
        Write-Host "Tests failed with exit code: $LASTEXITCODE" -ForegroundColor Red
        Write-Host "========================================" -ForegroundColor Red
        exit $LASTEXITCODE
    }
} catch {
    Write-Host ""
    Write-Host "Error running tests: $_" -ForegroundColor Red
    exit 1
}
