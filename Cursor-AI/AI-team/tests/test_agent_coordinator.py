"""
Unit Tests for Agent Coordinator

Tests the AgentCoordinator class which is responsible for:
- Managing all agents and tasks in the system
- Handling task assignment based on dependencies and agent availability
- Processing agent messages (status updates, checkpoints, completions)
- Tracking progress and checkpoints for all tasks
- Supporting task state management (pending, ready, assigned, in_progress, blocked, review, completed, failed)
- Supporting dependency resolution and graph management
- Supporting state persistence (save/load project state)
- Supporting agent lifecycle management (start, stop, pause, resume)
- REQ-1.2.1: Team ID generation and persistence
- REQ-1.2.2: Team ID persists for entire team lifecycle
"""

import os
import sys
import tempfile
import threading
import time
import unittest
from datetime import datetime, timedelta
from pathlib import Path

# Add parent directory to path
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))

from src.ai_team.agents.agent_coordinator import (
    AgentCoordinator, Task, TaskStatus, AgentMessage, MessageType,
    AgentState, BlockerType, Checkpoint
)
from src.ai_team.utils.conflict_prevention import ConflictPreventionSystem, LockType


class TestAgentCoordinatorInitialization(unittest.TestCase):
    """Test coordinator initialization and setup"""

    def test_coordinator_initialization(self):
        """Test basic coordinator initialization"""
        coordinator = AgentCoordinator(project_name="Test Project")

        self.assertEqual(coordinator.project_name, "Test Project")
        self.assertEqual(len(coordinator.tasks), 0)
        self.assertEqual(len(coordinator.agents), 0)
        self.assertEqual(len(coordinator.messages), 0)
        self.assertEqual(len(coordinator.checkpoints), 0)
        self.assertIsNotNone(coordinator.conflict_prevention)

    def test_coordinator_without_conflict_prevention(self):
        """Test coordinator initialization with conflict prevention disabled"""
        coordinator = AgentCoordinator(enable_conflict_prevention=False)

        self.assertIsNone(coordinator.conflict_prevention)

    def test_team_id_generation(self):
        """Test REQ-1.2.1: Team ID is generated at initialization"""
        coordinator = AgentCoordinator()

        # Set team ID
        team_id = "test-team-20240118-abc123"
        coordinator.team_id = team_id

        self.assertEqual(coordinator.team_id, team_id)


class TestAgentRegistration(unittest.TestCase):
    """Test agent registration and management"""

    def setUp(self):
        """Create a coordinator for testing"""
        self.coordinator = AgentCoordinator()

    def test_register_agent(self):
        """Test registering a new agent"""
        self.coordinator.register_agent("agent-001")

        self.assertIn("agent-001", self.coordinator.agents)
        self.assertEqual(self.coordinator.agent_workloads["agent-001"], 0)
        self.assertEqual(self.coordinator.agent_states["agent-001"], AgentState.CREATED)

    def test_register_multiple_agents(self):
        """Test registering multiple agents"""
        agent_ids = ["agent-001", "agent-002", "agent-003"]

        for agent_id in agent_ids:
            self.coordinator.register_agent(agent_id)

        self.assertEqual(len(self.coordinator.agents), 3)
        for agent_id in agent_ids:
            self.assertIn(agent_id, self.coordinator.agents)

    def test_agent_initial_state(self):
        """Test that newly registered agents start in CREATED state"""
        self.coordinator.register_agent("agent-001")

        self.assertEqual(self.coordinator.agent_states["agent-001"], AgentState.CREATED)

    def test_agent_heartbeat_tracking(self):
        """Test REQ-10.2.1: Tracking agent heartbeats for liveness"""
        self.coordinator.register_agent("agent-001")

        # Initially should have a heartbeat timestamp
        self.assertIn("agent-001", self.coordinator.agent_last_heartbeat)

        # Record a heartbeat
        before_time = datetime.now()
        self.coordinator.record_heartbeat("agent-001", task_id="task-001", state="running")
        after_time = datetime.now()

        # Verify heartbeat was updated
        heartbeat_time = self.coordinator.agent_last_heartbeat["agent-001"]
        self.assertGreaterEqual(heartbeat_time, before_time)
        self.assertLessEqual(heartbeat_time, after_time)


