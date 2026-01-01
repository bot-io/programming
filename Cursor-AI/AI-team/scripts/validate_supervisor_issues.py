"""
Supervisor Issues Validator

Validates a project directory against the checks described in `supervisor_issues_checklist.md`.

Design goals:
- Generic: no project-specific assumptions (framework/language/structure beyond the standard team files)
- Works cross-platform (Windows/macOS/Linux) using built-in OS tooling for process inspection
- Produces a concise PASS/FAIL report per issue/check
"""

from __future__ import annotations

import argparse
import os
import re
import subprocess
import sys
import time
from dataclasses import dataclass
from datetime import datetime
from typing import Dict, Iterable, List, Optional, Tuple


@dataclass(frozen=True)
class CheckResult:
    check_id: str
    title: str
    ok: bool
    details: str = ""


def _read_text(path: str) -> Optional[str]:
    """
    Read a text file robustly.

    On Windows, the team may be writing progress/log files while the validator is reading them,
    which can cause transient sharing-violation/permission errors. We retry briefly to avoid
    false FAILs.
    """
    last_err: Optional[Exception] = None
    for attempt in range(3):
        try:
            with open(path, "r", encoding="utf-8") as f:
                return f.read()
        except FileNotFoundError:
            return None
        except (PermissionError, OSError) as e:
            last_err = e
            # Small backoff to allow concurrent writers to finish.
            time.sleep(0.12 * (attempt + 1))
            continue
        except Exception as e:
            return f"[ERROR_READING_FILE] {e}"
    return f"[ERROR_READING_FILE] {last_err}" if last_err else "[ERROR_READING_FILE] unknown"


def _parse_progress_last_updated(progress_md: str) -> Optional[datetime]:
    # progress.md renders markdown emphasis: "**Last Updated:** 2025-12-28 15:58:27"
    m = re.search(r"(?:\*\*)?Last Updated:(?:\*\*)?\s*(\d{4}-\d{2}-\d{2}\s+\d{2}:\d{2}:\d{2})", progress_md)
    if not m:
        return None
    try:
        return datetime.strptime(m.group(1), "%Y-%m-%d %H:%M:%S")
    except Exception:
        return None


def _parse_progress_overall_percent(progress_md: str) -> Optional[float]:
    # progress.md renders markdown emphasis: "**Overall Progress:** 96.9%"
    m = re.search(r"(?:\*\*)?Overall Progress:(?:\*\*)?\s*(\d+(?:\.\d+)?)%", progress_md)
    if not m:
        return None
    try:
        return float(m.group(1))
    except Exception:
        return None


def _parse_progress_total_tasks(progress_md: str) -> Optional[int]:
    # progress.md renders markdown emphasis: "- **Total Tasks:** 45"
    m = re.search(r"(?:\*\*)?Total Tasks:(?:\*\*)?\s*(\d+)", progress_md)
    if not m:
        return None
    try:
        return int(m.group(1))
    except Exception:
        return None


def _parse_progress_completed_history(progress_md: str) -> List[Tuple[int, int]]:
    """
    Returns list of (prev, curr) transitions for completed count from history lines.
    Ex: "0 → 5" -> (0, 5)
    """
    transitions: List[Tuple[int, int]] = []
    for m in re.finditer(r"(\d+)\s*→\s*(\d+)", progress_md):
        try:
            transitions.append((int(m.group(1)), int(m.group(2))))
        except Exception:
            continue
    return transitions


def _parse_tasks_status_counts(tasks_md: str) -> Dict[str, int]:
    # tasks.md is a loosely structured markdown; we rely on "Status:" keys.
    counts: Dict[str, int] = {"completed": 0, "in_progress": 0, "blocked": 0, "ready": 0, "pending": 0, "assigned": 0, "failed": 0}
    for m in re.finditer(r"^\s*-?\s*Status:\s*([a-zA-Z_]+)\s*$", tasks_md, re.MULTILINE):
        status = m.group(1).strip().lower()
        if status in counts:
            counts[status] += 1
    return counts


