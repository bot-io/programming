"""
Integration Tests for Coordinator-Agent Interactions

Tests the integration between the AgentCoordinator and Agent classes:
- Agent registration and lifecycle
- Task assignment workflows
- Message processing and state updates
- REQ-3.2.4.1: Communication protocol (status updates, checkpoints, completions)
- REQ-3.3.3.1: Work session protocols
- REQ-3.2.3.1: Agent control (start, stop, pause, resume)
- REQ-11.2.4: Team ID propagation across components
"""

import os
import sys
import tempfile
import threading
import time
import unittest
from datetime import datetime
from unittest.mock import Mock, MagicMock

# Add parent directory to path
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))

from src.ai_team.agents.agent_coordinator import (
    AgentCoordinator, Task, TaskStatus, AgentState, AgentMessage, MessageType
)
from src.ai_team.utils.progress_tracker import DetailedProgressTracker
from src.ai_team.utils.progress_persistence import ProgressPersistence


class MockAgent:
    """A mock agent for testing coordinator interactions"""

    def __init__(self, agent_id: str, coordinator: AgentCoordinator, specialization: str = ""):
        self.agent_id = agent_id
        self.coordinator = coordinator
        self.specialization = specialization
        self.current_task = None
        self.state = AgentState.CREATED
        self.locked_resources = set()
        self.workspace_path = None

        # Register with coordinator
        self.coordinator.register_agent_instance(self)

    def start(self):
        """Start the agent"""
        self.state = AgentState.RUNNING
        self.coordinator.agent_states[self.agent_id] = AgentState.RUNNING

    def stop(self):
        """Stop the agent"""
        self.state = AgentState.STOPPED
        self.coordinator.agent_states[self.agent_id] = AgentState.STOPPED

    def pause(self):
        """Pause the agent"""
        self.state = AgentState.PAUSED
        self.coordinator.agent_states[self.agent_id] = AgentState.PAUSED

    def resume(self):
        """Resume the agent"""
        self.state = AgentState.RUNNING
        self.coordinator.agent_states[self.agent_id] = AgentState.RUNNING

    def request_task(self) -> Task:
        """Request a task from coordinator"""
        ready_tasks = self.coordinator.get_ready_tasks()
        if not ready_tasks:
            return None

        task = ready_tasks[0]
        if self.coordinator.assign_task(task.id, self.agent_id):
            self.current_task = task
            return task
        return None

    def send_status_update(self, task_id: str, status: TaskStatus,
                          progress: int = None, message: str = None):
        """Send a status update to coordinator"""
        msg = AgentMessage(
            agent_id=self.agent_id,
            task_id=task_id,
            message_type=MessageType.STATUS_UPDATE,
            status=status,
            progress=progress,
            message=message
        )
        self.coordinator.process_message(msg)

    def send_checkpoint(self, task_id: str, progress: int, changes: str, next_steps: str):
        """Send a checkpoint to coordinator"""
        msg = AgentMessage(
            agent_id=self.agent_id,
            task_id=task_id,
            message_type=MessageType.CHECKPOINT,
            progress=progress,
            changes=changes,
            next_steps=next_steps
        )
        self.coordinator.process_message(msg)

    def complete_task(self, task_id: str, result: str, artifacts: list = None):
        """Complete a task"""
        msg = AgentMessage(
            agent_id=self.agent_id,
            task_id=task_id,
            message_type=MessageType.COMPLETION,
            result=result,
            artifacts=artifacts or []
        )
        self.coordinator.process_message(msg)
        self.coordinator.complete_task(task_id, self.agent_id)
        self.current_task = None

    def report_blocked(self, task_id: str, blocked_on: str, message: str):
        """Report that task is blocked"""
        msg = AgentMessage(
            agent_id=self.agent_id,
            task_id=task_id,
            message_type=MessageType.DEPENDENCY_REQUEST,
            blocked_on=blocked_on,
            message=message
        )
        self.coordinator.process_message(msg)


