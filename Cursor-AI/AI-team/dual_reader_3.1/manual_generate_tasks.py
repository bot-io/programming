"""
Manually trigger task generation from requirements.md
"""
import sys
import os

# Add parent directory to path
parent_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, parent_dir)

from supervisor_agent import SupervisorAgent
from agent_coordinator import AgentCoordinator
from task_config_parser import TaskConfigParser

def main():
    project_dir = os.path.dirname(os.path.abspath(__file__))
    
    # Create coordinator
    coordinator = AgentCoordinator()
    
    # Create supervisor
    supervisor = SupervisorAgent("supervisor-agent-1", coordinator)
    supervisor.project_dir = project_dir
    
    # Load existing tasks
    parser = TaskConfigParser(project_dir)
    tasks = parser.parse_tasks()
    for task in tasks:
        coordinator.add_task(task)
    
    print(f"Current tasks: {len(coordinator.tasks)}")
    for task_id, task in coordinator.tasks.items():
        print(f"  - {task_id}: {task.title}")
    
    # Check for template tasks
    print("\nChecking for template tasks...")
    template_issue = supervisor._check_template_tasks_only()
    
    if template_issue:
        print(f"\n✓ Found issue: {template_issue['type']}")
        print("Generating tasks from requirements...")
        success = supervisor._generate_tasks_from_requirements()
        if success:
            print("\n✓ Tasks generated successfully!")
            # Reload tasks
            new_tasks = parser.parse_tasks()
            print(f"\nNew tasks count: {len(new_tasks)}")
            for task in new_tasks[:10]:  # Show first 10
                print(f"  - {task.id}: {task.title}")
        else:
            print("\n✗ Failed to generate tasks")
    else:
        print("\nNo template tasks detected")

if __name__ == '__main__':
    main()
