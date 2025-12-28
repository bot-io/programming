"""
Enhanced Progress Tracker - Shows detailed real-time progress for each agent
"""

from ..agents.agent_coordinator import AgentCoordinator, TaskStatus, AgentState
from typing import Dict, List, Optional
from datetime import datetime, timedelta
import time


class DetailedProgressTracker:
    """Tracks and displays detailed progress for each agent and task"""
    
    def __init__(self, coordinator: AgentCoordinator):
        self.coordinator = coordinator
        self.last_update = {}
        self.activity_log = []  # Log of recent activities
    
    def get_agent_activity(self, agent_id: str) -> Dict:
        """Get current activity details for an agent"""
        # Try to get state from coordinator first
        agent_state = self.coordinator.agent_states.get(agent_id)
        
        # If not found in coordinator, try to get from agent instance
        if not agent_state and hasattr(self.coordinator, 'agent_instances'):
            agent_instance = self.coordinator.agent_instances.get(agent_id)
            if agent_instance and hasattr(agent_instance, 'state'):
                agent_state = agent_instance.state
        
        # Default to CREATED if still not found
        if not agent_state:
            agent_state = AgentState.CREATED
        
        # Find current task
        current_task = None
        for task in self.coordinator.tasks.values():
            if task.assigned_agent == agent_id and task.status == TaskStatus.IN_PROGRESS:
                current_task = task
                break
        
        # Get recent checkpoints for this agent
        recent_checkpoints = [
            cp for cp in self.coordinator.checkpoints[-10:]
            if cp.agent_id == agent_id
        ]
        
        # Get recent messages
        recent_messages = [
            msg for msg in self.coordinator.messages[-10:]
            if msg.agent_id == agent_id
        ]
        
        activity = {
            'agent_id': agent_id,
            'state': agent_state.value,
            'current_task': None,
            'current_activity': 'Idle',
            'progress': 0,
            'recent_activity': [],
            'time_in_current_task': None
        }
        
        if current_task:
            activity['current_task'] = {
                'id': current_task.id,
                'title': current_task.title,
                'progress': current_task.progress,
                'status': current_task.status.value
            }
            
            # Determine current activity from checkpoints
            if recent_checkpoints:
                latest = recent_checkpoints[-1]
                activity['current_activity'] = latest.changes or latest.next_steps or "Working on task"
                activity['progress'] = latest.progress
            else:
                activity['current_activity'] = f"Working on: {current_task.title}"
                activity['progress'] = current_task.progress
            
            # Calculate time in task
            if current_task.started_at:
                elapsed = datetime.now() - current_task.started_at
                activity['time_in_current_task'] = str(elapsed).split('.')[0]  # Remove microseconds
        
        # Add recent activity log
        if recent_checkpoints:
            activity['recent_activity'] = [
                {
                    'time': cp.timestamp.strftime("%H:%M:%S") if hasattr(cp, 'timestamp') else "N/A",
                    'action': cp.changes or "Checkpoint",
                    'progress': cp.progress
                }
                for cp in recent_checkpoints[-5:]
            ]
        
        return activity
    
    def get_all_agents_activity(self) -> List[Dict]:
        """Get activity for all agents"""
        activities = []
        for agent_id in self.coordinator.agents:
            activities.append(self.get_agent_activity(agent_id))
        return activities
    
    def get_task_details(self, task_id: str) -> Optional[Dict]:
        """Get detailed information about a task"""
        task = self.coordinator.tasks.get(task_id)
        if not task:
            return None
        
        # Get all checkpoints for this task
        task_checkpoints = [
            cp for cp in self.coordinator.checkpoints
            if cp.task_id == task_id
        ]
        
        # Get all messages for this task
        task_messages = [
            msg for msg in self.coordinator.messages
            if msg.task_id == task_id
        ]
        
        details = {
            'id': task.id,
            'title': task.title,
            'description': task.description[:200] + "..." if len(task.description) > 200 else task.description,
            'status': task.status.value,
            'progress': task.progress,
            'assigned_agent': task.assigned_agent,
            'dependencies': task.dependencies,
            'estimated_hours': task.estimated_hours,
            'created_at': task.created_at.strftime("%Y-%m-%d %H:%M:%S") if task.created_at else "N/A",
            'started_at': task.started_at.strftime("%Y-%m-%d %H:%M:%S") if task.started_at else None,
            'completed_at': task.completed_at.strftime("%Y-%m-%d %H:%M:%S") if task.completed_at else None,
            'artifacts': task.artifacts,
            'checkpoints': [
                {
                    'agent': cp.agent_id,
                    'progress': cp.progress,
                    'changes': cp.changes,
                    'next_steps': cp.next_steps,
                    'timestamp': cp.timestamp.strftime("%H:%M:%S") if hasattr(cp, 'timestamp') and cp.timestamp else datetime.now().strftime("%H:%M:%S")
                }
                for cp in task_checkpoints
            ],
            'recent_messages': [
                {
                    'agent': msg.agent_id,
                    'type': msg.message_type.value,
                    'message': msg.message,
                    'timestamp': "N/A"
                }
                for msg in task_messages[-5:]
            ]
        }
        
        # Calculate duration if completed
        if task.completed_at and task.started_at:
            duration = task.completed_at - task.started_at
            details['duration'] = str(duration).split('.')[0]
        elif task.started_at:
            duration = datetime.now() - task.started_at
            details['elapsed_time'] = str(duration).split('.')[0]
        
        return details
    
    def print_detailed_progress(self, refresh: bool = True, last_progress_time: Optional[datetime] = None, 
                                 last_overall_progress_time: Optional[datetime] = None):
        """Print detailed progress display"""
        if refresh:
            print("\033[2J\033[H", end="")  # Clear screen (works on most terminals)
        
        print("=" * 100)
        print("AI AGENT TEAM - DETAILED PROGRESS TRACKER")
        print("=" * 100)
        current_time = datetime.now()
        print(f"Last Updated: {current_time.strftime('%Y-%m-%d %H:%M:%S')}")
        
        if last_progress_time:
            time_since_progress = current_time - last_progress_time
            total_seconds = int(time_since_progress.total_seconds())
            if total_seconds < 60:
                elapsed_str = f"{total_seconds}s"
            elif total_seconds < 3600:
                elapsed_str = f"{total_seconds // 60}m {total_seconds % 60}s"
            else:
                hours = total_seconds // 3600
                minutes = (total_seconds % 3600) // 60
                elapsed_str = f"{hours}h {minutes}m"
            print(f"Time Since Last Progress: {elapsed_str}")
        
        if last_overall_progress_time:
            time_since_overall = current_time - last_overall_progress_time
            total_seconds = int(time_since_overall.total_seconds())
            if total_seconds < 60:
                elapsed_str = f"{total_seconds}s"
            elif total_seconds < 3600:
                elapsed_str = f"{total_seconds // 60}m {total_seconds % 60}s"
            else:
                hours = total_seconds // 3600
                minutes = (total_seconds % 3600) // 60
                elapsed_str = f"{hours}h {minutes}m"
            print(f"Time Since Last Overall Progress Change: {elapsed_str}")
        print()
        
        # Overall Statistics
        all_tasks = list(self.coordinator.tasks.values())
        total = len(all_tasks)
        completed = sum(1 for t in all_tasks if t.status == TaskStatus.COMPLETED)
        in_progress = sum(1 for t in all_tasks if t.status == TaskStatus.IN_PROGRESS)
        blocked = sum(1 for t in all_tasks if t.status == TaskStatus.BLOCKED)
        ready = sum(1 for t in all_tasks if t.status == TaskStatus.READY)
        pending = sum(1 for t in all_tasks if t.status == TaskStatus.PENDING)
        
        progress_pct = (completed / total * 100) if total > 0 else 0
        
        print("OVERALL PROGRESS")
        print("-" * 100)
        print(f"Total Tasks: {total} | Completed: {completed} | In Progress: {in_progress} | Blocked: {blocked} | Ready: {ready} | Pending: {pending}")
        # Use ASCII-safe progress bar
        bar_filled = int(progress_pct / 2)
        bar_empty = 50 - bar_filled
        progress_bar = '#' * bar_filled + '-' * bar_empty
        print(f"Progress: {progress_pct:.1f}% | [{progress_bar}]")
        print()
        
        # Agent Activities
        print("AGENT ACTIVITIES")
        print("-" * 100)
        activities = self.get_all_agents_activity()
        
        for activity in activities:
            state_icon = {
                'running': '[RUN]',
                'started': '[RUN]',
                'paused': '[PAUSE]',
                'stopped': '[STOP]',
                'error': '[ERROR]',
                'created': '[NEW]'
            }.get(activity['state'], '[?]')
            
            print(f"\n{state_icon} Agent: {activity['agent_id']} [{activity['state']}]")
            
            if activity['current_task']:
                task = activity['current_task']
                print(f"   Current Task: {task['id']} - {task['title']}")
                print(f"   Activity: {activity['current_activity']}")
                bar_filled = int(task['progress'] / 5)
                bar_empty = 20 - bar_filled
                progress_bar = '#' * bar_filled + '-' * bar_empty
                print(f"   Progress: {task['progress']}% | [{progress_bar}]")
                
                if activity['time_in_current_task']:
                    print(f"   Time in Task: {activity['time_in_current_task']}")
                
                if activity['recent_activity']:
                    print(f"   Recent Activity:")
                    for act in activity['recent_activity'][-3:]:
                        print(f"     • [{act['time']}] {act['action']} ({act['progress']}%)")
            else:
                print(f"   Status: {activity['current_activity']}")
        
        print()
        
        # Current Tasks Detail
        print("CURRENT TASKS IN PROGRESS")
        print("-" * 100)
        in_progress_tasks = [t for t in all_tasks if t.status == TaskStatus.IN_PROGRESS]
        
        if in_progress_tasks:
            for task in in_progress_tasks:
                print(f"\n[->] {task.id}: {task.title}")
                print(f"   Agent: {task.assigned_agent or 'Unassigned'}")
                bar_filled = int(task.progress / 5)
                bar_empty = 20 - bar_filled
                progress_bar = '#' * bar_filled + '-' * bar_empty
                print(f"   Progress: {task.progress}% | [{progress_bar}]")
                
                # Get latest checkpoint
                task_checkpoints = [
                    cp for cp in self.coordinator.checkpoints
                    if cp.task_id == task.id
                ]
                if task_checkpoints:
                    latest = task_checkpoints[-1]
                    print(f"   Latest: {latest.changes or 'Working...'}")
                    if latest.next_steps:
                        print(f"   Next: {latest.next_steps}")
        else:
            print("   No tasks currently in progress")
        
        print()
        
        # Blocked Tasks
        if blocked > 0:
            print("BLOCKED TASKS")
            print("-" * 100)
            blocked_tasks = [t for t in all_tasks if t.status == TaskStatus.BLOCKED]
            for task in blocked_tasks:
                print(f"   [BLOCKED] {task.id}: {task.title}")
                print(f"      Blocker: {task.blocker_message or 'Waiting on dependencies'}")
                print(f"      Dependencies: {', '.join(task.dependencies) if task.dependencies else 'None'}")
            print()
        
        # Ready Tasks
        if ready > 0:
            print("READY TASKS (Waiting for Agent)")
            print("-" * 100)
            ready_tasks = [t for t in all_tasks if t.status == TaskStatus.READY]
            for task in ready_tasks[:5]:  # Show first 5
                print(f"   [READY] {task.id}: {task.title}")
            if len(ready_tasks) > 5:
                print(f"   ... and {len(ready_tasks) - 5} more")
            print()
        
        # Recent Completions
        recent_completions = [
            t for t in all_tasks
            if t.status == TaskStatus.COMPLETED and t.completed_at
        ]
        recent_completions.sort(key=lambda t: t.completed_at or datetime.min, reverse=True)
        
        if recent_completions:
            print("RECENTLY COMPLETED")
            print("-" * 100)
            for task in recent_completions[:3]:
                duration = ""
                if task.completed_at and task.started_at:
                    dur = task.completed_at - task.started_at
                    duration = f" (Duration: {str(dur).split('.')[0]})"
                print(f"   [OK] {task.id}: {task.title}{duration}")
            print()
        
        print("=" * 100)
    
    def monitor_live(self, interval: float = 2.0):
        """Monitor and display progress in real-time"""
        try:
            while True:
                self.print_detailed_progress(refresh=True)
                time.sleep(interval)
        except KeyboardInterrupt:
            print("\n\nMonitoring stopped.")
    
    def get_progress_summary(self) -> Dict:
        """Get a summary of current progress"""
        all_tasks = list(self.coordinator.tasks.values())
        activities = self.get_all_agents_activity()
        
        return {
            'timestamp': datetime.now().isoformat(),
            'overall': {
                'total_tasks': len(all_tasks),
                'completed': sum(1 for t in all_tasks if t.status == TaskStatus.COMPLETED),
                'in_progress': sum(1 for t in all_tasks if t.status == TaskStatus.IN_PROGRESS),
                'blocked': sum(1 for t in all_tasks if t.status == TaskStatus.BLOCKED),
                'ready': sum(1 for t in all_tasks if t.status == TaskStatus.READY),
                'progress_percentage': (sum(1 for t in all_tasks if t.status == TaskStatus.COMPLETED) / len(all_tasks) * 100) if all_tasks else 0
            },
            'agents': activities,
            'active_tasks': [
                {
                    'id': t.id,
                    'title': t.title,
                    'agent': t.assigned_agent,
                    'progress': t.progress
                }
                for t in all_tasks if t.status == TaskStatus.IN_PROGRESS
            ]
        }

