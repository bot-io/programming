"""
Unit Tests for Task Configuration Parser

Tests the TaskConfigParser class which is responsible for:
- Parsing requirements.md files
- Parsing tasks.md files
- Extracting task metadata
- Handling task dependencies
- REQ-2.2.1.1: Must parse "Dependencies: none" as empty list
- REQ-2.2.1.2: Handle variations of "no dependencies"
- REQ-2.2.1.3: Filter out "none" keywords from dependency lists
- REQ-2.2.1.4: Prevent false dependencies from subsequent sections
"""

import os
import sys
import tempfile
import unittest
from datetime import datetime
from pathlib import Path

# Add parent directory to path
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))

from src.ai_team.utils.task_config_parser import TaskConfigParser
from src.ai_team.agents.agent_coordinator import TaskStatus


class TestTaskConfigParserBasicParsing(unittest.TestCase):
    """Test basic parsing functionality of TaskConfigParser"""

    def setUp(self):
        """Create a temporary directory for test files"""
        self.test_dir = tempfile.mkdtemp()
        self.parser = TaskConfigParser(self.test_dir)

    def tearDown(self):
        """Clean up temporary files"""
        import shutil
        shutil.rmtree(self.test_dir, ignore_errors=True)

    def test_parse_requirements_from_valid_file(self):
        """Test parsing a valid requirements.md file"""
        requirements_content = """# Project Requirements

## Overview
This is a test project for a notes application.

## Features
- User authentication
- Note creation and editing
- Category management

## Technical Requirements
- Flutter framework
- Hive for local storage
- Material Design
"""
        requirements_path = os.path.join(self.test_dir, "requirements.md")
        with open(requirements_path, 'w', encoding='utf-8') as f:
            f.write(requirements_content)

        requirements = self.parser.parse_requirements()

        self.assertEqual(requirements["overview"], "This is a test project for a notes application.")
        self.assertEqual(len(requirements["features"]), 3)
        self.assertIn("User authentication", requirements["features"])
        self.assertEqual(len(requirements["technical_requirements"]), 3)

    def test_parse_requirements_returns_empty_dict_when_file_missing(self):
        """Test that parse_requirements returns empty dict when file doesn't exist"""
        requirements = self.parser.parse_requirements()

        self.assertEqual(requirements["overview"], "")
        self.assertEqual(requirements["features"], [])
        self.assertEqual(requirements["technical_requirements"], [])

    def test_parse_tasks_from_valid_file(self):
        """Test parsing tasks from a valid tasks.md file"""
        tasks_content = """### task-001-create-model
- Title: Create Note Model
- Description: Create a data model for notes
- Estimated Hours: 2
- Dependencies: none
- Status: pending
- Progress: 0

### task-002-create-service
- Title: Create Note Service
- Description: Create a service for note CRUD operations
- Estimated Hours: 3
- Dependencies: task-001-create-model
- Status: pending
- Progress: 0
"""
        tasks_path = os.path.join(self.test_dir, "tasks.md")
        with open(tasks_path, 'w', encoding='utf-8') as f:
            f.write(tasks_content)

        tasks = self.parser.parse_tasks()

        self.assertEqual(len(tasks), 2)
        self.assertEqual(tasks[0].id, "task-001-create-model")
        self.assertEqual(tasks[0].title, "Create Note Model")
        self.assertEqual(tasks[0].estimated_hours, 2.0)
        self.assertEqual(tasks[1].dependencies, ["task-001-create-model"])

    def test_parse_tasks_returns_empty_list_when_file_missing(self):
        """Test that parse_tasks returns empty list when file doesn't exist"""
        tasks = self.parser.parse_tasks()
        self.assertEqual(tasks, [])