def _parse_tasks_dependencies_none_misparsed(tasks_md: str) -> bool:
    """
    Heuristic: detect dependency fields explicitly containing 'none' as a literal dependency token.
    Example of bad content: "Dependencies: none" being treated as a list item in some formats.
    """
    # In this repo tasks.md uses either "- Dependencies:" or "Dependencies:".
    # We treat these as textual; validator just detects suspicious patterns.
    for line in tasks_md.splitlines():
        if re.search(r"Dependencies:\s*none\b", line, re.IGNORECASE):
            # This is not necessarily wrong in the file, but it is a known parsing footgun.
            return True
    return False


def _find_python_run_team_processes(project_dir: str) -> List[Tuple[int, str]]:
    """
    Returns list of (pid, commandline) for processes that look like a run_team invocation for project_dir.
    Uses OS commands (no external deps).
    """
    # Note: on Windows the commandline is often just "python.exe run_team.py" (no cwd),
    # so we must not require project_dir to appear in the command line to detect it.
    project_dir_abs = os.path.abspath(project_dir)
    matches: List[Tuple[int, str]] = []

    if sys.platform.startswith("win"):
        # Use wmic which exists on many Windows systems; if missing, fall back to empty.
        # Query all python processes and inspect command lines.
        try:
            # CSV output is easier to parse reliably.
            cmd = ["wmic", "process", "where", "name='python.exe' or name='pythonw.exe'", "get", "ProcessId,CommandLine", "/format:csv"]
            out = subprocess.check_output(cmd, stderr=subprocess.STDOUT, text=True, encoding="utf-8", errors="replace")
        except Exception:
            return []
        for line in out.splitlines():
            # Format: Node,CommandLine,ProcessId
            if not line.strip() or line.lower().startswith("node,"):
                continue
            parts = [p.strip() for p in line.split(",")]
            if len(parts) < 3:
                continue
            command_line = parts[-2]
            pid_str = parts[-1]
            try:
                pid = int(pid_str)
            except Exception:
                continue
            if "run_team.py" in command_line:
                matches.append((pid, command_line))
        return matches

    # POSIX (macOS/Linux)
    try:
        out = subprocess.check_output(["ps", "-ax", "-o", "pid=,command="], stderr=subprocess.STDOUT, text=True, encoding="utf-8", errors="replace")
    except Exception:
        return []
    for line in out.splitlines():
        line = line.strip()
        if not line:
            continue
        m = re.match(r"^(\d+)\s+(.*)$", line)
        if not m:
            continue
        pid = int(m.group(1))
        cmdline = m.group(2)
        # On POSIX we usually get full command, but still keep it permissive.
        if "run_team.py" in cmdline:
            matches.append((pid, cmdline))
    return matches


def _iter_task_blocks(tasks_md: str) -> Iterable[Tuple[str, str]]:
    """
    Yield (task_id, block_text) for sections that look like:
      ### task-001
      ...
      ### task-002
    """
    pattern = re.compile(r"^###\s+([^\n]+)\s*\n(.*?)(?=^\s*###\s+|\Z)", re.MULTILINE | re.DOTALL)
    for m in pattern.finditer(tasks_md):
        yield m.group(1).strip(), m.group(2)


def _extract_first_field(block: str, field_name: str) -> Optional[str]:
    # Matches "Field: value" or "- Field: value"
    # Also supports markdown-bold labels like "**Field:** value"
    m = re.search(
        rf"^\s*(?:\*\*)?\s*-?\s*{re.escape(field_name)}\s*(?:\*\*)?\s*:\s*(.+?)\s*$",
        block,
        re.MULTILINE | re.IGNORECASE,
    )
    return m.group(1).strip() if m else None


def _check_progress_report_present(project_dir: str) -> CheckResult:
    path = os.path.join(project_dir, "progress_reports", "progress.md")
    content = _read_text(path)
    ok = content is not None and not content.startswith("[ERROR_READING_FILE]")
    details = "" if ok else f"Missing or unreadable: {path}"
    return CheckResult("5.2", "Progress Report Not Created or Updated (presence)", ok, details)


