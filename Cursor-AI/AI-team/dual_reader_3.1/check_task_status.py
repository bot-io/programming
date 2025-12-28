import sys
import os
# Add parent directory to path
parent_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, parent_dir)

from src.ai_team.utils.task_config_parser import TaskConfigParser
from src.ai_team.agents.agent_coordinator import TaskStatus

parser = TaskConfigParser('.')
tasks = parser.parse_tasks()

print(f'Total tasks: {len(tasks)}')

statuses = {}
for t in tasks:
    s = t.status.value if hasattr(t.status, 'value') else str(t.status)
    statuses[s] = statuses.get(s, 0) + 1

print('\nTask statuses:')
for k, v in sorted(statuses.items()):
    print(f'  {k}: {v}')

ready = [t for t in tasks if t.status == TaskStatus.READY]
pending = [t for t in tasks if t.status == TaskStatus.PENDING]
completed = [t for t in tasks if t.status == TaskStatus.COMPLETED]
in_progress = [t for t in tasks if t.status == TaskStatus.IN_PROGRESS]

print(f'\nReady: {len(ready)}')
print(f'Pending: {len(pending)}')
print(f'Completed: {len(completed)}')
print(f'In Progress: {len(in_progress)}')

if ready:
    print(f'\nFirst 5 ready task IDs: {[t.id for t in ready[:5]]}')
elif pending:
    print(f'\nFirst 5 pending task IDs: {[t.id for t in pending[:5]]}')
    print('Tasks are in PENDING status - they need to be updated to READY')

if in_progress:
    print(f'\nIn Progress tasks:')
    for t in in_progress[:5]:
        print(f'  - {t.id}: {t.title} (Progress: {t.progress}%, Assigned: {t.assigned_agent})')
