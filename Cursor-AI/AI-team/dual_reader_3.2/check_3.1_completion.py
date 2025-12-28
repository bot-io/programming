"""
Check if Dual Reader 3.1 project is completed before starting 3.2
"""
# -*- coding: utf-8 -*-

import sys
import os

# Add parent directory to path
parent_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, parent_dir)

from src.ai_team.utils.task_config_parser import TaskConfigParser
from src.ai_team.agents.agent_coordinator import TaskStatus


def check_3_1_completion() -> tuple[bool, str]:
    """
    Check if Dual Reader 3.1 is completed.
    Returns (is_completed, message)
    """
    project_3_1_dir = os.path.join(parent_dir, 'dual_reader_3.1')
    
    if not os.path.exists(project_3_1_dir):
        return False, "Dual Reader 3.1 directory does not exist"
    
    tasks_file = os.path.join(project_3_1_dir, 'tasks.md')
    if not os.path.exists(tasks_file):
        return False, "Dual Reader 3.1 tasks.md not found"
    
    try:
        parser = TaskConfigParser(project_3_1_dir)
        tasks = parser.parse_tasks()
        
        if not tasks:
            return False, "Dual Reader 3.1 has no tasks"
        
        total = len(tasks)
        completed = sum(1 for t in tasks if t.status == TaskStatus.COMPLETED)
        failed = sum(1 for t in tasks if t.status == TaskStatus.FAILED)
        in_progress = sum(1 for t in tasks if t.status == TaskStatus.IN_PROGRESS)
        ready = sum(1 for t in tasks if t.status == TaskStatus.READY)
        pending = sum(1 for t in tasks if t.status == TaskStatus.PENDING)
        
        # Check if all tasks are completed
        if completed == total:
            return True, f"Dual Reader 3.1 is complete! ({completed}/{total} tasks completed)"
        
        # Check if all tasks are finished (completed or failed)
        if completed + failed == total:
            return True, f"Dual Reader 3.1 is finished ({completed} completed, {failed} failed)"
        
        # Not complete
        progress_pct = (completed / total * 100) if total > 0 else 0
        return False, (
            f"Dual Reader 3.1 is not complete yet. "
            f"Progress: {completed}/{total} ({progress_pct:.1f}%) - "
            f"{in_progress} in progress, {ready} ready, {pending} pending"
        )
        
    except Exception as e:
        return False, f"Error checking Dual Reader 3.1 status: {e}"


if __name__ == '__main__':
    is_completed, message = check_3_1_completion()
    print(message)
    sys.exit(0 if is_completed else 1)