def _check_progress_update_frequency(project_dir: str, now: datetime) -> CheckResult:
    path = os.path.join(project_dir, "progress_reports", "progress.md")
    content = _read_text(path)
    if not content or content.startswith("[ERROR_READING_FILE]"):
        return CheckResult("1.1", "Overall Progress Stagnation (update frequency)", False, f"Missing/unreadable: {path}")

    pct = _parse_progress_overall_percent(content)
    last = _parse_progress_last_updated(content)
    if pct is None or last is None:
        return CheckResult("1.1", "Overall Progress Stagnation (update frequency)", False, "Could not parse Overall Progress and/or Last Updated")

    minutes = (now - last).total_seconds() / 60.0
    if pct < 100.0:
        # Also detect "no overall progress change" even if the report keeps updating.
        # This is the classic "stuck but still alive" failure mode.
        def _parse_duration_minutes(s: str) -> Optional[float]:
            s = (s or "").strip().lower()
            if not s:
                return None
            # Examples:
            # - "0 seconds"
            # - "3 minutes 24 seconds"
            # - "6 hours 51 minutes"
            h = re.search(r"(\d+(?:\.\d+)?)\s*hour", s)
            m = re.search(r"(\d+(?:\.\d+)?)\s*minute", s)
            sec = re.search(r"(\d+(?:\.\d+)?)\s*second", s)
            total = 0.0
            found = False
            if h:
                total += float(h.group(1)) * 60.0
                found = True
            if m:
                total += float(m.group(1))
                found = True
            if sec:
                total += float(sec.group(1)) / 60.0
                found = True
            return total if found else None

        overall_change_str = _extract_first_field(content, "Time Since Last Overall Progress Change")
        overall_change_min = _parse_duration_minutes(overall_change_str) if overall_change_str else None

        ok_update = minutes <= 2.0

        # Match supervisor_issues_checklist.md:
        # - If progress < 100%, the last updated time must be within 2 minutes.
        # - If the last overall progress change is older than 10 minutes, the team is considered stuck.
        #
        # Exception (generic): if there are no READY/IN_PROGRESS tasks and at least one task is explicitly
        # blocked by an ENVIRONMENT blocker (e.g., missing SDK/toolchain), overall progress may legitimately
        # not change for an extended period. In that case we treat the run as environment-gated, not stuck.
        ok_change = True
        if overall_change_min is not None and overall_change_min > 10.0:
            env_gated = False
            try:
                # progress.md formats these as bullet lines like:
                #   - **In Progress:** 3
                #   - **Ready:** 0
                in_prog_m = re.search(r"^\s*-\s*\*\*In Progress:\*\*\s*(\d+)\s*$", content, re.MULTILINE)
                ready_m = re.search(r"^\s*-\s*\*\*Ready:\*\*\s*(\d+)\s*$", content, re.MULTILINE)
                in_prog_n = int(in_prog_m.group(1)) if in_prog_m else None
                ready_n = int(ready_m.group(1)) if ready_m else None
                no_runnable = (in_prog_n == 0 and ready_n == 0) if (in_prog_n is not None and ready_n is not None) else False

                if no_runnable:
                    tasks_path = os.path.join(project_dir, "tasks.md")
                    tasks_md = _read_text(tasks_path) or ""
                    if tasks_md and not tasks_md.startswith("[ERROR_READING_FILE]"):
                        for _tid, block in _iter_task_blocks(tasks_md):
                            st = _extract_first_field(block, "Status")
                            bt = _extract_first_field(block, "Blocker Type")
                            if st and st.strip().lower() == "blocked" and bt and bt.strip().lower() == "environment":
                                env_gated = True
                                break
            except Exception:
                env_gated = False

            ok_change = env_gated

        ok = ok_update and ok_change
        details = f"progress={pct:.1f}%, minutes_since_update={minutes:.1f}"
        if overall_change_min is not None:
            details += f", minutes_since_overall_change={overall_change_min:.1f}"
            if overall_change_min > 10.0 and ok_update and ok_change:
                details += " (environment-gated)"
        return CheckResult("1.1", "Overall Progress Stagnation (update frequency)", ok, details)
    return CheckResult("1.1", "Overall Progress Stagnation (update frequency)", True, f"progress={pct:.1f}% (complete)")


