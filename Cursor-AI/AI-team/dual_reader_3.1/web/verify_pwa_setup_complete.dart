import 'dart:io';

/// Comprehensive verification script for PWA setup
/// Verifies all acceptance criteria for Web Platform Settings task
void main() async {
  print('🔍 Verifying Web Platform Settings Configuration...\n');
  
  final successes = <String>[];
  final warnings = <String>[];
  final errors = <String>[];
  
  // 1. Verify manifest.json exists and is valid
  print('1. Checking PWA manifest.json...');
  final manifestFile = File('web/manifest.json');
  if (await manifestFile.exists()) {
    final manifestContent = await manifestFile.readAsString();
    final checks = {
      'name': manifestContent.contains('"name"'),
      'short_name': manifestContent.contains('"short_name"'),
      'start_url': manifestContent.contains('"start_url"'),
      'display': manifestContent.contains('"display"'),
      'icons': manifestContent.contains('"icons"'),
      'theme_color': manifestContent.contains('"theme_color"'),
      'background_color': manifestContent.contains('"background_color"'),
    };
    
    final allChecksPass = checks.values.every((v) => v);
    if (allChecksPass) {
      successes.add('manifest.json exists with all required fields');
      print('   ✅ manifest.json exists with all required fields');
    } else {
      final missing = checks.entries
          .where((e) => !e.value)
          .map((e) => e.key)
          .join(', ');
      errors.add('manifest.json missing fields: $missing');
      print('   ❌ manifest.json missing fields: $missing');
    }
  } else {
    errors.add('manifest.json not found');
    print('   ❌ manifest.json not found');
  }
  
  // 2. Verify index.html has responsive meta tags
  print('\n2. Checking responsive meta tags in index.html...');
  final indexFile = File('web/index.html');
  if (await indexFile.exists()) {
    final indexContent = await indexFile.readAsString();
    final metaChecks = {
      'viewport': indexContent.contains('name="viewport"'),
      'theme-color': indexContent.contains('name="theme-color"'),
      'apple-mobile-web-app-capable': indexContent.contains('apple-mobile-web-app-capable'),
      'apple-mobile-web-app-status-bar-style': indexContent.contains('apple-mobile-web-app-status-bar-style'),
      'msapplication-TileColor': indexContent.contains('msapplication-TileColor'),
      'manifest link': indexContent.contains('rel="manifest"'),
    };
    
    final allMetaChecksPass = metaChecks.values.every((v) => v);
    if (allMetaChecksPass) {
      successes.add('index.html has all required responsive meta tags');
      print('   ✅ index.html has all required responsive meta tags');
    } else {
      final missing = metaChecks.entries
          .where((e) => !e.value)
          .map((e) => e.key)
          .join(', ');
      warnings.add('index.html missing meta tags: $missing');
      print('   ⚠️  index.html missing meta tags: $missing');
    }
  } else {
    errors.add('index.html not found');
    print('   ❌ index.html not found');
  }
  
  // 3. Verify service worker configuration
  print('\n3. Checking service worker configuration...');
  final swFile = File('web/service-worker.js');
  if (await swFile.exists()) {
    successes.add('service-worker.js exists (Flutter auto-generates flutter_service_worker.js)');
    print('   ✅ service-worker.js exists (Flutter auto-generates flutter_service_worker.js)');
  } else {
    warnings.add('service-worker.js not found (Flutter will generate flutter_service_worker.js)');
    print('   ℹ️  service-worker.js not found (Flutter will generate flutter_service_worker.js)');
  }
  
  // Check if index.html references service worker
  if (await indexFile.exists()) {
    final indexContent = await indexFile.readAsString();
    if (indexContent.contains('serviceWorker') || 
        indexContent.contains('flutter_service_worker')) {
      successes.add('Service worker referenced in index.html');
      print('   ✅ Service worker referenced in index.html');
    } else {
      warnings.add('Service worker not referenced in index.html');
      print('   ⚠️  Service worker not referenced in index.html');
    }
  }
  
  // 4. Verify PWA install prompt handling
  print('\n4. Checking PWA install prompt handling...');
  if (await indexFile.exists()) {
    final indexContent = await indexFile.readAsString();
    if (indexContent.contains('beforeinstallprompt') ||
        indexContent.contains('showInstallPrompt')) {
      successes.add('PWA install prompt handling configured');
      print('   ✅ PWA install prompt handling configured');
    } else {
      warnings.add('PWA install prompt handling not found');
      print('   ⚠️  PWA install prompt handling not found');
    }
  }
  
  // 5. Verify icons directory structure
  print('\n5. Checking icons directory...');
  final iconsDir = Directory('web/icons');
  if (await iconsDir.exists()) {
    successes.add('Icons directory exists');
    print('   ✅ Icons directory exists');
    
    // Check for some key icon files
    final keyIcons = ['icon-192x192.png', 'icon-512x512.png'];
    final foundIcons = <String>[];
    for (final icon in keyIcons) {
      final iconFile = File('web/icons/$icon');
      if (await iconFile.exists()) {
        foundIcons.add(icon);
      }
    }
    
    if (foundIcons.isNotEmpty) {
      successes.add('Key icon files found: ${foundIcons.join(", ")}');
      print('   ✅ Key icon files found: ${foundIcons.join(", ")}');
    } else {
      warnings.add('Icon PNG files not found (use scripts in web/icons/ to generate them)');
      print('   ⚠️  Icon PNG files not found (use scripts in web/icons/ to generate them)');
    }
  } else {
    warnings.add('Icons directory not found');
    print('   ⚠️  Icons directory not found');
  }
  
  // 6. Verify browserconfig.xml for Windows tiles
  print('\n6. Checking browserconfig.xml...');
  final browserConfigFile = File('web/browserconfig.xml');
  if (await browserConfigFile.exists()) {
    successes.add('browserconfig.xml exists for Windows tiles');
    print('   ✅ browserconfig.xml exists for Windows tiles');
  } else {
    warnings.add('browserconfig.xml not found');
    print('   ⚠️  browserconfig.xml not found');
  }
  
  // 7. Verify server configuration files
  print('\n7. Checking server configuration files...');
  final htaccessFile = File('web/.htaccess');
  final headersFile = File('web/_headers');
  final vercelFile = File('web/vercel.json');
  
  if (await htaccessFile.exists()) {
    successes.add('.htaccess exists for Apache servers');
    print('   ✅ .htaccess exists for Apache servers');
  }
  if (await headersFile.exists()) {
    successes.add('_headers exists for Netlify');
    print('   ✅ _headers exists for Netlify');
  }
  if (await vercelFile.exists()) {
    successes.add('vercel.json exists for Vercel');
    print('   ✅ vercel.json exists for Vercel');
  }
  
  // 8. Verify PWA service implementation
  print('\n8. Checking PWA service implementation...');
  final pwaServiceFile = File('lib/services/pwa_service.dart');
  final pwaServiceWebFile = File('lib/services/pwa_service_web.dart');
  
  if (await pwaServiceFile.exists() && await pwaServiceWebFile.exists()) {
    successes.add('PWA service implementation exists');
    print('   ✅ PWA service implementation exists');
  } else {
    errors.add('PWA service implementation not found');
    print('   ❌ PWA service implementation not found');
  }
  
  // 9. Verify PWA install banner widget
  print('\n9. Checking PWA install banner widget...');
  final pwaBannerFile = File('lib/widgets/pwa_install_banner.dart');
  if (await pwaBannerFile.exists()) {
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
  
  if (successes.isNotEmpty) {
    print('✅ Successful checks:');
    for (final success in successes) {
      print('   • $success');
    }
  }
  
  if (warnings.isNotEmpty) {
    print('\n⚠️  Warnings:');
    for (final warning in warnings) {
      print('   • $warning');
    }
  }
  
  if (errors.isNotEmpty) {
    print('\n❌ Errors:');
    for (final error in errors) {
      print('   • $error');
    }
  }
  
  print('\n' + '=' * 60);
  print('📋 Acceptance Criteria Check');
  print('=' * 60);
  
  final criteria = {
    'PWA manifest.json created with app metadata': 
        successes.contains('manifest.json exists with all required fields'),
    'Service worker configured for offline support': 
        successes.contains('Service worker referenced in index.html'),
    'Responsive meta tags configured': 
        successes.contains('index.html has all required responsive meta tags'),
    'PWA install prompt handling': 
        successes.contains('PWA install prompt handling configured'),
    'App is installable as PWA': 
        successes.contains('PWA install prompt handling configured') &&
        successes.contains('manifest.json exists with all required fields'),
  };
  
  for (final entry in criteria.entries) {
    final status = entry.value ? '✅' : '❌';
    print('$status ${entry.key}');
  }
  
  final allCriteriaMet = criteria.values.every((v) => v);
  print('\n' + '=' * 60);
  if (allCriteriaMet) {
    print('🎉 All acceptance criteria met!');
    print('✅ Web Platform Settings configuration is complete.');
  } else {
    print('⚠️  Some acceptance criteria are not met.');
    print('Please review the errors and warnings above.');
  }
  print('=' * 60);
  
  exit(allCriteriaMet ? 0 : 1);
}
