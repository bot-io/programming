# AI Agent Instructions: Confluence Sync Tool

## Overview

You are an AI agent responsible for maintaining and enhancing the **Confluence Sync Tool** (`confluence_sync.py`). 

**IMPORTANT**: All functional requirements are documented in `FUNCTIONAL_REQUIREMENTS.md`. Always refer to that file for WHAT the tool should do. This document focuses on HOW to work on the tool.

## Project Structure

```
confluence_sync/
├── confluence_sync.py              # Main application code
├── sync_to_confluence.bat          # Windows batch file for execution
├── test_confluence_sync.py          # Comprehensive test suite
├── run_tests.bat                   # Test runner script
├── pytest.ini                      # Pytest configuration
├── requirements.txt                 # Python dependencies
├── README.md                        # User documentation
├── FUNCTIONAL_REQUIREMENTS.md      # Functional requirements (MUST UPDATE)
└── debug_sync.py                   # Debug utility (if exists)
```

## Core Responsibilities

### 1. Code Development
- Implement new features according to requirements
- Fix bugs and improve existing functionality
- Maintain code quality and consistency
- Follow existing code patterns and architecture

### 2. Requirements Documentation (CRITICAL)
**ALWAYS update `FUNCTIONAL_REQUIREMENTS.md` when:**
- A new feature is requested
- A feature is modified
- A bug fix changes behavior
- Edge cases are discovered
- Limitations are identified

**Update process:**
1. Read the current `FUNCTIONAL_REQUIREMENTS.md` to understand existing requirements
2. Identify which sections need updates
3. Update the relevant sections with new/changed requirements
4. Ensure requirements are clear, testable, and complete
5. Maintain consistency with existing documentation style

### 3. Testing (CRITICAL)
**ALWAYS update `test_confluence_sync.py` when:**
- A new feature is implemented
- A bug is fixed (add regression test)
- Edge cases are handled
- Requirements change

**Testing requirements:**
- Write comprehensive unit tests for new functionality
- Add integration tests for complex workflows
- Ensure test coverage for edge cases
- Run tests before completing any task: `python -m pytest test_confluence_sync.py -v`
- All tests must pass before considering work complete

## Key Components

### Main Classes

1. **`MarkdownConverter`**
   - Static methods for Markdown processing
   - `extract_title()`: Extracts title from Markdown content
   - `sanitize_title()`: Sanitizes titles for Confluence
   - `markdown_to_confluence()`: Converts Markdown to Confluence format

2. **`ConfluenceSync`**
   - Main synchronization class
   - Handles directory traversal, page operations, and state management
   - Key methods:
     - `_traverse_directory()`: Scans local directory
     - `_build_operations()`: Determines create/update/delete operations
     - `_execute_operations()`: Performs Confluence API operations
     - `_find_page_by_path()`: Matches files to Confluence pages
     - `_resolve_parent_id()`: Resolves parent page relationships

3. **`SyncState`**
   - Tracks created/updated/deleted pages for rollback

4. **`PageOperation`** and **`OperationType`**
   - Represents operations to be performed

### Key Features

Refer to `FUNCTIONAL_REQUIREMENTS.md` for detailed feature descriptions. The main areas of functionality include:
- Directory traversal and file processing
- Page synchronization (create, update, delete)
- Page identification and matching
- Change detection
- Error handling and rollback
- Created pages tracking

See the requirements file for complete specifications.

## Development Guidelines

### Code Style
- Follow PEP 8 Python style guide
- Use type hints where appropriate
- Write clear, descriptive function and variable names
- Add docstrings for all public methods
- Keep functions focused and single-purpose

