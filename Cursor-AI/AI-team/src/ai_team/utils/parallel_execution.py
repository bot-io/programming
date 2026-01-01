"""
Parallel Execution Optimizer - Maximizes parallel task execution.
Ensures tasks run in parallel whenever possible.
"""

from typing import List, Dict, Set, Optional, Tuple
from ..agents.agent_coordinator import AgentCoordinator, Task, TaskStatus
from collections import defaultdict
import threading


class ParallelExecutionOptimizer:
    """
    Optimizes task assignment to maximize parallel execution.
    Ensures independent tasks are assigned to different agents simultaneously.
    """
    
    def __init__(self, coordinator: AgentCoordinator):
        self.coordinator = coordinator
        self.lock = threading.Lock()
        self.parallel_groups: Dict[int, List[str]] = defaultdict(list)  # level -> task_ids
        self.execution_graph: Dict[str, Set[str]] = {}  # task_id -> set of parallel tasks
    
    def analyze_parallelism(self) -> Dict:
        """
        Analyze which tasks can run in parallel.
        Returns information about parallel execution opportunities.
        """
        # Group tasks by dependency depth (level)
        levels = self._calculate_dependency_levels()
        
        # Find tasks that can run in parallel (same level, no dependencies between them)
        parallel_opportunities = {}
        for level, task_ids in levels.items():
            if len(task_ids) > 1:
                parallel_opportunities[level] = task_ids
        
        # Calculate current parallelism
        active_tasks = [
            t for t in self.coordinator.tasks.values()
            if t.status in [TaskStatus.ASSIGNED, TaskStatus.IN_PROGRESS]
        ]
        current_parallelism = len(active_tasks)
        
        # Calculate maximum possible parallelism
        max_parallelism = max(
            (len(tasks) for tasks in levels.values()),
            default=0
        )
        
        return {
            "dependency_levels": {k: len(v) for k, v in levels.items()},
            "parallel_opportunities": parallel_opportunities,
            "current_parallelism": current_parallelism,
            "max_possible_parallelism": max_parallelism,
            "parallelism_efficiency": (current_parallelism / max_parallelism * 100) if max_parallelism > 0 else 0
        }
    
    def _calculate_dependency_levels(self) -> Dict[int, List[str]]:
        """
        Calculate dependency levels for all tasks.
        Level 0 = no dependencies
        Level 1 = depends on level 0 tasks
        Level 2 = depends on level 1 tasks, etc.
        """
        levels: Dict[int, List[str]] = defaultdict(list)
        task_levels: Dict[str, int] = {}
        
        def get_level(task_id: str) -> int:
            if task_id in task_levels:
                return task_levels[task_id]
            
            task = self.coordinator.tasks.get(task_id)
            if not task:
                return 0
            
            if not task.dependencies:
                level = 0
            else:
                # Level is max of dependency levels + 1
                dep_levels = [get_level(dep_id) for dep_id in task.dependencies]
                level = max(dep_levels, default=-1) + 1
            
            task_levels[task_id] = level
            return level
        
        # Calculate levels for all tasks
        for task_id in self.coordinator.tasks:
            level = get_level(task_id)
            levels[level].append(task_id)
        
        return levels
    
    def get_parallel_task_groups(self) -> List[List[str]]:
        """
        Get groups of tasks that can run in parallel.
        Returns list of task groups, where tasks in each group can run simultaneously.
        """
        levels = self._calculate_dependency_levels()
        groups = []
        
        for level in sorted(levels.keys()):
            task_ids = levels[level]
            # Filter to only ready tasks
            ready_tasks = [
                tid for tid in task_ids
                if self.coordinator.tasks[tid].status == TaskStatus.READY
            ]
            if ready_tasks:
                groups.append(ready_tasks)
        
        return groups
    
    def optimize_assignment(self, available_agents: List[str]) -> List[tuple]:
        """
        Optimize task assignment to maximize parallelism.
        Returns list of (agent_id, task_id) assignments.
        """
        assignments = []
        
        # Get parallel task groups
        parallel_groups = self.get_parallel_task_groups()
        
        # Assign tasks from each group to different agents
        agent_index = 0
        for group in parallel_groups:
            for task_id in group:
                if agent_index < len(available_agents):
                    agent_id = available_agents[agent_index]
                    assignments.append((agent_id, task_id))
                    agent_index = (agent_index + 1) % len(available_agents)
                else:
                    # Not enough agents, but still record the task
                    assignments.append((None, task_id))
        
        return assignments
    
    def get_parallel_execution_stats(self) -> Dict:
        """Get statistics about parallel execution"""
        analysis = self.analyze_parallelism()
        
        # Count tasks running in parallel right now
        active_by_level = defaultdict(int)
        for task in self.coordinator.tasks.values():
            if task.status in [TaskStatus.ASSIGNED, TaskStatus.IN_PROGRESS]:
                # Find which level this task is at
                levels = self._calculate_dependency_levels()
                for level, task_ids in levels.items():
                    if task.id in task_ids:
                        active_by_level[level] += 1
                        break
        
        return {
            "analysis": analysis,
            "active_by_level": dict(active_by_level),
            "total_active": sum(active_by_level.values()),
            "parallel_groups": self.get_parallel_task_groups()
        }