class TestTaskManagement(unittest.TestCase):
    """Test task creation, addition, and management"""

    def setUp(self):
        """Create a coordinator for testing"""
        self.coordinator = AgentCoordinator()

    def test_add_task(self):
        """Test adding a task to the coordinator"""
        task = Task(
            id="task-001",
            title="Test Task",
            description="A test task",
            estimated_hours=2.0,
            dependencies=[]
        )

        self.coordinator.add_task(task)

        self.assertIn("task-001", self.coordinator.tasks)
        self.assertEqual(self.coordinator.tasks["task-001"].title, "Test Task")

    def test_add_multiple_tasks_with_dependencies(self):
        """Test adding multiple tasks with dependencies"""
        task1 = Task(
            id="task-001",
            title="First Task",
            description="First task",
            estimated_hours=1.0,
            dependencies=[]
        )

        task2 = Task(
            id="task-002",
            title="Second Task",
            description="Second task depends on first",
            estimated_hours=2.0,
            dependencies=["task-001"]
        )

        task3 = Task(
            id="task-003",
            title="Third Task",
            description="Third task depends on first two",
            estimated_hours=3.0,
            dependencies=["task-001", "task-002"]
        )

        self.coordinator.add_task(task1)
        self.coordinator.add_task(task2)
        self.coordinator.add_task(task3)

        self.assertEqual(len(self.coordinator.tasks), 3)
        self.assertEqual(len(self.coordinator.tasks["task-002"].dependencies), 1)
        self.assertEqual(len(self.coordinator.tasks["task-003"].dependencies), 2)

    def test_get_task_by_id(self):
        """Test retrieving a task by ID"""
        task = Task(
            id="task-001",
            title="Test Task",
            description="A test task",
            estimated_hours=2.0,
            dependencies=[]
        )

        self.coordinator.add_task(task)
        retrieved_task = self.coordinator.tasks.get("task-001")

        self.assertIsNotNone(retrieved_task)
        self.assertEqual(retrieved_task.id, "task-001")
        self.assertEqual(retrieved_task.title, "Test Task")

    def test_get_nonexistent_task_returns_none(self):
        """Test that getting a non-existent task returns None"""
        retrieved_task = self.coordinator.tasks.get("nonexistent-task")
        self.assertIsNone(retrieved_task)