def _check_progress_history_integrity(project_dir: str) -> CheckResult:
    path = os.path.join(project_dir, "progress_reports", "progress.md")
    content = _read_text(path)
    if not content or content.startswith("[ERROR_READING_FILE]"):
        return CheckResult("1.2", "Progress History Anomalies (completed count)", False, f"Missing/unreadable: {path}")

    transitions = _parse_progress_completed_history(content)
    if not transitions:
        # Fresh runs may not have emitted any completed-count transitions yet.
        # This is not evidence of regression; treat as pass with "not enough data yet".
        return CheckResult("1.2", "Progress History Anomalies (completed count)", True, "No completed-count history transitions yet (fresh run)")

    regressed = [(a, b) for (a, b) in transitions if b < a]
    ok = len(regressed) == 0
    details = "No regressions detected" if ok else f"Regressions: {regressed[:5]}"
    return CheckResult("1.2", "Progress History Anomalies (completed count)", ok, details)


def _check_initialization_log(project_dir: str) -> CheckResult:
    path = os.path.join(project_dir, "agent_logs", "team_initialization.log")
    content = _read_text(path)
    if not content or content.startswith("[ERROR_READING_FILE]"):
        return CheckResult("5.3", "Initialization Log Missing or Incomplete", False, f"Missing/unreadable: {path}")
    has_started = "Team initialization started" in content
    has_completed = "Team initialization completed" in content
    ok = has_started and has_completed
    details = f"has_started={has_started}, has_completed={has_completed}"
    return CheckResult("5.3", "Initialization Log Missing or Incomplete", ok, details)


def _check_team_id_present(project_dir: str) -> CheckResult:
    team_id_path = os.path.join(project_dir, ".team_id")
    tid = _read_text(team_id_path)
    if not tid or tid.startswith("[ERROR_READING_FILE]"):
        return CheckResult("6.1", "Team ID Not Present", False, f"Missing/unreadable: {team_id_path}")
    tid = tid.strip().splitlines()[0].strip()
    if not tid:
        return CheckResult("6.1", "Team ID Not Present", False, f"Empty team id file: {team_id_path}")

    progress_path = os.path.join(project_dir, "progress_reports", "progress.md")
    progress = _read_text(progress_path) or ""
    logs_dir = os.path.join(project_dir, "agent_logs")
    ok_progress = tid in progress
    ok_logs = False
    if os.path.isdir(logs_dir):
        # Sample a few logs for presence
        for name in os.listdir(logs_dir)[:20]:
            if not name.lower().endswith(".log"):
                continue
            content = _read_text(os.path.join(logs_dir, name)) or ""
            if tid in content:
                ok_logs = True
                break

    ok = ok_progress or ok_logs
    details = f"team_id={tid}, in_progress_report={ok_progress}, in_any_agent_log={ok_logs}"
    return CheckResult("6.1", "Team ID Not Present", ok, details)


def _check_multiple_teams_running(project_dir: str) -> CheckResult:
    procs = _find_python_run_team_processes(project_dir)
    ok = len(procs) <= 1
    details = f"matching_run_team_processes={len(procs)}"
    if not ok:
        details += f", pids={[p[0] for p in procs][:5]}"
    return CheckResult("6.2", "Multiple Teams Running", ok, details)


def _check_team_process_running_if_incomplete(project_dir: str, now: datetime) -> CheckResult:
    """
    If progress is < 100% and last update is stale, verify there's an active process.
    """
    progress_path = os.path.join(project_dir, "progress_reports", "progress.md")
    progress = _read_text(progress_path)
    if not progress or progress.startswith("[ERROR_READING_FILE]"):
        # Can't assess; fail because we can't validate.
        return CheckResult("6.3", "Team Process Not Running (Stopped / Crashed)", False, f"Missing/unreadable: {progress_path}")

    pct = _parse_progress_overall_percent(progress)
    last = _parse_progress_last_updated(progress)
    if pct is None or last is None:
        return CheckResult("6.3", "Team Process Not Running (Stopped / Crashed)", False, "Could not parse Overall Progress and/or Last Updated")

    minutes = (now - last).total_seconds() / 60.0
    if pct >= 100.0:
        return CheckResult("6.3", "Team Process Not Running (Stopped / Crashed)", True, "Project complete")

    # If fresh updates, don't require process check to pass (team might be between updates).
    if minutes <= 2.0:
        return CheckResult("6.3", "Team Process Not Running (Stopped / Crashed)", True, f"progress={pct:.1f}%, last_update_minutes={minutes:.1f} (fresh)")

    procs = _find_python_run_team_processes(project_dir)
    ok = len(procs) >= 1
    details = f"progress={pct:.1f}%, last_update_minutes={minutes:.1f}, matching_run_team_processes={len(procs)}"
    return CheckResult("6.3", "Team Process Not Running (Stopped / Crashed)", ok, details)


