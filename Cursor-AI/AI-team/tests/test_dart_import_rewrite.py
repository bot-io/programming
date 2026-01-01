import json
import os
import tempfile
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


class _FakeAI:
    def __init__(self, payload: dict):
        self._payload = payload

    def is_available(self) -> bool:
        return True

    def generate_with_retry(self, *args, **kwargs) -> str:
        return json.dumps(self._payload)


class TestDartImportRewrite(unittest.TestCase):
    def test_rewrites_placeholder_package_import(self):
        with tempfile.TemporaryDirectory() as td:
            # pubspec.yaml defines the real package name
            with open(os.path.join(td, "pubspec.yaml"), "w", encoding="utf-8") as f:
                f.write("name: simplenotes\n")

            payload = {
                "files": [
                    {
                        "path": "lib/foo.dart",
                        "content": "import 'package:test_notes_app/models/note.dart';\n",
                    }
                ],
                "commands": [],
            }

            from src.ai_team.agents.generic_agent import GenericAgent
            from src.ai_team.agents.agent_coordinator import Task
            from src.ai_team.utils.task_adapter import TaskContext

            coord = _Coordinator(td)
            agent = GenericAgent("dev", coord)
            agent._cursor_cli = None
            agent._ai_client = _FakeAI(payload)

            t = Task(
                id="task-1",
                title="Write dart file",
                description="Create `lib/foo.dart`",
                estimated_hours=0.1,
            )
            ctx = TaskContext(task=t, agent_id="dev", config={"project_dir": td}, metadata={})

            ok = agent._cursor_cli_execute_task(ctx)
            self.assertTrue(ok)

            out_path = os.path.join(td, "lib", "foo.dart")
            with open(out_path, "r", encoding="utf-8") as f:
                content = f.read()
            self.assertIn("package:simplenotes/", content)
            self.assertNotIn("package:test_notes_app/", content)


if __name__ == "__main__":
    unittest.main()


