"""
AI Agent Coordinator - Manages multiple AI agents working on a project
with incremental task execution and coordination.
"""

from enum import Enum
from dataclasses import dataclass, field
from typing import List, Dict, Optional, Set, Any
from datetime import datetime
from collections import defaultdict
import json
import os
import inspect
from ..utils.conflict_prevention import ConflictPreventionSystem, ChangeSet, LockType

# Import logger (optional)
try:
    from ..utils.agent_logger import AgentLogger
    LOGGING_AVAILABLE = True
except Exception:
    LOGGING_AVAILABLE = False
    # Fallback logger (keep it minimal; coordinator should not crash if logging is unavailable)
    class AgentLogger:  # type: ignore
        @staticmethod
        def debug(*args, **kwargs): pass
        @staticmethod
        def info(*args, **kwargs): pass
        @staticmethod
        def warning(*args, **kwargs): pass
        @staticmethod
        def error(*args, **kwargs): pass


class TaskStatus(Enum):
    """Task status states following the protocol"""
    PENDING = "pending"
    READY = "ready"
    ASSIGNED = "assigned"
    IN_PROGRESS = "in_progress"
    BLOCKED = "blocked"
    REVIEW = "review"
    COMPLETED = "completed"
    FAILED = "failed"

class BlockerType(Enum):
    """
    Orthogonal classification of why a task is blocked.
    This is intentionally separate from TaskStatus to avoid state explosion.
    """
    DEPENDENCY = "dependency"
    ACCEPTANCE = "acceptance"
    ENVIRONMENT = "environment"
    CONFLICT = "conflict"
    UNKNOWN = "unknown"


class MessageType(Enum):
    """Types of messages agents can send"""
    STATUS_UPDATE = "status_update"
    DEPENDENCY_REQUEST = "dependency_request"
    CHECKPOINT = "checkpoint"
    COMPLETION = "completion"
    AGENT_CONTROL = "agent_control"  # Control messages from coordinator


class AgentState(Enum):
    """Agent lifecycle states"""
    CREATED = "created"
    STARTED = "started"
    RUNNING = "running"
    PAUSED = "paused"
    STOPPED = "stopped"
    ERROR = "error"


@dataclass
class Task:
    """Represents a single task increment"""
    id: str
    title: str
    description: str
    estimated_hours: float
    dependencies: List[str] = field(default_factory=list)
    assigned_agent: Optional[str] = None
    status: TaskStatus = TaskStatus.PENDING
    progress: int = 0  # 0-100
    created_at: datetime = field(default_factory=datetime.now)
    started_at: Optional[datetime] = None
    completed_at: Optional[datetime] = None
    acceptance_criteria: List[str] = field(default_factory=list)
    artifacts: List[str] = field(default_factory=list)
    blocker_message: Optional[str] = None
    blocker_type: Optional[str] = None  # One of BlockerType.*.value (string for persistence compatibility)
    metadata: Dict[str, Any] = field(default_factory=dict)  # Task metadata for adapters

    def to_dict(self):
        """Convert task to dictionary for serialization"""
        return {
            "id": self.id,
            "title": self.title,
            "description": self.description,
            "estimated_hours": self.estimated_hours,
            "dependencies": self.dependencies,
            "assigned_agent": self.assigned_agent,
            "status": self.status.value,
            "progress": self.progress,
            "created_at": self.created_at.isoformat(),
            "started_at": self.started_at.isoformat() if self.started_at else None,
            "completed_at": self.completed_at.isoformat() if self.completed_at else None,
            "acceptance_criteria": self.acceptance_criteria,
            "artifacts": self.artifacts,
            "blocker_message": self.blocker_message,
            "blocker_type": self.blocker_type,
            "metadata": self.metadata
        }

    @classmethod
    def from_dict(cls, data):
        """Create task from dictionary"""
        task = cls(
            id=data["id"],
            title=data["title"],
            description=data["description"],
            estimated_hours=data["estimated_hours"],
            dependencies=data.get("dependencies", []),
            assigned_agent=data.get("assigned_agent"),
            status=TaskStatus(data.get("status", "pending")),
            progress=data.get("progress", 0),
            acceptance_criteria=data.get("acceptance_criteria", []),
            artifacts=data.get("artifacts", []),
            blocker_message=data.get("blocker_message"),
            blocker_type=data.get("blocker_type"),
            metadata=data.get("metadata", {})
        )
        if data.get("created_at"):
            task.created_at = datetime.fromisoformat(data["created_at"])
        if data.get("started_at"):
            task.started_at = datetime.fromisoformat(data["started_at"])
        if data.get("completed_at"):
            task.completed_at = datetime.fromisoformat(data["completed_at"])
        return task


@dataclass
class AgentMessage:
    """Message from an agent following the communication protocol"""
    agent_id: str
    task_id: Optional[str]
    message_type: MessageType
    status: Optional[TaskStatus] = None
    progress: Optional[int] = None
    message: Optional[str] = None
    blocked_on: Optional[str] = None
    changes: Optional[str] = None
    next_steps: Optional[str] = None
    result: Optional[str] = None
    artifacts: Optional[List[str]] = None
    tests: Optional[str] = None
    timestamp: datetime = field(default_factory=datetime.now)

    def to_dict(self):
        """Convert message to dictionary"""
        return {
            "agent_id": self.agent_id,
            "task_id": self.task_id,
            "message_type": self.message_type.value,
            "status": self.status.value if self.status else None,
            "progress": self.progress,
            "message": self.message,
            "blocked_on": self.blocked_on,
            "changes": self.changes,
            "next_steps": self.next_steps,
            "result": self.result,
            "artifacts": self.artifacts,
            "tests": self.tests,
            "timestamp": self.timestamp.isoformat()
        }


