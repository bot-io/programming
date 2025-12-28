// Verification script for PWA configuration
// Run with: dart run web/verify_pwa_setup.dart

import 'dart:io';

void main() {
  print('🔍 Verifying PWA Configuration for Dual Reader 3.1\n');
  
  final webDir = Directory('web');
  if (!webDir.existsSync()) {
    print('❌ Error: web/ directory not found');
    exit(1);
  }
  
  int errors = 0;
  int warnings = 0;
  
  // Check manifest.json
  print('📋 Checking manifest.json...');
  final manifestFile = File('web/manifest.json');
  if (manifestFile.existsSync()) {
    try {
      final content = manifestFile.readAsStringSync();
      if (content.contains('"name"') && content.contains('"short_name"')) {
        print('  ✅ manifest.json exists and has required fields');
      } else {
        print('  ⚠️  manifest.json missing some required fields');
        warnings++;
      }
    } catch (e) {
      print('  ❌ Error reading manifest.json: $e');
      errors++;
    }
  } else {
    print('  ❌ manifest.json not found');
    errors++;
  }
  
  // Check index.html
  print('\n📄 Checking index.html...');
  final indexFile = File('web/index.html');
  if (indexFile.existsSync()) {
    try {
      final content = indexFile.readAsStringSync();
      final checks = {
        'manifest link': content.contains('rel="manifest"'),
        'viewport meta tag': content.contains('name="viewport"'),
        'theme-color meta tag': content.contains('name="theme-color"'),
        'service worker script': content.contains('serviceWorker') || content.contains('flutter.js'),
        'responsive meta tags': content.contains('apple-mobile-web-app-capable') || content.contains('MobileOptimized'),
      };
      
      checks.forEach((check, passed) {
        if (passed) {
          print('  ✅ $check');
        } else {
          print('  ⚠️  $check');
          warnings++;
        }
      });
    } catch (e) {
      print('  ❌ Error reading index.html: $e');
      errors++;
    }
  } else {
    print('  ❌ index.html not found');
    errors++;
  }
  
  // Check icons directory
  print('\n🖼️  Checking icons...');
  final iconsDir = Directory('web/icons');
  if (iconsDir.existsSync()) {
    final iconFiles = iconsDir.listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.png'))
        .length;
    if (iconFiles > 0) {
      print('  ✅ Icons directory exists with $iconFiles PNG files');
    } else {
      print('  ⚠️  Icons directory exists but no PNG files found');
      warnings++;
    }
  } else {
    print('  ⚠️  Icons directory not found (icons may be generated during build)');
    warnings++;
  }
  
  // Check browserconfig.xml
  print('\n🌐 Checking browserconfig.xml...');
  final browserConfigFile = File('web/browserconfig.xml');
  if (browserConfigFile.existsSync()) {
    print('  ✅ browserconfig.xml exists');
  } else {
    print('  ⚠️  browserconfig.xml not found (optional for Windows tiles)');
    warnings++;
  }
  
  // Summary
  print('\n' + '=' * 50);
  print('📊 Summary:');
  print('  Errors: $errors');
  print('  Warnings: $warnings');
  
  if (errors == 0 && warnings == 0) {
    print('\n✅ All checks passed! PWA configuration looks good.');
    exit(0);
  } else if (errors == 0) {
    print('\n⚠️  Configuration has some warnings but should work.');
    exit(0);
  } else {
    print('\n❌ Configuration has errors. Please fix them before deploying.');
    exit(1);
  }
}
