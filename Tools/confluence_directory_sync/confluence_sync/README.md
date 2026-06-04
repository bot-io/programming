# Directory to Confluence Sync Tool

A Python program that synchronizes Markdown files from a local directory structure to Confluence pages, maintaining the directory hierarchy and ensuring consistency between the local filesystem and Confluence.

## Features

- ✅ Recursively traverses directories and processes all Markdown files (`.md`, `.markdown`)
- ✅ Creates Confluence pages from Markdown files with proper hierarchy
- ✅ Creates empty parent pages for subdirectories
- ✅ Updates existing pages when content changes (with versioning)
- ✅ Deletes orphaned pages that no longer exist in the directory
- ✅ Preview changes before execution
- ✅ User confirmation for destructive operations
- ✅ Error handling with rollback capability
- ✅ Preserves Markdown formatting (headings, code blocks, lists, tables, etc.)
- ✅ Ignores images (as per requirements)
- ✅ Preserves links as-is

## Requirements

- Python 3.7 or higher
- Confluence Cloud account with API access
- Confluence API token

## Installation

1. Clone or download this repository

2. Install required dependencies:
```bash
pip install -r requirements.txt
```

## Configuration

### Getting a Confluence API Token

1. Log in to your Confluence instance
2. Go to your account settings
3. Navigate to Security → API tokens
4. Create a new API token
5. Copy the token (you'll need it for the command)

## Usage

### Basic Usage

```bash
python confluence_sync.py <directory_path> <confluence_page_id> \
    --url https://your-domain.atlassian.net \
    --username your-email@example.com \
    --api-token YOUR_API_TOKEN
```

### Arguments

- `directory_path`: Path to the directory containing Markdown files (absolute or relative)
- `confluence_page_id`: ID of the root Confluence page that will serve as the parent for all created pages
- `--url`: Your Confluence instance URL (e.g., `https://your-domain.atlassian.net`)
- `--username`: Your Confluence username or email address
- `--api-token`: Your Confluence API token
- `--log-file`: (Optional) Path to log file. If not specified, defaults to `confluence_sync.log` in the current directory
- `--log-level`: (Optional) Logging level: DEBUG, INFO, WARNING, or ERROR (default: INFO)
- `--dry-run`: (Optional) Preview changes without executing them
- `--dry-run`: (Optional) Preview changes without executing them

### Example

```bash
python confluence_sync.py ./docs 123456 \
    --url https://mycompany.atlassian.net \
    --username john.doe@mycompany.com \
    --api-token ATATT3xFfGF0...
```

### Dry Run Mode

To preview changes without making any modifications:

```bash
python confluence_sync.py ./docs 123456 \
    --url https://mycompany.atlassian.net \
    --username john.doe@mycompany.com \
    --api-token ATATT3xFfGF0... \
    --dry-run
```

## How It Works

### Initial Run

1. The program traverses the specified directory structure
2. For each subdirectory, it creates an empty Confluence page (parent page)
3. For each Markdown file, it:
   - Extracts the title from the first heading (`# Title`) or uses the filename
   - Converts Markdown content to Confluence format
   - Creates a Confluence page with the content
4. Establishes the correct parent-child relationships matching the directory structure

### Subsequent Runs

1. The program compares the current directory state with existing Confluence pages
2. Generates a preview of all changes (create, update, delete operations)
3. Displays the preview and requests user confirmation
4. If confirmed:
   - **Updates** pages that correspond to existing files/folders (creates new versions)
   - **Creates** pages for new files/folders
   - **Deletes** Confluence pages that no longer have corresponding files/folders (with separate confirmation)
5. If not confirmed, aborts without making changes

### Page Title Extraction

- The program extracts the page title from the first heading in the Markdown file (`# Title`)
- If no heading exists, it uses the filename (without extension)
- Directory names are sanitized to create valid Confluence page titles

### Markdown Conversion

- Markdown content is converted to Confluence storage format
- Images are ignored (not processed or uploaded)
- Links are preserved as-is (no conversion to Confluence page links)
- Other formatting (headings, code blocks, lists, tables) is preserved

## Directory Structure Example

```
docs/
├── README.md
├── getting-started/
│   ├── installation.md
│   └── configuration.md
└── advanced/
    ├── api-reference.md
    └── troubleshooting.md
```

This structure will create:
- Root page (specified by `confluence_page_id`)
  - README (from README.md)
  - getting-started (empty parent page)
    - installation (from installation.md)
    - configuration (from configuration.md)
  - advanced (empty parent page)
    - api-reference (from api-reference.md)
    - troubleshooting (from troubleshooting.md)

## Error Handling

- The program handles invalid directory paths, inaccessible Confluence pages, and network errors
- If the program fails partway through execution, it attempts to roll back all changes made during the current run
- Meaningful error messages are provided for troubleshooting

## Limitations

- **Images**: Images in Markdown files are ignored (not uploaded to Confluence)
- **Links**: Links are preserved as-is and not converted to Confluence page links
- **Concurrent Execution**: The program assumes no concurrent runs (single instance execution)
- **Page Identification**: Page identification is based on titles and hierarchy. If multiple files would create pages with the same title, conflicts may occur.

## Security Notes

- Never commit your API token to version control
- Consider using environment variables for sensitive information:
  ```bash
  export CONFLUENCE_API_TOKEN="your-token-here"
  python confluence_sync.py ./docs 123456 \
      --url https://mycompany.atlassian.net \
      --username john.doe@mycompany.com \
      --api-token "$CONFLUENCE_API_TOKEN"
  ```

## Troubleshooting

### "Root page ID not found or not accessible"
- Verify the page ID is correct
- Ensure your API token has access to the page
- Check that the page exists in the Confluence instance

### "Invalid directory path"
- Ensure the path is correct and accessible
- Use absolute paths if relative paths don't work
- Check file permissions

### "Error during sync"
- Check your internet connection
- Verify your API token is valid and not expired
- Check Confluence API rate limits
- Review the error message for specific details

## Logging

The program logs all operations to both the console and a log file for easier debugging:

- **Default log file**: `confluence_sync.log` in the current working directory
- **Custom log file**: Use `--log-file` to specify a different path
- **Log levels**: Use `--log-level` to set the verbosity (DEBUG, INFO, WARNING, ERROR)
- **Log format**: `%(asctime)s - %(levelname)s - %(message)s`
- **File encoding**: UTF-8
- **Append mode**: Multiple runs append to the same log file

Example:
```bash
python confluence_sync.py <directory_path> <confluence_page_id> \
    --url https://your-domain.atlassian.net \
    --username your-email@example.com \
    --api-token YOUR_API_TOKEN \
    --log-file /path/to/custom.log \
    --log-level DEBUG
```

## Testing

A comprehensive test suite is included to verify all functionality and edge cases.

### Running Tests

Install test dependencies:
```bash
pip install -r requirements.txt
```

Run all tests:
```bash
pytest test_confluence_sync.py -v
```

Run with coverage report:
```bash
pytest test_confluence_sync.py --cov=confluence_sync --cov-report=html
```

### Test Coverage

The test suite covers:

- **MarkdownConverter Tests**: Title extraction, sanitization, Markdown conversion
- **Directory Traversal Tests**: Simple and nested structures, file filtering, encoding
- **Page Operations Tests**: Create, update, delete operations, nested structures
- **Edge Cases**: Special characters, empty files, Unicode, deeply nested structures
- **Error Handling**: Invalid paths, API errors, file read errors, rollback
- **Integration Tests**: Full workflow, update scenarios
- **Preview Tests**: Operation preview display

### Test Structure

- `TestMarkdownConverter`: Tests for Markdown conversion utilities
- `TestDirectoryTraversal`: Tests for directory scanning and file discovery
- `TestPageOperations`: Tests for building and executing page operations
- `TestEdgeCases`: Tests for edge cases and special scenarios
- `TestErrorHandling`: Tests for error conditions and recovery
- `TestIntegration`: End-to-end workflow tests
- `TestPreview`: Tests for preview and confirmation functionality

## License

This project is provided as-is for use according to your organization's policies.