class TestDependencyParsing(unittest.TestCase):
    """Test REQ-2.2.1.1 through REQ-2.2.1.4: Dependency parsing edge cases"""

    def setUp(self):
        """Create a temporary directory for test files"""
        self.test_dir = tempfile.mkdtemp()
        self.parser = TaskConfigParser(self.test_dir)

    def tearDown(self):
        """Clean up temporary files"""
        import shutil
        shutil.rmtree(self.test_dir, ignore_errors=True)

    def test_req_2_2_1_1_dependencies_none_parsed_as_empty_list(self):
        """REQ-2.2.1.1: Must parse 'Dependencies: none' as empty list []"""
        tasks_content = """### task-001
- Title: Test Task
- Description: Test task with no dependencies
- Dependencies: none
"""
        tasks_path = os.path.join(self.test_dir, "tasks.md")
        with open(tasks_path, 'w', encoding='utf-8') as f:
            f.write(tasks_content)

        tasks = self.parser.parse_tasks()
        self.assertEqual(len(tasks), 1)
        self.assertEqual(tasks[0].dependencies, [],
                        "Dependencies: none should be parsed as empty list")

    def test_req_2_2_1_2_variations_of_no_dependencies(self):
        """REQ-2.2.1.2: Handle variations of 'no dependencies' as empty list"""
        variations = ["none", "no dependencies", "no deps", "n/a", "na", "N/A", "NA", ""]

        for i, variation in enumerate(variations):
            test_dir = tempfile.mkdtemp()
            parser = TaskConfigParser(test_dir)

            tasks_content = f"""### task-00{i}
- Title: Test Task {i}
- Description: Test task with variation: {variation}
- Dependencies: {variation}
"""
            tasks_path = os.path.join(test_dir, "tasks.md")
            with open(tasks_path, 'w', encoding='utf-8') as f:
                f.write(tasks_content)

            tasks = parser.parse_tasks()
            self.assertEqual(tasks[0].dependencies, [],
                           f"Dependencies: '{variation}' should be parsed as empty list")

            import shutil
            shutil.rmtree(test_dir, ignore_errors=True)

    def test_req_2_2_1_3_filter_none_from_dependency_lists(self):
        """REQ-2.2.1.3: Filter out 'none' if it appears in dependency lists"""
        tasks_content = """### task-001
- Title: Test Task
- Description: Test task with mixed dependencies
- Dependencies: task-002, none, task-003
"""
        tasks_path = os.path.join(self.test_dir, "tasks.md")
        with open(tasks_path, 'w', encoding='utf-8') as f:
            f.write(tasks_content)

        tasks = self.parser.parse_tasks()
        self.assertEqual(tasks[0].dependencies, ["task-002", "task-003"],
                        "None should be filtered from dependency list")

    def test_req_2_2_1_4_prevent_false_dependencies_from_sections(self):
        """REQ-2.2.1.4: Prevent 'Acceptance Criteria' from being parsed as dependency"""
        tasks_content = """### task-001
- Title: Test Task
- Description: Test task
- Dependencies: task-002
- Acceptance Criteria:
  - File exists
  - Tests pass
"""
        tasks_path = os.path.join(self.test_dir, "tasks.md")
        with open(tasks_path, 'w', encoding='utf-8') as f:
            f.write(tasks_content)

        tasks = self.parser.parse_tasks()
        self.assertEqual(tasks[0].dependencies, ["task-002"],
                        "Only 'task-002' should be a dependency, not 'Acceptance Criteria'")
        # Verify acceptance criteria were parsed correctly
        self.assertEqual(len(tasks[0].acceptance_criteria), 2)

    def test_dependencies_with_multiple_values(self):
        """Test parsing multiple comma-separated dependencies"""
        tasks_content = """### task-001
- Title: Test Task
- Description: Test task with multiple dependencies
- Dependencies: task-002, task-003, task-004
"""
        tasks_path = os.path.join(self.test_dir, "tasks.md")
        with open(tasks_path, 'w', encoding='utf-8') as f:
            f.write(tasks_content)

        tasks = self.parser.parse_tasks()
        self.assertEqual(tasks[0].dependencies, ["task-002", "task-003", "task-004"])

    def test_dependencies_with_newline_separated_values(self):
        """Test parsing newline-separated dependencies"""
        tasks_content = """### task-001
- Title: Test Task
- Description: Test task
- Dependencies:
  - task-002
  - task-003
  - task-004
"""
        tasks_path = os.path.join(self.test_dir, "tasks.md")
        with open(tasks_path, 'w', encoding='utf-8') as f:
            f.write(tasks_content)

        tasks = self.parser.parse_tasks()
        self.assertEqual(len(tasks[0].dependencies), 3)