def _check_dependency_parsing_footgun(project_dir: str) -> CheckResult:
    """
    Validates Issue 3.1 - dependency parsing issues.
    Since the parser lives in the team code, we validate via file heuristics.
    """
    tasks_path = os.path.join(project_dir, "tasks.md")
    tasks = _read_text(tasks_path)
    if not tasks or tasks.startswith("[ERROR_READING_FILE]"):
        # tasks.md may legitimately not exist in the earliest initialization phase.
        progress = _read_text(os.path.join(project_dir, "progress_reports", "progress.md")) or ""
        if _parse_progress_total_tasks(progress) == 0:
            return CheckResult("3.1", "Dependency Parsing Issues (\"none\" keyword)", True, "tasks.md not created yet (initialization phase)")
        return CheckResult("3.1", "Dependency Parsing Issues (\"none\" keyword)", False, f"Missing/unreadable: {tasks_path}")
    # Detection should focus on symptoms: tasks with "Dependencies: none" should not get stuck
    # in PENDING/BLOCKED due to the parser treating "none" as a dependency token.
    impacted: List[str] = []
    found_none = False
    for task_id, block in _iter_task_blocks(tasks):
        deps = _extract_first_field(block, "Dependencies")
        if not deps:
            continue
        if not re.fullmatch(r"none|no dependencies|no deps|n/?a|na", deps.strip(), flags=re.IGNORECASE):
            continue

        found_none = True

        # This check is meant to detect the *misparse* where "none" becomes an actual dependency token
        # (e.g., tasks get stuck on "Waiting on dependencies: ['none']"). A task with no dependencies
        # can still be BLOCKED for other reasons (execution failure, acceptance failure), which is OK.
        blocker = (_extract_first_field(block, "Blocker") or "").lower()
        if "waiting on dependencies" in blocker and ("'none'" in blocker or "\"none\"" in blocker or " none" in blocker):
            impacted.append(task_id)

    ok = not impacted
    if not found_none:
        return CheckResult("3.1", "Dependency Parsing Issues (\"none\" keyword)", True, "No 'Dependencies: none' style fields found")
    if ok:
        return CheckResult("3.1", "Dependency Parsing Issues (\"none\" keyword)", True, "Found 'Dependencies: none' fields and none appear to be misparsed into real dependencies")
    return CheckResult(
        "3.1",
        "Dependency Parsing Issues (\"none\" keyword)",
        False,
        f"Tasks with 'Dependencies: none' appear misparsed as real deps (blocked on 'none'): {impacted[:10]}",
    )


