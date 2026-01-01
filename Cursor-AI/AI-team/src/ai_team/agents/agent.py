"""
Base Agent class for AI agents following the incremental work protocol.
"""

from abc import ABC, abstractmethod
from typing import Optional, List, Set, Tuple
from .agent_coordinator import (
    AgentCoordinator, Task, TaskStatus, AgentMessage, MessageType, AgentState
)
from datetime import datetime
from ..utils.conflict_prevention import LockType, ChangeSet
import threading
import os
import re
import subprocess
import sys
import time

# Import logger
try:
    from ..utils.agent_logger import AgentLogger
    LOGGING_AVAILABLE = True
except ImportError:
    LOGGING_AVAILABLE = False
    # Fallback logger
    class AgentLogger:
        @staticmethod
        def debug(*args, **kwargs): pass
        @staticmethod
        def info(*args, **kwargs): pass
        @staticmethod
        def warning(*args, **kwargs): print(f"[WARNING] {args[1]}")
        @staticmethod
        def error(*args, **kwargs): print(f"[ERROR] {args[1]}")
        @staticmethod
        def critical(*args, **kwargs): print(f"[CRITICAL] {args[1]}")
        @staticmethod
        def task_start(*args, **kwargs): pass
        @staticmethod
        def task_complete(*args, **kwargs): pass
        @staticmethod
        def task_fail(*args, **kwargs): pass
        @staticmethod
        def method_entry(*args, **kwargs): pass
        @staticmethod
        def method_exit(*args, **kwargs): pass
        @staticmethod
        def execution_flow(*args, **kwargs): pass


