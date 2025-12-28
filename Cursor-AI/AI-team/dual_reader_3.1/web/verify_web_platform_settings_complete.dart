import 'dart:io';

/// Verification script for Web Platform Settings
/// Checks that all PWA and web configuration is complete and correct
void main() async {
  print('🔍 Verifying Web Platform Settings Configuration...\n');
  
  final webBase = 'web';
  final issues = <String>[];
  final warnings = <String>[];
  final successes = <String>[];
  
  // 1. Check manifest.json
  print('1. Checking manifest.json...');
  final manifestFile = File('$webBase/manifest.json');
  if (await manifestFile.exists()) {
    final content = await manifestFile.readAsString();
    
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
      if (content.contains('"$field"')) {
        successes.add('manifest.json contains "$field"');
      } else {
        issues.add('manifest.json missing required field: "$field"');
      }
    }
    
    // Check for PWA installability
    if (content.contains('"display":') && 
        (content.contains('"standalone"') || content.contains('"fullscreen"'))) {
      successes.add('manifest.json has installable display mode');
    } else {
      warnings.add('manifest.json display mode may not support PWA installation');
    }
    
    // Check for icons
    if (content.contains('"icons"') && content.contains('192x192') && content.contains('512x512')) {
      successes.add('manifest.json includes required icon sizes (192x192, 512x512)');
    } else {
      issues.add('manifest.json missing required icon sizes');
    }
    
    print('   ✅ manifest.json exists and is configured');
  } else {
    issues.add('manifest.json not found at $webBase/manifest.json');
    print('   ❌ manifest.json not found');
  }
  
  // 2. Check index.html
  print('\n2. Checking index.html...');
  final indexFile = File('$webBase/index.html');
  if (await indexFile.exists()) {
    final content = await indexFile.readAsString();
    
    // Check for manifest link
    if (content.contains('manifest.json') || content.contains('rel="manifest"')) {
      successes.add('index.html links to manifest.json');
    } else {
      issues.add('index.html missing manifest.json link');
    }
    
    // Check for responsive meta tags
    final metaTags = [
      'viewport',
      'theme-color',
      'apple-mobile-web-app-capable',
      'apple-mobile-web-app-status-bar-style',
      'apple-mobile-web-app-title',
    ];
    
    for (final tag in metaTags) {
      if (content.contains(tag)) {
        successes.add('index.html contains responsive meta tag: $tag');
      } else {
        warnings.add('index.html missing meta tag: $tag');
      }
    }
    
    // Check for Flutter initialization
    if (content.contains('flutter.js') || content.contains('main.dart.js')) {
      successes.add('index.html includes Flutter initialization');
    } else {
      warnings.add('index.html may be missing Flutter initialization');
    }
    
    // Check for service worker registration
    if (content.contains('serviceWorker') || content.contains('service-worker')) {
      successes.add('index.html includes service worker registration');
    } else {
      warnings.add('index.html may be missing service worker registration (Flutter auto-registers)');
    }
    
    print('   ✅ index.html exists and is configured');
  } else {
    issues.add('index.html not found at $webBase/index.html');
    print('   ❌ index.html not found');
  }
  
  // 3. Check Flutter build configuration
  print('\n3. Checking Flutter build configuration...');
  final buildConfigFile = File('$webBase/flutter_build_config.json');
  if (await buildConfigFile.exists()) {
    final content = await buildConfigFile.readAsString();
    
    if (content.contains('"pwa"') && content.contains('"enabled"')) {
      successes.add('Flutter build config has PWA enabled');
    } else {
      warnings.add('Flutter build config may not have PWA enabled');
    }
    
    print('   ✅ Flutter web build configuration exists');
  } else {
    warnings.add('flutter_build_config.json not found (optional, Flutter has defaults)');
    print('   ⚠️  flutter_build_config.json not found (optional)');
  }
  
  // 4. Check service worker reference
  print('\n4. Checking service worker configuration...');
  final swFile = File('$webBase/service-worker.js');
  if (await swFile.exists()) {
    successes.add('service-worker.js reference implementation exists');
    print('   ✅ service-worker.js exists (reference implementation)');
    print('   ℹ️  Note: Flutter auto-generates flutter_service_worker.js during build');
  } else {
    warnings.add('service-worker.js not found (optional, Flutter auto-generates)');
    print('   ⚠️  service-worker.js not found (optional)');
  }
  
  // 5. Check browserconfig.xml (Windows tiles)
  print('\n5. Checking browserconfig.xml...');
  final browserConfigFile = File('$webBase/browserconfig.xml');
  if (await browserConfigFile.exists()) {
    successes.add('browserconfig.xml exists for Windows tiles');
    print('   ✅ browserconfig.xml exists');
  } else {
    warnings.add('browserconfig.xml not found (optional for Windows)');
    print('   ⚠️  browserconfig.xml not found (optional)');
  }
  
  // 6. Check icons directory
  print('\n6. Checking icons directory...');
  final iconsDir = Directory('$webBase/icons');
  if (await iconsDir.exists()) {
    final iconFiles = await iconsDir.list().toList();
    final pngIcons = iconFiles.where((f) => f.path.endsWith('.png')).length;
    
    if (pngIcons > 0) {
      successes.add('Icons directory contains $pngIcons PNG icon(s)');
      print('   ✅ Icons directory exists with $pngIcons icon(s)');
    } else {
      warnings.add('Icons directory exists but contains no PNG files');
      print('   ⚠️  Icons directory exists but no PNG files found');
      print('   ℹ️  Run icon generation scripts to create icons');
    }
  } else {
    warnings.add('Icons directory not found');
    print('   ⚠️  Icons directory not found');
    print('   ℹ️  Create icons directory and generate icon files');
  }
  
  // 7. Check robots.txt
  print('\n7. Checking robots.txt...');
  final robotsFile = File('$webBase/robots.txt');
  if (await robotsFile.exists()) {
    successes.add('robots.txt exists');
    print('   ✅ robots.txt exists');
  } else {
    warnings.add('robots.txt not found (optional for SEO)');
    print('   ⚠️  robots.txt not found (optional)');
  }
  
  // Summary
  print('\n' + '=' * 60);
  print('📊 VERIFICATION SUMMARY');
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
  
  if (issues.isNotEmpty) {
    print('\n❌ Issues (${issues.length}):');
    for (final issue in issues) {
      print('   • $issue');
    }
  }
  
  print('\n' + '=' * 60);
  
  if (issues.isEmpty) {
    print('✅ Web Platform Settings Configuration: COMPLETE');
    if (warnings.isEmpty) {
      print('🎉 All checks passed! Ready for production.');
    } else {
      print('⚠️  Configuration complete, but some optional items are missing.');
    }
    
    print('\n📝 Next Steps:');
    print('   1. Generate PWA icons if not already done');
    print('   2. Build web app: flutter build web --release');
    print('   3. Verify build output: build/web/flutter_service_worker.js exists');
    print('   4. Test PWA installation in browser');
    print('   5. Deploy build/web/ directory to hosting service');
  } else {
    print('❌ Web Platform Settings Configuration: INCOMPLETE');
    print('\n🔧 Please fix the issues above before building.');
    exit(1);
  }
  
  print('\n' + '=' * 60);
}
