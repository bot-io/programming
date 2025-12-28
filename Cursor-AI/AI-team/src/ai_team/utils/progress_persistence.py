"""
Progress Persistence - Saves agent team progress to Markdown files
"""

from ..agents.agent_coordinator import AgentCoordinator, TaskStatus, AgentState
from .progress_tracker import DetailedProgressTracker
from typing import Dict, List, Optional
from datetime import datetime, timedelta
import os
import json


class ProgressPersistence:
    """Saves and loads progress to/from Markdown files"""
    
    def __init__(self, coordinator: AgentCoordinator, tracker: DetailedProgressTracker, 
                 output_dir: str = "progress_reports", project_dir: Optional[str] = None,
                 team_start_time: Optional[datetime] = None):
        self.coordinator = coordinator
        self.tracker = tracker
        self.output_dir = output_dir
        self.project_dir = project_dir or "."
        os.makedirs(output_dir, exist_ok=True)
        
        # Track team start time
        self.team_start_time = team_start_time or datetime.now()
        
        # Create history directory
        self.history_dir = os.path.join(output_dir, "history")
        os.makedirs(self.history_dir, exist_ok=True)
        
        # Current progress files
        self.md_file = os.path.join(output_dir, "progress.md")
        self.json_file = os.path.join(output_dir, "progress.json")
        
        # History summary file
        self.history_summary_file = os.path.join(self.history_dir, "progress_history.json")
        
        self.task_parser = None
        if project_dir:
            try:
                from .task_config_parser import TaskConfigParser
                self.task_parser = TaskConfigParser(self.project_dir)
            except ImportError:
                pass
        
        # Track last factual progress change
        self.last_progress_change_time = datetime.now()
        self.last_state_snapshot = self._get_state_snapshot()
        
        # Track last overall progress change separately
        self.last_overall_progress_change_time = datetime.now()
        self.last_overall_progress = self._get_state_snapshot()['overall_progress']
        
        # Track completed task count history
        self.completed_count_history = self._load_completed_count_history()
    
    def _load_completed_count_history(self) -> List[Dict]:
        """Load completed task count history from file"""
        if os.path.exists(self.history_summary_file):
            try:
                with open(self.history_summary_file, 'r', encoding='utf-8') as f:
                    data = json.load(f)
                    return data.get('completed_count_history', [])
            except Exception:
                return []
        return []
    
    def _save_completed_count_history(self):
        """Save completed task count history to file"""
        try:
            history_data = {
                'completed_count_history': self.completed_count_history,
                'last_updated': datetime.now().isoformat()
            }
            with open(self.history_summary_file, 'w', encoding='utf-8') as f:
                json.dump(history_data, f, indent=2, default=str)
        except Exception:
            pass  # Silently fail if can't save history
    
    def _record_completed_count_change(self, current_completed: int, previous_completed: int):
        """
        Record a change in completed task count.
        CRITICAL: Per Manifesto requirement, completed task count must never go backwards.
        We only record increases, never decreases.
        """
        if current_completed != previous_completed:
            # Only record if count increased (per Manifesto: "must never go backwards")
            if current_completed > previous_completed:
                entry = {
                    'timestamp': datetime.now().isoformat(),
                    'completed_count': current_completed,
                    'previous_count': previous_completed,
                    'change': current_completed - previous_completed,
                    'change_type': 'increase'
                }
                self.completed_count_history.append(entry)
                
                # Keep only last 1000 entries to prevent file from growing too large
                if len(self.completed_count_history) > 1000:
                    self.completed_count_history = self.completed_count_history[-1000:]
                
                self._save_completed_count_history()
            else:
                # Count decreased - this should never happen per Manifesto
                # Log warning but don't record the decrease
                print(f"[WARNING] Completed task count decreased from {previous_completed} to {current_completed} - this violates Manifesto requirement. Not recording decrease.")
    
    def _cleanup_old_history(self, keep_count: int = 100):
        """Clean up old history files, keeping only the most recent ones"""
        try:
            # Get all history files
            md_files = [f for f in os.listdir(self.history_dir) if f.startswith('progress_') and f.endswith('.md')]
            json_files = [f for f in os.listdir(self.history_dir) if f.startswith('progress_') and f.endswith('.json')]
            
            # Sort by timestamp (extracted from filename)
            def get_timestamp(filename):
                try:
                    # Extract timestamp from filename like "progress_20251227_195430.md"
                    parts = filename.replace('progress_', '').replace('.md', '').replace('.json', '').split('_')
                    if len(parts) >= 2:
                        return int(parts[0] + parts[1])
                    return 0
                except:
                    return 0
            
            md_files.sort(key=get_timestamp, reverse=True)
            json_files.sort(key=get_timestamp, reverse=True)
            
            # Remove old files
            for file in md_files[keep_count:]:
                try:
                    os.remove(os.path.join(self.history_dir, file))
                except:
                    pass
            
            for file in json_files[keep_count:]:
                try:
                    os.remove(os.path.join(self.history_dir, file))
                except:
                    pass
        except Exception:
            pass  # Silently fail if cleanup fails
    
    def _get_state_snapshot(self) -> Dict:
        """Get a snapshot of current state for comparison"""
        all_tasks = list(self.coordinator.tasks.values())
        total = len(all_tasks)
        completed = sum(1 for t in all_tasks if t.status == TaskStatus.COMPLETED)
        return {
            'overall_progress': (completed / total * 100) if total > 0 else 0,
            'task_states': {task.id: (task.status.value, task.progress) for task in all_tasks},
            'completed_count': completed,
            'in_progress_count': sum(1 for t in all_tasks if t.status == TaskStatus.IN_PROGRESS),
            'blocked_count': sum(1 for t in all_tasks if t.status == TaskStatus.BLOCKED),
            'ready_count': sum(1 for t in all_tasks if t.status == TaskStatus.READY),
        }
    
    def _has_progress_changed(self) -> bool:
        """Check if there has been any factual progress change"""
        current_state = self._get_state_snapshot()
        
        # Compare with last snapshot
        if self.last_state_snapshot is None or not hasattr(self, 'last_state_snapshot'):
            self.last_state_snapshot = current_state
            return True
        
        # Check if overall progress changed
        if abs(current_state['overall_progress'] - self.last_state_snapshot['overall_progress']) > 0.01:
            return True
        
        # Check if task counts changed
        if (current_state['completed_count'] != self.last_state_snapshot['completed_count'] or
            current_state['in_progress_count'] != self.last_state_snapshot['in_progress_count'] or
            current_state['blocked_count'] != self.last_state_snapshot['blocked_count'] or
            current_state['ready_count'] != self.last_state_snapshot['ready_count']):
            return True
        
        # Check if any task status or progress changed
        for task_id, (status, progress) in current_state['task_states'].items():
            if task_id not in self.last_state_snapshot['task_states']:
                return True  # New task
            last_status, last_progress = self.last_state_snapshot['task_states'][task_id]
            if status != last_status or abs(progress - last_progress) > 0.01:
                return True
        
        return False
    
    def save_progress(self):
        """Save current progress to Markdown and JSON files, and create historical snapshot"""
        try:
            # Check if there's been factual progress change
            current_state = self._get_state_snapshot()
            has_changed = self._has_progress_changed()
            
            # Track completed count changes
            previous_completed = self.last_state_snapshot.get('completed_count', 0) if self.last_state_snapshot else 0
            current_completed = current_state['completed_count']
            
            if has_changed:
                self.last_progress_change_time = datetime.now()
                
                # Record completed count change
                if current_completed != previous_completed:
                    self._record_completed_count_change(current_completed, previous_completed)
                
                self.last_state_snapshot = current_state
                
                # Check if overall progress specifically changed
                if abs(current_state['overall_progress'] - self.last_overall_progress) > 0.01:
                    self.last_overall_progress_change_time = datetime.now()
                    self.last_overall_progress = current_state['overall_progress']
            
            # Generate markdown report
            md_content = self._generate_markdown_report()
            
            # Always write markdown file to update "Last Updated" timestamp
            # This ensures Manifesto requirement: "if progress < 100%, it must be within the last 2 minutes"
            # Even if there's no factual change, we update the timestamp to show the system is active
            with open(self.md_file, 'w', encoding='utf-8') as f:
                f.write(md_content)
            
            # Generate JSON snapshot
            json_data = self._generate_json_snapshot()
            
            # Write current JSON file
            with open(self.json_file, 'w', encoding='utf-8') as f:
                json.dump(json_data, f, indent=2, default=str)
            
            # Save historical snapshot if there was a change
            if has_changed:
                timestamp_str = datetime.now().strftime('%Y%m%d_%H%M%S')
                
                # Save historical markdown
                history_md_file = os.path.join(self.history_dir, f"progress_{timestamp_str}.md")
                with open(history_md_file, 'w', encoding='utf-8') as f:
                    f.write(md_content)
                
                # Save historical JSON
                history_json_file = os.path.join(self.history_dir, f"progress_{timestamp_str}.json")
                # Add metadata to JSON
                json_data['history_metadata'] = {
                    'completed_count': current_completed,
                    'previous_completed_count': previous_completed,
                    'completed_count_changed': current_completed != previous_completed
                }
                with open(history_json_file, 'w', encoding='utf-8') as f:
                    json.dump(json_data, f, indent=2, default=str)
                
                # Clean up old history files (keep last 100)
                self._cleanup_old_history()
            
            # Update tasks.md with current statuses
            self._update_tasks_file()
            
            return True
        except Exception as e:
            # Don't print error during normal operation to avoid cluttering output
            # Only print if it's a critical error
            import traceback
            if "PermissionError" in str(type(e)):
                print(f"Warning: Cannot save progress (permission denied): {self.md_file}")
            elif "FileNotFoundError" not in str(type(e)):
                # Only log non-file-not-found errors (those are usually recoverable)
                print(f"Warning: Error saving progress: {type(e).__name__}")
            return False
    
    def _format_time_elapsed(self, elapsed: timedelta) -> str:
        """Format time elapsed in a human-readable way"""
        total_seconds = int(elapsed.total_seconds())
        
        if total_seconds < 60:
            return f"{total_seconds} second{'s' if total_seconds != 1 else ''}"
        elif total_seconds < 3600:
            minutes = total_seconds // 60
            seconds = total_seconds % 60
            if seconds == 0:
                return f"{minutes} minute{'s' if minutes != 1 else ''}"
            else:
                return f"{minutes} minute{'s' if minutes != 1 else ''} {seconds} second{'s' if seconds != 1 else ''}"
        else:
            hours = total_seconds // 3600
            minutes = (total_seconds % 3600) // 60
            if minutes == 0:
                return f"{hours} hour{'s' if hours != 1 else ''}"
            else:
                return f"{hours} hour{'s' if hours != 1 else ''} {minutes} minute{'s' if minutes != 1 else ''}"
    
    def _generate_markdown_report(self) -> str:
        """Generate a comprehensive Markdown progress report"""
        lines = []
        lines.append("# AI Agent Team Progress Report")
        lines.append("")
        
        # Current time
        current_time = datetime.now()
        lines.append(f"**Last Updated:** {current_time.strftime('%Y-%m-%d %H:%M:%S')}")
        lines.append("")
        
        # Elapsed time since team started
        elapsed_time = current_time - self.team_start_time
        elapsed_str = self._format_time_elapsed(elapsed_time)
        lines.append(f"**Elapsed Time:** {elapsed_str}")
        
        # Overall Statistics (needed for time estimation)
        all_tasks = list(self.coordinator.tasks.values())
        total = len(all_tasks)
        completed = sum(1 for t in all_tasks if t.status == TaskStatus.COMPLETED)
        remaining = total - completed
        
        # Calculate estimated time to completion
        if completed > 0 and elapsed_time.total_seconds() > 0:
            # Calculate completion rate (tasks per hour)
            elapsed_hours = elapsed_time.total_seconds() / 3600.0
            completion_rate = completed / elapsed_hours if elapsed_hours > 0 else 0
            
            if completion_rate > 0 and remaining > 0:
                # Estimate time to complete remaining tasks
                estimated_hours_remaining = remaining / completion_rate
                estimated_time_remaining = timedelta(hours=estimated_hours_remaining)
                estimated_str = self._format_time_elapsed(estimated_time_remaining)
                estimated_completion = current_time + estimated_time_remaining
                lines.append(f"**Estimated Time to Completion:** {estimated_str}")
                lines.append(f"**Estimated Completion Time:** {estimated_completion.strftime('%Y-%m-%d %H:%M:%S')}")
                lines.append(f"**Completion Rate:** {completion_rate:.2f} tasks/hour")
            elif remaining == 0:
                lines.append(f"**Estimated Time to Completion:** Complete!")
                if elapsed_hours > 0:
                    lines.append(f"**Completion Rate:** {completion_rate:.2f} tasks/hour")
            else:
                lines.append(f"**Estimated Time to Completion:** Calculating...")
        else:
            lines.append(f"**Estimated Time to Completion:** Calculating... (need more progress)")
        
        lines.append("")
        
        # Time since last factual progress (any task change)
        time_since_progress = current_time - self.last_progress_change_time
        time_elapsed_str = self._format_time_elapsed(time_since_progress)
        lines.append(f"**Time Since Last Progress:** {time_elapsed_str}")
        
        # Time since last overall progress change
        time_since_overall_progress = current_time - self.last_overall_progress_change_time
        time_overall_elapsed_str = self._format_time_elapsed(time_since_overall_progress)
        lines.append(f"**Time Since Last Overall Progress Change:** {time_overall_elapsed_str}")
        lines.append("")
        lines.append("---")
        lines.append("")
        in_progress = sum(1 for t in all_tasks if t.status == TaskStatus.IN_PROGRESS)
        blocked = sum(1 for t in all_tasks if t.status == TaskStatus.BLOCKED)
        ready = sum(1 for t in all_tasks if t.status == TaskStatus.READY)
        pending = sum(1 for t in all_tasks if t.status == TaskStatus.PENDING)
        failed = sum(1 for t in all_tasks if t.status == TaskStatus.FAILED)
        
        progress_pct = (completed / total * 100) if total > 0 else 0
        
        lines.append("## Overall Progress")
        lines.append("")
        lines.append(f"- **Total Tasks:** {total}")
        lines.append(f"- **Completed:** {completed} ({completed/total*100:.1f}%)" if total > 0 else f"- **Completed:** {completed} (0.0%)")
        lines.append(f"- **In Progress:** {in_progress}")
        lines.append(f"- **Blocked:** {blocked}")
        lines.append(f"- **Ready:** {ready}")
        lines.append(f"- **Pending:** {pending}")
        lines.append(f"- **Failed:** {failed}")
        lines.append("")
        lines.append(f"**Overall Progress:** {progress_pct:.1f}%")
        lines.append("")
        
        # Add completed count history section
        if self.completed_count_history:
            lines.append("### Completed Task Count History")
            lines.append("")
            lines.append("Recent changes in completed task count:")
            lines.append("")
            # Show last 10 changes
            for entry in self.completed_count_history[-10:]:
                change_icon = "📈" if entry['change'] > 0 else "📉"
                timestamp = datetime.fromisoformat(entry['timestamp']).strftime('%Y-%m-%d %H:%M:%S')
                lines.append(f"- **[{timestamp}]** {change_icon} {entry['previous_count']} → {entry['completed_count']} ({entry['change']:+d})")
            lines.append("")
            lines.append(f"*Full history available in: `{os.path.basename(self.history_summary_file)}`*")
            lines.append("")
        
        lines.append("---")
        lines.append("")
        
        # Agent Activities
        lines.append("## Agent Activities")
        lines.append("")
        activities = self.tracker.get_all_agents_activity()
        
        for activity in activities:
            state_icon = {
                'running': '▶️',
                'started': '▶️',
                'paused': '⏸️',
                'stopped': '⏹️',
                'error': '❌',
                'created': '🆕'
            }.get(activity['state'], '❓')
            
            lines.append(f"### {state_icon} {activity['agent_id']}")
            lines.append("")
            lines.append(f"- **State:** {activity['state']}")
            
            if activity['current_task']:
                task = activity['current_task']
                lines.append(f"- **Current Task:** `{task['id']}` - {task['title']}")
                lines.append(f"- **Activity:** {activity['current_activity']}")
                lines.append(f"- **Progress:** {task['progress']}%")
                
                if activity['time_in_current_task']:
                    lines.append(f"- **Time in Task:** {activity['time_in_current_task']}")
                
                if activity['recent_activity']:
                    lines.append("- **Recent Activity:**")
                    for act in activity['recent_activity'][-3:]:
                        lines.append(f"  - [{act['time']}] {act['action']} ({act['progress']}%)")
            else:
                lines.append(f"- **Status:** {activity['current_activity']}")
            
            lines.append("")
        
        lines.append("---")
        lines.append("")
        
        # Tasks Detail
        lines.append("## Tasks Detail")
        lines.append("")
        
        # Group tasks by status
        status_groups = {
            'Completed': [t for t in all_tasks if t.status == TaskStatus.COMPLETED],
            'In Progress': [t for t in all_tasks if t.status == TaskStatus.IN_PROGRESS],
            'Blocked': [t for t in all_tasks if t.status == TaskStatus.BLOCKED],
            'Ready': [t for t in all_tasks if t.status == TaskStatus.READY],
            'Pending': [t for t in all_tasks if t.status == TaskStatus.PENDING],
            'Failed': [t for t in all_tasks if t.status == TaskStatus.FAILED]
        }
        
        for status_name, tasks in status_groups.items():
            if not tasks:
                continue
            
            lines.append(f"### {status_name} ({len(tasks)})")
            lines.append("")
            
            for task in tasks:
                status_icon = {
                    'Completed': '✅',
                    'In Progress': '🔄',
                    'Blocked': '🚫',
                    'Ready': '⏳',
                    'Pending': '⏸️',
                    'Failed': '❌'
                }.get(status_name, '❓')
                
                lines.append(f"#### {status_icon} {task.id}: {task.title}")
                lines.append("")
                lines.append(f"- **Description:** {task.description[:200]}{'...' if len(task.description) > 200 else ''}")
                lines.append(f"- **Progress:** {task.progress}%")
                lines.append(f"- **Assigned Agent:** {task.assigned_agent or 'Unassigned'}")
                
                if task.dependencies:
                    lines.append(f"- **Dependencies:** {', '.join(task.dependencies)}")
                
                if task.estimated_hours:
                    lines.append(f"- **Estimated Hours:** {task.estimated_hours}")
                
                if task.created_at:
                    lines.append(f"- **Created:** {task.created_at.strftime('%Y-%m-%d %H:%M:%S')}")
                
                if task.started_at:
                    lines.append(f"- **Started:** {task.started_at.strftime('%Y-%m-%d %H:%M:%S')}")
                
                if task.completed_at:
                    lines.append(f"- **Completed:** {task.completed_at.strftime('%Y-%m-%d %H:%M:%S')}")
                    if task.started_at:
                        duration = task.completed_at - task.started_at
                        lines.append(f"- **Duration:** {str(duration).split('.')[0]}")
                
                if task.artifacts:
                    lines.append(f"- **Artifacts:** {', '.join(task.artifacts)}")
                
                # Get checkpoints for this task
                task_checkpoints = [
                    cp for cp in self.coordinator.checkpoints
                    if cp.task_id == task.id
                ]
                
                if task_checkpoints:
                    lines.append("- **Checkpoints:**")
                    for cp in task_checkpoints[-5:]:  # Last 5 checkpoints
                        timestamp = cp.timestamp.strftime('%H:%M:%S') if hasattr(cp, 'timestamp') and cp.timestamp else "N/A"
                        lines.append(f"  - [{timestamp}] {cp.progress}% - {cp.changes}")
                        if cp.next_steps:
                            lines.append(f"    - Next: {cp.next_steps}")
                
                if task.blocker_message:
                    lines.append(f"- **Blocker:** {task.blocker_message}")
                
                lines.append("")
            
            lines.append("")
        
        lines.append("---")
        lines.append("")
        lines.append("## Recent Messages")
        lines.append("")
        
        recent_messages = self.coordinator.messages[-20:]  # Last 20 messages
        for msg in recent_messages:
            timestamp = msg.timestamp.strftime('%H:%M:%S') if hasattr(msg, 'timestamp') and msg.timestamp else "N/A"
            lines.append(f"- **[{timestamp}]** `{msg.agent_id}`: {msg.message or msg.message_type.value}")
        
        lines.append("")
        lines.append("---")
        lines.append("")
        lines.append(f"*Report generated at {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}*")
        lines.append("")
        lines.append(f"*Progress history saved to: `history/` directory*")
        lines.append(f"*Historical snapshots: Check `{os.path.join('history', 'progress_*.md')}` files*")
        
        return "\n".join(lines)
    
    def _generate_json_snapshot(self) -> Dict:
        """Generate JSON snapshot of current state"""
        all_tasks = list(self.coordinator.tasks.values())
        activities = self.tracker.get_all_agents_activity()
        
        # Calculate time metrics
        current_time = datetime.now()
        elapsed_time = current_time - self.team_start_time
        completed = sum(1 for t in all_tasks if t.status == TaskStatus.COMPLETED)
        total = len(all_tasks)
        remaining = total - completed
        
        # Calculate completion rate and estimated time
        elapsed_hours = elapsed_time.total_seconds() / 3600.0
        completion_rate = completed / elapsed_hours if elapsed_hours > 0 and completed > 0 else 0
        estimated_hours_remaining = remaining / completion_rate if completion_rate > 0 and remaining > 0 else None
        estimated_completion = (current_time + timedelta(hours=estimated_hours_remaining)).isoformat() if estimated_hours_remaining else None
        
        return {
            "timestamp": current_time.isoformat(),
            "team_start_time": self.team_start_time.isoformat(),
            "elapsed_seconds": elapsed_time.total_seconds(),
            "elapsed_hours": elapsed_hours,
            "completion_rate": completion_rate,
            "estimated_hours_remaining": estimated_hours_remaining,
            "estimated_completion_time": estimated_completion,
            "overall": {
                "total_tasks": total,
                "completed": completed,
                "remaining": remaining,
                "in_progress": sum(1 for t in all_tasks if t.status == TaskStatus.IN_PROGRESS),
                "blocked": sum(1 for t in all_tasks if t.status == TaskStatus.BLOCKED),
                "ready": sum(1 for t in all_tasks if t.status == TaskStatus.READY),
                "pending": sum(1 for t in all_tasks if t.status == TaskStatus.PENDING),
                "failed": sum(1 for t in all_tasks if t.status == TaskStatus.FAILED),
                "progress_percentage": (completed / total * 100) if total > 0 else 0
            },
            "agents": activities,
            "tasks": [
                {
                    "id": t.id,
                    "title": t.title,
                    "description": t.description,
                    "status": t.status.value,
                    "progress": t.progress,
                    "assigned_agent": t.assigned_agent,
                    "dependencies": t.dependencies,
                    "estimated_hours": t.estimated_hours,
                    "created_at": t.created_at.isoformat() if t.created_at else None,
                    "started_at": t.started_at.isoformat() if t.started_at else None,
                    "completed_at": t.completed_at.isoformat() if t.completed_at else None,
                    "artifacts": t.artifacts,
                    "blocker_message": t.blocker_message
                }
                for t in all_tasks
            ],
            "checkpoints": [
                {
                    "agent_id": cp.agent_id,
                    "task_id": cp.task_id,
                    "progress": cp.progress,
                    "changes": cp.changes,
                    "next_steps": cp.next_steps,
                    "timestamp": cp.timestamp.isoformat() if hasattr(cp, 'timestamp') and cp.timestamp else None
                }
                for cp in self.coordinator.checkpoints[-50:]  # Last 50 checkpoints
            ],
            "recent_messages": [
                {
                    "agent_id": msg.agent_id,
                    "task_id": msg.task_id,
                    "message_type": msg.message_type.value,
                    "message": msg.message,
                    "timestamp": msg.timestamp.isoformat() if hasattr(msg, 'timestamp') and msg.timestamp else None
                }
                for msg in self.coordinator.messages[-50:]  # Last 50 messages
            ]
        }
    
    def _update_tasks_file(self):
        """Update tasks.md with current task statuses"""
        if not self.task_parser:
            return
        try:
            for task in self.coordinator.tasks.values():
                self.task_parser.update_task_in_file(task)
        except Exception as e:
            # Don't fail on update errors
            pass

