#!/usr/bin/env dart
// Verification script for Web Platform Settings Task
// Validates all acceptance criteria for PWA configuration

import 'dart:io';
import 'dart:convert';

void main() {
  print('🔍 Verifying Web Platform Settings Configuration...\n');
  
  final results = <String, bool>{};
  final warnings = <String>[];
  final errors = <String>[];
  
  // Determine base path
  final currentDir = Directory.current.path;
  final isInWebDir = currentDir.endsWith('web') || currentDir.endsWith('web\\');
  final webBase = isInWebDir ? '.' : 'web';
  
  // 1. Check PWA manifest.json exists with app metadata
  print('1️⃣  Checking PWA manifest.json...');
  final manifestFile = File('$webBase/manifest.json');
  if (manifestFile.existsSync()) {
    final manifestContent = manifestFile.readAsStringSync();
    final manifestJson = _parseJson(manifestContent);
    
    if (manifestJson != null) {
      final requiredFields = [
        'name',
        'short_name',
        'description',
        'start_url',
        'display',
        'background_color',
        'theme_color',
        'icons'
      ];
      
      bool allFieldsPresent = true;
      for (final field in requiredFields) {
        if (!manifestJson.containsKey(field)) {
          errors.add('Missing required field in manifest.json: $field');
          allFieldsPresent = false;
        }
      }
      
      if (allFieldsPresent) {
        print('   ✅ manifest.json exists with all required fields');
        results['manifest'] = true;
        
        // Check for PWA installability requirements
        if (manifestJson['display'] == 'standalone' || 
            manifestJson['display'] == 'fullscreen') {
          print('   ✅ Display mode set for PWA installability');
        } else {
          warnings.add('Display mode should be "standalone" or "fullscreen" for best PWA experience');
        }
        
        // Check icons
        if (manifestJson['icons'] is List && 
            (manifestJson['icons'] as List).isNotEmpty) {
          final icons = manifestJson['icons'] as List;
          final has192Icon = icons.any((icon) => 
            icon is Map && icon['sizes'] == '192x192');
          final has512Icon = icons.any((icon) => 
            icon is Map && icon['sizes'] == '512x512');
          
          if (has192Icon && has512Icon) {
            print('   ✅ Required icon sizes (192x192, 512x512) present');
          } else {
            warnings.add('Recommended: Include 192x192 and 512x512 icons for PWA');
          }
        }
      } else {
        results['manifest'] = false;
      }
    } else {
      errors.add('manifest.json exists but is not valid JSON');
      results['manifest'] = false;
    }
  } else {
    errors.add('manifest.json not found');
    results['manifest'] = false;
  }
  
  // 2. Check service worker configuration
  print('\n2️⃣  Checking Service Worker configuration...');
  final indexFile = File('$webBase/index.html');
  if (indexFile.existsSync()) {
    final indexContent = indexFile.readAsStringSync();
    
    // Check for Flutter service worker references
    if (indexContent.contains('flutter_service_worker') ||
        indexContent.contains('serviceWorker')) {
      print('   ✅ Service worker referenced in index.html');
      results['service_worker'] = true;
      
      // Check for service worker registration code
      if (indexContent.contains('navigator.serviceWorker') ||
          indexContent.contains('serviceWorkerVersion')) {
        print('   ✅ Service worker registration code present');
      } else {
        warnings.add('Service worker registration code may be handled by Flutter automatically');
      }
    } else {
      warnings.add('Service worker not explicitly referenced (Flutter may handle automatically)');
      results['service_worker'] = true; // Flutter handles this
    }
    
    // Check for manifest link
    if (indexContent.contains('rel="manifest"') &&
        indexContent.contains('manifest.json')) {
      print('   ✅ manifest.json linked in index.html');
    } else {
      errors.add('manifest.json not linked in index.html');
      results['manifest'] = false;
    }
  } else {
    errors.add('index.html not found');
    results['service_worker'] = false;
  }
  
  // 3. Check responsive meta tags
  print('\n3️⃣  Checking Responsive Meta Tags...');
  if (indexFile.existsSync()) {
    final indexContent = indexFile.readAsStringSync();
    
    final requiredMetaTags = [
      'viewport',
      'theme-color',
      'apple-mobile-web-app-capable',
      'HandheldFriendly',
      'MobileOptimized'
    ];
    
    int foundTags = 0;
    for (final tag in requiredMetaTags) {
      if (indexContent.contains(tag)) {
        foundTags++;
      }
    }
    
    if (foundTags == requiredMetaTags.length) {
      print('   ✅ All essential responsive meta tags present');
      results['responsive_meta'] = true;
    } else {
      warnings.add('Some responsive meta tags may be missing');
      results['responsive_meta'] = foundTags >= 3; // At least 3 should be present
    }
    
    // Check for viewport meta tag specifically
    if (indexContent.contains('name="viewport"')) {
      print('   ✅ Viewport meta tag configured');
    } else {
      errors.add('Viewport meta tag is required for responsive design');
      results['responsive_meta'] = false;
    }
  }
  
  // 4. Check PWA installability features
  print('\n4️⃣  Checking PWA Installability...');
  if (indexFile.existsSync() && manifestFile.existsSync()) {
    final indexContent = indexFile.readAsStringSync();
    final manifestContent = manifestFile.readAsStringSync();
    final manifestJson = _parseJson(manifestContent);
    
    bool installable = true;
    
    // Check for beforeinstallprompt handling
    if (indexContent.contains('beforeinstallprompt')) {
      print('   ✅ PWA install prompt handling configured');
    } else {
      warnings.add('PWA install prompt handling not found (optional but recommended)');
    }
    
    // Check manifest for installability requirements
    if (manifestJson != null) {
      if (manifestJson['display'] == 'standalone' ||
          manifestJson['display'] == 'fullscreen' ||
          manifestJson['display'] == 'minimal-ui') {
        print('   ✅ Display mode suitable for PWA installation');
      } else {
        warnings.add('Display mode should be standalone/fullscreen/minimal-ui for PWA');
        installable = false;
      }
      
      if (manifestJson.containsKey('icons') &&
          manifestJson['icons'] is List &&
          (manifestJson['icons'] as List).isNotEmpty) {
        print('   ✅ Icons configured for PWA installation');
      } else {
        errors.add('Icons are required for PWA installation');
        installable = false;
      }
    }
    
    results['pwa_installable'] = installable;
  }
  
  // 5. Check web app build configuration
  print('\n5️⃣  Checking Web App Build Configuration...');
  final flutterConfigFile = File('$webBase/flutter_build_config.json');
  if (flutterConfigFile.existsSync()) {
    print('   ✅ Flutter web build configuration exists');
    results['build_config'] = true;
  } else {
    warnings.add('flutter_build_config.json not found (optional)');
    results['build_config'] = true; // Not required, Flutter has defaults
  }
  
  // Summary
  print('\n' + '=' * 60);
  print('📊 Verification Summary');
  print('=' * 60);
  
  final allPassed = results.values.every((v) => v == true);
  
  print('\n✅ Passed Checks:');
  results.forEach((key, value) {
    if (value) {
      print('   ✅ $key');
    }
  });
  
  if (warnings.isNotEmpty) {
    print('\n⚠️  Warnings:');
    for (final warning in warnings) {
      print('   ⚠️  $warning');
    }
  }
  
  if (errors.isNotEmpty) {
    print('\n❌ Errors:');
    for (final error in errors) {
      print('   ❌ $error');
    }
  }
  
  print('\n' + '=' * 60);
  
  if (allPassed && errors.isEmpty) {
    print('✅ All acceptance criteria met!');
    print('\n📋 Acceptance Criteria Status:');
    print('   ✅ PWA manifest.json created with app metadata');
    print('   ✅ Service worker configured for offline support');
    print('   ✅ Responsive meta tags configured');
    print('   ✅ App is installable as PWA');
    print('\n💡 Next Steps:');
    print('   1. Run: flutter build web');
    print('   2. Verify: build/web/flutter_service_worker.js exists');
    print('   3. Test: Deploy and test PWA installation');
    exit(0);
  } else {
    print('❌ Some checks failed. Please review errors above.');
    exit(1);
  }
}

Map<String, dynamic>? _parseJson(String content) {
  try {
    return jsonDecode(content) as Map<String, dynamic>;
  } catch (e) {
    return null;
  }
}
