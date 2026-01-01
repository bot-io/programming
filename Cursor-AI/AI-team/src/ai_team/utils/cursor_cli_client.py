"""
Cursor CLI Client - Wrapper for cursor-agent CLI
Replaces OpenAI/Anthropic API calls with Cursor CLI commands
"""

import subprocess
import os
import json
from typing import Optional, Dict, Any, List
import tempfile
import time

def _default_debug_log_path() -> str:
    """
    Return a generic, machine-independent debug log path.
    Prefer a local `.cursor/debug.log` in the current working directory.
    Fall back to the OS temp directory if needed.
    """
    try:
        base = os.getcwd()
        cursor_dir = os.path.join(base, ".cursor")
        os.makedirs(cursor_dir, exist_ok=True)
        return os.path.join(cursor_dir, "debug.log")
    except Exception:
        return os.path.join(tempfile.gettempdir(), "ai_team_debug.log")

# Debug logging configuration (generic; no hardcoded user paths)
DEBUG_LOG_PATH = _default_debug_log_path()

def _debug_log(location: str, message: str, data: dict = None, hypothesis_id: str = None):
    """Write debug log entry"""
    try:
        log_entry = {
            "timestamp": int(time.time() * 1000),
            "location": location,
            "message": message,
            "data": data or {},
            "sessionId": "debug-session",
            "runId": "run1",
            "hypothesisId": hypothesis_id or "unknown"
        }
        with open(DEBUG_LOG_PATH, 'a', encoding='utf-8') as f:
            f.write(json.dumps(log_entry) + '\n')
    except Exception:
        pass  # Silently fail if logging fails

# Import logger
try:
    from .agent_logger import AgentLogger
    LOGGING_AVAILABLE = True
except ImportError:
    LOGGING_AVAILABLE = False
    class AgentLogger:
        @staticmethod
        def debug(*args, **kwargs): pass
        @staticmethod
        def info(*args, **kwargs): pass
        @staticmethod
        def warning(*args, **kwargs): print(f"[WARNING] {args[1] if len(args) > 1 else ''}")
        @staticmethod
        def error(*args, **kwargs): print(f"[ERROR] {args[1] if len(args) > 1 else ''}")


