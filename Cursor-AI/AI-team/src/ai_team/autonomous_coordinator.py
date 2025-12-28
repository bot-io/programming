"""
Autonomous Coordinator - Runs the team independently until all tasks are completed.
Manages agents, distributes tasks, and handles completion automatically.
"""

from typing import List, Dict, Optional, Type, Callable
from .agents.agent_coordinator import AgentCoordinator, Task, TaskStatus
from .agents.agent import Agent
from .agent_manager import AgentManager, CoordinatorAgent
from ..utils.parallel_execution import ParallelTaskAssigner
from datetime import datetime, timedelta
import time
import threading


class AutonomousCoordinator:
    """
    Autonomous coordinator that runs the team without human intervention.
    Automatically:
    - Spawns agents as needed
    - Distributes tasks to agents
    - Monitors progress
    - Detects completion
    - Shuts down when done
    """
    
    def __init__(
        self,
        coordinator: AgentCoordinator,
        agent_manager: AgentManager,
        min_agents: int = 1,
        max_agents: int = 10,
        check_interval: float = 2.0,
        idle_timeout: float = 60.0,
        maximize_parallelism: bool = True
    ):
        self.coordinator = coordinator
        self.agent_manager = agent_manager
        self.min_agents = min_agents
        self.max_agents = max_agents
        self.check_interval = check_interval
        self.idle_timeout = idle_timeout
        self.maximize_parallelism = maximize_parallelism
        
        self.running = False
        self.completed = False
        self.last_activity = datetime.now()
        self.monitor_thread: Optional[threading.Thread] = None
        
        # Parallel execution optimizer
        if maximize_parallelism:
            self.parallel_assigner = ParallelTaskAssigner(coordinator)
        else:
            self.parallel_assigner = None
        
    def is_all_tasks_completed(self) -> bool:
        """Check if all tasks are completed"""
        if not self.coordinator.tasks:
            return False
        
        all_completed = all(
            task.status == TaskStatus.COMPLETED
            for task in self.coordinator.tasks.values()
        )
        return all_completed
    
    def get_idle_agents(self) -> List[str]:
        """Get list of agents that are running but not working on tasks"""
        idle = []
        for agent_id in self.coordinator.agents:
            state = self.coordinator.get_agent_state(agent_id)
            if state and state.value in ["running", "started"]:
                # Check if agent has active tasks
                agent_tasks = self.coordinator.get_agent_tasks(agent_id)
                active_tasks = [
                    t for t in agent_tasks
                    if t.status in [TaskStatus.ASSIGNED, TaskStatus.IN_PROGRESS]
                ]
                if not active_tasks:
                    idle.append(agent_id)
        return idle
    
    def get_ready_tasks_count(self) -> int:
        """Get number of tasks ready to be assigned"""
        return len(self.coordinator.get_ready_tasks())
    
    def assign_tasks_to_idle_agents(self):
        """Automatically assign ready tasks to idle agents, maximizing parallelism"""
        idle_agents = self.get_idle_agents()
        ready_tasks = self.coordinator.get_ready_tasks()
        
        if not ready_tasks or not idle_agents:
            return
        
        # Use parallel optimizer if enabled
        if self.maximize_parallelism and self.parallel_assigner:
            assigned = self.parallel_assigner.assign_for_max_parallelism(idle_agents)
            if assigned > 0:
                self.last_activity = datetime.now()
                # Show parallelism metrics
                metrics = self.parallel_assigner.get_parallelism_metrics()
                if metrics['total_active'] > 1:
                    print(f"  ⚡ {metrics['total_active']} tasks running in parallel")
        else:
            # Simple round-robin assignment
            for agent_id in idle_agents:
                if not ready_tasks:
                    break
                
                task = ready_tasks.pop(0)
                
                # Assign task
                if self.coordinator.assign_task(task.id, agent_id):
                    # Start the task
                    self.coordinator.start_task(task.id, agent_id)
                    
                    # Get agent instance and trigger work
                    agent = self.agent_manager.get_agent(agent_id)
                    if agent and hasattr(agent, 'current_task'):
                        agent.current_task = task
                    
                    print(f"  Auto-assigned task '{task.id}' to agent '{agent_id}'")
                    self.last_activity = datetime.now()
    
    def spawn_agents_if_needed(self):
        """Spawn additional agents if there are tasks but not enough agents"""
        ready_tasks_count = self.get_ready_tasks_count()
        running_agents = [
            agent_id for agent_id, state in self.coordinator.get_all_agent_states().items()
            if state in ["running", "started"]
        ]
        idle_agents = self.get_idle_agents()
        
        # If maximizing parallelism, consider parallel task groups
        if self.maximize_parallelism and self.parallel_assigner:
            parallel_groups = self.parallel_assigner.optimizer.get_parallel_task_groups()
            # Count tasks that can run in parallel
            parallel_tasks = sum(len(group) for group in parallel_groups)
            # Need at least as many agents as parallel tasks (up to max)
            agents_needed = min(
                parallel_tasks - len(idle_agents),
                self.max_agents - len(running_agents)
            )
        else:
            # Simple calculation
            agents_needed = min(
                ready_tasks_count - len(idle_agents),
                self.max_agents - len(running_agents)
            )
        
        if agents_needed > 0 and len(running_agents) < self.max_agents:
            # Try to spawn agents (need at least one registered type)
            if self.agent_manager.agent_factories:
                agent_type = list(self.agent_manager.agent_factories.keys())[0]
                
                for i in range(agents_needed):
                    agent_id = f"auto-agent-{len(running_agents) + i + 1}"
                    agent = self.agent_manager.create_agent(
                        agent_id,
                        agent_type,
                        auto_start=True
                    )
                    if agent:
                        print(f"  Auto-spawned agent '{agent_id}' for parallel execution")
                        self.last_activity = datetime.now()
    
    def ensure_min_agents(self):
        """Ensure minimum number of agents are running"""
        running_agents = [
            agent_id for agent_id, state in self.coordinator.get_all_agent_states().items()
            if state in ["running", "started"]
        ]
        
        if len(running_agents) < self.min_agents:
            needed = self.min_agents - len(running_agents)
            
            if self.agent_manager.agent_factories:
                agent_type = list(self.agent_manager.agent_factories.keys())[0]
                
                for i in range(needed):
                    agent_id = f"auto-agent-{len(running_agents) + i + 1}"
                    agent = self.agent_manager.create_agent(
                        agent_id,
                        agent_type,
                        auto_start=True
                    )
                    if agent:
                        print(f"  Spawned minimum agent '{agent_id}'")
    
    def monitor_loop(self):
        """Main monitoring loop that runs autonomously"""
        print("\n" + "=" * 80)
        print("Autonomous Coordinator - Monitoring Loop Started")
        print("=" * 80)
        
        while self.running:
            try:
                # Check if all tasks completed
                if self.is_all_tasks_completed():
                    print("\n" + "=" * 80)
                    print("ALL TASKS COMPLETED!")
                    print("=" * 80)
                    self.completed = True
                    break
                
                # Ensure minimum agents
                self.ensure_min_agents()
                
                # Assign tasks to idle agents
                self.assign_tasks_to_idle_agents()
                
                # Spawn more agents if needed
                self.spawn_agents_if_needed()
                
                # Check for activity
                status = self.coordinator.get_status_board()
                if status['completed_tasks'] < status['total_tasks']:
                    self.last_activity = datetime.now()
                
                # Check for idle timeout (no progress for too long)
                if (datetime.now() - self.last_activity).total_seconds() > self.idle_timeout:
                    ready_tasks = self.get_ready_tasks_count()
                    if ready_tasks == 0:
                        # No ready tasks, might be blocked
                        blocked_tasks = [
                            t for t in self.coordinator.tasks.values()
                            if t.status == TaskStatus.BLOCKED
                        ]
                        if blocked_tasks:
                            print(f"\n⚠ WARNING: {len(blocked_tasks)} tasks are blocked")
                            print("  This may indicate a dependency issue or deadlock")
                    
                    # Reset activity timer if there's work to do
                    if ready_tasks > 0:
                        self.last_activity = datetime.now()
                
                # Sleep before next check
                time.sleep(self.check_interval)
                
            except Exception as e:
                print(f"\n⚠ Error in monitor loop: {e}")
                time.sleep(self.check_interval)
    
    def start(self):
        """Start the autonomous coordinator"""
        if self.running:
            return
        
        self.running = True
        self.completed = False
        self.last_activity = datetime.now()
        
        # Ensure minimum agents are running
        self.ensure_min_agents()
        
        # Start monitoring in background thread
        self.monitor_thread = threading.Thread(target=self.monitor_loop, daemon=False)
        self.monitor_thread.start()
        
        print("Autonomous coordinator started")
    
    def stop(self):
        """Stop the autonomous coordinator"""
        self.running = False
        
        if self.monitor_thread and self.monitor_thread.is_alive():
            self.monitor_thread.join(timeout=5.0)
        
        # Stop all agents
        self.coordinator.stop_all_agents()
        
        print("Autonomous coordinator stopped")
    
    def wait_for_completion(self, timeout: Optional[float] = None):
        """Wait until all tasks are completed or timeout"""
        start_time = datetime.now()
        
        while self.running and not self.completed:
            if timeout and (datetime.now() - start_time).total_seconds() > timeout:
                print(f"\n⚠ Timeout reached ({timeout}s)")
                break
            
            time.sleep(self.check_interval)
        
        return self.completed
    
    def get_progress(self) -> Dict:
        """Get current progress information"""
        status = self.coordinator.get_status_board()
        
        total = status['total_tasks']
        completed = status['completed_tasks']
        progress_pct = (completed / total * 100) if total > 0 else 0
        
        progress = {
            "total_tasks": total,
            "completed_tasks": completed,
            "progress_percentage": progress_pct,
            "ready_tasks": len(self.coordinator.get_ready_tasks()),
            "running_agents": len([
                a for a, s in self.coordinator.get_all_agent_states().items()
                if s in ["running", "started"]
            ]),
            "idle_agents": len(self.get_idle_agents()),
            "all_completed": self.is_all_tasks_completed(),
            "running": self.running
        }
        
        # Add parallelism metrics if enabled
        if self.maximize_parallelism and self.parallel_assigner:
            parallelism = self.parallel_assigner.get_parallelism_metrics()
            progress["parallelism"] = {
                "current_parallel_tasks": parallelism["total_active"],
                "max_possible_parallelism": parallelism["analysis"]["max_possible_parallelism"],
                "parallelism_efficiency": parallelism["analysis"]["parallelism_efficiency"]
            }
        
        return progress


