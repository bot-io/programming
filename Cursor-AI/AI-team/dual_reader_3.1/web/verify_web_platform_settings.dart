#!/usr/bin/env dart
///
/// Web Platform Settings Verification Script
/// 
/// This script verifies that all web platform settings are correctly configured
/// for PWA support, responsive design, and optimal web deployment.
///
/// Usage: dart run web/verify_web_platform_settings.dart
///

import 'dart:io';

void main() {
  print('🔍 Verifying Web Platform Settings for Dual Reader 3.1\n');
  
  final webDir = Directory('web');
  final iconsDir = Directory('web/icons');
  
  bool allChecksPassed = true;
  final List<String> warnings = [];
  final List<String> errors = [];
  
  // 1. Check manifest.json
  print('1. Checking manifest.json...');
  final manifestFile = File('web/manifest.json');
  if (manifestFile.existsSync()) {
    final manifestContent = manifestFile.readAsStringSync();
    if (manifestContent.contains('"name"') && 
        manifestContent.contains('"short_name"') &&
        manifestContent.contains('"start_url"') &&
        manifestContent.contains('"display"') &&
        manifestContent.contains('"icons"')) {
      print('   ✅ manifest.json exists and contains required fields');
    } else {
      errors.add('manifest.json is missing required fields');
      allChecksPassed = false;
    }
  } else {
    errors.add('manifest.json not found');
    allChecksPassed = false;
  }
  
  // 2. Check index.html
  print('\n2. Checking index.html...');
  final indexFile = File('web/index.html');
  if (indexFile.existsSync()) {
    final indexContent = indexFile.readAsStringSync();
    final checks = {
      'viewport meta tag': indexContent.contains('name="viewport"'),
      'manifest link': indexContent.contains('rel="manifest"'),
      'theme-color meta': indexContent.contains('name="theme-color"'),
      'service worker script': indexContent.contains('flutter.js') || 
                               indexContent.contains('serviceWorker'),
      'responsive meta tags': indexContent.contains('HandheldFriendly') ||
                             indexContent.contains('MobileOptimized'),
    };
    
    checks.forEach((check, passed) {
      if (passed) {
        print('   ✅ $check');
      } else {
        warnings.add('Missing: $check');
      }
    });
  } else {
    errors.add('index.html not found');
    allChecksPassed = false;
  }
  
  // 3. Check Flutter build config
  print('\n3. Checking Flutter build configuration...');
  final buildConfigFile = File('web/flutter_build_config.json');
  if (buildConfigFile.existsSync()) {
    final configContent = buildConfigFile.readAsStringSync();
    if (configContent.contains('"pwa"') && 
        configContent.contains('"enabled"')) {
      print('   ✅ flutter_build_config.json exists with PWA settings');
    } else {
      warnings.add('flutter_build_config.json may be missing PWA configuration');
    }
  } else {
    warnings.add('flutter_build_config.json not found (optional but recommended)');
  }
  
  // 4. Check service worker reference
  print('\n4. Checking service worker configuration...');
  print('   ℹ️  Flutter automatically generates flutter_service_worker.js during build');
  print('   ℹ️  Custom service-worker.js exists as reference implementation');
  
  final swFile = File('web/service-worker.js');
  if (swFile.existsSync()) {
    print('   ✅ service-worker.js reference file exists');
  } else {
    warnings.add('service-worker.js reference file not found');
  }
  
  // 5. Check icons
  print('\n5. Checking PWA icons...');
  final requiredIconSizes = [16, 32, 72, 96, 128, 144, 152, 192, 384, 512];
  int iconsFound = 0;
  
  for (final size in requiredIconSizes) {
    final iconFile = File('web/icons/icon-$size.png');
    if (iconFile.existsSync()) {
      iconsFound++;
    }
  }
  
  if (iconsFound == requiredIconSizes.length) {
    print('   ✅ All required icon sizes found ($iconsFound/${requiredIconSizes.length})');
  } else if (iconsFound > 0) {
    warnings.add('Only $iconsFound/${requiredIconSizes.length} icon sizes found');
    print('   ⚠️  Found $iconsFound/${requiredIconSizes.length} icon sizes');
    print('   ℹ️  Run: dart run web/icons/create_placeholder_icons.dart');
    print('   ℹ️  Or: powershell web/icons/create_placeholder_icons.ps1');
  } else {
    errors.add('No PWA icons found');
    print('   ❌ No icons found');
    print('   ℹ️  Generate icons using:');
    print('      - dart run web/icons/create_placeholder_icons.dart');
    print('      - powershell web/icons/create_placeholder_icons.ps1');
    print('      - python web/icons/create_placeholder_icons.py');
    allChecksPassed = false;
  }
  
  // 6. Check favicon
  print('\n6. Checking favicon...');
  final faviconPng = File('web/favicon.png');
  final faviconIco = File('web/favicon.ico');
  
  if (faviconPng.existsSync() || faviconIco.existsSync()) {
    print('   ✅ Favicon found');
  } else {
    warnings.add('Favicon not found (optional but recommended)');
    print('   ⚠️  Favicon not found');
  }
  
  // 7. Check deployment configs
  print('\n7. Checking deployment configurations...');
  final vercelConfig = File('web/vercel.json');
  final netlifyHeaders = File('web/_headers');
  
  if (vercelConfig.existsSync()) {
    print('   ✅ Vercel configuration found');
  }
  if (netlifyHeaders.existsSync()) {
    print('   ✅ Netlify headers configuration found');
  }
  
  // Summary
  print('\n' + '=' * 60);
  print('VERIFICATION SUMMARY');
  print('=' * 60);
  
  if (errors.isEmpty && warnings.isEmpty) {
    print('\n✅ All checks passed! Web platform settings are correctly configured.');
  } else {
    if (errors.isNotEmpty) {
      print('\n❌ ERRORS (must be fixed):');
      errors.forEach((error) => print('   - $error'));
      allChecksPassed = false;
    }
    
    if (warnings.isNotEmpty) {
      print('\n⚠️  WARNINGS (recommended to fix):');
      warnings.forEach((warning) => print('   - $warning'));
    }
  }
  
  print('\n' + '=' * 60);
  print('NEXT STEPS');
  print('=' * 60);
  
  if (!allChecksPassed || iconsFound < requiredIconSizes.length) {
    print('\n1. Generate PWA icons:');
    print('   dart run web/icons/create_placeholder_icons.dart');
    print('   OR');
    print('   powershell web/icons/create_placeholder_icons.ps1');
    print('\n2. Build the web app:');
    print('   flutter build web --release');
    print('\n3. Verify the build output:');
    print('   - Check that build/web/flutter_service_worker.js exists');
    print('   - Check that build/web/manifest.json exists');
    print('   - Check that build/web/icons/ contains all icon files');
  } else {
    print('\n✅ Configuration is complete!');
    print('\nTo build and test:');
    print('1. Build: flutter build web --release');
    print('2. Test locally: flutter run -d chrome --web-port=8080');
    print('3. Deploy: Upload build/web/ to your hosting provider');
  }
  
  print('\n📚 Documentation:');
  print('   - web/README.md');
  print('   - web/QUICK_START.md');
  print('   - web/WEB_PLATFORM_SETTINGS_GUIDE.md');
  
  exit(allChecksPassed ? 0 : 1);
}