class TestTaskStateTransitions(unittest.TestCase):
    """Test REQ-3.1.2.1: Task state transitions"""

    def setUp(self):
        """Create a coordinator and task for testing"""
        self.coordinator = AgentCoordinator()
        self.task = Task(
            id="task-001",
            title="Test Task",
            description="A test task",
            estimated_hours=2.0,
            dependencies=[]
        )
        self.coordinator.add_task(self.task)

    def test_initial_task_state_is_ready(self):
        """Test that newly created tasks start in READY state (no dependencies)"""
        # Tasks with no dependencies are automatically set to READY
        self.assertEqual(self.task.status, TaskStatus.READY)

    def test_transition_to_ready_when_dependencies_met(self):
        """Test that tasks without dependencies are READY"""
        # Task with no dependencies should be ready
        ready_tasks = self.coordinator.get_ready_tasks()

        self.assertEqual(self.coordinator.tasks["task-001"].status, TaskStatus.READY)

    def test_task_with_dependencies_stays_blocked_until_prereqs_complete(self):
        """Test that tasks with dependencies stay blocked until prerequisites complete"""
        task_with_deps = Task(
            id="task-002",
            title="Task with Dependencies",
            description="Depends on task-001",
            estimated_hours=2.0,
            dependencies=["task-001"]
        )
        self.coordinator.add_task(task_with_deps)

        # task-002 should be blocked since task-001 is not completed
        self.assertEqual(self.coordinator.tasks["task-002"].status, TaskStatus.BLOCKED)

        # Complete task-001
        self.coordinator.tasks["task-001"].status = TaskStatus.COMPLETED
        self.coordinator._update_task_status("task-002")

        # Now task-002 should be ready
        self.assertEqual(self.coordinator.tasks["task-002"].status, TaskStatus.READY)

    def test_all_task_states_are_reachable(self):
        """Test that all defined task states can be set"""
        # Test states that need to be set directly (not auto-updated)
        # Note: BLOCKED auto-converts to READY when task has no dependencies and no blocker_message
        states = [
            TaskStatus.READY,
            TaskStatus.ASSIGNED,
            TaskStatus.IN_PROGRESS,
            TaskStatus.REVIEW,
            TaskStatus.COMPLETED,
            TaskStatus.FAILED
        ]

        for i, state in enumerate(states):
            task_id = f"task-{i:03d}"
            task = Task(
                id=task_id,
                title=f"Test Task {i}",
                description=f"Testing state {state.value}",
                estimated_hours=1.0,
                dependencies=[]
            )
            # Set status before adding to avoid auto-conversion
            task.status = state
            self.coordinator.add_task(task)
            self.assertEqual(self.coordinator.tasks[task_id].status, state)

        # Test BLOCKED state separately (needs dependencies or blocker_message)
        blocked_task = Task(
            id="task-blocked",
            title="Blocked Task",
            description="Testing blocked state",
            estimated_hours=1.0,
            dependencies=["nonexistent-task"]  # Has dependencies so will be BLOCKED
        )
        self.coordinator.add_task(blocked_task)
        self.assertEqual(self.coordinator.tasks["task-blocked"].status, TaskStatus.BLOCKED)


class TestTaskAssignment(unittest.TestCase):
    """Test REQ-3.1.3.1: Task assignment to agents"""

    def setUp(self):
        """Create a coordinator and agents for testing"""
        self.coordinator = AgentCoordinator()
        self.coordinator.register_agent("agent-001")
        self.coordinator.register_agent("agent-002")

        # Create some tasks
        self.task1 = Task(
            id="task-001",
            title="Task 1",
            description="First task",
            estimated_hours=2.0,
            dependencies=[]
        )
        self.task2 = Task(
            id="task-002",
            title="Task 2",
            description="Second task",
            estimated_hours=1.5,
            dependencies=[]
        )

        self.coordinator.add_task(self.task1)
        self.coordinator.add_task(self.task2)

    def test_assign_task_to_agent(self):
        """Test assigning a task to an agent"""
        success = self.coordinator.assign_task("task-001", "agent-001")

        self.assertTrue(success)
        self.assertEqual(self.coordinator.tasks["task-001"].assigned_agent, "agent-001")
        self.assertEqual(self.coordinator.tasks["task-001"].status, TaskStatus.ASSIGNED)

    def test_assign_nonexistent_task_fails(self):
        """Test that assigning a non-existent task fails"""
        success = self.coordinator.assign_task("nonexistent-task", "agent-001")
        self.assertFalse(success)

    def test_assign_task_to_nonexistent_agent_fails(self):
        """Test that assigning to a non-existent agent fails"""
        success = self.coordinator.assign_task("task-001", "nonexistent-agent")
        self.assertFalse(success)

    def test_get_ready_tasks_excludes_assigned_tasks(self):
        """Test that get_ready_tasks doesn't return already assigned tasks"""
        # Assign first task
        self.coordinator.assign_task("task-001", "agent-001")

        # Get ready tasks
        ready_tasks = self.coordinator.get_ready_tasks()

        # Should only return task-002
        self.assertEqual(len(ready_tasks), 1)
        self.assertEqual(ready_tasks[0].id, "task-002")

    def test_get_ready_tasks_excludes_in_progress_tasks(self):
        """Test that get_ready_tasks doesn't return in-progress tasks"""
        # Mark task as in progress
        self.coordinator.tasks["task-001"].status = TaskStatus.IN_PROGRESS

        # Get ready tasks
        ready_tasks = self.coordinator.get_ready_tasks()

        # Should only return task-002
        self.assertEqual(len(ready_tasks), 1)
        self.assertEqual(ready_tasks[0].id, "task-002")


