import os
import tempfile
import unittest
from datetime import datetime, timedelta


class TestValidatorEnvironmentPlateau(unittest.TestCase):
    def test_progress_update_frequency_allows_environment_gated_plateau(self):
        with tempfile.TemporaryDirectory() as td:
            os.makedirs(os.path.join(td, "progress_reports"), exist_ok=True)

            now = datetime(2026, 1, 1, 12, 0, 0)
            last_updated = now - timedelta(minutes=1)

            progress_md = f"""# AI Agent Team Progress Report

**Team ID:** `team-test`

**Last Updated:** {last_updated.strftime("%Y-%m-%d %H:%M:%S")}

**Time Since Last Overall Progress Change:** 20 minutes 0 seconds

---

## Overall Progress

- **Total Tasks:** 10
- **Completed:** 5 (50.0%)
- **In Progress:** 0
- **Blocked:** 5
- **Ready:** 0
- **Pending:** 0
- **Failed:** 0

**Overall Progress:** 50.0%
"""
            with open(os.path.join(td, "progress_reports", "progress.md"), "w", encoding="utf-8") as f:
                f.write(progress_md)

            # tasks.md indicates at least one environment blocker, and no runnable tasks.
            tasks_md = """### task-001

Status: blocked
Blocker Type: environment
Blocker: Missing SDK
"""
            with open(os.path.join(td, "tasks.md"), "w", encoding="utf-8") as f:
                f.write(tasks_md)

            from scripts.validate_supervisor_issues import _check_progress_update_frequency

            res = _check_progress_update_frequency(td, now)
            self.assertTrue(res.ok, res.details)


if __name__ == "__main__":
    unittest.main()


