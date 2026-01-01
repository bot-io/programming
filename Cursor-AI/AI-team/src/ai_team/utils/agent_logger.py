"""
Centralized logging system for AI agents
Provides extensive logging with timestamps, agent IDs, task IDs, and execution flow
"""

import os
import sys
import io
from datetime import datetime
from typing import Optional
import threading

# Force UTF-8 encoding for stdout/stderr on Windows
if sys.platform == 'win32' and not hasattr(sys.stdout, 'is_wrapped_for_utf8'):
    if hasattr(sys.stdout, 'buffer'):
        sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')
        sys.stdout.is_wrapped_for_utf8 = True
    if hasattr(sys.stderr, 'buffer'):
        sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding='utf-8', errors='replace')
        sys.stderr.is_wrapped_for_utf8 = True


class AgentLogger:
    """Centralized logger for agents with file and console output"""
    
    _lock = threading.Lock()
    _log_files = {}
    _project_dir = None
    _team_id = None  # REQ-1.2.3: Team ID for all log entries
    
    @classmethod
    def set_project_dir(cls, project_dir: str):
        """Set the project directory for log files"""
        cls._project_dir = os.path.abspath(project_dir)
        os.makedirs(cls._project_dir, exist_ok=True)
    
    @classmethod
    def set_team_id(cls, team_id: str):
        """REQ-1.2.3: Set the team ID for all log entries"""
        cls._team_id = team_id
    
    @classmethod
    def _get_log_file(cls, agent_id: str) -> str:
        """Get log file path for an agent"""
        if not cls._project_dir:
            cls._project_dir = os.getcwd()
        
        log_dir = os.path.join(cls._project_dir, 'agent_logs')
        os.makedirs(log_dir, exist_ok=True)
        
        # Sanitize agent_id for filename
        safe_id = agent_id.replace(':', '_').replace('/', '_').replace('\\', '_')
        return os.path.join(log_dir, f'{safe_id}.log')
    
    @classmethod
    def _write_log(cls, agent_id: str, level: str, message: str, task_id: Optional[str] = None, 
                   extra: Optional[dict] = None):
        """Write log entry to both file and console"""
        timestamp = datetime.now().strftime('%Y-%m-%d %H:%M:%S.%f')[:-3]
        
        # Build log entry
        # REQ-1.2.3: Include team ID in all log entries
        parts = [f"[{timestamp}]", f"[{level}]"]
        if cls._team_id:
            parts.append(f"[team:{cls._team_id}]")
        parts.append(f"[{agent_id}]")
        if task_id:
            parts.append(f"[task:{task_id}]")
        parts.append(message)
        
        log_entry = " ".join(parts)
        
        # Add extra info if provided
        if extra:
            extra_str = " | ".join([f"{k}={v}" for k, v in extra.items()])
            log_entry += f" | {extra_str}"
        
        log_entry += "\n"
        
        # Write to file
        try:
            log_file = cls._get_log_file(agent_id)
            with cls._lock:
                with open(log_file, 'a', encoding='utf-8') as f:
                    f.write(log_entry)
                    f.flush()
        except Exception as e:
            # Fallback to stderr if file write fails
            sys.stderr.write(f"[LOG ERROR] Failed to write to {log_file}: {e}\n")
            sys.stderr.write(log_entry)
        
        # Also write to console for important messages
        if level in ['ERROR', 'WARNING', 'CRITICAL', 'TASK_START', 'TASK_COMPLETE', 'TASK_FAIL']:
            print(log_entry.rstrip())
            sys.stdout.flush()
    
    @classmethod
    def debug(cls, agent_id: str, message: str, task_id: Optional[str] = None, **kwargs):
        """Log debug message"""
        cls._write_log(agent_id, 'DEBUG', message, task_id, kwargs)
    
    @classmethod
    def info(cls, agent_id: str, message: str, task_id: Optional[str] = None, **kwargs):
        """Log info message"""
        cls._write_log(agent_id, 'INFO', message, task_id, kwargs)
    
    @classmethod
    def warning(cls, agent_id: str, message: str, task_id: Optional[str] = None, **kwargs):
        """Log warning message"""
        cls._write_log(agent_id, 'WARNING', message, task_id, kwargs)
    
    @classmethod
    def error(cls, agent_id: str, message: str, task_id: Optional[str] = None, **kwargs):
        """Log error message"""
        cls._write_log(agent_id, 'ERROR', message, task_id, kwargs)
    
    @classmethod
    def critical(cls, agent_id: str, message: str, task_id: Optional[str] = None, **kwargs):
        """Log critical message"""
        cls._write_log(agent_id, 'CRITICAL', message, task_id, kwargs)
    
    @classmethod
    def task_start(cls, agent_id: str, task_id: str, task_title: str, **kwargs):
        """Log task start"""
        cls._write_log(agent_id, 'TASK_START', f"Starting task: {task_title}", task_id, kwargs)
    
    @classmethod
    def task_complete(cls, agent_id: str, task_id: str, task_title: str, artifacts: int = 0, **kwargs):
        """Log task completion"""
        cls._write_log(agent_id, 'TASK_COMPLETE', f"Completed task: {task_title} (artifacts: {artifacts})", 
                      task_id, {'artifacts': artifacts, **kwargs})
    
    @classmethod
    def task_fail(cls, agent_id: str, task_id: str, task_title: str, reason: str, **kwargs):
        """Log task failure"""
        cls._write_log(agent_id, 'TASK_FAIL', f"Failed task: {task_title} - {reason}", task_id, 
                      {'reason': reason, **kwargs})
    
    @classmethod
    def method_entry(cls, agent_id: str, method_name: str, task_id: Optional[str] = None, **kwargs):
        """Log method entry"""
        cls._write_log(agent_id, 'METHOD_ENTRY', f"Entering {method_name}", task_id, kwargs)
    
    @classmethod
    def method_exit(cls, agent_id: str, method_name: str, task_id: Optional[str] = None, 
                    result: Optional[str] = None, **kwargs):
        """Log method exit"""
        result_str = f" -> {result}" if result else ""
        cls._write_log(agent_id, 'METHOD_EXIT', f"Exiting {method_name}{result_str}", task_id, kwargs)
    
    @classmethod
    def execution_flow(cls, agent_id: str, step: str, task_id: Optional[str] = None, **kwargs):
        """Log execution flow step"""
        cls._write_log(agent_id, 'FLOW', step, task_id, kwargs)
    
    @classmethod
    def get_log_file(cls, agent_id: str) -> str:
        """Get the log file path for an agent"""
        return cls._get_log_file(agent_id)
    
    @classmethod
    def clear_log(cls, agent_id: str):
        """Clear log file for an agent"""
        try:
            log_file = cls._get_log_file(agent_id)
            with cls._lock:
                if os.path.exists(log_file):
                    with open(log_file, 'w', encoding='utf-8') as f:
                        f.write(f"Log cleared at {datetime.now().isoformat()}\n")
        except Exception as e:
            sys.stderr.write(f"[LOG ERROR] Failed to clear log: {e}\n")