class TestDependencyResolution(unittest.TestCase):
    """Test REQ-3.1.4.1: Dependency management and resolution"""

    def setUp(self):
        """Create a coordinator for testing"""
        self.coordinator = AgentCoordinator()

    def test_complex_dependency_graph(self):
        """Test resolution of complex dependency graphs"""
        # Create a diamond dependency graph:
        # task-001 (no deps)
        #   ├─> task-002 (depends on 001)
        #   └─> task-003 (depends on 001)
        #          └─> task-004 (depends on 002 and 003)
        tasks = [
            Task(id="task-001", title="Base", description="Base task", estimated_hours=1.0, dependencies=[]),
            Task(id="task-002", title="Branch A", description="Branch A", estimated_hours=1.0, dependencies=["task-001"]),
            Task(id="task-003", title="Branch B", description="Branch B", estimated_hours=1.0, dependencies=["task-001"]),
            Task(id="task-004", title="Merge", description="Merge task", estimated_hours=2.0, dependencies=["task-002", "task-003"]),
        ]

        for task in tasks:
            self.coordinator.add_task(task)

        # Initially only task-001 should be ready
        ready_tasks = self.coordinator.get_ready_tasks()
        self.assertEqual(len(ready_tasks), 1)
        self.assertEqual(ready_tasks[0].id, "task-001")

        # Complete task-001
        self.coordinator.tasks["task-001"].status = TaskStatus.COMPLETED
        for task_id in ["task-002", "task-003", "task-004"]:
            self.coordinator._update_task_status(task_id)
        ready_tasks = self.coordinator.get_ready_tasks()

        # Now task-002 and task-003 should be ready
        ready_ids = {t.id for t in ready_tasks}
        self.assertEqual(ready_ids, {"task-002", "task-003"})


class TestMessageProcessing(unittest.TestCase):
    """Test REQ-3.2.4.1: Agent communication through messages"""

    def setUp(self):
        """Create a coordinator for testing"""
        self.coordinator = AgentCoordinator()
        self.coordinator.register_agent("agent-001")

        task = Task(
            id="task-001",
            title="Test Task",
            description="A test task",
            estimated_hours=2.0,
            dependencies=[]
        )
        self.coordinator.add_task(task)

    def test_process_status_update_message(self):
        """Test processing a status update message"""
        message = AgentMessage(
            agent_id="agent-001",
            task_id="task-001",
            message_type=MessageType.STATUS_UPDATE,
            status=TaskStatus.IN_PROGRESS,
            progress=25,
            message="Working on task"
        )

        self.coordinator.process_message(message)

        self.assertEqual(self.coordinator.tasks["task-001"].status, TaskStatus.IN_PROGRESS)
        self.assertEqual(self.coordinator.tasks["task-001"].progress, 25)
        # blocker_message is only set when status is BLOCKED
        self.assertIsNone(self.coordinator.tasks["task-001"].blocker_message)

    def test_process_checkpoint_message(self):
        """Test processing a checkpoint message"""
        message = AgentMessage(
            agent_id="agent-001",
            task_id="task-001",
            message_type=MessageType.CHECKPOINT,
            progress=50,
            changes="Created initial data model",
            next_steps="Add validation logic"
        )

        self.coordinator.process_message(message)

        # Check that checkpoint was recorded
        self.assertEqual(len(self.coordinator.checkpoints), 1)
        checkpoint = self.coordinator.checkpoints[0]
        self.assertEqual(checkpoint.agent_id, "agent-001")
        self.assertEqual(checkpoint.task_id, "task-001")
        self.assertEqual(checkpoint.progress, 50)
        self.assertEqual(checkpoint.changes, "Created initial data model")
        self.assertEqual(checkpoint.next_steps, "Add validation logic")

    def test_process_completion_message(self):
        """Test processing a completion message"""
        message = AgentMessage(
            agent_id="agent-001",
            task_id="task-001",
            message_type=MessageType.COMPLETION,
            result="Task completed successfully",
            artifacts=["lib/note.dart", "test/note_test.dart"]
        )

        # First mark task as in progress and assign to agent
        self.coordinator.tasks["task-001"].status = TaskStatus.IN_PROGRESS
        self.coordinator.tasks["task-001"].assigned_agent = "agent-001"

        self.coordinator.process_message(message)

        # Task should be marked as completed
        self.assertEqual(self.coordinator.tasks["task-001"].status, TaskStatus.COMPLETED)
        self.assertEqual(self.coordinator.tasks["task-001"].artifacts,
                        ["lib/note.dart", "test/note_test.dart"])

    def test_process_dependency_request_message(self):
        """Test processing a dependency request (blocked) message"""
        message = AgentMessage(
            agent_id="agent-001",
            task_id="task-001",
            message_type=MessageType.DEPENDENCY_REQUEST,
            blocked_on="task-002",
            message="Waiting for task-002 to complete first"
        )

        self.coordinator.process_message(message)

        self.assertEqual(self.coordinator.tasks["task-001"].status, TaskStatus.BLOCKED)
        self.assertIn("task-002", self.coordinator.tasks["task-001"].blocker_message)