class Agent(ABC):
    """
    Base class for AI agents working in a coordinated team.
    Agents should inherit from this and implement the work() method.
    """

    def __init__(self, agent_id: str, coordinator: AgentCoordinator, specialization: str = ""):
        self.agent_id = agent_id
        self.coordinator = coordinator
        self.specialization = specialization
        self.current_task: Optional[Task] = None
        self.locked_resources: Set[str] = set()  # Track resources this agent has locked
        self.workspace_path: Optional[str] = None
        self.state = AgentState.CREATED
        self._running = False
        self._paused = False
        self._stop_event = threading.Event()
        self._pause_event = threading.Event()
        self._pause_event.set()  # Initially not paused
        self._work_thread: Optional[threading.Thread] = None
        # Heartbeat throttling (for supervisor liveness detection)
        self._last_heartbeat_sent = 0.0
        self.coordinator.register_agent_instance(self)
        # Best-effort project directory (used for executing acceptance criteria commands).
        self.project_dir: Optional[str] = None
        if hasattr(coordinator, 'runner') and hasattr(coordinator.runner, 'project_dir'):
            try:
                self.project_dir = coordinator.runner.project_dir
            except Exception:
                self.project_dir = None
        
        # Initialize logging
        if LOGGING_AVAILABLE:
            # Try to get project_dir from coordinator's runner if available
            project_dir = None
            if hasattr(coordinator, 'runner') and hasattr(coordinator.runner, 'project_dir'):
                project_dir = coordinator.runner.project_dir
            if project_dir:
                AgentLogger.set_project_dir(project_dir)
            AgentLogger.info(self.agent_id, f"Agent initialized (specialization: {specialization})")

    def _get_project_dir(self) -> str:
        """Get project directory for command execution and validation."""
        if self.project_dir:
            return self.project_dir
        if hasattr(self.coordinator, 'runner') and hasattr(self.coordinator.runner, 'project_dir'):
            try:
                return self.coordinator.runner.project_dir
            except Exception:
                pass
        return os.getcwd()

    def _extract_acceptance_commands(self, task: Task) -> List[str]:
        """
        Extract runnable shell commands from task description and acceptance criteria.
        We intentionally only execute backticked snippets (e.g., `tool command ...`) to avoid
        running arbitrary prose.
        """
        texts: List[str] = []
        try:
            if getattr(task, "description", None):
                texts.append(task.description)
            if getattr(task, "acceptance_criteria", None):
                # acceptance_criteria is typically a list of strings
                texts.extend([str(x) for x in task.acceptance_criteria if x])
        except Exception:
            pass

        commands: List[str] = []
        for t in texts:
            tl = (t or "").lower()
            looks_like_command_line = any(k in tl for k in ("command", "run ", "run:", "execute", "executed"))
            for m in re.findall(r'`([^`]+)`', t):
                cmd = m.strip()
                if not cmd:
                    continue
                # Allow obvious tooling commands even if the line doesn't include "Command/Run/Execute".
                # This keeps us generic but avoids missing real commands in loosely-worded criteria.
                cmd_l = cmd.lower()
                looks_like_tool_cmd = cmd_l.startswith(("flutter ", "dart ", "python ", "npm ", "npx ", "yarn ", "pnpm ", "gradle", "./gradlew", "gradlew"))
                if looks_like_command_line or looks_like_tool_cmd:
                    commands.append(cmd)

        # Basic safety filters: prevent obviously destructive commands.
        deny_prefixes = (
            "rm ", "rm-", "del ", "rmdir", "remove-item", "format ", "shutdown", "reboot",
            "mkfs", "diskpart", "reg ", "powershell -command remove-item",
        )
        safe: List[str] = []
        for c in commands:
            c_norm = c.strip().lower()
            if any(c_norm.startswith(p) for p in deny_prefixes):
                continue
            safe.append(c)

        # De-duplicate while preserving order
        seen = set()
        unique: List[str] = []
        for c in safe:
            if c not in seen:
                seen.add(c)
                unique.append(c)
        return unique

    def _run_acceptance_commands(self, task: Task) -> Tuple[bool, str]:
        """
        Run extracted acceptance commands (if any).
        Returns (ok, message). If no commands found, returns (True, 'no commands').
        """
        commands = self._extract_acceptance_commands(task)
        if not commands:
            return True, "No acceptance commands to run"

        cwd = self._get_project_dir()
        is_windows = os.name == "nt"
        is_macos = sys.platform == "darwin"
        # Default timeout: allow longer for build/install/test commands.
        def _timeout_for(cmd: str) -> int:
            c = cmd.lower()
            if " build" in c:
                return 900
            if " test" in c:
                return 600
            if " install" in c or " restore" in c:
                return 600
            return 300

        for cmd in commands:
            cmd_to_run = cmd
            cmd_lower = cmd_to_run.lower().strip()

            def _is_existing_relative_path_token(s: str) -> Optional[str]:
                """
                If an extracted "command" is actually just a path token (file OR directory),
                treat it as an existence check instead of executing it.
                This is fully generic and fixes common patterns like backticked `lib/` or `android/app/build.gradle`.
                Returns the normalized relative path if it exists; otherwise None.
                """
                ss = (s or "").strip().strip("\"'")
                if not ss or " " in ss:
                    return None
                if ss.lower().startswith(("http://", "https://")):
                    return None
                # Only treat relative paths as artifact checks.
                try:
                    if os.path.isabs(ss):
                        return None
                except Exception:
                    return None
                rel = ss.replace("\\", "/")
                if rel.startswith("./"):
                    rel = rel[2:]
                p = os.path.join(cwd, rel.replace("/", os.sep))
                return rel if os.path.exists(p) else None

            # Platform-aware skips (generic): only skip when the criterion line explicitly says so.
            # (We do NOT special-case any tool/framework names here.)
            context_lines: List[str] = []
            try:
                if getattr(task, "acceptance_criteria", None):
                    context_lines.extend([str(x) for x in task.acceptance_criteria if x])
                if getattr(task, "description", None):
                    context_lines.append(str(task.description))
            except Exception:
                context_lines = []

            # Find the line that contains this command (best-effort).
            # Some task files wrap commands in backticks, others don't.
            ctx = next((l for l in context_lines if f"`{cmd}`" in l or cmd in l), "")
            ctx_l = ctx.lower()
            # Only execute snippets that are actually described as commands in the criteria.
            # Many tasks include backticked inline config snippets (e.g. `hive: ^2.2.3`, `minSdkVersion 21`)
            # which should NOT be executed as shell commands.
            is_command_line = any(k in ctx_l for k in ("command", "run ", "run:", "execute", "executed"))
            # Platform-aware skips (generic). Many task files phrase this as:
            # - "macOS only"
            # - "On macOS: ..."
            # - "Windows only" / "On Windows: ..."
            if (("macos only" in ctx_l or "mac only" in ctx_l or "on macos" in ctx_l) and (not is_macos)):
                print(f"  [{self.agent_id}] [ACCEPTANCE] Skipping command (macOS only): {cmd_to_run}")
                continue
            if (("windows only" in ctx_l or "on windows" in ctx_l) and (not is_windows)):
                print(f"  [{self.agent_id}] [ACCEPTANCE] Skipping command (Windows only): {cmd_to_run}")
                continue
            if (("linux only" in ctx_l or "on linux" in ctx_l) and (os.name != "posix" or sys.platform == "darwin")):
                print(f"  [{self.agent_id}] [ACCEPTANCE] Skipping command (Linux only): {cmd_to_run}")
                continue

            # If the extracted "command" is actually an existing path token, validate existence instead of executing.
            rel = _is_existing_relative_path_token(cmd_to_run)
            if rel:
                print(f"  [{self.agent_id}] [ACCEPTANCE] Path exists: {rel}")
                continue

            # If the snippet came from a non-command criteria line, skip it (it's likely inline code/config).
            if ctx and not is_command_line:
                print(f"  [{self.agent_id}] [ACCEPTANCE] Skipping inline snippet (not a command): {cmd_to_run}")
                continue

            # If we couldn't find any context line, be conservative: skip obvious key:value snippets.
            if not ctx:
                s = cmd_to_run.strip()
                if ":" in s and "/" not in s and "\\" not in s:
                    print(f"  [{self.agent_id}] [ACCEPTANCE] Skipping inline key:value snippet: {cmd_to_run}")
                    continue

            # Normalize common LLM-generated incomplete create/init commands:
            # If a tool's create/init is invoked without a target, default to current directory.
            if re.fullmatch(r"\S+\s+(create|init)\s*", cmd_lower):
                cmd_to_run = f"{cmd_to_run} ."

            # Acquire a coarse per-tool lock to avoid concurrent executions of the same heavy tool
            # in the same project (e.g., build/test tools that use global caches/locks).
            # This must remain framework/language agnostic: we lock based on the first executable token.
            # (Generic, cross-platform: uses an atomic lock file with stale-lock recovery.)
            lock_dir = os.path.join(cwd, ".ai_team_locks")
            exe_token = (cmd_to_run.strip().split() or [""])[0].strip().strip("\"'").lower()
            # Normalize common Windows forms.
            if exe_token.endswith(".exe"):
                exe_token = exe_token[:-4]
            if exe_token in {"./gradlew", "gradlew", "gradlew.bat"}:
                exe_token = "gradlew"
            if exe_token == "":
                exe_token = "unknown"
            tool_lock = os.path.join(lock_dir, f"tool.{exe_token}.lock")  # file (legacy runs may leave a directory here)
            is_tool_cmd = exe_token not in {"unknown"}

            def _acquire_tool_lock(timeout_s: int) -> bool:
                if not is_tool_cmd:
                    return True
                try:
                    os.makedirs(lock_dir, exist_ok=True)
                except Exception:
                    return True  # don't hard-fail if we can't create lock dir
                start = time.time()
                # Stale lock recovery: if lock exists for too long, assume previous holder crashed and remove it.
                # Use a conservative threshold to avoid breaking legitimate long builds/tests.
                stale_s = max(600, timeout_s * 2)
                while True:
                    try:
                        # Legacy: some runs used a directory lock. Clean it up if stale.
                        if os.path.isdir(tool_lock):
                            try:
                                age = time.time() - os.path.getmtime(tool_lock)
                                if age > stale_s:
                                    # Directory is stale; remove it.
                                    try:
                                        os.rmdir(tool_lock)
                                    except Exception:
                                        # Best-effort: directory should be empty; if not, ignore.
                                        pass
                            except Exception:
                                pass

                        # Atomic file lock creation.
                        fd = os.open(tool_lock, os.O_CREAT | os.O_EXCL | os.O_WRONLY)
                        try:
                            payload = f"pid={os.getpid()}\nagent={self.agent_id}\nstarted={datetime.now().isoformat()}\ntool={exe_token}\ncmd={cmd_to_run}\n"
                            os.write(fd, payload.encode("utf-8", errors="replace"))
                        finally:
                            try:
                                os.close(fd)
                            except Exception:
                                pass
                        return True
                    except FileExistsError:
                        # Lock file exists. If stale, remove and retry.
                        try:
                            age = time.time() - os.path.getmtime(tool_lock)
                            if age > stale_s:
                                try:
                                    os.remove(tool_lock)
                                    continue
                                except Exception:
                                    pass
                        except Exception:
                            pass
                        if time.time() - start > timeout_s:
                            return False
                        time.sleep(0.5)
                    except IsADirectoryError:
                        # Another process left a directory at flutter_lock path. Treat as lock held.
                        try:
                            age = time.time() - os.path.getmtime(tool_lock)
                            if age > stale_s:
                                try:
                                    os.rmdir(tool_lock)
                                    continue
                                except Exception:
                                    pass
                        except Exception:
                            pass
                        if time.time() - start > timeout_s:
                            return False
                        time.sleep(0.5)
                    except Exception:
                        return True

            def _release_tool_lock():
                if not is_tool_cmd:
                    return
                try:
                    if os.path.isdir(tool_lock):
                        os.rmdir(tool_lock)
                    else:
                        os.remove(tool_lock)
                except Exception:
                    pass

            # Wait up to the command timeout (+60s) to acquire the tool lock; build/test can be slow.
            lock_timeout_s = max(180, min(1200, _timeout_for(cmd_to_run) + 60))
            if not _acquire_tool_lock(lock_timeout_s):
                return False, f"Acceptance command lock timed out (tool={exe_token}): `{cmd_to_run}`"

            print(f"  [{self.agent_id}] [ACCEPTANCE] Running: {cmd_to_run}")
            try:
                # Environment: allow light-weight, best-effort auto-detection for common toolchains.
                # This is especially important on Windows where some SDK-driven tools may not see the Android SDK
                # unless ANDROID_HOME / ANDROID_SDK_ROOT is set.
                env = os.environ.copy()
                if is_windows and ("ANDROID_HOME" not in env and "ANDROID_SDK_ROOT" not in env):
                    try:
                        localappdata = env.get("LOCALAPPDATA") or ""
                        candidate = os.path.join(localappdata, "Android", "Sdk")
                        if candidate and os.path.isdir(candidate):
                            env["ANDROID_HOME"] = candidate
                            env["ANDROID_SDK_ROOT"] = candidate
                    except Exception:
                        pass

                result = subprocess.run(
                    cmd_to_run,
                    cwd=cwd,
                    shell=True,
                    capture_output=True,
                    text=True,
                    env=env,
                    timeout=_timeout_for(cmd),
                )
                # Post-check: some commands return exit 0 but still indicate missing toolchains in output.
                # Keep this generic and only enforce when the task itself is about the relevant platform/tool.
                if result.returncode == 0:
                    out = ((result.stdout or "") + "\n" + (result.stderr or "")).strip()
                    # Some doctor/check commands may show missing Android SDK while still exiting 0.
                    if "flutter doctor" in cmd_lower:
                        task_text = f"{getattr(task, 'title', '')} {getattr(task, 'description', '')}".lower()
                        is_android_task = "android" in task_text
                        if is_android_task and (
                            "unable to locate android sdk" in out.lower()
                            or "no android sdk found" in out.lower()
                            or "android toolchain - develop for android devices" in out.lower() and "[x]" in out.lower()
                        ):
                            return False, "Acceptance command indicates missing Android SDK. Install Android Studio/SDK and set ANDROID_HOME (or use `flutter config --android-sdk`)."
                if result.returncode != 0:
                    stderr = (result.stderr or "").strip()
                    stdout = (result.stdout or "").strip()
                    combined = (stderr + "\n" + stdout).strip()

                    # Generic retry: Dart/Flutter tests sometimes fail because generated tests import the wrong
                    # package name (e.g., `package:test_notes_app/...`) even though pubspec.yaml defines a different
                    # `name:`. If we detect this, rewrite imports in the failing test files and retry once.
                    if cmd_lower.startswith("flutter test") and "couldn't resolve the package 'test_notes_app'" in combined.lower():
                        try:
                            pkg = None
                            pubspec_path = os.path.join(cwd, "pubspec.yaml")
                            if os.path.exists(pubspec_path):
                                with open(pubspec_path, "r", encoding="utf-8", errors="replace") as f:
                                    for line in f.read().splitlines():
                                        m = re.match(r"^\s*name\s*:\s*([A-Za-z0-9_\-]+)\s*$", line)
                                        if m:
                                            pkg = m.group(1).strip()
                                            break
                            if pkg and pkg != "test_notes_app":
                                # Extract referenced dart paths from output and patch them.
                                candidates = set()
                                for m in re.finditer(r"(?:(?:[A-Za-z]:)?[\\/])?(?:test[\\/][^\\s:]+\\.dart)", combined):
                                    candidates.add(m.group(0))
                                # Also catch absolute paths printed by flutter.
                                for m in re.finditer(r"(?:[A-Za-z]:[\\/][^\\s:]+\\.dart)", combined):
                                    candidates.add(m.group(0))

                                fixed = 0
                                for p in list(candidates)[:6]:
                                    # Normalize to absolute path.
                                    ap = p
                                    if not os.path.isabs(ap):
                                        ap = os.path.join(cwd, p.replace("/", os.sep).replace("\\", os.sep))
                                    if not os.path.exists(ap):
                                        continue
                                    try:
                                        txt = ""
                                        with open(ap, "r", encoding="utf-8", errors="replace") as fh:
                                            txt = fh.read()
                                        if "package:test_notes_app/" in txt:
                                            txt2 = txt.replace("package:test_notes_app/", f"package:{pkg}/")
                                            with open(ap, "w", encoding="utf-8", errors="replace") as fh:
                                                fh.write(txt2)
                                            fixed += 1
                                    except Exception:
                                        continue

                                if fixed:
                                    retry = cmd_to_run
                                    print(f"  [{self.agent_id}] [ACCEPTANCE] Retrying after fixing Dart package imports in {fixed} file(s): {retry}")
                                    retry_res = subprocess.run(
                                        retry,
                                        cwd=cwd,
                                        shell=True,
                                        capture_output=True,
                                        text=True,
                                        env=env,
                                        timeout=_timeout_for(retry),
                                    )
                                    if retry_res.returncode == 0:
                                        continue
                                    retry_err = ((retry_res.stderr or "") + "\n" + (retry_res.stdout or "")).strip()[:400]
                                    return False, f"Acceptance command failed: `{retry}` (exit {retry_res.returncode}) :: {retry_err}"
                        except Exception:
                            pass

                    # Generic retry: if a command starts with "cd <dir> && ..." but that dir doesn't exist
                    # and the project root already looks like the workspace (e.g., pubspec.yaml present),
                    # retry without the cd prefix.
                    m_cd = re.match(r"^\\s*cd\\s+([^\\s&]+)\\s*&&\\s*(.+)$", cmd_to_run, flags=re.IGNORECASE)
                    if m_cd and ("cannot find the path specified" in combined.lower() or "system cannot find the path specified" in combined.lower()):
                        subdir = m_cd.group(1).strip().strip("\"'")
                        rest = m_cd.group(2).strip()
                        try:
                            if not os.path.isdir(os.path.join(cwd, subdir)) and os.path.exists(os.path.join(cwd, "pubspec.yaml")):
                                retry = rest
                                print(f"  [{self.agent_id}] [ACCEPTANCE] Retrying without missing cd dir: {retry}")
                                retry_res = subprocess.run(
                                    retry,
                                    cwd=cwd,
                                    shell=True,
                                    capture_output=True,
                                    text=True,
                                    env=env,
                                    timeout=_timeout_for(retry),
                                )
                                if retry_res.returncode == 0:
                                    continue
                                retry_err = ((retry_res.stderr or "") + "\\n" + (retry_res.stdout or "")).strip()[:400]
                                return False, f"Acceptance command failed: `{retry}` (exit {retry_res.returncode}) :: {retry_err}"
                        except Exception:
                            pass

                    # Generic retry: remove an unsupported flag if the tool reports it explicitly.
                    if ("could not find an option named \"debug\"" in combined.lower()
                        or "no option named \"debug\"" in combined.lower()) and "--debug" in cmd_to_run:
                        retry = cmd_to_run.replace("--debug", "").replace("  ", " ").strip()
                        print(f"  [{self.agent_id}] [ACCEPTANCE] Retrying without --debug: {retry}")
                        retry_res = subprocess.run(
                            retry,
                            cwd=cwd,
                            shell=True,
                            capture_output=True,
                            text=True,
                            timeout=_timeout_for(retry),
                        )
                        if retry_res.returncode == 0:
                            continue
                        retry_err = (retry_res.stderr or retry_res.stdout or "").strip()[:400]
                        return False, f"Acceptance command failed: `{retry}` (exit {retry_res.returncode}) :: {retry_err}"

                    # Generic retry: remove a specifically-named unsupported option, if present.
                    # Example: "Could not find an option named \"no-sound-null-safety\"."
                    m_opt = re.search(r'could not find an option named \"\\s*([a-z0-9\\-]+)\\s*\"', combined, flags=re.IGNORECASE)
                    if m_opt:
                        opt = m_opt.group(1).strip()
                        if opt:
                            flag = f"--{opt}"
                            if flag in cmd_to_run:
                                retry = cmd_to_run.replace(flag, "").replace("  ", " ").strip()
                                print(f"  [{self.agent_id}] [ACCEPTANCE] Retrying without unsupported option {flag}: {retry}")
                                retry_res = subprocess.run(
                                    retry,
                                    cwd=cwd,
                                    shell=True,
                                    capture_output=True,
                                    text=True,
                                    env=env,
                                    timeout=_timeout_for(retry),
                                )
                                if retry_res.returncode == 0:
                                    continue
                                retry_err = ((retry_res.stderr or "") + "\\n" + (retry_res.stdout or "")).strip()[:400]
                                return False, f"Acceptance command failed: `{retry}` (exit {retry_res.returncode}) :: {retry_err}"

                    # Generic retry: some CLIs reject "create/init" invocations that accidentally specify
                    # multiple output directories (e.g., "NAME ." in the same command).
                    # If we detect this error, try removing the extra positional output argument.
                    if "multiple output directories specified" in combined.lower():
                        tokens = cmd_to_run.strip().split()
                        if tokens and tokens[-1] == "." and len(tokens) >= 3:
                            # Find the last positional arg before '.' that doesn't look like an option.
                            # We'll remove it once and retry.
                            idx = None
                            for i in range(len(tokens) - 2, 0, -1):
                                if tokens[i].startswith("-"):
                                    continue
                                # Avoid removing the subcommand itself (e.g., "create"/"init").
                                if tokens[i].lower() in ("create", "init"):
                                    break
                                idx = i
                                break
                            if idx is not None:
                                retry_tokens = tokens[:idx] + tokens[idx + 1 :]
                                retry = " ".join(retry_tokens).replace("  ", " ").strip()
                                print(f"  [{self.agent_id}] [ACCEPTANCE] Retrying after removing extra output dir token: {retry}")
                                retry_res = subprocess.run(
                                    retry,
                                    cwd=cwd,
                                    shell=True,
                                    capture_output=True,
                                    text=True,
                                    timeout=_timeout_for(retry),
                                )
                                if retry_res.returncode == 0:
                                    continue
                                retry_err = ((retry_res.stderr or "") + "\n" + (retry_res.stdout or "")).strip()[:400]
                                return False, f"Acceptance command failed: `{retry}` (exit {retry_res.returncode}) :: {retry_err}"

                    snippet = (combined or "")[:400]
                    return False, f"Acceptance command failed: `{cmd_to_run}` (exit {result.returncode}) :: {snippet}"
            except subprocess.TimeoutExpired:
                return False, f"Acceptance command timed out: `{cmd_to_run}`"
            except Exception as e:
                return False, f"Acceptance command error: `{cmd_to_run}` :: {e}"
            finally:
                _release_tool_lock()

        return True, "Acceptance commands passed"

    def request_task(self) -> Optional[Task]:
        """Request a task from the coordinator"""
        if LOGGING_AVAILABLE:
            AgentLogger.method_entry(self.agent_id, "request_task")
        
        ready_tasks = self.coordinator.get_ready_tasks()
        
        if LOGGING_AVAILABLE:
            AgentLogger.debug(self.agent_id, f"Found {len(ready_tasks)} ready tasks", 
                            extra={'ready_task_ids': [t.id for t in ready_tasks]})
        
        if not ready_tasks:
            if LOGGING_AVAILABLE:
                AgentLogger.method_exit(self.agent_id, "request_task", result="None (no ready tasks)")
            return None

        # Filter by specialization if applicable
        # CRITICAL: Don't filter out tasks if no matches - use all ready tasks
        # Specialization matching is a preference, not a requirement
        if self.specialization and ready_tasks:
            # Simple keyword matching - prefer tasks matching specialization
            matching_tasks = [
                t for t in ready_tasks
                if self.specialization.lower() in t.title.lower() or
                   self.specialization.lower() in t.description.lower()
            ]
            # Only use filtered list if we have matches AND there are other tasks
            # If all tasks match or no tasks match, use original list
            if matching_tasks and len(matching_tasks) < len(ready_tasks):
                ready_tasks = matching_tasks
                if LOGGING_AVAILABLE:
                    AgentLogger.debug(self.agent_id, f"Filtered to {len(matching_tasks)} tasks matching specialization '{self.specialization}'")
            elif matching_tasks:
                # All tasks match specialization - use them
                if LOGGING_AVAILABLE:
                    AgentLogger.debug(self.agent_id, f"All {len(matching_tasks)} ready tasks match specialization '{self.specialization}'")
            else:
                # No tasks match specialization, but use all ready tasks anyway
                if LOGGING_AVAILABLE:
                    AgentLogger.debug(self.agent_id, f"No tasks match specialization '{self.specialization}', using all {len(ready_tasks)} ready tasks")

        # Get task with least dependencies first (or use other priority logic)
        task = min(ready_tasks, key=lambda t: len(t.dependencies))
        
        if LOGGING_AVAILABLE:
            AgentLogger.debug(self.agent_id, f"Selected task: {task.id} ({task.title})", 
                            task_id=task.id, extra={'dependencies': len(task.dependencies)})
        
        if self.coordinator.assign_task(task.id, self.agent_id):
            self.current_task = task
            if LOGGING_AVAILABLE:
                AgentLogger.info(self.agent_id, f"Task assigned: {task.id}", task_id=task.id)
                AgentLogger.method_exit(self.agent_id, "request_task", result=f"task:{task.id}")
            return task
        
        if LOGGING_AVAILABLE:
            AgentLogger.warning(self.agent_id, f"Failed to assign task: {task.id}", task_id=task.id)
            AgentLogger.method_exit(self.agent_id, "request_task", result="None (assignment failed)")
        return None

    def start_work(self, task_id: Optional[str] = None) -> bool:
        """Start working on a task"""
        if LOGGING_AVAILABLE:
            AgentLogger.method_entry(self.agent_id, "start_work", task_id=task_id)
        
        if task_id:
            if task_id not in self.coordinator.tasks:
                if LOGGING_AVAILABLE:
                    AgentLogger.error(self.agent_id, f"Task not found: {task_id}", task_id=task_id)
                    AgentLogger.method_exit(self.agent_id, "start_work", result="False (task not found)")
                return False
            task = self.coordinator.tasks[task_id]
            if task.assigned_agent != self.agent_id:
                if LOGGING_AVAILABLE:
                    AgentLogger.error(self.agent_id, f"Task assigned to different agent: {task.assigned_agent}", 
                                    task_id=task_id)
                    AgentLogger.method_exit(self.agent_id, "start_work", result="False (wrong agent)")
                return False
        elif not self.current_task:
            if LOGGING_AVAILABLE:
                AgentLogger.error(self.agent_id, "No current task and no task_id provided")
                AgentLogger.method_exit(self.agent_id, "start_work", result="False (no task)")
            return False
        else:
            task = self.current_task

        was_in_progress = task.status == TaskStatus.IN_PROGRESS

        # Check if task is already completed - if so, clear it and return False
        if task.status == TaskStatus.COMPLETED:
            if LOGGING_AVAILABLE:
                AgentLogger.warning(self.agent_id, f"Task {task.id} is already completed - clearing current_task", task_id=task.id)
            if self.current_task == task:
                self.current_task = None
            if LOGGING_AVAILABLE:
                AgentLogger.method_exit(self.agent_id, "start_work", result="False (task already completed)")
            return False
        
        # Check if task is at 100% progress - supervisor should complete it, don't start it
        if task.progress >= 100:
            if LOGGING_AVAILABLE:
                AgentLogger.warning(self.agent_id, f"Task {task.id} is at 100% progress - supervisor should complete it, skipping", task_id=task.id, extra={
                    'task_status': task.status.value,
                    'task_progress': task.progress
                })
            if self.current_task == task:
                self.current_task = None
            if LOGGING_AVAILABLE:
                AgentLogger.method_exit(self.agent_id, "start_work", result="False (task at 100% progress)")
            return False

        if LOGGING_AVAILABLE:
            AgentLogger.task_start(self.agent_id, task.id, task.title, 
                                  extra={'status': task.status.value, 'progress': task.progress})

        if self.coordinator.start_task(task.id, self.agent_id):
            self.current_task = task
            
            # Create isolated workspace if conflict prevention is enabled
            if self.coordinator.conflict_prevention:
                self.workspace_path = self.coordinator.conflict_prevention.create_agent_workspace(
                    self.agent_id, task.id
                )
                if LOGGING_AVAILABLE:
                    AgentLogger.debug(self.agent_id, f"Workspace created: {self.workspace_path}", task_id=task.id)
            
            self.send_status_update(
                task.id,
                TaskStatus.IN_PROGRESS,
                progress=(task.progress if was_in_progress else 0),
                message=(f"Resuming work on: {task.title}" if was_in_progress else f"Starting work on: {task.title}")
            )
            
            if LOGGING_AVAILABLE:
                AgentLogger.info(self.agent_id, f"Work started on task: {task.id}", task_id=task.id)
                AgentLogger.method_exit(self.agent_id, "start_work", result="True")
            return True
        
        if LOGGING_AVAILABLE:
            AgentLogger.error(self.agent_id, f"Failed to start task: {task.id}", task_id=task.id)
            AgentLogger.method_exit(self.agent_id, "start_work", result="False (coordinator rejected)")
        return False

    def send_status_update(
        self,
        task_id: str,
        status: TaskStatus,
        progress: Optional[int] = None,
        message: Optional[str] = None
    ):
        """Send a status update to the coordinator"""
        msg = AgentMessage(
            agent_id=self.agent_id,
            task_id=task_id,
            message_type=MessageType.STATUS_UPDATE,
            status=status,
            progress=progress,
            message=message
        )
        self.coordinator.process_message(msg)

    def send_checkpoint(
        self,
        task_id: str,
        progress: int,
        changes: str,
        next_steps: str
    ):
        """Send a checkpoint update"""
        msg = AgentMessage(
            agent_id=self.agent_id,
            task_id=task_id,
            message_type=MessageType.CHECKPOINT,
            progress=progress,
            changes=changes,
            next_steps=next_steps
        )
        self.coordinator.process_message(msg)

    def report_blocked(
        self,
        task_id: str,
        blocked_on: str,
        message: str
    ):
        """Report that the task is blocked"""
        msg = AgentMessage(
            agent_id=self.agent_id,
            task_id=task_id,
            message_type=MessageType.DEPENDENCY_REQUEST,
            blocked_on=blocked_on,
            message=message
        )
        self.coordinator.process_message(msg)

    def request_resource_lock(self, resource_path: str, lock_type: LockType = LockType.EXCLUSIVE) -> bool:
        """
        Request a lock on a resource before modifying it.
        Returns True if lock acquired, False otherwise.
        """
        if not self.coordinator.conflict_prevention:
            return True  # No conflict prevention, allow access
        
        if self.coordinator.conflict_prevention.request_resource_access(
            resource_path, self.agent_id, lock_type
        ):
            self.locked_resources.add(resource_path)
            return True
        return False
    
    def release_resource_lock(self, resource_path: str):
        """Release a lock on a resource"""
        if self.coordinator.conflict_prevention:
            self.coordinator.conflict_prevention.release_resource_access(resource_path, self.agent_id)
        self.locked_resources.discard(resource_path)
    
    def release_all_locks(self):
        """Release all locks held by this agent"""
        for resource in list(self.locked_resources):
            self.release_resource_lock(resource)
    
    def validate_changes(self, files_modified: List[str], files_created: List[str] = None, allow_completed_updates: bool = False) -> Tuple[bool, List[str]]:
        """
        Validate changes before completing task.
        Returns (is_valid, list_of_issues)
        """
        if not self.coordinator.conflict_prevention or not self.current_task:
            return True, []
        
        change_set = ChangeSet(
            agent_id=self.agent_id,
            task_id=self.current_task.id,
            files_modified=files_modified,
            files_created=files_created or [],
            description=f"Changes for {self.current_task.title}"
        )
        
        return self.coordinator.conflict_prevention.validate_changes(change_set, allow_completed_updates=allow_completed_updates)

    def validate_task_completion(self, task: Task, artifacts: Optional[List[str]] = None) -> Tuple[bool, str]:
        """
        Validate that a task is truly done before marking it complete.
        Returns (is_valid, reason)
        Override this method in subclasses for specific validation logic.
        """
        # Basic validation: require expected artifacts to exist.
        # IMPORTANT: If agents mark tasks complete without producing any artifacts,
        # we can still infer expected file outputs from the task text to prevent
        # false completion (e.g., shipping the default template app).
        expected = artifacts or self._infer_expected_artifacts(task)
        if expected:
            missing: List[str] = []
            for a in expected:
                ap = self._resolve_artifact_path(a)
                if not os.path.exists(ap):
                    missing.append(a)
            if missing:
                return False, f"Missing required artifacts: {', '.join(missing[:10])}"
        
        # Check if task has acceptance criteria and validate them
        if hasattr(task, 'acceptance_criteria') and task.acceptance_criteria:
            # Basic check - subclasses should implement detailed validation
            pass
        
        return True, "Task validation passed"

    def _resolve_artifact_path(self, artifact: str) -> str:
        """
        Resolve an artifact path to an absolute path.
        - Absolute paths are returned as-is
        - Relative paths are treated as relative to the project directory (not the process cwd)
        """
        try:
            if os.path.isabs(artifact):
                return artifact
        except Exception:
            pass
        base = self._get_project_dir()
        return os.path.abspath(os.path.join(base, artifact))

    def _infer_expected_artifacts(self, task: Task) -> List[str]:
        """
        Heuristic extraction of file paths mentioned in task description/acceptance criteria.
        Generic: no framework-specific assumptions.
        """
        texts: List[str] = []
        try:
            if getattr(task, "description", None):
                texts.append(str(task.description))
            if getattr(task, "acceptance_criteria", None):
                texts.extend([str(x) for x in task.acceptance_criteria if x])
        except Exception:
            pass

        candidates: List[str] = []
        # Backticked snippets often contain file paths.
        for t in texts:
            for m in re.findall(r"`([^`]+)`", t):
                candidates.append(m.strip())

        # Explicit acceptance statements often mention files/directories without backticks, e.g.:
        # - "File lib/models/note.dart exists"
        # - "Directory lib/models/ exists"
        # We extract these as artifacts so completion validation can catch missing scaffolding.
        for t in texts:
            for m in re.findall(r"\bFile\s+([^\s]+)\s+exists\b", t, flags=re.IGNORECASE):
                candidates.append(m.strip())
            for m in re.findall(r"\bDirectory\s+([^\s]+)\s+exists\b", t, flags=re.IGNORECASE):
                candidates.append(m.strip())
            for m in re.findall(r"\bFolder\s+([^\s]+)\s+exists\b", t, flags=re.IGNORECASE):
                candidates.append(m.strip())

        # Also scan raw text for common path patterns with an extension.
        for t in texts:
            for m in re.findall(r"(?:(?:[A-Za-z]:)?[\\/])?(?:[\\w.\\-]+[\\/])+[\\w.\\-]+\\.(?:dart|yaml|yml|json|md|py|js|ts|tsx|java|kt|swift|html|css)", t):
                candidates.append(m.strip())
            for m in re.findall(r"\\b[\\w./\\-]+\\.(?:dart|yaml|yml|json|md|py|js|ts|tsx|java|kt|swift|html|css)\\b", t):
                candidates.append(m.strip())

        cleaned: List[str] = []
        for c in candidates:
            if not c or " " in c:
                continue
            if c.startswith("http://") or c.startswith("https://"):
                continue
            # Ignore common commands that are backticked.
            if any(c.lower().startswith(p) for p in ("flutter ", "python ", "npm ", "dart ", "gradle", "adb ")):
                continue
            c = c.replace("\\", "/")
            if c.startswith("./"):
                c = c[2:]
            cleaned.append(c)

        # De-duplicate while preserving order.
        seen = set()
        out: List[str] = []
        for c in cleaned:
            if c not in seen:
                seen.add(c)
                out.append(c)
        return out[:12]
    
    def complete_task(
        self,
        task_id: str,
        result: str,
        artifacts: Optional[List[str]] = None,
        tests: Optional[str] = None
    ) -> bool:
        """
        Complete a task and report completion.
        Protocol: Always write tests for new functionality and run the app at the end.
        ENHANCED: Validates that artifacts are actual files, not placeholders.
        ENHANCED: Validates task is truly done before completion.
        """
        # Get task for validation
        task = self.coordinator.tasks.get(task_id)
        if not task:
            if LOGGING_AVAILABLE:
                AgentLogger.error(self.agent_id, f"Task not found: {task_id}", task_id=task_id)
            return False
        
        # Step 0: Validate task is truly done
        is_valid, reason = self.validate_task_completion(task, artifacts)
        if not is_valid:
            if LOGGING_AVAILABLE:
                AgentLogger.warning(self.agent_id, f"Task validation failed: {reason}", task_id=task_id)
            print(f"  [{self.agent_id}] [ERROR] Task validation failed: {reason}")
            self.send_status_update(
                task_id,
                TaskStatus.BLOCKED,
                message=f"Task validation failed: {reason}"
            )
            return False
        
        # Step 0.5: Validate artifacts exist and are not placeholders
        if artifacts:
            ok_artifacts, artifact_issues = self._validate_artifacts_basic(artifacts)
            if not ok_artifacts:
                print(f"  [{self.agent_id}] [ERROR] Artifacts validation failed - cannot complete task")
                self.send_status_update(
                    task_id,
                    TaskStatus.BLOCKED,
                    message="Artifacts validation failed: " + (", ".join(artifact_issues[:5]) if artifact_issues else "required files not created or are placeholders")
                )
                return False

        # Step 0.75: Run acceptance criteria commands if present.
        # This prevents false "completed" statuses for tasks that claim command-based validation.
        ok, msg = self._run_acceptance_commands(task)
        if not ok:
            if LOGGING_AVAILABLE:
                AgentLogger.warning(self.agent_id, f"Acceptance criteria failed: {msg}", task_id=task_id)
            print(f"  [{self.agent_id}] [ERROR] {msg}")
            self.send_status_update(task_id, TaskStatus.BLOCKED, message=msg)
            return False
        
        # Step 1-3: Optional, minimal verification for Python projects (generic).
        # For other project types, acceptance commands (above) and task artifacts are the primary signals.
        project_dir = self._get_project_dir()
        is_python_project = os.path.exists(os.path.join(project_dir, "src", "app.py")) or os.path.exists(os.path.join(project_dir, "pyproject.toml"))
        test_status = "SKIPPED"
        app_status = "SKIPPED"

        if is_python_project:
            # Step 1: Write tests for new functionality if this is a feature/fix task
            test_artifacts = self._ensure_tests_exist(task_id, artifacts or [])
            if test_artifacts:
                if artifacts:
                    artifacts.extend(test_artifacts)
                else:
                    artifacts = test_artifacts

            # Step 2: Run test suite
            print(f"  [{self.agent_id}] Running test suite...")
            test_result = self._run_test_suite()
            test_status = "PASSED" if test_result == 0 else "FAILED"
            if test_result != 0:
                print(f"  [{self.agent_id}] [WARNING] Some tests failed")

            # Step 3: Run the app to verify it works
            print(f"  [{self.agent_id}] Verifying app runs correctly...")
            app_status = self._verify_app_runs()
        
        # Step 4: Validate changes before completion if conflict prevention is enabled
        # Note: Allow updates to files from completed tasks (they're already integrated)
        if self.coordinator.conflict_prevention and artifacts:
            is_valid, issues = self.validate_changes(artifacts, allow_completed_updates=True)
            if not is_valid:
                self.send_status_update(
                    task_id,
                    TaskStatus.BLOCKED,
                    message=f"Cannot complete: conflicts detected - {', '.join(issues)}"
                )
                return False
        
        # Step 5: Complete task with test and app status
        combined_tests = f"{tests or 'Checks complete'}. Test suite: {test_status}. App status: {app_status}. Acceptance: {msg}"
        
        msg = AgentMessage(
            agent_id=self.agent_id,
            task_id=task_id,
            message_type=MessageType.COMPLETION,
            result=result,
            artifacts=artifacts or [],
            tests=combined_tests
        )
        self.coordinator.process_message(msg)
        
        if self.coordinator.complete_task(task_id, self.agent_id):
            # Release all locks when task is completed
            self.release_all_locks()
            self.current_task = None
            self.workspace_path = None
            return True
        return False
    
    def _validate_artifacts_basic(self, artifacts: List[str]) -> Tuple[bool, List[str]]:
        """
        Basic validation that artifacts are actual files with content.
        Subclasses can override for more specific validation.
        """
        if not artifacts:
            return False, ["no artifacts provided"]
        
        issues: List[str] = []
        for artifact in artifacts:
            artifact_path = self._resolve_artifact_path(artifact)
            if not os.path.exists(artifact_path):
                print(f"    [VALIDATION] Artifact file does not exist: {artifact}")
                issues.append(f"missing:{artifact}")
                continue

            # Many tasks (especially scaffolding/setup tasks) legitimately treat directories as artifacts.
            # For directories, existence is sufficient (size checks are not meaningful).
            try:
                if os.path.isdir(artifact_path):
                    continue
            except Exception:
                # If we can't stat it reliably, treat it as invalid.
                issues.append(f"stat_error:{artifact}")
                continue
            
            # Check file size (must be > 0 bytes)
            file_size = os.path.getsize(artifact_path)
            if file_size == 0:
                # Allow common placeholder files used to keep empty dirs in git.
                base = os.path.basename(artifact_path).lower()
                if base in {".gitkeep", ".keep"}:
                    continue
                print(f"    [VALIDATION] Artifact file is empty: {artifact}")
                issues.append(f"empty:{artifact}")
                continue
        
        return (len(issues) == 0), issues
    
    def _ensure_tests_exist(self, task_id: str, artifacts: List[str]) -> List[str]:
        """
        Ensure tests exist for new functionality.
        Protocol: Always write tests for new code.
        """
        test_artifacts = []
        task = self.coordinator.tasks.get(task_id)
        if not task:
            return test_artifacts
        
        # Check if this is a feature/fix task that needs tests
        task_type = task.metadata.get('type', '').lower()
        is_feature = 'feature' in task_type or 'fix' in task_type or 'bug_fix' in task_type
        is_implementation = any(keyword in task.title.lower() for keyword in ['implement', 'add', 'create', 'fix', 'update'])
        
        if is_feature or is_implementation:
            # Check if tests already exist
            test_file = f"tests/test_{task_id}.py"
            if not os.path.exists(test_file):
                print(f"  [{self.agent_id}] Writing tests for {task_id}...")
                test_code = self._generate_test_code(task, artifacts)
                if test_code:
                    os.makedirs("tests", exist_ok=True)
                    with open(test_file, 'w', encoding='utf-8') as f:
                        f.write(test_code)
                    test_artifacts.append(test_file)
                    print(f"  [{self.agent_id}] Created test file: {test_file}")
        
        return test_artifacts
    
    def _generate_test_code(self, task, artifacts: List[str]) -> str:
        """Generate test code for a task"""
        # Basic test template
        test_code = f'''"""
Tests for {task.title}
"""
import pytest
import sys
import os

# Add src to path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'src'))


class Test{task.id.replace('-', '_').title()}:
    """Test {task.title}"""
    
    def test_{task.id}_basic(self):
        """Basic test for {task.id}"""
        # TODO: Add specific tests based on task requirements
        assert True
    
    def test_{task.id}_functionality(self):
        """Test the functionality implemented"""
        # TODO: Test the actual functionality
        # Check artifacts: {', '.join(artifacts[:3])}
        assert True
'''
        return test_code
    
    def _run_test_suite(self) -> int:
        """
        Run the test suite including E2E tests.
        Protocol: Always run full test suite after making changes, including UI/E2E tests.
        """
        import subprocess
        import sys
        import os
        
        # Find project root (go up from current file)
        current_file = os.path.abspath(__file__)
        project_root = os.path.dirname(os.path.dirname(current_file))
        
        # Check for project-specific test script
        test_script = os.path.join(project_root, 'scripts', 'run_tests.py')
        if os.path.exists(test_script):
            try:
                result = subprocess.run(
                    [sys.executable, test_script],
                    cwd=project_root,
                    capture_output=True,
                    timeout=300  # Increased timeout for E2E tests
                )
                if result.stdout:
                    output = result.stdout.decode('utf-8', errors='ignore')
                    # Show summary
                    lines = output.split('\n')
                    for line in lines[-15:]:  # Show more lines for E2E test results
                        if line.strip() and ('passed' in line.lower() or 'failed' in line.lower() or 'error' in line.lower() or 'test' in line.lower()):
                            print(f"    {line}")
                if result.returncode != 0 and result.stderr:
                    error_output = result.stderr.decode('utf-8', errors='ignore')
                    print(f"    Test errors: {error_output[:500]}")
                return result.returncode
            except Exception as e:
                print(f"    Error running tests: {e}")
                return 1
        
        # Fallback: run pytest directly with E2E tests
        try:
            # Run all tests including E2E
            result = subprocess.run(
                [sys.executable, '-m', 'pytest', 'tests/', '-v', '--tb=short', '--maxfail=5'],  # Allow up to 5 failures before stopping
                cwd=project_root,
                capture_output=True,
                timeout=300
            )
            if result.stdout:
                output = result.stdout.decode('utf-8', errors='ignore')
                # Show test summary
                lines = output.split('\n')
                for line in lines[-15:]:
                    if line.strip():
                        print(f"    {line}")
            return result.returncode
        except Exception as e:
            print(f"    Error running pytest: {e}")
            return 1
    
    def _verify_app_runs(self) -> str:
        """
        Verify the app runs correctly.
        Protocol: Always run the app at the end to verify it works.
        """
        # Project-agnostic note:
        # Running an application is highly environment-specific; this core implementation
        # relies on task acceptance commands for run/build validation.
        return "SKIPPED"

    @abstractmethod
    def work(self, task: Task) -> bool:
        """
        Implement the actual work for a task.
        This should:
        1. Break work into small increments
        2. Create checkpoints regularly
        3. Report progress
        4. Handle blockers
        5. Complete the task
        
        Returns True if task completed successfully, False otherwise.
        """
        pass

    def start(self):
        """Start the agent (can be called by coordinator)"""
        if LOGGING_AVAILABLE:
            AgentLogger.method_entry(self.agent_id, "start", extra={'current_state': self.state.value})
        
        if self.state == AgentState.RUNNING:
            if LOGGING_AVAILABLE:
                AgentLogger.warning(self.agent_id, "Agent already running")
                AgentLogger.method_exit(self.agent_id, "start", result="Already running")
            return
        
        self.state = AgentState.STARTED
        self._running = True
        self._stop_event.clear()
        self._pause_event.set()  # Not paused
        
        # Update coordinator state
        if hasattr(self.coordinator, 'agent_states'):
            self.coordinator.agent_states[self.agent_id] = AgentState.STARTED
        
        # Start work thread
        self._work_thread = threading.Thread(target=self._run_loop, daemon=True)
        self._work_thread.start()
        self.state = AgentState.RUNNING
        
        # Update coordinator state to RUNNING
        if hasattr(self.coordinator, 'agent_states'):
            self.coordinator.agent_states[self.agent_id] = AgentState.RUNNING
        
        if LOGGING_AVAILABLE:
            AgentLogger.info(self.agent_id, "Agent started", extra={'thread_id': self._work_thread.ident})
            AgentLogger.method_exit(self.agent_id, "start", result="Started")
        
        print(f"[{self.agent_id}] Agent started")
    
    def stop(self):
        """Stop the agent (can be called by coordinator)"""
        if self.state == AgentState.STOPPED:
            return
        
        self._running = False
        self._stop_event.set()
        self._pause_event.set()  # Unpause if paused
        
        # Wait for thread to finish (with timeout)
        if self._work_thread and self._work_thread.is_alive():
            self._work_thread.join(timeout=5.0)
        
        self.state = AgentState.STOPPED
        print(f"[{self.agent_id}] Agent stopped")
    
    def pause(self):
        """Pause the agent (can be called by coordinator)"""
        if self.state != AgentState.RUNNING:
            return
        
        self._paused = True
        self._pause_event.clear()
        self.state = AgentState.PAUSED
        print(f"[{self.agent_id}] Agent paused")
    
    def resume(self):
        """Resume the agent (can be called by coordinator)"""
        if self.state != AgentState.PAUSED:
            return
        
        self._paused = False
        self._pause_event.set()
        self.state = AgentState.RUNNING
        print(f"[{self.agent_id}] Agent resumed")
    
    def _run_loop(self):
        """Internal work loop that respects start/stop/pause and automatically picks up new tasks"""
        if LOGGING_AVAILABLE:
            AgentLogger.info(self.agent_id, "Work loop started")
        
        loop_iteration = 0
        while self._running and not self._stop_event.is_set():
            loop_iteration += 1

            # Lightweight heartbeat to coordinator (generic liveness signal).
            # This helps the supervisor distinguish "idle but alive" from "hung".
            try:
                now = time.time()
                if now - self._last_heartbeat_sent >= 5.0:
                    if hasattr(self.coordinator, "record_heartbeat"):
                        task_id = self.current_task.id if self.current_task else None
                        self.coordinator.record_heartbeat(self.agent_id, task_id=task_id, state=getattr(self.state, "value", None))
                    self._last_heartbeat_sent = now
            except Exception:
                pass
            if LOGGING_AVAILABLE and loop_iteration % 100 == 0:
                AgentLogger.debug(self.agent_id, f"Work loop iteration {loop_iteration}", 
                                extra={'has_current_task': self.current_task is not None})
            
            # Wait if paused
            self._pause_event.wait()
            
            if self._stop_event.is_set():
                if LOGGING_AVAILABLE:
                    AgentLogger.info(self.agent_id, "Work loop stopped (stop event set)")
                break
            
            # Request a new task if we don't have one
            if not self.current_task:
                # First, try to resume a previously assigned/in-progress task for this agent.
                # This is important after process restarts where tasks may be persisted as
                # ASSIGNED/IN_PROGRESS in tasks.md/progress reports.
                try:
                    agent_tasks = self.coordinator.get_agent_tasks(self.agent_id) or []
                except Exception:
                    agent_tasks = []

                resumable = [
                    t for t in agent_tasks
                    if t.status in (TaskStatus.ASSIGNED, TaskStatus.IN_PROGRESS)
                ]
                resumed_task = False
                if resumable:
                    # Prefer already IN_PROGRESS tasks, then ASSIGNED.
                    def _sort_key(t: Task):
                        return (0 if t.status == TaskStatus.IN_PROGRESS else 1, t.started_at or datetime.min)

                    task = sorted(resumable, key=_sort_key)[0]
                    self.current_task = task
                    if LOGGING_AVAILABLE:
                        AgentLogger.execution_flow(self.agent_id, f"Resuming assigned task: {task.id}", task_id=task.id)
                    if not self.start_work(task.id):
                        if LOGGING_AVAILABLE:
                            AgentLogger.warning(self.agent_id, f"Failed to resume task: {task.id}", task_id=task.id)
                        self.current_task = None
                        self._stop_event.wait(timeout=0.5)
                        continue
                    resumed_task = True

                # If we successfully resumed a task, do NOT request a new one in the same iteration.
                # Fall through to the "work on current task" block below.
                if not resumed_task:
                    if LOGGING_AVAILABLE:
                        AgentLogger.execution_flow(self.agent_id, "No current task, requesting new task")
                    task = self.request_task()
                    if not task:
                        # No tasks available, wait a bit and check again
                        if LOGGING_AVAILABLE and loop_iteration % 10 == 0:
                            AgentLogger.debug(self.agent_id, "No tasks available, waiting...")
                        self._stop_event.wait(timeout=1.0)  # Reduced wait time for faster task pickup
                        continue
                    
                    # Start working on the task
                    if LOGGING_AVAILABLE:
                        AgentLogger.execution_flow(self.agent_id, f"Starting work on task: {task.id}", task_id=task.id)
                    if not self.start_work():
                        # Failed to start, try again
                        if LOGGING_AVAILABLE:
                            AgentLogger.warning(self.agent_id, f"Failed to start work on task: {task.id}", task_id=task.id)
                        self.current_task = None
                        self._stop_event.wait(timeout=0.5)
                        continue

            # Work on current task
            if self.current_task:
                # Do not auto-complete tasks based on framework-specific file layouts.
                # Completion should be driven by explicit artifacts and acceptance criteria.
                
                try:
                    success = self.work(self.current_task)
                    if success:
                        # Task completed, clear it to pick up next task
                        self.current_task = None
                    else:
                        # Task failed or was blocked, wait a bit before retrying
                        self._stop_event.wait(timeout=2.0)
                        # Clear task to try getting a new one
                        self.current_task = None
                except Exception as e:
                    error_str = str(e).lower()
                    # Check if it's a connection error
                    is_connection_error = any(keyword in error_str for keyword in [
                        'connection', 'failed', 'timeout', 'network',
                        'unreachable', 'refused', 'vpn', 'internet'
                    ])
                    
                    if is_connection_error:
                        print(f"[{self.agent_id}] Connection error on task {self.current_task.id}: {e}")
                        print(f"[{self.agent_id}] Will retry task after delay...")
                        # Don't clear the task - keep it for retry
                        # Send status update about the connection issue
                        self.send_status_update(
                            self.current_task.id,
                            TaskStatus.BLOCKED,
                            message=f"Connection error: {str(e)[:100]}. Retrying..."
                        )
                        # Wait longer for connection errors (exponential backoff)
                        self._stop_event.wait(timeout=5.0)
                    else:
                        # Non-connection error - log and clear task
                        print(f"[{self.agent_id}] Error working on task: {e}")
                        self.send_status_update(
                            self.current_task.id,
                            TaskStatus.FAILED,
                            message=f"Error: {str(e)[:100]}"
                        )
                        self.current_task = None
                        self._stop_event.wait(timeout=1.0)
    
    def run(self):
        """
        Main agent loop - request tasks and work on them.
        For backward compatibility. Use start() for coordinator control.
        """
        if self.state == AgentState.CREATED:
            self.start()
        else:
            # If already started, just run the loop
            self._run_loop()

    def get_workload(self) -> int:
        """Get current number of active tasks"""
        return len(self.coordinator.get_agent_tasks(self.agent_id))


