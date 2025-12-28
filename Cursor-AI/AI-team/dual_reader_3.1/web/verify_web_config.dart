import 'dart:io';

/// Verification script for Web Platform Settings
/// Checks that all PWA requirements are met
void main() async {
  print('🔍 Verifying Web Platform Settings for Dual Reader 3.1...\n');

  final webDir = Directory('web');
  final iconsDir = Directory('web/icons');
  final manifestFile = File('web/manifest.json');
  final indexFile = File('web/index.html');
  final serviceWorkerFile = File('web/service-worker.js');
  final browserConfigFile = File('web/browserconfig.xml');

  bool allChecksPassed = true;

  // Check manifest.json
  print('📋 Checking manifest.json...');
  if (await manifestFile.exists()) {
    final manifestContent = await manifestFile.readAsString();
    final checks = {
      'name': manifestContent.contains('"name"'),
      'short_name': manifestContent.contains('"short_name"'),
      'start_url': manifestContent.contains('"start_url"'),
      'display': manifestContent.contains('"display"'),
      'icons': manifestContent.contains('"icons"'),
      'theme_color': manifestContent.contains('"theme_color"'),
      'background_color': manifestContent.contains('"background_color"'),
    };
    
    checks.forEach((key, value) {
      if (value) {
        print('  ✓ $key');
      } else {
        print('  ✗ Missing: $key');
        allChecksPassed = false;
      }
    });
  } else {
    print('  ✗ manifest.json not found');
    allChecksPassed = false;
  }

  // Check index.html
  print('\n📄 Checking index.html...');
  if (await indexFile.exists()) {
    final indexContent = await indexFile.readAsString();
    final checks = {
      'viewport meta tag': indexContent.contains('name="viewport"'),
      'theme-color meta tag': indexContent.contains('name="theme-color"'),
      'manifest link': indexContent.contains('rel="manifest"'),
      'apple-touch-icon': indexContent.contains('apple-touch-icon'),
      'service worker script': indexContent.contains('serviceWorker') || indexContent.contains('flutter.js'),
    };
    
    checks.forEach((key, value) {
      if (value) {
        print('  ✓ $key');
      } else {
        print('  ✗ Missing: $key');
        allChecksPassed = false;
      }
    });
  } else {
    print('  ✗ index.html not found');
    allChecksPassed = false;
  }

  // Check service worker
  print('\n⚙️  Checking service worker...');
  if (await serviceWorkerFile.exists()) {
    print('  ✓ service-worker.js exists');
    final swContent = await serviceWorkerFile.readAsString();
    if (swContent.contains('install') && swContent.contains('activate') && swContent.contains('fetch')) {
      print('  ✓ Service worker has install, activate, and fetch handlers');
    } else {
      print('  ⚠ Service worker may be incomplete');
    }
  } else {
    print('  ⚠ service-worker.js not found (Flutter will generate flutter_service_worker.js)');
  }

  // Check icons
  print('\n🖼️  Checking icons...');
  final requiredIcons = [16, 32, 72, 96, 128, 144, 152, 192, 384, 512];
  int iconsFound = 0;
  
  if (await iconsDir.exists()) {
    for (final size in requiredIcons) {
      final iconFile = File('web/icons/icon-${size}x${size}.png');
      if (await iconFile.exists()) {
        iconsFound++;
      }
    }
    print('  Found $iconsFound/${requiredIcons.length} required icons');
    
    if (iconsFound < requiredIcons.length) {
      print('  ⚠ Some icons are missing. Run icon generation script:');
      print('     - PowerShell: web/icons/create_placeholder_icons.ps1');
      print('     - Python: web/icons/create_placeholder_icons.py');
      print('     - HTML: Open web/icons/generate_icons_simple.html in browser');
      allChecksPassed = false;
    }
  } else {
    print('  ✗ icons directory not found');
    allChecksPassed = false;
  }

  // Check browserconfig.xml
  print('\n🌐 Checking browserconfig.xml...');
  if (await browserConfigFile.exists()) {
    print('  ✓ browserconfig.xml exists');
  } else {
    print('  ⚠ browserconfig.xml not found (optional for Windows tiles)');
  }

  // Summary
  print('\n' + '=' * 50);
  if (allChecksPassed) {
    print('✅ All critical checks passed!');
    print('\nYour web platform is configured for PWA deployment.');
  } else {
    print('⚠️  Some checks failed. Please review the issues above.');
    print('\nTo generate missing icons:');
    print('  1. PowerShell: web/icons/create_placeholder_icons.ps1');
    print('  2. Python: web/icons/create_placeholder_icons.py');
    print('  3. HTML: Open web/icons/generate_icons_simple.html in browser');
  }
  print('=' * 50);
}
