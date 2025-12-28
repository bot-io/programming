"""
Manually reset a stuck task to ready status
"""
import sys
import os
import json
from datetime import datetime

# Add parent directory to path
parent_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, parent_dir)

from agent_coordinator import AgentCoordinator, TaskStatus
from task_config_parser import TaskConfigParser

def reset_stuck_task(task_id: str):
    project_dir = os.path.dirname(os.path.abspath(__file__))
    
    # Create coordinator
    coordinator = AgentCoordinator()
    
    # Load tasks
    parser = TaskConfigParser(project_dir)
    tasks = parser.parse_tasks()
    for task in tasks:
        coordinator.add_task(task)
    
    # Find the stuck task
    if task_id not in coordinator.tasks:
        print(f"Task {task_id} not found")
        return False
    
    task = coordinator.tasks[task_id]
    print(f"Found task: {task.id} - {task.title}")
    print(f"  Status: {task.status.value}")
    print(f"  Progress: {task.progress}%")
    print(f"  Assigned to: {task.assigned_agent}")
    print(f"  Started at: {task.started_at}")
    
    if task.status == TaskStatus.IN_PROGRESS:
        print(f"\nResetting task {task_id} to READY...")
        task.status = TaskStatus.READY
        task.assigned_agent = None
        if task.assigned_agent in coordinator.agent_workloads:
            coordinator.agent_workloads[task.assigned_agent] = max(
                0, coordinator.agent_workloads[task.assigned_agent] - 1
            )
        print(f"Task {task_id} reset to READY")
        return True
    else:
        print(f"Task is not in progress (status: {task.status.value})")
        return False

if __name__ == '__main__':
    task_id = 'task-017'
    if len(sys.argv) > 1:
        task_id = sys.argv[1]
    
    reset_stuck_task(task_id)

