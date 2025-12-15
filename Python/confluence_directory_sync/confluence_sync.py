#!/usr/bin/env python3
"""
Directory to Confluence Sync Tool

This program synchronizes Markdown files from a local directory structure
to Confluence pages, maintaining the directory hierarchy.
"""

import os
import sys
import json
import logging
from pathlib import Path
from typing import Dict, List, Optional, Tuple, Set
from dataclasses import dataclass, field
from enum import Enum
import re

try:
    from atlassian import Confluence
    import markdown
    from markdown.extensions import codehilite, tables, fenced_code
    from bs4 import BeautifulSoup
except ImportError as e:
    print(f"Error: Missing required dependency. Please install requirements: {e}")
    print("Run: pip install -r requirements.txt")
    sys.exit(1)


# Configure logging - will be set up in main() or setup_logging()
# Set up basic console logging by default (for backward compatibility)
# This will be overridden by setup_logging() if called
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    force=True  # Override any existing configuration
)
logger = logging.getLogger(__name__)


def setup_logging(log_file: Optional[str] = None, log_level: int = logging.INFO) -> None:
    """
    Configure logging to both console and file.
    
    Args:
        log_file: Optional path to log file. If None, logs only to console.
        log_level: Logging level (default: INFO)
    """
    # Clear any existing handlers
    logger.handlers.clear()
    root_logger = logging.getLogger()
    # Close and remove existing handlers
    for handler in root_logger.handlers[:]:
        handler.close()
        root_logger.removeHandler(handler)
    
    # Create formatter
    formatter = logging.Formatter('%(asctime)s - %(levelname)s - %(message)s')
    
    # Console handler (always)
    console_handler = logging.StreamHandler(sys.stdout)
    console_handler.setLevel(log_level)
    console_handler.setFormatter(formatter)
    root_logger.addHandler(console_handler)
    
    # File handler (if log_file is provided)
    if log_file:
        try:
            log_path = Path(log_file)
            # Create parent directory if it doesn't exist
            log_path.parent.mkdir(parents=True, exist_ok=True)
            
            file_handler = logging.FileHandler(log_path, mode='a', encoding='utf-8')
            file_handler.setLevel(log_level)
            file_handler.setFormatter(formatter)
            root_logger.addHandler(file_handler)
            
            root_logger.info(f"Logging to file: {log_path.absolute()}")
        except Exception as e:
            # Use print since logging might not be set up yet
            root_logger.warning(f"Failed to set up file logging to '{log_file}': {e}. Logging to console only.")
    
    root_logger.setLevel(log_level)


class OperationType(Enum):
    """Types of operations that can be performed."""
    CREATE = "create"
    UPDATE = "update"
    DELETE = "delete"


@dataclass
class PageOperation:
    """Represents an operation to be performed on a Confluence page."""
    operation: OperationType
    title: str
    path: Path
    parent_id: Optional[str] = None
    content: Optional[str] = None
    page_id: Optional[str] = None
    old_title: Optional[str] = None


@dataclass
class SyncState:
    """Tracks the state of a sync operation for rollback purposes."""
    created_pages: List[str] = field(default_factory=list)
    updated_pages: List[Tuple[str, int]] = field(default_factory=list)  # (page_id, old_version)
    deleted_pages: List[Dict] = field(default_factory=list)  # Store page data for restoration


class MarkdownConverter:
    """Converts Markdown content to Confluence storage format."""
    
    @staticmethod
    def extract_title(markdown_content: str, filename: str) -> str:
        """
        Extract title from Markdown content.
        Returns the first H1 heading (# Title) or falls back to filename.
        Prioritizes H1 headings over H2+ headings.
        Handles BOM (Byte Order Mark) characters at the start of files.
        """
        # Remove BOM if present
        if markdown_content.startswith('\ufeff'):
            markdown_content = markdown_content[1:]
        
        lines = markdown_content.strip().split('\n')
        
        # First pass: look for H1 heading (single #)
        for line in lines:
            line = line.strip()
            # Remove BOM if still present after split
            if line.startswith('\ufeff'):
                line = line[1:].strip()
            # Match H1 heading: starts with # but not ##
            if line.startswith('#') and not line.startswith('##'):
                # Remove # and any leading/trailing whitespace
                title = re.sub(r'^#+\s*', '', line).strip()
                if title:
                    return title
        
        # Second pass: if no H1 found, look for any heading (fallback)
        for line in lines:
            line = line.strip()
            # Remove BOM if still present after split
            if line.startswith('\ufeff'):
                line = line[1:].strip()
            if line.startswith('#'):
                # Remove # and any leading/trailing whitespace
                title = re.sub(r'^#+\s*', '', line).strip()
                if title:
                    return title
        
        # Final fallback: use filename without extension, converting dashes to spaces
        filename_title = Path(filename).stem
        # Convert dashes to spaces for better readability (e.g., "Authentication-and-Security-Management" -> "Authentication and Security Management")
        filename_title = filename_title.replace('-', ' ')
        return filename_title
    
    @staticmethod
    def sanitize_title(title: str, strict: bool = False) -> str:
        """
        Sanitize title for Confluence page title requirements.
        
        Args:
            title: The title to sanitize
            strict: If True, removes dashes and numbers (for directory names per requirements)
                   If False, keeps alphanumeric, spaces, and dashes (for file titles)
        """
        if strict:
            # For directory names: plain text only (no dashes, no numbers per requirements)
            # Keep only letters and spaces
            title = re.sub(r'[^a-zA-Z\s]', ' ', title)
        else:
            # For file titles: keep alphanumeric, spaces, and dashes
            title = re.sub(r'[^\w\s-]', ' ', title)
        
        # Replace multiple spaces with single space
        title = re.sub(r'\s+', ' ', title)
        # Remove leading/trailing spaces
        title = title.strip()
        # If empty after sanitization, use a default
        if not title:
            title = "Untitled"
        return title
    
    @staticmethod
    def markdown_to_confluence(markdown_content: str) -> str:
        """
        Convert Markdown content to Confluence storage format.
        
        Confluence storage format is XML-based. This converter:
        - Converts Markdown to HTML
        - Removes images (as per requirements)
        - Preserves links as-is
        - Wraps in Confluence storage format XML structure
        """
        # Configure markdown with extensions
        md = markdown.Markdown(
            extensions=[
                'codehilite',
                'tables',
                'fenced_code',
                'nl2br',
                'sane_lists'
            ]
        )
        
        # Convert markdown to HTML
        html = md.convert(markdown_content)
        
        # Parse HTML and process
        soup = BeautifulSoup(html, 'html.parser')
        
        # Remove images (as per requirements)
        for img in soup.find_all('img'):
            img.decompose()
        
        # Get body content - Confluence storage format expects XHTML without <body> tags
        # Extract content from body tag if present, otherwise use the entire soup
        if soup.body:
            # Extract children of body tag (don't include the body tag itself)
            body_content = ''.join(str(child) for child in soup.body.children)
        else:
            # No body tag, use the entire soup content
            body_content = str(soup)
        
        # Ensure we have valid content
        if not body_content or body_content.strip() == '':
            return ""
        
        # Return the HTML content - Confluence storage format accepts HTML/XHTML
        # The content should NOT include <html> or <body> tags, just the inner content
        return body_content.strip()


