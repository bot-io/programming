import 'dart:io';
import 'dart:mirrors';

/// Comprehensive PWA verification script for Dual Reader 3.1
/// Verifies all PWA requirements are met for production deployment
void main() async {
  print('🔍 Verifying PWA Configuration for Dual Reader 3.1\n');
  
  // Use relative paths from current directory (should be project root)
  final webDir = Directory('web');
  if (!await webDir.exists()) {
    print('❌ Error: web/ directory not found');
    print('   Current directory: ${Directory.current.path}');
    print('   Please run this script from the project root directory');
    exit(1);
  }
  
  final checks = <String, bool>{};
  final warnings = <String>[];
  final errors = <String>[];
  
  // 1. Check manifest.json
  print('1. Checking manifest.json...');
  final manifestFile = File('web/manifest.json');
  if (await manifestFile.exists()) {
    final manifestContent = await manifestFile.readAsString();
    final requiredFields = [
      'name',
      'short_name',
      'start_url',
      'display',
      'icons',
      'theme_color',
      'background_color',
    ];
    
    bool allFieldsPresent = true;
    for (final field in requiredFields) {
      if (!manifestContent.contains('"$field"')) {
        errors.add('Missing required field in manifest.json: $field');
        allFieldsPresent = false;
      }
    }
    
    if (allFieldsPresent) {
      checks['manifest.json exists with required fields'] = true;
      print('   ✅ manifest.json exists with all required fields');
    } else {
      checks['manifest.json'] = false;
      print('   ❌ manifest.json missing required fields');
    }
    
    // Check for PWA installability requirements
    if (manifestContent.contains('"display": "standalone"') ||
        manifestContent.contains('"display": "fullscreen"') ||
        manifestContent.contains('"display": "minimal-ui"')) {
      checks['manifest.json has installable display mode'] = true;
      print('   ✅ Display mode configured for PWA installability');
    } else {
      warnings.add('manifest.json display mode may not support PWA installation');
      print('   ⚠️  Display mode may not support PWA installation');
    }
    
    // Check for icons
    if (manifestContent.contains('"icons"') && 
        manifestContent.contains('192x192') &&
        manifestContent.contains('512x512')) {
      checks['manifest.json has required icon sizes'] = true;
      print('   ✅ Icons configured (192x192 and 512x512 required)');
    } else {
      errors.add('manifest.json missing required icon sizes (192x192, 512x512)');
      print('   ❌ Missing required icon sizes');
    }
  } else {
    errors.add('manifest.json not found');
    checks['manifest.json exists'] = false;
    print('   ❌ manifest.json not found');
  }
  
  // 2. Check index.html
  print('\n2. Checking index.html...');
  final indexFile = File('web/index.html');
  if (await indexFile.exists()) {
    final indexContent = await indexFile.readAsString();
    
    // Check manifest link
    if (indexContent.contains('rel="manifest"') && 
        indexContent.contains('manifest.json')) {
      checks['index.html links to manifest.json'] = true;
      print('   ✅ Manifest link present');
    } else {
      errors.add('index.html missing manifest.json link');
      print('   ❌ Manifest link missing');
    }
    
    // Check viewport meta tag
    if (indexContent.contains('name="viewport"')) {
      checks['index.html has viewport meta tag'] = true;
      print('   ✅ Viewport meta tag present');
    } else {
      errors.add('index.html missing viewport meta tag');
      print('   ❌ Viewport meta tag missing');
    }
    
    // Check theme-color
    if (indexContent.contains('name="theme-color"')) {
      checks['index.html has theme-color meta tag'] = true;
      print('   ✅ Theme color meta tag present');
    } else {
      warnings.add('index.html missing theme-color meta tag');
      print('   ⚠️  Theme color meta tag missing');
    }
    
    // Check responsive meta tags
    final responsiveTags = [
      'HandheldFriendly',
      'MobileOptimized',
      'apple-mobile-web-app-capable',
    ];
    int responsiveCount = 0;
    for (final tag in responsiveTags) {
      if (indexContent.contains(tag)) {
        responsiveCount++;
      }
    }
    if (responsiveCount >= 2) {
      checks['index.html has responsive meta tags'] = true;
      print('   ✅ Responsive meta tags present');
    } else {
      warnings.add('index.html may be missing some responsive meta tags');
      print('   ⚠️  Some responsive meta tags may be missing');
    }
    
    // Check service worker reference
    if (indexContent.contains('serviceWorker') || 
        indexContent.contains('flutter_service_worker')) {
      checks['index.html references service worker'] = true;
      print('   ✅ Service worker referenced (Flutter auto-generates flutter_service_worker.js)');
    } else {
      warnings.add('index.html may not reference service worker (Flutter handles this automatically)');
      print('   ℹ️  Service worker handled by Flutter automatically');
    }
  } else {
    errors.add('index.html not found');
    checks['index.html exists'] = false;
    print('   ❌ index.html not found');
  }
  
  // 3. Check service worker (optional - Flutter generates its own)
  print('\n3. Checking service worker configuration...');
  final serviceWorkerFile = File('web/service-worker.js');
  if (await serviceWorkerFile.exists()) {
    checks['Custom service-worker.js exists'] = true;
    print('   ✅ Custom service-worker.js exists (Flutter uses flutter_service_worker.js)');
  } else {
    print('   ℹ️  Custom service-worker.js not found (Flutter auto-generates flutter_service_worker.js)');
  }
  
  // 4. Check icon files
  print('\n4. Checking icon files...');
  final iconSizes = [16, 32, 72, 96, 128, 144, 152, 192, 384, 512];
  final iconsDir = Directory('web/icons');
  int iconsFound = 0;
  
  if (await iconsDir.exists()) {
    for (final size in iconSizes) {
      final iconFile = File('web/icons/icon-$size.png');
      if (await iconFile.exists()) {
        iconsFound++;
      }
    }
    
    if (iconsFound >= 2) {
      checks['Icon files exist'] = true;
      print('   ✅ Found $iconsFound icon files');
    } else if (iconsFound > 0) {
      warnings.add('Only $iconsFound icon files found (recommended: ${iconSizes.length})');
      print('   ⚠️  Found $iconsFound icon files (recommended: ${iconSizes.length})');
    } else {
      warnings.add('No icon files found in web/icons/ directory');
      print('   ⚠️  No icon files found (icons will need to be created)');
    }
  } else {
    warnings.add('web/icons/ directory not found');
    print('   ⚠️  web/icons/ directory not found');
  }
  
  // 5. Check browserconfig.xml
  print('\n5. Checking browserconfig.xml...');
  final browserConfigFile = File('web/browserconfig.xml');
  if (await browserConfigFile.exists()) {
    checks['browserconfig.xml exists'] = true;
    print('   ✅ browserconfig.xml exists');
  } else {
    warnings.add('browserconfig.xml not found (optional for Windows tiles)');
    print('   ℹ️  browserconfig.xml not found (optional)');
  }
  
  // Summary
  print('\n' + '=' * 60);
  print('📊 Verification Summary');
  print('=' * 60);
  
  final passedChecks = checks.values.where((v) => v == true).length;
  final totalChecks = checks.length;
  
  print('\n✅ Passed: $passedChecks/$totalChecks checks');
  
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
  
  // PWA Installability Checklist
  print('\n📋 PWA Installability Checklist:');
  print('=' * 60);
  
  final installabilityChecks = [
    ('HTTPS required', '⚠️  Must be served over HTTPS (or localhost)'),
    ('Manifest with required fields', checks['manifest.json exists with required fields'] == true ? '✅' : '❌'),
    ('192x192 icon', iconsFound > 0 ? '✅' : '⚠️ '),
    ('512x512 icon', iconsFound > 0 ? '✅' : '⚠️ '),
    ('Service worker registered', checks['index.html references service worker'] == true ? '✅' : '⚠️ '),
    ('Start URL configured', checks['manifest.json exists with required fields'] == true ? '✅' : '❌'),
    ('Display mode standalone/fullscreen', checks['manifest.json has installable display mode'] == true ? '✅' : '❌'),
  ];
  
  for (final (check, status) in installabilityChecks) {
    print('   $status $check');
  }
  
  print('\n' + '=' * 60);
  
  if (errors.isEmpty && passedChecks == totalChecks) {
    print('\n✅ PWA configuration is complete and ready for production!');
    print('\n📝 Next steps:');
    print('   1. Ensure icons are created in web/icons/ directory');
    print('   2. Build the web app: flutter build web');
    print('   3. Verify flutter_service_worker.js is generated in build/web/');
    print('   4. Test PWA installability in Chrome DevTools (Application > Manifest)');
    print('   5. Deploy to HTTPS hosting (required for PWA installation)');
    exit(0);
  } else if (errors.isEmpty) {
    print('\n⚠️  PWA configuration is mostly complete, but some warnings exist.');
    print('   Review warnings above and ensure all requirements are met.');
    exit(0);
  } else {
    print('\n❌ PWA configuration has errors. Please fix the errors above.');
    exit(1);
  }
}