class TestTaskStatusParsing(unittest.TestCase):
    """Test parsing of various task status values"""

    def setUp(self):
        """Create a temporary directory for test files"""
        self.test_dir = tempfile.mkdtemp()
        self.parser = TaskConfigParser(self.test_dir)

    def tearDown(self):
        """Clean up temporary files"""
        import shutil
        shutil.rmtree(self.test_dir, ignore_errors=True)

    def test_parse_all_task_statuses(self):
        """Test parsing all valid task status values"""
        status_variations = {
            "pending": TaskStatus.PENDING,
            "ready": TaskStatus.READY,
            "in_progress": TaskStatus.IN_PROGRESS,
            "in progress": TaskStatus.IN_PROGRESS,
            "assigned": TaskStatus.ASSIGNED,
            "blocked": TaskStatus.BLOCKED,
            "review": TaskStatus.REVIEW,
            "completed": TaskStatus.COMPLETED,
            "done": TaskStatus.COMPLETED,
            "failed": TaskStatus.FAILED,
        }

        for status_str, expected_status in status_variations.items():
            test_dir = tempfile.mkdtemp()
            parser = TaskConfigParser(test_dir)

            tasks_content = f"""### task-{status_str.replace(' ', '_')}
- Title: Test Task
- Description: Test task with status: {status_str}
- Status: {status_str}
"""
            tasks_path = os.path.join(test_dir, "tasks.md")
            with open(tasks_path, 'w', encoding='utf-8') as f:
                f.write(tasks_content)

            tasks = parser.parse_tasks()
            self.assertEqual(tasks[0].status, expected_status,
                           f"Status '{status_str}' should map to {expected_status}")

            import shutil
            shutil.rmtree(test_dir, ignore_errors=True)


class TestTaskMetadataExtraction(unittest.TestCase):
    """Test extraction of task metadata fields"""

    def setUp(self):
        """Create a temporary directory for test files"""
        self.test_dir = tempfile.mkdtemp()
        self.parser = TaskConfigParser(self.test_dir)

    def tearDown(self):
        """Clean up temporary files"""
        import shutil
        shutil.rmtree(self.test_dir, ignore_errors=True)

    def test_parse_acceptance_criteria(self):
        """Test parsing acceptance criteria from task"""
        tasks_content = """### task-001
- Title: Test Task
- Description: Test task
- Acceptance Criteria:
  - File lib/note.dart exists
  - All tests pass
  - Code is documented
"""
        tasks_path = os.path.join(self.test_dir, "tasks.md")
        with open(tasks_path, 'w', encoding='utf-8') as f:
            f.write(tasks_content)

        tasks = self.parser.parse_tasks()
        self.assertEqual(len(tasks[0].acceptance_criteria), 3)
        self.assertIn("File lib/note.dart exists", tasks[0].acceptance_criteria)

    def test_parse_artifacts(self):
        """Test parsing artifacts from task"""
        tasks_content = """### task-001
- Title: Test Task
- Description: Test task
- Artifacts: lib/note.dart, lib/category.dart, test/note_test.dart
"""
        tasks_path = os.path.join(self.test_dir, "tasks.md")
        with open(tasks_path, 'w', encoding='utf-8') as f:
            f.write(tasks_content)

        tasks = self.parser.parse_tasks()
        self.assertEqual(len(tasks[0].artifacts), 3)
        self.assertIn("lib/note.dart", tasks[0].artifacts)

    def test_parse_assigned_agent(self):
        """Test parsing assigned agent from task"""
        tasks_content = """### task-001
- Title: Test Task
- Description: Test task
- Assigned Agent: agent-001
"""
        tasks_path = os.path.join(self.test_dir, "tasks.md")
        with open(tasks_path, 'w', encoding='utf-8') as f:
            f.write(tasks_content)

        tasks = self.parser.parse_tasks()
        self.assertEqual(tasks[0].assigned_agent, "agent-001")

    def test_parse_progress_percentage(self):
        """Test parsing progress percentage"""
        tasks_content = """### task-001
- Title: Test Task
- Description: Test task
- Progress: 50
"""
        tasks_path = os.path.join(self.test_dir, "tasks.md")
        with open(tasks_path, 'w', encoding='utf-8') as f:
            f.write(tasks_content)

        tasks = self.parser.parse_tasks()
        self.assertEqual(tasks[0].progress, 50)

    def test_parse_estimated_hours(self):
        """Test parsing estimated hours"""
        tasks_content = """### task-001
- Title: Test Task
- Description: Test task
- Estimated Hours: 3.5
"""
        tasks_path = os.path.join(self.test_dir, "tasks.md")
        with open(tasks_path, 'w', encoding='utf-8') as f:
            f.write(tasks_content)

        tasks = self.parser.parse_tasks()
        self.assertEqual(tasks[0].estimated_hours, 3.5)

    def test_parse_blocker_message(self):
        """Test parsing blocker message"""
        tasks_content = """### task-001
- Title: Test Task
- Description: Test task
- Blocker: Waiting for dependency task-002 to complete
"""
        tasks_path = os.path.join(self.test_dir, "tasks.md")
        with open(tasks_path, 'w', encoding='utf-8') as f:
            f.write(tasks_content)

        tasks = self.parser.parse_tasks()
        self.assertIn("dependency task-002", tasks[0].blocker_message)


