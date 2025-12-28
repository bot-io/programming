/// Verification script for PWA configuration
/// Run this script to verify all PWA requirements are met
/// 
/// Usage: dart run web/verify_pwa_configuration_complete.dart

import 'dart:io';

void main() {
  print('🔍 Verifying PWA Configuration for Dual Reader 3.1\n');
  
  final checks = <CheckResult>[];
  
  // Check 1: manifest.json exists
  checks.add(_checkManifestFile());
  
  // Check 2: index.html exists and has manifest link
  checks.add(_checkIndexHtml());
  
  // Check 3: Service worker configuration
  checks.add(_checkServiceWorker());
  
  // Check 4: Responsive meta tags
  checks.add(_checkResponsiveMetaTags());
  
  // Check 5: PWA installability
  checks.add(_checkPWAInstallability());
  
  // Check 6: Icons configuration
  checks.add(_checkIcons());
  
  // Print results
  print('\n📊 Verification Results:\n');
  
  int passed = 0;
  int warnings = 0;
  int failed = 0;
  
  for (final check in checks) {
    final status = check.status;
    final icon = status == CheckStatus.passed 
        ? '✅' 
        : status == CheckStatus.warning 
            ? '⚠️' 
            : '❌';
    
    print('$icon ${check.name}');
    print('   ${check.message}');
    if (check.details.isNotEmpty) {
      for (final detail in check.details) {
        print('   • $detail');
      }
    }
    print('');
    
    if (status == CheckStatus.passed) {
      passed++;
    } else if (status == CheckStatus.warning) {
      warnings++;
    } else {
      failed++;
    }
  }
  
  // Summary
  print('─' * 50);
  print('Summary:');
  print('  ✅ Passed: $passed');
  print('  ⚠️  Warnings: $warnings');
  print('  ❌ Failed: $failed');
  print('─' * 50);
  
  if (failed == 0) {
    print('\n🎉 All critical checks passed! PWA configuration is ready.');
    if (warnings > 0) {
      print('⚠️  Some warnings were found. Review them above.');
    }
    exit(0);
  } else {
    print('\n❌ Some checks failed. Please fix the issues above.');
    exit(1);
  }
}

CheckResult _checkManifestFile() {
  final manifestFile = File('web/manifest.json');
  
  if (!manifestFile.existsSync()) {
    return CheckResult(
      name: 'PWA Manifest',
      status: CheckStatus.failed,
      message: 'manifest.json not found',
      details: ['Create web/manifest.json with required PWA metadata'],
    );
  }
  
  try {
    final content = manifestFile.readAsStringSync();
    final json = content;
    
    final requiredFields = [
      'name',
      'short_name',
      'start_url',
      'display',
      'icons',
      'theme_color',
      'background_color',
    ];
    
    final missingFields = <String>[];
    for (final field in requiredFields) {
      if (!json.contains('"$field"')) {
        missingFields.add(field);
      }
    }
    
    if (missingFields.isNotEmpty) {
      return CheckResult(
        name: 'PWA Manifest',
        status: CheckStatus.failed,
        message: 'Missing required fields in manifest.json',
        details: ['Missing: ${missingFields.join(", ")}'],
      );
    }
    
    // Check for icons
    if (!json.contains('"icons"') || !json.contains('"src"')) {
      return CheckResult(
        name: 'PWA Manifest',
        status: CheckStatus.warning,
        message: 'Icons configuration found but verify icon files exist',
        details: ['Ensure all icon files referenced in manifest.json exist'],
      );
    }
    
    return CheckResult(
      name: 'PWA Manifest',
      status: CheckStatus.passed,
      message: 'manifest.json exists with all required fields',
      details: [
        '✅ name, short_name, start_url, display configured',
        '✅ icons array configured',
        '✅ theme_color and background_color set',
      ],
    );
  } catch (e) {
    return CheckResult(
      name: 'PWA Manifest',
      status: CheckStatus.failed,
      message: 'Error reading manifest.json: $e',
      details: ['Check file format and JSON syntax'],
    );
  }
}

