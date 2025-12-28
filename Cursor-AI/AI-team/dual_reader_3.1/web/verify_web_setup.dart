#!/usr/bin/env dart
/// Verification script for Web Platform Settings
/// 
/// This script verifies that all web platform settings are correctly configured:
/// - PWA manifest.json exists and is valid
/// - Service worker is configured (Flutter auto-generates flutter_service_worker.js)
/// - Responsive meta tags are present in index.html
/// - PWA installability is configured
/// 
/// Usage: dart run verify_web_setup.dart

import 'dart:io';

void main() {
  print('🔍 Verifying Web Platform Settings for Dual Reader 3.1\n');
  
  final successes = <String>[];
  final warnings = <String>[];
  final errors = <String>[];
  
  // Check web directory exists
  final webDir = Directory('web');
  if (!webDir.existsSync()) {
    errors.add('web directory not found');
    print('❌ web directory not found');
    printResults(successes, warnings, errors);
    exit(1);
  }
  
  // 1. Check manifest.json
  print('1. Checking PWA manifest.json...');
  final manifestFile = File('web/manifest.json');
  if (manifestFile.existsSync()) {
    try {
      final manifestContent = manifestFile.readAsStringSync();
      if (manifestContent.contains('"name"') && 
          manifestContent.contains('"short_name"') &&
          manifestContent.contains('"start_url"') &&
          manifestContent.contains('"display"') &&
          manifestContent.contains('"icons"')) {
        successes.add('manifest.json exists and contains required fields');
        print('   ✅ manifest.json exists and contains required fields');
        
        // Check for icon references
        if (manifestContent.contains('icon-192x192.png') &&
            manifestContent.contains('icon-512x512.png')) {
          successes.add('manifest.json references required icon sizes');
          print('   ✅ manifest.json references required icon sizes (192x192, 512x512)');
        } else {
          warnings.add('manifest.json may be missing some icon references');
          print('   ⚠️  manifest.json may be missing some icon references');
        }
      } else {
        errors.add('manifest.json is missing required fields');
        print('   ❌ manifest.json is missing required fields');
      }
    } catch (e) {
      errors.add('Error reading manifest.json: $e');
      print('   ❌ Error reading manifest.json: $e');
    }
  } else {
    errors.add('manifest.json not found');
    print('   ❌ manifest.json not found');
  }
  
  // 2. Check index.html for responsive meta tags
  print('\n2. Checking index.html for responsive meta tags...');
  final indexFile = File('web/index.html');
  if (indexFile.existsSync()) {
    try {
      final indexContent = indexFile.readAsStringSync();
      
      // Check for essential meta tags
      final requiredMetaTags = [
        'viewport',
        'theme-color',
        'description',
        'apple-mobile-web-app-capable',
        'application-name',
      ];
      
      int foundTags = 0;
      for (final tag in requiredMetaTags) {
        if (indexContent.contains(tag)) {
          foundTags++;
        }
      }
      
      if (foundTags == requiredMetaTags.length) {
        successes.add('index.html contains all required responsive meta tags');
        print('   ✅ index.html contains all required responsive meta tags');
      } else {
        warnings.add('index.html may be missing some meta tags ($foundTags/${requiredMetaTags.length} found)');
        print('   ⚠️  index.html may be missing some meta tags ($foundTags/${requiredMetaTags.length} found)');
      }
      
      // Check for manifest link
      if (indexContent.contains('manifest.json')) {
        successes.add('index.html links to manifest.json');
        print('   ✅ index.html links to manifest.json');
      } else {
        errors.add('index.html does not link to manifest.json');
        print('   ❌ index.html does not link to manifest.json');
      }
      
      // Check for service worker reference (Flutter auto-generates)
      if (indexContent.contains('serviceWorker') || 
          indexContent.contains('flutter_service_worker')) {
        successes.add('index.html references service worker (Flutter auto-generates flutter_service_worker.js)');
        print('   ✅ index.html references service worker');
        print('   ℹ️  Note: Flutter automatically generates flutter_service_worker.js during build');
      } else {
        warnings.add('index.html does not explicitly reference service worker (Flutter handles this automatically)');
        print('   ⚠️  index.html does not explicitly reference service worker');
        print('   ℹ️  Note: Flutter automatically handles service worker registration');
      }
      
      // Check for PWA install prompt handling
      if (indexContent.contains('beforeinstallprompt') ||
          indexContent.contains('pwa-install')) {
        successes.add('index.html includes PWA install prompt handling');
        print('   ✅ index.html includes PWA install prompt handling');
      } else {
        warnings.add('index.html may not include PWA install prompt handling');
        print('   ⚠️  index.html may not include PWA install prompt handling');
      }
      
    } catch (e) {
      errors.add('Error reading index.html: $e');
      print('   ❌ Error reading index.html: $e');
    }
  } else {
    errors.add('index.html not found');
    print('   ❌ index.html not found');
  }
  
  // 3. Check service worker configuration
  print('\n3. Checking service worker configuration...');
  final swFile = File('web/service-worker.js');
  if (swFile.existsSync()) {
    successes.add('service-worker.js exists (Flutter uses flutter_service_worker.js)');
    print('   ✅ service-worker.js exists');
    print('   ℹ️  Note: Flutter automatically generates flutter_service_worker.js during build');
  } else {
    warnings.add('service-worker.js not found (Flutter will generate flutter_service_worker.js)');
    print('   ⚠️  service-worker.js not found');
    print('   ℹ️  Note: Flutter automatically generates flutter_service_worker.js during build');
  }
  
  // Check flutter_build_config.json
  final buildConfigFile = File('web/flutter_build_config.json');
  if (buildConfigFile.existsSync()) {
    try {
      final configContent = buildConfigFile.readAsStringSync();
      if (configContent.contains('"pwa"') && 
          configContent.contains('"serviceWorker"')) {
        successes.add('flutter_build_config.json has PWA configuration');
        print('   ✅ flutter_build_config.json has PWA configuration');
      }
    } catch (e) {
      warnings.add('Error reading flutter_build_config.json: $e');
      print('   ⚠️  Error reading flutter_build_config.json: $e');
    }
  }
  
  // 4. Check icons directory
  print('\n4. Checking icons...');
  final iconsDir = Directory('web/icons');
  if (iconsDir.existsSync()) {
    successes.add('icons directory exists');
    print('   ✅ icons directory exists');
    
    // Check for some key icon files
    final keyIcons = ['icon-192x192.png', 'icon-512x512.png'];
    int foundIcons = 0;
    for (final icon in keyIcons) {
      final iconFile = File('web/icons/$icon');
      if (iconFile.existsSync()) {
        foundIcons++;
      }
    }
    
    if (foundIcons == keyIcons.length) {
      successes.add('Required icon files exist (192x192, 512x512)');
      print('   ✅ Required icon files exist (192x192, 512x512)');
    } else {
      warnings.add('Some icon files may be missing ($foundIcons/${keyIcons.length} found)');
      print('   ⚠️  Some icon files may be missing ($foundIcons/${keyIcons.length} found)');
      print('   ℹ️  Run: python web/icons/create_placeholder_icons.py to generate icons');
    }
  } else {
    warnings.add('icons directory not found');
    print('   ⚠️  icons directory not found');
    print('   ℹ️  Create icons directory and generate icons');
  }
  
  // 5. Check browserconfig.xml
  print('\n5. Checking browserconfig.xml...');
  final browserConfigFile = File('web/browserconfig.xml');
  if (browserConfigFile.existsSync()) {
    successes.add('browserconfig.xml exists');
    print('   ✅ browserconfig.xml exists');
  } else {
    warnings.add('browserconfig.xml not found (optional for Windows tiles)');
    print('   ⚠️  browserconfig.xml not found (optional for Windows tiles)');
  }
  
  // Print summary
  printResults(successes, warnings, errors);
  
  // Exit with appropriate code
  if (errors.isNotEmpty) {
    exit(1);
  } else if (warnings.isNotEmpty) {
    exit(0); // Warnings don't fail the check
  } else {
    exit(0);
  }
}

