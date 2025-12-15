# AI Agent Instructions: Delete Pages Tool

## Overview

You are an AI agent responsible for maintaining and enhancing the **Delete Pages Tool** (`delete_pages.py`).

**IMPORTANT**: All functional requirements are documented in `DELETE_PAGES_REQUIREMENTS.md`. Always refer to that file for WHAT the tool should do. This document focuses on HOW to work on the tool.

## Project Structure

```
delete_pages/
├── delete_pages.py                    # Main application code
├── delete_pages.bat                    # Windows batch file for execution
├── requirements.txt                    # Python dependencies
├── DELETE_PAGES_REQUIREMENTS.md       # Functional requirements (MUST UPDATE)
└── AGENT_INSTRUCTIONS.md              # This file
```

## Core Responsibilities

### 1. Code Development
- Implement new features according to requirements
- Fix bugs and improve existing functionality
- Maintain code quality and consistency
- Follow existing code patterns and architecture

### 2. Requirements Documentation (CRITICAL)
**ALWAYS update `DELETE_PAGES_REQUIREMENTS.md` when:**
- A new feature is requested
- A feature is modified
- A bug fix changes behavior
- Edge cases are discovered
- Limitations are identified
- JSON file format changes
- Command-line arguments change

**Update process:**
1. Read the current `DELETE_PAGES_REQUIREMENTS.md` to understand existing requirements
2. Identify which sections need updates
3. Update the relevant sections with new/changed requirements
4. Ensure requirements are clear, testable, and complete
5. Maintain consistency with existing documentation style

### 3. Testing (CRITICAL)
**ALWAYS update tests when:**
- A new feature is implemented
- A bug is fixed (add regression test)
- Edge cases are handled
- Requirements change

**Note**: Currently, there is no dedicated test file. If tests are needed:
- Create `test_delete_pages.py` following pytest conventions
- Mock the Confluence API client
- Test all code paths including error cases
- Run tests: `python -m pytest test_delete_pages.py -v`

## Key Components

### Main Functions

1. **`load_pages_list(json_file: Path) -> Optional[Dict]`**
   - Loads and validates JSON file
   - Handles file not found, invalid JSON, and other errors
   - Returns None on failure

2. **`delete_pages(confluence: Confluence, pages: List[Dict], dry_run: bool = False) -> tuple[int, int]`**
   - Core deletion logic
   - Handles dry-run mode
   - Returns (successful_count, failed_count)
   - Continues processing even if individual deletions fail

3. **`main()`**
   - Entry point
   - Parses command-line arguments
   - Handles authentication
   - Coordinates the deletion process
   - Provides user feedback

### Key Features

Refer to `DELETE_PAGES_REQUIREMENTS.md` for detailed feature descriptions. The main areas of functionality include:
- JSON file loading and validation
- Authentication and connection handling
- Page deletion with safety features
- User confirmation and dry-run mode
- Error handling and logging
- Progress feedback and reporting

See the requirements file for complete specifications.

## Development Guidelines

### Code Style
- Follow PEP 8 Python style guide
- Use type hints where appropriate
- Write clear, descriptive function and variable names
- Add docstrings for all public functions
- Keep functions focused and single-purpose

### Error Handling
- Use try-except blocks for API calls and file operations
- Log errors with appropriate levels (DEBUG, INFO, WARNING, ERROR)
- Provide meaningful error messages
- Continue processing remaining pages if one fails
- Track successful vs failed operations

### Logging
- Use the `logger` object (configured in `delete_pages.py`)
- Log to both console and file (`delete_pages.log`)
- Log at appropriate levels:
  - DEBUG: Detailed diagnostic information
  - INFO: Normal operations and progress
  - WARNING: Recoverable issues (e.g., page not found)
  - ERROR: Failures that need attention
- Include context in log messages (page IDs, titles, error details)

### API Interactions
- Use `atlassian-python-api` library (`Confluence` class)
- Handle API errors gracefully
- Test connection before proceeding
- Use `remove_page()` method for deletion
- Handle cases where page doesn't exist

