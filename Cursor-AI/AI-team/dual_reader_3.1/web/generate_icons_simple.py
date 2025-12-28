#!/usr/bin/env python3
"""
Generate PWA icons for Dual Reader 3.1
Creates simple placeholder icons using PIL/Pillow
"""

import os
from PIL import Image, ImageDraw, ImageFont

# Icon sizes required for PWA
ICON_SIZES = [16, 32, 72, 96, 128, 144, 152, 192, 384, 512]

# Colors (Material Blue #1976D2)
BACKGROUND_COLOR = (25, 118, 210)  # RGB
FOREGROUND_COLOR = (255, 255, 255)  # White

def create_icon(size, output_path):
    """Create a single icon"""
    # Create image with background
    img = Image.new('RGB', (size, size), BACKGROUND_COLOR)
    draw = ImageDraw.Draw(img)
    
    # Draw a simple book icon
    padding = int(size * 0.2)
    icon_size = size - (padding * 2)
    icon_x = padding
    icon_y = padding
    
    # Draw open book (two pages)
    page_width = icon_size // 2
    stroke_width = max(1, size // 16)
    
    # Left page
    draw.rectangle(
        [icon_x, icon_y, icon_x + page_width, icon_y + icon_size],
        outline=FOREGROUND_COLOR,
        width=stroke_width
    )
    
    # Right page
    draw.rectangle(
        [icon_x + page_width, icon_y, icon_x + icon_size, icon_y + icon_size],
        outline=FOREGROUND_COLOR,
        width=stroke_width
    )
    
    # Center binding line
    center_x = icon_x + page_width
    draw.line(
        [center_x, icon_y, center_x, icon_y + icon_size],
        fill=FOREGROUND_COLOR,
        width=stroke_width
    )
    
    # Save icon
    img.save(output_path, 'PNG')
    print(f'✓ Created: {output_path} ({size}x{size})')

def main():
    print('Generating PWA icons for Dual Reader 3.1...\n')
    
    # Ensure icons directory exists
    icons_dir = 'icons'
    if not os.path.exists(icons_dir):
        os.makedirs(icons_dir)
    
    # Generate all icon sizes
    for size in ICON_SIZES:
        output_path = os.path.join(icons_dir, f'icon-{size}.png')
        create_icon(size, output_path)
    
    # Generate favicon
    favicon_path = 'favicon.png'
    create_icon(32, favicon_path)
    
    print('\n✓ All icons generated successfully!')
    print('\nNote: These are placeholder icons. Replace them with your final')
    print('      icon designs for production use.')

if __name__ == '__main__':
    try:
        main()
    except ImportError:
        print('Error: PIL/Pillow not installed.')
        print('Install with: pip install Pillow')
        exit(1)
    except Exception as e:
        print(f'Error: {e}')
        exit(1)