def _check_dependency_field_contamination(project_dir: str) -> CheckResult:
    """
    Validates Issue 3.4 - dependency field contamination by other sections (Acceptance Criteria / Artifacts).
    This detects tasks.md corruption patterns that lead to false "Missing dependencies" deadlocks.
    """
    tasks_path = os.path.join(project_dir, "tasks.md")
    tasks = _read_text(tasks_path)
    if not tasks or tasks.startswith("[ERROR_READING_FILE]"):
        progress = _read_text(os.path.join(project_dir, "progress_reports", "progress.md")) or ""
        if _parse_progress_total_tasks(progress) == 0:
            return CheckResult("3.4", "Dependency Field Contamination (section markers parsed as deps)", True, "tasks.md not created yet (initialization phase)")
        return CheckResult("3.4", "Dependency Field Contamination (section markers parsed as deps)", False, f"Missing/unreadable: {tasks_path}")

    # Build the set of task IDs present in this tasks.md (task headings). This keeps the check generic:
    # - supports numeric IDs (task-001) and slugged IDs (task-001-verify-flutter-sdk)
    # - avoids hard-coding any specific ID regex
    task_ids: set[str] = set()
    for tid, _ in _iter_task_blocks(tasks):
        if tid:
            task_ids.add(tid)

    bad: List[str] = []
    for task_id, block in _iter_task_blocks(tasks):
        deps = (_extract_first_field(block, "Dependencies") or "").strip()
        if not deps:
            continue

        tokens = [t.strip() for t in re.split(r"[,;\n]", deps) if t.strip()]
        if len(tokens) == 1 and re.fullmatch(r"none|no dependencies|no deps|n/?a|na", tokens[0], flags=re.IGNORECASE):
            continue

        for t in tokens:
            tt = t.strip().lstrip("- ").strip()
            if not tt:
                continue
            tl = tt.lower()
            if "acceptance criteria" in tl or tl.startswith("artifacts:") or tl.startswith("artifact:") or tl == "task completes successfully":
                bad.append(task_id)
                break
            # Valid dependency iff it is one of the known task IDs in this tasks.md.
            if tt not in task_ids:
                bad.append(task_id)
                break

    bad = sorted(set(bad))
    ok = len(bad) == 0
    details = "OK" if ok else f"Dependencies contain non-task tokens for tasks: {bad[:10]}"
    return CheckResult("3.4", "Dependency Field Contamination (section markers parsed as deps)", ok, details)


def _check_pending_to_ready_timeframe(project_dir: str) -> CheckResult:
    """
    Approximates Issue 2.3 by ensuring there are not many pending tasks when project is active.
    (We can't infer timestamps reliably from tasks.md in all formats.)
    """
    # During initialization, progress.md may exist but still report Total Tasks: 0 while the supervisor
    # is generating tasks or the coordinator hasn't loaded them yet. In that phase, pending counts in
    # tasks.md (if created early) are not evidence of a stuck system.
    progress = _read_text(os.path.join(project_dir, "progress_reports", "progress.md")) or ""
    if _parse_progress_total_tasks(progress) == 0:
        return CheckResult("2.3", "PENDING Tasks Not Transitioning to READY (heuristic)", True, "initialization phase (progress Total Tasks: 0)")

    tasks_path = os.path.join(project_dir, "tasks.md")
    tasks = _read_text(tasks_path)
    if not tasks or tasks.startswith("[ERROR_READING_FILE]"):
        if _parse_progress_total_tasks(progress) == 0:
            return CheckResult("2.3", "PENDING Tasks Not Transitioning to READY (heuristic)", True, "tasks.md not created yet (initialization phase)")
        return CheckResult("2.3", "PENDING Tasks Not Transitioning to READY (heuristic)", False, f"Missing/unreadable: {tasks_path}")
    counts = _parse_tasks_status_counts(tasks)
    # Heuristic: having pending tasks at all may be fine, but large numbers indicate something stuck.
    ok = counts.get("pending", 0) == 0
    details = f"pending={counts.get('pending', 0)} (heuristic expects 0 after initialization)"
    return CheckResult("2.3", "PENDING Tasks Not Transitioning to READY (heuristic)", ok, details)


