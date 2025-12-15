#!/usr/bin/env python3
"""Debug script to test sync behavior"""

import sys
from pathlib import Path
from confluence_sync import ConfluenceSync, MarkdownConverter

# Test directory
test_dir = r"C:\Users\svetlin.chobanov\OneDrive - Paynetics\Documents\Cursor\Project\Outputs\Wallets\Wallets-2.0-Pages"

# Test a sample file
sample_file = Path(test_dir) / "01-Onboarding-and-Authentication" / "Authentication-and-Security-Management.md"

if sample_file.exists():
    content = sample_file.read_text(encoding='utf-8')
    print(f"File: {sample_file.name}")
    print(f"Content length: {len(content)} chars")
    print(f"First 200 chars: {content[:200]}")
    print()
    
    # Test title extraction
    title = MarkdownConverter.extract_title(content, sample_file.name)
    print(f"Extracted title: '{title}'")
    
    # Test content conversion
    converted = MarkdownConverter.markdown_to_confluence(content)
    print(f"Converted content length: {len(converted)} chars")
    print(f"First 200 chars of converted: {converted[:200]}")
    print()
    
    # Test directory name sanitization
    dir_name = "01-Onboarding-and-Authentication"
    dir_title = MarkdownConverter.sanitize_title(dir_name, strict=True)
    print(f"Directory: {dir_name}")
    print(f"Sanitized title: '{dir_title}'")
else:
    print(f"File not found: {sample_file}")
