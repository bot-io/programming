/**
 * Icon Generator for Dual Reader 3.1
 * Generates PWA icons using Node.js and canvas
 * 
 * Usage: node generate_icons_node.js
 * 
 * Requirements: npm install canvas
 */

const fs = require('fs');
const path = require('path');

// Check if canvas is available
let canvas;
try {
  canvas = require('canvas');
} catch (e) {
  console.error('Error: canvas module not found.');
  console.error('Install it with: npm install canvas');
  console.error('\nAlternatively, use the PowerShell script:');
  console.error('  powershell -File generate_icons_dotnet.ps1');
  process.exit(1);
}

const { createCanvas } = canvas;

// Icon sizes required for PWA
const ICON_SIZES = [16, 32, 72, 96, 128, 144, 152, 192, 384, 512];

// Colors
const BACKGROUND_COLOR = '#1976D2'; // Material Blue
const TEXT_COLOR = '#FFFFFF'; // White

/**
 * Create an icon with the specified size
 */
function createIcon(size) {
  const canvas = createCanvas(size, size);
  const ctx = canvas.getContext('2d');
  
  // Fill background
  ctx.fillStyle = BACKGROUND_COLOR;
  ctx.fillRect(0, 0, size, size);
  
  // Draw text
  ctx.fillStyle = TEXT_COLOR;
  const fontSize = Math.max(12, Math.floor(size * 0.4));
  ctx.font = `bold ${fontSize}px Arial`;
  ctx.textAlign = 'center';
  ctx.textBaseline = 'middle';
  ctx.fillText('DR', size / 2, size / 2);
  
  return canvas;
}

/**
 * Generate all icons
 */
function generateIcons() {
  const iconsDir = path.join(__dirname, 'icons');
  
  // Create icons directory if it doesn't exist
  if (!fs.existsSync(iconsDir)) {
    fs.mkdirSync(iconsDir, { recursive: true });
    console.log(`Created icons directory: ${iconsDir}`);
  }
  
  console.log('Generating PWA icons for Dual Reader 3.1...\n');
  
  // Generate all icon sizes
  for (const size of ICON_SIZES) {
    const canvas = createIcon(size);
    const outputPath = path.join(iconsDir, `icon-${size}x${size}.png`);
    const buffer = canvas.toBuffer('image/png');
    fs.writeFileSync(outputPath, buffer);
    console.log(`  ✓ Generated icon-${size}x${size}.png`);
  }
  
  // Create favicon.png in web root
  const faviconCanvas = createIcon(32);
  const faviconPath = path.join(__dirname, 'favicon.png');
  const faviconBuffer = faviconCanvas.toBuffer('image/png');
  fs.writeFileSync(faviconPath, faviconBuffer);
  console.log(`  ✓ Generated favicon.png`);
  
  console.log('\n✓ All icons generated successfully!');
  console.log('\nNote: These are placeholder icons. Replace them with your final');
  console.log('      icon designs for production use.');
}

// Run
try {
  generateIcons();
} catch (error) {
  console.error('Error generating icons:', error.message);
  process.exit(1);
}