def _check_requirements_deliverable_sanity(project_dir: str) -> CheckResult:
    """
    Detects a class of failures where progress claims 100% but the deliverable
    is still a template/default scaffold (or required artifacts are missing).
    This stays generic by deriving expectations from requirements.md signals.
    """
    progress_path = os.path.join(project_dir, "progress_reports", "progress.md")
    progress = _read_text(progress_path) or ""
    pct = _parse_progress_overall_percent(progress) if progress else None
    if pct is None:
        return CheckResult("9.1", "Deliverable Sanity vs requirements.md (when complete)", False, "Could not parse Overall Progress to decide whether to enforce deliverable checks")
    if pct < 100.0:
        return CheckResult("9.1", "Deliverable Sanity vs requirements.md (when complete)", True, f"progress={pct:.1f}% (skipped until complete)")

    req_path = os.path.join(project_dir, "requirements.md")
    req = _read_text(req_path)
    if not req or req.startswith("[ERROR_READING_FILE]"):
        return CheckResult("9.1", "Deliverable Sanity vs requirements.md (when complete)", False, f"Missing/unreadable: {req_path}")

    details: List[str] = []

    # 1) Template detection (Flutter default counter demo is a common false-positive completion).
    main_dart_path = os.path.join(project_dir, "lib", "main.dart")
    main_dart = _read_text(main_dart_path) or ""
    if main_dart and "You have pushed the button this many times" in main_dart:
        return CheckResult("9.1", "Deliverable Sanity vs requirements.md (when complete)", False, "lib/main.dart appears to be the default Flutter counter template")

    # 2) Requirements-referenced file paths (best-effort): ensure they exist if mentioned.
    referenced_files: List[str] = []
    for m in re.finditer(r"(?:^|\\s)(lib[\\\\/][^\\s`]+?\\.(?:dart))\\b", req):
        referenced_files.append(m.group(1).replace("\\\\", "/"))
    for m in re.finditer(r"(?:^|\\s)(test[\\\\/][^\\s`]+?\\.(?:dart))\\b", req):
        referenced_files.append(m.group(1).replace("\\\\", "/"))
    # De-dupe
    seen = set()
    referenced_files = [p for p in referenced_files if not (p in seen or seen.add(p))]
    missing_files = [p for p in referenced_files if not os.path.exists(os.path.join(project_dir, p.replace("/", os.sep)))]
    if missing_files:
        details.append(f"missing_required_files={missing_files[:10]}")

    # 3) Dependency sanity (only enforced if requirements mention them)
    pubspec_path = os.path.join(project_dir, "pubspec.yaml")
    pubspec = _read_text(pubspec_path) or ""
    # If requirements mention these packages, pubspec should include them.
    expected_pkgs = ["hive", "hive_flutter", "provider", "path_provider"]
    missing_pkgs: List[str] = []
    for pkg in expected_pkgs:
        if re.search(rf"\\b{re.escape(pkg)}\\b", req, re.IGNORECASE):
            if not re.search(rf"^\\s*{re.escape(pkg)}\\s*:", pubspec, re.MULTILINE):
                missing_pkgs.append(pkg)
    if missing_pkgs:
        details.append(f"pubspec_missing_dependencies={missing_pkgs}")

    ok = len(details) == 0
    return CheckResult("9.1", "Deliverable Sanity vs requirements.md (when complete)", ok, "; ".join(details) if details else "OK")


def run_checks(project_dir: str) -> List[CheckResult]:
    now = datetime.now()
    return [
        _check_progress_report_present(project_dir),
        _check_initialization_log(project_dir),
        _check_progress_update_frequency(project_dir, now),
        _check_progress_history_integrity(project_dir),
        _check_team_id_present(project_dir),
        _check_multiple_teams_running(project_dir),
        _check_team_process_running_if_incomplete(project_dir, now),
        _check_dependency_parsing_footgun(project_dir),
        _check_dependency_field_contamination(project_dir),
        _check_pending_to_ready_timeframe(project_dir),
        _check_requirements_deliverable_sanity(project_dir),
    ]


def _format_results(results: Iterable[CheckResult]) -> str:
    lines: List[str] = []
    failures = 0
    for r in results:
        status = "PASS" if r.ok else "FAIL"
        if not r.ok:
            failures += 1
        suffix = f" — {r.details}" if r.details else ""
        lines.append(f"[{status}] {r.check_id} {r.title}{suffix}")
    lines.append("")
    lines.append(f"Summary: {failures} failed, {sum(1 for _ in results)} total")
    return "\n".join(lines)


def main() -> int:
    parser = argparse.ArgumentParser(description="Validate a project dir against supervisor_issues_checklist.md")
    parser.add_argument("--project-dir", required=True, help="Project directory containing requirements.md / tasks.md / progress_reports / agent_logs")
    args = parser.parse_args()

    project_dir = os.path.abspath(args.project_dir)
    if not os.path.isdir(project_dir):
        print(f"[FAIL] project dir does not exist: {project_dir}")
        return 2

    results = run_checks(project_dir)
    print(_format_results(results))
    return 0 if all(r.ok for r in results) else 1


if __name__ == "__main__":
    raise SystemExit(main())


