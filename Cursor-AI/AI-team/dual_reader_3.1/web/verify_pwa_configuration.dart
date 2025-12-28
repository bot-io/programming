import 'dart:io';

/// Verification script for PWA configuration
/// Checks that all required files and configurations are in place
void main() async {
  print('🔍 Verifying PWA Configuration for Dual Reader 3.1\n');
  
  final webDir = Directory('web');
  if (!await webDir.exists()) {
    print('❌ Error: web/ directory not found');
    exit(1);
  }
  
  final issues = <String>[];
  final warnings = <String>[];
  final successes = <String>[];
  
  // Check 1: manifest.json
  print('📋 Checking manifest.json...');
  final manifestFile = File('web/manifest.json');
  if (await manifestFile.exists()) {
    final manifestContent = await manifestFile.readAsString();
    
    // Check required fields
    final requiredFields = [
      'name',
      'short_name',
      'start_url',
      'display',
      'icons',
      'theme_color',
      'background_color',
    ];
    
    for (final field in requiredFields) {
      if (manifestContent.contains('"$field"')) {
        successes.add('manifest.json contains "$field"');
      } else {
        issues.add('manifest.json missing required field: "$field"');
      }
    }
    
    // Check for PWA installability
    if (manifestContent.contains('"display": "standalone"') ||
        manifestContent.contains('"display": "fullscreen"') ||
        manifestContent.contains('"display": "minimal-ui"')) {
      successes.add('manifest.json has installable display mode');
    } else {
      warnings.add('manifest.json display mode may not be installable');
    }
    
    // Check for icons array
    if (manifestContent.contains('"icons"') && 
        manifestContent.contains('"192x192"') &&
        manifestContent.contains('"512x512"')) {
      successes.add('manifest.json has required icon sizes (192x192, 512x512)');
    } else {
      issues.add('manifest.json missing required icon sizes');
    }
    
    print('  ✅ manifest.json exists and configured');
  } else {
    issues.add('manifest.json not found');
    print('  ❌ manifest.json not found');
  }
  
  // Check 2: index.html
  print('\n📄 Checking index.html...');
  final indexFile = File('web/index.html');
  if (await indexFile.exists()) {
    final indexContent = await indexFile.readAsString();
    
    // Check for manifest link
    if (indexContent.contains('rel="manifest"') && 
        indexContent.contains('manifest.json')) {
      successes.add('index.html links to manifest.json');
    } else {
      issues.add('index.html missing manifest.json link');
    }
    
    // Check for responsive meta tags
    final responsiveTags = [
      'viewport',
      'theme-color',
      'apple-mobile-web-app-capable',
      'apple-mobile-web-app-status-bar-style',
    ];
    
    for (final tag in responsiveTags) {
      if (indexContent.contains(tag)) {
        successes.add('index.html has $tag meta tag');
      } else {
        warnings.add('index.html missing $tag meta tag');
      }
    }
    
    // Check for service worker registration
    if (indexContent.contains('serviceWorker') || 
        indexContent.contains('flutter_service_worker')) {
      successes.add('index.html has service worker registration');
    } else {
      warnings.add('index.html may be missing service worker registration');
    }
    
    // Check for Flutter loader
    if (indexContent.contains('flutter.js') || 
        indexContent.contains('_flutter.loader')) {
      successes.add('index.html has Flutter loader');
    } else {
      issues.add('index.html missing Flutter loader');
    }
    
    print('  ✅ index.html exists and configured');
  } else {
    issues.add('index.html not found');
    print('  ❌ index.html not found');
  }
  
  // Check 3: Service worker (optional - Flutter generates its own)
  print('\n⚙️  Checking service worker configuration...');
  final swFile = File('web/service-worker.js');
  if (await swFile.exists()) {
    warnings.add('Custom service-worker.js found (Flutter generates its own automatically)');
    print('  ⚠️  Custom service-worker.js exists (Flutter will use its own)');
  } else {
    successes.add('Using Flutter\'s automatic service worker');
    print('  ✅ Using Flutter\'s automatic service worker');
  }
  
  // Check 4: Icons (check if directory exists)
  print('\n🖼️  Checking icons...');
  final iconsDir = Directory('web/icons');
  if (await iconsDir.exists()) {
    final iconFiles = await iconsDir.list()
        .where((entity) => entity is File && entity.path.endsWith('.png'))
        .toList();
    
    if (iconFiles.isNotEmpty) {
      successes.add('Icons directory contains ${iconFiles.length} icon files');
      print('  ✅ Icons directory exists with ${iconFiles.length} files');
    } else {
      warnings.add('Icons directory exists but no PNG files found');
      print('  ⚠️  Icons directory exists but no PNG files found');
      print('     Run: web/icons/create_placeholder_icons.ps1 to generate icons');
    }
  } else {
    warnings.add('Icons directory not found');
    print('  ⚠️  Icons directory not found');
  }
  
  // Check 5: Favicon
  print('\n🔖 Checking favicon...');
  final faviconFile = File('web/favicon.png');
  if (await faviconFile.exists()) {
    successes.add('favicon.png exists');
    print('  ✅ favicon.png exists');
  } else {
    warnings.add('favicon.png not found (recommended but not required)');
    print('  ⚠️  favicon.png not found (recommended)');
  }
  
  // Check 6: browserconfig.xml (Windows tiles)
  print('\n🪟 Checking browserconfig.xml...');
  final browserConfigFile = File('web/browserconfig.xml');
  if (await browserConfigFile.exists()) {
    successes.add('browserconfig.xml exists for Windows tiles');
    print('  ✅ browserconfig.xml exists');
  } else {
    warnings.add('browserconfig.xml not found (optional for Windows)');
    print('  ⚠️  browserconfig.xml not found (optional)');
  }
  
  // Summary
  print('\n' + '=' * 60);
  print('📊 Verification Summary\n');
  
  if (successes.isNotEmpty) {
    print('✅ Successes (${successes.length}):');
    for (final success in successes) {
      print('   • $success');
    }
    print('');
  }
  
  if (warnings.isNotEmpty) {
    print('⚠️  Warnings (${warnings.length}):');
    for (final warning in warnings) {
      print('   • $warning');
    }
    print('');
  }
  
  if (issues.isNotEmpty) {
    print('❌ Issues (${issues.length}):');
    for (final issue in issues) {
      print('   • $issue');
    }
    print('');
  }
  
  // Final verdict
  print('=' * 60);
  if (issues.isEmpty) {
    if (warnings.isEmpty) {
      print('🎉 Perfect! All PWA requirements are met.');
      print('✅ Your app is ready to be installed as a PWA.');
    } else {
      print('✅ Core PWA requirements are met.');
      print('⚠️  Some optional features are missing but won\'t prevent installation.');
    }
    exit(0);
  } else {
    print('❌ Some critical issues found. Please fix them before deployment.');
    exit(1);
  }
}