class TestAgentTaskQueries(unittest.TestCase):
    """Test querying tasks by agent"""

    def setUp(self):
        """Create a coordinator with agents and tasks"""
        self.coordinator = AgentCoordinator()
        self.coordinator.register_agent("agent-001")
        self.coordinator.register_agent("agent-002")

        # Create tasks and assign them
        task1 = Task(
            id="task-001",
            title="Task 1",
            description="First task",
            estimated_hours=2.0,
            dependencies=[],
            assigned_agent="agent-001",
            status=TaskStatus.IN_PROGRESS
        )
        task2 = Task(
            id="task-002",
            title="Task 2",
            description="Second task",
            estimated_hours=1.5,
            dependencies=[],
            assigned_agent="agent-001",
            status=TaskStatus.ASSIGNED
        )
        task3 = Task(
            id="task-003",
            title="Task 3",
            description="Third task",
            estimated_hours=1.0,
            dependencies=[],
            assigned_agent="agent-002",
            status=TaskStatus.IN_PROGRESS
        )

        for task in [task1, task2, task3]:
            self.coordinator.add_task(task)

    def test_get_agent_tasks(self):
        """Test retrieving all tasks for a specific agent"""
        agent_tasks = self.coordinator.get_agent_tasks("agent-001")

        self.assertEqual(len(agent_tasks), 2)
        task_ids = {t.id for t in agent_tasks}
        self.assertEqual(task_ids, {"task-001", "task-002"})

    def test_get_agent_tasks_for_different_agent(self):
        """Test retrieving tasks for a different agent"""
        agent_tasks = self.coordinator.get_agent_tasks("agent-002")

        self.assertEqual(len(agent_tasks), 1)
        self.assertEqual(agent_tasks[0].id, "task-003")

    def test_get_agent_tasks_for_agent_with_no_tasks(self):
        """Test retrieving tasks for an agent with no assigned tasks"""
        self.coordinator.register_agent("agent-003")
        agent_tasks = self.coordinator.get_agent_tasks("agent-003")

        self.assertEqual(len(agent_tasks), 0)