class TestAgentRegistrationAndLifecycle(unittest.TestCase):
    """Test agent registration and lifecycle management"""

    def setUp(self):
        """Create a coordinator for testing"""
        self.coordinator = AgentCoordinator(project_name="Test Project")
        self.coordinator.team_id = "test-team-lifecycle-20240118"

    def test_agent_registration_through_coordinator(self):
        """Test that agents can register with coordinator"""
        agent = MockAgent("agent-001", self.coordinator)

        self.assertIn("agent-001", self.coordinator.agents)
        self.assertIn("agent-001", self.coordinator.agent_instances)
        self.assertEqual(self.coordinator.agent_states["agent-001"], AgentState.CREATED)

    def test_multiple_agent_registration(self):
        """Test registering multiple agents"""
        agents = []
        for i in range(3):
            agent = MockAgent(f"agent-{i:03d}", self.coordinator, specialization="developer")
            agents.append(agent)

        self.assertEqual(len(self.coordinator.agents), 3)
        self.assertEqual(len(self.coordinator.agent_instances), 3)

    def test_agent_start_changes_state(self):
        """Test that starting an agent updates its state"""
        agent = MockAgent("agent-001", self.coordinator)
        agent.start()

        self.assertEqual(agent.state, AgentState.RUNNING)
        self.assertEqual(self.coordinator.agent_states["agent-001"], AgentState.RUNNING)

    def test_agent_pause_changes_state(self):
        """Test that pausing an agent updates its state"""
        agent = MockAgent("agent-001", self.coordinator)
        agent.start()
        agent.pause()

        self.assertEqual(agent.state, AgentState.PAUSED)
        self.assertEqual(self.coordinator.agent_states["agent-001"], AgentState.PAUSED)

    def test_agent_resume_changes_state(self):
        """Test that resuming an agent updates its state"""
        agent = MockAgent("agent-001", self.coordinator)
        agent.start()
        agent.pause()
        agent.resume()

        self.assertEqual(agent.state, AgentState.RUNNING)
        self.assertEqual(self.coordinator.agent_states["agent-001"], AgentState.RUNNING)

    def test_agent_stop_changes_state(self):
        """Test that stopping an agent updates its state"""
        agent = MockAgent("agent-001", self.coordinator)
        agent.start()
        agent.stop()

        self.assertEqual(agent.state, AgentState.STOPPED)
        self.assertEqual(self.coordinator.agent_states["agent-001"], AgentState.STOPPED)


class TestTaskAssignmentIntegration(unittest.TestCase):
    """Test task assignment workflows"""

    def setUp(self):
        """Create a coordinator and agent for testing"""
        self.coordinator = AgentCoordinator(project_name="Test Project")
        self.agent = MockAgent("agent-001", self.coordinator, specialization="developer")

        # Create some tasks
        for i in range(3):
            task = Task(
                id=f"task-{i:03d}",
                title=f"Task {i}",
                description=f"Test task {i}",
                estimated_hours=1.0,
                dependencies=[]
            )
            self.coordinator.add_task(task)

    def test_agent_can_request_task(self):
        """Test that an agent can request and be assigned a task"""
        task = self.agent.request_task()

        self.assertIsNotNone(task)
        self.assertEqual(task.assigned_agent, "agent-001")
        self.assertEqual(task.status, TaskStatus.ASSIGNED)
        self.assertEqual(self.agent.current_task, task)

    def test_assigned_task_not_available_to_others(self):
        """Test that assigned tasks are not available to other agents"""
        agent1 = MockAgent("agent-001", self.coordinator)
        agent2 = MockAgent("agent-002", self.coordinator)

        # Agent 1 requests a task
        task1 = agent1.request_task()
        self.assertIsNotNone(task1)

        # Agent 2 requests a task
        task2 = agent2.request_task()
        self.assertIsNotNone(task2)

        # They should have different tasks
        self.assertNotEqual(task1.id, task2.id)

    def test_tasks_with_dependencies_not_available_until_prereqs_complete(self):
        """Test that tasks with dependencies wait for prerequisites"""
        # Clear existing tasks first
        self.coordinator.tasks.clear()

        # Create dependent tasks
        task1 = Task(
            id="task-001",
            title="Base Task",
            description="First task",
            estimated_hours=1.0,
            dependencies=[]
        )
        task2 = Task(
            id="task-002",
            title="Dependent Task",
            description="Depends on task-001",
            estimated_hours=1.0,
            dependencies=["task-001"]
        )

        self.coordinator.add_task(task1)
        self.coordinator.add_task(task2)

        # Agent should only get task-001 (task-002 is blocked)
        task = self.agent.request_task()

        self.assertEqual(task.id, "task-001")