def run_autonomous_team(
    coordinator: AgentCoordinator,
    tasks: List[Task],
    agent_class: Type[Agent],
    agent_type_name: str = "worker",
    min_agents: int = 2,
    max_agents: int = 5,
    check_interval: float = 2.0,
    idle_timeout: float = 300.0,  # 5 minutes
    progress_callback: Optional[Callable[[Dict], None]] = None,
    maximize_parallelism: bool = True,
    agent_factory: Optional[Callable[[str, AgentCoordinator], Agent]] = None
) -> bool:
    """
    Run an autonomous team until all tasks are completed.
    
    Args:
        coordinator: The coordinator instance
        tasks: List of tasks to complete
        agent_class: Agent class to use
        agent_type_name: Name for the agent type
        min_agents: Minimum number of agents
        max_agents: Maximum number of agents
        check_interval: How often to check status (seconds)
        idle_timeout: Timeout for idle detection (seconds)
        progress_callback: Optional callback for progress updates
    
    Returns:
        True if all tasks completed, False otherwise
    """
    # Add tasks
    coordinator.add_tasks(tasks)
    
    # Create agent manager
    agent_manager = AgentManager(coordinator)
    
    # Register agent type - support both class and factory function
    if agent_factory:
        def factory_wrapper(agent_id: str, coord: AgentCoordinator):
            return agent_factory(agent_id, coord)
        agent_manager.register_agent_type(agent_type_name, factory_wrapper)
    else:
        agent_manager.register_agent_type(agent_type_name, agent_class)
    
    # Create autonomous coordinator
    auto_coord = AutonomousCoordinator(
        coordinator,
        agent_manager,
        min_agents=min_agents,
        max_agents=max_agents,
        check_interval=check_interval,
        idle_timeout=idle_timeout,
        maximize_parallelism=maximize_parallelism
    )
    
    # Start autonomous coordinator
    auto_coord.start()
    
    print("\n" + "=" * 80)
    print("AUTONOMOUS TEAM - Running until completion")
    print("=" * 80)
    print(f"Tasks: {len(tasks)}")
    print(f"Agents: {min_agents}-{max_agents}")
    print(f"Check interval: {check_interval}s")
    print("=" * 80)
    
    # Monitor progress
    last_progress = 0
    while auto_coord.running and not auto_coord.completed:
        time.sleep(check_interval)
        
        progress = auto_coord.get_progress()
        
        # Print progress if changed
        if progress['completed_tasks'] != last_progress:
            parallelism_info = ""
            if 'parallelism' in progress:
                p = progress['parallelism']
                parallelism_info = f" | ⚡ Parallel: {p['current_parallel_tasks']}/{p['max_possible_parallelism']} ({p['parallelism_efficiency']:.0f}%)"
            
            print(f"\n📊 Progress: {progress['completed_tasks']}/{progress['total_tasks']} "
                  f"({progress['progress_percentage']:.1f}%) | "
                  f"Running agents: {progress['running_agents']} | "
                  f"Ready tasks: {progress['ready_tasks']}{parallelism_info}")
            last_progress = progress['completed_tasks']
            
            if progress_callback:
                progress_callback(progress)
    
    # Wait for completion
    completed = auto_coord.wait_for_completion()
    
    # Stop coordinator
    auto_coord.stop()
    
    # Final status
    final_progress = auto_coord.get_progress()
    print("\n" + "=" * 80)
    print("FINAL STATUS")
    print("=" * 80)
    print(f"Completed: {final_progress['completed_tasks']}/{final_progress['total_tasks']}")
    print(f"Progress: {final_progress['progress_percentage']:.1f}%")
    print(f"All tasks completed: {final_progress['all_completed']}")
    
    return completed