class TestTaskUpdateAndPersistence(unittest.TestCase):
    """Test updating tasks in the file and persistence"""

    def setUp(self):
        """Create a temporary directory for test files"""
        self.test_dir = tempfile.mkdtemp()
        self.parser = TaskConfigParser(self.test_dir)

    def tearDown(self):
        """Clean up temporary files"""
        import shutil
        shutil.rmtree(self.test_dir, ignore_errors=True)

    def test_update_task_status_in_file(self):
        """Test updating a task's status in tasks.md"""
        tasks_content = """### task-001
- Title: Test Task
- Description: Test task
- Status: pending
- Progress: 0
"""
        tasks_path = os.path.join(self.test_dir, "tasks.md")
        with open(tasks_path, 'w', encoding='utf-8') as f:
            f.write(tasks_content)

        tasks = self.parser.parse_tasks()
        task = tasks[0]
        task.status = TaskStatus.IN_PROGRESS
        task.progress = 50

        # Update the file
        self.parser.update_task_in_file(task)

        # Re-parse and verify
        updated_tasks = self.parser.parse_tasks()
        self.assertEqual(updated_tasks[0].status, TaskStatus.IN_PROGRESS)
        self.assertEqual(updated_tasks[0].progress, 50)

    def test_update_task_with_new_task_appends_to_file(self):
        """Test that updating a non-existent task appends it to the file"""
        original_content = """### task-001
- Title: Existing Task
- Description: This task already exists
- Status: completed
"""
        tasks_path = os.path.join(self.test_dir, "tasks.md")
        with open(tasks_path, 'w', encoding='utf-8') as f:
            f.write(original_content)

        # Create a new task that doesn't exist in the file
        from src.ai_team.agents.agent_coordinator import Task
        new_task = Task(
            id="task-002",
            title="New Task",
            description="This is a new task",
            estimated_hours=2.0,
            dependencies=[],
            status=TaskStatus.PENDING,
            progress=0
        )

        # Update should append the new task
        result = self.parser.update_task_in_file(new_task)
        self.assertTrue(result)

        # Verify the new task was appended
        with open(tasks_path, 'r', encoding='utf-8') as f:
            content = f.read()

        self.assertIn("task-001", content)
        self.assertIn("task-002", content)
        self.assertIn("New Task", content)

    def test_reset_all_task_statuses(self):
        """Test resetting all task statuses to pending"""
        tasks_content = """### task-001
- Title: Task 1
- Status: completed
- Progress: 100
- Assigned Agent: agent-001
- Started: 2024-01-01 10:00:00
- Completed: 2024-01-01 12:00:00

### task-002
- Title: Task 2
- Status: in_progress
- Progress: 50
- Assigned Agent: agent-002
"""
        tasks_path = os.path.join(self.test_dir, "tasks.md")
        with open(tasks_path, 'w', encoding='utf-8') as f:
            f.write(tasks_content)

        # Reset all statuses
        result = self.parser.reset_all_task_statuses()
        self.assertTrue(result)

        # Verify all tasks are now pending
        tasks = self.parser.parse_tasks()
        self.assertEqual(tasks[0].status, TaskStatus.PENDING)
        self.assertEqual(tasks[0].progress, 0)
        self.assertIsNone(tasks[0].assigned_agent)

        self.assertEqual(tasks[1].status, TaskStatus.PENDING)
        self.assertEqual(tasks[1].progress, 0)
        self.assertIsNone(tasks[1].assigned_agent)


