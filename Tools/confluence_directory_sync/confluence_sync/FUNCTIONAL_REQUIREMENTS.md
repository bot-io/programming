# Functional Requirements: Directory to Confluence Sync

## 1. Overview

This document describes the functional requirements for a Python program that synchronizes Markdown files from a local directory structure to Confluence pages, maintaining the directory hierarchy and ensuring consistency between the local filesystem and Confluence.

## 2. Purpose

The program should:
- Read Markdown files from a specified directory (and subdirectories)
- Create or update corresponding Confluence pages
- Maintain the directory structure as a page hierarchy in Confluence
- Handle updates, deletions, and new file additions
- Provide a preview of changes before execution
- Require user confirmation before making changes

## 3. Input Parameters

The program must accept the following command-line arguments:
- `--confluence-url`: URL of the Confluence instance (e.g., `https://your-domain.atlassian.net`)
- `--username`: Confluence username or email
- `--api-token`: Confluence API token (for authentication)
- `--directory-path`: Path to the directory containing Markdown files to sync
- `--confluence-page-id`: ID of the root Confluence page under which all pages will be created/updated
- `--log-file`: (Optional) Path to log file. If not specified, defaults to `confluence_sync.log` in the current directory
- `--log-level`: (Optional) Logging level: DEBUG, INFO, WARNING, or ERROR (default: INFO)
- `--dry-run`: (Optional) Preview changes without executing them

## 4. Core Functionality

### 4.1 Directory Traversal

- The program must recursively traverse the specified directory
- Identify all Markdown files (`.md` or `.markdown` extensions)
- Identify all subdirectories
- Build a complete map of the directory structure

### 4.2 Authentication

- Use the provided API token to authenticate with Confluence
- Handle authentication errors gracefully
- Provide clear error messages if authentication fails

### 4.3 Markdown File Processing

- For each Markdown file found in the directory:
  - Read the file contents (UTF-8 encoding)
  - Convert Markdown content to Confluence storage format (or appropriate Confluence format)
  - **Page Title**: Derived from the first heading (`# Title`) in the Markdown file
    - If no heading exists, fallback to filename (without extension)
  - **Content**: Convert Markdown to Confluence format
    - Images: Ignored (not processed or uploaded)
    - Links: Preserved as-is (no conversion to Confluence page links)
  - Create a Confluence page with:
    - Title from first heading
    - Content from the Markdown file
    - Parent page set according to the directory structure
    - **Versioning**: Updates create new versions (do not overwrite without versioning)

### 4.4 Subdirectory Handling

- For each subdirectory found:
  - **Single-File Directory Optimization**: If a directory contains exactly one file and no subdirectories, skip creating the directory page. Instead, create the file page directly under the directory's parent (one level up). This avoids creating unnecessary empty pages.
  - **Multi-File or Multi-Directory Directories**: For directories with multiple files or subdirectories:
    - Create an **empty Confluence page** that acts as a parent page
    - **Page Title**: Match the directory name, but sanitized:
      - Plain text only (no dashes, no numbers)
      - Special characters should be handled appropriately for Confluence page title requirements
    - **Page Content**: Empty (title only, no content)
    - This parent page will contain all subpages created from files and subdirectories within that folder
  - The parent page hierarchy must reflect the directory structure
  - **Page Ordering**: Pages should be ordered alphabetically within each folder

### 4.5 Page Synchronization