class ConfluenceSync:
    """Main class for synchronizing directory to Confluence."""
    
    def __init__(
        self,
        confluence_url: str,
        username: str,
        api_token: str,
        directory_path: str,
        root_page_id: str
    ):
        """
        Initialize the Confluence sync tool.
        
        Args:
            confluence_url: URL of Confluence instance (e.g., https://your-domain.atlassian.net)
            username: Confluence username or email
            api_token: Confluence API token
            directory_path: Path to directory containing Markdown files
            root_page_id: ID of the root Confluence page
        """
        self.confluence = Confluence(
            url=confluence_url,
            username=username,
            password=api_token,
            cloud=True
        )
        
        self.directory_path = Path(directory_path).resolve()
        self.root_page_id = str(root_page_id)
        
        if not self.directory_path.exists() or not self.directory_path.is_dir():
            raise ValueError(f"Invalid directory path: {directory_path}")
        
        # Verify root page exists and cache its title
        try:
            root_page = self.confluence.get_page_by_id(self.root_page_id)
            if not root_page:
                raise ValueError(f"Root page ID {root_page_id} not found or not accessible")
            self.root_page_title = root_page.get('title', 'Root Page')
        except Exception as e:
            raise ValueError(f"Error accessing root page {root_page_id}: {e}")
        
        self.converter = MarkdownConverter()
        self.sync_state = SyncState()
        
        # Cache for page mappings
        self.page_cache: Dict[str, Dict] = {}
        
        # Note: root_page_title is already set above (line 227)
    
    def _get_all_subpages(self, parent_id: str) -> Dict[str, Dict]:
        """
        Get all subpages under a parent page, recursively.
        Returns a dictionary mapping page paths to page data.
        Note: This uses a simplified path structure based on titles.
        """
        pages = {}
        
        def _recursive_get_pages(page_id: str, parent_path: str = "", parent_page_id: str = None):
            try:
                children = self.confluence.get_page_child_by_type(
                    page_id,
                    type='page',
                    start=0,
                    limit=100
                )
                
                if 'results' in children:
                    for page in children['results']:
                        page_title = page.get('title', '')
                        child_page_id = page.get('id', '')
                        full_path = f"{parent_path}/{page_title}" if parent_path else page_title
                        
                        # Get full page details to check parent
                        try:
                            full_page = self.confluence.get_page_by_id(child_page_id)
                            ancestors = full_page.get('ancestors', [])
                            actual_parent_id = ancestors[-1].get('id') if ancestors else None
                        except:
                            actual_parent_id = parent_page_id
                        
                        pages[full_path] = {
                            'id': child_page_id,
                            'title': page_title,
                            'version': page.get('version', {}).get('number', 1),
                            'parent_id': actual_parent_id,
                            'path': full_path
                        }
                        
                        # Recursively get children
                        _recursive_get_pages(child_page_id, full_path, child_page_id)
            except Exception as e:
                logger.warning(f"Error getting subpages for {page_id}: {e}")
        
        _recursive_get_pages(parent_id, "", parent_id)
        return pages
    
    def _traverse_directory(self) -> Tuple[Dict[Path, str], Dict[Path, List[Path]]]:
        """
        Traverse the directory and collect all Markdown files and subdirectories.
        
        Returns:
            Tuple of (file_map, dir_structure)
            - file_map: Dict mapping file paths to their content
            - dir_structure: Dict mapping directory paths to their contents
        """
        file_map = {}
        dir_structure = {}
        
        markdown_extensions = {'.md', '.markdown'}
        
        def _traverse(path: Path, relative_path: Path = None):
            if relative_path is None:
                relative_path = Path('.')
            
            dir_contents = []
            
            try:
                for item in sorted(path.iterdir()):
                    item_relative = relative_path / item.name
                    
                    if item.is_file() and item.suffix.lower() in markdown_extensions:
                        try:
                            content = item.read_text(encoding='utf-8')
                            file_map[item_relative] = content
                            dir_contents.append(item_relative)
                            logger.debug(f"Found Markdown file: {item_relative}")
                        except Exception as e:
                            logger.error(f"Error reading file {item}: {e}")
                    
                    elif item.is_dir():
                        dir_relative = item_relative
                        dir_structure[dir_relative] = []
                        dir_contents.append(dir_relative)
                        _traverse(item, dir_relative)
                        if dir_relative in dir_structure:
                            dir_contents.extend(dir_structure[dir_relative])
            
            except PermissionError as e:
                logger.error(f"Permission denied accessing {path}: {e}")
            except Exception as e:
                logger.error(f"Error traversing {path}: {e}")
            
            if relative_path != Path('.'):
                dir_structure[relative_path] = dir_contents
        
        _traverse(self.directory_path)
        return file_map, dir_structure
    
    def _build_operations(
        self,
        file_map: Dict[Path, str],
        dir_structure: Dict[Path, List[Path]]
    ) -> List[PageOperation]:
        """
        Build a list of operations needed to sync the directory to Confluence.
        """
        operations = []
        
        # Get all existing pages under root
        existing_pages = self._get_all_subpages(self.root_page_id)
        
        # Build a map of what should exist
        expected_pages: Set[str] = set()
        
        # Identify single-file directories (directories with exactly one file and no subdirectories)
        # These directories should not get their own page - the file should be created one level up
        single_file_directories: Set[Path] = set()
        
        for dir_path in dir_structure.keys():
            if dir_path == Path('.'):
                continue  # Skip root directory
            
            contents = dir_structure.get(dir_path, [])
            # Count files (have .md or .markdown extension) and subdirectories
            files = [item for item in contents if item in file_map]
            subdirs = [item for item in contents if item not in file_map and item in dir_structure]
            
            # If exactly one file and no subdirectories, mark as single-file directory
            if len(files) == 1 and len(subdirs) == 0:
                single_file_directories.add(dir_path)
                logger.debug(f"Directory '{dir_path}' is a single-file directory - will skip creating directory page")
        
        # Process directories first (to establish parent structure)
        for dir_path in sorted(dir_structure.keys()):
            dir_title = self.converter.sanitize_title(
                dir_path.name if dir_path != Path('.') else 'Root',
                strict=True  # Directory names: plain text only, no dashes, no numbers
            )
            dir_path_str = str(dir_path)
            
            # Determine parent
            if dir_path == Path('.'):
                parent_id = self.root_page_id
            else:
                parent_path = dir_path.parent
                if parent_path == Path('.'):
                    parent_id = self.root_page_id
                else:
                    # Find parent page ID
                    parent_title = self.converter.sanitize_title(parent_path.name)
                    parent_path_str = str(parent_path)
                    # This is simplified - in production, you'd need better path tracking
                    parent_id = None  # Will be resolved during execution
            
            expected_pages.add(dir_path_str)
            
            # Check if page exists - match by title and verify it's in the right location
            # For directories, we need to check if a page with this title exists under the expected parent
            page_exists = False
            matching_page = None
            
            for page_path, page_data in existing_pages.items():
                if page_data.get('title') == dir_title:
                    # Found a page with matching title - check if it's in the right location
                    # For now, we'll consider it a match (simplified - in production, verify parent hierarchy)
                    matching_page = page_data
                    page_exists = True
                    logger.debug(f"Found existing directory page: {dir_title} at {page_path}")
                    break
            
            # Skip creating directory page if it's a single-file directory
            if dir_path in single_file_directories:
                logger.debug(f"Skipping directory page creation for single-file directory: {dir_path}")
                continue
            
            if not page_exists:
                operations.append(PageOperation(
                    operation=OperationType.CREATE,
                    title=dir_title,
                    path=dir_path,
                    parent_id=parent_id,
                    content=""  # Empty page for directories
                ))
                logger.debug(f"Directory operation: {dir_path} -> title: '{dir_title}', parent_id: {parent_id}")
        
        # Process files
        for file_path, content in file_map.items():
            title = self.converter.extract_title(content, file_path.name)
            title = self.converter.sanitize_title(title, strict=False)  # File titles: more lenient
            file_path_str = str(file_path)
            
            expected_pages.add(file_path_str)
            
            # Determine parent
            parent_path = file_path.parent
            
            # If the file's parent directory is a single-file directory, use the directory's parent instead
            # Handle nested single-file directories by traversing up until we find a non-single-file directory
            actual_parent_path = parent_path
            while actual_parent_path in single_file_directories:
                actual_parent_path = actual_parent_path.parent
                if actual_parent_path == Path('.'):
                    break
            
            if actual_parent_path != parent_path:
                # We traversed up one or more single-file directories
                if actual_parent_path == Path('.'):
                    parent_id = self.root_page_id
                else:
                    parent_id = None  # Will be resolved during execution
                logger.debug(f"File '{file_path}' is in single-file directory chain - using '{actual_parent_path}' as parent (original: '{parent_path}')")
            else:
                # Normal case - not in a single-file directory
                if parent_path == Path('.'):
                    parent_id = self.root_page_id
                else:
                    parent_id = None  # Will be resolved during execution
            
            # Check if page exists - match by title
            # Note: We match by title only for now. If a page exists with the same title
            # but in the wrong location, it will be updated (which may not move it).
            # In a production system, you'd want to use metadata/labels to track file paths.
            existing_page = None
            for page_path, page_data in existing_pages.items():
                if page_data.get('title') == title:
                    existing_page = page_data
                    logger.debug(f"Found existing page with title '{title}' at path '{page_path}'")
                    break
            
            if existing_page:
                # Check if content needs updating
                try:
                    current_page = self.confluence.get_page_by_id(existing_page['id'])
                    current_content = current_page.get('body', {}).get('storage', {}).get('value', '')
                    
                    new_content = self.converter.markdown_to_confluence(content)
                    if current_content != new_content:
                        operations.append(PageOperation(
                            operation=OperationType.UPDATE,
                            title=title,
                            path=file_path,
                            parent_id=parent_id,
                            content=new_content,
                            page_id=existing_page['id']
                        ))
                except Exception as e:
                    logger.warning(f"Error checking page {existing_page['id']}: {e}")
                    operations.append(PageOperation(
                        operation=OperationType.UPDATE,
                        title=title,
                        path=file_path,
                        parent_id=parent_id,
                        content=self.converter.markdown_to_confluence(content),
                        page_id=existing_page['id']
                    ))
            else:
                # Convert markdown content to Confluence format
                converted_content = self.converter.markdown_to_confluence(content)
                
                # Verify conversion produced content
                if not converted_content or converted_content.strip() == "":
                    logger.warning(f"WARNING: Markdown conversion for {file_path.name} produced empty content!")
                    logger.warning(f"Original content length: {len(content)} chars")
                
                operations.append(PageOperation(
                    operation=OperationType.CREATE,
                    title=title,
                    path=file_path,
                    parent_id=parent_id,
                    content=converted_content
                ))
                logger.debug(f"File operation: {file_path.name} -> title: {title}, parent: {parent_path}, content length: {len(converted_content)}")
        
        # Find pages to delete (exist in Confluence but not in directory)
        for page_path, page_data in existing_pages.items():
            if page_path not in expected_pages:
                operations.append(PageOperation(
                    operation=OperationType.DELETE,
                    title=page_data.get('title', 'Unknown'),
                    path=Path(page_path),
                    page_id=page_data['id']
                ))
        
        return operations
    
    def _is_same_path(self, page_data: Dict, path_str: str) -> bool:
        """Check if a page corresponds to a given path (simplified)."""
        # This is a simplified check - in production, you'd use metadata or labels
        # For now, we match by title only, which can cause issues if multiple pages have same title
        # The path_str is the directory/file path, page_data contains page info
        return True  # Placeholder - title matching is done elsewhere
    
    def _resolve_parent_id(self, path: Path, created_pages: Dict[str, str], existing_pages_map: Optional[Dict[str, str]] = None, existing_pages: Optional[Dict[str, Dict]] = None) -> str:
        """
        Resolve the parent page ID for a given path.
        Uses created_pages cache to track newly created pages.
        Recursively searches for parent pages at any depth.
        
        Args:
            path: The path for which to find the parent (e.g., Path('parent/child') -> finds parent of 'parent/child', which is 'parent')
            created_pages: Dictionary mapping paths to newly created page IDs
            existing_pages_map: Optional pre-built map of existing pages (path -> page_id)
            existing_pages: Optional full existing pages structure from _get_all_subpages for path-based matching
        """
        logger.debug(f"_resolve_parent_id called with path={path}, created_pages keys={list(created_pages.keys())}")
        
        # If path is root, return root page ID
        if path == Path('.'):
            logger.debug(f"  Path is root, returning root_page_id")
            return self.root_page_id
        
        # Get the parent path (the directory containing this path)
        parent_path = path.parent
        
        # If parent is root, return root page ID
        if parent_path == Path('.'):
            logger.debug(f"  Parent path is root, returning root_page_id")
            return self.root_page_id
        
        # Now we need to find the page ID for parent_path
        # parent_path is what we're looking for (e.g., if path is "parent/child", parent_path is "parent")
        # We want to find the page ID for "parent"
        
        # Check if parent was just created
        # Normalize path separators for consistent lookup
        parent_key = str(parent_path).replace('\\', '/')
        
        # Also compute the sanitized title for the parent directory
        # This helps match directory paths to existing pages by title
        parent_title = self.converter.sanitize_title(parent_path.name, strict=True)
        
        logger.info(f"Resolving parent for path: '{parent_path}' (normalized: '{parent_key}', sanitized title: '{parent_title}')")
        logger.debug(f"Created pages at lookup time ({len(created_pages)} entries): {list(created_pages.keys())[:10]}{'...' if len(created_pages) > 10 else ''}")
        logger.debug(f"Looking for parent_key: '{parent_key}' (repr: {repr(parent_key)}, type: {type(parent_key).__name__})")
        if existing_pages_map:
            logger.debug(f"Existing pages map keys (first 10): {list(existing_pages_map.keys())[:10]}")
        
        # Check created_pages first (most recent) - by path key
        logger.debug(f"Checking if '{parent_key}' is in created_pages (len={len(created_pages)})...")
        if parent_key in created_pages:
            found_id = created_pages[parent_key]
            logger.info(f"✓ Found parent '{parent_key}' in created_pages -> page_id: {found_id}")
            # Try to get page title for better logging
            try:
                parent_page = self.confluence.get_page_by_id(found_id)
                parent_page_title = parent_page.get('title', 'Unknown')
                logger.debug(f"   Parent page title: '{parent_page_title}' (page_id: {found_id})")
            except:
                pass
            return found_id
        else:
            logger.debug(f"✗ '{parent_key}' NOT found in created_pages using 'in' operator")
        
        # Fallback: try direct iteration in case of any edge cases with 'in' operator
        # This handles cases where the key exists but 'in' check fails (shouldn't happen, but safety check)
        logger.debug(f"Parent key '{parent_key}' not found in created_pages using 'in' operator. Iterating through {len(created_pages)} created pages...")
        for key, page_id in created_pages.items():
            key_match = (key == parent_key)
            if key_match:
                logger.info(f"✓ Found parent '{parent_key}' in created_pages (via iteration, key='{key}') -> {page_id}")
                return page_id
            else:
                logger.debug(f"  Key mismatch: '{key}' != '{parent_key}' (key repr: {repr(key)}, parent_key repr: {repr(parent_key)})")
        
        # Check existing_pages_map by path key
        if existing_pages_map and parent_key in existing_pages_map:
            found_id = existing_pages_map[parent_key]
            logger.info(f"✓ Found parent '{parent_key}' in existing_pages_map -> page_id: {found_id}")
            return found_id
        
        # Also try matching by sanitized title (for existing pages that were stored by title)
        if existing_pages_map and parent_title in existing_pages_map:
            found_id = existing_pages_map[parent_title]
            logger.info(f"✓ Found parent by title '{parent_title}' in existing_pages_map -> page_id: {found_id}")
            # Store it with the path key for future lookups
            existing_pages_map[parent_key] = found_id
            return found_id
        
        # Try to find parent by matching directory path structure to page hierarchy
        if existing_pages:
            # Build path components from parent_path
            path_components = []
            current_path = parent_path
            while current_path != Path('.') and current_path != Path(''):
                path_components.insert(0, current_path.name)
                current_path = current_path.parent
            
            logger.debug(f"Attempting path component matching for '{parent_key}': components={path_components}")
            
            if path_components:
                # Build hierarchy tree from existing_pages
                root_children = []
                parent_to_children = {}
                
                for page_title_path, page_data in existing_pages.items():
                    page_id = page_data.get('id')
                    parent_id = page_data.get('parent_id')
                    
                    if not page_id:
                        continue
                    
                    if parent_id == self.root_page_id or not parent_id:
                        root_children.append(page_data)
                    else:
                        if parent_id not in parent_to_children:
                            parent_to_children[parent_id] = []
                        parent_to_children[parent_id].append(page_data)
                
                logger.debug(f"Built hierarchy: {len(root_children)} root children, {len(parent_to_children)} parent-child relationships")
                
                def find_page_by_path_components(components: List[str], current_parent_id: str, depth: int = 0) -> Optional[str]:
                    """Recursively find page matching path components."""
                    if depth >= len(components):
                        logger.debug(f"  Path component search: depth {depth} >= {len(components)} components, returning None")
                        return None
                    
                    target_name = components[depth]
                    target_sanitized = self.converter.sanitize_title(target_name, strict=True)
                    logger.debug(f"  Searching at depth {depth}: looking for '{target_name}' (sanitized: '{target_sanitized}') under parent {current_parent_id}")
                    
                    # Get children
                    children = []
                    if current_parent_id == self.root_page_id:
                        children = root_children
                        logger.debug(f"    Found {len(children)} root children")
                    elif current_parent_id in parent_to_children:
                        children = parent_to_children[current_parent_id]
                        logger.debug(f"    Found {len(children)} children under parent {current_parent_id}")
                    else:
                        logger.debug(f"    No children found under parent {current_parent_id}")
                    
                    # Find matching child
                    for child_page in children:
                        child_title = child_page.get('title', '')
                        child_sanitized = self.converter.sanitize_title(child_title, strict=True)
                        logger.debug(f"    Comparing: '{child_title}' (sanitized: '{child_sanitized}') == '{target_sanitized}'?")
                        if child_sanitized == target_sanitized:
                            child_id = child_page.get('id')
                            logger.debug(f"    ✓ Match found! Page ID: {child_id}, title: '{child_title}'")
                            if depth == len(components) - 1:
                                logger.info(f"    ✓ Found final page at depth {depth}: {child_id} ('{child_title}')")
                                return child_id
                            logger.debug(f"    Not final component, recursing into {child_id}...")
                            found = find_page_by_path_components(components, child_id, depth + 1)
                            if found:
                                return found
                    logger.debug(f"  No match found at depth {depth} for '{target_sanitized}'")
                    return None
                
                found_id = find_page_by_path_components(path_components, self.root_page_id)
                if found_id:
                    logger.info(f"✓ Found parent '{parent_key}' via path component matching -> {found_id}")
                    logger.info(f"  Path components: {path_components}")
                    # Store it for future lookups
                    if existing_pages_map is not None:
                        existing_pages_map[parent_key] = found_id
                        logger.debug(f"  Stored mapping: '{parent_key}' -> {found_id} in existing_pages_map")
                    return found_id
                else:
                    logger.debug(f"✗ Path component matching failed for '{parent_key}' with components {path_components}")
        
        logger.warning(f"⚠ Parent '{parent_key}' not found in created_pages or existing_pages_map, will search recursively or fallback to root")
        
        # Otherwise, recursively find existing parent page by title only (fallback)
        parent_title = self.converter.sanitize_title(parent_path.name, strict=True)
        
        def _find_page_recursive(parent_id: str, target_title: str, current_depth: int = 0, max_depth: int = 10) -> Optional[str]:
            """Recursively search for a page with the given title."""
            if current_depth > max_depth:
                return None
            
            try:
                pages = self.confluence.get_page_child_by_type(
                    parent_id,
                    type='page',
                    start=0,
                    limit=100
                )
                
                if 'results' in pages:
                    for page in pages['results']:
                        page_title = page.get('title', '')
                        page_id = page.get('id', '')
                        
                        if page_title == target_title:
                            return page_id
                        
                        # Recursively search in this page's children
                        found = _find_page_recursive(page_id, target_title, current_depth + 1, max_depth)
                        if found:
                            return found
            except Exception as e:
                logger.debug(f"Error searching in page {parent_id}: {e}")
            
            return None
        
        # First, try to find the parent page recursively from root
        try:
            found_id = _find_page_recursive(self.root_page_id, parent_title)
            if found_id:
                # Get page title for logging
                try:
                    found_page = self.confluence.get_page_by_id(found_id) if existing_pages is None else None
                    found_page_title = found_page.get('title', parent_title) if found_page else parent_title
                except:
                    found_page_title = parent_title
                logger.info(f"✓ Found parent '{parent_title}' via recursive search -> page_id: {found_id}, page_title: '{found_page_title}'")
                # Store it in existing_pages_map for future lookups
                if existing_pages_map is not None:
                    existing_pages_map[parent_key] = found_id
                    logger.debug(f"Stored found parent in existing_pages_map: '{parent_key}' -> {found_id}")
                return found_id
        except Exception as e:
            logger.warning(f"Error finding parent '{parent_title}' (path: '{parent_key}') recursively from root (root_page_id: {self.root_page_id}): {e}")
        
        # Note: The path component matching above should handle nested structures.
        # If it fails, we fall back to recursive title-based search below.
        
        # Final fallback to root - this means parent resolution failed
        logger.warning(f"⚠ Could not resolve parent for path '{parent_path}' (normalized: '{parent_key}', title: '{parent_title}') - falling back to root page")
        logger.warning(f"  Root page: '{self.root_page_title}' (root_page_id: {self.root_page_id})")
        logger.warning(f"  This will create the page under root instead of under its directory parent!")
        logger.warning(f"  Created pages keys ({len(created_pages)}): {list(created_pages.keys())[:20]}{'...' if len(created_pages) > 20 else ''}")
        if existing_pages_map:
            logger.warning(f"  Existing pages map keys ({len(existing_pages_map)}): {list(existing_pages_map.keys())[:20]}{'...' if len(existing_pages_map) > 20 else ''}")
        return self.root_page_id
    
    def _preview_operations(self, operations: List[PageOperation]) -> None:
        """Display a preview of operations to be performed."""
        creates = [op for op in operations if op.operation == OperationType.CREATE]
        updates = [op for op in operations if op.operation == OperationType.UPDATE]
        deletes = [op for op in operations if op.operation == OperationType.DELETE]
        
        print("\n" + "="*80)
        print("PREVIEW OF CHANGES")
        print("="*80)
        print(f"Root page: '{self.root_page_title}' (root_page_id: {self.root_page_id})")
        print(f"Directory: '{self.directory_path}'")
        print("="*80)
        
        if creates:
            print(f"\n📄 Pages to CREATE ({len(creates)}):")
            for op in creates:
                parent_info = f" (parent_id: {op.parent_id})" if op.parent_id else " (parent will be resolved)"
                content_info = " [directory page]" if not op.content or op.content.strip() == "" else f" [file, {len(op.content)} chars]"
                print(f"  - '{op.title}'{content_info}")
                print(f"    Path: {op.path}{parent_info}")
        
        if updates:
            print(f"\n✏️  Pages to UPDATE ({len(updates)}):")
            for op in updates:
                parent_info = f" (parent_id: {op.parent_id})" if op.parent_id else " (parent will be resolved)"
                content_info = f" ({len(op.content)} chars)" if op.content else " (empty)"
                print(f"  - '{op.title}' (page_id: {op.page_id}){content_info}")
                print(f"    Path: {op.path}{parent_info}")
        
        if deletes:
            print(f"\n🗑️  Pages to DELETE ({len(deletes)}):")
            for op in deletes:
                print(f"  - '{op.title}' (page_id: {op.page_id})")
                print(f"    Path: {op.path}")
        
        if not creates and not updates and not deletes:
            print("\n✓ No changes needed. Directory and Confluence are in sync.")
        
        print("\n" + "="*80)
    
    def _execute_operations(self, operations: List[PageOperation]) -> None:
        """Execute the list of operations."""
        created_pages: Dict[str, str] = {}  # Map path to page_id
        
        # Build existing pages map for faster lookup
        existing_pages = self._get_all_subpages(self.root_page_id)
        existing_pages_map = {}  # Will be built as we process
        
        # Pre-populate existing_pages_map with all existing pages
        # The existing_pages dict uses page title paths as keys (from _get_all_subpages)
        # We need to map directory paths to these pages by matching titles
        # This is done by sanitizing directory paths and matching them to page titles
        for page_title_path, page_data in existing_pages.items():
            page_id = page_data.get('id')
            page_title = page_data.get('title', '')
            if page_id:
                # Store by title (for direct title lookups)
                existing_pages_map[page_title] = page_id
                # Also store by normalized title path (for path-based lookups)
                # The page_title_path from _get_all_subpages is like "Title/Subtitle"
                normalized_title_path = page_title_path.replace('\\', '/')
                existing_pages_map[normalized_title_path] = page_id
                logger.debug(f"Pre-populated existing_pages_map: title='{page_title}', path='{normalized_title_path}' -> {page_id}")
        
        # Separate deletes for confirmation
        deletes = [op for op in operations if op.operation == OperationType.DELETE]
        other_ops = [op for op in operations if op.operation != OperationType.DELETE]
        
        # Sort operations: directories first (by depth), then files
        # This ensures parent pages are created before their children
        def get_depth(op: PageOperation) -> int:
            """Get the depth of the path (number of parent directories)."""
            return len(op.path.parts) - 1 if op.path != Path('.') else 0
        
        def is_directory(op: PageOperation) -> bool:
            """Check if operation is for a directory (empty content)."""
            return not op.content or op.content.strip() == ""
        
        # Sort: directories first (by depth), then files (by depth)
        # Within each group, sort by depth, then alphabetically
        other_ops.sort(key=lambda op: (
            0 if is_directory(op) else 1,  # Directories first
            get_depth(op),  # Then by depth
            str(op.path)  # Then alphabetically
        ))
        
        # Log the order of operations for debugging
        logger.info(f"Operations to execute (sorted):")
        for i, op in enumerate(other_ops[:10]):  # Show first 10
            is_dir = is_directory(op)
            logger.info(f"  {i+1}. {'[DIR]' if is_dir else '[FILE]'} {op.path} -> parent: {op.parent_id}, title: {op.title}")
        if len(other_ops) > 10:
            logger.info(f"  ... and {len(other_ops) - 10} more operations")
        
        # Execute creates and updates first
        for op in other_ops:
            try:
                # Resolve parent ID
                parent_id = op.parent_id
                if parent_id is None:
                    # Resolve parent: pass the full path, function will get the parent internally
                    # For "parent/child", we want to find the parent of "parent/child", which is "parent"
                    parent_id = self._resolve_parent_id(op.path, created_pages, existing_pages_map, existing_pages)
                    parent_path_to_resolve = op.path.parent  # For logging purposes
                    
                    # Verify we didn't just get root (unless that's correct)
                    if parent_id == self.root_page_id and parent_path_to_resolve != Path('.'):
                        logger.warning(f"⚠ WARNING: Parent resolution for '{parent_path_to_resolve}' (path: '{op.path}') returned root page ID!")
                        logger.warning(f"  Root page: '{self.root_page_title}' (root_page_id: {self.root_page_id})")
                        logger.warning(f"  This means the directory page was not found. Page '{op.title}' (path: '{op.path}') will be created under root instead of its intended parent.")
                        logger.warning(f"  Created pages keys ({len(created_pages)}): {list(created_pages.keys())[:20]}{'...' if len(created_pages) > 20 else ''}")
                        logger.warning(f"  Existing pages map keys ({len(existing_pages_map) if existing_pages_map else 0}): {list(existing_pages_map.keys())[:20] if existing_pages_map else []}{'...' if existing_pages_map and len(existing_pages_map) > 20 else ''}")
                        logger.warning(f"  Operation: {op.operation.value}, Path: '{op.path}', Title: '{op.title}'")
                    
                    logger.info(f"Resolved parent for '{op.path}': {parent_id} (parent path: '{parent_path_to_resolve}')")
                else:
                    logger.debug(f"Using provided parent_id for {op.path}: {parent_id}")
                
                if op.operation == OperationType.CREATE:
                    # Get space key and parent page info
                    parent_page_title = "Unknown"
                    space_key = None
                    try:
                        parent_page = self.confluence.get_page_by_id(parent_id)
                        space_key = parent_page.get('space', {}).get('key')
                        parent_page_title = parent_page.get('title', 'Unknown')
                        logger.info(f"Creating page: '{op.title}' (path: '{op.path}') under parent '{parent_page_title}' (parent_id: {parent_id}, space: {space_key})")
                    except Exception as e:
                        logger.error(f"Error getting parent page info for parent_id {parent_id} when creating page '{op.title}' (path: '{op.path}'): {e}")
                        raise
                    
                    # Prepare content - use empty string for directories, converted markdown for files
                    # op.content should already be converted markdown for files, empty string for directories
                    page_content = op.content if op.content else ""
                    
                    # Verify content for files
                    if op.path.suffix in ['.md', '.markdown'] and not page_content:
                        logger.warning(f"WARNING: File page '{op.title}' (path: '{op.path}') has no content! This should not happen.")
                    
                    logger.debug(f"Page content length for '{op.title}' (path: '{op.path}'): {len(page_content)} chars")
                    if page_content:
                        logger.debug(f"First 200 chars of content for '{op.title}': {page_content[:200]}")
                    
                    # Try to create the page, handle duplicate title errors
                    page_title = op.title
                    result = None
                    try:
                        # Create page with proper body format
                        # The atlassian-python-api expects body in a specific format
                        # Ensure body is not None - use empty string if needed
                        body_param = page_content if page_content else ""
                        
                        logger.info(f"Creating page '{page_title}' in space '{space_key}' under parent '{parent_page_title}' (parent_id: {parent_id})")
                        result = self.confluence.create_page(
                            space=space_key,
                            title=page_title,
                            body=body_param,
                            parent_id=parent_id,
                            type='page',
                            representation='storage'
                        )
                        logger.debug(f"Create page API call: space={space_key}, title={page_title}, parent_id={parent_id}, parent_title={parent_page_title}, content_len={len(body_param)}")
                        
                        # Verify the result
                        if result:
                            created_page_id = result.get('id')
                            logger.debug(f"Page created successfully with ID: {created_page_id}")
                        else:
                            logger.error(f"create_page returned None for {page_title}")
                    except Exception as e:
                        # Check if it's a duplicate title error
                        error_msg = str(e)
                        if ('BadRequestException' in error_msg or 
                            'page with this title already exists' in error_msg.lower() or
                            'page already exists with the same title' in error_msg.lower()):
                            # Try multiple strategies to create a unique title
                            # Verify root_page_title is set
                            if not self.root_page_title:
                                # This should never happen, but if it does, try to get it again
                                try:
                                    root_page = self.confluence.get_page_by_id(self.root_page_id)
                                    self.root_page_title = root_page.get('title', 'Root Page')
                                    logger.warning(f"Root page title was not set, retrieved it: '{self.root_page_title}' (root_page_id: {self.root_page_id})")
                                except Exception as e2:
                                    logger.error(f"Could not retrieve root page title for root_page_id {self.root_page_id}: {e2}")
                                    self.root_page_title = 'Root Page'  # Fallback
                            
                            # Try multiple title modification strategies
                            title_attempts = []
                            if self.root_page_title:
                                title_attempts.append(f"{self.root_page_title} - {op.title}")
                                # If that also exists, try with a number suffix
                                for i in range(2, 10):  # Try up to 9 attempts
                                    title_attempts.append(f"{self.root_page_title} - {op.title} ({i})")
                            else:
                                # Fallback: use suffix
                                title_attempts.append(f"{op.title} (Duplicate)")
                                for i in range(2, 10):
                                    title_attempts.append(f"{op.title} (Duplicate {i})")
                            
                            result = None
                            last_error = None
                            logger.warning(f"⚠ Duplicate title detected for page '{op.title}' (path: '{op.path}')")
                            logger.warning(f"   Parent: '{parent_page_title}' (parent_id: {parent_id})")
                            logger.warning(f"   Space: '{space_key}'")
                            logger.warning(f"   Root page: '{self.root_page_title}' (root_page_id: {self.root_page_id})")
                            logger.warning(f"   Will try {len(title_attempts)} title variations...")
                            
                            for attempt_num, attempt_title in enumerate(title_attempts, 1):
                                try:
                                    logger.info(f"   Attempt {attempt_num}/{len(title_attempts)}: Trying title '{attempt_title}' (original: '{op.title}')")
                                    result = self.confluence.create_page(
                                        space=space_key,
                                        title=attempt_title,
                                        body=body_param,
                                        parent_id=parent_id,
                                        type='page',
                                        representation='storage'
                                    )
                                    page_title = attempt_title  # Update to the successful title
                                    created_page_id = result.get('id') if result else 'N/A'
                                    logger.info(f"✓ Successfully created page with modified title: '{attempt_title}'")
                                    logger.info(f"   Original title: '{op.title}'")
                                    logger.info(f"   Page ID: {created_page_id}")
                                    logger.info(f"   Parent: '{parent_page_title}' (parent_id: {parent_id})")
                                    logger.info(f"   Space: '{space_key}'")
                                    logger.info(f"   Path: '{op.path}'")
                                    break
                                except Exception as retry_error:
                                    retry_error_msg = str(retry_error)
                                    if ('BadRequestException' in retry_error_msg or 
                                        'page with this title already exists' in retry_error_msg.lower() or
                                        'page already exists with the same title' in retry_error_msg.lower()):
                                        last_error = retry_error
                                        logger.warning(f"     ✗ Title '{attempt_title}' also exists in space '{space_key}' under parent '{parent_page_title}' (parent_id: {parent_id})")
                                        if attempt_num < len(title_attempts):
                                            logger.info(f"     → Trying next variation...")
                                        continue
                                    else:
                                        # Different error, re-raise with full context
                                        logger.error(f"❌ Error creating page '{attempt_title}' (original: '{op.title}', path: '{op.path}')")
                                        logger.error(f"   Parent: '{parent_page_title}' (parent_id: {parent_id})")
                                        logger.error(f"   Space: '{space_key}'")
                                        logger.error(f"   Root page: '{self.root_page_title}' (root_page_id: {self.root_page_id})")
                                        logger.error(f"   Error: {retry_error}")
                                        raise
                            
                            if result is None:
                                # All attempts failed
                                logger.error(f"❌ FAILED to create page after {len(title_attempts)} title modification attempts")
                                logger.error(f"   Original title: '{op.title}'")
                                logger.error(f"   File path: '{op.path}'")
                                logger.error(f"   Parent page: '{parent_page_title}' (parent_id: {parent_id})")
                                logger.error(f"   Space: '{space_key}'")
                                logger.error(f"   Root page: '{self.root_page_title}' (root_page_id: {self.root_page_id})")
                                logger.error(f"   All attempted titles ({len(title_attempts)}):")
                                for idx, attempt_title in enumerate(title_attempts, 1):
                                    logger.error(f"     {idx}. '{attempt_title}'")
                                logger.error(f"   Last error: {last_error}")
                                raise Exception(f"Could not create page '{op.title}' (path: '{op.path}') - all {len(title_attempts)} title variations already exist in space '{space_key}' under parent '{parent_page_title}' (parent_id: {parent_id}). Last error: {last_error}")
                        else:
                            # Re-raise if it's not a duplicate title error
                            logger.error(f"❌ Error creating page '{op.title}' (path: '{op.path}')")
                            logger.error(f"   Parent: '{parent_page_title}' (parent_id: {parent_id})")
                            logger.error(f"   Space: '{space_key}'")
                            logger.error(f"   Root page: '{self.root_page_title}' (root_page_id: {self.root_page_id})")
                            logger.error(f"   Error type: {type(e).__name__}")
                            logger.error(f"   Error message: {e}")
                            raise
                    
                    if result:
                        page_id = result.get('id')
                        if page_id:
                            # Store the page ID using normalized path as key
                            path_key = str(op.path).replace('\\', '/')
                            created_pages[path_key] = page_id
                            existing_pages_map[path_key] = page_id
                            self.sync_state.created_pages.append(page_id)
                            
                            # Log creation with content info and parent relationship
                            content_info = " (empty)" if not page_content or page_content.strip() == "" else f" ({len(page_content)} chars)"
                            parent_info = f" under parent '{parent_page_title}' (ID: {parent_id})" if parent_id != self.root_page_id else f" under root page (ID: {self.root_page_id})"
                            if page_title != op.title:
                                logger.info(f"✓ Created page: '{page_title}' (page_id: {page_id}) [original title: '{op.title}']{content_info}{parent_info}")
                            else:
                                logger.info(f"✓ Created page: '{op.title}' (page_id: {page_id}){content_info}{parent_info}")
                            logger.info(f"  Path: '{path_key}' -> page_id={page_id}, parent_id={parent_id}, parent_title='{parent_page_title}', space={space_key}")
                            logger.debug(f"  Hierarchy: root({self.root_page_id}) -> ... -> parent('{parent_page_title}', {parent_id}) -> this_page('{page_title}', {page_id})")
                            
                            # Verify content was actually set (for debugging)
                            if page_content and page_content.strip():
                                logger.debug(f"Page {page_id} should have content: {len(page_content)} chars")
                            else:
                                logger.debug(f"Page {page_id} is empty (directory page or no content)")
                        else:
                            logger.error(f"Failed to create page '{page_title}' (path: '{op.path}', parent_id: {parent_id}, parent_title: '{parent_page_title}') - no page ID returned in result")
                            raise Exception(f"Failed to create page '{page_title}' (path: '{op.path}') - no page ID returned")
                    else:
                        logger.error(f"Failed to create page '{page_title}' (path: '{op.path}', parent_id: {parent_id}, parent_title: '{parent_page_title}') - no result returned from API")
                        raise Exception(f"Failed to create page '{page_title}' (path: '{op.path}') - no result returned")
                
                elif op.operation == OperationType.UPDATE:
                    # Get current page to preserve version and get page info
                    try:
                        current_page = self.confluence.get_page_by_id(op.page_id)
                        current_page_title = current_page.get('title', 'Unknown')
                        old_version = current_page.get('version', {}).get('number', 1)
                        current_parent_id = None
                        current_parent_title = "Unknown"
                        ancestors = current_page.get('ancestors', [])
                        if ancestors:
                            current_parent_id = ancestors[-1].get('id') if ancestors else None
                            if current_parent_id:
                                try:
                                    current_parent_page = self.confluence.get_page_by_id(current_parent_id)
                                    current_parent_title = current_parent_page.get('title', 'Unknown')
                                except:
                                    pass
                        logger.info(f"Updating page: '{op.title}' (page_id: {op.page_id}, current_title: '{current_page_title}', path: '{op.path}', current_version: {old_version})")
                        logger.info(f"  Current parent: '{current_parent_title}' (parent_id: {current_parent_id})")
                    except Exception as e:
                        logger.error(f"Error getting current page info for page_id {op.page_id} when updating page '{op.title}' (path: '{op.path}'): {e}")
                        raise
                    
                    # Resolve parent ID if needed
                    update_parent_id = op.parent_id
                    update_parent_title = "Unknown"
                    if update_parent_id is None:
                        # Pass the full path, function will get the parent internally
                        update_parent_id = self._resolve_parent_id(op.path, created_pages, existing_pages_map, existing_pages)
                        # Get parent page title for logging
                        try:
                            if update_parent_id and update_parent_id != self.root_page_id:
                                update_parent_page = self.confluence.get_page_by_id(update_parent_id)
                                update_parent_title = update_parent_page.get('title', 'Unknown')
                            else:
                                update_parent_title = self.root_page_title if hasattr(self, 'root_page_title') else 'Root'
                        except:
                            pass
                        logger.info(f"Resolved parent for update: '{op.path.parent}' -> '{update_parent_title}' (parent_id: {update_parent_id})")
                    
                    # Check if page needs to be moved to different parent (already retrieved above)
                    
                    # Prepare content - ensure it's not None and is converted markdown
                    update_content = op.content if op.content else ""
                    if not update_content and op.path.suffix in ['.md', '.markdown']:
                        # This is a file, it should have content - log warning
                        logger.warning(f"Update operation for file '{op.path}' (page_id: {op.page_id}, title: '{op.title}') has no content!")
                    
                    content_info = f" ({len(update_content)} chars)" if update_content else " (empty)"
                    parent_change_info = ""
                    if update_parent_id != current_parent_id:
                        parent_change_info = f" [MOVING from '{current_parent_title}' ({current_parent_id}) to '{update_parent_title}' ({update_parent_id})]"
                    logger.info(f"Updating page '{op.title}' (page_id: {op.page_id}){content_info}, new version: {old_version + 1}{parent_change_info}")
                    
                    # Update the page - try with parent_id first if it changed
                    try:
                        # Try update with parent_id if parent changed
                        if update_parent_id and update_parent_id != current_parent_id:
                            try:
                                logger.info(f"Attempting to update page '{op.title}' (page_id: {op.page_id}) with parent change to '{update_parent_title}' ({update_parent_id})")
                                result = self.confluence.update_page(
                                    page_id=op.page_id,
                                    title=op.title,
                                    body=update_content,
                                    version=old_version + 1,
                                    representation='storage',
                                    parent_id=update_parent_id
                                )
                            except (TypeError, KeyError):
                                # parent_id parameter not supported, update without it
                                logger.warning(f"Page '{op.title}' (page_id: {op.page_id}) parent changed from '{current_parent_title}' ({current_parent_id}) to '{update_parent_title}' ({update_parent_id}), but parent_id update not supported by API - updating content only")
                                result = self.confluence.update_page(
                                    page_id=op.page_id,
                                    title=op.title,
                                    body=update_content,
                                    version=old_version + 1,
                                    representation='storage'
                                )
                        else:
                            # Parent unchanged, just update content
                            logger.debug(f"Updating page '{op.title}' (page_id: {op.page_id}) content only, parent unchanged: '{update_parent_title}' ({update_parent_id})")
                            result = self.confluence.update_page(
                                page_id=op.page_id,
                                title=op.title,
                                body=update_content,
                                version=old_version + 1,
                                representation='storage'
                            )
                    except Exception as e:
                        logger.error(f"Error updating page '{op.title}' (page_id: {op.page_id}, path: '{op.path}', parent_id: {update_parent_id}): {e}")
                        raise
                    
                    if result:
                        self.sync_state.updated_pages.append((op.page_id, old_version))
                        content_info = f" ({len(update_content)} chars)" if update_content else " (empty)"
                        logger.info(f"✓ Updated page: '{op.title}' (page_id: {op.page_id}, path: '{op.path}'){content_info}, version: {old_version} -> {old_version + 1}, parent: '{update_parent_title}' ({update_parent_id})")
            
            except Exception as e:
                logger.error(f"❌ Error executing {op.operation.value} operation")
                logger.error(f"   Page title: '{op.title}'")
                logger.error(f"   File path: '{op.path}'")
                logger.error(f"   Page ID: {op.page_id if hasattr(op, 'page_id') and op.page_id else 'N/A'}")
                logger.error(f"   Operation type: {op.operation.value}")
                logger.error(f"   Root page: '{self.root_page_title}' (root_page_id: {self.root_page_id})")
                logger.error(f"   Error type: {type(e).__name__}")
                logger.error(f"   Error message: {e}")
                raise
        
        # Handle deletes separately with confirmation
        if deletes:
            print(f"\n⚠️  WARNING: {len(deletes)} page(s) will be deleted.")
            print("Pages to delete:")
            for op in deletes:
                # Get page info for better display
                try:
                    page_data = self.confluence.get_page_by_id(op.page_id)
                    page_title = page_data.get('title', op.title)
                    parent_info = ""
                    ancestors = page_data.get('ancestors', [])
                    if ancestors:
                        parent_id = ancestors[-1].get('id') if ancestors else None
                        if parent_id:
                            try:
                                parent_page = self.confluence.get_page_by_id(parent_id)
                                parent_title = parent_page.get('title', 'Unknown')
                                parent_info = f" (under '{parent_title}', parent_id: {parent_id})"
                            except:
                                parent_info = f" (parent_id: {parent_id})"
                    print(f"  - '{page_title}' (page_id: {op.page_id}){parent_info}")
                except Exception as e:
                    print(f"  - '{op.title}' (page_id: {op.page_id}) [Error getting page info: {e}]")
            
            confirm = input("\nConfirm deletion? (yes/no): ").strip().lower()
            if confirm in ['yes', 'y']:
                for op in deletes:
                    try:
                        # Get page info before deletion
                        page_data = self.confluence.get_page_by_id(op.page_id)
                        page_title = page_data.get('title', op.title)
                        logger.info(f"Deleting page: '{page_title}' (page_id: {op.page_id}, path: '{op.path}')")
                        
                        # Store page data for potential rollback
                        self.sync_state.deleted_pages.append(page_data)
                        
                        self.confluence.remove_page(op.page_id)
                        logger.info(f"✓ Deleted page: '{page_title}' (page_id: {op.page_id}, path: '{op.path}')")
                    except Exception as e:
                        logger.error(f"Error deleting page '{op.title}' (page_id: {op.page_id}, path: '{op.path}'): {e}")
                        raise
            else:
                logger.info("Deletion cancelled by user.")
    
    def _rollback(self) -> None:
        """Rollback changes made during the current sync operation."""
        logger.warning(f"Rolling back changes: {len(self.sync_state.created_pages)} created pages, {len(self.sync_state.updated_pages)} updated pages, {len(self.sync_state.deleted_pages)} deleted pages")
        
        # Delete created pages
        for page_id in reversed(self.sync_state.created_pages):
            try:
                # Get page info before deletion for logging
                try:
                    page_data = self.confluence.get_page_by_id(page_id)
                    page_title = page_data.get('title', 'Unknown')
                    logger.info(f"Rolling back: Deleting created page '{page_title}' (page_id: {page_id})")
                except:
                    logger.info(f"Rolling back: Deleting created page (page_id: {page_id})")
                self.confluence.remove_page(page_id)
                logger.info(f"✓ Rolled back: Deleted created page (page_id: {page_id})")
            except Exception as e:
                logger.error(f"Error rolling back created page (page_id: {page_id}): {e}")
        
        # Restore updated pages (revert to old version)
        for page_id, old_version in reversed(self.sync_state.updated_pages):
            try:
                # Get page info for logging
                try:
                    page_data = self.confluence.get_page_by_id(page_id)
                    page_title = page_data.get('title', 'Unknown')
                    current_version = page_data.get('version', {}).get('number', 'Unknown')
                    logger.warning(f"Could not automatically rollback page '{page_title}' (page_id: {page_id}) from version {current_version} to {old_version} - Confluence API doesn't support direct version rollback")
                except:
                    logger.warning(f"Could not automatically rollback page (page_id: {page_id}) to version {old_version}")
            except Exception as e:
                logger.error(f"Error rolling back updated page (page_id: {page_id}): {e}")
        
        # Restore deleted pages (would need to recreate them)
        for page_data in reversed(self.sync_state.deleted_pages):
            try:
                page_title = page_data.get('title', 'Unknown')
                page_id = page_data.get('id', 'Unknown')
                space_key = page_data.get('space', {}).get('key', 'Unknown')
                parent_id = page_data.get('ancestors', [{}])[-1].get('id') if page_data.get('ancestors') else None
                logger.info(f"Rolling back: Restoring deleted page '{page_title}' (page_id: {page_id}) in space '{space_key}' under parent_id: {parent_id}")
                # Recreate deleted page
                self.confluence.create_page(
                    space=space_key,
                    title=page_title,
                    body=page_data.get('body', {}).get('storage', {}).get('value', ''),
                    parent_id=parent_id,
                    type='page',
                    representation='storage'
                )
                logger.info(f"✓ Rolled back: Restored deleted page '{page_title}' (page_id: {page_id})")
            except Exception as e:
                page_title = page_data.get('title', 'Unknown') if page_data else 'Unknown'
                logger.error(f"Error rolling back deleted page '{page_title}': {e}")
        
        logger.warning("Rollback completed (with possible errors)")
    
    def sync(self, dry_run: bool = False) -> None:
        """
        Perform the synchronization.
        
        Args:
            dry_run: If True, only preview changes without executing them
        """
        try:
            logger.info(f"Starting sync from {self.directory_path} to Confluence page {self.root_page_id}")
            
            # Traverse directory
            logger.info("Traversing directory structure...")
            file_map, dir_structure = self._traverse_directory()
            logger.info(f"Found {len(file_map)} Markdown files and {len(dir_structure)} directories")
            
            # Build operations
            logger.info("Analyzing changes...")
            operations = self._build_operations(file_map, dir_structure)
            
            # Preview operations
            self._preview_operations(operations)
            
            if dry_run:
                logger.info("Dry run mode - no changes will be made")
                return
            
            # Confirm before proceeding (except for deletes which are handled separately)
            non_delete_ops = [op for op in operations if op.operation != OperationType.DELETE]
            if non_delete_ops:
                confirm = input("\nProceed with these changes? (yes/no): ").strip().lower()
                if confirm not in ['yes', 'y']:
                    logger.info("Sync cancelled by user.")
                    return
            
            # Execute operations
            logger.info("Executing operations...")
            self._execute_operations(operations)
            
            # Summary
            creates = len([op for op in operations if op.operation == OperationType.CREATE])
            updates = len([op for op in operations if op.operation == OperationType.UPDATE])
            deletes = len([op for op in operations if op.operation == OperationType.DELETE])
            
            print("\n" + "="*80)
            print("SYNC COMPLETED")
            print("="*80)
            print(f"✓ Pages created: {creates}")
            print(f"✓ Pages updated: {updates}")
            print(f"✓ Pages deleted: {deletes}")
            print("="*80)
            
            logger.info("Sync completed successfully")
        
        except Exception as e:
            logger.error(f"❌ Error during sync")
            logger.error(f"   Directory: '{self.directory_path}'")
            logger.error(f"   Root page: '{self.root_page_title}' (root_page_id: {self.root_page_id})")
            logger.error(f"   Error type: {type(e).__name__}")
            logger.error(f"   Error message: {e}")
            logger.error(f"   Full traceback:", exc_info=True)
            print(f"\n❌ Error during sync: {e}")
            print(f"   Directory: '{self.directory_path}'")
            print(f"   Root page: '{self.root_page_title}' (ID: {self.root_page_id})")
            
            # Attempt rollback
            if self.sync_state.created_pages or self.sync_state.updated_pages:
                logger.warning(f"Attempting to rollback {len(self.sync_state.created_pages)} created pages and {len(self.sync_state.updated_pages)} updated pages...")
                try:
                    self._rollback()
                except Exception as rollback_error:
                    logger.error(f"Error during rollback: {rollback_error}", exc_info=True)
            
            raise


