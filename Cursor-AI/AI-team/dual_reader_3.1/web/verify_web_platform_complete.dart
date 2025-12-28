import 'dart:io';

/// Comprehensive verification script for Web Platform Settings
/// Verifies PWA manifest, service worker, responsive meta tags, and installability
void main() async {
  print('🔍 Verifying Web Platform Settings for Dual Reader 3.1\n');
  
  final webDir = Directory('web');
  final buildWebDir = Directory('build/web');
  
  if (!webDir.exists()) {
    print('❌ ERROR: web/ directory not found');
    exit(1);
  }
  
  final successes = <String>[];
  final warnings = <String>[];
  final errors = <String>[];
  
  // 1. Verify manifest.json
  print('📋 Checking PWA Manifest...');
  final manifestFile = File('web/manifest.json');
  if (manifestFile.existsSync()) {
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
    
    bool allFieldsPresent = true;
    for (final field in requiredFields) {
      if (!manifestContent.contains('"$field"')) {
        errors.add('Missing required field: $field');
        allFieldsPresent = false;
      }
    }
    
    if (allFieldsPresent) {
      successes.add('manifest.json exists with all required fields');
      print('   ✅ manifest.json exists with all required fields');
    } else {
      print('   ❌ manifest.json missing required fields');
    }
    
    // Check for PWA features
    if (manifestContent.contains('"shortcuts"')) {
      successes.add('App shortcuts configured');
      print('   ✅ App shortcuts configured');
    }
    
    if (manifestContent.contains('"share_target"')) {
      successes.add('Share target configured');
      print('   ✅ Share target configured');
    }
  } else {
    errors.add('manifest.json not found');
    print('   ❌ manifest.json not found');
  }
  
  // 2. Verify index.html
  print('\n🌐 Checking index.html...');
  final indexFile = File('web/index.html');
  if (indexFile.existsSync()) {
    final indexContent = await indexFile.readAsString();
    
    // Check manifest link
    if (indexContent.contains('rel="manifest"') && 
        indexContent.contains('manifest.json')) {
      successes.add('manifest.json linked in index.html');
      print('   ✅ manifest.json linked in index.html');
    } else {
      errors.add('manifest.json not linked in index.html');
      print('   ❌ manifest.json not linked in index.html');
    }
    
    // Check responsive meta tags
    final responsiveTags = [
      'viewport',
      'theme-color',
      'apple-mobile-web-app-capable',
      'apple-mobile-web-app-status-bar-style',
      'msapplication-TileColor',
    ];
    
    int foundTags = 0;
    for (final tag in responsiveTags) {
      if (indexContent.contains(tag)) {
        foundTags++;
      }
    }
    
    if (foundTags == responsiveTags.length) {
      successes.add('All responsive meta tags present');
      print('   ✅ All responsive meta tags present');
    } else {
      warnings.add('Some responsive meta tags missing ($foundTags/${responsiveTags.length})');
      print('   ⚠️  Some responsive meta tags missing ($foundTags/${responsiveTags.length})');
    }
    
    // Check service worker registration
    if (indexContent.contains('serviceWorker') || 
        indexContent.contains('flutter_service_worker')) {
      successes.add('Service worker registration code present');
      print('   ✅ Service worker registration code present');
    } else {
      warnings.add('Service worker registration code not found');
      print('   ⚠️  Service worker registration code not found');
    }
    
    // Check PWA install prompt handling
    if (indexContent.contains('beforeinstallprompt') || 
        indexContent.contains('pwa-install')) {
      successes.add('PWA install prompt handling present');
      print('   ✅ PWA install prompt handling present');
    } else {
      warnings.add('PWA install prompt handling not found');
      print('   ⚠️  PWA install prompt handling not found');
    }
  } else {
    errors.add('index.html not found');
    print('   ❌ index.html not found');
  }
  
  // 3. Verify service worker
  print('\n⚙️  Checking Service Worker...');
  // Flutter automatically generates flutter_service_worker.js during build
  if (buildWebDir.existsSync()) {
    final swFile = File('build/web/flutter_service_worker.js');
    if (swFile.existsSync()) {
      successes.add('flutter_service_worker.js exists (auto-generated)');
      print('   ✅ flutter_service_worker.js exists (auto-generated)');
    } else {
      warnings.add('flutter_service_worker.js not found (run flutter build web first)');
      print('   ℹ️  flutter_service_worker.js not found (run flutter build web first)');
    }
  } else {
    warnings.add('build/web directory not found (run flutter build web first)');
    print('   ℹ️  build/web directory not found (run flutter build web first)');
  }
  
  // Check custom service worker reference
  final customSwFile = File('web/service-worker.js');
  if (customSwFile.existsSync()) {
    successes.add('Custom service-worker.js exists (Flutter uses flutter_service_worker.js)');
    print('   ✅ service-worker.js exists (Flutter uses flutter_service_worker.js)');
  } else {
    warnings.add('service-worker.js not found (Flutter will generate flutter_service_worker.js)');
    print('   ℹ️  service-worker.js not found (Flutter will generate flutter_service_worker.js)');
  }
  
  // 4. Verify icons
  print('\n🖼️  Checking Icons...');
  final iconsDir = Directory('web/icons');
  if (iconsDir.existsSync()) {
    final iconSizes = [16, 32, 72, 96, 128, 144, 152, 192, 384, 512];
    int foundIcons = 0;
    
    for (final size in iconSizes) {
      final iconFile = File('web/icons/icon-$sizex$size.png');
      if (iconFile.existsSync()) {
        foundIcons++;
      }
    }
    
    if (foundIcons == iconSizes.length) {
      successes.add('All required icon sizes present');
      print('   ✅ All required icon sizes present ($foundIcons icons)');
    } else if (foundIcons > 0) {
      warnings.add('Some icon sizes missing ($foundIcons/${iconSizes.length})');
      print('   ⚠️  Some icon sizes missing ($foundIcons/${iconSizes.length})');
    } else {
      warnings.add('No icon files found (icons may need to be generated)');
      print('   ⚠️  No icon files found (icons may need to be generated)');
    }
  } else {
    warnings.add('web/icons directory not found');
    print('   ⚠️  web/icons directory not found');
  }
  
  // 5. Verify browserconfig.xml
  print('\n🪟 Checking Browser Config...');
  final browserConfigFile = File('web/browserconfig.xml');
  if (browserConfigFile.existsSync()) {
    successes.add('browserconfig.xml exists');
    print('   ✅ browserconfig.xml exists');
  } else {
    warnings.add('browserconfig.xml not found');
    print('   ⚠️  browserconfig.xml not found');
  }
  
  // 6. Verify Flutter build config
  print('\n⚙️  Checking Flutter Build Config...');
  final buildConfigFile = File('web/flutter_build_config.json');
  if (buildConfigFile.existsSync()) {
    final configContent = await buildConfigFile.readAsString();
    if (configContent.contains('"pwa"') && configContent.contains('"enabled"')) {
      successes.add('Flutter build config has PWA enabled');
      print('   ✅ Flutter build config has PWA enabled');
    }
  } else {
    warnings.add('flutter_build_config.json not found');
    print('   ⚠️  flutter_build_config.json not found');
  }
  
  // 7. Verify PWA service implementation
  print('\n📱 Checking PWA Service Implementation...');
  final pwaServiceFile = File('lib/services/pwa_service.dart');
  final pwaServiceWebFile = File('lib/services/pwa_service_web.dart');
  final pwaServiceStubFile = File('lib/services/pwa_service_stub.dart');
  
  if (pwaServiceFile.existsSync() && 
      pwaServiceWebFile.existsSync() && 
      pwaServiceStubFile.existsSync()) {
    successes.add('PWA service implementation complete');
    print('   ✅ PWA service implementation complete');
  } else {
    errors.add('PWA service implementation incomplete');
    print('   ❌ PWA service implementation incomplete');
  }
  
  // 8. Verify PWA install banner widget
  print('\n🎨 Checking PWA Install Banner...');
  final pwaBannerFile = File('lib/widgets/pwa_install_banner.dart');
  if (pwaBannerFile.existsSync()) {
    successes.add('PWA install banner widget exists');
    print('   ✅ PWA install banner widget exists');
  } else {
    warnings.add('PWA install banner widget not found');
    print('   ⚠️  PWA install banner widget not found');
  }
  
  // Summary
  print('\n' + '=' * 60);
  print('📊 Verification Summary');
  print('=' * 60);
  print('✅ Successes: ${successes.length}');
  print('⚠️  Warnings: ${warnings.length}');
  print('❌ Errors: ${errors.length}');
  print('');
  
  if (errors.isNotEmpty) {
    print('❌ ERRORS:');
    for (final error in errors) {
      print('   • $error');
    }
    print('');
  }
  
  if (warnings.isNotEmpty) {
    print('⚠️  WARNINGS:');
    for (final warning in warnings) {
      print('   • $warning');
    }
    print('');
  }
  
  if (successes.isNotEmpty) {
    print('✅ SUCCESSES:');
    for (final success in successes.take(10)) {
      print('   • $success');
    }
    if (successes.length > 10) {
      print('   ... and ${successes.length - 10} more');
    }
    print('');
  }
  
  // Final verdict
  if (errors.isEmpty && warnings.isEmpty) {
    print('🎉 All checks passed! Web platform is fully configured.');
    exit(0);
  } else if (errors.isEmpty) {
    print('✅ Core configuration complete. Some optional features may need attention.');
    exit(0);
  } else {
    print('❌ Configuration incomplete. Please fix errors above.');
    exit(1);
  }
}
