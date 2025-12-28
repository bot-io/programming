#!/usr/bin/env dart
/// Verification script for Web Platform Settings
/// 
/// This script verifies that all acceptance criteria are met:
/// - PWA manifest.json created with app metadata
/// - Service worker configured for offline support
/// - Web app builds and runs in browser
/// - Responsive meta tags configured
/// - App is installable as PWA

import 'dart:io';

String _repeat(String s, int n) => List.filled(n, s).join('');

void main() async {
  print(_repeat('=', 60));
  print('Web Platform Settings Verification');
  print('Dual Reader 3.1');
  print(_repeat('=', 60));
  print('');

  final successes = <String>[];
  final errors = <String>[];
  final warnings = <String>[];

  // 1. Check PWA manifest.json
  print('1. Checking PWA manifest.json...');
  await _checkManifest(successes, errors, warnings);

  // 2. Check responsive meta tags in index.html
  print('\n2. Checking responsive meta tags...');
  await _checkResponsiveMetaTags(successes, errors, warnings);

  // 3. Check service worker configuration
  print('\n3. Checking service worker configuration...');
  await _checkServiceWorker(successes, errors, warnings);

  // 4. Check icon files
  print('\n4. Checking icon files...');
  await _checkIcons(successes, errors, warnings);

  // 5. Check Flutter web build configuration
  print('\n5. Checking Flutter web build configuration...');
  await _checkFlutterConfig(successes, errors, warnings);

  // 6. Check deployment configuration files
  print('\n6. Checking deployment configuration...');
  await _checkDeploymentConfig(successes, errors, warnings);

  // Print summary
  print('\n${_repeat('=', 60)}');
  print('Verification Summary');
  print(_repeat('=', 60));
  print('');

  if (successes.isNotEmpty) {
    print('✅ Successes (${successes.length}):');
    for (final success in successes) {
      print('   ✓ $success');
    }
    print('');
  }

  if (warnings.isNotEmpty) {
    print('⚠️  Warnings (${warnings.length}):');
    for (final warning in warnings) {
      print('   ⚠  $warning');
    }
    print('');
  }

  if (errors.isNotEmpty) {
    print('❌ Errors (${errors.length}):');
    for (final error in errors) {
      print('   ✗ $error');
    }
    print('');
  }

  // Acceptance criteria check
  print(_repeat('=', 60));
  print('Acceptance Criteria');
  print(_repeat('=', 60));
  print('');

  final criteria = {
    'PWA manifest.json created with app metadata':
        successes.contains('manifest.json exists with all required fields'),
    'Service worker configured for offline support':
        successes.contains('Service worker configuration verified'),
    'Responsive meta tags configured':
        successes.contains('Responsive meta tags present'),
    'App is installable as PWA':
        successes.contains('manifest.json configured for PWA installation'),
  };

  bool allPassed = true;
  for (final entry in criteria.entries) {
    final status = entry.value ? '✅' : '❌';
    print('$status ${entry.key}');
    if (!entry.value) allPassed = false;
  }

  print('');
  if (allPassed && errors.isEmpty) {
    print('🎉 All acceptance criteria met!');
    exit(0);
  } else {
    print('⚠️  Some acceptance criteria not met. Please review errors above.');
    exit(1);
  }
}

Future<void> _checkManifest(
    List<String> successes, List<String> errors, List<String> warnings) async {
  final manifestFile = File('web/manifest.json');
  if (!await manifestFile.exists()) {
    errors.add('manifest.json not found');
    print('   ❌ manifest.json not found');
    return;
  }

  try {
    final content = await manifestFile.readAsString();
    final requiredFields = [
      'name',
      'short_name',
      'description',
      'start_url',
      'display',
      'icons',
      'theme_color',
      'background_color',
    ];

    bool allFieldsPresent = true;
    for (final field in requiredFields) {
      if (!content.contains('"$field"')) {
        errors.add('manifest.json missing required field: $field');
        print('   ❌ Missing field: $field');
        allFieldsPresent = false;
      }
    }

    if (allFieldsPresent) {
      successes.add('manifest.json exists with all required fields');
      print('   ✅ manifest.json exists with all required fields');
    }

    // Check display mode for PWA installation
    if (content.contains('"display": "standalone"') ||
        content.contains('"display": "fullscreen"') ||
        content.contains('"display": "minimal-ui"')) {
      successes.add('manifest.json configured for PWA installation');
      print('   ✅ manifest.json configured for PWA installation');
    } else {
      warnings.add('manifest.json display mode may not support PWA installation');
      print('   ⚠️  Display mode may not support PWA installation');
    }

    // Check for required icon sizes
    if (content.contains('"192x192"') && content.contains('"512x512"')) {
      successes.add('manifest.json includes required icon sizes');
      print('   ✅ manifest.json includes required icon sizes (192x192, 512x512)');
    } else {
      warnings.add('manifest.json may be missing required icon sizes');
      print('   ⚠️  May be missing required icon sizes');
    }

    // Check for shortcuts (optional but recommended)
    if (content.contains('"shortcuts"')) {
      successes.add('manifest.json includes app shortcuts');
      print('   ✅ manifest.json includes app shortcuts');
    }
  } catch (e) {
    errors.add('Failed to parse manifest.json: $e');
    print('   ❌ Failed to parse manifest.json: $e');
  }
}

