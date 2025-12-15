#!/usr/bin/env python3
"""
Delete Confluence Pages Tool

This program deletes Confluence pages listed in a JSON file created by confluence_sync.py.
The JSON file contains a list of page IDs that were created during a sync run.
"""

import json
import sys
import logging
import argparse
from pathlib import Path
from typing import List, Dict, Optional
from datetime import datetime

try:
    from atlassian import Confluence
except ImportError:
    print("Error: atlassian-python-api library is required.")
    print("Install it with: pip install atlassian-python-api")
    sys.exit(1)

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.StreamHandler(),
        logging.FileHandler('delete_pages.log', encoding='utf-8')
    ]
)
logger = logging.getLogger(__name__)


def load_pages_list(json_file: Path) -> Optional[Dict]:
    """Load the created pages list from JSON file."""
    try:
        with open(json_file, 'r', encoding='utf-8') as f:
            data = json.load(f)
        return data
    except FileNotFoundError:
        logger.error(f"File not found: {json_file}")
        return None
    except json.JSONDecodeError as e:
        logger.error(f"Invalid JSON in file {json_file}: {e}")
        return None
    except Exception as e:
        logger.error(f"Error reading file {json_file}: {e}")
        return None


def delete_pages(
    confluence: Confluence,
    pages: List[Dict],
    dry_run: bool = False
) -> tuple[int, int]:
    """
    Delete pages from Confluence.
    
    Args:
        confluence: Confluence API client
        pages: List of page dictionaries with 'page_id' and 'title'
        dry_run: If True, only preview deletions without executing
        
    Returns:
        Tuple of (successful_deletions, failed_deletions)
    """
    successful = 0
    failed = 0
    
    if not pages:
        logger.info("No pages to delete.")
        return 0, 0
    
    print(f"\n{'='*80}")
    print(f"{'DRY RUN - ' if dry_run else ''}Deleting {len(pages)} page(s)")
    print(f"{'='*80}\n")
    
    for i, page_info in enumerate(pages, 1):
        page_id = page_info.get('page_id')
        page_title = page_info.get('title', 'Unknown')
        space = page_info.get('space', 'Unknown')
        
        if not page_id:
            logger.warning(f"Page {i}/{len(pages)}: Missing page_id, skipping")
            failed += 1
            continue
        
        try:
            if dry_run:
                logger.info(f"[DRY RUN] Would delete page {i}/{len(pages)}: '{page_title}' (ID: {page_id}, Space: {space})")
                successful += 1
            else:
                # Get current page info before deletion
                try:
                    current_page = confluence.get_page_by_id(page_id)
                    current_title = current_page.get('title', page_title)
                    logger.info(f"Deleting page {i}/{len(pages)}: '{current_title}' (ID: {page_id}, Space: {space})")
                except Exception as e:
                    logger.warning(f"Could not get page info for {page_id}: {e}")
                    logger.info(f"Deleting page {i}/{len(pages)}: '{page_title}' (ID: {page_id}, Space: {space})")
                
                # Delete the page
                confluence.remove_page(page_id)
                logger.info(f"[OK] Successfully deleted page '{page_title}' (ID: {page_id})")
                print(f"[OK] Successfully deleted page '{page_title}' (ID: {page_id})")
                successful += 1
                
        except Exception as e:
            error_msg = str(e)
            logger.error(f"[FAIL] Failed to delete page '{page_title}' (ID: {page_id}): {error_msg}")
            print(f"[FAIL] Failed to delete page '{page_title}' (ID: {page_id}): {error_msg}")
            failed += 1
    
    return successful, failed


