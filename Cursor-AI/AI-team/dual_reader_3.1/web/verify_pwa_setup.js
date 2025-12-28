/**
 * PWA Configuration Verification Script for Dual Reader 3.1
 * 
 * This script verifies that all PWA requirements are met:
 * - manifest.json exists and is valid
 * - Service worker is configured
 * - Icons are present
 * - Meta tags are configured in index.html
 * 
 * Usage: node verify_pwa_setup.js
 */

const fs = require('fs');
const path = require('path');

const WEB_DIR = __dirname;
const ICONS_DIR = path.join(WEB_DIR, 'icons');

// Required icon sizes
const REQUIRED_ICON_SIZES = [16, 32, 72, 96, 128, 144, 152, 192, 384, 512];

// Required files
const REQUIRED_FILES = {
  'index.html': 'Main HTML file with PWA meta tags',
  'manifest.json': 'PWA manifest file',
  'service-worker.js': 'Service worker for offline support',
  'browserconfig.xml': 'Windows tile configuration',
  'favicon.png': 'Favicon file',
};

const checks = {
  passed: 0,
  failed: 0,
  warnings: 0,
};

function checkFile(filepath, description) {
  const fullPath = path.join(WEB_DIR, filepath);
  if (fs.existsSync(fullPath)) {
    console.log(`✓ ${description}: ${filepath}`);
    checks.passed++;
    return true;
  } else {
    console.log(`✗ ${description}: ${filepath} - MISSING`);
    checks.failed++;
    return false;
  }
}

function checkManifest() {
  console.log('\n📋 Checking manifest.json...');
  const manifestPath = path.join(WEB_DIR, 'manifest.json');
  
  if (!fs.existsSync(manifestPath)) {
    console.log('✗ manifest.json not found');
    checks.failed++;
    return false;
  }
  
  try {
    const manifestContent = fs.readFileSync(manifestPath, 'utf8');
    const manifest = JSON.parse(manifestContent);
    
    // Check required fields
    const requiredFields = ['name', 'short_name', 'start_url', 'display', 'icons'];
    let allFieldsPresent = true;
    
    for (const field of requiredFields) {
      if (!manifest[field]) {
        console.log(`✗ Missing required field: ${field}`);
        checks.failed++;
        allFieldsPresent = false;
      }
    }
    
    if (allFieldsPresent) {
      console.log('✓ manifest.json has all required fields');
      checks.passed++;
    }
    
    // Check icons
    if (manifest.icons && Array.isArray(manifest.icons)) {
      console.log(`✓ manifest.json references ${manifest.icons.length} icons`);
      checks.passed++;
    } else {
      console.log('✗ manifest.json missing icons array');
      checks.failed++;
    }
    
    // Check for 192x192 and 512x512 icons (required for PWA)
    const has192 = manifest.icons?.some(icon => icon.sizes === '192x192');
    const has512 = manifest.icons?.some(icon => icon.sizes === '512x512');
    
    if (has192 && has512) {
      console.log('✓ Required icon sizes (192x192, 512x512) found in manifest');
      checks.passed++;
    } else {
      if (!has192) {
        console.log('⚠ Missing 192x192 icon in manifest (required for Android)');
        checks.warnings++;
      }
      if (!has512) {
        console.log('⚠ Missing 512x512 icon in manifest (required for PWA)');
        checks.warnings++;
      }
    }
    
    return allFieldsPresent;
  } catch (error) {
    console.log(`✗ Error parsing manifest.json: ${error.message}`);
    checks.failed++;
    return false;
  }
}

function checkServiceWorker() {
  console.log('\n🔧 Checking service worker...');
  const swPath = path.join(WEB_DIR, 'service-worker.js');
  
  if (!fs.existsSync(swPath)) {
    console.log('✗ service-worker.js not found');
    checks.failed++;
    return false;
  }
  
  const swContent = fs.readFileSync(swPath, 'utf8');
  
  // Check for essential service worker features
  const requiredFeatures = [
    'install',
    'activate',
    'fetch',
  ];
  
  let allFeaturesPresent = true;
  for (const feature of requiredFeatures) {
    if (swContent.includes(`addEventListener('${feature}'`)) {
      console.log(`✓ Service worker handles '${feature}' event`);
      checks.passed++;
    } else {
      console.log(`⚠ Service worker missing '${feature}' event handler`);
      checks.warnings++;
      allFeaturesPresent = false;
    }
  }
  
  // Check for caching strategy
  if (swContent.includes('cache') || swContent.includes('Cache')) {
    console.log('✓ Service worker implements caching');
    checks.passed++;
  } else {
    console.log('⚠ Service worker may not implement caching');
    checks.warnings++;
  }
  
  return allFeaturesPresent;
}