class ParallelTaskAssigner:
    """
    Assigns tasks to maximize parallel execution.
    Works with AutonomousCoordinator to ensure maximum parallelism.
    """
    
    def __init__(self, coordinator: AgentCoordinator):
        self.coordinator = coordinator
        self.optimizer = ParallelExecutionOptimizer(coordinator)
    
    def assign_for_max_parallelism(self, idle_agents: List[str]) -> int:
        """
        Assign tasks to idle agents to maximize parallel execution.
        Returns number of tasks assigned.
        """
        if not idle_agents:
            return 0
        
        # Get parallel task groups
        parallel_groups = self.optimizer.get_parallel_task_groups()
        
        assigned_count = 0
        agent_index = 0
        
        # Assign tasks from parallel groups
        for group in parallel_groups:
            for task_id in group:
                if agent_index >= len(idle_agents):
                    break
                
                task = self.coordinator.tasks.get(task_id)
                if not task or task.status != TaskStatus.READY:
                    continue
                
                agent_id = idle_agents[agent_index]
                
                # Check for conflicts before assigning
                has_conflicts = self._check_task_file_conflicts(task, agent_id)
                if has_conflicts:
                    # Skip this task for now - conflicts with active work
                    continue
                
                # Assign and start task (with conflict checking enabled)
                if self.coordinator.assign_task(task_id, agent_id, check_conflicts=True):
                    if self.coordinator.start_task(task_id, agent_id):
                        # Get agent instance and set current task
                        agent = self.coordinator.agent_instances.get(agent_id)
                        if agent:
                            agent.current_task = task
                        
                        assigned_count += 1
                        agent_index += 1
                        print(f"  ↻ Parallel assignment: task '{task_id}' → agent '{agent_id}'")
        
        return assigned_count
    
    def _check_task_file_conflicts(self, task: Task, agent_id: str) -> bool:
        """Check if task would conflict with files being worked on by other agents"""
        # Get expected files for this task
        expected_files = self._get_expected_files_for_task(task)
        
        # Check against all active tasks
        for active_task in self.coordinator.tasks.values():
            if active_task.status in [TaskStatus.IN_PROGRESS, TaskStatus.ASSIGNED]:
                if active_task.id == task.id:
                    continue
                
                # Get expected files for active task
                active_files = self._get_expected_files_for_task(active_task)
                
                # Check for file overlap
                overlap = set(expected_files) & set(active_files)
                if overlap:
                    return True  # Conflict detected
        
        return False  # No conflicts
    
    def _get_expected_files_for_task(self, task: Task) -> List[str]:
        """
        Get expected files that this task will likely create/modify.
        
        Project-agnostic approach:
        - Prefer explicit `task.artifacts` (if present)
        - Otherwise, return an empty list (no assumptions about framework/layout)
        """
        expected: List[str] = []
        try:
            if getattr(task, "artifacts", None):
                expected.extend([a for a in task.artifacts if a])
        except Exception:
            pass
        return expected
    
    def get_parallelism_metrics(self) -> Dict:
        """Get current parallelism metrics"""
        return self.optimizer.get_parallel_execution_stats()

