# PowerShell script to verify Web Platform Settings configuration
# Checks all PWA and web configuration requirements

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "Web Platform Settings Verification" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""

$checks = @()
$passed = 0
$failed = 0

# Check 1: manifest.json exists and is valid
Write-Host "Checking manifest.json..." -ForegroundColor Yellow
$manifestPath = "web\manifest.json"
if (Test-Path $manifestPath) {
    try {
        $manifestContent = Get-Content $manifestPath -Raw
        $manifest = $manifestContent | ConvertFrom-Json
        
        $requiredFields = @("name", "short_name", "start_url", "display", "icons", "theme_color", "background_color")
        $missingFields = $requiredFields | Where-Object { -not $manifest.PSObject.Properties.Name.Contains($_) }
        
        if ($missingFields.Count -eq 0) {
            if ($manifest.icons -and $manifest.icons.Count -gt 0) {
                Write-Host "  ✓ manifest.json is valid" -ForegroundColor Green
                $checks += @{Name="manifest.json is valid"; Passed=$true}
                $passed++
            } else {
                Write-Host "  ✗ manifest.json has no icons" -ForegroundColor Red
                $checks += @{Name="manifest.json has icons"; Passed=$false}
                $failed++
            }
        } else {
            Write-Host "  ✗ manifest.json missing fields: $($missingFields -join ', ')" -ForegroundColor Red
            $checks += @{Name="manifest.json has required fields"; Passed=$false}
            $failed++
        }
    } catch {
        Write-Host "  ✗ manifest.json is not valid JSON: $_" -ForegroundColor Red
        $checks += @{Name="manifest.json is valid JSON"; Passed=$false}
        $failed++
    }
} else {
    Write-Host "  ✗ manifest.json not found" -ForegroundColor Red
    $checks += @{Name="manifest.json exists"; Passed=$false}
    $failed++
}

# Check 2: index.html exists and has required elements
Write-Host "Checking index.html..." -ForegroundColor Yellow
$indexPath = "web\index.html"
if (Test-Path $indexPath) {
    $indexContent = Get-Content $indexPath -Raw
    
    $requiredElements = @(
        @{Pattern='rel="manifest"'; Name="manifest link"},
        @{Pattern='name="viewport"'; Name="viewport meta tag"},
        @{Pattern='name="theme-color"'; Name="theme-color meta tag"},
        @{Pattern='flutter.js'; Name="Flutter service worker script"}
    )
    
    $allPresent = $true
    foreach ($element in $requiredElements) {
        if ($indexContent -notmatch $element.Pattern) {
            Write-Host "  ✗ Missing: $($element.Name)" -ForegroundColor Red
            $allPresent = $false
        }
    }
    
    if ($allPresent) {
        Write-Host "  ✓ index.html is properly configured" -ForegroundColor Green
        $checks += @{Name="index.html is properly configured"; Passed=$true}
        $passed++
    } else {
        $checks += @{Name="index.html has required elements"; Passed=$false}
        $failed++
    }
} else {
    Write-Host "  ✗ index.html not found" -ForegroundColor Red
    $checks += @{Name="index.html exists"; Passed=$false}
    $failed++
}

# Check 3: Service worker configuration
Write-Host "Checking service worker configuration..." -ForegroundColor Yellow
if (Test-Path $indexPath) {
    $indexContent = Get-Content $indexPath -Raw
    
    if ($indexContent -match 'serviceWorker|flutter_service_worker') {
        Write-Host "  ✓ Service worker is configured" -ForegroundColor Green
        $checks += @{Name="Service worker is configured"; Passed=$true}
        $passed++
    } else {
        Write-Host "  ✗ Service worker registration not found" -ForegroundColor Red
        $checks += @{Name="Service worker configured"; Passed=$false}
        $failed++
    }
} else {
    $checks += @{Name="Service worker configured"; Passed=$false}
    $failed++
}