class TestMessageProcessingIntegration(unittest.TestCase):
    """Test REQ-3.2.4.1: Communication protocol"""

    def setUp(self):
        """Create a coordinator and agent for testing"""
        self.coordinator = AgentCoordinator(project_name="Test Project")
        self.agent = MockAgent("agent-001", self.coordinator)

        task = Task(
            id="task-001",
            title="Test Task",
            description="A test task",
            estimated_hours=2.0,
            dependencies=[]
        )
        self.coordinator.add_task(task)
        self.agent.request_task()

    def test_status_update_message_changes_task_status(self):
        """Test that status update messages update task status"""
        self.agent.send_status_update("task-001", TaskStatus.IN_PROGRESS, progress=10)

        self.assertEqual(self.coordinator.tasks["task-001"].status, TaskStatus.IN_PROGRESS)
        self.assertEqual(self.coordinator.tasks["task-001"].progress, 10)

    def test_checkpoint_message_is_recorded(self):
        """Test that checkpoint messages are recorded"""
        self.agent.send_checkpoint(
            task_id="task-001",
            progress=25,
            changes="Created data model",
            next_steps="Add validation logic"
        )

        # Check that checkpoint was recorded
        self.assertEqual(len(self.coordinator.checkpoints), 1)
        checkpoint = self.coordinator.checkpoints[0]
        self.assertEqual(checkpoint.agent_id, "agent-001")
        self.assertEqual(checkpoint.task_id, "task-001")
        self.assertEqual(checkpoint.progress, 25)
        self.assertEqual(checkpoint.changes, "Created data model")

    def test_completion_message_completes_task(self):
        """Test that completion messages complete the task"""
        # Mark task as in progress first
        self.coordinator.tasks["task-001"].status = TaskStatus.IN_PROGRESS

        self.agent.complete_task(
            task_id="task-001",
            result="Task completed successfully",
            artifacts=["lib/note.dart", "test/note_test.dart"]
        )

        self.assertEqual(self.coordinator.tasks["task-001"].status, TaskStatus.COMPLETED)
        self.assertEqual(self.coordinator.tasks["task-001"].artifacts,
                        ["lib/note.dart", "test/note_test.dart"])
        self.assertIsNotNone(self.coordinator.tasks["task-001"].completed_at)

    def test_blocked_message_sets_task_to_blocked(self):
        """Test that blocked messages set task to blocked status"""
        self.agent.send_status_update(
            task_id="task-001",
            status=TaskStatus.BLOCKED,
            message="Waiting for dependency"
        )

        self.assertEqual(self.coordinator.tasks["task-001"].status, TaskStatus.BLOCKED)
        self.assertIn("dependency", self.coordinator.tasks["task-001"].blocker_message.lower())


