"""
Local settings loader (project-agnostic).

We intentionally support a *gitignored* local settings JSON file so users can store
API keys without committing them to the repository.

Precedence (highest -> lowest):
1) Explicit environment variables (e.g., GEMINI_API_KEY)
2) AI_TEAM_SETTINGS_FILE JSON (if set)
3) Repo-root `ai_team_settings.local.json` (recommended; gitignored)

Settings JSON is a flat dict, e.g.:
{
  "AI_PROVIDER": "gemini",
  "GEMINI_API_KEY": "..."
}
"""

from __future__ import annotations

import json
import os
from pathlib import Path
from typing import Any, Dict, Optional


def _repo_root_from_here() -> Optional[Path]:
    """
    Best-effort repo root discovery for this codebase layout:
      repo_root/src/ai_team/utils/settings.py
    """
    try:
        p = Path(__file__).resolve()
        # utils -> ai_team -> src -> repo_root
        return p.parents[3]
    except Exception:
        return None


def get_settings_path() -> Optional[str]:
    """
    Return the effective settings file path (may not exist).
    """
    override = os.getenv("AI_TEAM_SETTINGS_FILE")
    if override:
        return override

    root = _repo_root_from_here()
    if root:
        return str(root / "ai_team_settings.local.json")

    # Fall back to current working directory.
    return str(Path(os.getcwd()) / "ai_team_settings.local.json")


def load_settings(path: Optional[str] = None) -> Dict[str, Any]:
    """
    Load settings JSON. Returns {} on any error.
    """
    p = path or get_settings_path()
    if not p:
        return {}
    try:
        pp = Path(p)
        if not pp.exists():
            return {}
        raw = pp.read_text(encoding="utf-8", errors="replace")
        data = json.loads(raw or "{}")
        return data if isinstance(data, dict) else {}
    except Exception:
        return {}


def get_setting(key: str, default: Any = None, *, settings_path: Optional[str] = None) -> Any:
    """
    Get a single setting from the settings file.
    Environment variables are NOT read here (caller should check env first).
    """
    try:
        s = load_settings(settings_path)
        return s.get(key, default)
    except Exception:
        return default


