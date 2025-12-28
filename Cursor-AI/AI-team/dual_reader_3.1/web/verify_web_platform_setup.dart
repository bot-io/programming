#!/usr/bin/env dart
/// Verification script for Web Platform Settings
/// Checks that all PWA requirements are met

import 'dart:io';
import 'dart:convert';

void main() {
  print('=' * 60);
  print('Web Platform Settings Verification');
  print('=' * 60);
  print('');
  
  final results = <String, bool>{};
  final warnings = <String>[];
  final errors = <String>[];
  
  // 1. Check manifest.json
  print('1. Checking manifest.json...');
  final manifestFile = File('web/manifest.json');
  if (manifestFile.existsSync()) {
    try {
      final manifestContent = manifestFile.readAsStringSync();
      final manifest = jsonDecode(manifestContent) as Map<String, dynamic>;
      
      // Required fields
      final requiredFields = ['name', 'short_name', 'start_url', 'display', 'icons'];
      for (final field in requiredFields) {
        if (manifest.containsKey(field)) {
          print('   ✓ $field: present');
        } else {
          errors.add('manifest.json missing required field: $field');
          print('   ✗ $field: missing');
        }
      }
      
      // Check icons
      if (manifest.containsKey('icons')) {
        final icons = manifest['icons'] as List;
        print('   ✓ Icons defined: ${icons.length} entries');
        
        // Check for required icon sizes
        final requiredSizes = [192, 512];
        for (final size in requiredSizes) {
          final hasSize = icons.any((icon) {
            final sizes = icon['sizes'] as String? ?? '';
            return sizes.contains('$size');
          });
          if (hasSize) {
            print('   ✓ Icon size $size: present');
          } else {
            warnings.add('Icon size $size not found in manifest');
            print('   ⚠ Icon size $size: not found');
          }
        }
      }
      
      results['manifest'] = errors.isEmpty;
    } catch (e) {
      errors.add('Error parsing manifest.json: $e');
      print('   ✗ Error: $e');
      results['manifest'] = false;
    }
  } else {
    errors.add('manifest.json not found');
    print('   ✗ manifest.json not found');
    results['manifest'] = false;
  }
  
  print('');
  
  // 2. Check index.html
  print('2. Checking index.html...');
  final indexFile = File('web/index.html');
  if (indexFile.existsSync()) {
    final indexContent = indexFile.readAsStringSync();
    
    // Check for manifest link
    if (indexContent.contains('manifest.json')) {
      print('   ✓ Manifest link: present');
    } else {
      errors.add('manifest.json link not found in index.html');
      print('   ✗ Manifest link: missing');
    }
    
    // Check for responsive meta tags
    final metaTags = [
      'viewport',
      'theme-color',
      'apple-mobile-web-app-capable',
      'apple-mobile-web-app-status-bar-style',
    ];
    
    for (final tag in metaTags) {
      if (indexContent.contains(tag)) {
        print('   ✓ Meta tag $tag: present');
      } else {
        warnings.add('Meta tag $tag not found');
        print('   ⚠ Meta tag $tag: not found');
      }
    }
    
    // Check for service worker registration
    if (indexContent.contains('serviceWorker') || 
        indexContent.contains('flutter_service_worker')) {
      print('   ✓ Service worker registration: present');
    } else {
      warnings.add('Service worker registration not found');
      print('   ⚠ Service worker registration: not found');
    }
    
    results['index.html'] = true;
  } else {
    errors.add('index.html not found');
    print('   ✗ index.html not found');
    results['index.html'] = false;
  }
  
  print('');
  
  // 3. Check icons
  print('3. Checking icon files...');
  final iconSizes = [16, 32, 72, 96, 128, 144, 152, 192, 384, 512];
  int iconsFound = 0;
  
  for (final size in iconSizes) {
    final iconFile = File('web/icons/icon-$size.png');
    if (iconFile.existsSync()) {
      iconsFound++;
      print('   ✓ icon-$size.png: exists');
    } else {
      warnings.add('Icon icon-$size.png not found');
      print('   ⚠ icon-$size.png: missing');
    }
  }
  
  // Required icons
  final requiredIcons = [192, 512];
  for (final size in requiredIcons) {
    final iconFile = File('web/icons/icon-$size.png');
    if (!iconFile.existsSync()) {
      errors.add('Required icon icon-$size.png not found');
    }
  }
  
  print('   Found: $iconsFound/${iconSizes.length} icons');
  results['icons'] = iconsFound >= 2; // At least required icons
  
  print('');
  
  // 4. Check favicon
  print('4. Checking favicon...');
  final faviconPng = File('web/favicon.png');
  final faviconIco = File('web/favicon.ico');
  
  if (faviconPng.existsSync() || faviconIco.existsSync()) {
    print('   ✓ Favicon: exists');
    results['favicon'] = true;
  } else {
    warnings.add('Favicon not found (optional but recommended)');
    print('   ⚠ Favicon: not found');
    results['favicon'] = false;
  }
  
  print('');
  
  // 5. Check service worker
  print('5. Checking service worker...');
  final swFile = File('web/service-worker.js');
  if (swFile.existsSync()) {
    print('   ✓ service-worker.js: exists');
    print('   ℹ Note: Flutter generates flutter_service_worker.js automatically');
    results['service-worker'] = true;
  } else {
    warnings.add('service-worker.js not found (Flutter generates its own)');
    print('   ⚠ service-worker.js: not found (Flutter generates its own)');
    results['service-worker'] = true; // Not required, Flutter handles it
  }
  
  print('');
  
  // 6. Check browserconfig.xml
  print('6. Checking browserconfig.xml...');
  final browserConfig = File('web/browserconfig.xml');
  if (browserConfig.existsSync()) {
    print('   ✓ browserconfig.xml: exists');
    results['browserconfig'] = true;
  } else {
    warnings.add('browserconfig.xml not found (optional for Windows tiles)');
    print('   ⚠ browserconfig.xml: not found (optional)');
    results['browserconfig'] = false;
  }
  
  print('');
  
  // Summary
  print('=' * 60);
  print('Verification Summary');
  print('=' * 60);
  print('');
  
  final allPassed = results.values.every((v) => v == true) && errors.isEmpty;
  
  if (allPassed) {
    print('✓ All critical checks passed!');
  } else {
    print('✗ Some checks failed');
  }
  
  print('');
  print('Results:');
  results.forEach((key, value) {
    print('  ${value ? "✓" : "✗"} $key: ${value ? "PASS" : "FAIL"}');
  });
  
  if (errors.isNotEmpty) {
    print('');
    print('Errors:');
    for (final error in errors) {
      print('  ✗ $error');
    }
  }
  
  if (warnings.isNotEmpty) {
    print('');
    print('Warnings:');
    for (final warning in warnings) {
      print('  ⚠ $warning');
    }
  }
  
  print('');
  print('=' * 60);
  
  if (allPassed && errors.isEmpty) {
    print('✓ Web Platform Settings are properly configured!');
    print('');
    print('Next steps:');
    print('  1. Build the web app: flutter build web');
    print('  2. Test locally: flutter run -d chrome');
    print('  3. Deploy to hosting service (Netlify, Vercel, etc.)');
    exit(0);
  } else {
    print('✗ Please fix the errors above before deploying');
    exit(1);
  }
}