# Check 4: Responsive meta tags
Write-Host "Checking responsive meta tags..." -ForegroundColor Yellow
if (Test-Path $indexPath) {
    $indexContent = Get-Content $indexPath -Raw
    
    $requiredTags = @(
        'name="viewport"',
        'name="HandheldFriendly"',
        'name="MobileOptimized"',
        'name="apple-mobile-web-app-capable"'
    )
    
    $missingTags = $requiredTags | Where-Object { $indexContent -notmatch $_ }
    
    if ($missingTags.Count -eq 0) {
        Write-Host "  ✓ Responsive meta tags are present" -ForegroundColor Green
        $checks += @{Name="Responsive meta tags are present"; Passed=$true}
        $passed++
    } else {
        Write-Host "  ✗ Missing responsive tags: $($missingTags -join ', ')" -ForegroundColor Red
        $checks += @{Name="Responsive meta tags present"; Passed=$false}
        $failed++
    }
} else {
    $checks += @{Name="Responsive meta tags"; Passed=$false}
    $failed++
}

# Check 5: PWA installability
Write-Host "Checking PWA installability features..." -ForegroundColor Yellow
if (Test-Path $indexPath) {
    $indexContent = Get-Content $indexPath -Raw
    
    if ($indexContent -match 'beforeinstallprompt' -and $indexContent -match 'appinstalled') {
        Write-Host "  ✓ PWA installability features are configured" -ForegroundColor Green
        $checks += @{Name="PWA installability features are configured"; Passed=$true}
        $passed++
    } else {
        Write-Host "  ✗ Missing PWA installability handlers" -ForegroundColor Red
        $checks += @{Name="PWA installability features"; Passed=$false}
        $failed++
    }
} else {
    $checks += @{Name="PWA installability"; Passed=$false}
    $failed++
}

# Check 6: Browser config
Write-Host "Checking browserconfig.xml..." -ForegroundColor Yellow
$browserConfigPath = "web\browserconfig.xml"
if (Test-Path $browserConfigPath) {
    $browserConfigContent = Get-Content $browserConfigPath -Raw
    if ($browserConfigContent -match 'msapplication') {
        Write-Host "  ✓ browserconfig.xml is configured" -ForegroundColor Green
        $checks += @{Name="browserconfig.xml is configured"; Passed=$true}
        $passed++
    } else {
        Write-Host "  ✗ browserconfig.xml missing msapplication config" -ForegroundColor Red
        $checks += @{Name="browserconfig.xml is valid"; Passed=$false}
        $failed++
    }
} else {
    Write-Host "  ⚠ browserconfig.xml not found (optional)" -ForegroundColor Yellow
    $checks += @{Name="browserconfig.xml exists"; Passed=$false; Optional=$true}
}

# Print summary
Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "Verification Summary" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan

foreach ($check in $checks) {
    if ($check.Passed) {
        Write-Host "✓ PASS" -ForegroundColor Green -NoNewline
    } else {
        if ($check.Optional) {
            Write-Host "⚠ OPTIONAL" -ForegroundColor Yellow -NoNewline
        } else {
            Write-Host "✗ FAIL" -ForegroundColor Red -NoNewline
        }
    }
    Write-Host " $($check.Name)"
}

Write-Host ""
Write-Host "Total: $($checks.Count) checks" -ForegroundColor White
Write-Host "Passed: $passed" -ForegroundColor Green
Write-Host "Failed: $failed" -ForegroundColor $(if ($failed -eq 0) { "Green" } else { "Red" })
Write-Host ""

if ($failed -eq 0) {
    Write-Host "✓ All checks passed! Web platform is properly configured." -ForegroundColor Green
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor Cyan
    Write-Host "  1. Run: flutter build web" -ForegroundColor White
    Write-Host "  2. Test in browser: flutter run -d chrome" -ForegroundColor White
    Write-Host "  3. Verify PWA installability in Chrome DevTools" -ForegroundColor White
    exit 0
} else {
    Write-Host "✗ Some checks failed. Please review the issues above." -ForegroundColor Red
    exit 1
}