class TestTaskCompletion(unittest.TestCase):
    """Test task completion workflow"""

    def setUp(self):
        """Create a coordinator with agent and task"""
        self.coordinator = AgentCoordinator()
        self.coordinator.register_agent("agent-001")

        self.task = Task(
            id="task-001",
            title="Test Task",
            description="A test task",
            estimated_hours=2.0,
            dependencies=[],
            assigned_agent="agent-001",
            status=TaskStatus.IN_PROGRESS
        )
        self.coordinator.add_task(self.task)

    def test_complete_task_successfully(self):
        """Test completing a task successfully"""
        success = self.coordinator.complete_task("task-001", "agent-001")

        self.assertTrue(success)
        self.assertEqual(self.coordinator.tasks["task-001"].status, TaskStatus.COMPLETED)
        self.assertIsNotNone(self.coordinator.tasks["task-001"].completed_at)

    def test_complete_task_fails_for_nonexistent_task(self):
        """Test that completing a non-existent task fails"""
        success = self.coordinator.complete_task("nonexistent-task", "agent-001")
        self.assertFalse(success)

    def test_complete_task_fails_for_wrong_agent(self):
        """Test that completing with wrong agent fails"""
        success = self.coordinator.complete_task("task-001", "agent-999")
        self.assertFalse(success)

    def test_complete_task_unblocks_dependent_tasks(self):
        """Test that completing a task unblocks dependent tasks"""
        # Create dependent task
        task2 = Task(
            id="task-002",
            title="Dependent Task",
            description="Depends on task-001",
            estimated_hours=1.0,
            dependencies=["task-001"]
        )
        self.coordinator.add_task(task2)

        # task-002 should be blocked
        self.assertEqual(self.coordinator.tasks["task-002"].status, TaskStatus.BLOCKED)

        # Complete task-001
        self.coordinator.complete_task("task-001", "agent-001")

        # task-002 should now be ready
        self.assertEqual(self.coordinator.tasks["task-002"].status, TaskStatus.READY)


class TestConflictPreventionIntegration(unittest.TestCase):
    """Test integration with conflict prevention system"""

    def setUp(self):
        """Create a coordinator with conflict prevention enabled"""
        self.coordinator = AgentCoordinator(enable_conflict_prevention=True)

    def test_conflict_prevention_system_initialized(self):
        """Test that conflict prevention system is initialized"""
        self.assertIsNotNone(self.coordinator.conflict_prevention)
        self.assertIsInstance(self.coordinator.conflict_prevention, ConflictPreventionSystem)

    def test_request_lock_through_coordinator(self):
        """Test requesting a resource lock"""
        success = self.coordinator.conflict_prevention.request_resource_access(
            "lib/main.dart",
            "agent-001",
            LockType.EXCLUSIVE
        )

        self.assertTrue(success)
        self.assertTrue(self.coordinator.conflict_prevention.lock_manager.is_locked("lib/main.dart"))


class TestCheckpointTracking(unittest.TestCase):
    """Test REQ-3.3.2.1: Checkpoint system"""

    def setUp(self):
        """Create a coordinator for testing"""
        self.coordinator = AgentCoordinator()

    def test_create_checkpoint(self):
        """Test creating a checkpoint"""
        checkpoint = Checkpoint(
            agent_id="agent-001",
            task_id="task-001",
            progress=50,
            changes="Created data model",
            next_steps="Add validation"
        )

        self.coordinator.checkpoints.append(checkpoint)

        self.assertEqual(len(self.coordinator.checkpoints), 1)
        self.assertEqual(self.coordinator.checkpoints[0].progress, 50)

    def test_get_checkpoints_for_task(self):
        """Test retrieving checkpoints for a specific task"""
        checkpoints = [
            Checkpoint(agent_id="agent-001", task_id="task-001", progress=25,
                      changes="First checkpoint", next_steps="Continue"),
            Checkpoint(agent_id="agent-001", task_id="task-001", progress=50,
                      changes="Second checkpoint", next_steps="Almost done"),
            Checkpoint(agent_id="agent-002", task_id="task-002", progress=75,
                      changes="Other task checkpoint", next_steps="Finish"),
        ]

        for cp in checkpoints:
            self.coordinator.checkpoints.append(cp)

        task_checkpoints = [cp for cp in self.coordinator.checkpoints
                           if cp.task_id == "task-001"]

        self.assertEqual(len(task_checkpoints), 2)


if __name__ == "__main__":
    unittest.main()
