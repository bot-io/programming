"""
Visualization utilities for the AI Agent Team Protocol.
Provides text-based visualizations of task status, dependencies, and progress.
"""

from ..agents.agent_coordinator import AgentCoordinator, TaskStatus
from parallel_execution import ParallelExecutionOptimizer
from typing import Dict, List


class ProtocolVisualizer:
    """Text-based visualizations for agent coordination"""

    @staticmethod
    def print_status_board(coordinator: AgentCoordinator):
        """Print a formatted status board"""
        status = coordinator.get_status_board()
        
        print("\n" + "=" * 80)
        print(f"PROJECT: {status['project']}")
        print("=" * 80)
        
        print(f"\nAgents: {len(status['agents'])}")
        for agent_id, workload in status['agent_workloads'].items():
            print(f"  • {agent_id}: {workload} active task(s)")
        
        print(f"\nTasks: {status['total_tasks']} total, {status['completed_tasks']} completed")
        print(f"  Ready: {len(status['ready_tasks'])}")
        
        # Tasks by status
        print("\nTasks by Status:")
        for status_name, tasks in status['tasks_by_status'].items():
            if tasks:
                print(f"  {status_name.upper()}: {len(tasks)}")
                for task in tasks[:5]:  # Show first 5
                    agent = task.get('assigned_agent', 'unassigned')
                    progress = task.get('progress', 0)
                    print(f"    - {task['id']}: {task['title'][:50]} [{agent}] ({progress}%)")
                if len(tasks) > 5:
                    print(f"    ... and {len(tasks) - 5} more")

    @staticmethod
    def print_dependency_graph(coordinator: AgentCoordinator):
        """Print dependency graph in text format"""
        graph = coordinator.get_dependency_graph()
        
        print("\n" + "=" * 80)
        print("DEPENDENCY GRAPH")
        print("=" * 80)
        
        for task_id, info in graph.items():
            status_icon = {
                'pending': '○',
                'ready': '◐',
                'assigned': '◑',
                'in_progress': '◒',
                'blocked': '⚠',
                'review': '◓',
                'completed': '✓',
                'failed': '✗'
            }.get(info['status'], '?')
            
            print(f"\n{status_icon} {task_id}: {info['title']}")
            print(f"   Status: {info['status']}")
            
            if info['dependencies']:
                print(f"   Depends on: {', '.join(info['dependencies'])}")
            else:
                print(f"   Depends on: (none)")
            
            if info['dependents']:
                print(f"   Blocks: {', '.join(info['dependents'])}")

    @staticmethod
    def print_progress_summary(coordinator: AgentCoordinator):
        """Print progress summary with percentages"""
        status = coordinator.get_status_board()
        total = status['total_tasks']
        completed = status['completed_tasks']
        
        if total == 0:
            print("\nNo tasks in project")
            return
        
        completion_pct = (completed / total) * 100
        
        print("\n" + "=" * 80)
        print("PROGRESS SUMMARY")
        print("=" * 80)
        print(f"\nOverall Progress: {completed}/{total} tasks ({completion_pct:.1f}%)")
        
        # Progress bar
        bar_length = 50
        filled = int(bar_length * completion_pct / 100)
        bar = '█' * filled + '░' * (bar_length - filled)
        print(f"[{bar}] {completion_pct:.1f}%")
        
        # Checkpoints
        print(f"\nCheckpoints: {len(coordinator.checkpoints)}")
        if coordinator.checkpoints:
            recent = coordinator.checkpoints[-5:]
            print("Recent checkpoints:")
            for cp in recent:
                print(f"  • [{cp.agent_id}] {cp.task_id}: {cp.progress}% - {cp.changes[:60]}")

    @staticmethod
    def print_task_timeline(coordinator: AgentCoordinator):
        """Print a simple timeline of task execution"""
        tasks = sorted(
            [t for t in coordinator.tasks.values() if t.started_at],
            key=lambda t: t.started_at or t.created_at
        )
        
        if not tasks:
            print("\nNo tasks have been started yet")
            return
        
        print("\n" + "=" * 80)
        print("TASK TIMELINE")
        print("=" * 80)
        
        for task in tasks:
            status_icon = {
                TaskStatus.IN_PROGRESS: '→',
                TaskStatus.COMPLETED: '✓',
                TaskStatus.BLOCKED: '⚠',
                TaskStatus.REVIEW: '◓'
            }.get(task.status, '○')
            
            agent = task.assigned_agent or 'unassigned'
            started = task.started_at.strftime("%H:%M:%S") if task.started_at else "N/A"
            
            print(f"\n{status_icon} {task.id}: {task.title}")
            print(f"   Agent: {agent} | Started: {started} | Progress: {task.progress}%")
            
            if task.completed_at:
                duration = task.completed_at - (task.started_at or task.created_at)
                print(f"   Completed: {task.completed_at.strftime('%H:%M:%S')} (Duration: {duration})")

    @staticmethod
    def print_parallel_execution(coordinator: AgentCoordinator):
        """Print parallel execution analysis"""
        optimizer = ParallelExecutionOptimizer(coordinator)
        analysis = optimizer.analyze_parallelism()
        stats = optimizer.get_parallel_execution_stats()
        
        print("\n" + "=" * 80)
        print("PARALLEL EXECUTION ANALYSIS")
        print("=" * 80)
        
        print(f"\nCurrent Parallelism: {stats['total_active']} tasks running")
        print(f"Maximum Possible: {analysis['max_possible_parallelism']} tasks")
        print(f"Efficiency: {analysis['parallelism_efficiency']:.1f}%")
        
        print("\nDependency Levels (tasks at each level can run in parallel):")
        for level, count in sorted(analysis['dependency_levels'].items()):
            active = stats['active_by_level'].get(level, 0)
            status = "⚡" if active > 0 else "○"
            print(f"  {status} Level {level}: {active}/{count} active")
        
        print("\nParallel Task Groups:")
        for i, group in enumerate(stats['parallel_groups'], 1):
            if group:
                print(f"  Group {i}: {len(group)} tasks - {', '.join(group)}")
    
    @staticmethod
    def visualize_all(coordinator: AgentCoordinator):
        """Print all visualizations"""
        ProtocolVisualizer.print_status_board(coordinator)
        ProtocolVisualizer.print_progress_summary(coordinator)
        ProtocolVisualizer.print_dependency_graph(coordinator)
        ProtocolVisualizer.print_task_timeline(coordinator)
        ProtocolVisualizer.print_parallel_execution(coordinator)