def main():
    """Main entry point for the program."""
    import argparse
    
    parser = argparse.ArgumentParser(
        description='Sync Markdown files from a directory to Confluence pages'
    )
    
    parser.add_argument(
        'directory_path',
        help='Path to directory containing Markdown files'
    )
    
    parser.add_argument(
        'confluence_page_id',
        help='ID of the root Confluence page'
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
        help='Preview changes without executing them'
    )
    
    parser.add_argument(
        '--log-file',
        type=str,
        default=None,
        help='Path to log file. If not specified, logs only to console. Default: confluence_sync.log in the current directory'
    )
    
    parser.add_argument(
        '--log-level',
        type=str,
        choices=['DEBUG', 'INFO', 'WARNING', 'ERROR'],
        default='INFO',
        help='Logging level (default: INFO)'
    )
    
    args = parser.parse_args()
    
    # Set up logging
    log_level = getattr(logging, args.log_level.upper())
    log_file = args.log_file
    if log_file is None:
        # Default log file in current directory
        log_file = 'confluence_sync.log'
    setup_logging(log_file=log_file, log_level=log_level)
    
    try:
        sync_tool = ConfluenceSync(
            confluence_url=args.url,
            username=args.username,
            api_token=args.api_token,
            directory_path=args.directory_path,
            root_page_id=args.confluence_page_id
        )
        
        sync_tool.sync(dry_run=args.dry_run)
    
    except KeyboardInterrupt:
        print("\n\nSync interrupted by user.")
        sys.exit(1)
    except Exception as e:
        print(f"\n\nFatal error: {e}")
        sys.exit(1)


if __name__ == '__main__':
    main()
