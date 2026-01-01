import os
import tempfile
import unittest
from dataclasses import dataclass
from datetime import datetime


@dataclass
class _Runner:
    project_dir: str


class _Coordinator:
    def __init__(self, project_dir: str):
        self.runner = _Runner(project_dir=project_dir)
        self.tasks = {}
        self.agent_workloads = {}

    def register_agent_instance(self, _agent):
        return

    def add_task(self, task):
        self.tasks[task.id] = task


class TestSupervisorFixupTasksMonotonic(unittest.TestCase):
    def test_fixup_creation_does_not_reset_completed_task(self):
        with tempfile.TemporaryDirectory() as td:
            # minimal tasks.md so TaskConfigParser can write if it wants to
            with open(os.path.join(td, "tasks.md"), "w", encoding="utf-8") as f:
                f.write("")

            from src.ai_team.agents.agent_coordinator import Task, TaskStatus
            from src.ai_team.agents.supervisor_agent import SupervisorAgent

            coord = _Coordinator(td)

            completed = Task(
                id="task-001",
                title="Completed task",
                description="Creates `lib/missing.dart`",
                estimated_hours=0.1,
                status=TaskStatus.COMPLETED,
                progress=100,
                created_at=datetime.now(),
            )
            coord.tasks[completed.id] = completed

            sup = SupervisorAgent("supervisor-test", coord)
            sup.project_dir = td

            issue = {
                "type": "completed_tasks_missing_expected_files",
                "task_ids": ["task-001"],
                "examples": [{"task_id": "task-001", "missing": ["lib/missing.dart"]}],
            }

            before = coord.tasks["task-001"].status
            sup._fix_issue(issue)
            after = coord.tasks["task-001"].status

            self.assertEqual(before, TaskStatus.COMPLETED)
            self.assertEqual(after, TaskStatus.COMPLETED)

            fixups = [tid for tid in coord.tasks.keys() if tid.startswith("fix-missing-task-001-")]
            self.assertTrue(fixups, "expected at least one fix-up task to be created")
            self.assertEqual(coord.tasks[fixups[0]].status, TaskStatus.READY)


if __name__ == "__main__":
    unittest.main()