class TestWorkSessionProtocol(unittest.TestCase):
    """Test REQ-3.3.3.1: Work session protocols"""

    def setUp(self):
        """Create a coordinator and agent for testing"""
        self.coordinator = AgentCoordinator(project_name="Test Project")
        self.agent = MockAgent("agent-001", self.coordinator)

        task = Task(
            id="task-001",
            title="Test Task",
            description="A test task with acceptance criteria",
            estimated_hours=2.0,
            dependencies=[],
            acceptance_criteria=["File exists", "Tests pass"]
        )
        self.coordinator.add_task(task)

    def test_work_session_reviews_task_requirements(self):
        """Test that agent reviews task requirements during work session"""
        task = self.agent.request_task()
        self.assertIsNotNone(task)
        self.assertIsNotNone(task.title)
        self.assertIsNotNone(task.description)
        self.assertEqual(len(task.acceptance_criteria), 2)

    def test_work_session_creates_checkpoints(self):
        """Test that work session includes checkpoints"""
        task = self.agent.request_task()

        # Simulate work with checkpoints
        checkpoints = [
            (10, "Initial setup", "Create model"),
            (50, "Model created", "Add service"),
            (90, "Service created", "Write tests"),
        ]

        for progress, changes, next_steps in checkpoints:
            self.agent.send_checkpoint("task-001", progress, changes, next_steps)

        self.assertEqual(len(self.coordinator.checkpoints), 3)

    def test_work_session_releases_resources_on_completion(self):
        """Test that work session releases resources on completion"""
        # Simulate acquiring locks (in real scenario)
        self.agent.locked_resources.add("lib/note.dart")
        self.agent.locked_resources.add("lib/category.dart")

        # Complete task
        self.agent.complete_task("task-001", "Done", ["lib/note.dart"])

        # In real scenario, locks would be released
        # For mock agent, we check current_task is cleared
        self.assertIsNone(self.agent.current_task)


class TestTaskStateTransitionsIntegration(unittest.TestCase):
    """Test complete task state transition workflows"""

    def setUp(self):
        """Create a coordinator and agents for testing"""
        self.coordinator = AgentCoordinator(project_name="Test Project")
        self.coordinator.team_id = "test-team-transitions-20240118"

    def test_full_task_lifecycle(self):
        """Test complete lifecycle: PENDING -> READY -> ASSIGNED -> IN_PROGRESS -> COMPLETED"""
        agent = MockAgent("agent-001", self.coordinator)

        # Create task
        task = Task(
            id="task-001",
            title="Full Lifecycle Task",
            description="Testing full lifecycle",
            estimated_hours=2.0,
            dependencies=[]
        )
        self.coordinator.add_task(task)

        # Tasks with no dependencies auto-become READY
        self.assertEqual(task.status, TaskStatus.READY)

        # Agent requests task (becomes ASSIGNED)
        agent.request_task()
        self.assertEqual(task.status, TaskStatus.ASSIGNED)

        # Agent starts work (becomes IN_PROGRESS)
        agent.send_status_update("task-001", TaskStatus.IN_PROGRESS, progress=0)
        self.assertEqual(task.status, TaskStatus.IN_PROGRESS)

        # Agent completes task
        agent.complete_task("task-001", "Completed", ["artifact.dart"])
        self.assertEqual(task.status, TaskStatus.COMPLETED)

    def test_task_blocked_then_unblocked(self):
        """Test task getting blocked and then unblocked"""
        agent = MockAgent("agent-001", self.coordinator)

        # Create two dependent tasks
        task1 = Task(
            id="task-001",
            title="Prerequisite",
            description="First task",
            estimated_hours=1.0,
            dependencies=[]
        )
        task2 = Task(
            id="task-002",
            title="Dependent",
            description="Depends on first",
            estimated_hours=1.0,
            dependencies=["task-001"]
        )

        self.coordinator.add_task(task1)
        self.coordinator.add_task(task2)

        # task-002 should be BLOCKED (waiting on task-001)
        self.assertEqual(task2.status, TaskStatus.BLOCKED)

        # Complete task-001
        self.coordinator.assign_task("task-001", "agent-001")
        self.coordinator.tasks["task-001"].status = TaskStatus.IN_PROGRESS
        self.coordinator.complete_task("task-001", "agent-001")

        # Update task-002 status - should now be READY
        self.coordinator._update_task_status("task-002")
        self.assertEqual(task2.status, TaskStatus.READY)

    def test_task_failed_and_retried(self):
        """Test task failing and being retried"""
        agent = MockAgent("agent-001", self.coordinator)

        task = Task(
            id="task-001",
            title="Failing Task",
            description="This task will fail",
            estimated_hours=1.0,
            dependencies=[]
        )
        self.coordinator.add_task(task)

        agent.request_task()
        agent.send_status_update("task-001", TaskStatus.IN_PROGRESS)

        # Task fails
        agent.send_status_update("task-001", TaskStatus.FAILED, message="Build error")

        self.assertEqual(task.status, TaskStatus.FAILED)

        # For retry, task needs to be reset to READY and reassigned
        # This simulates supervisor resetting the task
        task.status = TaskStatus.READY
        task.assigned_agent = None
        task.progress = 0

        # Can be retried - agent requests again
        agent2 = MockAgent("agent-002", self.coordinator)
        task2 = agent2.request_task()

        self.assertIsNotNone(task2)
        self.assertEqual(task2.id, "task-001")


