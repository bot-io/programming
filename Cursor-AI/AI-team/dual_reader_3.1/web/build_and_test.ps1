# Build and Test Script for Dual Reader 3.1 Web
# This script builds the Flutter web app and provides testing instructions

Write-Host "🚀 Building Dual Reader 3.1 for Web..." -ForegroundColor Green
Write-Host ""

# Check if Flutter is available
try {
    $flutterVersion = flutter --version 2>&1 | Select-Object -First 1
    Write-Host "✓ Flutter found: $flutterVersion" -ForegroundColor Cyan
} catch {
    Write-Host "✗ Flutter not found. Please install Flutter first." -ForegroundColor Red
    Write-Host "  Download from: https://flutter.dev/docs/get-started/install" -ForegroundColor Yellow
    exit 1
}

# Check if we're in the right directory
if (-not (Test-Path "pubspec.yaml")) {
    Write-Host "✗ pubspec.yaml not found. Please run this script from the project root." -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "📦 Step 1: Getting dependencies..." -ForegroundColor Cyan
flutter pub get
if ($LASTEXITCODE -ne 0) {
    Write-Host "✗ Failed to get dependencies" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "🔨 Step 2: Building web app..." -ForegroundColor Cyan
flutter build web --release
if ($LASTEXITCODE -ne 0) {
    Write-Host "✗ Build failed" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "✅ Build completed successfully!" -ForegroundColor Green
Write-Host ""
Write-Host "📁 Build output: build/web/" -ForegroundColor Cyan
Write-Host ""
Write-Host "🧪 Testing Instructions:" -ForegroundColor Yellow
Write-Host ""
Write-Host "1. Serve the build locally:" -ForegroundColor White
Write-Host "   cd build/web" -ForegroundColor Gray
Write-Host "   python -m http.server 8000" -ForegroundColor Gray
Write-Host "   # Or use any static file server" -ForegroundColor Gray
Write-Host ""
Write-Host "2. Open in browser:" -ForegroundColor White
Write-Host "   http://localhost:8000" -ForegroundColor Gray
Write-Host ""
Write-Host "3. Test PWA features:" -ForegroundColor White
Write-Host "   - Open Chrome DevTools (F12)" -ForegroundColor Gray
Write-Host "   - Go to Application tab" -ForegroundColor Gray
Write-Host "   - Check Manifest, Service Workers, Cache Storage" -ForegroundColor Gray
Write-Host "   - Test offline mode (Network > Offline)" -ForegroundColor Gray
Write-Host "   - Look for install prompt" -ForegroundColor Gray
Write-Host ""
Write-Host "4. Run development server (for hot reload):" -ForegroundColor White
Write-Host "   flutter run -d chrome" -ForegroundColor Gray
Write-Host ""
Write-Host "📝 Note: Ensure icons are generated before testing PWA installability" -ForegroundColor Yellow
Write-Host "   Run: node web/verify_pwa_setup.js" -ForegroundColor Gray
Write-Host ""