void printResults(List<String> successes, List<String> warnings, List<String> errors) {
  print('\n' + '=' * 60);
  print('📊 Verification Summary');
  print('=' * 60);
  
  print('\n✅ Successes (${successes.length}):');
  for (final success in successes) {
    print('   • $success');
  }
  
  if (warnings.isNotEmpty) {
    print('\n⚠️  Warnings (${warnings.length}):');
    for (final warning in warnings) {
      print('   • $warning');
    }
  }
  
  if (errors.isNotEmpty) {
    print('\n❌ Errors (${errors.length}):');
    for (final error in errors) {
      print('   • $error');
    }
  }
  
  print('\n' + '=' * 60);
  
  if (errors.isEmpty && warnings.isEmpty) {
    print('✅ All checks passed! Web platform settings are correctly configured.');
  } else if (errors.isEmpty) {
    print('✅ Configuration is valid. Some warnings may need attention.');
  } else {
    print('❌ Configuration has errors that need to be fixed.');
  }
  
  print('\n📝 Next Steps:');
  print('   1. Generate icons: python web/icons/create_placeholder_icons.py');
  print('   2. Build web app: flutter build web');
  print('   3. Verify build output contains flutter_service_worker.js');
  print('   4. Test PWA installability in browser');
  print('=' * 60 + '\n');
}
