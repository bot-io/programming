import 'dart:io';

/// Verification script for PWA configuration
/// Run with: dart run web/verify_pwa_config.dart

void main() {
  print('🔍 Verifying PWA Configuration for Dual Reader 3.1\n');
  
  final webDir = Directory('web');
  if (!webDir.exists()) {
    print('❌ Error: web/ directory not found');
    exit(1);
  }
  
  final issues = <String>[];
  final warnings = <String>[];
  final successes = <String>[];
  
  // Check manifest.json
  print('📋 Checking manifest.json...');
  final manifestFile = File('web/manifest.json');
  if (manifestFile.existsSync()) {
    final manifestContent = manifestFile.readAsStringSync();
    
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
        successes.add('manifest.json contains $field');
      } else {
        issues.add('manifest.json missing required field: $field');
      }
    }
    
    // Check for icons array
    if (manifestContent.contains('"icons"') && manifestContent.contains('[')) {
      successes.add('manifest.json has icons array');
    } else {
      issues.add('manifest.json missing icons array');
    }
    
    // Check for PWA display modes
    if (manifestContent.contains('"standalone"') || manifestContent.contains('"display": "standalone"')) {
      successes.add('manifest.json configured for standalone display');
    } else {
      warnings.add('manifest.json may not be configured for standalone display');
    }
    
    print('   ✅ manifest.json exists');
  } else {
    issues.add('manifest.json not found');
    print('   ❌ manifest.json not found');
  }
  
  // Check index.html
  print('\n📄 Checking index.html...');
  final indexFile = File('web/index.html');
  if (indexFile.existsSync()) {
    final indexContent = indexFile.readAsStringSync();
    
    // Check for manifest link
    if (indexContent.contains('manifest.json') || indexContent.contains('rel="manifest"')) {
      successes.add('index.html links to manifest.json');
      print('   ✅ manifest.json linked');
    } else {
      issues.add('index.html missing manifest.json link');
      print('   ❌ manifest.json not linked');
    }
    
    // Check for responsive meta tags
    final responsiveTags = [
      'viewport',
      'theme-color',
      'apple-mobile-web-app-capable',
      'mobile-web-app-capable',
    ];
    
    int foundTags = 0;
    for (final tag in responsiveTags) {
      if (indexContent.contains(tag)) {
        foundTags++;
      }
    }
    
    if (foundTags >= 3) {
      successes.add('index.html has responsive meta tags');
      print('   ✅ Responsive meta tags configured');
    } else {
      warnings.add('index.html may be missing some responsive meta tags');
      print('   ⚠️  Some responsive meta tags may be missing');
    }
    
    // Check for service worker reference
    if (indexContent.contains('serviceWorker') || indexContent.contains('flutter_service_worker')) {
      successes.add('index.html references service worker');
      print('   ✅ Service worker referenced');
    } else {
      warnings.add('index.html may not reference service worker (Flutter auto-generates)');
      print('   ℹ️  Service worker (Flutter auto-generates flutter_service_worker.js)');
    }
    
    // Check for PWA install prompt handling
    if (indexContent.contains('beforeinstallprompt') || indexContent.contains('pwa-install')) {
      successes.add('index.html has PWA install prompt handling');
      print('   ✅ PWA install prompt handling configured');
    } else {
      warnings.add('index.html may not have PWA install prompt handling');
      print('   ⚠️  PWA install prompt handling may be missing');
    }
    
    print('   ✅ index.html exists');
  } else {
    issues.add('index.html not found');
    print('   ❌ index.html not found');
  }
  
  // Check icons
  print('\n🖼️  Checking icons...');
  final iconsDir = Directory('web/icons');
  final requiredIconSizes = [16, 32, 72, 96, 128, 144, 152, 192, 384, 512];
  
  if (iconsDir.existsSync()) {
    int foundIcons = 0;
    for (final size in requiredIconSizes) {
      final iconFile = File('web/icons/icon-${size}x${size}.png');
      if (iconFile.existsSync()) {
        foundIcons++;
      }
    }
    
    if (foundIcons == requiredIconSizes.length) {
      successes.add('All required PWA icons exist');
      print('   ✅ All required icons found ($foundIcons/${requiredIconSizes.length})');
    } else if (foundIcons > 0) {
      warnings.add('Some PWA icons missing ($foundIcons/${requiredIconSizes.length})');
      print('   ⚠️  Some icons missing ($foundIcons/${requiredIconSizes.length})');
      print('   💡 Run: dart run web/generate_pwa_icons.dart or open web/icons/generate_icons_simple.html');
    } else {
      warnings.add('No PWA icons found. Generate them using the icon generator.');
      print('   ⚠️  No icons found');
      print('   💡 Run: .\\web\\generate_pwa_icons.ps1 or open web/icons/generate_icons_simple.html');
    }
  } else {
    warnings.add('Icons directory not found');
    print('   ⚠️  Icons directory not found');
  }
  
  // Check service worker (Flutter auto-generates)
  print('\n⚙️  Checking service worker configuration...');
  final swFile = File('web/service-worker.js');
  if (swFile.existsSync()) {
    successes.add('Custom service-worker.js exists (Flutter uses flutter_service_worker.js)');
    print('   ✅ Custom service-worker.js exists');
    print('   ℹ️  Note: Flutter automatically generates flutter_service_worker.js during build');
  } else {
    warnings.add('Custom service-worker.js not found (Flutter will generate flutter_service_worker.js)');
    print('   ℹ️  Custom service-worker.js not found (Flutter auto-generates flutter_service_worker.js)');
  }
  
  // Check build output
  print('\n🏗️  Checking build output...');
  final buildSwFile = File('build/web/flutter_service_worker.js');
  if (buildSwFile.existsSync()) {
    successes.add('flutter_service_worker.js exists in build output');
    print('   ✅ flutter_service_worker.js found in build output');
  } else {
    warnings.add('Build output not found. Run: flutter build web');
    print('   ℹ️  Build output not found. Run: flutter build web');
  }
  
  // Summary
  print('\n' + '=' * 60);
  print('📊 Verification Summary');
  print('=' * 60);
  print('✅ Successes: ${successes.length}');
  print('⚠️  Warnings: ${warnings.length}');
  print('❌ Issues: ${issues.length}');
  print('');
  
  if (successes.isNotEmpty) {
    print('✅ Successful checks:');
    for (final success in successes) {
      print('   • $success');
    }
    print('');
  }
  
  if (warnings.isNotEmpty) {
    print('⚠️  Warnings:');
    for (final warning in warnings) {
      print('   • $warning');
    }
    print('');
  }
  
  if (issues.isNotEmpty) {
    print('❌ Issues to fix:');
    for (final issue in issues) {
      print('   • $issue');
    }
    print('');
  }
  
  // Final verdict
  if (issues.isEmpty && warnings.isEmpty) {
    print('🎉 All checks passed! PWA configuration is complete.');
    exit(0);
  } else if (issues.isEmpty) {
    print('✅ Configuration is functional. Some warnings can be addressed for optimal setup.');
    exit(0);
  } else {
    print('❌ Please fix the issues above before deploying.');
    exit(1);
  }
}
