import os
import tempfile
import time
import unittest
from dataclasses import dataclass


@dataclass
class _Runner:
    project_dir: str


class _Coordinator:
    def __init__(self, project_dir: str):
        self.runner = _Runner(project_dir=project_dir)

    def register_agent_instance(self, _agent):
        return


class TestAcceptanceCommandLocking(unittest.TestCase):
    def _make_agent_and_task(self, project_dir: str):
        from src.ai_team.agents.agent import Agent
        from src.ai_team.agents.agent_coordinator import Task

        class _TestAgent(Agent):
            def work(self, task: Task) -> bool:  # pragma: no cover
                return True

        coord = _Coordinator(project_dir)
        agent = _TestAgent("test-agent", coord)
        task = Task(
            id="task-1",
            title="Test",
            description="",
            estimated_hours=0.1,
            acceptance_criteria=['Command: `python -c "print(123)"`'],
        )
        return agent, task

    def test_stale_lock_file_is_removed_and_command_runs(self):
        with tempfile.TemporaryDirectory() as td:
            agent, task = self._make_agent_and_task(td)

            lock_dir = os.path.join(td, ".ai_team_locks")
            os.makedirs(lock_dir, exist_ok=True)
            lock_path = os.path.join(lock_dir, "tool.python.lock")
            with open(lock_path, "w", encoding="utf-8") as f:
                f.write("stale")
            old = time.time() - 999999
            os.utime(lock_path, (old, old))

            ok, msg = agent._run_acceptance_commands(task)
            self.assertTrue(ok, msg)
            self.assertFalse(os.path.exists(lock_path), "lock file should be released/removed after run")

    def test_legacy_lock_directory_is_removed_and_command_runs(self):
        with tempfile.TemporaryDirectory() as td:
            agent, task = self._make_agent_and_task(td)

            lock_dir = os.path.join(td, ".ai_team_locks")
            os.makedirs(lock_dir, exist_ok=True)
            lock_path = os.path.join(lock_dir, "tool.python.lock")
            os.makedirs(lock_path, exist_ok=True)  # legacy: directory instead of file
            old = time.time() - 999999
            os.utime(lock_path, (old, old))

            ok, msg = agent._run_acceptance_commands(task)
            self.assertTrue(ok, msg)
            self.assertFalse(os.path.exists(lock_path), "legacy lock directory should be cleaned up")


if __name__ == "__main__":
    unittest.main()