class CursorCLIClient:
    """Wrapper for cursor-agent CLI commands"""
    
    def __init__(self):
        """Initialize Cursor CLI client"""
        self.cli_command = self._find_cli_command()
        # Cache availability checks to avoid repeatedly spawning `cursor-agent --version`
        # across many agents/tasks (which can fail transiently and cause false "CLI not available").
        self._available_cache: Optional[bool] = None
        self._available_cache_ts: float = 0.0
        self.verify_cli_available()
    
    def _find_cli_command(self) -> str:
        """Find the cursor-agent command, checking common locations"""
        # First try the command directly (if in PATH)
        try:
            result = subprocess.run(
                ["cursor-agent", "--version"],
                capture_output=True,
                text=True,
                timeout=5
            )
            if result.returncode == 0:
                return "cursor-agent"
        except:
            pass
        
        # Try Windows default installation location
        home = os.path.expanduser("~")
        windows_paths = [
            os.path.join(home, ".local", "bin", "cursor-agent.cmd"),
            os.path.join(home, ".local", "bin", "cursor-agent.exe"),
        ]
        
        for path in windows_paths:
            if os.path.exists(path):
                return path
        
        # Default to command name (will fail gracefully if not found)
        return "cursor-agent"
    
    def verify_cli_available(self) -> bool:
        """Verify that cursor-agent CLI is installed and available"""
        # Use a short TTL cache to reduce flakiness under load.
        try:
            if self._available_cache is not None and (time.time() - float(self._available_cache_ts)) < 30.0:
                return bool(self._available_cache)
        except Exception:
            pass

        try:
            # Retry briefly to avoid false negatives due to transient process limits.
            last = None
            for attempt in range(3):
                try:
                    result = subprocess.run(
                        [self.cli_command, "--version"],
                        capture_output=True,
                        text=True,
                        timeout=8
                    )
                    last = result
                    if result.returncode == 0:
                        print(f"[CURSOR_CLI] Cursor CLI is available at: {self.cli_command}")
                        self._available_cache = True
                        self._available_cache_ts = time.time()
                        return True
                except Exception as e:
                    last = e
                time.sleep(0.25 * (attempt + 1))

            # If we get here, attempts failed.
            result = last if hasattr(last, "returncode") else None
            if result.returncode == 0:
                print(f"[CURSOR_CLI] Cursor CLI is available at: {self.cli_command}")
                self._available_cache = True
                self._available_cache_ts = time.time()
                return True
            else:
                print(f"[CURSOR_CLI] WARNING: cursor-agent CLI may not be properly installed")
                print(f"[CURSOR_CLI] Install with: curl https://cursor.com/install -fsSL | bash")
                self._available_cache = False
                self._available_cache_ts = time.time()
                return False
        except FileNotFoundError:
            print(f"[CURSOR_CLI] ERROR: cursor-agent CLI not found in PATH")
            print(f"[CURSOR_CLI] Install with: curl https://cursor.com/install -fsSL | bash")
            print(f"[CURSOR_CLI] Then authenticate with: cursor auth login")
            self._available_cache = False
            self._available_cache_ts = time.time()
            return False
        except Exception as e:
            print(f"[CURSOR_CLI] WARNING: Could not verify CLI: {e}")
            # Cache negative briefly to avoid thrash.
            self._available_cache = False
            self._available_cache_ts = time.time()
            return False
    
    def is_available(self) -> bool:
        """Check if Cursor CLI is available"""
        return self.verify_cli_available()
    
    def generate_code(
        self,
        prompt: str,
        context: str = "",
        language: str = "python",
        role: str = "Developer",
        working_dir: Optional[str] = None,
        **kwargs
    ) -> str:
        """
        Generate code using cursor-agent CLI.
        
        Args:
            prompt: The task/requirement description
            context: Additional context (requirements, existing code, etc.)
            language: Programming language
            role: System persona/role (Supervisor, Developer, Tester, Editor)
            working_dir: Working directory for the command
            **kwargs: Additional arguments (ignored for CLI)
        
        Returns:
            Generated code or response as string
        """
        if not self.is_available():
            raise RuntimeError("Cursor CLI not available. Install with: curl https://cursor.com/install -fsSL | bash")
        
        # Build the full prompt with role context
        full_prompt = self._build_prompt(prompt, context, language, role)
        
        # Prepare the command
        # Use stdin for long prompts to avoid command line length limits (Windows limit is ~8191 chars)
        prompt_file = None
        stdin_input = None
        import tempfile
        
        full_command = f"AS {role}: {full_prompt}"
        if len(full_command) > 8000:
            # Use stdin input for long prompts
            # Note: Cursor CLI reads from stdin if no prompt is provided
            cmd = [
                self.cli_command,
                "chat",
                "--print",
                "--force",
                f"AS {role}:"
            ]
            stdin_input = full_prompt
            prompt_file = None
            print(f"[CURSOR_CLI] Using stdin input for long prompt ({len(full_prompt)} chars)...")
        else:
            # Use command line argument for short prompts
            cmd = [
                self.cli_command,
                "chat",
                "--print",
                "--force",
                full_command
            ]
            prompt_file = None
            stdin_input = None
        
        # Execute the command
        start_time = time.time()
        cmd_preview = ' '.join(cmd[:3]) + ' ...' if len(cmd) > 3 else ' '.join(cmd)
        
        # #region debug log
        _debug_log("cursor_cli_client.py:160", "generate_code: About to execute subprocess", {
            "cmd": cmd,
            "cmd_preview": cmd_preview,
            "cwd": working_dir if working_dir else os.getcwd(),
            "stdin_length": len(stdin_input) if stdin_input else 0,
            "full_command_length": len(full_command)
        }, "H1,H2,H5")
        # #endregion
        
        try:
            print(f"[CURSOR_CLI] Executing as {role}...")
            print(f"[CURSOR_CLI] Command: {cmd_preview}")
            
            # Set working directory if provided
            cwd = working_dir if working_dir else os.getcwd()
            
            # #region debug log
            _debug_log("cursor_cli_client.py:172", "generate_code: Before subprocess.run", {
                "cwd": cwd,
                "cmd_full": ' '.join(cmd),
                "has_stdin": stdin_input is not None
            }, "H1,H2,H3")
            # #endregion
            
            # Use subprocess.run with timeout for better control
            # Ensure UTF-8 encoding for stdin to handle Unicode characters
            # Also add ripgrep to PATH if it's installed via winget
            env = os.environ.copy()
            env['PYTHONIOENCODING'] = 'utf-8'
            # Add ripgrep to PATH if it exists in the winget installation location
            rg_path = os.path.join(os.path.expanduser("~"), 
                                  "AppData", "Local", "Microsoft", "WinGet", "Packages",
                                  "BurntSushi.ripgrep.MSVC_Microsoft.Winget.Source_8wekyb3d8bbwe",
                                  "ripgrep-15.1.0-x86_64-pc-windows-msvc")
            if os.path.exists(rg_path):
                current_path = env.get('PATH', '')
                if rg_path not in current_path:
                    env['PATH'] = f"{rg_path};{current_path}"
            
            process = subprocess.run(
                cmd,
                input=stdin_input,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True,
                encoding='utf-8',
                errors='replace',
                cwd=cwd,
                env=env,
                timeout=300  # 5 minute timeout
            )
            
            # #region debug log
            _debug_log("cursor_cli_client.py:195", "generate_code: After subprocess.run completed", {
                "returncode": process.returncode,
                "stdout_length": len(process.stdout) if process.stdout else 0,
                "stderr_length": len(process.stderr) if process.stderr else 0,
                "stdout_preview": (process.stdout[:200] if process.stdout else ""),
                "stderr_preview": (process.stderr[:200] if process.stderr else "")
            }, "H1,H2,H3,H4")
            # #endregion
            
            # Clean up temp file
            if prompt_file and os.path.exists(prompt_file):
                try:
                    os.unlink(prompt_file)
                except:
                    pass
            
            elapsed = time.time() - start_time
            
            # #region debug log
            _debug_log("cursor_cli_client.py:207", "generate_code: After cleanup, before returncode check", {
                "elapsed": elapsed,
                "returncode": process.returncode
            }, "H3")
            # #endregion
            
            if process.returncode != 0:
                error_msg = f"Cursor CLI error (exit code {process.returncode}): {process.stderr[:500]}"
                print(f"[CURSOR_CLI] {error_msg}")
                if LOGGING_AVAILABLE:
                    AgentLogger.error("CURSOR_CLI", "Cursor CLI command failed", extra={
                        'exit_code': process.returncode,
                        'stderr': process.stderr[:1000] if process.stderr else '',
                        'stdout': process.stdout[:500] if process.stdout else '',
                        'elapsed': elapsed,
                        'role': role,
                        'command': cmd_preview
                    })
                # Return empty string to indicate failure - don't treat error messages as code
                return ""
            
            # Return the output
            result = process.stdout.strip() if process.stdout else ""
            result_length = len(result)
            
            # #region debug log
            _debug_log("cursor_cli_client.py:220", "generate_code: About to return success result", {
                "result_length": result_length,
                "elapsed": elapsed,
                "result_preview": result[:200] if result else ""
            }, "H3,H4")
            # #endregion
            
            msg = f"Command completed successfully ({result_length} chars in {elapsed:.2f}s)"
            print(f"[CURSOR_CLI] {msg}")
            if LOGGING_AVAILABLE:
                AgentLogger.info("CURSOR_CLI", "Cursor CLI command succeeded", extra={
                    'result_length': result_length,
                    'elapsed': elapsed,
                    'role': role,
                    'command': cmd_preview,
                    'result_preview': result[:200] if result else ''
                })
            return result
            
        except subprocess.TimeoutExpired as e:
            elapsed = time.time() - start_time
            
            # #region debug log
            _debug_log("cursor_cli_client.py:234", "generate_code: TimeoutExpired exception", {
                "elapsed": elapsed,
                "timeout": 300,
                "exception_type": type(e).__name__,
                "exception_msg": str(e)
            }, "H1")
            # #endregion
            
            # Clean up temp file on timeout
            if prompt_file and os.path.exists(prompt_file):
                try:
                    os.unlink(prompt_file)
                except:
                    pass
            msg = f"Cursor CLI command timed out after {elapsed:.2f}s"
            print(f"[CURSOR_CLI] {msg}")
            if LOGGING_AVAILABLE:
                AgentLogger.error("CURSOR_CLI", msg, extra={
                    'timeout': 300,
                    'elapsed': elapsed,
                    'role': role,
                    'command': cmd_preview
                })
            raise RuntimeError(msg)
        except Exception as e:
            elapsed = time.time() - start_time
            
            # #region debug log
            import traceback
            _debug_log("cursor_cli_client.py:260", "generate_code: General exception caught", {
                "exception_type": type(e).__name__,
                "exception_msg": str(e),
                "elapsed": elapsed,
                "traceback": traceback.format_exc()
            }, "H2")
            # #endregion
            
            # Clean up temp file on error
            if prompt_file and os.path.exists(prompt_file):
                try:
                    os.unlink(prompt_file)
                except:
                    pass
            msg = f"Failed to execute Cursor CLI: {e}"
            print(f"[CURSOR_CLI] {msg}")
            if LOGGING_AVAILABLE:
                AgentLogger.error("CURSOR_CLI", msg, extra={
                    'exception': str(e),
                    'exception_type': type(e).__name__,
                    'elapsed': elapsed,
                    'role': role,
                    'command': cmd_preview,
                    'traceback': traceback.format_exc()
                })
            raise RuntimeError(msg)
    
    def _build_prompt(self, prompt: str, context: str, language: str, role: str) -> str:
        """Build the full prompt for code generation"""
        
        role_instructions = {
            "Supervisor": """You are a Supervisor in an AI Dev Team. Your role is to:
- Analyze requirements and produce an actionable task breakdown
- Review code and test results
- Coordinate the team's work
- Ensure quality and completeness""",
            
            "Developer": """You are a Developer in an AI Dev Team. Your role is to:
- Write production-ready code based on requirements
- Follow best practices and coding standards
- Implement features completely and correctly
- Write clean, maintainable code""",
            
            "Tester": """You are a Tester in an AI Dev Team. Your role is to:
- Write comprehensive tests for code
- Run test suites and report results
- Identify bugs and edge cases
- Ensure code quality and reliability""",
            
            "Editor": """You are an Editor in an AI Dev Team. Your role is to:
- Review code for style and consistency
- Refactor code for better maintainability
- Ensure code follows project conventions
- Improve code quality without changing functionality"""
        }
        
        role_instruction = role_instructions.get(role, f"You are a {role} in an AI Dev Team.")
        
        system_context = f"""{role_instruction}

Task: {prompt}

{f'Context:\n{context}' if context else ''}

Language: {language}

Generate complete, working code that implements the requirements."""
        
        return system_context
    
    def generate_with_retry(
        self,
        prompt: str,
        context: str = "",
        language: str = "python",
        role: str = "Developer",
        max_retries: int = 3,
        working_dir: Optional[str] = None,
        **kwargs
    ) -> str:
        """Generate code with retry logic"""
        for attempt in range(max_retries):
            try:
                return self.generate_code(prompt, context, language, role, working_dir, **kwargs)
            except Exception as e:
                if attempt == max_retries - 1:
                    raise
                print(f"[CURSOR_CLI] Generation attempt {attempt + 1} failed: {e}. Retrying...")
                import time
                time.sleep(2 ** attempt)  # Exponential backoff
        
        raise RuntimeError("Failed to generate code after retries")


def create_cursor_cli_client() -> Optional[CursorCLIClient]:
    """
    Create a Cursor CLI client.
    
    Returns:
        CursorCLIClient instance or None if CLI not available
    """
    try:
        client = CursorCLIClient()
        if client.is_available():
            print(f"[CURSOR_CLI] Successfully created Cursor CLI client")
            return client
        else:
            print(f"[CURSOR_CLI] Cursor CLI not available")
            return None
    except Exception as e:
        print(f"[CURSOR_CLI] Failed to create client: {e}")
        return None