### Error Handling
- Use try-except blocks for API calls
- Log errors with appropriate levels (DEBUG, INFO, WARNING, ERROR)
- Provide meaningful error messages
- Continue processing where possible (don't fail entire sync for one error)

### Logging
- Use the `logger` object (configured in `confluence_sync.py`)
- Log at appropriate levels:
  - DEBUG: Detailed diagnostic information
  - INFO: Normal operations and progress
  - WARNING: Recoverable issues or fallbacks
  - ERROR: Failures that need attention
- Include context in log messages (file paths, page IDs, etc.)

### API Interactions
- Use `atlassian-python-api` library (`Confluence` class)
- Handle API errors gracefully
- Implement retries for transient failures if needed
- Validate API responses before using them

### Path Handling
- Always normalize paths (use forward slashes)
- Use `Path` objects from `pathlib` for file operations
- Handle both Windows and Unix path separators

## Common Workflows

### Adding a New Feature

1. **Understand Requirements**
   - Read `FUNCTIONAL_REQUIREMENTS.md`
   - Clarify any ambiguities
   - Identify affected components

2. **Update Requirements**
   - Add/update relevant sections in `FUNCTIONAL_REQUIREMENTS.md`
   - Document edge cases and limitations
   - Specify error handling requirements

3. **Design Implementation**
   - Identify which classes/methods need changes
   - Plan backward compatibility
   - Consider impact on existing functionality

4. **Implement Code**
   - Write code following existing patterns
   - Add appropriate logging
   - Handle errors gracefully

5. **Write Tests**
   - Add unit tests for new functionality
   - Add integration tests if needed
   - Test edge cases and error conditions
   - Ensure existing tests still pass

6. **Update Documentation**
   - Update `README.md` if user-facing changes
   - Update docstrings
   - Update `FUNCTIONAL_REQUIREMENTS.md` if needed

7. **Verify**
   - Run test suite: `python -m pytest test_confluence_sync.py -v`
   - Check for linting errors
   - Verify logging output

### Fixing a Bug

1. **Reproduce the Issue**
   - Understand the bug from user report or logs
   - Identify root cause
   - Check if it's a requirements gap

2. **Update Requirements (if needed)**
   - If behavior was incorrect, update `FUNCTIONAL_REQUIREMENTS.md`
   - Document the expected behavior

3. **Fix the Code**
   - Implement the fix
   - Ensure it doesn't break existing functionality

4. **Add Regression Test**
   - Write a test that reproduces the bug
   - Verify the test fails before fix
   - Verify the test passes after fix

5. **Update Requirements**
   - Document the fix in `FUNCTIONAL_REQUIREMENTS.md` if it changes behavior

6. **Verify**
   - Run all tests
   - Test the specific bug scenario

## Testing Guidelines

### Test Structure
- Use pytest framework
- Organize tests by class/component
- Use fixtures for common setup (see `test_confluence_sync.py`)
- Mock external dependencies (Confluence API)

### Test Categories
- **Unit Tests**: Test individual methods/functions
- **Integration Tests**: Test complete workflows
- **Edge Case Tests**: Test boundary conditions
- **Error Handling Tests**: Test error scenarios

### Running Tests
```bash
# Run all tests
python -m pytest test_confluence_sync.py -v

# Run specific test class
python -m pytest test_confluence_sync.py::TestMarkdownConverter -v

# Run with coverage
python -m pytest test_confluence_sync.py --cov=confluence_sync --cov-report=html
```

### Test Fixtures
- `temp_dir`: Temporary directory for file operations
- `mock_confluence`: Mocked Confluence API client
- `sync_tool`: ConfluenceSync instance with mocked API

## Requirements Documentation Guidelines

### Structure
Follow the existing structure in `FUNCTIONAL_REQUIREMENTS.md`:
- Overview and Purpose
- Input Parameters
- Core Functionality (detailed sections)
- Behavior Specifications
- Edge Cases
- User Interface
- Technical Requirements
- Security Considerations
- Limitations

### Writing Requirements
- Be specific and testable
- Include examples where helpful
- Document edge cases
- Specify error handling
- Note limitations and dependencies
- Use clear, unambiguous language

### When to Update
- **New Feature**: Add new section or subsection
- **Feature Change**: Update existing section
- **Bug Fix**: Update if behavior changes
- **Edge Case**: Add to Edge Cases section
- **Limitation**: Add to Limitations section

## Dependencies

### Required Libraries
- `atlassian-python-api>=3.41.0`: Confluence API client
- `markdown>=3.4.0`: Markdown processing
- `beautifulsoup4>=4.12.0`: HTML parsing
- `lxml>=4.9.0`: XML/HTML parser backend

### Test Dependencies
- `pytest>=7.4.0`: Testing framework
- `pytest-cov>=4.1.0`: Coverage reporting

## Important Notes

### Implementation Details

For specific implementation details about:
- File path labels and encoding: See `FUNCTIONAL_REQUIREMENTS.md` Section 4.6
- Page matching strategies: See `FUNCTIONAL_REQUIREMENTS.md` Section 4.6
- Change detection: See `FUNCTIONAL_REQUIREMENTS.md` Section 4.5
- Directory handling: See `FUNCTIONAL_REQUIREMENTS.md` Section 4.4

Always refer to the requirements file for the complete specifications of what needs to be implemented.

## Workflow Checklist

When working on any task, ensure:

- [ ] Requirements are understood
- [ ] `FUNCTIONAL_REQUIREMENTS.md` is updated (if needed)
- [ ] Code is implemented following guidelines
- [ ] Tests are written/updated
- [ ] All tests pass
- [ ] Logging is appropriate
- [ ] Error handling is comprehensive
- [ ] Documentation is updated
- [ ] Backward compatibility is maintained (if applicable)

## Common Issues and Solutions

### Issue: Duplicate pages created
- **Check**: Label setting is working
- **Check**: Title matching fallback logic
- **Check**: Logs for matching failures
- **Solution**: Review `_find_page_by_path()` logic

### Issue: Parent resolution fails
- **Check**: Path normalization
- **Check**: Created pages cache
- **Check**: Existing pages map
- **Solution**: Review `_resolve_parent_id()` logic

### Issue: Tests failing
- **Check**: Mock setup is correct
- **Check**: Test data matches expected format
- **Check**: API method names haven't changed
- **Solution**: Review test fixtures and mocks

## Questions to Ask

If requirements are unclear:
1. What is the expected behavior?
2. What are the edge cases?
3. How should errors be handled?
4. What should be logged?
5. Are there any limitations?
6. Does this affect existing functionality?

## Success Criteria

A task is complete when:
- ✅ Code is implemented and working
- ✅ `FUNCTIONAL_REQUIREMENTS.md` is updated
- ✅ Tests are written and passing
- ✅ Documentation is updated
- ✅ Code follows style guidelines
- ✅ Error handling is appropriate
- ✅ Logging is comprehensive

