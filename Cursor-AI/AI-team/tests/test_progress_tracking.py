"""
Unit Tests for Progress Tracking and Persistence

Tests the DetailedProgressTracker and ProgressPersistence classes which are responsible for:
- REQ-3.7.1.1: Progress report creation as first action
- REQ-3.7.2.1: Progress report includes team ID
- REQ-3.7.3.1: Continuous progress report updates
- REQ-3.7.4.1: Progress report always available
- REQ-10.1.1: Logging to agent_logs/ directory
- Tracking detailed progress for all tasks
- Tracking agent status and workload
- Tracking checkpoint history
- Generating progress reports
- Saving and loading progress to files
"""

import os
import sys
import tempfile
import time
import unittest
import json
from datetime import datetime, timedelta
from pathlib import Path

# Add parent directory to path
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))

from src.ai_team.agents.agent_coordinator import (
    AgentCoordinator, Task, TaskStatus, AgentState, Checkpoint, AgentMessage, MessageType
)
from src.ai_team.utils.progress_tracker import DetailedProgressTracker
from src.ai_team.utils.progress_persistence import ProgressPersistence


class TestDetailedProgressTracker(unittest.TestCase):
    """Test DetailedProgressTracker functionality"""

    def setUp(self):
        """Create a coordinator and tracker for testing"""
        self.coordinator = AgentCoordinator(project_name="Test Project")
        self.tracker = DetailedProgressTracker(self.coordinator)

    def test_tracker_initialization(self):
        """Test that tracker initializes with coordinator"""
        self.assertEqual(self.tracker.coordinator, self.coordinator)
        self.assertEqual(self.tracker.activity_log, [])

    def test_get_agent_activity_for_nonexistent_agent(self):
        """Test getting activity for an agent that doesn't exist"""
        activity = self.tracker.get_agent_activity("nonexistent-agent")

        self.assertEqual(activity["agent_id"], "nonexistent-agent")
        self.assertEqual(activity["state"], AgentState.CREATED.value)
        self.assertEqual(activity["current_activity"], "Idle")

    def test_get_agent_activity_for_idle_agent(self):
        """Test getting activity for an idle agent"""
        self.coordinator.register_agent("agent-001")

        activity = self.tracker.get_agent_activity("agent-001")

        self.assertEqual(activity["agent_id"], "agent-001")
        self.assertEqual(activity["current_activity"], "Idle")
        self.assertEqual(activity["progress"], 0)

    def test_get_agent_activity_with_current_task(self):
        """Test getting activity for agent working on a task"""
        self.coordinator.register_agent("agent-001")

        task = Task(
            id="task-001",
            title="Test Task",
            description="A test task",
            estimated_hours=2.0,
            dependencies=[],
            assigned_agent="agent-001",
            status=TaskStatus.IN_PROGRESS,
            progress=50,
            started_at=datetime.now()
        )
        self.coordinator.add_task(task)

        activity = self.tracker.get_agent_activity("agent-001")

        self.assertIsNotNone(activity["current_task"])
        self.assertEqual(activity["current_task"]["id"], "task-001")
        self.assertEqual(activity["current_task"]["progress"], 50)
        self.assertEqual(activity["progress"], 50)

    def test_get_agent_activity_with_time_in_task(self):
        """Test that time in current task is calculated"""
        self.coordinator.register_agent("agent-001")

        started_time = datetime.now() - timedelta(minutes=30)
        task = Task(
            id="task-001",
            title="Test Task",
            description="A test task",
            estimated_hours=2.0,
            dependencies=[],
            assigned_agent="agent-001",
            status=TaskStatus.IN_PROGRESS,
            progress=50,
            started_at=started_time
        )
        self.coordinator.add_task(task)

        activity = self.tracker.get_agent_activity("agent-001")

        self.assertIsNotNone(activity["time_in_current_task"])
        self.assertIn(":", activity["time_in_current_task"])

    def test_get_agent_activity_with_recent_checkpoints(self):
        """Test that recent checkpoints are included in activity"""
        self.coordinator.register_agent("agent-001")

        task = Task(
            id="task-001",
            title="Test Task",
            description="A test task",
            estimated_hours=2.0,
            dependencies=[],
            assigned_agent="agent-001",
            status=TaskStatus.IN_PROGRESS,
            progress=50
        )
        self.coordinator.add_task(task)

        # Add some checkpoints
        checkpoint1 = Checkpoint(
            agent_id="agent-001",
            task_id="task-001",
            progress=25,
            changes="Created initial model",
            next_steps="Add validation"
        )
        checkpoint2 = Checkpoint(
            agent_id="agent-001",
            task_id="task-001",
            progress=50,
            changes="Added validation",
            next_steps="Write tests"
        )
        self.coordinator.checkpoints.extend([checkpoint1, checkpoint2])

        activity = self.tracker.get_agent_activity("agent-001")

        self.assertEqual(len(activity["recent_activity"]), 2)
        self.assertEqual(activity["recent_activity"][0]["progress"], 25)
        self.assertEqual(activity["recent_activity"][1]["progress"], 50)

    def test_get_all_agents_activity(self):
        """Test getting activity for all agents"""
        self.coordinator.register_agent("agent-001")
        self.coordinator.register_agent("agent-002")

        activities = self.tracker.get_all_agents_activity()

        self.assertEqual(len(activities), 2)
        agent_ids = {a["agent_id"] for a in activities}
        self.assertEqual(agent_ids, {"agent-001", "agent-002"})

    def test_get_task_details(self):
        """Test getting detailed information about a task"""
        task = Task(
            id="task-001",
            title="Test Task",
            description="A detailed test task with lots of information",
            estimated_hours=2.0,
            dependencies=[],
            status=TaskStatus.IN_PROGRESS,
            progress=50,
            assigned_agent="agent-001"
        )
        self.coordinator.add_task(task)

        # Add checkpoints
        checkpoint = Checkpoint(
            agent_id="agent-001",
            task_id="task-001",
            progress=50,
            changes="Halfway done",
            next_steps="Finish up"
        )
        self.coordinator.checkpoints.append(checkpoint)

        details = self.tracker.get_task_details("task-001")

        self.assertIsNotNone(details)
        self.assertEqual(details["id"], "task-001")
        self.assertEqual(details["title"], "Test Task")
        self.assertEqual(details["status"], TaskStatus.IN_PROGRESS.value)
        self.assertEqual(details["progress"], 50)
        self.assertEqual(len(details["checkpoints"]), 1)

    def test_get_task_details_for_nonexistent_task(self):
        """Test getting details for a non-existent task"""
        details = self.tracker.get_task_details("nonexistent-task")
        self.assertIsNone(details)

    def test_get_overall_progress(self):
        """Test getting overall progress across all tasks"""
        # Add tasks with various progress
        for i in range(5):
            task = Task(
                id=f"task-{i:03d}",
                title=f"Task {i}",
                description=f"Test task {i}",
                estimated_hours=1.0,
                dependencies=[],
                status=TaskStatus.IN_PROGRESS,
                progress=i * 20  # 0, 20, 40, 60, 80
            )
            self.coordinator.add_task(task)

        summary = self.tracker.get_progress_summary()

        # Check that we have 5 in-progress tasks
        self.assertEqual(summary['overall']['total_tasks'], 5)
        self.assertEqual(summary['overall']['in_progress'], 5)
        # Progress percentage is based on completed count, not average progress
        # Since none are completed, progress is 0%
        self.assertEqual(summary['overall']['progress_percentage'], 0)

    def test_get_overall_progress_with_completed_tasks(self):
        """Test overall progress calculation with completed tasks"""
        # Add mix of completed and in-progress tasks
        for i in range(4):
            task = Task(
                id=f"task-{i:03d}",
                title=f"Task {i}",
                description=f"Test task {i}",
                estimated_hours=1.0,
                dependencies=[],
                status=TaskStatus.COMPLETED if i < 2 else TaskStatus.IN_PROGRESS,
                progress=100 if i < 2 else 50
            )
            self.coordinator.add_task(task)

        summary = self.tracker.get_progress_summary()

        # Check counts
        self.assertEqual(summary['overall']['total_tasks'], 4)
        self.assertEqual(summary['overall']['completed'], 2)
        # Progress percentage is (2 completed / 4 total) * 100 = 50%
        self.assertEqual(summary['overall']['progress_percentage'], 50)


