"""
Run the AI-team automation tests (stdlib unittest, no third-party deps).

Usage:
  python run_tests.py
"""

import os
import sys
import unittest


def main() -> int:
    # Ensure repo root is on sys.path for imports like `src.ai_team...`
    repo_root = os.path.dirname(os.path.abspath(__file__))
    if repo_root not in sys.path:
        sys.path.insert(0, repo_root)

    suite = unittest.defaultTestLoader.discover("tests")
    runner = unittest.TextTestRunner(verbosity=2)
    result = runner.run(suite)
    return 0 if result.wasSuccessful() else 1


if __name__ == "__main__":
    raise SystemExit(main())