CheckResult _checkIndexHtml() {
  final indexFile = File('web/index.html');
  
  if (!indexFile.existsSync()) {
    return CheckResult(
      name: 'index.html',
      status: CheckStatus.failed,
      message: 'index.html not found',
      details: ['Create web/index.html with PWA configuration'],
    );
  }
  
  try {
    final content = indexFile.readAsStringSync();
    
    final checks = <String, bool>{
      'manifest link': content.contains('rel="manifest"') && 
                       content.contains('manifest.json'),
      'viewport meta': content.contains('name="viewport"'),
      'theme-color meta': content.contains('name="theme-color"'),
      'service worker script': content.contains('serviceWorker') || 
                               content.contains('flutter_service_worker'),
    };
    
    final missing = checks.entries
        .where((e) => !e.value)
        .map((e) => e.key)
        .toList();
    
    if (missing.isNotEmpty) {
      return CheckResult(
        name: 'index.html',
        status: CheckStatus.failed,
        message: 'Missing required PWA elements',
        details: missing.map((m) => 'Missing: $m').toList(),
      );
    }
    
    return CheckResult(
      name: 'index.html',
      status: CheckStatus.passed,
      message: 'index.html configured correctly',
      details: [
        '✅ Manifest link present',
        '✅ Viewport meta tag configured',
        '✅ Theme color meta tag present',
        '✅ Service worker registration configured',
      ],
    );
  } catch (e) {
    return CheckResult(
      name: 'index.html',
      status: CheckStatus.failed,
      message: 'Error reading index.html: $e',
      details: [],
    );
  }
}

CheckResult _checkServiceWorker() {
  // Flutter automatically generates flutter_service_worker.js during build
  // Check if custom service-worker.js exists (optional)
  final customSwFile = File('web/service-worker.js');
  final buildSwFile = File('build/web/flutter_service_worker.js');
  
  if (buildSwFile.existsSync()) {
    return CheckResult(
      name: 'Service Worker',
      status: CheckStatus.passed,
      message: 'Service worker configured (Flutter auto-generated)',
      details: [
        '✅ flutter_service_worker.js found in build output',
        'ℹ️  Flutter automatically generates and registers service worker',
        if (customSwFile.existsSync())
          'ℹ️  Custom service-worker.js exists (reference implementation)',
      ],
    );
  } else if (customSwFile.existsSync()) {
    return CheckResult(
      name: 'Service Worker',
      status: CheckStatus.warning,
      message: 'Custom service worker exists, but build output not found',
      details: [
        '⚠️  Run "flutter build web" to generate flutter_service_worker.js',
        'ℹ️  Custom service-worker.js exists (reference implementation)',
        'ℹ️  Flutter will auto-generate flutter_service_worker.js during build',
      ],
    );
  } else {
    return CheckResult(
      name: 'Service Worker',
      status: CheckStatus.warning,
      message: 'Service worker will be auto-generated during build',
      details: [
        'ℹ️  Flutter automatically generates flutter_service_worker.js during build',
        'ℹ️  Run "flutter build web" to create the service worker',
      ],
    );
  }
}

CheckResult _checkResponsiveMetaTags() {
  final indexFile = File('web/index.html');
  
  if (!indexFile.existsSync()) {
    return CheckResult(
      name: 'Responsive Meta Tags',
      status: CheckStatus.failed,
      message: 'index.html not found',
      details: [],
    );
  }
  
  try {
    final content = indexFile.readAsStringSync();
    
    final requiredTags = {
      'viewport': 'name="viewport"',
      'HandheldFriendly': 'name="HandheldFriendly"',
      'MobileOptimized': 'name="MobileOptimized"',
      'apple-mobile-web-app-capable': 'name="apple-mobile-web-app-capable"',
      'theme-color': 'name="theme-color"',
    };
    
    final missing = requiredTags.entries
        .where((e) => !content.contains(e.value))
        .map((e) => e.key)
        .toList();
    
    if (missing.isNotEmpty) {
      return CheckResult(
        name: 'Responsive Meta Tags',
        status: CheckStatus.failed,
        message: 'Missing responsive meta tags',
        details: missing.map((m) => 'Missing: $m').toList(),
      );
    }
    
    return CheckResult(
      name: 'Responsive Meta Tags',
      status: CheckStatus.passed,
      message: 'All responsive meta tags configured',
      details: [
        '✅ Viewport configured for mobile devices',
        '✅ HandheldFriendly and MobileOptimized set',
        '✅ Apple mobile web app meta tags configured',
        '✅ Theme color configured',
      ],
    );
  } catch (e) {
    return CheckResult(
      name: 'Responsive Meta Tags',
      status: CheckStatus.failed,
      message: 'Error checking responsive meta tags: $e',
      details: [],
    );
  }
}

