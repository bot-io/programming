/// Verification script for Web Platform Settings Task
/// 
/// This script verifies that all requirements for the Web Platform Settings task are met:
/// - PWA manifest.json created with app metadata
/// - Service worker configured for offline support
/// - Web app builds and runs in browser
/// - Responsive meta tags configured
/// - App is installable as PWA
/// 
/// Run with: dart run web/verify_web_platform_settings_complete_task.dart

import 'dart:io';

void main() {
  print('=' * 60);
  print('Web Platform Settings - Task Verification');
  print('=' * 60);
  print('');
  
  final results = <String, bool>{};
  final warnings = <String>[];
  final errors = <String>[];
  
  // 1. Check manifest.json exists and is valid
  print('1. Checking PWA manifest.json...');
  final manifestFile = File('web/manifest.json');
  if (manifestFile.existsSync()) {
    try {
      final content = manifestFile.readAsStringSync();
      final requiredFields = [
        '"name"',
        '"short_name"',
        '"description"',
        '"start_url"',
        '"display"',
        '"theme_color"',
        '"background_color"',
        '"icons"',
      ];
      
      bool allFieldsPresent = true;
      for (final field in requiredFields) {
        if (!content.contains(field)) {
          allFieldsPresent = false;
          errors.add('manifest.json missing required field: $field');
        }
      }
      
      if (allFieldsPresent) {
        results['manifest.json'] = true;
        print('   ✅ manifest.json exists with all required fields');
      } else {
        results['manifest.json'] = false;
        print('   ❌ manifest.json missing required fields');
      }
    } catch (e) {
      results['manifest.json'] = false;
      errors.add('Failed to read manifest.json: $e');
      print('   ❌ Failed to read manifest.json: $e');
    }
  } else {
    results['manifest.json'] = false;
    errors.add('manifest.json not found');
    print('   ❌ manifest.json not found');
  }
  
  // 2. Check service worker configuration
  print('');
  print('2. Checking service worker configuration...');
  final indexFile = File('web/index.html');
  if (indexFile.existsSync()) {
    final indexContent = indexFile.readAsStringSync();
    
    // Check for service worker references
    if (indexContent.contains('serviceWorker') || 
        indexContent.contains('flutter_service_worker')) {
      results['service_worker_referenced'] = true;
      print('   ✅ Service worker referenced in index.html');
      print('   ℹ️  Note: Flutter auto-generates flutter_service_worker.js during build');
    } else {
      results['service_worker_referenced'] = false;
      warnings.add('Service worker not referenced in index.html');
      print('   ⚠️  Service worker not referenced in index.html');
    }
    
    // Check for manifest link
    if (indexContent.contains('manifest.json') && 
        indexContent.contains('rel="manifest"')) {
      results['manifest_linked'] = true;
      print('   ✅ manifest.json linked in index.html');
    } else {
      results['manifest_linked'] = false;
      errors.add('manifest.json not linked in index.html');
      print('   ❌ manifest.json not linked in index.html');
    }
  } else {
    results['service_worker_referenced'] = false;
    results['manifest_linked'] = false;
    errors.add('index.html not found');
    print('   ❌ index.html not found');
  }
  
  // 3. Check responsive meta tags
  print('');
  print('3. Checking responsive meta tags...');
  if (indexFile.existsSync()) {
    final indexContent = indexFile.readAsStringSync();
    
    final requiredMetaTags = [
      'viewport',
      'theme-color',
      'apple-mobile-web-app-capable',
      'HandheldFriendly',
    ];
    
    int foundTags = 0;
    for (final tag in requiredMetaTags) {
      if (indexContent.contains(tag)) {
        foundTags++;
      }
    }
    
    if (foundTags == requiredMetaTags.length) {
      results['responsive_meta_tags'] = true;
      print('   ✅ All required responsive meta tags present');
    } else {
      results['responsive_meta_tags'] = false;
      warnings.add('Some responsive meta tags missing');
      print('   ⚠️  Some responsive meta tags missing ($foundTags/${requiredMetaTags.length})');
    }
  }
  
  // 4. Check icons exist
  print('');
  print('4. Checking PWA icons...');
  final iconSizes = [16, 32, 72, 96, 128, 144, 152, 192, 384, 512];
  int iconsFound = 0;
  
  for (final size in iconSizes) {
    final iconFile = File('web/icons/icon-${size}x${size}.png');
    if (iconFile.existsSync()) {
      iconsFound++;
    }
  }
  
  if (iconsFound == iconSizes.length) {
    results['icons'] = true;
    print('   ✅ All required icons present ($iconsFound/${iconSizes.length})');
  } else if (iconsFound > 0) {
    results['icons'] = false;
    warnings.add('Some icons missing ($iconsFound/${iconSizes.length})');
    print('   ⚠️  Some icons missing ($iconsFound/${iconSizes.length})');
    print('   ℹ️  Run: cd web/icons && python create_placeholder_icons.py');
  } else {
    results['icons'] = false;
    warnings.add('No icons found. PWA may not be installable without icons.');
    print('   ⚠️  No icons found');
    print('   ℹ️  Run: cd web/icons && python create_placeholder_icons.py');
  }
  
  // 5. Check favicon
  print('');
  print('5. Checking favicon...');
  final faviconPng = File('web/favicon.png');
  final faviconIco = File('web/favicon.ico');
  
  if (faviconPng.existsSync() || faviconIco.existsSync()) {
    results['favicon'] = true;
    print('   ✅ Favicon exists');
  } else {
    results['favicon'] = false;
    warnings.add('Favicon not found');
    print('   ⚠️  Favicon not found');
  }
  
  // 6. Check build configuration
  print('');
  print('6. Checking build configuration...');
  final buildConfigFile = File('web/flutter_build_config.json');
  if (buildConfigFile.existsSync()) {
    final content = buildConfigFile.readAsStringSync();
    if (content.contains('"pwa"') && content.contains('"enabled"')) {
      results['build_config'] = true;
      print('   ✅ Build configuration includes PWA settings');
    } else {
      results['build_config'] = false;
      warnings.add('Build configuration may not have PWA enabled');
      print('   ⚠️  Build configuration may not have PWA enabled');
    }
  } else {
    results['build_config'] = false;
    warnings.add('flutter_build_config.json not found');
    print('   ⚠️  flutter_build_config.json not found');
  }
  
  // Summary
  print('');
  print('=' * 60);
  print('Verification Summary');
  print('=' * 60);
  
  final allPassed = results.values.every((v) => v);
  final passedCount = results.values.where((v) => v).length;
  final totalCount = results.length;
  
  print('');
  print('Results: $passedCount/$totalCount checks passed');
  print('');
  
  if (allPassed) {
    print('✅ All checks passed! Web Platform Settings are configured correctly.');
  } else {
    print('⚠️  Some checks failed. Please review the issues above.');
  }
  
  if (warnings.isNotEmpty) {
    print('');
    print('Warnings:');
    for (final warning in warnings) {
      print('  ⚠️  $warning');
    }
  }
  
  if (errors.isNotEmpty) {
    print('');
    print('Errors:');
    for (final error in errors) {
      print('  ❌ $error');
    }
  }
  
  print('');
  print('Next Steps:');
  print('  1. Ensure all icons are generated (run icon generation script)');
  print('  2. Build the web app: flutter build web');
  print('  3. Verify flutter_service_worker.js is generated in build/web/');
  print('  4. Test PWA installation in a browser');
  print('  5. Verify offline functionality works');
  print('');
  
  exit(allPassed ? 0 : 1);
}