- When the program is rerun:
  - **Pre-execution Preview**: Before making any changes, the program must:
    - Generate a list of all changes to be made (pages to create, update, delete)
    - Display this list to the user
    - Require user confirmation before proceeding
  - **Override/Update**: All existing pages that correspond to files or folders in the directory must be updated with current content
    - Updates create new versions (preserve version history)
    - **Change Detection**: The program detects three types of changes:
      - **Title Changes**: When the first heading (`# Title`) in a Markdown file changes, the Confluence page title is updated
      - **Content Changes**: When the file content changes, the page content is updated (using normalized comparison to avoid false positives from formatting differences)
      - **Parent Changes**: When a file is moved to a different directory, the page's parent relationship is updated
    - **Smart Matching**: Pages are matched to files using:
      1. File path labels stored in Confluence page labels (most reliable, enables tracking even if titles change)
      2. Case-insensitive title matching (fallback when labels are not available)
      3. **Collision-Resolution Title Matching**: When title matching fails, the program also checks for pages with collision-resolution titles (e.g., "Root Page - Original Title" will match "Original Title"). This handles cases where duplicate title resolution modified the page title.
    - Content is always updated to reflect the current Markdown file content
    - Parent relationships are preserved or updated if the page needs to be moved to a different parent
    - If a page is found by title but is in the wrong location, the program attempts to update its parent (subject to API limitations)
    - **File Path Tracking**: When pages are created or updated, the program stores the file path in Confluence page labels using hex encoding (format: `syncfilepath{hex_encoded_path}`)
    - File paths are hex-encoded to comply with Confluence label restrictions (lowercase, no colons, no slashes, no spaces)
    - Labels are set using the `set_page_label` method from atlassian-python-api
    - If label setting fails, the program logs a warning with details but continues (matching will rely on title only)
    - Labels are checked before setting to avoid duplicates
    - Label length is validated (must be under 255 characters) before setting
- **Change Logging**: The program logs what specifically changed (title, content, parent) for each updated page
- **Diagnostic Logging**: The program provides detailed diagnostic information:
    - Logs how many existing pages were found at the start of sync
    - Logs which matching method succeeded (label vs title) for each page
    - Logs warnings when pages cannot be matched, including list of existing page titles for debugging
    - This helps diagnose issues when duplicate pages are created
  - **Delete**: Any Confluence subpages under the root page that do not correspond to existing files or folders in the directory must be deleted
    - Display a list of pages to be deleted
    - Require user confirmation before deletion
  - **Create**: Any new files or folders in the directory must result in new Confluence pages
  - **Root Page**: The root page (specified by `confluence_page_id`) is never modified by the program

### 4.6 Page Identification

- The program must be able to identify which Confluence pages correspond to which files/folders
- **Primary Method - File Path Labels**: 
  - The program stores file paths in Confluence page labels using hex encoding (format: `syncfilepath{hex_encoded_path}`)
  - File paths are hex-encoded to comply with Confluence label requirements (lowercase, no colons, no slashes, no spaces)
  - Example: `syncfilepath30312d4f6e626f617264696e67...` encodes the path `01-Onboarding-and-Authentication/...`
  - This enables reliable matching even when page titles change or files are moved
  - Labels are automatically set when pages are created and updated when files are moved
  - The program also supports reading old label format (`sync-file-path:path`) for backward compatibility
  - If label methods are not available in the Confluence API, the program gracefully falls back to title matching
  - **Label Format Requirements**: Labels must be lowercase, contain only alphanumeric characters (hex uses 0-9, a-f), and be under 255 characters
- **Fallback Method - Title Matching**:
  - When file path labels are not available, the program matches pages by title
  - Title matching is case-insensitive for better reliability
  - Matches the title extracted from the first heading in the Markdown file (or filename if no heading exists)
  - **Collision-Resolution Handling**: If exact title match fails, the program checks for pages with collision-resolution titles (format: "{prefix} - {original_title}"). This ensures pages can be found even when their titles were modified due to duplicate title conflicts.
  - **Partial Matching**: The program checks if the file title appears at the end of the page title after a dash separator, enabling matching of collision-resolved titles
- **Additional Methods** (for reference):
  - Page hierarchy matching directory structure
  - A mapping mechanism to track relationships