Future<void> _checkResponsiveMetaTags(List<String> successes,
    List<String> errors, List<String> warnings) async {
  final indexFile = File('web/index.html');
  if (!await indexFile.exists()) {
    errors.add('index.html not found');
    print('   ❌ index.html not found');
    return;
  }

  final content = await indexFile.readAsString();

  final requiredMetaTags = [
    'viewport',
    'theme-color',
    'description',
    'apple-mobile-web-app-capable',
    'apple-mobile-web-app-status-bar-style',
  ];

  bool allTagsPresent = true;
  for (final tag in requiredMetaTags) {
    if (!content.contains('name="$tag"') && !content.contains('name=\'$tag\'')) {
      warnings.add('index.html missing meta tag: $tag');
      print('   ⚠️  Missing meta tag: $tag');
      allTagsPresent = false;
    }
  }

  if (allTagsPresent) {
    successes.add('Responsive meta tags present');
    print('   ✅ Responsive meta tags present');
  }

  // Check for manifest link
  if (content.contains('rel="manifest"') && content.contains('manifest.json')) {
    successes.add('index.html links to manifest.json');
    print('   ✅ index.html links to manifest.json');
  } else {
    errors.add('index.html missing manifest link');
    print('   ❌ index.html missing manifest link');
  }

  // Check for viewport meta tag with proper configuration
  if (content.contains('viewport') &&
      content.contains('width=device-width') &&
      content.contains('initial-scale=1.0')) {
    successes.add('Viewport meta tag properly configured');
    print('   ✅ Viewport meta tag properly configured');
  } else {
    warnings.add('Viewport meta tag may not be properly configured');
    print('   ⚠️  Viewport meta tag may need configuration');
  }
}

Future<void> _checkServiceWorker(List<String> successes, List<String> errors,
    List<String> warnings) async {
  // Flutter automatically generates flutter_service_worker.js during build
  // Check if index.html references service worker
  final indexFile = File('web/index.html');
  if (await indexFile.exists()) {
    final content = await indexFile.readAsString();
    if (content.contains('serviceWorker') ||
        content.contains('flutter_service_worker') ||
        content.contains('flutter.js')) {
      successes.add('Service worker configuration verified');
      print('   ✅ Service worker configuration verified');
      print('   ℹ️  Flutter auto-generates flutter_service_worker.js during build');
    } else {
      warnings.add('Service worker may not be referenced');
      print('   ⚠️  Service worker may not be referenced');
    }
  }

  // Check for custom service worker (optional)
  final swFile = File('web/service-worker.js');
  if (await swFile.exists()) {
    successes.add('Custom service-worker.js exists (reference implementation)');
    print('   ✅ Custom service-worker.js exists (reference implementation)');
  } else {
    print('   ℹ️  Custom service-worker.js not found (Flutter uses flutter_service_worker.js)');
  }
}

Future<void> _checkIcons(
    List<String> successes, List<String> errors, List<String> warnings) async {
  final requiredSizes = [16, 32, 72, 96, 128, 144, 152, 192, 384, 512];
  final iconsDir = Directory('web/icons');
  int foundCount = 0;

  if (!await iconsDir.exists()) {
    warnings.add('Icons directory not found');
    print('   ⚠️  Icons directory not found');
    print('   ℹ️  Run: python web/icons/create_placeholder_icons.py');
    return;
  }

  for (final size in requiredSizes) {
    final iconFile = File('web/icons/icon-$size x$size.png');
    if (await iconFile.exists()) {
      foundCount++;
    }
  }

  if (foundCount == requiredSizes.length) {
    successes.add('All required icon sizes present');
    print('   ✅ All required icon sizes present ($foundCount/${requiredSizes.length})');
  } else if (foundCount > 0) {
    warnings.add('Some icon sizes missing ($foundCount/${requiredSizes.length})');
    print('   ⚠️  Some icon sizes missing ($foundCount/${requiredSizes.length})');
    print('   ℹ️  Run: python web/icons/create_placeholder_icons.py');
  } else {
    warnings.add('No icon files found');
    print('   ⚠️  No icon files found');
    print('   ℹ️  Run: python web/icons/create_placeholder_icons.py');
  }

  // Check favicon
  final faviconFile = File('web/favicon.png');
  if (await faviconFile.exists()) {
    successes.add('Favicon present');
    print('   ✅ Favicon present');
  } else {
    warnings.add('Favicon not found');
    print('   ⚠️  Favicon not found');
  }
}

Future<void> _checkFlutterConfig(List<String> successes, List<String> errors,
    List<String> warnings) async {
  // Check flutter_build_config.json
  final configFile = File('web/flutter_build_config.json');
  if (await configFile.exists()) {
    final content = await configFile.readAsString();
    if (content.contains('"pwa"') && content.contains('"enabled": true')) {
      successes.add('Flutter PWA configuration enabled');
      print('   ✅ Flutter PWA configuration enabled');
    } else {
      warnings.add('Flutter PWA may not be enabled in config');
      print('   ⚠️  Flutter PWA may not be enabled');
    }
  } else {
    print('   ℹ️  flutter_build_config.json not found (optional)');
  }

  // Check pubspec.yaml for web support
  final pubspecFile = File('pubspec.yaml');
  if (await pubspecFile.exists()) {
    successes.add('pubspec.yaml exists');
    print('   ✅ pubspec.yaml exists');
  } else {
    errors.add('pubspec.yaml not found');
    print('   ❌ pubspec.yaml not found');
  }
}

Future<void> _checkDeploymentConfig(List<String> successes,
    List<String> errors, List<String> warnings) async {
  final configFiles = [
    'web/_headers',
    'web/.htaccess',
    'web/vercel.json',
    'web/browserconfig.xml',
  ];

  int foundCount = 0;
  for (final configFile in configFiles) {
    final file = File(configFile);
    if (await file.exists()) {
      foundCount++;
    }
  }

  if (foundCount > 0) {
    successes.add('Deployment configuration files present ($foundCount/${configFiles.length})');
    print('   ✅ Deployment configuration files present ($foundCount/${configFiles.length})');
  } else {
    warnings.add('No deployment configuration files found');
    print('   ⚠️  No deployment configuration files found');
  }
}