class TestProgressTrackingIntegration(unittest.TestCase):
    """Test progress tracking across coordinator and agents"""

    def setUp(self):
        """Create coordinator, tracker, and agent"""
        self.coordinator = AgentCoordinator(project_name="Test Project")
        self.coordinator.team_id = "test-team-progress-20240118"
        self.tracker = DetailedProgressTracker(self.coordinator)
        self.agent = MockAgent("agent-001", self.coordinator)

    def test_progress_tracker_sees_agent_activity(self):
        """Test that progress tracker can see agent activity"""
        self.coordinator.register_agent("agent-001")

        activity = self.tracker.get_agent_activity("agent-001")

        self.assertEqual(activity["agent_id"], "agent-001")
        self.assertIsNotNone(activity)

    def test_progress_tracker_shows_current_task(self):
        """Test that progress tracker shows agent's current task"""
        task = Task(
            id="task-001",
            title="Current Task",
            description="Agent working on this",
            estimated_hours=1.0,
            dependencies=[],
            status=TaskStatus.IN_PROGRESS,
            progress=50,
            assigned_agent="agent-001"
        )
        self.coordinator.add_task(task)

        activity = self.tracker.get_agent_activity("agent-001")

        self.assertIsNotNone(activity["current_task"])
        self.assertEqual(activity["current_task"]["id"], "task-001")
        self.assertEqual(activity["current_task"]["progress"], 50)

    def test_progress_tracker_includes_checkpoints(self):
        """Test that progress tracker includes checkpoints in activity"""
        task = Task(
            id="task-001",
            title="Task with Checkpoints",
            description="Testing checkpoints",
            estimated_hours=1.0,
            dependencies=[],
            assigned_agent="agent-001"
        )
        self.coordinator.add_task(task)
        self.agent.request_task()

        # Add checkpoints
        self.agent.send_checkpoint("task-001", 25, "First step", "Next step")
        self.agent.send_checkpoint("task-001", 50, "Halfway", "Continue")

        activity = self.tracker.get_agent_activity("agent-001")

        self.assertEqual(len(activity["recent_activity"]), 2)


class TestTeamIDPropagation(unittest.TestCase):
    """Test REQ-11.2.4: Team ID propagation across components"""

    def setUp(self):
        """Create coordinator with team ID"""
        self.team_id = "test-team-propagation-20240118"
        self.coordinator = AgentCoordinator(project_name="Test Project")
        self.coordinator.team_id = self.team_id

    def test_coordinator_has_team_id(self):
        """Test that coordinator has team ID"""
        self.assertEqual(self.coordinator.team_id, self.team_id)

    def test_progress_persistence_receives_team_id(self):
        """Test that progress persistence receives team ID"""
        temp_dir = tempfile.mkdtemp()
        try:
            tracker = DetailedProgressTracker(self.coordinator)
            persistence = ProgressPersistence(
                coordinator=self.coordinator,
                tracker=tracker,
                output_dir=os.path.join(temp_dir, "progress"),
                team_id=self.team_id
            )

            self.assertEqual(persistence.team_id, self.team_id)

            # Save progress and verify team ID is in report
            persistence.save_progress()

            with open(persistence.md_file, 'r', encoding='utf-8') as f:
                content = f.read()

            self.assertIn(self.team_id, content)
        finally:
            import shutil
            shutil.rmtree(temp_dir, ignore_errors=True)


if __name__ == "__main__":
    unittest.main()