- **Path Normalization**: Paths are normalized (backslashes converted to forward slashes) to ensure consistent parent-child relationship resolution across different operating systems
- **Parent Resolution**: When creating or updating pages, parent page IDs are resolved by:
  1. First checking if the parent page was just created in the current sync operation (using normalized path as key)
  2. Then checking existing pages in the Confluence space (using normalized path as key)
  3. Recursively searching the page hierarchy by matching sanitized directory titles
  4. Falling back to root page if parent cannot be found (with warning logged)
- **Operation Ordering**: Operations are sorted to ensure:
  - Directory pages are created before file pages at the same depth
  - Pages are created in depth order (shallow to deep)
  - This ensures parent pages exist before their children are created
- **Parent Resolution Failure**: If parent resolution fails and falls back to root, detailed warning messages are logged including:
  - The parent path that could not be resolved
  - A message indicating the page will be created under root instead of its intended directory parent
  - The list of created pages keys (to help diagnose why the parent wasn't found)
  - The list of existing pages map keys (first 20, to help diagnose lookup issues)
  - Operation details (operation type, path, and title) for the page being created
  - These warnings help diagnose hierarchy issues when pages are incorrectly created under root

## 5. Behavior Specifications

### 5.1 Initial Run

1. Traverse the directory structure
2. Create the root parent page structure (if needed)
3. For each subdirectory, create an empty parent page
4. For each Markdown file, create a page with the file's content
5. Establish the correct parent-child relationships

### 5.2 Subsequent Runs

1. Traverse the directory structure again
2. Compare current directory state with existing Confluence pages
3. Generate a list of all changes (create, update, delete operations)
4. Display the change list to the user and request confirmation
5. If confirmed:
   - **Update** pages that correspond to existing files/folders with current content (creating new versions)
   - **Create** pages for new files/folders
   - **Delete** Confluence pages that no longer have corresponding files/folders in the directory (with separate confirmation)
6. If not confirmed, abort without making changes

### 5.3 Error Handling

- Handle cases where the root Confluence page ID is invalid or inaccessible
- Handle cases where the directory path is invalid or inaccessible
- Handle network/API errors when communicating with Confluence

## 6. Edge Cases and Special Scenarios

### 6.1 Empty Directories

- Empty directories (with no files or subdirectories) should still create an empty Confluence page to maintain structure

### 6.2 Duplicate File Names

- Files with the same name in different directories should create separate pages (titles may be the same, but hierarchy differentiates them)

### 6.3 Special Characters

- Directory and file names with special characters should be sanitized appropriately for Confluence page titles
- Directory names: Plain text only (no dashes, no numbers) - strict sanitization
- File titles: More lenient, preserving dashes and numbers when possible

### 6.4 File Naming Conflicts

- If a page with the same title already exists in the same parent location:
  - Prepend the root page title to the new page title (e.g., "{root_page_title} - {original_title}")
  - Retry the page creation with the modified title
  - Log the title modification for user awareness
  - If root page title is not available, append "(Duplicate)" to the title instead

### 6.5 Markdown Files Without Headings

- If a Markdown file has no heading, use the filename (without extension) as the page title
- Convert dashes in filename to spaces for better readability (e.g., "my-document.md" -> "my document")

### 6.6 Byte Order Mark (BOM)

- Handle UTF-8 files with BOM characters at the start
- Strip BOM characters before processing content

## 7. User Interface

### 7.1 Preview Mode

- Before execution, display:
  - List of pages to be created (with titles and paths)
  - List of pages to be updated (with titles and page IDs)
  - List of pages to be deleted (with titles and page IDs)
- Format the output clearly and readably

### 7.2 Confirmation Prompts

- Require explicit user confirmation before:
  - Creating/updating pages
  - Deleting pages (separate confirmation)
- Allow user to abort at any confirmation prompt

### 7.3 Progress Feedback

- Provide progress updates during execution
- Log important operations (page creation, updates, deletions)
- Display summary of operations performed

## 8. Technical Requirements

### 8.1 Created Pages Tracking

- **Automatic List Generation**: After each successful sync run, the program automatically creates a JSON file listing all newly created pages
- **File Naming**: Each run creates a new file with timestamp format: `created_pages_YYYYMMDD_HHMMSS.json`
- **File Location**: Files are created in the current working directory where the sync program is executed
- **File Contents**: The JSON file contains:
  - `timestamp`: ISO format timestamp of when the sync completed
  - `root_page_id`: ID of the root Confluence page
  - `root_page_title`: Title of the root Confluence page
  - `directory_path`: Path to the source directory that was synced
  - `created_pages`: Array of page objects, each containing:
    - `page_id`: Confluence page ID
    - `title`: Page title
    - `space`: Confluence space key
    - `version`: Page version number
- **Error Handling**: If saving the list fails, the program logs a warning but does not fail the sync operation
- **Use Case**: These JSON files can be used with the `delete_pages.py` utility (see `DELETE_PAGES_REQUIREMENTS.md` for details)

### 8.2 Dependencies

- Use the `atlassian-python-api` library for Confluence API interactions
- Use standard Python libraries for file operations and Markdown processing
- Handle dependencies gracefully if not installed

### 8.4 Error Handling

- Catch and handle API errors gracefully
- Provide meaningful error messages to the user
- Log errors for debugging purposes
- Continue processing other files if one fails (where possible)

### 8.5 State Management

- Track which pages have been created/updated in the current run
- Maintain mappings between file paths and Confluence page IDs
- Preserve content for file pages (converted markdown)
- Use empty content for directory pages
- Normalize paths (backslashes to forward slashes) for consistent lookups

### 8.6 Logging

- Use Python's `logging` module for consistent log output
- Log at appropriate levels (INFO, WARNING, ERROR, DEBUG)
- Include detailed diagnostic information in warnings when parent resolution fails
- **File Logging**: All log messages are written to both console and a log file
  - Default log file: `confluence_sync.log` in the current working directory
  - Log file path can be customized via `--log-file` command-line argument
  - Log file uses append mode, so multiple runs append to the same file
  - Log file encoding: UTF-8
  - If file logging fails, the program continues with console logging only
  - Log format: `%(asctime)s - %(levelname)s - %(message)s`
- **Diagnostic Logging**: The program provides comprehensive diagnostic information to help troubleshoot issues:
  - At the start of sync: Logs how many existing pages were found in Confluence
  - During page matching: Logs which matching method succeeded (file path label vs title matching)
  - When matching fails: Logs warnings with details including:
    - The file path and title that couldn't be matched
    - The number of existing pages searched
    - A list of existing page titles (for small sets) to help identify why matching failed
  - During label operations: Logs success/failure of label setting with clear error messages
  - This diagnostic information helps identify why duplicate pages might be created

## 9. Security Considerations

- Never log or expose API tokens in output
- Handle sensitive information appropriately
- Validate input parameters before processing

## 10. Limitations

- Images in Markdown files are not processed or uploaded
- Links are not converted to Confluence page links
- The program does not handle Confluence page moves (only creates/updates/deletes)
- Parent relationship updates may be limited by Confluence API capabilities
- **Label Dependencies**: File path tracking via labels requires the atlassian-python-api library to support `get_page_labels` and `set_page_label` methods. If these methods are not available or fail, the program falls back to title matching, which may be less reliable if titles change or collision resolution occurs.
- **Label Format**: File paths are hex-encoded in labels to comply with Confluence restrictions. The format is `syncfilepath{hex_encoded_path}` where the path is encoded as hexadecimal (lowercase). This ensures labels are Confluence-compliant (lowercase, no special characters, under 255 chars).
- **Duplicate Prevention**: The program uses multiple matching strategies to prevent duplicate pages, but if all matching methods fail (labels unavailable and title matching fails), duplicate pages may still be created. The enhanced logging helps diagnose these cases.