def main():
    """Main entry point."""
    parser = argparse.ArgumentParser(
        description='Delete Confluence pages listed in a JSON file created by confluence_sync.py'
    )
    
    parser.add_argument(
        'json_file',
        type=str,
        help='Path to JSON file containing created pages list (e.g., created_pages_20231215_143022.json)'
    )
    
    parser.add_argument(
        '--url',
        required=True,
        help='Confluence instance URL (e.g., https://your-domain.atlassian.net)'
    )
    
    parser.add_argument(
        '--username',
        required=True,
        help='Confluence username or email'
    )
    
    parser.add_argument(
        '--api-token',
        required=True,
        help='Confluence API token'
    )
    
    parser.add_argument(
        '--dry-run',
        action='store_true',
        help='Preview deletions without actually deleting'
    )
    
    args = parser.parse_args()
    
    try:
        logger.info(f"Script started with arguments: {sys.argv}")
    except:
        pass  # If logging fails, continue anyway
    
    json_file = Path(args.json_file)
    dry_run = args.dry_run
    confluence_url = args.url
    username = args.username
    api_token = args.api_token
    
    # Load pages list
    logger.info(f"Loading pages list from: {json_file}")
    print(f"\nLoading pages list from: {json_file}")
    
    if not json_file.exists():
        error_msg = f"Error: File not found: {json_file}"
        logger.error(error_msg)
        print(error_msg)
        print(f"Current directory: {Path.cwd()}")
        sys.exit(1)
    
    data = load_pages_list(json_file)
    
    if not data:
        error_msg = "Failed to load pages list. Exiting."
        logger.error(error_msg)
        print(f"\n{error_msg}")
        print("Please check that the JSON file is valid and try again.")
        sys.exit(1)
    
    logger.info("Successfully loaded pages list")
    
    # Display file info
    try:
        print(f"\n{'='*80}")
        print("DELETE PAGES FROM CONFLUENCE")
        print(f"{'='*80}")
        print(f"File: {json_file}")
        print(f"Timestamp: {data.get('timestamp', 'Unknown')}")
        print(f"Root Page: {data.get('root_page_title', 'Unknown')} (ID: {data.get('root_page_id', 'Unknown')})")
        print(f"Directory: {data.get('directory_path', 'Unknown')}")
        print(f"Pages to delete: {len(data.get('created_pages', []))}")
        print(f"{'='*80}")
        logger.info(f"Displayed file info. Pages to delete: {len(data.get('created_pages', []))}")
    except Exception as e:
        logger.error(f"Error displaying file info: {e}", exc_info=True)
        print(f"\nError displaying file info: {e}")
        sys.exit(1)
    
    pages = data.get('created_pages', [])
    logger.info(f"Found {len(pages)} pages in the list")
    
    if not pages:
        logger.info("No pages found in the list.")
        print("\nNo pages found in the list. Nothing to delete.")
        sys.exit(0)
    
    # Display pages that will be deleted
    try:
        print("\nPages to be deleted:")
        for i, page_info in enumerate(pages, 1):
            page_id = page_info.get('page_id', 'Unknown')
            title = page_info.get('title', 'Unknown')
            space = page_info.get('space', 'Unknown')
            print(f"  {i}. {title} (ID: {page_id}, Space: {space})")
        logger.info(f"Displayed {len(pages)} pages to be deleted")
    except Exception as e:
        logger.error(f"Error displaying pages list: {e}", exc_info=True)
        print(f"\nError displaying pages list: {e}")
        sys.exit(1)
    
    # Confirm deletion (unless dry run)
    if not dry_run:
        print(f"\n[WARNING] This will permanently delete {len(pages)} page(s) from Confluence!")
        print("Type 'yes' to confirm, or anything else to cancel.")
        try:
            confirm = input("Are you sure you want to proceed? (yes/no): ").strip().lower()
        except (EOFError, KeyboardInterrupt):
            print("\nOperation cancelled - no input available.")
            logger.info("Deletion cancelled - EOF/KeyboardInterrupt during confirmation.")
            sys.exit(0)
        
        if confirm not in ['yes', 'y']:
            print(f"\nDeletion cancelled. (You entered: '{confirm}')")
            logger.info(f"Deletion cancelled by user. (Input: '{confirm}')")
            sys.exit(0)
    
    # Initialize Confluence client
    try:
        logger.info(f"Connecting to Confluence at {confluence_url}...")
        confluence = Confluence(
            url=confluence_url,
            username=username,
            password=api_token,
            cloud=True
        )
        # Test connection by getting the root page from the JSON file
        root_page_id = data.get('root_page_id')
        if root_page_id:
            try:
                confluence.get_page_by_id(root_page_id)
                logger.info("[OK] Successfully connected to Confluence")
                print("\n[OK] Successfully connected to Confluence")
            except Exception as e:
                error_msg = f"Failed to verify connection to Confluence (could not access root page {root_page_id}): {e}"
                logger.error(error_msg, exc_info=True)
                print(f"\n[FAIL] {error_msg}")
                print("Please check your URL, username, and API token.")
                sys.exit(1)
        else:
            # If no root_page_id in JSON, just log a warning but continue
            logger.warning("No root_page_id found in JSON file, skipping connection test")
            print("\n[OK] Connected to Confluence (connection test skipped - no root_page_id in JSON)")
    except Exception as e:
        error_msg = f"Failed to connect to Confluence: {e}"
        logger.error(error_msg, exc_info=True)
        print(f"\n[FAIL] {error_msg}")
        print("Please check your URL, username, and API token.")
        sys.exit(1)
    
    # Delete pages
    print("\n" + "="*80)
    successful, failed = delete_pages(confluence, pages, dry_run=dry_run)
    
    # Summary
    print("\n" + "="*80)
    if dry_run:
        print("DRY RUN COMPLETED")
    else:
        print("DELETION COMPLETED")
    print("="*80)
    print(f"[OK] Successfully deleted: {successful}")
    if failed > 0:
        print(f"[FAIL] Failed: {failed}")
    print("="*80)
    
    logger.info(f"Deletion completed: {successful} successful, {failed} failed")
    
    if failed > 0:
        sys.exit(1)


if __name__ == "__main__":
    try:
        main()
    except Exception as e:
        logger.error(f"Unhandled exception in main: {e}", exc_info=True)
        print(f"\nFatal error: {e}")
        print("Check delete_pages.log for details.")
        sys.exit(1)