### User Interface
- Use ASCII-safe characters (no Unicode emojis) for Windows compatibility
- Format output clearly with separators
- Show progress indicators: `[OK]`, `[FAIL]`, `[WARNING]`, `[DRY RUN]`
- Provide clear confirmation prompts
- Handle EOF/KeyboardInterrupt gracefully for non-interactive environments

## Common Workflows

### Adding a New Feature

1. **Understand Requirements**
   - Read `DELETE_PAGES_REQUIREMENTS.md`
   - Clarify any ambiguities
   - Identify affected components

2. **Update Requirements**
   - Add/update relevant sections in `DELETE_PAGES_REQUIREMENTS.md`
   - Document edge cases and limitations
   - Specify error handling requirements
   - Document command-line arguments if changed

3. **Design Implementation**
   - Identify which functions need changes
   - Plan backward compatibility
   - Consider impact on existing functionality

4. **Implement Code**
   - Write code following existing patterns
   - Add appropriate logging
   - Handle errors gracefully
   - Update command-line argument parsing if needed

5. **Write Tests (if applicable)**
   - Add unit tests for new functionality
   - Add integration tests if needed
   - Test edge cases and error conditions
   - Ensure existing tests still pass

6. **Update Documentation**
   - Update `DELETE_PAGES_REQUIREMENTS.md`
   - Update docstrings
   - Update usage examples if needed

7. **Verify**
   - Test manually with sample JSON file
   - Test dry-run mode
   - Test error scenarios
   - Check logging output

### Fixing a Bug

1. **Reproduce the Issue**
   - Understand the bug from user report or logs
   - Identify root cause
   - Check if it's a requirements gap

2. **Update Requirements (if needed)**
   - If behavior was incorrect, update `DELETE_PAGES_REQUIREMENTS.md`
   - Document the expected behavior

3. **Fix the Code**
   - Implement the fix
   - Ensure it doesn't break existing functionality

4. **Add Regression Test (if applicable)**
   - Write a test that reproduces the bug
   - Verify the test fails before fix
   - Verify the test passes after fix

5. **Update Requirements**
   - Document the fix in `DELETE_PAGES_REQUIREMENTS.md` if it changes behavior

6. **Verify**
   - Test the specific bug scenario
   - Test related functionality

## Testing Guidelines

### Test Structure (if creating tests)
- Use pytest framework
- Mock the Confluence API client
- Test all code paths including error cases
- Test dry-run mode
- Test confirmation prompts (may need to mock input)

### Test Categories
- **Unit Tests**: Test individual functions
- **Integration Tests**: Test complete workflows
- **Edge Case Tests**: Test boundary conditions (empty lists, invalid JSON, etc.)
- **Error Handling Tests**: Test error scenarios (API failures, missing pages, etc.)

### Running Tests (if tests exist)
```bash
# Run all tests
python -m pytest test_delete_pages.py -v

# Run with coverage
python -m pytest test_delete_pages.py --cov=delete_pages --cov-report=html
```

## Requirements Documentation Guidelines

### Structure
Follow the existing structure in `DELETE_PAGES_REQUIREMENTS.md`:
- Overview and Purpose
- Input Parameters
- JSON File Format
- Core Functionality (detailed sections)
- Error Handling
- Logging
- User Interface
- Batch File Support
- Security Considerations
- Dependencies
- Exit Codes
- Usage Examples
- Integration with confluence_sync.py
- Limitations

### Writing Requirements
- Be specific and testable
- Include examples where helpful (especially JSON format)
- Document edge cases
- Specify error handling
- Note limitations and dependencies
- Use clear, unambiguous language
- Document command-line arguments clearly

### When to Update
- **New Feature**: Add new section or subsection
- **Feature Change**: Update existing section
- **Bug Fix**: Update if behavior changes
- **Edge Case**: Add to relevant section
- **Limitation**: Add to Limitations section
- **JSON Format Change**: Update JSON File Format section
- **CLI Change**: Update Input Parameters section