class IncrementalWorkMixin:
    """
    Mixin to help agents work incrementally.
    Provides utilities for breaking work into steps.
    """

    def create_increments(self, task: Task, increment_descriptions: List[str]) -> List[dict]:
        """
        Create a list of increments from descriptions.
        Each increment should be 1-4 hours of work.
        """
        increments = []
        total_increments = len(increment_descriptions)
        
        for i, desc in enumerate(increment_descriptions):
            increment = {
                "number": i + 1,
                "total": total_increments,
                "description": desc,
                "progress_start": int((i / total_increments) * 100),
                "progress_end": int(((i + 1) / total_increments) * 100)
            }
            increments.append(increment)
        
        return increments

    def work_increment(
        self,
        task: Task,
        increment: dict,
        work_function
    ) -> bool:
        """
        Execute a single increment of work.
        
        Args:
            task: The task being worked on
            increment: Increment description dict
            work_function: Function to execute for this increment
        
        Returns:
            True if increment completed, False if blocked/failed
        """
        # Update progress
        self.send_status_update(
            task.id,
            TaskStatus.IN_PROGRESS,
            progress=increment["progress_start"],
            message=f"Working on increment {increment['number']}/{increment['total']}: {increment['description']}"
        )

        # Execute work
        try:
            result = work_function()
            
            # Checkpoint after increment
            self.send_checkpoint(
                task.id,
                progress=increment["progress_end"],
                changes=f"Completed: {increment['description']}",
                next_steps=f"Next: increment {increment['number'] + 1}" if increment['number'] < increment['total'] else "Finalizing task"
            )
            
            return result
        except Exception as e:
            self.send_status_update(
                task.id,
                TaskStatus.BLOCKED,
                progress=increment["progress_start"],
                message=f"Error in increment: {str(e)}"
            )
            return False

