/**
 * Simple Icon Generator for Dual Reader 3.1 PWA
 * Generates placeholder icons using Node.js and Canvas API
 * 
 * Usage: node generate_icons_simple.js
 * 
 * Requirements: npm install canvas
 */

const fs = require('fs');
const path = require('path');

// Icon sizes required for PWA
const ICON_SIZES = [16, 32, 72, 96, 128, 144, 152, 192, 384, 512];

// Colors
const BACKGROUND_COLOR = '#1976D2'; // Material Blue
const TEXT_COLOR = '#FFFFFF'; // White

const ICONS_DIR = path.join(__dirname, 'icons');
const WEB_DIR = __dirname;

// Try to use canvas, fallback to creating SVG icons
let canvas, createCanvas, loadImage;
try {
  const canvasModule = require('canvas');
  createCanvas = canvasModule.createCanvas;
  loadImage = canvasModule.loadImage;
  console.log('Using canvas module for icon generation...');
} catch (e) {
  console.log('Canvas module not found. Creating SVG icons instead...');
  console.log('To generate PNG icons, install canvas: npm install canvas');
}

function createSVGIcon(size) {
  const fontSize = Math.max(12, Math.floor(size * 0.4));
  return `<?xml version="1.0" encoding="UTF-8"?>
<svg width="${size}" height="${size}" xmlns="http://www.w3.org/2000/svg">
  <rect width="${size}" height="${size}" fill="${BACKGROUND_COLOR}"/>
  <text x="50%" y="50%" font-family="Arial, sans-serif" font-size="${fontSize}" font-weight="bold" 
        fill="${TEXT_COLOR}" text-anchor="middle" dominant-baseline="middle">DR</text>
</svg>`;
}

function createPNGIcon(size) {
  return new Promise((resolve, reject) => {
    try {
      const canvas = createCanvas(size, size);
      const ctx = canvas.getContext('2d');
      
      // Fill background
      ctx.fillStyle = BACKGROUND_COLOR;
      ctx.fillRect(0, 0, size, size);
      
      // Draw text
      const fontSize = Math.max(12, Math.floor(size * 0.4));
      ctx.font = `bold ${fontSize}px Arial`;
      ctx.fillStyle = TEXT_COLOR;
      ctx.textAlign = 'center';
      ctx.textBaseline = 'middle';
      ctx.fillText('DR', size / 2, size / 2);
      
      // Convert to PNG buffer
      const buffer = canvas.toBuffer('image/png');
      resolve(buffer);
    } catch (error) {
      reject(error);
    }
  });
}

async function generateIcons() {
  console.log('Generating PWA icons for Dual Reader 3.1...');
  console.log(`Output directory: ${ICONS_DIR}\n`);
  
  // Ensure icons directory exists
  if (!fs.existsSync(ICONS_DIR)) {
    fs.mkdirSync(ICONS_DIR, { recursive: true });
  }
  
  const usePNG = typeof createCanvas !== 'undefined';
  
  for (const size of ICON_SIZES) {
    const filename = `icon-${size}x${size}.${usePNG ? 'png' : 'svg'}`;
    const filepath = path.join(ICONS_DIR, filename);
    
    try {
      if (usePNG) {
        const buffer = await createPNGIcon(size);
        fs.writeFileSync(filepath, buffer);
        console.log(`✓ Created: ${filename} (${size}x${size})`);
      } else {
        const svg = createSVGIcon(size);
        fs.writeFileSync(filepath, svg, 'utf8');
        console.log(`✓ Created: ${filename} (${size}x${size}) [SVG]`);
      }
    } catch (error) {
      console.error(`✗ Failed to create ${filename}:`, error.message);
    }
  }
  
  // Create favicon
  const faviconPath = path.join(WEB_DIR, 'favicon.png');
  try {
    if (usePNG) {
      const buffer = await createPNGIcon(32);
      fs.writeFileSync(faviconPath, buffer);
      console.log(`✓ Created: favicon.png`);
    } else {
      // For SVG, copy the 32x32 icon
      const svgIcon = createSVGIcon(32);
      fs.writeFileSync(faviconPath.replace('.png', '.svg'), svgIcon, 'utf8');
      console.log(`✓ Created: favicon.svg`);
    }
  } catch (error) {
    console.error(`✗ Failed to create favicon:`, error.message);
  }
  
  console.log('\n✓ Icon generation complete!');
  if (!usePNG) {
    console.log('\nNote: SVG icons were created. For PNG icons, install canvas:');
    console.log('  npm install canvas');
    console.log('\nOr use the browser-based generator:');
    console.log('  Open web/icons/generate_icons.html in a web browser');
  } else {
    console.log('\nNote: These are placeholder icons with "DR" text.');
    console.log('      Replace them with your final icon designs for production.');
  }
}

// Run if executed directly
if (require.main === module) {
  generateIcons().catch(console.error);
}

module.exports = { generateIcons };