CheckResult _checkPWAInstallability() {
  final indexFile = File('web/index.html');
  
  if (!indexFile.existsSync()) {
    return CheckResult(
      name: 'PWA Installability',
      status: CheckStatus.failed,
      message: 'index.html not found',
      details: [],
    );
  }
  
  try {
    final content = indexFile.readAsStringSync();
    
    final checks = {
      'beforeinstallprompt handler': content.contains('beforeinstallprompt'),
      'appinstalled handler': content.contains('appinstalled'),
      'standalone mode check': content.contains('standalone') || 
                               content.contains('display-mode'),
    };
    
    final missing = checks.entries
        .where((e) => !e.value)
        .map((e) => e.key)
        .toList();
    
    if (missing.isNotEmpty) {
      return CheckResult(
        name: 'PWA Installability',
        status: CheckStatus.warning,
        message: 'Some install prompt handlers may be missing',
        details: missing.map((m) => 'Check: $m').toList(),
      );
    }
    
    // Check if PWA service exists in Dart code
    final pwaServiceFile = File('lib/services/pwa_service.dart');
    final pwaServiceWebFile = File('lib/services/pwa_service_web.dart');
    
    final dartImplementation = pwaServiceFile.existsSync() && 
                                pwaServiceWebFile.existsSync();
    
    return CheckResult(
      name: 'PWA Installability',
      status: CheckStatus.passed,
      message: 'PWA installability configured',
      details: [
        '✅ Install prompt handlers configured in index.html',
        '✅ Standalone mode detection configured',
        if (dartImplementation)
          '✅ Dart PWA service implementation found',
      ],
    );
  } catch (e) {
    return CheckResult(
      name: 'PWA Installability',
      status: CheckStatus.failed,
      message: 'Error checking PWA installability: $e',
      details: [],
    );
  }
}

CheckResult _checkIcons() {
  final iconsDir = Directory('web/icons');
  final manifestFile = File('web/manifest.json');
  
  if (!iconsDir.existsSync()) {
    return CheckResult(
      name: 'Icons',
      status: CheckStatus.warning,
      message: 'Icons directory not found',
      details: [
        '⚠️  Create web/icons/ directory',
        '⚠️  Generate icon files (16x16, 32x32, 72x72, 96x96, 128x128, 144x144, 152x152, 192x192, 384x384, 512x512)',
        'ℹ️  Use scripts in web/icons/ to generate icons',
      ],
    );
  }
  
  final iconFiles = iconsDir.listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.png'))
      .toList();
  
  if (iconFiles.isEmpty) {
    return CheckResult(
      name: 'Icons',
      status: CheckStatus.warning,
      message: 'No icon files found in web/icons/',
      details: [
        '⚠️  Generate icon files for PWA',
        'ℹ️  Required sizes: 16x16, 32x32, 72x72, 96x96, 128x128, 144x144, 152x152, 192x192, 384x384, 512x512',
        'ℹ️  Use scripts in web/icons/ to generate icons',
        if (manifestFile.existsSync())
          'ℹ️  Manifest.json references icons - ensure files exist',
      ],
    );
  }
  
  final iconSizes = iconFiles.map((f) {
    final name = f.path.split('/').last;
    final match = RegExp(r'icon-(\d+)x\d+\.png').firstMatch(name);
    return match != null ? int.tryParse(match.group(1)!) : null;
  }).whereType<int>().toList();
  
  final requiredSizes = [16, 32, 72, 96, 128, 144, 152, 192, 384, 512];
  final missingSizes = requiredSizes.where((s) => !iconSizes.contains(s)).toList();
  
  if (missingSizes.isNotEmpty) {
    return CheckResult(
      name: 'Icons',
      status: CheckStatus.warning,
      message: 'Some icon sizes are missing',
      details: [
        '⚠️  Missing sizes: ${missingSizes.join(", ")}',
        '✅ Found sizes: ${iconSizes.join(", ")}',
        'ℹ️  Generate missing icon sizes for complete PWA support',
      ],
    );
  }
  
  return CheckResult(
    name: 'Icons',
    status: CheckStatus.passed,
    message: 'Icons configured correctly',
    details: [
      '✅ Icons directory exists',
      '✅ Required icon sizes found: ${iconSizes.join(", ")}',
    ],
  );
}

enum CheckStatus {
  passed,
  warning,
  failed,
}

class CheckResult {
  final String name;
  final CheckStatus status;
  final String message;
  final List<String> details;
  
  CheckResult({
    required this.name,
    required this.status,
    required this.message,
    this.details = const [],
  });
}
