import json
import os
import tempfile
import unittest
from pathlib import Path


class TestSettingsAndAIClient(unittest.TestCase):
    def setUp(self):
        self._old_env = dict(os.environ)

    def tearDown(self):
        os.environ.clear()
        os.environ.update(self._old_env)

    def test_settings_file_is_read_for_gemini_api_key(self):
        with tempfile.TemporaryDirectory() as td:
            settings_path = Path(td) / "ai_team_settings.local.json"
            settings_path.write_text(
                json.dumps({"AI_PROVIDER": "gemini", "GEMINI_API_KEY": "settings-key"}),
                encoding="utf-8",
            )
            os.environ.pop("GEMINI_API_KEY", None)
            os.environ["AI_TEAM_SETTINGS_FILE"] = str(settings_path)

            from src.ai_team.utils.ai_client import AIClient

            c = AIClient(provider="gemini")
            self.assertEqual(c.api_key, "settings-key")

    def test_env_overrides_settings_file(self):
        with tempfile.TemporaryDirectory() as td:
            settings_path = Path(td) / "ai_team_settings.local.json"
            settings_path.write_text(
                json.dumps({"AI_PROVIDER": "gemini", "GEMINI_API_KEY": "settings-key"}),
                encoding="utf-8",
            )
            os.environ["AI_TEAM_SETTINGS_FILE"] = str(settings_path)
            os.environ["GEMINI_API_KEY"] = "env-key"

            from src.ai_team.utils.ai_client import AIClient

            c = AIClient(provider="gemini")
            self.assertEqual(c.api_key, "env-key")

    def test_provider_can_come_from_settings(self):
        with tempfile.TemporaryDirectory() as td:
            settings_path = Path(td) / "ai_team_settings.local.json"
            settings_path.write_text(
                json.dumps({"AI_PROVIDER": "gemini", "GEMINI_API_KEY": "settings-key"}),
                encoding="utf-8",
            )
            os.environ["AI_TEAM_SETTINGS_FILE"] = str(settings_path)
            os.environ.pop("AI_PROVIDER", None)
            os.environ.pop("GEMINI_API_KEY", None)

            from src.ai_team.utils.ai_client import create_ai_client

            c = create_ai_client(provider=None)
            self.assertIsNotNone(c)
            self.assertEqual(c.provider, "gemini")


if __name__ == "__main__":
    unittest.main()