function checkIcons() {
  console.log('\n🖼️  Checking icons...');
  
  let iconsFound = 0;
  let iconsMissing = 0;
  
  for (const size of REQUIRED_ICON_SIZES) {
    const iconPath = path.join(ICONS_DIR, `icon-${size}x${size}.png`);
    if (fs.existsSync(iconPath)) {
      iconsFound++;
    } else {
      // Check for SVG fallback
      const svgPath = path.join(ICONS_DIR, `icon-${size}x${size}.svg`);
      if (fs.existsSync(svgPath)) {
        console.log(`⚠ icon-${size}x${size}.png missing, but SVG found (convert to PNG for production)`);
        checks.warnings++;
      } else {
        console.log(`✗ icon-${size}x${size}.png - MISSING`);
        iconsMissing++;
      }
    }
  }
  
  if (iconsFound === REQUIRED_ICON_SIZES.length) {
    console.log(`✓ All ${REQUIRED_ICON_SIZES.length} required icons found`);
    checks.passed++;
  } else if (iconsFound > 0) {
    console.log(`⚠ Found ${iconsFound}/${REQUIRED_ICON_SIZES.length} icons`);
    checks.warnings++;
  } else {
    console.log(`✗ No icons found (${iconsMissing} missing)`);
    checks.failed++;
  }
  
  // Check critical icons
  const criticalIcons = [192, 512];
  let criticalFound = 0;
  for (const size of criticalIcons) {
    const iconPath = path.join(ICONS_DIR, `icon-${size}x${size}.png`);
    if (fs.existsSync(iconPath)) {
      criticalFound++;
      console.log(`✓ Critical icon icon-${size}x${size}.png found`);
      checks.passed++;
    } else {
      console.log(`✗ Critical icon icon-${size}x${size}.png MISSING (required for PWA)`);
      checks.failed++;
    }
  }
  
  return iconsFound === REQUIRED_ICON_SIZES.length;
}

function checkIndexHtml() {
  console.log('\n📄 Checking index.html...');
  const indexPath = path.join(WEB_DIR, 'index.html');
  
  if (!fs.existsSync(indexPath)) {
    console.log('✗ index.html not found');
    checks.failed++;
    return false;
  }
  
  const htmlContent = fs.readFileSync(indexPath, 'utf8');
  
  // Check for required meta tags
  const requiredMetaTags = [
    { name: 'viewport', description: 'Viewport meta tag' },
    { name: 'theme-color', description: 'Theme color meta tag' },
  ];
  
  let allTagsPresent = true;
  for (const tag of requiredMetaTags) {
    const regex = new RegExp(`<meta[^>]*name=["']${tag.name}["']`, 'i');
    if (regex.test(htmlContent)) {
      console.log(`✓ ${tag.description} found`);
      checks.passed++;
    } else {
      console.log(`✗ ${tag.description} missing`);
      checks.failed++;
      allTagsPresent = false;
    }
  }
  
  // Check for manifest link
  if (htmlContent.includes('manifest.json')) {
    console.log('✓ manifest.json linked in index.html');
    checks.passed++;
  } else {
    console.log('✗ manifest.json not linked in index.html');
    checks.failed++;
    allTagsPresent = false;
  }
  
  // Check for service worker registration
  if (htmlContent.includes('serviceWorker') || htmlContent.includes('service-worker')) {
    console.log('✓ Service worker registration found in index.html');
    checks.passed++;
  } else {
    console.log('⚠ Service worker registration not found in index.html');
    checks.warnings++;
  }
  
  return allTagsPresent;
}

function main() {
  console.log('🔍 Verifying PWA Configuration for Dual Reader 3.1\n');
  console.log('='.repeat(60));
  
  // Check required files
  console.log('\n📁 Checking required files...');
  for (const [file, description] of Object.entries(REQUIRED_FILES)) {
    checkFile(file, description);
  }
  
  // Check manifest
  checkManifest();
  
  // Check service worker
  checkServiceWorker();
  
  // Check icons
  checkIcons();
  
  // Check index.html
  checkIndexHtml();
  
  // Summary
  console.log('\n' + '='.repeat(60));
  console.log('\n📊 Verification Summary:');
  console.log(`   ✓ Passed: ${checks.passed}`);
  console.log(`   ✗ Failed: ${checks.failed}`);
  console.log(`   ⚠ Warnings: ${checks.warnings}`);
  
  if (checks.failed === 0 && checks.warnings === 0) {
    console.log('\n✅ All checks passed! PWA configuration is complete.');
    process.exit(0);
  } else if (checks.failed === 0) {
    console.log('\n⚠️  Configuration is functional but has warnings.');
    console.log('   Review warnings above and fix them for production.');
    process.exit(0);
  } else {
    console.log('\n❌ Configuration has errors. Please fix the issues above.');
    process.exit(1);
  }
}

if (require.main === module) {
  main();
}

module.exports = { checkManifest, checkServiceWorker, checkIcons, checkIndexHtml };
