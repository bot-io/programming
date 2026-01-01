"""
Generic Agent - Task-agnostic agent that works with any task type.
Uses adapters and tools to handle different task types.
"""

from typing import Optional, List
from .agent import Agent, IncrementalWorkMixin
from .agent_coordinator import Task, TaskStatus
from ..utils.task_adapter import (
    TaskAdapter, TaskAdapterRegistry, TaskContext, GenericTaskAdapter
)
from ..utils.tool_system import ToolRegistry, ToolExecutor
from ..utils.conflict_prevention import LockType
import time
import json
import os
import re


class GenericAgent(Agent, IncrementalWorkMixin):
    """
    Generic agent that can work on any task type using adapters.
    Task-agnostic implementation.
    """
    
    def __init__(
        self,
        agent_id: str,
        coordinator,
        specialization: str = "",
        adapter_registry: Optional[TaskAdapterRegistry] = None,
        tool_registry: Optional[ToolRegistry] = None
    ):
        super().__init__(agent_id, coordinator, specialization)
        self.adapter_registry = adapter_registry or TaskAdapterRegistry()
        self.tool_registry = tool_registry
        self.tool_executor: Optional[ToolExecutor] = None
        self.current_context: Optional[TaskContext] = None
        self._cursor_cli = None
        self._ai_client = None
        try:
            from ..utils.cursor_cli_client import create_cursor_cli_client
            self._cursor_cli = create_cursor_cli_client()
        except Exception:
            self._cursor_cli = None

        # Optional: external LLM APIs (Gemini/OpenAI/Anthropic) as a fallback when Cursor CLI isn't available.
        # This keeps the team usable in environments where `cursor-agent` cannot be installed or authenticated.
        try:
            from ..utils.ai_client import create_ai_client
            preferred = os.getenv("AI_PROVIDER")  # e.g., "gemini", "openai", "anthropic"
            if not preferred:
                try:
                    from ..utils.settings import get_setting
                    preferred = str(get_setting("AI_PROVIDER") or "").strip() or None
                except Exception:
                    preferred = None
            self._ai_client = create_ai_client(provider=preferred)
        except Exception:
            self._ai_client = None

    def _infer_target_files(self, task: Task) -> List[str]:
        """
        Infer likely file paths from task description / acceptance criteria.
        This is intentionally heuristic and project-agnostic.
        """
        texts: List[str] = []
        try:
            if getattr(task, "title", None):
                texts.append(str(task.title))
            if getattr(task, "description", None):
                texts.append(str(task.description))
            if getattr(task, "acceptance_criteria", None):
                # Acceptance criteria sometimes parse as multi-line blobs; split for better matching.
                for x in task.acceptance_criteria:
                    if not x:
                        continue
                    sx = str(x)
                    texts.append(sx)
                    for line in sx.splitlines():
                        if line.strip():
                            texts.append(line.strip())
        except Exception:
            pass

        candidates: List[str] = []
        # Backticked snippets often contain file paths.
        for t in texts:
            for m in re.findall(r"`([^`]+)`", t):
                candidates.append(m.strip())

        # Also scan raw text for common path patterns with an extension.
        #
        # NOTE: This must cover common non-code config files for multi-platform projects
        # (e.g., Flutter/Android/iOS/Web). If we miss extensions like ".gradle",
        # tasks like "edit android/app/build.gradle" will infer zero target files and deadlock.
        _exts = (
            "dart|yaml|yml|json|md|py|js|ts|tsx|java|kt|swift|html|css|"
            "gradle|properties|xml|plist|pbxproj|xcconfig|entitlements|lock|iml"
        )
        for t in texts:
            for m in re.findall(rf"(?:(?:[A-Za-z]:)?[\\/])?(?:[\\w.\\-]+[\\/])+[\\w.\\-]+\\.(?:{_exts})", t):
                candidates.append(m.strip())
            # IMPORTANT: Use real regex word-boundaries (\b). Using \\b matches a literal backslash+b and breaks inference.
            for m in re.findall(rf"\b[\w./\-]+\.(?:{_exts})\b", t):
                candidates.append(m.strip())

        # Normalize and filter.
        cleaned: List[str] = []
        for c in candidates:
            if not c or " " in c:
                continue
            if c.startswith("http://") or c.startswith("https://"):
                continue
            # Ignore commands that happen to contain dots (e.g., "flutter pub get")
            if any(c.lower().startswith(p) for p in ("flutter ", "python ", "npm ", "dart ", "gradle", "adb ")):
                continue
            c = c.replace("\\", "/")
            if c.startswith("./"):
                c = c[2:]
            cleaned.append(c)

        # De-dupe while preserving order.
        seen = set()
        out: List[str] = []
        for c in cleaned:
            if c not in seen:
                seen.add(c)
                out.append(c)
        return out[:8]  # safety: cap per task

    def _cursor_cli_execute_task(self, context: TaskContext) -> bool:
        """
        Best-effort executor that uses Cursor CLI to generate concrete file contents
        and writes them to the project directory.
        """
        def _extract_first_json_object(text: str) -> Optional[str]:
            """
            Extract the first balanced JSON object from text.
            Cursor CLI sometimes returns extra text despite instructions; this makes parsing resilient.
            """
            if not text:
                return None
            raw = text.strip()
            # Strip common code fences (best-effort).
            raw = re.sub(r"^```(?:json)?\\s*", "", raw, flags=re.IGNORECASE)
            raw = re.sub(r"\\s*```\\s*$", "", raw)
            start = raw.find("{")
            if start == -1:
                return None

            depth = 0
            in_str = False
            esc = False
            for i in range(start, len(raw)):
                ch = raw[i]
                if in_str:
                    if esc:
                        esc = False
                    elif ch == "\\\\":
                        esc = True
                    elif ch == "\"":
                        in_str = False
                    continue

                if ch == "\"":
                    in_str = True
                    continue
                if ch == "{":
                    depth += 1
                elif ch == "}":
                    depth -= 1
                    if depth == 0:
                        return raw[start:i + 1]
            return None

        # AI generation backend:
        # - Prefer external API client if available (default order prefers Gemini)
        # - Fall back to Cursor CLI if available
        # For command-only verification tasks or directory-creation tasks (no target files inferred),
        # we can proceed without any AI backend and rely on acceptance validation.
        api_ai_available = bool(self._ai_client and getattr(self._ai_client, "is_available", lambda: False)())
        cursor_ai_available = bool(self._cursor_cli and getattr(self._cursor_cli, "is_available", lambda: False)())
        ai_available = api_ai_available or cursor_ai_available

        project_dir = None
        try:
            project_dir = context.config.get("project_dir") if context.config else None
        except Exception:
            project_dir = None
        # Always anchor to the real project directory (not the agent workspace cwd).
        # Using os.getcwd() here is a footgun because agents execute from per-task workspaces.
        if project_dir:
            project_dir = os.path.abspath(project_dir)
        else:
            project_dir = self._get_project_dir()

        requirements_path = os.path.join(project_dir, "requirements.md")
        requirements_content = ""
        try:
            if os.path.exists(requirements_path):
                with open(requirements_path, "r", encoding="utf-8") as f:
                    requirements_content = f.read()
        except Exception:
            requirements_content = ""

        # Best-effort: detect Flutter/Dart package name from pubspec.yaml to avoid wrong imports
        # like `package:test_notes_app/...` when the actual package is `simplenotes`.
        package_name = None
        try:
            pubspec_path = os.path.join(project_dir, "pubspec.yaml")
            if os.path.exists(pubspec_path):
                with open(pubspec_path, "r", encoding="utf-8", errors="replace") as f:
                    for line in f.read().splitlines():
                        m = re.match(r"^\s*name\s*:\s*([A-Za-z0-9_\\-]+)\s*$", line)
                        if m:
                            package_name = m.group(1).strip()
                            break
        except Exception:
            package_name = None

        target_files = self._infer_target_files(context.task)

        # If we couldn't infer any concrete files, do NOT blindly succeed.
        # Many tasks (e.g., scaffolding) still have concrete directory/file existence requirements.
        # We'll handle explicit directory existence requirements generically; otherwise fail so the
        # task can't be incorrectly marked complete.
        if not target_files:
            # Pure command/verification tasks are valid without file outputs. Let completion
            # validation run the extracted acceptance commands instead of forcing file generation.
            try:
                acceptance_cmds = self._extract_acceptance_commands(context.task)
            except Exception:
                acceptance_cmds = []
            if acceptance_cmds:
                print(f"[{context.agent_id}] [EXEC] No target files inferred; treating as command/verification task.")
                context.metadata["artifacts"] = []
                return True

            expected = []
            try:
                expected = self._infer_expected_artifacts(context.task)
            except Exception:
                expected = []

            created_dirs: List[str] = []
            for a in expected:
                a_norm = str(a).replace("\\", "/")
                if a_norm.startswith("./"):
                    a_norm = a_norm[2:]
                # Only handle explicit directory paths (commonly ending with "/").
                if not a_norm or not a_norm.endswith("/"):
                    continue
                abs_dir = os.path.abspath(os.path.join(project_dir, a_norm))
                if not abs_dir.startswith(os.path.abspath(project_dir) + os.sep):
                    continue
                try:
                    os.makedirs(abs_dir, exist_ok=True)
                    created_dirs.append(a_norm)
                except Exception:
                    continue

            if created_dirs:
                print(f"[{context.agent_id}] [EXEC] Created required directories: {created_dirs}")
                # We do not record directories as artifacts (artifact validation expects files),
                # but completion validation will now see them on disk.
                context.metadata["artifacts"] = []
                return True
            # If Cursor CLI is available, we can still attempt execution safely:
            # allow the model to decide which files to create/edit (we will enforce project-root writes).
            if ai_available:
                print(f"[{context.agent_id}] [EXEC] No target files inferred; using AI backend to decide outputs.")
                target_files = []
            else:
                print(f"[{context.agent_id}] [ERROR] No target files inferred and no explicit directories to create; cannot execute task safely.")
                try:
                    context.metadata["execution_error"] = "No target files inferred and no explicit directories to create"
                except Exception:
                    pass
                context.metadata["artifacts"] = []
                return False

        if not ai_available:
            print(f"[{context.agent_id}] [ERROR] No AI backend available (Gemini/OpenAI/Anthropic via env vars, or Cursor CLI); cannot execute file-producing task.")
            try:
                context.metadata["execution_error"] = "No AI backend available"
            except Exception:
                pass
            return False

        existing_snippets: List[str] = []
        for rel in target_files:
            abs_path = os.path.join(project_dir, rel)
            try:
                if os.path.exists(abs_path) and os.path.getsize(abs_path) < 200_000:
                    with open(abs_path, "r", encoding="utf-8", errors="replace") as f:
                        existing_snippets.append(f"FILE: {rel}\n---\n{f.read()}\n---\n")
            except Exception:
                continue

        pkg_hint = f"\nProject package name (from pubspec.yaml): {package_name}\n- Use it in Dart imports: `package:{package_name}/...`\n" if package_name else ""

        prompt = f"""Implement the following task in the existing project workspace.

Task:
- Title: {context.task.title}
- Description: {context.task.description}

Constraints:
- Only edit/create files under the project root.
- Only output STRICT JSON (no markdown fences, no commentary).
- Return full file contents for any file you edit.
- Prefer minimal changes needed to satisfy the task acceptance criteria.
{pkg_hint}

You MUST output JSON in this exact shape:
{{
  "files": [{{"path": "relative/path.ext", "content": "full file content"}}],
  "commands": ["optional command to run (no destructive ops)"]
}}

Target files (preferred): {target_files}
"""

        context_blob = ""
        if requirements_content:
            context_blob += f"REQUIREMENTS.md:\n{requirements_content}\n\n"
        if existing_snippets:
            context_blob += "EXISTING FILES:\n" + "\n".join(existing_snippets)

        def _generate_with_any_ai(prompt_text: str, ctx_text: str) -> str:
            # Prefer external API LLM when available (default order: Gemini -> OpenAI -> Anthropic).
            # Cursor CLI is a good fallback when authenticated/configured.
            if api_ai_available:
                return self._ai_client.generate_with_retry(
                    prompt=prompt_text,
                    context=ctx_text,
                    language="text",
                )
            # Cursor CLI fallback
            return self._cursor_cli.generate_with_retry(
                prompt=prompt_text,
                context=ctx_text,
                language="text",
                role="Developer",
                working_dir=project_dir,
            )

        # Cursor/LLM sometimes violates "strict JSON" instructions. Retry a few times with explicit correction prompts.
        last_err = None
        data = None
        for attempt in range(3):
            resp = _generate_with_any_ai(prompt, context_blob)

            if not resp:
                last_err = "AI backend returned empty response."
                continue

            raw_json = _extract_first_json_object(resp)
            if not raw_json:
                last_err = "Could not find a JSON object in Cursor CLI response."
                # Tighten prompt for next attempt.
                prompt += "\n\nIMPORTANT: Your previous response did not contain a JSON object. Output ONLY a single valid JSON object matching the required shape."
                continue

            try:
                data = json.loads(raw_json)
                last_err = None
                break
            except Exception as e:
                last_err = f"Failed to parse JSON from Cursor CLI: {e}"
                prompt += f"\n\nIMPORTANT: Your previous JSON was invalid ({e}). Output ONLY valid JSON (no comments, no trailing commas, no markdown)."
                continue

        if data is None:
            err = last_err or "Unknown Cursor CLI parsing error."
            print(f"[{context.agent_id}] [ERROR] {err}")
            try:
                context.metadata["execution_error"] = err
            except Exception:
                pass
            return False

        files = data.get("files") or []
        commands = data.get("commands") or []
        if not isinstance(files, list) or not isinstance(commands, list):
            print(f"[{context.agent_id}] [ERROR] Invalid JSON shape from Cursor CLI.")
            try:
                context.metadata["execution_error"] = "Invalid JSON shape from Cursor CLI (expected keys: files[], commands[])"
            except Exception:
                pass
            return False

        written: List[str] = []
        for fobj in files:
            if not isinstance(fobj, dict):
                continue
            rel = str(fobj.get("path") or "").replace("\\", "/")
            if rel.startswith("./"):
                rel = rel[2:]
            content = fobj.get("content")
            if not rel or content is None:
                continue
            # Safety: prevent path traversal.
            abs_path = os.path.abspath(os.path.join(project_dir, rel))
            if not abs_path.startswith(os.path.abspath(project_dir) + os.sep):
                print(f"[{context.agent_id}] [ERROR] Refusing to write outside project_dir: {rel}")
                try:
                    context.metadata["execution_error"] = f"Refused to write outside project_dir: {rel}"
                except Exception:
                    pass
                return False
            os.makedirs(os.path.dirname(abs_path), exist_ok=True)
            # Generic sanitation: if the Cursor output uses a placeholder Dart package name,
            # rewrite it to the real pubspec package name.
            out_content = str(content)
            if package_name and rel.endswith(".dart") and package_name != "test_notes_app":
                out_content = out_content.replace("package:test_notes_app/", f"package:{package_name}/")
            with open(abs_path, "w", encoding="utf-8", errors="replace") as out:
                out.write(out_content)
            written.append(rel)

        context.metadata["artifacts"] = written

        # Optionally run non-destructive commands (best-effort).
        # We intentionally do not fail the whole task if commands fail; the base Agent
        # will still run acceptance commands later, and can block appropriately.
        if commands:
            for cmd in commands[:3]:
                try:
                    cmd_s = str(cmd).strip()
                    if not cmd_s:
                        continue
                    # Very small safety filter.
                    if re.search(r"\\b(rm|del|rmdir|Remove-Item|format|diskpart)\\b", cmd_s, re.IGNORECASE):
                        continue
                    import subprocess
                    subprocess.run(cmd_s, cwd=project_dir, shell=True, capture_output=True, text=True, timeout=600)
                except Exception:
                    continue

        return True
    
    def work(self, task: Task) -> bool:
        """Work on task using appropriate adapter"""
        print(f"\n[{self.agent_id}] Working on: {task.title}")
        
        # Get appropriate adapter
        adapter = self.adapter_registry.get_adapter(task)
        if not adapter:
            # Fallback to generic adapter
            adapter = GenericTaskAdapter(executor=self._cursor_cli_execute_task)
            print(f"  [{self.agent_id}] Using generic adapter")
        else:
            print(f"  [{self.agent_id}] Using adapter: {adapter.task_type}")
        
        # Validate task
        is_valid, issues = adapter.validate_task(task)
        if not is_valid:
            print(f"  [{self.agent_id}] ✗ Task validation failed: {issues}")
            self.send_status_update(
                task.id,
                TaskStatus.BLOCKED,
                message=f"Validation failed: {', '.join(issues)}"
            )
            return False
        
        # Prepare context
        self.current_context = adapter.prepare_context(task, self.agent_id)
        if self.coordinator.conflict_prevention:
            self.current_context.workspace_path = self.workspace_path
        # Ensure project_dir is available to executors.
        try:
            self.current_context.config["project_dir"] = self._get_project_dir()
        except Exception:
            pass
        
        # Setup tool executor if available
        if self.tool_registry:
            self.tool_executor = ToolExecutor(self.tool_registry, self.current_context)

        # Do NOT simulate progress. Only emit checkpoints tied to real steps so progress is meaningful and debuggable.
        if not self._running:
            return False
        self._pause_event.wait()

        # Prepare
        print(f"  [{self.agent_id}] Preparing workspace...")
        self.send_checkpoint(
            task.id,
            progress=min(int(max(task.progress, 5)), 90),
            changes="Completed: Prepare workspace",
            next_steps="Next: Execute task",
        )
        
        # Execute task using adapter
        try:
            print(f"  [{self.agent_id}] Executing task...")
            success = adapter.execute(self.current_context)
            
            if not success:
                # Critical: avoid silent spinning. Mark as BLOCKED with a clear reason so supervisor/coordinator can act.
                err = None
                try:
                    err = (self.current_context.metadata or {}).get("execution_error")
                except Exception:
                    err = None
                if err:
                    msg = f"Execution failed: {err}"
                else:
                    msg = "Execution failed (adapter returned False). Check agent logs / Cursor CLI availability / inferred targets."
                print(f"  [{self.agent_id}] ✗ {msg}")
                self.send_status_update(
                    task.id,
                    TaskStatus.BLOCKED,
                    message=msg,
                    progress=min(int(task.progress or 0), 90),
                )
                return False
            
            self.send_checkpoint(
                task.id,
                progress=min(int(max(task.progress, 50)), 90),
                changes="Completed: Execute task",
                next_steps="Next: Validate results",
            )

            # Get artifacts
            artifacts = adapter.get_artifacts(self.current_context)
            
            # Validate changes if conflict prevention enabled
            if self.coordinator.conflict_prevention and artifacts:
                # Allow updates to files from completed (integrated) tasks.
                # Many real workflows require downstream tasks to extend/modify interfaces created by prerequisites.
                is_valid, issues = self.validate_changes(artifacts, allow_completed_updates=True)
                if not is_valid:
                    print(f"  [{self.agent_id}] ✗ Validation failed: {issues}")
                    self.send_status_update(
                        task.id,
                        TaskStatus.BLOCKED,
                        message=f"Validation failed: {issues}",
                        progress=min(int(task.progress or 0), 90),
                    )
                    return False

            self.send_checkpoint(
                task.id,
                progress=min(int(max(task.progress, 75)), 90),
                changes="Completed: Validate results",
                next_steps="Next: Finalize",
            )
            
            # Complete task
            completed_ok = self.complete_task(
                task.id,
                result=f"Successfully completed {task.title}",
                artifacts=artifacts,
                tests="Validation passed"
            )
            if not completed_ok:
                # Important: if completion validation fails (missing artifacts / acceptance commands),
                # do NOT report success to the run loop. Otherwise the agent will drop the task and
                # it can get stuck in an endless "resume -> drop" cycle.
                print(f"  [{self.agent_id}] ✗ Could not complete task (validation/acceptance failed): {task.title}")
                return False
            
            # Cleanup
            adapter.cleanup(self.current_context)
            self.current_context = None
            
            print(f"  [{self.agent_id}] ✓ Completed: {task.title}")
            return True
            
        except Exception as e:
            print(f"  [{self.agent_id}] ✗ Error: {e}")
            self.send_status_update(
                task.id,
                TaskStatus.FAILED,
                message=f"Execution error: {str(e)}"
            )
            return False
    
    def use_tool(self, tool_name: str, *args, **kwargs):
        """Use a tool from the tool registry"""
        if not self.tool_executor:
            print(f"  [{self.agent_id}] No tool executor available")
            return None
        
        result = self.tool_executor.execute(tool_name, *args, **kwargs)
        if not result.success:
            print(f"  [{self.agent_id}] Tool '{tool_name}' failed: {result.error}")
        return result

