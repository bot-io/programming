"""
Cleanup utilities for supervisor agent - safely removes temporary files
"""

import os
import glob
from typing import List, Set
from datetime import datetime, timedelta

# Protected directories that should NEVER be deleted
PROTECTED_DIRS = {
    'lib', 'test', 'android', 'ios', 'web', 'assets', 'scripts',
    'docs', 'progress_reports', 'agent_logs', '.git', 'node_modules',
    'build', 'dist', 'out', '.dart_tool', '.idea', '.vscode'
}

# Protected file patterns that should NEVER be deleted
# CRITICAL: run_team.py is required infrastructure - without it, the team cannot start
PROTECTED_FILE_PATTERNS = [
    'pubspec.yaml', 'pubspec.lock', 'requirements.md', 'tasks.md',
    'README.md', 'LICENSE', '.gitignore', '.gitattributes',
    'analysis_options.yaml', 'build.yaml', 'run_team.py',  # Infrastructure file - MUST be preserved
    'check_task_status.py', 'view_progress_history.py'
]

# Temporary file patterns that CAN be safely deleted
TEMPORARY_PATTERNS = [
    'test_write.txt',
    'agent_debug.log',
    '*.tmp',
    '*.temp',
    '*.bak',
    '*.swp',
    '*.swo',
    '*.~',
    '.DS_Store',
    'Thumbs.db'
]

# Temporary directories that can be cleaned (if empty or old)
TEMPORARY_DIRS = [
    'workspaces',  # Agent workspaces
    '__pycache__',  # Python cache
    '.pytest_cache',  # Pytest cache
]

# File patterns in src/ that look like temporary task files
TEMP_TASK_FILE_PATTERNS = [
    'src/task_*.dart',  # Temporary task files in src/
]

# Test files that shouldn't be in the project (e.g., Python test files in Dart project)
TEMP_TEST_PATTERNS = [
    'test/*.test.py',  # Python test files in Dart project
]

def is_protected_path(path: str, project_dir: str) -> bool:
    """Check if a path is protected and should not be deleted"""
    rel_path = os.path.relpath(path, project_dir) if project_dir else path
    
    # Check if it's in a protected directory
    path_parts = rel_path.split(os.sep)
    if path_parts and path_parts[0] in PROTECTED_DIRS:
        return True
    
    # Check if it matches a protected file pattern
    filename = os.path.basename(rel_path)
    for pattern in PROTECTED_FILE_PATTERNS:
        if filename == pattern or filename.endswith(pattern):
            return True
    
    return False

def get_temporary_files(project_dir: str, max_age_hours: int = 24) -> List[str]:
    """Get list of temporary files that can be safely deleted"""
    temp_files = []
    cutoff_time = datetime.now() - timedelta(hours=max_age_hours)
    
    # Check temporary file patterns
    for pattern in TEMPORARY_PATTERNS:
        if '*' in pattern:
            # Glob pattern
            matches = glob.glob(os.path.join(project_dir, pattern), recursive=True)
            for match in matches:
                if not is_protected_path(match, project_dir):
                    try:
                        mtime = datetime.fromtimestamp(os.path.getmtime(match))
                        if mtime < cutoff_time:
                            temp_files.append(match)
                    except OSError:
                        pass
        else:
            # Exact filename
            filepath = os.path.join(project_dir, pattern)
            if os.path.exists(filepath) and not is_protected_path(filepath, project_dir):
                try:
                    mtime = datetime.fromtimestamp(os.path.getmtime(filepath))
                    if mtime < cutoff_time:
                        temp_files.append(filepath)
                except OSError:
                    pass
    
    # Check temporary task files in src/
    for pattern in TEMP_TASK_FILE_PATTERNS:
        matches = glob.glob(os.path.join(project_dir, pattern))
        for match in matches:
            if not is_protected_path(match, project_dir):
                try:
                    mtime = datetime.fromtimestamp(os.path.getmtime(match))
                    if mtime < cutoff_time:
                        temp_files.append(match)
                except OSError:
                    pass
    
    # Check temporary test files
    for pattern in TEMP_TEST_PATTERNS:
        matches = glob.glob(os.path.join(project_dir, pattern))
        for match in matches:
            if not is_protected_path(match, project_dir):
                try:
                    mtime = datetime.fromtimestamp(os.path.getmtime(match))
                    if mtime < cutoff_time:
                        temp_files.append(match)
                except OSError:
                    pass
    
    return temp_files

def cleanup_empty_directories(project_dir: str, dir_patterns: List[str]) -> List[str]:
    """Clean up empty temporary directories"""
    cleaned = []
    
    for pattern in dir_patterns:
        if '*' in pattern:
            matches = glob.glob(os.path.join(project_dir, pattern), recursive=True)
        else:
            dirpath = os.path.join(project_dir, pattern)
            matches = [dirpath] if os.path.exists(dirpath) else []
        
        for dirpath in matches:
            if not is_protected_path(dirpath, project_dir):
                try:
                    # Check if directory is empty
                    if os.path.isdir(dirpath) and len(os.listdir(dirpath)) == 0:
                        os.rmdir(dirpath)
                        cleaned.append(dirpath)
                except OSError:
                    pass
    
    return cleaned