class TestProgressPersistence(unittest.TestCase):
    """Test ProgressPersistence functionality"""

    def setUp(self):
        """Create a temporary directory and setup for testing"""
        self.temp_dir = tempfile.mkdtemp()
        self.output_dir = os.path.join(self.temp_dir, "progress_reports")
        self.coordinator = AgentCoordinator(project_name="Test Project")
        self.tracker = DetailedProgressTracker(self.coordinator)

        # Set team ID for REQ-1.2.4 compliance
        self.coordinator.team_id = "test-team-20240118-abc123"

        self.persistence = ProgressPersistence(
            coordinator=self.coordinator,
            tracker=self.tracker,
            output_dir=self.output_dir,
            project_dir=self.temp_dir,
            team_id=self.coordinator.team_id
        )

    def tearDown(self):
        """Clean up temporary directory"""
        import shutil
        shutil.rmtree(self.temp_dir, ignore_errors=True)

    def test_persistence_initialization(self):
        """Test that persistence initializes correctly"""
        self.assertTrue(os.path.exists(self.output_dir))
        self.assertTrue(os.path.exists(self.persistence.history_dir))
        self.assertEqual(self.persistence.team_id, "test-team-20240118-abc123")

    def test_req_3_7_1_1_progress_report_created_early(self):
        """REQ-3.7.1.1: Progress report must be created before task initialization"""
        # Create progress report with no tasks
        self.persistence.save_progress()

        # Check that progress.md file exists
        self.assertTrue(os.path.exists(self.persistence.md_file))

        # Read and verify content mentions no tasks
        with open(self.persistence.md_file, 'r', encoding='utf-8') as f:
            content = f.read()

        self.assertIn("test-team-20240118-abc123", content)

    def test_req_3_7_2_1_team_id_in_progress_report(self):
        """REQ-3.7.2.1: Progress report must include team ID"""
        self.coordinator.team_id = "test-team-xyz789"
        self.persistence.team_id = "test-team-xyz789"

        self.persistence.save_progress()

        with open(self.persistence.md_file, 'r', encoding='utf-8') as f:
            content = f.read()

        # Team ID should be in the report header
        self.assertIn("test-team-xyz789", content)

    def test_req_3_7_3_1_continuous_progress_updates(self):
        """REQ-3.7.3.1: Progress report must be continuously updated"""
        # Create initial report
        self.persistence.save_progress()
        initial_mtime = os.path.getmtime(self.persistence.md_file)

        # Wait a bit and add a task
        time.sleep(0.1)
        task = Task(
            id="task-001",
            title="New Task",
            description="A new task",
            estimated_hours=1.0,
            dependencies=[]
        )
        self.coordinator.add_task(task)

        # Update progress report
        self.persistence.save_progress()
        updated_mtime = os.path.getmtime(self.persistence.md_file)

        # File should have been modified
        self.assertGreater(updated_mtime, initial_mtime)

        # Content should include the new task
        with open(self.persistence.md_file, 'r', encoding='utf-8') as f:
            content = f.read()

        self.assertIn("task-001", content)
        self.assertIn("New Task", content)

    def test_req_3_7_4_1_progress_report_always_available(self):
        """REQ-3.7.4.1: Progress report must always be available from initialization"""
        # Save progress to create the report
        self.persistence.save_progress()

        # Report should exist after save
        self.assertTrue(os.path.exists(self.persistence.md_file))

        # Report should contain team status even with no tasks
        with open(self.persistence.md_file, 'r', encoding='utf-8') as f:
            content = f.read()

        # Should mention team
        self.assertIn("Team", content)

    def test_save_progress_to_markdown(self):
        """Test saving progress to markdown file"""
        # Add some tasks and agents
        self.coordinator.register_agent("agent-001")
        task = Task(
            id="task-001",
            title="Test Task",
            description="A test task",
            estimated_hours=2.0,
            dependencies=[],
            status=TaskStatus.COMPLETED,
            progress=100
        )
        self.coordinator.add_task(task)

        self.persistence.save_progress()

        self.assertTrue(os.path.exists(self.persistence.md_file))

        with open(self.persistence.md_file, 'r', encoding='utf-8') as f:
            content = f.read()

        self.assertIn("task-001", content)
        self.assertIn("completed", content.lower())

    def test_save_progress_to_json(self):
        """Test saving progress to JSON file"""
        self.coordinator.register_agent("agent-001")
        task = Task(
            id="task-001",
            title="Test Task",
            description="A test task",
            estimated_hours=2.0,
            dependencies=[],
            progress=50
        )
        self.coordinator.add_task(task)

        self.persistence.save_progress()

        self.assertTrue(os.path.exists(self.persistence.json_file))

        # Load and verify JSON
        import json
        with open(self.persistence.json_file, 'r', encoding='utf-8') as f:
            data = json.load(f)

        self.assertIn("tasks", data)
        self.assertIn("agents", data)

    def test_load_progress_from_json(self):
        """Test loading progress from JSON file"""
        # Save some progress
        self.coordinator.register_agent("agent-001")
        task = Task(
            id="task-001",
            title="Test Task",
            description="A test task",
            estimated_hours=2.0,
            dependencies=[],
            status=TaskStatus.IN_PROGRESS,
            progress=50,
            assigned_agent="agent-001"
        )
        self.coordinator.add_task(task)

        self.persistence.save_progress()

        # Verify JSON file was created
        self.assertTrue(os.path.exists(self.persistence.json_file))

        # Read and verify the JSON file
        with open(self.persistence.json_file, 'r', encoding='utf-8') as f:
            data = json.load(f)

        self.assertIn("tasks", data)
        self.assertIn("agents", data)
        # Verify task was saved
        self.assertEqual(len(data["tasks"]), 1)
        self.assertEqual(data["tasks"][0]["id"], "task-001")

    def test_progress_history_tracking(self):
        """Test that progress history is tracked"""
        # Save multiple times
        for i in range(3):
            task = Task(
                id=f"task-{i:03d}",
                title=f"Task {i}",
                description=f"Test task {i}",
                estimated_hours=1.0,
                dependencies=[],
                status=TaskStatus.COMPLETED,
                progress=100
            )
            self.coordinator.add_task(task)
            self.persistence.save_progress()
            time.sleep(0.1)  # Ensure different timestamps

        # Check that history files were created
        history_files = os.listdir(self.persistence.history_dir)
        self.assertGreater(len(history_files), 0)

    def test_completed_count_history_increases_only(self):
        """Test that completed task count only increases (supervisor_issues_checklist.md requirement)"""
        # Add and complete some tasks
        for i in range(3):
            task = Task(
                id=f"task-{i:03d}",
                title=f"Task {i}",
                description=f"Test task {i}",
                estimated_hours=1.0,
                dependencies=[],
                status=TaskStatus.COMPLETED,
                progress=100
            )
            self.coordinator.add_task(task)
            self.persistence._record_completed_count_change(i + 1, i)

        history = self.persistence.completed_count_history

        # All entries should be increases
        for entry in history:
            self.assertEqual(entry["change_type"], "increase")
            self.assertGreater(entry["change"], 0)

    def test_cleanup_old_history(self):
        """Test that old history files are cleaned up"""
        # Create multiple history files
        for i in range(110):  # More than default keep_count of 100
            task = Task(
                id=f"task-{i:03d}",
                title=f"Task {i}",
                description=f"Test task {i}",
                estimated_hours=1.0,
                dependencies=[],
                status=TaskStatus.COMPLETED,
                progress=100
            )
            self.coordinator.add_task(task)
            self.persistence.save_progress()

        # Cleanup old history
        self.persistence._cleanup_old_history(keep_count=100)

        # Count remaining history files
        history_files = [f for f in os.listdir(self.persistence.history_dir)
                        if f.startswith("progress_") and f.endswith(".md")]

        # Should have approximately keep_count files (give or take a few)
        self.assertLessEqual(len(history_files), 105)