@dataclass
class Checkpoint:
    """Represents a checkpoint in agent work"""
    agent_id: str
    task_id: str
    progress: int
    changes: str
    next_steps: str
    timestamp: datetime = field(default_factory=datetime.now)

    def to_dict(self):
        return {
            "agent_id": self.agent_id,
            "task_id": self.task_id,
            "progress": self.progress,
            "changes": self.changes,
            "next_steps": self.next_steps,
            "timestamp": self.timestamp.isoformat()
        }


class AgentCoordinator:
    """
    Coordinates multiple AI agents working on a project.
    Manages task assignment, dependencies, and incremental progress.
    """

    def __init__(self, project_name: str = "AI Team Project", enable_conflict_prevention: bool = True):
        self.project_name = project_name
        self.tasks: Dict[str, Task] = {}
        self.agents: Set[str] = set()
        self.agent_instances: Dict[str, 'Agent'] = {}  # agent_id -> Agent instance
        self.agent_states: Dict[str, AgentState] = {}  # agent_id -> AgentState
        # Agent liveness tracking (generic, in-memory). Used by Supervisor to detect unresponsive agents.
        self.agent_last_heartbeat: Dict[str, datetime] = {}
        self.agent_specializations: Dict[str, str] = {}
        # Specialization -> callable(agent_id, coordinator, specialization?) -> Agent instance
        self._agent_spawn_factories: Dict[str, Any] = {}
        self.messages: List[AgentMessage] = []
        self.checkpoints: List[Checkpoint] = []
        self.agent_workloads: Dict[str, int] = defaultdict(int)  # agent_id -> number of active tasks
        self.conflict_prevention = ConflictPreventionSystem() if enable_conflict_prevention else None
        self.team_id: Optional[str] = None  # REQ-1.2.2: Team ID persists for entire team lifecycle

    def register_agent(self, agent_id: str, agent_instance: Optional['Agent'] = None):
        """Register a new agent with the coordinator"""
        self.agents.add(agent_id)
        self.agent_workloads[agent_id] = 0
        self.agent_states[agent_id] = AgentState.CREATED
        if agent_instance:
            self.agent_instances[agent_id] = agent_instance
            # Best-effort: track specialization for spawned agent replacement.
            try:
                spec = getattr(agent_instance, "specialization", "") or ""
                if spec:
                    self.agent_specializations[agent_id] = spec
            except Exception:
                pass
        # Initialize heartbeat to "now" to avoid false positives right after registration.
        try:
            self.agent_last_heartbeat[agent_id] = datetime.now()
        except Exception:
            pass
        print(f"Agent '{agent_id}' registered")
    
    def register_agent_instance(self, agent: 'Agent'):
        """Register an agent instance for remote control"""
        self.agent_instances[agent.agent_id] = agent
        # Track specialization and register a spawn factory for this specialization.
        try:
            spec = getattr(agent, "specialization", "") or ""
            if spec:
                self.agent_specializations[agent.agent_id] = spec
                self._register_spawn_factory_for_agent(agent, spec)
        except Exception:
            pass
        try:
            self.agent_last_heartbeat[agent.agent_id] = datetime.now()
        except Exception:
            pass
        self.register_agent(agent.agent_id, agent)

    def record_heartbeat(self, agent_id: str, task_id: Optional[str] = None, state: Optional[str] = None):
        """
        Record that an agent is alive. Intended to be called by agents from their work loop.
        This is generic and does not assume any project type.
        """
        self.agent_last_heartbeat[agent_id] = datetime.now()
        # Keep a small amount of structured data in-memory for diagnosis.
        try:
            agent = self.agent_instances.get(agent_id)
            if agent is not None and hasattr(agent, "state"):
                self.agent_states[agent_id] = agent.state  # type: ignore
        except Exception:
            pass

    def _register_spawn_factory_for_agent(self, agent: 'Agent', specialization: str):
        """
        Register a factory that can spawn a new agent of the same class for a given specialization.
        We do this lazily from the first observed agent instance.
        """
        if not specialization or specialization == "supervisor":
            return
        if specialization in self._agent_spawn_factories:
            return

        cls = agent.__class__

        def _factory(agent_id: str) -> 'Agent':
            # Prefer __init__(agent_id, coordinator, specialization) when supported.
            try:
                sig = inspect.signature(cls.__init__)
                params = list(sig.parameters.keys())
                # params includes 'self'
                if "specialization" in params:
                    return cls(agent_id, self, specialization)  # type: ignore[misc]
            except Exception:
                pass
            # Fallback: common pattern is __init__(agent_id, coordinator)
            return cls(agent_id, self)  # type: ignore[misc]

        self._agent_spawn_factories[specialization] = _factory

    def spawn_agent_for_specialization(self, specialization: str, agent_id: Optional[str] = None) -> Optional[str]:
        """
        Spawn a new agent for the given specialization (developer/tester/etc).
        This is used by Supervisor remediation to replace unresponsive agents.
        """
        if not specialization:
            return None
        factory = self._agent_spawn_factories.get(specialization)
        if not factory:
            return None

        # Generate a unique agent_id if not provided
        if not agent_id:
            base = f"{specialization}-agent-auto-"
            n = 1
            while f"{base}{n}" in self.agents:
                n += 1
            agent_id = f"{base}{n}"

        try:
            agent = factory(agent_id)
            # Agent base __init__ should register itself; but keep safe.
            if agent_id not in self.agent_instances:
                self.register_agent_instance(agent)
            self.start_agent(agent_id)
            return agent_id
        except Exception:
            return None
    
    def start_agent(self, agent_id: str) -> bool:
        """
        Start an agent. Returns True if successful.
        Can be called by coordinator or another coordinator agent.
        """
        if agent_id not in self.agents:
            print(f"Error: Agent '{agent_id}' not registered")
            return False
        
        if agent_id not in self.agent_instances:
            print(f"Error: Agent instance for '{agent_id}' not available")
            return False
        
        agent = self.agent_instances[agent_id]
        current_state = self.agent_states.get(agent_id, AgentState.CREATED)
        
        if current_state == AgentState.RUNNING:
            print(f"Agent '{agent_id}' is already running")
            return True
        
        if current_state == AgentState.STOPPED:
            print(f"Error: Agent '{agent_id}' is stopped and cannot be restarted")
            return False
        
        # Send control message to agent
        control_msg = AgentMessage(
            agent_id="coordinator",
            task_id=None,
            message_type=MessageType.AGENT_CONTROL,
            message="start"
        )
        
        # Update state
        self.agent_states[agent_id] = AgentState.STARTED
        
        # If agent has a start method, call it
        if hasattr(agent, 'start'):
            try:
                agent.start()
                self.agent_states[agent_id] = AgentState.RUNNING
                print(f"Agent '{agent_id}' started successfully")
                return True
            except Exception as e:
                self.agent_states[agent_id] = AgentState.ERROR
                print(f"Error starting agent '{agent_id}': {e}")
                return False
        
        # Otherwise, mark as started (agent will start itself)
        self.agent_states[agent_id] = AgentState.RUNNING
        print(f"Agent '{agent_id}' marked as started")
        return True
    
    def stop_agent(self, agent_id: str) -> bool:
        """Stop an agent. Returns True if successful."""
        if agent_id not in self.agents:
            return False
        
        if agent_id not in self.agent_instances:
            return False
        
        agent = self.agent_instances[agent_id]
        current_state = self.agent_states.get(agent_id, AgentState.CREATED)
        
        if current_state == AgentState.STOPPED:
            return True
        
        # Send control message
        control_msg = AgentMessage(
            agent_id="coordinator",
            task_id=None,
            message_type=MessageType.AGENT_CONTROL,
            message="stop"
        )
        
        # If agent has a stop method, call it
        if hasattr(agent, 'stop'):
            try:
                agent.stop()
                self.agent_states[agent_id] = AgentState.STOPPED
                print(f"Agent '{agent_id}' stopped")
                return True
            except Exception as e:
                print(f"Error stopping agent '{agent_id}': {e}")
                return False
        
        # Otherwise, just update state
        self.agent_states[agent_id] = AgentState.STOPPED
        print(f"Agent '{agent_id}' marked as stopped")
        return True
    
    def pause_agent(self, agent_id: str) -> bool:
        """Pause an agent. Returns True if successful."""
        if agent_id not in self.agents or agent_id not in self.agent_instances:
            return False
        
        agent = self.agent_instances[agent_id]
        current_state = self.agent_states.get(agent_id, AgentState.CREATED)
        
        if current_state != AgentState.RUNNING:
            return False
        
        if hasattr(agent, 'pause'):
            try:
                agent.pause()
                self.agent_states[agent_id] = AgentState.PAUSED
                print(f"Agent '{agent_id}' paused")
                return True
            except Exception as e:
                print(f"Error pausing agent '{agent_id}': {e}")
                return False
        
        self.agent_states[agent_id] = AgentState.PAUSED
        return True
    
    def resume_agent(self, agent_id: str) -> bool:
        """Resume a paused agent. Returns True if successful."""
        if agent_id not in self.agents or agent_id not in self.agent_instances:
            return False
        
        agent = self.agent_instances[agent_id]
        current_state = self.agent_states.get(agent_id, AgentState.CREATED)
        
        if current_state != AgentState.PAUSED:
            return False
        
        if hasattr(agent, 'resume'):
            try:
                agent.resume()
                self.agent_states[agent_id] = AgentState.RUNNING
                print(f"Agent '{agent_id}' resumed")
                return True
            except Exception as e:
                print(f"Error resuming agent '{agent_id}': {e}")
                return False
        
        self.agent_states[agent_id] = AgentState.RUNNING
        return True
    
    def get_agent_state(self, agent_id: str) -> Optional[AgentState]:
        """Get the current state of an agent"""
        return self.agent_states.get(agent_id)
    
    def get_all_agent_states(self) -> Dict[str, str]:
        """Get states of all agents"""
        return {
            agent_id: state.value
            for agent_id, state in self.agent_states.items()
        }
    
    def start_all_agents(self) -> Dict[str, bool]:
        """Start all registered agents. Returns dict of agent_id -> success"""
        results = {}
        for agent_id in self.agents:
            results[agent_id] = self.start_agent(agent_id)
        return results
    
    def stop_all_agents(self) -> Dict[str, bool]:
        """Stop all registered agents. Returns dict of agent_id -> success"""
        results = {}
        for agent_id in self.agents:
            results[agent_id] = self.stop_agent(agent_id)
        return results

    def add_task(self, task: Task):
        """Add a new task to the system"""
        self.tasks[task.id] = task
        self._update_task_status(task.id)
        print(f"Task '{task.id}' added: {task.title}")

    def add_tasks(self, tasks: List[Task]):
        """Add multiple tasks at once"""
        for task in tasks:
            self.add_task(task)

    def _update_task_status(self, task_id: str):
        """Update task status based on dependencies"""
        if task_id not in self.tasks:
            return  # Task doesn't exist
        
        task = self.tasks[task_id]
        
        # Don't change status of tasks that are already completed or failed
        if task.status in [TaskStatus.COMPLETED, TaskStatus.FAILED]:
            return
        
        # Don't change status of tasks that are in progress or assigned (they're actively being worked on)
        if task.status in [TaskStatus.IN_PROGRESS, TaskStatus.ASSIGNED]:
            return
        
        # Check if all dependencies are completed
        if task.dependencies:
            # Check which dependencies exist and their status
            missing_deps = [dep_id for dep_id in task.dependencies if dep_id not in self.tasks]
            existing_deps = [dep_id for dep_id in task.dependencies if dep_id in self.tasks]
            
            # If there are missing dependencies, we can't determine readiness - keep current status or block
            if missing_deps:
                # Missing deps should not leave tasks stuck in PENDING indefinitely.
                # Convert to BLOCKED with a clear dependency blocker so supervisor/agents can react.
                if task.status != TaskStatus.BLOCKED:
                    task.status = TaskStatus.BLOCKED
                    task.blocker_message = f"Missing dependencies: {missing_deps}"
                    try:
                        task.blocker_type = BlockerType.DEPENDENCY.value
                    except Exception:
                        task.blocker_type = "dependency"
                return
            
            # Check if all existing dependencies are completed
            # CRITICAL: Dependencies can be COMPLETED or REVIEW (both mean they're done)
            all_deps_completed = all(
                self.tasks[dep_id].status in [TaskStatus.COMPLETED, TaskStatus.REVIEW]
                for dep_id in existing_deps
            )
            
            if all_deps_completed:
                # Unblock if blocked, or make ready if pending
                if task.status == TaskStatus.BLOCKED:
                    # Only auto-unblock if this block appears dependency-related.
                    # Tasks can be BLOCKED for other reasons (e.g., missing environment/tooling, acceptance failures).
                    # In those cases, blindly unblocking causes infinite READY->IN_PROGRESS->BLOCKED loops.
                    blocker = (task.blocker_message or "").strip().lower()
                    bt = (getattr(task, "blocker_type", None) or "").strip().lower()
                    # Special-case: some BLOCKED states are transient execution/tooling failures.
                    # If dependencies are met and the blocker indicates an execution/parsing failure,
                    # allow a small retry budget before leaving the task blocked.
                    try:
                        repeats = int((task.metadata or {}).get("blocker_repeats", 0))
                    except Exception:
                        repeats = 0
                    retryable_exec_block = (
                        (not bt or bt == BlockerType.UNKNOWN.value)
                        and repeats <= 2
                        and (
                            "execution failed" in blocker
                            or "could not find a json object" in blocker
                            or "failed to parse json" in blocker
                            or "invalid json shape" in blocker
                            or "cursor cli returned empty response" in blocker
                        )
                    )
                    dependency_block = (
                        bt == BlockerType.DEPENDENCY.value
                        or not blocker
                        or blocker.startswith("waiting on dependencies")
                        or blocker.startswith("blocked on dependency")
                        or blocker.startswith("waiting on:")
                    )
                    if dependency_block or retryable_exec_block:
                        task.status = TaskStatus.READY
                        task.blocker_message = None
                        task.blocker_type = None
                        print(f"[COORDINATOR] Task '{task_id}' is now READY (all dependencies met)")
                        if LOGGING_AVAILABLE:
                            AgentLogger.info(
                                "AgentCoordinator",
                                f"Task {task_id} unblocked: BLOCKED -> READY (dependencies: {existing_deps})",
                                task_id=task_id,
                                extra={'dependencies': existing_deps},
                            )
                    else:
                        # Keep blocked; dependency condition is satisfied but the block reason is not dependencies.
                        if LOGGING_AVAILABLE:
                            try:
                                # Avoid log spam: this branch is evaluated frequently in the main loop.
                                # Only log when the blocker message/type changes for the task.
                                sig = f"non_dep_block::{getattr(task, 'blocker_type', None)}::{task.blocker_message}"
                                last_sig = None
                                try:
                                    last_sig = (task.metadata or {}).get("_last_non_dep_block_log_sig")
                                except Exception:
                                    last_sig = None
                                if sig != last_sig:
                                    try:
                                        task.metadata["_last_non_dep_block_log_sig"] = sig
                                    except Exception:
                                        pass
                                    AgentLogger.debug(
                                        "AgentCoordinator",
                                        f"Task {task_id} remains BLOCKED despite deps met (non-dependency blocker): {task.blocker_message}",
                                        task_id=task_id,
                                        extra={'dependencies': existing_deps},
                                    )
                            except Exception:
                                pass
                elif task.status == TaskStatus.PENDING:
                    task.status = TaskStatus.READY
                    print(f"[COORDINATOR] Task '{task_id}' is now READY (all dependencies met)")
                    if LOGGING_AVAILABLE:
                        AgentLogger.info("AgentCoordinator", 
                            f"Task {task_id} transitioned: PENDING -> READY (dependencies: {existing_deps})",
                            task_id=task_id,
                            extra={'dependencies': existing_deps})
                    # CRITICAL: Force immediate persistence of status change
                    # This ensures the status change is not lost
                    return  # Status changed, caller should persist
            else:
                # Not all dependencies are completed - block the task
                # CRITICAL: Dependencies can be COMPLETED or REVIEW (both mean they're done)
                incomplete_deps = [dep_id for dep_id in existing_deps 
                                  if self.tasks[dep_id].status not in [TaskStatus.COMPLETED, TaskStatus.REVIEW]]
                if task.status != TaskStatus.BLOCKED:
                    task.status = TaskStatus.BLOCKED
                    task.blocker_message = f"Waiting on dependencies: {incomplete_deps}"
                    print(f"Task '{task_id}' is now BLOCKED (waiting on: {incomplete_deps})")
                else:
                    # Already blocked, but update blocker message with current incomplete deps
                    task.blocker_message = f"Waiting on dependencies: {incomplete_deps}"
        elif task.status == TaskStatus.PENDING:
            # No dependencies - make ready
            task.status = TaskStatus.READY
        elif task.status == TaskStatus.BLOCKED and not task.dependencies:
            # Task is blocked but has no dependencies - might be a false block or needs manual review
            # If blocker_message doesn't contain task IDs, it might be a different type of block
            # For now, keep it blocked but log it for debugging
            if not task.blocker_message:
                # No blocker message and no dependencies - unblock it
                task.status = TaskStatus.READY
                task.blocker_message = None
                print(f"Task '{task_id}' is now READY (no dependencies and no blocker message)")
            else:
                # Has blocker message but no dependencies - might be blocked for other reasons
                # Try to extract task IDs from blocker message one more time
                import re
                task_id_pattern = r'task-\d+|[\w-]+-\d+'
                potential_deps = re.findall(task_id_pattern, task.blocker_message)
                if potential_deps:
                    for dep_id in potential_deps:
                        if dep_id in self.tasks and dep_id not in task.dependencies:
                            task.dependencies.append(dep_id)
                            print(f"Task '{task_id}' dependency '{dep_id}' extracted from blocker message")
                    # Recursively check again now that we have dependencies
                    if task.dependencies:
                        self._update_task_status(task_id)
                        return
                # Still no dependencies after extraction - keep blocked but log
                if LOGGING_AVAILABLE:
                    # IMPORTANT: do not re-import AgentLogger inside this function.
                    # Local imports would shadow the module-level AgentLogger and can raise:
                    # "cannot access local variable 'AgentLogger' where it is not associated with a value"
                    try:
                        AgentLogger.debug(
                            "AgentCoordinator",
                            f"Task {task_id} is BLOCKED with no dependencies - blocker: {task.blocker_message}",
                            task_id=task_id,
                        )
                    except Exception:
                        pass
        elif task.status == TaskStatus.BLOCKED and not task.dependencies:
            # Task is blocked but has no dependencies - might be a false block
            # Check if blocker_message suggests it should stay blocked or can be unblocked
            if task.blocker_message:
                # If blocker message doesn't contain task IDs, it might be a different type of block
                # For now, keep it blocked but log it
                if LOGGING_AVAILABLE:
                    # IMPORTANT: do not re-import AgentLogger inside this function.
                    try:
                        AgentLogger.debug(
                            "AgentCoordinator",
                            f"Task {task_id} is BLOCKED with no dependencies - blocker: {task.blocker_message}",
                            task_id=task_id,
                        )
                    except Exception:
                        pass
            else:
                # No blocker message and no dependencies - unblock it
                task.status = TaskStatus.READY
                print(f"Task '{task_id}' is now READY (no dependencies and no blocker message)")

    def assign_task(self, task_id: str, agent_id: str, check_conflicts: bool = True) -> bool:
        """
        Assign a task to an agent.
        Returns True if assignment successful, False otherwise.
        
        Args:
            task_id: ID of task to assign
            agent_id: ID of agent to assign to
            check_conflicts: If True, check for file conflicts before assigning
        """
        if agent_id not in self.agents:
            print(f"Error: Agent '{agent_id}' not registered")
            return False

        if task_id not in self.tasks:
            print(f"Error: Task '{task_id}' not found")
            return False

        task = self.tasks[task_id]

        if task.status != TaskStatus.READY:
            print(f"Error: Task '{task_id}' is not ready (status: {task.status.value})")
            return False

        # Check for conflicts if enabled
        if check_conflicts and self.conflict_prevention:
            # Get expected files for this task
            expected_files = self._get_expected_files_for_task(task)
            
            # Check if any expected files are locked by other agents
            for file_path in expected_files:
                if self.conflict_prevention.lock_manager.is_locked(file_path):
                    owner = self.conflict_prevention.lock_manager.get_lock_owner(file_path)
                    if owner and owner != agent_id:
                        print(f"  [CONFLICT] Cannot assign task '{task_id}' to '{agent_id}': file '{file_path}' locked by '{owner}'")
                        return False

        old_status = task.status
        task.assigned_agent = agent_id
        task.status = TaskStatus.ASSIGNED
        self.agent_workloads[agent_id] += 1
        print(f"Task '{task_id}' assigned to agent '{agent_id}'")
        try:
            if LOGGING_AVAILABLE:
                AgentLogger.info(
                    "AgentCoordinator",
                    f"[task:{task_id}] Task assigned: {old_status.value} -> {task.status.value}",
                    task_id=task_id,
                    extra={
                        "old_status": old_status.value,
                        "new_status": task.status.value,
                        "assigned_agent": agent_id,
                    },
                )
        except Exception:
            pass
        return True
    
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

    def start_task(self, task_id: str, agent_id: str) -> bool:
        """Mark a task as in progress"""
        if task_id not in self.tasks:
            return False

        task = self.tasks[task_id]
        if task.assigned_agent != agent_id:
            print(f"Error: Task '{task_id}' not assigned to agent '{agent_id}'")
            return False

        # Don't allow starting tasks that are already completed
        if task.status == TaskStatus.COMPLETED:
            print(f"Error: Task '{task_id}' is already completed - cannot start")
            return False

        # Don't allow starting tasks at 100% progress - supervisor should complete them
        if task.progress >= 100:
            print(f"Error: Task '{task_id}' is at 100% progress - supervisor should complete it, cannot start")
            return False

        # Allow resuming tasks that were persisted as IN_PROGRESS (e.g., after a process restart).
        # This is critical for progress persistence: agents must be able to pick up their
        # previously-started tasks instead of leaving them stuck forever.
        if task.status == TaskStatus.IN_PROGRESS:
            print(f"Agent '{agent_id}' resumed task '{task_id}'")
            try:
                if LOGGING_AVAILABLE:
                    AgentLogger.info(
                        "AgentCoordinator",
                        f"[task:{task_id}] Task resumed: {task.status.value}",
                        task_id=task_id,
                        extra={"agent_id": agent_id},
                    )
            except Exception:
                pass
            return True

        if task.status != TaskStatus.ASSIGNED:
            print(f"Error: Task '{task_id}' not in ASSIGNED status (current: {task.status.value})")
            return False

        old_status = task.status
        task.status = TaskStatus.IN_PROGRESS
        task.started_at = datetime.now()
        print(f"Agent '{agent_id}' started task '{task_id}'")
        try:
            if LOGGING_AVAILABLE:
                AgentLogger.info(
                    "AgentCoordinator",
                    f"[task:{task_id}] Task started: {old_status.value} -> {task.status.value}",
                    task_id=task_id,
                    extra={
                        "old_status": old_status.value,
                        "new_status": task.status.value,
                        "agent_id": agent_id,
                    },
                )
        except Exception:
            pass
        return True

    def process_message(self, message: AgentMessage):
        """Process a message from an agent"""
        self.messages.append(message)
        
        if message.task_id and message.task_id in self.tasks:
            task = self.tasks[message.task_id]

            if message.message_type == MessageType.STATUS_UPDATE:
                # CRITICAL: Per supervisor_issues_checklist.md requirement, completed tasks must never be reset
                # Once a task is COMPLETED, it stays COMPLETED to prevent completed count from going backwards
                was_completed = task.status == TaskStatus.COMPLETED
                new_status = message.status
                will_not_be_completed = new_status != TaskStatus.COMPLETED
                
                if was_completed and will_not_be_completed:
                    # Task is already completed - reject status change to prevent backwards progress
                    print(f"[{message.agent_id}] [WARNING] Task '{task.id}' is already COMPLETED - rejecting status change to {new_status.value} (per supervisor_issues_checklist.md: completed count must never go backwards)")
                    # Don't update status or clear completed_at
                    if message.message:
                        print(f"[{message.agent_id}] {message.message}")
                    return  # Don't process the status update
                
                old_status = task.status
                old_progress = task.progress

                if message.status:
                    task.status = message.status
                    # Preserve blocker reason when a task is blocked for non-dependency reasons.
                    if message.status == TaskStatus.BLOCKED:
                        if message.message:
                            task.blocker_message = message.message
                            # Best-effort blocker classification from message text.
                            msg = message.message.lower()
                            if "waiting on dependencies" in msg or "blocked on dependency" in msg or "missing dependencies" in msg:
                                task.blocker_type = BlockerType.DEPENDENCY.value
                            elif "acceptance command failed" in msg or "acceptance criteria failed" in msg:
                                task.blocker_type = BlockerType.ACCEPTANCE.value
                            elif "no android sdk" in msg or "android_home" in msg or "not found" in msg or "sdk" in msg:
                                # Environment/tooling failures (generic heuristic)
                                task.blocker_type = BlockerType.ENVIRONMENT.value
                            elif "conflict" in msg or "locked by" in msg:
                                task.blocker_type = BlockerType.CONFLICT.value
                            else:
                                task.blocker_type = BlockerType.UNKNOWN.value
                            # Track repeated blocker signatures to support supervisor quarantine policies.
                            try:
                                sig = msg.strip()[:200]
                                prev = task.metadata.get("blocker_signature")
                                if prev == sig:
                                    task.metadata["blocker_repeats"] = int(task.metadata.get("blocker_repeats", 0)) + 1
                                else:
                                    task.metadata["blocker_signature"] = sig
                                    task.metadata["blocker_repeats"] = 1
                            except Exception:
                                pass
                    else:
                        # Clear blocker message when task transitions out of BLOCKED.
                        if old_status == TaskStatus.BLOCKED:
                            task.blocker_message = None
                            task.blocker_type = None
                if message.progress is not None:
                    task.progress = message.progress
                if message.message:
                    print(f"[{message.agent_id}] {message.message}")

                try:
                    if LOGGING_AVAILABLE and (
                        task.status != old_status
                        or task.progress != old_progress
                        or bool(message.message)
                    ):
                        AgentLogger.info(
                            "AgentCoordinator",
                            f"[task:{task.id}] Status update from {message.agent_id}: "
                            f"{old_status.value}/{old_progress} -> {task.status.value}/{task.progress}",
                            task_id=task.id,
                            extra={
                                "from_agent": message.agent_id,
                                "old_status": old_status.value,
                                "new_status": task.status.value,
                                "old_progress": old_progress,
                                "new_progress": task.progress,
                                "message": (message.message or "")[:200],
                            },
                        )
                except Exception:
                    pass

            elif message.message_type == MessageType.DEPENDENCY_REQUEST:
                old_status = task.status
                task.status = TaskStatus.BLOCKED
                task.blocker_message = message.message or f"Waiting on: {message.blocked_on}"
                # CRITICAL: If blocked_on is a task ID, ensure it's in dependencies list
                if message.blocked_on and message.blocked_on not in task.dependencies:
                    if message.blocked_on in self.tasks:
                        # Add to dependencies if it's a valid task ID
                        task.dependencies.append(message.blocked_on)
                print(f"[{message.agent_id}] Blocked on dependency: {message.blocked_on}")
                try:
                    if LOGGING_AVAILABLE:
                        AgentLogger.info(
                            "AgentCoordinator",
                            f"[task:{task.id}] Dependency request from {message.agent_id}: "
                            f"{old_status.value} -> {task.status.value}",
                            task_id=task.id,
                            extra={
                                "from_agent": message.agent_id,
                                "old_status": old_status.value,
                                "new_status": task.status.value,
                                "blocked_on": message.blocked_on,
                                "blocker_message": (task.blocker_message or "")[:200],
                            },
                        )
                except Exception:
                    pass

            elif message.message_type == MessageType.CHECKPOINT:
                if message.progress is not None:
                    task.progress = message.progress
                checkpoint = Checkpoint(
                    agent_id=message.agent_id,
                    task_id=message.task_id,
                    progress=message.progress or task.progress,
                    changes=message.changes or "",
                    next_steps=message.next_steps or ""
                )
                self.checkpoints.append(checkpoint)
                print(f"[{message.agent_id}] Checkpoint: {message.progress}% - {message.changes}")

            elif message.message_type == MessageType.COMPLETION:
                # In this system, agents apply changes directly to the shared workspace.
                # That means a "completion" is effectively already integrated (there is no
                # separate merge step). Keeping tasks in REVIEW without marking their changes
                # as integrated causes false "pending task" conflicts for downstream tasks
                # touching the same files (e.g., pubspec.yaml).
                task.status = TaskStatus.COMPLETED
                task.progress = 100
                task.completed_at = datetime.now()
                if message.artifacts:
                    task.artifacts = message.artifacts
                
                # Register changes for conflict detection
                if self.conflict_prevention and message.artifacts:
                    change_set = ChangeSet(
                        agent_id=message.agent_id,
                        task_id=message.task_id,
                        files_modified=message.artifacts,
                        description=message.result or f"Completed {task.title}"
                    )
                    self.conflict_prevention.register_changes(change_set)
                    
                    # Validate changes before marking as ready for integration
                    # Allow updates to files from completed tasks (they're already integrated)
                    is_valid, issues = self.conflict_prevention.validate_changes(change_set, allow_completed_updates=True)
                    if not is_valid:
                        print(f"[{message.agent_id}] WARNING: Conflicts detected for task '{message.task_id}': {issues}")
                        task.blocker_message = f"Integration conflicts: {', '.join(issues)}"
                        task.status = TaskStatus.BLOCKED
                    else:
                        print(f"[{message.agent_id}] Completed task '{message.task_id}' (validated, ready for integration)")
                        # Mark changes integrated so they are treated as baseline and do not block
                        # subsequent tasks from modifying the same files.
                        try:
                            self.conflict_prevention.mark_changes_integrated(message.task_id)
                        except Exception:
                            pass
                
                print(f"[{message.agent_id}] Completed task '{message.task_id}'")
                
                # CRITICAL: Update dependencies for other tasks IMMEDIATELY when a task completes
                # This ensures blocked tasks are unblocked as soon as dependencies complete
                # Note: Task is in REVIEW status, which should be treated as completed for dependency purposes
                updated_count = 0
                for other_task in self.tasks.values():
                    if message.task_id in other_task.dependencies:
                        old_status = other_task.status
                        self._update_task_status(other_task.id)
                        if other_task.status != old_status:
                            updated_count += 1
                            print(f"[COORDINATOR] Task '{other_task.id}' status updated: {old_status.value} -> {other_task.status.value} (dependency '{message.task_id}' completed/REVIEW)")
                
                if updated_count > 0:
                    print(f"[COORDINATOR] Updated {updated_count} dependent task(s) after '{message.task_id}' completion")

    def complete_task(self, task_id: str, agent_id: str) -> bool:
        """Mark a task as completed and integrated"""
        if task_id not in self.tasks:
            return False

        task = self.tasks[task_id]
        if task.assigned_agent != agent_id:
            return False

        task.status = TaskStatus.COMPLETED
        task.progress = 100
        task.completed_at = datetime.now()
        self.agent_workloads[agent_id] = max(0, self.agent_workloads[agent_id] - 1)
        
        # Mark changes as integrated in conflict prevention system
        if self.conflict_prevention:
            self.conflict_prevention.mark_changes_integrated(task_id)
            # Release all locks held by agent for this task
            if task.artifacts:
                for artifact in task.artifacts:
                    self.conflict_prevention.release_resource_access(artifact, agent_id)
        
        # Update status of dependent tasks to unblock them
        # CRITICAL: Update ALL dependent tasks when a task completes
        updated_count = 0
        for other_task in self.tasks.values():
            if task_id in other_task.dependencies:
                old_status = other_task.status
                self._update_task_status(other_task.id)
                # Log status changes for debugging
                if other_task.status != old_status:
                    updated_count += 1
                    print(f"[COORDINATOR] Task '{other_task.id}' status updated: {old_status.value} -> {other_task.status.value} (dependency '{task_id}' completed)")
        
        if updated_count > 0:
            print(f"[COORDINATOR] Updated {updated_count} dependent task(s) after '{task_id}' completion")

        print(f"Task '{task_id}' completed and integrated by agent '{agent_id}'")
        return True

    def get_ready_tasks(self) -> List[Task]:
        """Get all tasks that are ready to be assigned"""
        return [task for task in self.tasks.values() if task.status == TaskStatus.READY]

    def get_agent_tasks(self, agent_id: str) -> List[Task]:
        """Get all tasks assigned to a specific agent"""
        return [task for task in self.tasks.values() if task.assigned_agent == agent_id]

    def get_status_board(self) -> Dict:
        """Get current status of all tasks and agents"""
        status = {
            "project": self.project_name,
            "agents": list(self.agents),
            "agent_workloads": dict(self.agent_workloads),
            "agent_states": self.get_all_agent_states(),
            "tasks_by_status": {
                status.value: [
                    task.to_dict() for task in self.tasks.values()
                    if task.status == status
                ]
                for status in TaskStatus
            },
            "ready_tasks": [task.to_dict() for task in self.get_ready_tasks()],
            "total_tasks": len(self.tasks),
            "completed_tasks": len([t for t in self.tasks.values() if t.status == TaskStatus.COMPLETED])
        }
        
        # Add conflict prevention status if enabled
        if self.conflict_prevention:
            status["conflict_prevention"] = self.conflict_prevention.get_status()
        
        return status

    def get_dependency_graph(self) -> Dict:
        """Get dependency graph representation"""
        graph = {}
        for task_id, task in self.tasks.items():
            graph[task_id] = {
                "title": task.title,
                "status": task.status.value,
                "dependencies": task.dependencies,
                "dependents": [
                    t_id for t_id, t in self.tasks.items()
                    if task_id in t.dependencies
                ]
            }
        return graph

    def save_state(self, filepath: str):
        """Save coordinator state to file"""
        state = {
            "project_name": self.project_name,
            "tasks": [task.to_dict() for task in self.tasks.values()],
            "agents": list(self.agents),
            "messages": [msg.to_dict() for msg in self.messages],
            "checkpoints": [cp.to_dict() for cp in self.checkpoints]
        }
        with open(filepath, 'w') as f:
            json.dump(state, f, indent=2)
        print(f"State saved to {filepath}")

    def load_state(self, filepath: str):
        """Load coordinator state from file"""
        with open(filepath, 'r') as f:
            state = json.load(f)
        
        self.project_name = state["project_name"]
        self.tasks = {t["id"]: Task.from_dict(t) for t in state["tasks"]}
        self.agents = set(state["agents"])
        self.messages = [
            AgentMessage(
                agent_id=msg["agent_id"],
                task_id=msg.get("task_id"),
                message_type=MessageType(msg["message_type"]),
                status=TaskStatus(msg["status"]) if msg.get("status") else None,
                progress=msg.get("progress"),
                message=msg.get("message"),
                blocked_on=msg.get("blocked_on"),
                changes=msg.get("changes"),
                next_steps=msg.get("next_steps"),
                result=msg.get("result"),
                artifacts=msg.get("artifacts"),
                tests=msg.get("tests"),
                timestamp=datetime.fromisoformat(msg["timestamp"])
            )
            for msg in state["messages"]
        ]
        self.checkpoints = [
            Checkpoint(
                agent_id=cp["agent_id"],
                task_id=cp["task_id"],
                progress=cp["progress"],
                changes=cp["changes"],
                next_steps=cp["next_steps"],
                timestamp=datetime.fromisoformat(cp["timestamp"])
            )
            for cp in state["checkpoints"]
        ]
        
        # Recalculate workloads
        self.agent_workloads = defaultdict(int)
        for task in self.tasks.values():
            if task.assigned_agent and task.status in [TaskStatus.ASSIGNED, TaskStatus.IN_PROGRESS]:
                self.agent_workloads[task.assigned_agent] += 1
        
        print(f"State loaded from {filepath}")