class TestTaskParsingEdgeCases(unittest.TestCase):
    """Test edge cases in task parsing"""

    def setUp(self):
        """Create a temporary directory for test files"""
        self.test_dir = tempfile.mkdtemp()
        self.parser = TaskConfigParser(self.test_dir)

    def tearDown(self):
        """Clean up temporary files"""
        import shutil
        shutil.rmtree(self.test_dir, ignore_errors=True)

    def test_task_followed_by_phase_header(self):
        """Test that tasks followed by '## Phase' headers are parsed correctly"""
        tasks_content = """### task-001
- Title: Phase 1 Task
- Description: Task in phase 1
- Dependencies: none

## Phase 2

### task-002
- Title: Phase 2 Task
- Description: Task in phase 2
- Dependencies: task-001
"""
        tasks_path = os.path.join(self.test_dir, "tasks.md")
        with open(tasks_path, 'w', encoding='utf-8') as f:
            f.write(tasks_content)

        tasks = self.parser.parse_tasks()
        self.assertEqual(len(tasks), 2, "Both tasks should be parsed")
        self.assertEqual(tasks[0].id, "task-001")
        self.assertEqual(tasks[1].id, "task-002")

    def test_task_without_title_uses_id_as_title(self):
        """Test that tasks without a title field use the task ID as title"""
        tasks_content = """### task-001-simple-task
- Description: This is a simple task
- Dependencies: none
"""
        tasks_path = os.path.join(self.test_dir, "tasks.md")
        with open(tasks_path, 'w', encoding='utf-8') as f:
            f.write(tasks_content)

        tasks = self.parser.parse_tasks()
        self.assertEqual(tasks[0].title, "Task 001 Simple Task")

    def test_task_with_slugged_id(self):
        """Test parsing tasks with slugged IDs like 'task-001-verify-flutter-sdk'"""
        tasks_content = """### task-001-verify-flutter-sdk
- Title: Verify Flutter SDK
- Description: Verify Flutter SDK is installed
- Dependencies: none

### task-002-install-hive
- Title: Install Hive Package
- Description: Install Hive package for local storage
- Dependencies: task-001-verify-flutter-sdk
"""
        tasks_path = os.path.join(self.test_dir, "tasks.md")
        with open(tasks_path, 'w', encoding='utf-8') as f:
            f.write(tasks_content)

        tasks = self.parser.parse_tasks()
        self.assertEqual(len(tasks), 2)
        self.assertEqual(tasks[0].id, "task-001-verify-flutter-sdk")
        self.assertEqual(tasks[1].id, "task-002-install-hive")
        self.assertEqual(tasks[1].dependencies, ["task-001-verify-flutter-sdk"])

    def test_task_with_artifacts_on_multiple_lines(self):
        """Test parsing artifacts spread across multiple lines"""
        tasks_content = """### task-001
- Title: Test Task
- Description: Test task
- Artifacts:
  - lib/models/note.dart
  - lib/models/category.dart
  - lib/services/storage_service.dart
"""
        tasks_path = os.path.join(self.test_dir, "tasks.md")
        with open(tasks_path, 'w', encoding='utf-8') as f:
            f.write(tasks_content)

        tasks = self.parser.parse_tasks()
        self.assertEqual(len(tasks[0].artifacts), 3)


if __name__ == "__main__":
    unittest.main()