## Dependencies

### Required Libraries
- `atlassian-python-api>=3.41.0`: Confluence API client

### Standard Libraries Used
- `json`: JSON file parsing
- `sys`: System operations and exit codes
- `logging`: Logging functionality
- `argparse`: Command-line argument parsing
- `pathlib`: Path handling
- `datetime`: Timestamp handling

## Important Notes

### Implementation Details

For specific implementation details about:
- JSON file format: See `DELETE_PAGES_REQUIREMENTS.md` Section 4
- Authentication: See `DELETE_PAGES_REQUIREMENTS.md` Section 5.2
- Safety features: See `DELETE_PAGES_REQUIREMENTS.md` Section 5.4 and 5.5
- Batch file support: See `DELETE_PAGES_REQUIREMENTS.md` Section 9

Always refer to the requirements file for the complete specifications of what needs to be implemented.

## Workflow Checklist

When working on any task, ensure:

- [ ] Requirements are understood
- [ ] `DELETE_PAGES_REQUIREMENTS.md` is updated (if needed)
- [ ] Code is implemented following guidelines
- [ ] Tests are written/updated (if applicable)
- [ ] All tests pass (if applicable)
- [ ] Logging is appropriate
- [ ] Error handling is comprehensive
- [ ] Documentation is updated
- [ ] Command-line interface is updated (if needed)
- [ ] Batch file is updated (if needed)
- [ ] Backward compatibility is maintained (if applicable)

## Common Issues and Solutions

### Issue: Script exits without deleting
- **Check**: EOF/KeyboardInterrupt handling for prompts
- **Check**: Authentication is working
- **Check**: JSON file format is correct
- **Solution**: Review `main()` function and input handling

### Issue: Unicode encoding errors
- **Check**: Use ASCII-safe characters in print statements
- **Check**: Log file encoding is UTF-8
- **Solution**: Replace Unicode emojis with ASCII alternatives

### Issue: Connection test fails
- **Check**: `get_page_by_id()` method exists
- **Check**: Root page ID from JSON is valid
- **Solution**: Use valid API method for connection test

### Issue: Batch file not working
- **Check**: Python path is correct
- **Check**: Script path uses `%~dp0`
- **Check**: Arguments are passed correctly
- **Solution**: Review batch file argument passing logic

## Questions to Ask

If requirements are unclear:
1. What is the expected behavior?
2. What are the edge cases?
3. How should errors be handled?
4. What should be logged?
5. Are there any limitations?
6. Does this affect JSON file format?
7. Does this require CLI changes?
8. Does this affect the batch file?

## Success Criteria

A task is complete when:
- ✅ Code is implemented and working
- ✅ `DELETE_PAGES_REQUIREMENTS.md` is updated
- ✅ Tests are written and passing (if applicable)
- ✅ Documentation is updated
- ✅ Code follows style guidelines
- ✅ Error handling is appropriate
- ✅ Logging is comprehensive
- ✅ Command-line interface works correctly
- ✅ Batch file works correctly (if applicable)

## Integration Notes

### Relationship with confluence_sync.py
- This tool consumes JSON files generated by `confluence_sync.py`
- See `DELETE_PAGES_REQUIREMENTS.md` Section 14 for integration details
- If JSON format changes, coordinate with confluence_sync tool
- Always refer to requirements for JSON format specifications

## Special Considerations

### Non-Interactive Environments
- Handle `EOFError` and `KeyboardInterrupt` for prompts
- Provide clear error messages when input is not available
- Exit gracefully with appropriate error codes

### Windows Compatibility
- Use ASCII-safe characters in output
- Handle path separators correctly
- Ensure batch file works correctly
- Test on Windows if possible

### Safety First
- Never delete without confirmation (unless dry-run)
- Always show what will be deleted
- Continue processing even if some deletions fail
- Provide detailed feedback on results