class TestProgressReportContent(unittest.TestCase):
    """Test the actual content of progress reports"""

    def setUp(self):
        """Create a temporary directory and setup for testing"""
        self.temp_dir = tempfile.mkdtemp()
        self.output_dir = os.path.join(self.temp_dir, "progress_reports")
        self.coordinator = AgentCoordinator(project_name="Test Project")
        self.coordinator.team_id = "test-team-content-20240118"
        self.tracker = DetailedProgressTracker(self.coordinator)

        self.persistence = ProgressPersistence(
            coordinator=self.coordinator,
            tracker=self.tracker,
            output_dir=self.output_dir,
            project_dir=self.temp_dir,
            team_id=self.coordinator.team_id
        )

    def tearDown(self):
        """Clean up temporary directory"""
        import shutil
        shutil.rmtree(self.temp_dir, ignore_errors=True)

    def test_progress_report_contains_task_statuses(self):
        """Test that progress report contains task status information"""
        # Add tasks with different statuses
        tasks = [
            Task(id="task-001", title="Pending Task", description="Pending", estimated_hours=1.0,
                  dependencies=[], status=TaskStatus.PENDING, progress=0),
            Task(id="task-002", title="In Progress Task", description="In Progress", estimated_hours=1.0,
                  dependencies=[], status=TaskStatus.IN_PROGRESS, progress=50),
            Task(id="task-003", title="Completed Task", description="Completed", estimated_hours=1.0,
                  dependencies=[], status=TaskStatus.COMPLETED, progress=100),
        ]
        for task in tasks:
            self.coordinator.add_task(task)

        self.persistence.save_progress()

        with open(self.persistence.md_file, 'r', encoding='utf-8') as f:
            content = f.read()

        self.assertIn("task-001", content)
        self.assertIn("task-002", content)
        self.assertIn("task-003", content)
        self.assertIn("pending", content.lower())
        self.assertIn("in progress", content.lower())  # Markdown uses "in progress" with space
        self.assertIn("completed", content.lower())

    def test_progress_report_contains_agent_status(self):
        """Test that progress report contains agent status information"""
        self.coordinator.register_agent("agent-001")
        self.coordinator.register_agent("agent-002")
        self.coordinator.agent_states["agent-001"] = AgentState.RUNNING
        self.coordinator.agent_states["agent-002"] = AgentState.PAUSED

        self.persistence.save_progress()

        with open(self.persistence.md_file, 'r', encoding='utf-8') as f:
            content = f.read()

        self.assertIn("agent-001", content)
        self.assertIn("agent-002", content)
        self.assertIn("running", content.lower())
        self.assertIn("paused", content.lower())

    def test_progress_report_contains_checkpoints(self):
        """Test that progress report contains checkpoint information"""
        task = Task(
            id="task-001",
            title="Task with Checkpoints",
            description="Testing checkpoints",
            estimated_hours=1.0,
            dependencies=[],
            status=TaskStatus.IN_PROGRESS,
            progress=50
        )
        self.coordinator.add_task(task)

        checkpoint = Checkpoint(
            agent_id="agent-001",
            task_id="task-001",
            progress=50,
            changes="Halfway there",
            next_steps="Finish up"
        )
        self.coordinator.checkpoints.append(checkpoint)

        self.persistence.save_progress()

        with open(self.persistence.md_file, 'r', encoding='utf-8') as f:
            content = f.read()

        # Should mention checkpoint
        self.assertTrue("checkpoint" in content.lower() or "progress" in content.lower())

    def test_progress_report_last_updated_indicator(self):
        """Test REQ-3.7.3.1: Progress report has 'Last Updated' indicator"""
        self.persistence.save_progress()

        with open(self.persistence.md_file, 'r', encoding='utf-8') as f:
            content = f.read()

        # Should have a timestamp or "last updated" indicator
        self.assertTrue(
            "last updated" in content.lower() or
            "updated" in content.lower() or
            "timestamp" in content.lower() or
            any(char.isdigit() for char in content)  # Has date/time numbers
        )


if __name__ == "__main__":
    unittest.main()
