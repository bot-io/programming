"""
Supervisor Agent - Monitors team work and catches issues automatically
"""

import os
import subprocess
import time
import sys
import io
import json
from typing import List, Dict, Optional, Set
from datetime import datetime, timedelta
from .agent import Agent, IncrementalWorkMixin
from .agent_coordinator import Task, TaskStatus, AgentMessage, MessageType

# Import cleanup utilities
try:
    from .supervisor_cleanup import get_temporary_files, cleanup_empty_directories, TEMPORARY_DIRS
    CLEANUP_AVAILABLE = True
except ImportError:
    CLEANUP_AVAILABLE = False

# Debug logging configuration
DEBUG_LOG_PATH = r"c:\Users\svetlin.chobanov\Documents\GitHub\programming\Cursor-AI\AI-team\.cursor\debug.log"

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
        def warning(*args, **kwargs): print(f"[WARNING] {args[1] if len(args) > 1 else ''}")
        @staticmethod
        def error(*args, **kwargs): print(f"[ERROR] {args[1] if len(args) > 1 else ''}")
        @staticmethod
        def critical(*args, **kwargs): print(f"[CRITICAL] {args[1] if len(args) > 1 else ''}")
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

# Force UTF-8 encoding for stdout/stderr on Windows to prevent Unicode errors
if sys.platform == 'win32' and not hasattr(sys.stdout, 'is_wrapped_for_utf8'):
    if hasattr(sys.stdout, 'buffer'):
        sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')
        sys.stdout.is_wrapped_for_utf8 = True
    if hasattr(sys.stderr, 'buffer'):
        sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding='utf-8', errors='replace')
        sys.stderr.is_wrapped_for_utf8 = True


class SupervisorAgent(Agent, IncrementalWorkMixin):
    """
    Supervisor Agent that monitors the team and catches issues:
    - Tasks marked complete without artifacts
    - Missing files that should exist
    - Premature completions
    - Final verification without builds
    - Stuck agents
    """
    
    def __init__(self, agent_id: str, coordinator, specialization: str = "supervisor"):
        super().__init__(agent_id, coordinator, specialization)
        self.project_dir = None
        self.last_audit_time = datetime.now()
        self.audit_interval = 30  # Audit every 30 seconds
        self.issues_found = []  # Track issues found
        self.fixes_applied = []  # Track fixes applied
        self.last_cleanup_time = datetime.now()
        self.cleanup_interval = 300  # Cleanup every 5 minutes
        self.team_size_analyzed = False  # Track if team size has been analyzed
        self.optimal_team_size = None  # Store optimal team size recommendation
    
    def request_task(self) -> Optional[Task]:
        """Supervisor doesn't request regular tasks - it monitors"""
        # CRITICAL: If supervisor somehow has a task assigned, release it immediately
        if self.current_task:
            task_id = self.current_task.id
            print(f"  [{self.agent_id}] [FIX] Supervisor should not have tasks assigned. Releasing task: {task_id}")
            # Release the task
            if task_id in self.coordinator.tasks:
                task = self.coordinator.tasks[task_id]
                task.assigned_agent = None
                task.status = TaskStatus.READY
                # Update workload
                if task.assigned_agent:
                    self.coordinator.agent_workloads[task.assigned_agent] = max(
                        0, self.coordinator.agent_workloads.get(task.assigned_agent, 0) - 1
                    )
                print(f"  [{self.agent_id}] [FIX] Task {task_id} released and set to READY")
            self.current_task = None
        return None
    
    def work(self, task: Task) -> bool:
        """
        Supervisor work loop - continuously monitors and fixes issues
        """
        # CRITICAL: Supervisor should never work on regular tasks
        # If a task is assigned to supervisor, release it immediately
        print(f"  [{self.agent_id}] [ERROR] Supervisor should not work on tasks! Releasing task: {task.id}")
        if task.id in self.coordinator.tasks:
            coordinator_task = self.coordinator.tasks[task.id]
            coordinator_task.assigned_agent = None
            coordinator_task.status = TaskStatus.READY
            # Update workload
            if coordinator_task.assigned_agent:
                self.coordinator.agent_workloads[coordinator_task.assigned_agent] = max(
                    0, self.coordinator.agent_workloads.get(coordinator_task.assigned_agent, 0) - 1
                )
            print(f"  [{self.agent_id}] [FIX] Task {task.id} released and set to READY for proper agent")
        self.current_task = None
        return True
    
    def _run_loop(self):
        """Supervisor monitoring loop"""
        while self._running and not self._stop_event.is_set():
            self._pause_event.wait()
            
            if self._stop_event.is_set():
                break
            
            # Run audit
            try:
                self._audit_team()
            except Exception as e:
                print(f"  [{self.agent_id}] [ERROR] Audit failed: {e}")
            
            # Run cleanup periodically (only when safe)
            try:
                if (datetime.now() - self.last_cleanup_time).total_seconds() >= self.cleanup_interval:
                    # Check if safe to clean before attempting
                    if self._is_safe_to_cleanup():
                        self._cleanup_workspace()
                        self.last_cleanup_time = datetime.now()
                    else:
                        # Still update last_cleanup_time to avoid checking too frequently
                        # But extend interval slightly if not safe
                        self.last_cleanup_time = datetime.now() - timedelta(seconds=self.cleanup_interval - 60)
            except Exception as e:
                print(f"  [{self.agent_id}] [ERROR] Cleanup check failed: {e}")
            
            # Wait before next audit
            self._stop_event.wait(timeout=self.audit_interval)
    
    def _audit_team(self):
        """Comprehensive audit of team work"""
        if LOGGING_AVAILABLE:
            AgentLogger.method_entry(self.agent_id, "_audit_team")
        
        if not self.project_dir:
            # Try to detect project directory
            self.project_dir = self._detect_project_dir()
            if not self.project_dir:
                if LOGGING_AVAILABLE:
                    AgentLogger.warning(self.agent_id, "Cannot audit: project_dir not available")
                    AgentLogger.method_exit(self.agent_id, "_audit_team", result="Skipped (no project_dir)")
                return  # Can't audit without project directory
        
        audit_start_time = time.time()
        if LOGGING_AVAILABLE:
            AgentLogger.info(self.agent_id, "Running team audit", extra={'project_dir': self.project_dir})
        print(f"  [{self.agent_id}] [AUDIT] Running team audit...")
        
        issues = []
        
        if LOGGING_AVAILABLE:
            AgentLogger.debug(self.agent_id, "Starting audit checks", extra={
                'total_tasks': len(self.coordinator.tasks),
                'project_dir': self.project_dir
            })
        
        # 1. Check completed tasks for missing artifacts
        issues.extend(self._check_completed_tasks())
        
        # 2. Check for missing files that should exist
        issues.extend(self._check_missing_files())
        
        # 3. Check final verification actually built executables
        issues.extend(self._check_final_verification())
        
        # 4. Check for stuck tasks (in progress too long)
        issues.extend(self._check_stuck_tasks())
        
        # 5. Check for tasks stuck in ASSIGNED status
        issues.extend(self._check_stuck_assigned_tasks())
        
        # 6. Check for premature completions
        issues.extend(self._check_premature_completions())
        
        # 7. Check build artifacts exist
        issues.extend(self._check_build_artifacts())
        
        # 8. Check if progress reached 100% - validate expected artifacts
        issues.extend(self._check_100_percent_completion())
        
        # 8.5. Check if all tasks are incorrectly marked as completed
        issues.extend(self._check_incorrectly_completed_tasks())
        
        # #region debug log
        _debug_log("supervisor_agent.py:201", "_audit_team: After step 8, before step 9", {
            "total_tasks": len(self.coordinator.tasks),
            "issues_count": len(issues)
        }, "H1")
        # #endregion
        
        # 9. Check for template tasks and complete them immediately
        try:
            template_keywords = ['example task', 'template', 'criterion 1', 'criterion 2', 'this is an example']
            template_tasks_completed = 0
            for task in self.coordinator.tasks.values():
                if task.status == TaskStatus.COMPLETED:
                    continue  # Skip already completed tasks
                
                task_text = f"{task.title} {task.description}".lower()
                is_template = any(keyword in task_text for keyword in template_keywords) or task.id == 'task-1'
                
                if is_template:
                    print(f"  [{self.agent_id}] [FIX] Found template task '{task.id}' - completing immediately", flush=True)
                    sys.stdout.flush()
                    from datetime import datetime
                    
                    # Use coordinator's complete_task method if task is assigned to an agent
                    if task.assigned_agent and task.assigned_agent != self.agent_id:
                        if self.coordinator.complete_task(task.id, task.assigned_agent):
                            template_tasks_completed += 1
                            self._persist_task_completion(task)
                            for other_task in self.coordinator.tasks.values():
                                if task.id in other_task.dependencies:
                                    self.coordinator._update_task_status(other_task.id)
                            continue
                    
                    # Complete directly
                    task.status = TaskStatus.COMPLETED
                    task.progress = 100
                    task.completed_at = datetime.now()
                    if not task.started_at:
                        task.started_at = task.completed_at
                    if task.assigned_agent and task.assigned_agent in self.coordinator.agent_workloads:
                        self.coordinator.agent_workloads[task.assigned_agent] = max(
                            0, self.coordinator.agent_workloads[task.assigned_agent] - 1
                        )
                    task.assigned_agent = None
                    template_tasks_completed += 1
                    self._persist_task_completion(task)
                    for other_task in self.coordinator.tasks.values():
                        if task.id in other_task.dependencies:
                            self.coordinator._update_task_status(other_task.id)
            
            if template_tasks_completed > 0:
                print(f"  [{self.agent_id}] [FIX] Completed {template_tasks_completed} template task(s)", flush=True)
                sys.stdout.flush()
                self.fixes_applied.append(f"Completed {template_tasks_completed} template task(s)")
        except Exception as e:
            print(f"  [{self.agent_id}] [ERROR] Exception completing template tasks: {e}")
            import traceback
            traceback.print_exc()
        
        # 10. Check for completed tasks that still have assigned agents or blocker messages (data inconsistency)
        try:
            completed_with_agent_fixed = 0
            completed_with_blocker_fixed = 0
            completed_tasks_count = 0
            completed_with_agent_count = 0
            for task in self.coordinator.tasks.values():
                if task.status == TaskStatus.COMPLETED:
                    completed_tasks_count += 1
                    needs_persistence = False
                    
                    if task.assigned_agent:
                        completed_with_agent_count += 1
                        # Completed tasks should not have assigned agents
                        print(f"  [{self.agent_id}] [FIX] Completed task '{task.id}' still has assigned agent '{task.assigned_agent}' - clearing", flush=True)
                        sys.stdout.flush()
                        
                        # Clear assigned agent
                        if task.assigned_agent in self.coordinator.agent_workloads:
                            self.coordinator.agent_workloads[task.assigned_agent] = max(
                                0, self.coordinator.agent_workloads[task.assigned_agent] - 1
                            )
                        task.assigned_agent = None
                        needs_persistence = True
                        completed_with_agent_fixed += 1
                    
                    if task.blocker_message:
                        # Completed tasks should not have blocker messages
                        print(f"  [{self.agent_id}] [FIX] Completed task '{task.id}' still has blocker message '{task.blocker_message}' - clearing", flush=True)
                        sys.stdout.flush()
                        task.blocker_message = None
                        needs_persistence = True
                        completed_with_blocker_fixed += 1
                    
                    if needs_persistence:
                        # Persist the fix to tasks.md
                        self._persist_task_completion(task)
            
            if completed_with_agent_fixed > 0 or completed_with_blocker_fixed > 0:
                fixes = []
                if completed_with_agent_fixed > 0:
                    fixes.append(f"{completed_with_agent_fixed} with assigned agents")
                if completed_with_blocker_fixed > 0:
                    fixes.append(f"{completed_with_blocker_fixed} with blocker messages")
                print(f"  [{self.agent_id}] [FIX] Fixed {completed_with_agent_fixed + completed_with_blocker_fixed} completed task(s): {', '.join(fixes)}", flush=True)
                sys.stdout.flush()
                self.fixes_applied.append(f"Fixed {completed_with_agent_fixed + completed_with_blocker_fixed} completed task(s) with data inconsistencies")
            elif completed_tasks_count > 0:
                # Debug: Log that we checked but found no issues
                print(f"  [{self.agent_id}] [DEBUG] Checked {completed_tasks_count} completed task(s), {completed_with_agent_count} had assigned agents", flush=True)
                sys.stdout.flush()
        except Exception as e:
            print(f"  [{self.agent_id}] [ERROR] Exception fixing completed tasks with assigned agents: {e}")
            import traceback
            traceback.print_exc()
        
        # 11. Check for pending tasks that should be ready or blocked (dependency status update)
        try:
            pending_tasks_updated = 0
            for task in self.coordinator.tasks.values():
                if task.status == TaskStatus.PENDING:
                    # Update task status based on dependencies
                    self.coordinator._update_task_status(task.id)
                    if task.status != TaskStatus.PENDING:
                        pending_tasks_updated += 1
                        print(f"  [{self.agent_id}] [FIX] Updated pending task '{task.id}' to {task.status.value}", flush=True)
                        sys.stdout.flush()
                        # Persist the status change
                        try:
                            from ..utils.task_config_parser import TaskConfigParser
                            parser = TaskConfigParser(self.project_dir)
                            parser.update_task_in_file(task)
                        except Exception as e:
                            print(f"  [{self.agent_id}] [WARNING] Failed to update tasks.md for task {task.id}: {e}", flush=True)
                            sys.stdout.flush()
            
            if pending_tasks_updated > 0:
                print(f"  [{self.agent_id}] [FIX] Updated {pending_tasks_updated} pending task(s) to ready/blocked", flush=True)
                sys.stdout.flush()
                self.fixes_applied.append(f"Updated {pending_tasks_updated} pending task(s) to ready/blocked")
        except Exception as e:
            print(f"  [{self.agent_id}] [ERROR] Exception updating pending tasks: {e}")
            import traceback
            traceback.print_exc()
        
        # 12. Check if only template tasks exist - generate real tasks from requirements
        try:
            print(f"  [{self.agent_id}] [DEBUG] About to check template tasks (total: {len(self.coordinator.tasks)})")
            # #region debug log
            _debug_log("supervisor_agent.py:206", "_audit_team: About to check template tasks", {
                "total_tasks": len(self.coordinator.tasks),
                "project_dir": self.project_dir
            }, "H1")
            # #endregion
            
            template_issue = self._check_template_tasks_only()
            print(f"  [{self.agent_id}] [DEBUG] Template check completed, result: {template_issue is not None}")
            
            # #region debug log
            _debug_log("supervisor_agent.py:190", "_audit_team: Template check result", {
                "template_issue": template_issue is not None,
                "issue_type": template_issue.get('type') if template_issue else None,
                "total_tasks": len(self.coordinator.tasks)
            }, "H1")
            # #endregion
            
            if template_issue:
                print(f"  [{self.agent_id}] [AUDIT] Found template tasks issue: {template_issue['type']}")
                issues.append(template_issue)
            else:
                print(f"  [{self.agent_id}] [AUDIT] No template tasks detected (tasks count: {len(self.coordinator.tasks)})")
        except Exception as e:
            print(f"  [{self.agent_id}] [ERROR] Exception in template check: {e}")
            import traceback
            traceback.print_exc()
            
            # #region debug log
            _debug_log("supervisor_agent.py:200", "_audit_team: Exception in template check", {
                "exception": str(e),
                "exception_type": type(e).__name__,
                "traceback": traceback.format_exc()
            }, "H2")
            # #endregion
        
        # Apply fixes
        audit_elapsed = time.time() - audit_start_time
        
        # #region debug log
        _debug_log("supervisor_agent.py:250", "_audit_team: About to apply fixes", {
            "issues_count": len(issues),
            "issue_types": [issue.get('type', 'unknown') for issue in issues] if issues else []
        }, "H3")
        # #endregion
        
        if issues:
            print(f"  [{self.agent_id}] [AUDIT] Found {len(issues)} issues in {audit_elapsed:.2f}s")
            if LOGGING_AVAILABLE:
                AgentLogger.info(self.agent_id, f"Found {len(issues)} issues during audit", extra={
                    'issue_count': len(issues),
                    'elapsed': audit_elapsed,
                    'issue_types': [issue.get('type', 'unknown') for issue in issues]
                })
            print(f"  [{self.agent_id}] [AUDIT] Starting to fix {len(issues)} issues...")
            for idx, issue in enumerate(issues):
                # #region debug log
                _debug_log("supervisor_agent.py:262", "_audit_team: About to fix issue", {
                    "issue_index": idx,
                    "total_issues": len(issues),
                    "issue_type": issue.get('type'),
                    "issue_severity": issue.get('severity')
                }, "H3")
                # #endregion
                print(f"  [{self.agent_id}] [AUDIT] Fixing issue {idx+1}/{len(issues)}: {issue.get('type')}")
                if LOGGING_AVAILABLE:
                    AgentLogger.info(self.agent_id, f"Fixing issue {idx+1}/{len(issues)}: {issue.get('type')}", extra={
                        'issue_index': idx,
                        'issue_type': issue.get('type'),
                        'issue_severity': issue.get('severity')
                    })
                try:
                    self._fix_issue(issue)
                    # #region debug log
                    _debug_log("supervisor_agent.py:280", "_audit_team: After fixing issue", {
                        "issue_index": idx,
                        "issue_type": issue.get('type')
                    }, "H3")
                    # #endregion
                except Exception as e:
                    print(f"  [{self.agent_id}] [ERROR] Exception fixing issue {issue.get('type')}: {e}")
                    import traceback
                    traceback.print_exc()
                    # #region debug log
                    _debug_log("supervisor_agent.py:288", "_audit_team: Exception fixing issue", {
                        "issue_index": idx,
                        "issue_type": issue.get('type'),
                        "exception": str(e),
                        "exception_type": type(e).__name__
                    }, "H3")
                    # #endregion
        else:
            print(f"  [{self.agent_id}] [AUDIT] No issues found (audit completed in {audit_elapsed:.2f}s)")
            if LOGGING_AVAILABLE:
                AgentLogger.debug(self.agent_id, "Audit completed with no issues", extra={'elapsed': audit_elapsed})
        
        self.last_audit_time = datetime.now()
    
    def _detect_project_dir(self) -> Optional[str]:
        """Detect project directory from coordinator or current working directory"""
        # Try to get from coordinator's runner if available
        if hasattr(self.coordinator, 'runner') and hasattr(self.coordinator.runner, 'project_dir'):
            return self.coordinator.runner.project_dir
        
        # Try to find by looking for requirements.md
        current = os.getcwd()
        for _ in range(5):
            if os.path.exists(os.path.join(current, 'requirements.md')):
                return current
            parent = os.path.dirname(current)
            if parent == current:
                break
            current = parent
        
        return os.getcwd()
    
    def _check_completed_tasks(self) -> List[Dict]:
        """Check that completed tasks actually have their artifacts"""
        issues = []
        
        for task in self.coordinator.tasks.values():
            if task.status == TaskStatus.COMPLETED:
                # Check artifacts exist
                if task.artifacts:
                    missing_artifacts = []
                    for artifact in task.artifacts:
                        # Resolve artifact path relative to project_dir
                        if self.project_dir and not os.path.isabs(artifact):
                            artifact_path = os.path.join(self.project_dir, artifact)
                        else:
                            artifact_path = artifact
                        
                        if not os.path.exists(artifact_path):
                            missing_artifacts.append(artifact)
                    
                    # Only report missing artifacts if task was not recently completed
                    # This prevents false positives when artifacts are still being created
                    if missing_artifacts:
                        recently_completed = False
                        if task.completed_at:
                            time_since_completion = datetime.now() - task.completed_at
                            if time_since_completion.total_seconds() < 1800:  # 30 minutes - longer grace period
                                recently_completed = True
                        
                        # Only report if not recently completed AND task has substantial progress
                        # Tasks with progress >= 50% are likely legitimate even if artifacts are missing
                        if not recently_completed and task.progress < 50:
                            issues.append({
                                'type': 'missing_artifacts',
                                'task_id': task.id,
                                'task_title': task.title,
                                'missing': missing_artifacts,
                                'severity': 'high'
                            })
                else:
                    # Task completed but no artifacts - suspicious
                    if 'setup' in task.id.lower() or 'implement' in task.id.lower():
                        issues.append({
                            'type': 'no_artifacts',
                            'task_id': task.id,
                            'task_title': task.title,
                            'severity': 'high'
                        })
        
        return issues
    
    def _check_missing_files(self) -> List[Dict]:
        """Check for critical files that should exist based on project type"""
        issues = []
        
        if not self.project_dir:
            return issues
        
        # Detect project type
        project_type = self._detect_project_type()
        
        if project_type == 'flutter':
            # Check Flutter-specific files
            required_files = {
                'pubspec.yaml': 'Flutter project configuration',
                'lib/main.dart': 'Flutter app entry point'
            }
            
            for file_path, description in required_files.items():
                full_path = os.path.join(self.project_dir, file_path)
                if not os.path.exists(full_path):
                    issues.append({
                        'type': 'missing_file',
                        'file': file_path,
                        'description': description,
                        'severity': 'critical'
                    })
            
            # Check for feature files that should exist based on completed tasks
            expected_files = self._get_expected_files_from_tasks()
            for file_path in expected_files:
                full_path = os.path.join(self.project_dir, file_path)
                if not os.path.exists(full_path):
                    # Check if there's a completed task that should have created this
                    task = self._find_task_for_file(file_path)
                    if task and task.status == TaskStatus.COMPLETED:
                        issues.append({
                            'type': 'missing_expected_file',
                            'file': file_path,
                            'task_id': task.id,
                            'task_title': task.title,
                            'severity': 'high'
                        })
        
        elif project_type == 'react_native':
            # Check React Native-specific files
            required_files = {
                'package.json': 'React Native project configuration',
                'App.js': 'React Native app entry point (or App.tsx)'
            }
            
            for file_path, description in required_files.items():
                full_path = os.path.join(self.project_dir, file_path)
                if not os.path.exists(full_path):
                    # Check for .tsx variant
                    if file_path == 'App.js':
                        tsx_path = os.path.join(self.project_dir, 'App.tsx')
                        if os.path.exists(tsx_path):
                            continue
                    issues.append({
                        'type': 'missing_file',
                        'file': file_path,
                        'description': description,
                        'severity': 'critical'
                    })
        
        return issues
    
    def _check_final_verification(self) -> List[Dict]:
        """Check that final verification actually built executables"""
        issues = []
        
        # Find final verification task
        final_task = None
        for task in self.coordinator.tasks.values():
            if 'final' in task.id.lower() and 'verification' in task.id.lower():
                final_task = task
                break
        
        if not final_task:
            return issues
        
        # If final verification is completed, check for build artifacts
        if final_task.status == TaskStatus.COMPLETED:
            project_type = self._detect_project_type()
            
            if project_type == 'flutter':
                # Check for build directory
                build_dir = os.path.join(self.project_dir, 'build')
                if not os.path.exists(build_dir):
                    issues.append({
                        'type': 'no_build_artifacts',
                        'description': 'Final verification completed but no build artifacts found',
                        'severity': 'critical',
                        'expected': 'build/ directory with APK, iOS, or Web builds'
                    })
                else:
                    # Check for specific build outputs
                    web_build = os.path.exists(os.path.join(build_dir, 'web'))
                    android_build = os.path.exists(os.path.join(build_dir, 'app', 'outputs', 'flutter-apk'))
                    ios_build = os.path.exists(os.path.join(build_dir, 'ios'))
                    
                    if not (web_build or android_build or ios_build):
                        issues.append({
                            'type': 'incomplete_build',
                            'description': 'Build directory exists but no actual builds found',
                            'severity': 'high',
                            'expected': 'Web, Android, or iOS build artifacts'
                        })
            
            elif project_type == 'react_native':
                # Check for React Native builds
                android_build = os.path.exists(os.path.join(self.project_dir, 'android', 'app', 'build', 'outputs', 'apk'))
                ios_build = os.path.exists(os.path.join(self.project_dir, 'ios', 'build'))
                dist_build = os.path.exists(os.path.join(self.project_dir, 'dist'))
                
                if not (android_build or ios_build or dist_build):
                    issues.append({
                        'type': 'no_build_artifacts',
                        'description': 'Final verification completed but no build artifacts found',
                        'severity': 'critical',
                        'expected': 'Android APK, iOS build, or dist/ directory'
                    })
        
        return issues
    
    def _check_stuck_tasks(self) -> List[Dict]:
        """Check for tasks that have been in progress too long - investigates after 10 minutes"""
        issues = []
        current_time = datetime.now()
        stuck_threshold = timedelta(minutes=3)  # 3 minutes - investigate stuck tasks quickly
        
        for task in self.coordinator.tasks.values():
            if task.status == TaskStatus.IN_PROGRESS:
                if task.started_at:
                    elapsed = current_time - task.started_at
                    if elapsed > stuck_threshold:
                        # Check if progress has changed
                        # Check if progress has changed - if no progress for 10 minutes, investigate
                        last_checkpoint_time = task.started_at
                        for cp in self.coordinator.checkpoints:
                            if cp.task_id == task.id and hasattr(cp, 'timestamp') and cp.timestamp:
                                if cp.timestamp > last_checkpoint_time:
                                    last_checkpoint_time = cp.timestamp
                        
                        time_since_last_progress = current_time - last_checkpoint_time
                        if time_since_last_progress > stuck_threshold:
                            # Investigate: Check if agent is actually working or stuck
                            assigned_agent = task.assigned_agent
                            agent_state = None
                            if assigned_agent and hasattr(self.coordinator, 'get_agent_state'):
                                agent_state = self.coordinator.get_agent_state(assigned_agent)
                            
                            issues.append({
                                'type': 'stuck_task',
                                'task_id': task.id,
                                'task_title': task.title,
                                'elapsed': str(elapsed),
                                'time_since_last_progress': str(time_since_last_progress),
                                'progress': task.progress,
                                'assigned_agent': assigned_agent,
                                'agent_state': agent_state.value if agent_state else 'unknown',
                                'severity': 'high'  # High severity - needs investigation
                            })
        
        return issues
    
    def _check_supervisor_assigned_tasks(self) -> List[Dict]:
        """Check for tasks incorrectly assigned to supervisor and release them"""
        issues = []
        
        for task in self.coordinator.tasks.values():
            # Check if task is assigned to supervisor but supervisor can't work on it
            if task.assigned_agent == self.agent_id and task.status in [TaskStatus.ASSIGNED, TaskStatus.IN_PROGRESS]:
                # Supervisor should only monitor, not implement
                # Release the task so a proper agent can pick it up
                issues.append({
                    'type': 'supervisor_assigned_task',
                    'task_id': task.id,
                    'task_title': task.title,
                    'severity': 'high',
                    'assigned_agent': task.assigned_agent
                            })
        
        return issues
    
    def _check_stuck_assigned_tasks(self) -> List[Dict]:
        """Check for tasks stuck in ASSIGNED status (assigned but never started)"""
        issues = []
        current_time = datetime.now()
        stuck_threshold = timedelta(minutes=5)  # 5 minutes without starting
        
        for task in self.coordinator.tasks.values():
            if task.status == TaskStatus.IN_PROGRESS and task.assigned_agent:
                # Check if task was assigned but never actually started (no checkpoints)
                if task.created_at:
                    elapsed = current_time - task.created_at
                    if elapsed > stuck_threshold:
                        # Check if there are any checkpoints
                        has_checkpoints = False
                        if hasattr(task, 'checkpoints') and task.checkpoints:
                            has_checkpoints = len(task.checkpoints) > 0
                        
                        if not has_checkpoints:
                            issues.append({
                                'type': 'stuck_assigned',
                                'task_id': task.id,
                                'task_title': task.title,
                                'assigned_agent': task.assigned_agent,
                                'elapsed': str(elapsed),
                                'severity': 'medium'
                            })
        
        return issues
    
    def _check_premature_completions(self) -> List[Dict]:
        """Check for tasks completed too quickly (likely premature)"""
        issues = []
        
        for task in self.coordinator.tasks.values():
            if task.status == TaskStatus.COMPLETED and task.started_at and task.completed_at:
                duration = task.completed_at - task.started_at
                
                # If completed in less than 5 seconds, it's suspicious
                if duration.total_seconds() < 5:
                    # Check if it's a setup or implementation task
                    if 'setup' in task.id.lower() or 'implement' in task.id.lower():
                        # Verify artifacts exist
                        if not task.artifacts or not all(os.path.exists(a) for a in task.artifacts):
                            issues.append({
                                'type': 'premature_completion',
                                'task_id': task.id,
                                'task_title': task.title,
                                'duration': str(duration),
                                'severity': 'high'
                            })
        
        return issues
    
    def _check_100_percent_completion(self) -> List[Dict]:
        """Check if progress reached 100% - validate expected artifacts"""
        issues = []
        
        # Check tasks that are at 100% progress
        for task in self.coordinator.tasks.values():
            if task.progress >= 100 and task.status != TaskStatus.COMPLETED:
                # Task at 100% but not marked as completed
                issues.append({
                    'type': 'assigned_at_100_percent',
                    'severity': 'medium',
                    'task_id': task.id,
                    'assigned_agent': task.assigned_agent,
                    'progress': task.progress
                })
        
        return issues
    
    def _check_incorrectly_completed_tasks(self) -> List[Dict]:
        """Check if tasks are incorrectly marked as completed when they shouldn't be"""
        issues = []
        
        # #region debug log
        _debug_log("supervisor_agent.py:592", "_check_incorrectly_completed_tasks: Entry", {
            "total_tasks": len(self.coordinator.tasks)
        }, "H4")
        # #endregion
        
        completed_tasks = [t for t in self.coordinator.tasks.values() if t.status == TaskStatus.COMPLETED]
        total_tasks = len(self.coordinator.tasks)
        
        # #region debug log
        _debug_log("supervisor_agent.py:598", "_check_incorrectly_completed_tasks: Found completed tasks", {
            "completed_count": len(completed_tasks),
            "total_tasks": total_tasks
        }, "H4")
        # #endregion
        
        # Only check if ALL tasks are completed (100%) AND there are at least 5 tasks
        # This prevents false positives when project is legitimately done or when there are very few tasks
        # Also add a check to ensure we don't reset tasks that were recently completed by agents
        if len(completed_tasks) == total_tasks and total_tasks >= 5:
            # Check if project is actually built/complete
            project_complete = False
            has_substantial_work = False
            tasks_with_artifacts = 0
            tasks_with_recent_completion = 0
            
            if self.project_dir:
                project_type = self._detect_project_type()
                
                # Count tasks with artifacts or recent completion
                for task in completed_tasks:
                    # Check if task has artifacts
                    if task.artifacts and len(task.artifacts) > 0:
                        tasks_with_artifacts += 1
                    
                    # Check if task was completed recently (within last hour)
                    if task.completed_at:
                        time_since_completion = datetime.now() - task.completed_at
                        if time_since_completion.total_seconds() < 3600:  # 1 hour
                            tasks_with_recent_completion += 1
                
                # Check if there's substantial work done
                if project_type == 'flutter':
                    lib_dir = os.path.join(self.project_dir, 'lib')
                    if os.path.exists(lib_dir):
                        # Count Dart files in lib/
                        dart_files = []
                        for root, dirs, files in os.walk(lib_dir):
                            dart_files.extend([f for f in files if f.endswith('.dart')])
                        
                        # If there are multiple Dart files, there's substantial work
                        if len(dart_files) >= 3:  # At least 3 Dart files
                            has_substantial_work = True
                    
                    # Check if build directory exists or main app files exist
                    build_dir = os.path.join(self.project_dir, 'build')
                    main_dart = os.path.join(self.project_dir, 'lib', 'main.dart')
                    
                    # Project is complete if build exists OR main.dart exists with substantial content
                    if os.path.exists(build_dir):
                        project_complete = True
                    elif os.path.exists(main_dart):
                        with open(main_dart, 'r', encoding='utf-8') as f:
                            content = f.read()
                        # If main.dart has more than just placeholder/TODO content
                        if len(content) > 500 and 'TODO' not in content[:200]:
                            project_complete = True
                
                # #region debug log
                _debug_log("supervisor_agent.py:625", "_check_incorrectly_completed_tasks: Project completeness check", {
                    "project_complete": project_complete,
                    "has_substantial_work": has_substantial_work,
                    "tasks_with_artifacts": tasks_with_artifacts,
                    "tasks_with_recent_completion": tasks_with_recent_completion,
                    "total_completed": len(completed_tasks),
                    "project_type": project_type
                }, "H4")
                # #endregion
            
            # Only flag as incorrectly completed if:
            # 1. Project is NOT complete AND
            # 2. There's NO substantial work AND
            # 3. Most tasks have NO artifacts AND
            # 4. Most tasks were NOT recently completed (likely auto-completed incorrectly)
            if not project_complete:
                # Check if most tasks lack artifacts (suspicious)
                tasks_without_artifacts = len(completed_tasks) - tasks_with_artifacts
                most_tasks_lack_artifacts = tasks_without_artifacts >= len(completed_tasks) * 0.7  # 70% or more lack artifacts
                
                # Check if most tasks were not recently completed (likely auto-completed)
                most_not_recent = tasks_with_recent_completion < len(completed_tasks) * 0.3  # Less than 30% recently completed
                
                # Only flag if there's no substantial work AND most tasks lack artifacts
                if not has_substantial_work and most_tasks_lack_artifacts and most_not_recent:
                    issues.append({
                        'type': 'all_tasks_incorrectly_completed',
                        'severity': 'critical',
                        'action': 'reset_all_tasks',
                        'incorrectly_completed_count': len(completed_tasks),
                        'total_tasks': total_tasks,
                        'reason': 'no_substantial_work_and_no_artifacts'
                    })
                    # #region debug log
                    _debug_log("supervisor_agent.py:640", "_check_incorrectly_completed_tasks: All tasks incorrectly completed", {
                        "incorrectly_completed_count": len(completed_tasks),
                        "total_tasks": total_tasks,
                        "project_complete": project_complete,
                        "has_substantial_work": has_substantial_work,
                        "tasks_with_artifacts": tasks_with_artifacts,
                        "most_tasks_lack_artifacts": most_tasks_lack_artifacts
                    }, "H4")
                    # #endregion
                else:
                    # #region debug log
                    _debug_log("supervisor_agent.py:650", "_check_incorrectly_completed_tasks: All tasks completed but validation passed", {
                        "has_substantial_work": has_substantial_work,
                        "tasks_with_artifacts": tasks_with_artifacts,
                        "tasks_without_artifacts": tasks_without_artifacts,
                        "most_tasks_lack_artifacts": most_tasks_lack_artifacts,
                        "tasks_with_recent_completion": tasks_with_recent_completion,
                        "most_not_recent": most_not_recent
                    }, "H4")
                    # #endregion
        
        return issues
    
    def _check_build_artifacts(self) -> List[Dict]:
        """Check that build artifacts exist if final verification passed"""
        issues = []
        
        # Check if all tasks are completed
        all_completed = all(
            t.status == TaskStatus.COMPLETED 
            for t in self.coordinator.tasks.values()
        )
        
        if all_completed:
            # Project should be built
            project_type = self._detect_project_type()
            
            if project_type == 'flutter':
                build_dir = os.path.join(self.project_dir, 'build')
                if not os.path.exists(build_dir):
                    issues.append({
                        'type': 'project_not_built',
                        'description': 'All tasks completed but project not built',
                        'severity': 'critical',
                        'action': 'Run flutter build web --release'
                    })
        
        return issues
    
    def _detect_project_type(self) -> str:
        """Detect project type from files"""
        if not self.project_dir:
            return 'unknown'
        
        if os.path.exists(os.path.join(self.project_dir, 'pubspec.yaml')):
            return 'flutter'
        elif os.path.exists(os.path.join(self.project_dir, 'package.json')):
            return 'react_native'
        elif os.path.exists(os.path.join(self.project_dir, 'requirements.txt')):
            return 'python'
        else:
            return 'unknown'
    
    def _get_expected_files_from_tasks(self) -> List[str]:
        """Get list of files that should exist based on completed tasks"""
        expected = []
        
        for task in self.coordinator.tasks.values():
            if task.status == TaskStatus.COMPLETED and task.artifacts:
                for artifact in task.artifacts:
                    # Make relative to project_dir
                    if os.path.isabs(artifact):
                        try:
                            rel_path = os.path.relpath(artifact, self.project_dir)
                            expected.append(rel_path)
                        except ValueError:
                            # Paths on different drives on Windows
                            pass
                    else:
                        expected.append(artifact)
        
        return expected
    
    def _find_task_for_file(self, file_path: str) -> Optional[Task]:
        """Find task that should have created this file"""
        for task in self.coordinator.tasks.values():
            if task.artifacts:
                for artifact in task.artifacts:
                    if file_path in artifact or artifact.endswith(file_path):
                        return task
        return None
    
    def _persist_task_completion(self, task: Task):
        """Helper method to persist task completion to tasks.md"""
        try:
            from ..utils.task_config_parser import TaskConfigParser
            parser = TaskConfigParser(self.project_dir)
            parser.update_task_in_file(task)
        except Exception as e:
            print(f"  [{self.agent_id}] [WARNING] Failed to update tasks.md: {e}", flush=True)
            sys.stdout.flush()
    
    def _fix_issue(self, issue: Dict):
        """Automatically fix an issue or create a fix task"""
        # #region debug log
        _debug_log("supervisor_agent.py:658", "_fix_issue: Entry", {
            "issue_type": issue.get('type'),
            "severity": issue.get('severity', 'medium'),
            "action": issue.get('action'),
            "full_issue": issue
        }, "H3")
        # #endregion
        
        issue_type = issue.get('type')
        severity = issue.get('severity', 'medium')
        
        print(f"  [{self.agent_id}] [FIX] Fixing issue: {issue_type} (severity: {severity})")
        
        # Handle template tasks or no tasks - generate from requirements
        # #region debug log
        _debug_log("supervisor_agent.py:672", "_fix_issue: Checking condition", {
            "issue_type": issue_type,
            "action": issue.get('action'),
            "is_template_or_no_tasks": issue_type in ['no_tasks', 'template_tasks_only'],
            "has_action": issue.get('action') == 'generate_tasks_from_requirements'
        }, "H3")
        # #endregion
        
        if issue_type in ['no_tasks', 'template_tasks_only']:
            if issue.get('action') == 'generate_tasks_from_requirements':
                # #region debug log
                _debug_log("supervisor_agent.py:580", "_fix_issue: About to generate tasks", {
                    "issue_type": issue_type,
                    "action": issue.get('action')
                }, "H3")
                # #endregion
                
                print(f"  [{self.agent_id}] [FIX] About to generate tasks from requirements...")
                if LOGGING_AVAILABLE:
                    AgentLogger.info(self.agent_id, "About to generate tasks from requirements", extra={
                        'issue_type': issue_type,
                        'action': issue.get('action')
                    })
                
                success = self._generate_tasks_from_requirements()
                
                # #region debug log
                _debug_log("supervisor_agent.py:588", "_fix_issue: Task generation result", {
                    "success": success
                }, "H3")
                # #endregion
                
                if success:
                    print(f"  [{self.agent_id}] [FIX] Successfully generated tasks from requirements")
                    if LOGGING_AVAILABLE:
                        AgentLogger.info(self.agent_id, "Successfully generated tasks from requirements")
                    self.fixes_applied.append("Generated tasks from requirements.md")
                else:
                    print(f"  [{self.agent_id}] [ERROR] Failed to generate tasks from requirements")
                    if LOGGING_AVAILABLE:
                        AgentLogger.error(self.agent_id, "Failed to generate tasks from requirements")
            return
        
        if issue_type == 'missing_artifacts':
            # Check if task was recently completed - if so, don't reset immediately
            # Artifacts might still be in the process of being created
            task_id = issue['task_id']
            task = self.coordinator.tasks.get(task_id)
            if task:
                # Check if task was completed recently (within last 10 minutes)
                recently_completed = False
                if task.completed_at:
                    time_since_completion = datetime.now() - task.completed_at
                    if time_since_completion.total_seconds() < 600:  # 10 minutes
                        recently_completed = True
                
                # Only reset if task was not recently completed AND has low progress
                # This prevents resetting tasks that just finished and artifacts are still being created
                if not recently_completed and task.progress < 50:
                    print(f"  [{self.agent_id}] [FIX] Resetting task '{task_id}' to ready (missing artifacts, not recently completed, low progress)")
                    self.send_status_update(
                        task_id,
                        TaskStatus.READY,
                        message=f"Supervisor: Missing artifacts detected - {', '.join(issue['missing'])}",
                        progress=0
                    )
                    self.fixes_applied.append(f"Reset task {task_id} to ready")
                else:
                    print(f"  [{self.agent_id}] [INFO] Task '{task_id}' missing artifacts but recently completed or has progress - preserving")
        
        elif issue_type == 'no_artifacts':
            # Check if task was recently completed - if so, don't reset immediately
            task_id = issue['task_id']
            task = self.coordinator.tasks.get(task_id)
            if task:
                # Check if task was completed recently (within last 30 minutes)
                recently_completed = False
                if task.completed_at:
                    time_since_completion = datetime.now() - task.completed_at
                    if time_since_completion.total_seconds() < 1800:  # 30 minutes - longer grace period
                        recently_completed = True
                
                # Only reset if task was not recently completed AND has very low progress
                # This prevents resetting tasks that just finished and might not have artifacts yet
                if not recently_completed and task.progress < 30:
                    print(f"  [{self.agent_id}] [FIX] Resetting task '{task_id}' to ready (no artifacts, not recently completed, very low progress)")
                    self.send_status_update(
                        task_id,
                        TaskStatus.READY,
                        message="Supervisor: Task completed without artifacts",
                        progress=0
                    )
                    self.fixes_applied.append(f"Reset task {task_id} to ready")
                else:
                    print(f"  [{self.agent_id}] [INFO] Task '{task_id}' has no artifacts but recently completed or has progress - preserving")
        
        elif issue_type == 'missing_file':
            # Create fix task
            file_path = issue['file']
            task_id = f"fix-missing-{file_path.replace('/', '-').replace('\\', '-')}"
            
            # Check if fix task already exists
            if task_id not in self.coordinator.tasks:
                print(f"  [{self.agent_id}] [FIX] Creating fix task for missing file: {file_path}")
                fix_task = Task(
                    id=task_id,
                    title=f"Fix Missing File: {file_path}",
                    description=f"Create missing file: {file_path}. {issue.get('description', '')}",
                    status=TaskStatus.READY,
                    progress=0,
                    estimated_hours=0.5,
                    dependencies=[],
                    assigned_agent=None,
                    created_at=datetime.now()
                )
                self.coordinator.add_task(fix_task)
                self.fixes_applied.append(f"Created fix task {task_id}")
        
        elif issue_type == 'missing_expected_file':
            # Reset the task that should have created this file
            task_id = issue['task_id']
            task = self.coordinator.tasks.get(task_id)
            if task:
                print(f"  [{self.agent_id}] [FIX] Resetting task '{task_id}' (expected file missing)")
                self.send_status_update(
                    task_id,
                    TaskStatus.READY,
                    message=f"Supervisor: Expected file missing: {issue['file']}",
                    progress=0
                )
                self.fixes_applied.append(f"Reset task {task_id} for missing file")
        
        elif issue_type == 'no_build_artifacts' or issue_type == 'incomplete_build':
            # Create build task
            task_id = "fix-build-artifacts"
            
            if task_id not in self.coordinator.tasks:
                print(f"  [{self.agent_id}] [FIX] Creating build task")
                project_type = self._detect_project_type()
                
                if project_type == 'flutter':
                    description = "Build Flutter app: flutter build web --release (and Android/iOS if SDKs available)"
                elif project_type == 'react_native':
                    description = "Build React Native app: npm run build or equivalent"
                else:
                    description = "Build the application"
                
                build_task = Task(
                    id=task_id,
                    title="Build Application Artifacts",
                    description=description,
                    status=TaskStatus.READY,
                    progress=0,
                    estimated_hours=1.0,
                    dependencies=[],
                    assigned_agent=None,
                    created_at=datetime.now()
                )
                self.coordinator.add_task(build_task)
                self.fixes_applied.append(f"Created build task {task_id}")
        
        elif issue_type == 'premature_completion':
            # Reset task
            task_id = issue['task_id']
            task = self.coordinator.tasks.get(task_id)
            if task:
                print(f"  [{self.agent_id}] [FIX] Resetting prematurely completed task '{task_id}'")
                self.send_status_update(
                    task_id,
                    TaskStatus.READY,
                    message=f"Supervisor: Task completed too quickly ({issue['duration']}) - likely incomplete",
                    progress=0
                )
                self.fixes_applied.append(f"Reset premature task {task_id}")
        
        elif issue_type == 'stuck_task':
            # Investigate and potentially reset or reassign
            task_id = issue['task_id']
            task = self.coordinator.tasks.get(task_id)
            if task:
                print(f"  [{self.agent_id}] [INVESTIGATE] Task '{task_id}' stuck for {issue.get('time_since_last_progress', 'unknown')}")
                print(f"  [{self.agent_id}] [INVESTIGATE] Assigned to: {issue.get('assigned_agent', 'unknown')}")
                print(f"  [{self.agent_id}] [INVESTIGATE] Agent state: {issue.get('agent_state', 'unknown')}")
                print(f"  [{self.agent_id}] [INVESTIGATE] Progress: {issue.get('progress', 0)}%")
                
                # Check if dependencies are blocking
                if task.dependencies:
                    blocking_deps = []
                    for dep_id in task.dependencies:
                        if dep_id in self.coordinator.tasks:
                            dep_task = self.coordinator.tasks[dep_id]
                            if dep_task.status != TaskStatus.COMPLETED:
                                blocking_deps.append(f"{dep_id} ({dep_task.status.value})")
                    
                    if blocking_deps:
                        print(f"  [{self.agent_id}] [INVESTIGATE] Blocked by dependencies: {', '.join(blocking_deps)}")
                
                # Check if artifacts exist but task not completed
                if task.artifacts:
                    missing_artifacts = [a for a in task.artifacts if not os.path.exists(a)]
                    if missing_artifacts:
                        print(f"  [{self.agent_id}] [INVESTIGATE] Missing artifacts: {', '.join(missing_artifacts)}")
                
                # If agent state is not running, or task has been stuck for a while, reset task to ready for reassignment
                agent_state = issue.get('agent_state', 'unknown')
                
                # Calculate total elapsed time since task started
                current_time = datetime.now()
                if task.started_at:
                    total_elapsed = current_time - task.started_at
                else:
                    total_elapsed = timedelta(0)
                
                # Parse time_since_last_progress from issue (it's stored as a string)
                time_since_last_progress_str = issue.get('time_since_last_progress', '0:00:00')
                if isinstance(time_since_last_progress_str, str):
                    # Try to parse the string format (e.g., "6:33:28")
                    try:
                        parts = time_since_last_progress_str.split(':')
                        if len(parts) == 3:
                            hours, minutes, seconds = map(int, parts)
                            time_since_last_progress = timedelta(hours=hours, minutes=minutes, seconds=seconds)
                        else:
                            time_since_last_progress = timedelta(0)
                    except:
                        time_since_last_progress = timedelta(0)
                else:
                    time_since_last_progress = time_since_last_progress_str
                
                # Extended threshold for very long stuck tasks (6 hours)
                extended_stuck_threshold = timedelta(hours=6)
                # Threshold for no progress (1 hour)
                no_progress_threshold = timedelta(hours=1)
                # Basic stuck threshold (3 minutes - from _check_stuck_tasks)
                basic_stuck_threshold = timedelta(minutes=3)
                
                # Also reset if task has 0% progress and has been stuck for more than threshold
                if task.progress == 0 and time_since_last_progress > basic_stuck_threshold:
                    print(f"  [{self.agent_id}] [FIX] Task '{task_id}' stuck at 0% progress - resetting to ready")
                    self.send_status_update(
                        task_id,
                        TaskStatus.READY,
                        message=f"Supervisor: Task stuck at 0% progress for {time_since_last_progress}. Resetting to ready.",
                        progress=0
                    )
                    task.assigned_agent = None
                    self.fixes_applied.append(f"Reset stuck task {task_id} (0% progress)")
                elif agent_state in ['stopped', 'error', 'paused']:
                    print(f"  [{self.agent_id}] [FIX] Agent not running - resetting task to ready for reassignment")
                    self.send_status_update(
                        task_id,
                        TaskStatus.READY,
                        message=f"Supervisor: Task stuck - agent {issue.get('assigned_agent')} not running. Resetting for reassignment.",
                        progress=task.progress  # Keep current progress
                    )
                    task.assigned_agent = None
                    self.fixes_applied.append(f"Reset stuck task {task_id} for reassignment")
                elif total_elapsed > extended_stuck_threshold:
                    # Task has been stuck for more than 6 hours - reset regardless of progress or agent state
                    print(f"  [{self.agent_id}] [FIX] Task '{task_id}' stuck for {total_elapsed} (>6 hours) - resetting to ready for reassignment")
                    self.send_status_update(
                        task_id,
                        TaskStatus.READY,
                        message=f"Supervisor: Task stuck for {total_elapsed} (exceeds 6 hour threshold). Resetting to ready for reassignment.",
                        progress=task.progress  # Keep current progress
                    )
                    task.assigned_agent = None
                    self.fixes_applied.append(f"Reset stuck task {task_id} (stuck for {total_elapsed})")
                elif time_since_last_progress > no_progress_threshold:
                    # Task has made no progress for more than 1 hour - reset even if agent is running
                    print(f"  [{self.agent_id}] [FIX] Task '{task_id}' has made no progress for {time_since_last_progress} (>1 hour) - resetting to ready")
                    self.send_status_update(
                        task_id,
                        TaskStatus.READY,
                        message=f"Supervisor: Task has made no progress for {time_since_last_progress} (exceeds 1 hour threshold). Resetting to ready.",
                        progress=task.progress  # Keep current progress
                    )
                    task.assigned_agent = None
                    self.fixes_applied.append(f"Reset stuck task {task_id} (no progress for {time_since_last_progress})")
                else:
                    # Agent is running but stuck - create investigation task or log for manual review
                    print(f"  [{self.agent_id}] [INVESTIGATE] Agent appears to be running but task is stuck - may need manual intervention")
                    self.fixes_applied.append(f"Investigated stuck task {task_id}")
        
        elif issue_type == 'all_tasks_incorrectly_completed':
            # All tasks are incorrectly marked as completed - reset them, but be selective
            # #region debug log
            _debug_log("supervisor_agent.py:962", "_fix_issue: Entering all_tasks_incorrectly_completed handler", {
                "incorrectly_completed_count": issue.get('incorrectly_completed_count', 0),
                "total_tasks": issue.get('total_tasks', 0),
                "reason": issue.get('reason', 'unknown')
            }, "H5")
            # #endregion
            
            print(f"  [{self.agent_id}] [FIX] All tasks incorrectly marked as completed - selectively resetting to ready/pending")
            # TaskStatus is already imported at module level
            
            reset_count = 0
            skipped_count = 0
            completed_before = len([t for t in self.coordinator.tasks.values() if t.status == TaskStatus.COMPLETED])
            
            # #region debug log
            _debug_log("supervisor_agent.py:975", "_fix_issue: Before reset loop", {
                "completed_before": completed_before,
                "total_tasks": len(self.coordinator.tasks)
            }, "H5")
            # #endregion
            
            for task in self.coordinator.tasks.values():
                if task.status == TaskStatus.COMPLETED:
                    # Don't reset tasks that have artifacts or were recently completed (within last 30 minutes)
                    # These are likely legitimately completed
                    should_reset = True
                    skip_reason = None
                    
                    # Check if task has artifacts
                    if task.artifacts and len(task.artifacts) > 0:
                        # Verify artifacts actually exist
                        artifacts_exist = False
                        for artifact in task.artifacts:
                            artifact_path = os.path.join(self.project_dir, artifact) if self.project_dir else artifact
                            if os.path.exists(artifact_path):
                                artifacts_exist = True
                                break
                        
                        if artifacts_exist:
                            should_reset = False
                            skip_reason = "has_artifacts"
                    
                    # Check if task was completed recently (within last 30 minutes)
                    if should_reset and task.completed_at:
                        time_since_completion = datetime.now() - task.completed_at
                        if time_since_completion.total_seconds() < 1800:  # 30 minutes
                            should_reset = False
                            skip_reason = "recently_completed"
                    
                    # Check if task has substantial progress (not just auto-completed)
                    # Only reset if ALL of these are true:
                    # 1. Progress < 30% (very low progress)
                    # 2. No artifacts exist
                    # 3. Not recently completed (already checked above)
                    if should_reset:
                        if task.progress < 30 and not artifacts_exist:
                            # Task has very low progress AND no artifacts - likely incorrectly marked
                            should_reset = True
                        else:
                            # Task has some progress or artifacts - preserve it
                            should_reset = False
                            if task.progress >= 30:
                                skip_reason = "has_substantial_progress"
                            elif artifacts_exist:
                                skip_reason = "has_artifacts"
                    
                    if should_reset:
                        # Reset based on dependencies
                        if task.dependencies:
                            task.status = TaskStatus.PENDING
                        else:
                            task.status = TaskStatus.READY
                        task.progress = 0
                        task.assigned_agent = None
                        task.completed_at = None
                        task.started_at = None
                        reset_count += 1
                        
                        # #region debug log
                        _debug_log("supervisor_agent.py:990", "_fix_issue: Reset task", {
                            "task_id": task.id,
                            "new_status": task.status.value,
                            "has_dependencies": bool(task.dependencies)
                        }, "H5")
                        # #endregion
                    else:
                        skipped_count += 1
                        # #region debug log
                        _debug_log("supervisor_agent.py:995", "_fix_issue: Skipped resetting task", {
                            "task_id": task.id,
                            "skip_reason": skip_reason,
                            "has_artifacts": bool(task.artifacts),
                            "progress": task.progress,
                            "completed_at": task.completed_at.isoformat() if task.completed_at else None
                        }, "H5")
                        # #endregion
            
            # #region debug log
            _debug_log("supervisor_agent.py:996", "_fix_issue: After reset loop", {
                "reset_count": reset_count
            }, "H5")
            # #endregion
            
            print(f"  [{self.agent_id}] [FIX] Reset {reset_count} tasks from completed to ready/pending (skipped {skipped_count} with artifacts/recent completion)")
            self.fixes_applied.append(f"Reset {reset_count} incorrectly completed tasks (preserved {skipped_count} legitimate completions)")
            
            # Update task statuses based on dependencies
            for task in self.coordinator.tasks.values():
                self.coordinator._update_task_status(task.id)
            
            # Update tasks.md file to persist the reset
            # This prevents tasks from being auto-completed again when the file is reloaded
            try:
                from ..utils.task_config_parser import TaskConfigParser
                parser = TaskConfigParser(self.project_dir)
                updated_count = 0
                for task in self.coordinator.tasks.values():
                    # Update all tasks that were reset (not completed, progress reset to 0)
                    if task.status != TaskStatus.COMPLETED and task.progress == 0:
                        # Update the file to reflect the reset
                        parser.update_task_in_file(task)
                        updated_count += 1
                print(f"  [{self.agent_id}] [FIX] Updated {updated_count} tasks in tasks.md file to persist reset")
                
                # #region debug log
                _debug_log("supervisor_agent.py:1027", "_fix_issue: Updated tasks.md file", {
                    "updated_count": updated_count
                }, "H5")
                # #endregion
            except Exception as e:
                print(f"  [{self.agent_id}] [WARNING] Failed to update tasks.md: {e}")
                import traceback
                traceback.print_exc()
                
                # #region debug log
                _debug_log("supervisor_agent.py:1035", "_fix_issue: Exception updating tasks.md", {
                    "exception": str(e),
                    "exception_type": type(e).__name__
                }, "H5")
                # #endregion
            
            # #region debug log
            ready_after = len([t for t in self.coordinator.tasks.values() if t.status == TaskStatus.READY])
            pending_after = len([t for t in self.coordinator.tasks.values() if t.status == TaskStatus.PENDING])
            completed_after = len([t for t in self.coordinator.tasks.values() if t.status == TaskStatus.COMPLETED])
            _debug_log("supervisor_agent.py:1010", "_fix_issue: After status updates", {
                "ready_after": ready_after,
                "pending_after": pending_after,
                "completed_after": completed_after
            }, "H5")
            # #endregion
        
        elif issue_type == 'some_tasks_incorrectly_completed':
            # Some tasks incorrectly completed - reset them
            task_ids = issue.get('task_ids', [])
            print(f"  [{self.agent_id}] [FIX] Resetting {len(task_ids)} incorrectly completed tasks")
            # TaskStatus is already imported at module level
            
            for task_id in task_ids:
                task = self.coordinator.tasks.get(task_id)
                if task and task.status == TaskStatus.COMPLETED:
                    if task.dependencies:
                        task.status = TaskStatus.PENDING
                    else:
                        task.status = TaskStatus.READY
                    task.progress = 0
                    task.assigned_agent = None
                    task.completed_at = None
                    task.started_at = None
                    self.coordinator._update_task_status(task_id)
            
            self.fixes_applied.append(f"Reset {len(task_ids)} incorrectly completed tasks")
        
        elif issue_type == 'assigned_at_100_percent':
            # Task has 100% progress but is still ASSIGNED/IN_PROGRESS - should be completed
            # TaskStatus is already imported at module level
            task_id = issue['task_id']
            task = self.coordinator.tasks.get(task_id)
            if task:
                # Double-check: if task is already completed, skip
                if task.status == TaskStatus.COMPLETED:
                    print(f"  [{self.agent_id}] [FIX] Task '{task_id}' is already COMPLETED - skipping fix", flush=True)
                    sys.stdout.flush()
                    return
                
                # Check if task is a template task - if so, complete it immediately
                template_keywords = ['example task', 'template', 'criterion 1', 'criterion 2', 'this is an example']
                task_text = f"{task.title} {task.description}".lower()
                is_template = any(keyword in task_text for keyword in template_keywords) or task.id == 'task-1'
                
                if is_template:
                    print(f"  [{self.agent_id}] [FIX] Template task '{task_id}' at 100% - completing immediately", flush=True)
                    sys.stdout.flush()
                    from datetime import datetime
                    
                    # Use coordinator's complete_task method if task is assigned to an agent
                    if task.assigned_agent and task.assigned_agent != self.agent_id:
                        if self.coordinator.complete_task(task_id, task.assigned_agent):
                            print(f"  [{self.agent_id}] [FIX] Marked template task '{task_id}' as COMPLETED", flush=True)
                            sys.stdout.flush()
                            self.fixes_applied.append(f"Completed template task {task_id}")
                            self._persist_task_completion(task)
                            for other_task in self.coordinator.tasks.values():
                                if task_id in other_task.dependencies:
                                    self.coordinator._update_task_status(other_task.id)
                            return
                    
                    # Complete directly
                    task.status = TaskStatus.COMPLETED
                    task.progress = 100
                    task.completed_at = datetime.now()
                    if not task.started_at:
                        task.started_at = task.completed_at
                    if task.assigned_agent and task.assigned_agent in self.coordinator.agent_workloads:
                        self.coordinator.agent_workloads[task.assigned_agent] = max(
                            0, self.coordinator.agent_workloads[task.assigned_agent] - 1
                        )
                    task.assigned_agent = None
                    print(f"  [{self.agent_id}] [FIX] Marked template task '{task_id}' as COMPLETED", flush=True)
                    sys.stdout.flush()
                    self.fixes_applied.append(f"Completed template task {task_id}")
                    self._persist_task_completion(task)
                    for other_task in self.coordinator.tasks.values():
                        if task_id in other_task.dependencies:
                            self.coordinator._update_task_status(other_task.id)
                    return
                
                print(f"  [{self.agent_id}] [FIX] Task '{task_id}' has 100% progress but status is {task.status.value} - checking completion", flush=True)
                print(f"  [{self.agent_id}] [DEBUG] Task artifacts: {task.artifacts}", flush=True)
                print(f"  [{self.agent_id}] [DEBUG] Task assigned to: {task.assigned_agent}", flush=True)
                sys.stdout.flush()
                if LOGGING_AVAILABLE:
                    AgentLogger.info(self.agent_id, f"Fixing assigned_at_100_percent for task {task_id}", task_id=task_id, extra={
                        'task_status': task.status.value,
                        'task_progress': task.progress,
                        'artifacts': task.artifacts,
                        'assigned_agent': task.assigned_agent
                    })
                
                # Check if artifacts exist (resolve paths relative to project_dir)
                artifacts_exist = False
                if task.artifacts:
                    missing_artifacts = []
                    for artifact in task.artifacts:
                        # Resolve artifact path relative to project_dir
                        if self.project_dir and not os.path.isabs(artifact):
                            artifact_path = os.path.join(self.project_dir, artifact)
                        else:
                            artifact_path = artifact
                        
                        if not os.path.exists(artifact_path):
                            missing_artifacts.append(artifact)
                    
                    if missing_artifacts:
                        print(f"  [{self.agent_id}] [WARNING] Some artifacts missing: {', '.join(missing_artifacts)}", flush=True)
                        sys.stdout.flush()
                        # For setup tasks, check if required files exist even if not in artifacts list
                        if 'setup' in task_id.lower() or 'initialize' in task_id.lower() or 'setup' in task.title.lower() or 'initialize' in task.title.lower() or 'flutter project' in task.title.lower():
                            # Check for common setup files
                            setup_files_exist = False
                            if self.project_dir:
                                pubspec_exists = os.path.exists(os.path.join(self.project_dir, 'pubspec.yaml'))
                                main_dart_exists = os.path.exists(os.path.join(self.project_dir, 'lib', 'main.dart'))
                                package_json_exists = os.path.exists(os.path.join(self.project_dir, 'package.json'))
                                
                                if pubspec_exists and main_dart_exists:
                                    setup_files_exist = True
                                    # Update artifacts to include these files
                                    if not task.artifacts:
                                        task.artifacts = []
                                    task.artifacts.extend([
                                        os.path.relpath(os.path.join(self.project_dir, 'pubspec.yaml'), self.project_dir),
                                        os.path.relpath(os.path.join(self.project_dir, 'lib', 'main.dart'), self.project_dir)
                                    ])
                                elif package_json_exists:
                                    setup_files_exist = True
                            
                            if setup_files_exist:
                                # Setup files exist - complete the task
                                from datetime import datetime
                                # Use coordinator's complete_task method if task is assigned to an agent
                                # Otherwise, complete directly
                                if task.assigned_agent and task.assigned_agent != self.agent_id:
                                    # Task assigned to another agent - try to complete via coordinator
                                    if self.coordinator.complete_task(task_id, task.assigned_agent):
                                        print(f"  [{self.agent_id}] [FIX] Marked setup task '{task_id}' as COMPLETED (setup files exist)")
                                        self.fixes_applied.append(f"Completed setup task {task_id} (setup files exist)")
                                        
                                        # Persist completion to tasks.md
                                        self._persist_task_completion(task)
                                        
                                        # Update dependent tasks
                                        for other_task in self.coordinator.tasks.values():
                                            if task_id in other_task.dependencies:
                                                self.coordinator._update_task_status(other_task.id)
                                        return
                                
                                # Complete directly (either no assigned agent or coordinator rejected)
                                task.status = TaskStatus.COMPLETED
                                task.progress = 100
                                task.completed_at = datetime.now()
                                if not task.started_at:
                                    task.started_at = task.completed_at
                                # Update agent workload if task was assigned
                                if task.assigned_agent and task.assigned_agent in self.coordinator.agent_workloads:
                                    self.coordinator.agent_workloads[task.assigned_agent] = max(
                                        0, self.coordinator.agent_workloads[task.assigned_agent] - 1
                                    )
                                task.assigned_agent = None
                                print(f"  [{self.agent_id}] [FIX] Marked setup task '{task_id}' as COMPLETED (setup files exist)")
                                self.fixes_applied.append(f"Completed setup task {task_id} (setup files exist)")
                                
                                # Persist completion to tasks.md
                                self._persist_task_completion(task)
                                
                                # Update dependent tasks
                                for other_task in self.coordinator.tasks.values():
                                    if task_id in other_task.dependencies:
                                        self.coordinator._update_task_status(other_task.id)
                                return
                        
                        # Reset to ready so it can be retried
                        self.send_status_update(
                            task_id,
                            TaskStatus.READY,
                            message=f"Supervisor: Task at 100% but artifacts missing. Resetting to ready.",
                            progress=100  # Keep progress
                        )
                        self.fixes_applied.append(f"Reset task {task_id} (100% but missing artifacts)")
                    else:
                        # All artifacts exist - complete the task
                        artifacts_exist = True
                else:
                    # No artifacts in task - check if it's a setup task and verify setup files exist
                    print(f"  [{self.agent_id}] [DEBUG] Task '{task_id}' has no artifacts - checking if setup task", flush=True)
                    sys.stdout.flush()
                    if 'setup' in task_id.lower() or 'initialize' in task_id.lower() or 'flutter project' in task.title.lower():
                        print(f"  [{self.agent_id}] [DEBUG] Task '{task_id}' is a setup/initialize task - checking for setup files", flush=True)
                        sys.stdout.flush()
                        if self.project_dir:
                            pubspec_exists = os.path.exists(os.path.join(self.project_dir, 'pubspec.yaml'))
                            main_dart_exists = os.path.exists(os.path.join(self.project_dir, 'lib', 'main.dart'))
                            package_json_exists = os.path.exists(os.path.join(self.project_dir, 'package.json'))
                            
                            if pubspec_exists and main_dart_exists:
                                # Setup files exist - complete the task
                                print(f"  [{self.agent_id}] [DEBUG] Setup files found for task '{task_id}' - completing", flush=True)
                                sys.stdout.flush()
                                from datetime import datetime
                                # Set artifacts first
                                task.artifacts = [
                                    os.path.relpath(os.path.join(self.project_dir, 'pubspec.yaml'), self.project_dir),
                                    os.path.relpath(os.path.join(self.project_dir, 'lib', 'main.dart'), self.project_dir)
                                ]
                                # Use coordinator's complete_task method if task is assigned to an agent
                                # Otherwise, complete directly
                                if task.assigned_agent and task.assigned_agent != self.agent_id:
                                    print(f"  [{self.agent_id}] [DEBUG] Attempting to complete via coordinator for agent {task.assigned_agent}", flush=True)
                                    sys.stdout.flush()
                                    # Task assigned to another agent - try to complete via coordinator
                                    if self.coordinator.complete_task(task_id, task.assigned_agent):
                                        print(f"  [{self.agent_id}] [FIX] Marked setup task '{task_id}' as COMPLETED (setup files exist)")
                                        self.fixes_applied.append(f"Completed setup task {task_id} (setup files exist)")
                                        
                                        # Persist completion to tasks.md
                                        self._persist_task_completion(task)
                                        
                                        # Update dependent tasks
                                        for other_task in self.coordinator.tasks.values():
                                            if task_id in other_task.dependencies:
                                                self.coordinator._update_task_status(other_task.id)
                                        return
                                
                                # Complete directly (either no assigned agent or coordinator rejected)
                                task.status = TaskStatus.COMPLETED
                                task.progress = 100
                                task.completed_at = datetime.now()
                                if not task.started_at:
                                    task.started_at = task.completed_at
                                # Update agent workload if task was assigned
                                if task.assigned_agent and task.assigned_agent in self.coordinator.agent_workloads:
                                    self.coordinator.agent_workloads[task.assigned_agent] = max(
                                        0, self.coordinator.agent_workloads[task.assigned_agent] - 1
                                    )
                                task.assigned_agent = None
                                print(f"  [{self.agent_id}] [FIX] Marked setup task '{task_id}' as COMPLETED (setup files exist)", flush=True)
                                sys.stdout.flush()
                                self.fixes_applied.append(f"Completed setup task {task_id} (setup files exist)")
                                
                                # Update tasks.md file to persist completion
                                try:
                                    from ..utils.task_config_parser import TaskConfigParser
                                    parser = TaskConfigParser(self.project_dir)
                                    parser.update_task_in_file(task)
                                except Exception as e:
                                    print(f"  [{self.agent_id}] [WARNING] Failed to update tasks.md: {e}")
                                
                                # Update dependent tasks
                                for other_task in self.coordinator.tasks.values():
                                    if task_id in other_task.dependencies:
                                        self.coordinator._update_task_status(other_task.id)
                                return
                            elif package_json_exists:
                                # React Native setup
                                from datetime import datetime
                                task.status = TaskStatus.COMPLETED
                                task.completed_at = datetime.now()
                                if not task.started_at:
                                    task.started_at = task.completed_at
                                task.artifacts = [
                                    os.path.relpath(os.path.join(self.project_dir, 'package.json'), self.project_dir)
                                ]
                                print(f"  [{self.agent_id}] [FIX] Marked setup task '{task_id}' as COMPLETED (package.json exists)")
                                self.fixes_applied.append(f"Completed setup task {task_id} (package.json exists)")
                                
                                # Persist completion to tasks.md
                                self._persist_task_completion(task)
                                
                                # Update dependent tasks
                                for other_task in self.coordinator.tasks.values():
                                    if task_id in other_task.dependencies:
                                        self.coordinator._update_task_status(other_task.id)
                                return
                
                # If we got here and artifacts exist, complete the task
                if artifacts_exist:
                    # All artifacts exist - complete the task
                    from datetime import datetime
                    # Use coordinator's complete_task method if task is assigned to an agent
                    # Otherwise, complete directly
                    if task.assigned_agent and task.assigned_agent != self.agent_id:
                        # Task assigned to another agent - try to complete via coordinator
                        if self.coordinator.complete_task(task_id, task.assigned_agent):
                            print(f"  [{self.agent_id}] [FIX] Marked task '{task_id}' as COMPLETED")
                            self.fixes_applied.append(f"Completed task {task_id} (was 100% but ASSIGNED)")
                            
                            # Persist completion to tasks.md
                            self._persist_task_completion(task)
                            
                            # Update dependent tasks
                            for other_task in self.coordinator.tasks.values():
                                if task_id in other_task.dependencies:
                                    self.coordinator._update_task_status(other_task.id)
                            return
                    
                    # Complete directly (either no assigned agent or coordinator rejected)
                    task.status = TaskStatus.COMPLETED
                    task.progress = 100
                    task.completed_at = datetime.now()
                    if not task.started_at:
                        task.started_at = task.completed_at
                    # Update agent workload if task was assigned
                    if task.assigned_agent and task.assigned_agent in self.coordinator.agent_workloads:
                        self.coordinator.agent_workloads[task.assigned_agent] = max(
                            0, self.coordinator.agent_workloads[task.assigned_agent] - 1
                        )
                    task.assigned_agent = None
                    print(f"  [{self.agent_id}] [FIX] Marked task '{task_id}' as COMPLETED")
                    self.fixes_applied.append(f"Completed task {task_id} (was 100% but ASSIGNED)")
                    
                    # Update tasks.md file to persist completion
                    try:
                        from ..utils.task_config_parser import TaskConfigParser
                        parser = TaskConfigParser(self.project_dir)
                        parser.update_task_in_file(task)
                    except Exception as e:
                        print(f"  [{self.agent_id}] [WARNING] Failed to update tasks.md: {e}")
                    
                    # Update dependent tasks
                    for other_task in self.coordinator.tasks.values():
                        if task_id in other_task.dependencies:
                            self.coordinator._update_task_status(other_task.id)
                elif not task.artifacts:
                    # No artifacts - might be a task that doesn't produce files
                    # If it's a verification/testing task, it might be legitimately done
                    if 'test' in task_id.lower() or 'verify' in task_id.lower() or 'verification' in task_id.lower():
                        print(f"  [{self.agent_id}] [FIX] Test/verification task at 100% - completing it")
                        from datetime import datetime
                        task.status = TaskStatus.COMPLETED
                        task.completed_at = datetime.now()
                        if not task.started_at:
                            task.started_at = task.completed_at
                        self.fixes_applied.append(f"Completed test task {task_id}")
                        
                        # Persist completion to tasks.md
                        self._persist_task_completion(task)
                        
                        # Update dependent tasks
                        for other_task in self.coordinator.tasks.values():
                            if task_id in other_task.dependencies:
                                self.coordinator._update_task_status(other_task.id)
                    else:
                        # Task at 100% progress should be completed by default, even without artifacts
                        # Most tasks at 100% are legitimately done
                        from datetime import datetime
                        
                        # Use coordinator's complete_task method if task is assigned to an agent
                        # Otherwise, complete directly
                        if task.assigned_agent and task.assigned_agent != self.agent_id:
                            # Task assigned to another agent - try to complete via coordinator
                            if self.coordinator.complete_task(task_id, task.assigned_agent):
                                print(f"  [{self.agent_id}] [FIX] Marked task '{task_id}' as COMPLETED (100% progress, no artifacts)")
                                self.fixes_applied.append(f"Completed task {task_id} (100% progress, no artifacts)")
                                
                                # Persist completion to tasks.md
                                self._persist_task_completion(task)
                                
                                # Update dependent tasks
                                for other_task in self.coordinator.tasks.values():
                                    if task_id in other_task.dependencies:
                                        self.coordinator._update_task_status(other_task.id)
                                return
                        
                        # Complete directly (either no assigned agent or coordinator rejected)
                        task.status = TaskStatus.COMPLETED
                        task.progress = 100
                        task.completed_at = datetime.now()
                        if not task.started_at:
                            task.started_at = task.completed_at
                        # Update agent workload if task was assigned
                        if task.assigned_agent and task.assigned_agent in self.coordinator.agent_workloads:
                            self.coordinator.agent_workloads[task.assigned_agent] = max(
                                0, self.coordinator.agent_workloads[task.assigned_agent] - 1
                        )
                        task.assigned_agent = None
                        print(f"  [{self.agent_id}] [FIX] Marked task '{task_id}' as COMPLETED (100% progress, no artifacts)")
                        self.fixes_applied.append(f"Completed task {task_id} (100% progress, no artifacts)")
                        
                        # Persist completion to tasks.md
                        self._persist_task_completion(task)
                        
                        # Update dependent tasks
                        for other_task in self.coordinator.tasks.values():
                            if task_id in other_task.dependencies:
                                self.coordinator._update_task_status(other_task.id)
        
        elif issue_type == 'stuck_assigned' or issue_type == 'assigned_to_stopped_agent':
            # Task stuck in ASSIGNED status - reset to READY
            task_id = issue['task_id']
            task = self.coordinator.tasks.get(task_id)
            if task:
                agent_state = issue.get('agent_state', 'unknown')
                print(f"  [{self.agent_id}] [FIX] Task '{task_id}' stuck in ASSIGNED status (agent: {issue.get('assigned_agent')}, state: {agent_state})")
                print(f"  [{self.agent_id}] [FIX] Resetting to READY for reassignment")
                
                self.send_status_update(
                    task_id,
                    TaskStatus.READY,
                    message=f"Supervisor: Task stuck in ASSIGNED status. Agent state: {agent_state}. Resetting to ready.",
                    progress=task.progress  # Keep current progress
                )
                task.assigned_agent = None  # Clear assignment
                self.fixes_applied.append(f"Reset stuck assigned task {task_id} to ready")
        
        elif issue_type == 'supervisor_assigned_task':
            # Task incorrectly assigned to supervisor - release it
            task_id = issue['task_id']
            task = self.coordinator.tasks.get(task_id)
            if task:
                print(f"  [{self.agent_id}] [FIX] Task '{task_id}' incorrectly assigned to supervisor. Releasing...")
                print(f"  [{self.agent_id}] [FIX] Task will be reassigned to appropriate agent (developer/tester)")
                
                # Release the task
                task.assigned_agent = None
                task.status = TaskStatus.READY
                
                # Update workload
                if task.assigned_agent:
                    self.coordinator.agent_workloads[task.assigned_agent] = max(
                        0, self.coordinator.agent_workloads.get(task.assigned_agent, 0) - 1
                    )
                
                # Update task status to trigger dependency checks
                self.coordinator._update_task_status(task_id)
                
                self.fixes_applied.append(f"Released task {task_id} from supervisor (supervisor only monitors)")
                print(f"  [{self.agent_id}] [OK] Task '{task_id}' released and set to READY")
        
        elif issue_type == 'missing_expected_artifacts_at_100':
            # Critical: Progress is 100% but expected artifacts are missing
            missing = issue.get('missing', [])
            print(f"  [{self.agent_id}] [CRITICAL] Progress is 100% but expected artifacts missing: {', '.join(missing)}")
            
            # Create fix tasks for missing artifacts
            for artifact_path in missing:
                fix_task_id = f"fix-missing-{artifact_path.replace('/', '-').replace('\\', '-').replace('.', '-')}"
                if fix_task_id not in self.coordinator.tasks:
                    fix_task = Task(
                        id=fix_task_id,
                        title=f"Create Missing Artifact: {artifact_path}",
                        description=f"Progress reached 100% but expected artifact is missing: {artifact_path}. Create this file to complete the project.",
                        status=TaskStatus.READY,
                        progress=0,
                        estimated_hours=1.0,
                        dependencies=[],
                        assigned_agent=None,
                        created_at=datetime.now()
                    )
                    self.coordinator.add_task(fix_task)
                    self.fixes_applied.append(f"Created fix task for missing artifact: {artifact_path}")
            
            # Also log this as a critical issue
            if LOGGING_AVAILABLE:
                AgentLogger.critical(self.agent_id, f"Progress 100% but artifacts missing: {', '.join(missing)}")
        
        elif issue_type == 'project_not_built':
            # If all tasks are incorrectly completed, don't create build task - reset tasks first
            # Check if there's an all_tasks_incorrectly_completed issue in the same audit
            # This will be handled by the all_tasks_incorrectly_completed handler
            print(f"  [{self.agent_id}] [FIX] Project not built - but checking if tasks need reset first")
            # Don't create build task if tasks are incorrectly completed - let the reset happen first
            # The build task will be created in the next audit cycle after tasks are reset
        
        self.issues_found.append(issue)
    
    def _is_safe_to_cleanup(self) -> bool:
        """Check if it's safe to clean up the workspace (no active work happening)"""
        if not self.coordinator or not self.coordinator.tasks:
            return True  # No tasks means safe to clean
        
        # Check if any tasks are actively being worked on
        active_tasks = [
            task for task in self.coordinator.tasks.values()
            if task.status in [TaskStatus.IN_PROGRESS, TaskStatus.ASSIGNED]
        ]
        
        if active_tasks:
            # There are active tasks - not safe to clean
            if LOGGING_AVAILABLE:
                AgentLogger.debug(self.agent_id, "Cleanup skipped - active tasks in progress", extra={
                    'active_task_count': len(active_tasks),
                    'active_tasks': [t.id for t in active_tasks[:5]]
                })
            return False
        
        # Check if all tasks are completed (end of project - safe to clean)
        all_tasks = list(self.coordinator.tasks.values())
        all_completed = all(task.status == TaskStatus.COMPLETED for task in all_tasks)
        
        if all_completed:
            # All tasks completed - definitely safe to clean
            if LOGGING_AVAILABLE:
                AgentLogger.debug(self.agent_id, "Cleanup safe - all tasks completed", extra={
                    'total_tasks': len(all_tasks)
                })
            return True
        
        # Check if there are any ready tasks that might be picked up soon
        ready_tasks = [task for task in all_tasks if task.status == TaskStatus.READY]
        
        # If there are ready tasks, wait a bit longer to see if they get picked up
        # But if there are no ready tasks and no active tasks, it's safe
        if not ready_tasks:
            # No ready tasks and no active tasks - safe to clean
            if LOGGING_AVAILABLE:
                AgentLogger.debug(self.agent_id, "Cleanup safe - no active or ready tasks", extra={
                    'total_tasks': len(all_tasks),
                    'completed': sum(1 for t in all_tasks if t.status == TaskStatus.COMPLETED),
                    'blocked': sum(1 for t in all_tasks if t.status == TaskStatus.BLOCKED)
                })
            return True
        
        # There are ready tasks that might be picked up - wait a bit
        # Only clean if it's been a while since last activity
        if hasattr(self, 'last_cleanup_time'):
            time_since_last_cleanup = (datetime.now() - self.last_cleanup_time).total_seconds()
            # If it's been more than 10 minutes since last cleanup attempt and no active work, safe
            if time_since_last_cleanup > 600:  # 10 minutes
                if LOGGING_AVAILABLE:
                    AgentLogger.debug(self.agent_id, "Cleanup safe - long idle period", extra={
                        'idle_seconds': time_since_last_cleanup,
                        'ready_tasks': len(ready_tasks)
                    })
                return True
        
        # Default: not safe if there are ready tasks that might be picked up
        return False
    
    def _cleanup_workspace(self):
        """Clean up temporary files and directories in the workspace (only when safe)"""
        if not self.project_dir or not os.path.exists(self.project_dir):
            return
        
        if not CLEANUP_AVAILABLE:
            return
        
        # Check if it's safe to clean up
        if not self._is_safe_to_cleanup():
            return  # Skip cleanup if not safe
        
        try:
            if LOGGING_AVAILABLE:
                AgentLogger.info(self.agent_id, "Starting workspace cleanup", extra={'project_dir': self.project_dir})
            
            # Get temporary files older than 24 hours
            temp_files = get_temporary_files(self.project_dir, max_age_hours=24)
            
            deleted_files = []
            for filepath in temp_files:
                try:
                    if os.path.exists(filepath):
                        os.remove(filepath)
                        deleted_files.append(filepath)
                        if LOGGING_AVAILABLE:
                            AgentLogger.debug(self.agent_id, f"Deleted temporary file: {os.path.basename(filepath)}", 
                                            extra={'filepath': filepath})
                except OSError as e:
                    if LOGGING_AVAILABLE:
                        AgentLogger.warning(self.agent_id, f"Could not delete file: {filepath}", extra={'error': str(e)})
            
            # Clean up empty temporary directories
            cleaned_dirs = cleanup_empty_directories(self.project_dir, TEMPORARY_DIRS)
            
            if deleted_files or cleaned_dirs:
                print(f"  [{self.agent_id}] [CLEANUP] Cleaned {len(deleted_files)} files and {len(cleaned_dirs)} directories")
                if LOGGING_AVAILABLE:
                    AgentLogger.info(self.agent_id, "Workspace cleanup completed", extra={
                        'deleted_files': len(deleted_files),
                        'cleaned_dirs': len(cleaned_dirs)
                    })
                self.fixes_applied.append(f"Cleaned {len(deleted_files)} temporary files and {len(cleaned_dirs)} empty directories")
        except Exception as e:
            print(f"  [{self.agent_id}] [ERROR] Cleanup failed: {e}")
            if LOGGING_AVAILABLE:
                AgentLogger.error(self.agent_id, f"Workspace cleanup failed: {e}")
    
    def _check_template_tasks_only(self) -> Optional[Dict]:
        """Check if only template tasks exist and need to generate real tasks from requirements"""
        # #region debug log
        _debug_log("supervisor_agent.py:905", "_check_template_tasks_only: Entry", {
            "project_dir": self.project_dir,
            "tasks_count": len(self.coordinator.tasks) if self.coordinator.tasks else 0
        }, "H1")
        # #endregion
        
        if not self.project_dir:
            print(f"  [{self.agent_id}] [CHECK] No project_dir - skipping template check")
            # #region debug log
            _debug_log("supervisor_agent.py:910", "_check_template_tasks_only: No project_dir", {}, "H1")
            # #endregion
            return None
        
        # Check if we have tasks
        if not self.coordinator.tasks:
            print(f"  [{self.agent_id}] [CHECK] No tasks found - will generate from requirements")
            # #region debug log
            import json
            try:
                with open('.cursor/debug.log', 'a', encoding='utf-8') as f:
                    f.write(json.dumps({'location': 'supervisor_agent.py:2057', 'message': '_check_template_tasks_only: No tasks found', 'data': {'action': 'generate_tasks_from_requirements', 'project_dir': self.project_dir}, 'timestamp': time.time(), 'sessionId': 'debug-session', 'runId': 'run1', 'hypothesisId': 'B'}) + '\n')
            except: pass
            # #endregion
            return {
                'type': 'no_tasks',
                'severity': 'critical',
                'action': 'generate_tasks_from_requirements'
            }
        
        # Check if all tasks are template tasks (have "Example Task" or similar)
        template_keywords = ['example task', 'template', 'criterion 1', 'criterion 2', 'this is an example']
        all_template = True
        template_count = 0
        total_tasks = len(self.coordinator.tasks)
        
        print(f"  [{self.agent_id}] [CHECK] Checking {total_tasks} tasks for template patterns...")
        if LOGGING_AVAILABLE:
            AgentLogger.debug(self.agent_id, f"Checking {total_tasks} tasks for template patterns", extra={
                'total_tasks': total_tasks,
                'template_keywords': template_keywords
            })
        
        for task in self.coordinator.tasks.values():
            task_text = f"{task.title} {task.description}".lower()
            is_template = any(keyword in task_text for keyword in template_keywords)
            if is_template:
                template_count += 1
                print(f"  [{self.agent_id}] [CHECK] Task '{task.title}' is a template task")
                if LOGGING_AVAILABLE:
                    AgentLogger.debug(self.agent_id, f"Task is template: {task.title}", task_id=task.id, extra={
                        'task_title': task.title,
                        'matched_keywords': [kw for kw in template_keywords if kw in task_text]
                    })
            else:
                all_template = False
                print(f"  [{self.agent_id}] [CHECK] Found non-template task: {task.title}")
                if LOGGING_AVAILABLE:
                    AgentLogger.debug(self.agent_id, f"Found non-template task: {task.title}", task_id=task.id)
                break
        
        print(f"  [{self.agent_id}] [CHECK] Template check result: all_template={all_template}, template_count={template_count}, total_tasks={total_tasks}")
        if LOGGING_AVAILABLE:
            AgentLogger.debug(self.agent_id, "Template check completed", extra={
                'all_template': all_template,
                'template_count': template_count,
                'total_tasks': total_tasks
            })
        
        # If all tasks are template tasks and we have 2 or fewer tasks, generate real tasks
        if all_template and total_tasks <= 2:
            print(f"  [{self.agent_id}] [CHECK] ✓ Detected template tasks only - will generate from requirements")
            if LOGGING_AVAILABLE:
                AgentLogger.info(self.agent_id, "Detected template tasks only - will generate from requirements", extra={
                    'template_count': template_count,
                    'total_tasks': total_tasks,
                    'action': 'generate_tasks_from_requirements'
                })
            # #region debug log
            _debug_log("supervisor_agent.py:960", "_check_template_tasks_only: Detected template tasks", {
                "all_template": all_template,
                "template_count": template_count,
                "total_tasks": total_tasks,
                "action": "generate_tasks_from_requirements"
            }, "H1")
            # #endregion
            return {
                'type': 'template_tasks_only',
                'severity': 'critical',
                'action': 'generate_tasks_from_requirements'
            }
        
        # Also check if we have very few tasks (1-2) which suggests we need to generate more
        # This handles the case where the template task was completed
        if total_tasks <= 2:
            # #region debug log
            _debug_log("supervisor_agent.py:976", "_check_template_tasks_only: Checking few tasks case", {
                "total_tasks": total_tasks,
                "all_template": all_template
            }, "H1")
            # #endregion
            
            # Check if requirements.md exists and has substantial content
            requirements_file = os.path.join(self.project_dir, "requirements.md")
            if os.path.exists(requirements_file):
                with open(requirements_file, 'r', encoding='utf-8') as f:
                    req_content = f.read()
                # #region debug log
                _debug_log("supervisor_agent.py:983", "_check_template_tasks_only: Requirements file check", {
                    "requirements_exists": True,
                    "requirements_length": len(req_content),
                    "threshold": 500
                }, "H1")
                # #endregion
                
                # If requirements are substantial but we have few tasks, generate tasks
                if len(req_content) > 500:  # Substantial requirements
                    print(f"  [{self.agent_id}] [CHECK] ✓ Few tasks ({total_tasks}) but substantial requirements ({len(req_content)} chars) - generating tasks")
                    # #region debug log
                    _debug_log("supervisor_agent.py:990", "_check_template_tasks_only: Triggering task generation", {
                        "total_tasks": total_tasks,
                        "requirements_length": len(req_content),
                        "action": "generate_tasks_from_requirements"
                    }, "H1")
                    # #endregion
                    return {
                        'type': 'template_tasks_only',
                        'severity': 'critical',
                        'action': 'generate_tasks_from_requirements'
                    }
            else:
                # #region debug log
                _debug_log("supervisor_agent.py:995", "_check_template_tasks_only: Requirements file not found", {
                    "requirements_file": requirements_file
                }, "H1")
                # #endregion
        
        print(f"  [{self.agent_id}] [CHECK] No action needed - tasks look valid")
        # #region debug log
        _debug_log("supervisor_agent.py:1000", "_check_template_tasks_only: No action needed", {
            "all_template": all_template,
            "total_tasks": total_tasks
        }, "H1")
        # #endregion
        return None
    
    def _generate_tasks_from_requirements(self) -> bool:
        """Generate tasks from requirements.md using Cursor CLI"""
        # #region debug log
        _debug_log("supervisor_agent.py:994", "_generate_tasks_from_requirements: Entry", {
            "project_dir": self.project_dir
        }, "H3")
        # #endregion
        
        # Check if tasks have already been generated (prevent multiple generations)
        # If we have more than 2 tasks that are not template tasks, don't regenerate
        non_template_tasks = [
            t for t in self.coordinator.tasks.values()
            if not (t.title.lower().startswith('example') or 'template' in t.title.lower() or t.id == 'task-1')
        ]
        if len(non_template_tasks) > 2:
            print(f"  [{self.agent_id}] [GENERATE] Tasks already generated ({len(non_template_tasks)} non-template tasks) - skipping regeneration")
            if LOGGING_AVAILABLE:
                AgentLogger.info(self.agent_id, "Tasks already generated - skipping regeneration", extra={
                    'non_template_count': len(non_template_tasks),
                    'total_count': len(self.coordinator.tasks)
                })
            return True  # Return True to indicate "success" (tasks already exist)
        
        print(f"  [{self.agent_id}] [GENERATE] Starting task generation...", flush=True)
        # #region debug log
        import json
        try:
            with open('.cursor/debug.log', 'a', encoding='utf-8') as f:
                f.write(json.dumps({'location': 'supervisor_agent.py:2209', 'message': '_generate_tasks_from_requirements: Starting', 'data': {'project_dir': self.project_dir}, 'timestamp': time.time(), 'sessionId': 'debug-session', 'runId': 'run1', 'hypothesisId': 'C'}) + '\n')
        except: pass
        # #endregion
        if LOGGING_AVAILABLE:
            AgentLogger.info(self.agent_id, "Starting task generation", extra={'project_dir': self.project_dir})
        
        print(f"  [{self.agent_id}] [GENERATE] Method entry point reached, project_dir: {self.project_dir}", flush=True)
        import sys
        sys.stdout.flush()
        
        if not self.project_dir:
            print(f"  [{self.agent_id}] [ERROR] No project_dir set - cannot generate tasks")
            # #region debug log
            _debug_log("supervisor_agent.py:999", "_generate_tasks_from_requirements: No project_dir", {}, "H3")
            # #endregion
            return False
        
        requirements_file = os.path.join(self.project_dir, "requirements.md")
        if not os.path.exists(requirements_file):
            print(f"  [{self.agent_id}] [ERROR] requirements.md not found at {requirements_file}")
            if LOGGING_AVAILABLE:
                AgentLogger.error(self.agent_id, "requirements.md not found", extra={'requirements_file': requirements_file})
            # #region debug log
            _debug_log("supervisor_agent.py:1005", "_generate_tasks_from_requirements: requirements.md not found", {
                "requirements_file": requirements_file
            }, "H3")
            # #endregion
            return False
        
        print(f"  [{self.agent_id}] [GENERATE] Found requirements.md, checking Cursor CLI...")
        if LOGGING_AVAILABLE:
            AgentLogger.info(self.agent_id, "Found requirements.md, checking Cursor CLI")
        
        # Try to import Cursor CLI client
        try:
            from ..utils.cursor_cli_client import create_cursor_cli_client
            cursor_cli = create_cursor_cli_client()
            
            if not cursor_cli or not cursor_cli.is_available():
                print(f"  [{self.agent_id}] [WARNING] Cursor CLI not available - cannot generate tasks")
                if LOGGING_AVAILABLE:
                    AgentLogger.warning(self.agent_id, "Cursor CLI not available - cannot generate tasks")
                return False
            print(f"  [{self.agent_id}] [GENERATE] Cursor CLI is available, proceeding with task generation...")
            if LOGGING_AVAILABLE:
                AgentLogger.info(self.agent_id, "Cursor CLI is available, proceeding with task generation")
        except ImportError as e:
            print(f"  [{self.agent_id}] [WARNING] cursor_cli_client not available - cannot generate tasks: {e}")
            if LOGGING_AVAILABLE:
                AgentLogger.error(self.agent_id, f"cursor_cli_client not available: {e}")
            import traceback
            traceback.print_exc()
            return False
        
        # Read requirements - initialize variable to ensure it's in scope
        requirements_content = None
        print(f"  [{self.agent_id}] [GENERATE] Reading requirements from {requirements_file}...", flush=True)
        if LOGGING_AVAILABLE:
            AgentLogger.info(self.agent_id, "Reading requirements file", extra={'requirements_file': requirements_file})
        import sys
        sys.stdout.flush()
        
        try:
            with open(requirements_file, 'r', encoding='utf-8') as f:
                requirements_content = f.read()
            print(f"  [{self.agent_id}] [GENERATE] Read {len(requirements_content)} characters from requirements.md", flush=True)
            if LOGGING_AVAILABLE:
                AgentLogger.info(self.agent_id, "Read requirements file", extra={'content_length': len(requirements_content)})
            sys.stdout.flush()
        except Exception as read_error:
            print(f"  [{self.agent_id}] [ERROR] Failed to read requirements.md: {read_error}", flush=True)
            if LOGGING_AVAILABLE:
                AgentLogger.error(self.agent_id, f"Failed to read requirements.md: {read_error}")
            sys.stdout.flush()
            return False
        
        if not requirements_content:
            print(f"  [{self.agent_id}] [ERROR] requirements_content is None or empty", flush=True)
            if LOGGING_AVAILABLE:
                AgentLogger.error(self.agent_id, "requirements_content is None or empty")
            sys.stdout.flush()
            return False
        
        # First, analyze requirements to determine optimal team size
        print(f"  [{self.agent_id}] [GENERATE] Analyzing requirements for team size...")
        team_size_recommendation = self._analyze_requirements_for_team_size(requirements_content)
        if team_size_recommendation:
            self.optimal_team_size = team_size_recommendation
            print(f"  [{self.agent_id}] [ANALYSIS] Recommended team size: {team_size_recommendation['developers']} developers, {team_size_recommendation['testers']} testers")
            if LOGGING_AVAILABLE:
                AgentLogger.info(self.agent_id, "Team size analysis complete", extra=team_size_recommendation)
        
        # Generate tasks using Cursor CLI
        print(f"  [{self.agent_id}] [GENERATE] Creating prompt for task generation...")
        if LOGGING_AVAILABLE:
            AgentLogger.info(self.agent_id, "Creating prompt for task generation")
        
        # Initialize prompt variable
        prompt = None
        try:
            # Ask it to write the file directly to the workspace
            prompt = f"""You are a Supervisor in an AI Dev Team. Write a comprehensive tasks.md file to the workspace.

Requirements:
{requirements_content}

Write a tasks.md file with ALL tasks needed to implement this project. Use this EXACT format for each task:

### task-id-here
- Title: Task Title Here
- Description: Detailed task description here
- Status: pending
- Progress: 0
- Estimated Hours: X.X
- Dependencies: task-id-1, task-id-2 (or "none" if no dependencies)
- Acceptance Criteria:
  - Criterion 1
  - Criterion 2
  - Criterion 3

Generate at least 20-30 tasks covering: project setup, core features, UI components, testing, and deployment.

Write the file now using your file writing tools. The file should be at tasks.md in the current workspace.
- Dependencies: task-id-1, task-id-2
- Acceptance Criteria:
  - Criterion 1
  - Criterion 2

Generate ALL tasks needed to complete this project from start to finish."""
            print(f"  [{self.agent_id}] [GENERATE] Prompt created ({len(prompt)} characters)")
            if LOGGING_AVAILABLE:
                AgentLogger.info(self.agent_id, "Prompt created", extra={'prompt_length': len(prompt)})
        except Exception as prompt_error:
            print(f"  [{self.agent_id}] [ERROR] Failed to create prompt: {prompt_error}")
            if LOGGING_AVAILABLE:
                AgentLogger.error(self.agent_id, f"Failed to create prompt: {prompt_error}")
            import traceback
            traceback.print_exc()
            return False
        
        # Ensure we have the prompt variable
        print(f"  [{self.agent_id}] [GENERATE] Checking prompt variable (type: {type(prompt).__name__}, length: {len(prompt) if prompt else 0})...", flush=True)
        import sys
        sys.stdout.flush()
        if not prompt:
            print(f"  [{self.agent_id}] [ERROR] Prompt variable is None or empty after creation", flush=True)
            if LOGGING_AVAILABLE:
                AgentLogger.error(self.agent_id, "Prompt variable is None or empty after creation")
            sys.stdout.flush()
            return False
        print(f"  [{self.agent_id}] [GENERATE] Prompt variable check passed", flush=True)
        sys.stdout.flush()
        
        print(f"  [{self.agent_id}] [GENERATE] Prompt validation passed, proceeding to generation...", flush=True)
        if LOGGING_AVAILABLE:
            AgentLogger.info(self.agent_id, "Prompt validation passed, proceeding to generation")
        import sys
        sys.stdout.flush()
        
        # Set generate_start_time - wrap in try/except to catch any issues
        generate_start_time = None
        try:
            print(f"  [{self.agent_id}] [GENERATE] About to set generate_start_time...", flush=True)
            if LOGGING_AVAILABLE:
                AgentLogger.info(self.agent_id, "About to set generate_start_time")
            sys.stdout.flush()
            generate_start_time = time.time()
            print(f"  [{self.agent_id}] [GENERATE] generate_start_time set: {generate_start_time}", flush=True)
            if LOGGING_AVAILABLE:
                AgentLogger.info(self.agent_id, "generate_start_time set", extra={'generate_start_time': generate_start_time})
            sys.stdout.flush()
            print(f"  [{self.agent_id}] [GENERATE] Starting generation process (prompt length: {len(prompt)})...", flush=True)
            if LOGGING_AVAILABLE:
                AgentLogger.info(self.agent_id, "Starting generation process", extra={'prompt_length': len(prompt)})
            sys.stdout.flush()
            print(f"  [{self.agent_id}] [GENERATE] About to enter try block for Cursor CLI call...", flush=True)
            if LOGGING_AVAILABLE:
                AgentLogger.info(self.agent_id, "About to enter try block for Cursor CLI call")
            sys.stdout.flush()
        except Exception as setup_error:
            print(f"  [{self.agent_id}] [ERROR] Failed during setup before Cursor CLI call: {setup_error}", flush=True)
            if LOGGING_AVAILABLE:
                AgentLogger.error(self.agent_id, f"Failed during setup before Cursor CLI call: {setup_error}")
            import traceback
            traceback.print_exc()
            sys.stdout.flush()
            return False
        
        if generate_start_time is None:
            print(f"  [{self.agent_id}] [ERROR] generate_start_time was not set", flush=True)
            if LOGGING_AVAILABLE:
                AgentLogger.error(self.agent_id, "generate_start_time was not set")
            sys.stdout.flush()
            return False
        
        try:
            print(f"  [{self.agent_id}] [GENERATE] Generating tasks from requirements using Cursor CLI...", flush=True)
            if LOGGING_AVAILABLE:
                AgentLogger.info(self.agent_id, "Generating tasks from requirements using Cursor CLI", extra={
                    'prompt_length': len(prompt),
                    'requirements_length': len(requirements_content)
                })
            import sys
            sys.stdout.flush()
            
            # #region debug log
            _debug_log("supervisor_agent.py:1055", "_generate_tasks_from_requirements: About to call Cursor CLI", {
                "prompt_length": len(prompt),
                "requirements_length": len(requirements_content)
            }, "H3")
            # #endregion
            
            # The CLI will write the file directly, so we run it and then read the file
            tasks_file = os.path.join(self.project_dir, "tasks.md")
            
            # Save original file if it exists
            original_content = None
            if os.path.exists(tasks_file):
                with open(tasks_file, 'r', encoding='utf-8') as f:
                    original_content = f.read()
            
            print(f"  [{self.agent_id}] [GENERATE] Calling Cursor CLI generate_with_retry...")
            if LOGGING_AVAILABLE:
                AgentLogger.info(self.agent_id, "Calling Cursor CLI generate_with_retry")
            
            # Run CLI - it will write the file directly
            try:
                generated_content = cursor_cli.generate_with_retry(
                    prompt=prompt,
                    context="",
                    language="markdown",
                    role="Supervisor",
                    working_dir=self.project_dir
                )
                print(f"  [{self.agent_id}] [GENERATE] Cursor CLI call completed, response length: {len(generated_content) if generated_content else 0}")
                if LOGGING_AVAILABLE:
                    AgentLogger.info(self.agent_id, "Cursor CLI call completed", extra={
                        'response_length': len(generated_content) if generated_content else 0
                    })
            except Exception as cli_error:
                print(f"  [{self.agent_id}] [ERROR] Cursor CLI call failed: {cli_error}")
                if LOGGING_AVAILABLE:
                    AgentLogger.error(self.agent_id, f"Cursor CLI call failed: {cli_error}")
                import traceback
                traceback.print_exc()
                return False
            
            # #region debug log
            _debug_log("supervisor_agent.py:1075", "_generate_tasks_from_requirements: Cursor CLI returned", {
                "generated_content_length": len(generated_content) if generated_content else 0
            }, "H3")
            # #endregion
            
            # Wait a moment for file to be written
            # time module is already imported at top of file
            time.sleep(2)
            
            # Check if CLI wrote the file (it should have)
            if os.path.exists(tasks_file):
                # Read the file that was written
                with open(tasks_file, 'r', encoding='utf-8') as f:
                    file_content = f.read()
                
                # Validate the file content
                task_count = file_content.count("###")
                if "###" in file_content and task_count >= 3:
                    print(f"  [{self.agent_id}] [SUCCESS] CLI wrote tasks.md with {task_count} tasks")
                    if LOGGING_AVAILABLE:
                        AgentLogger.info(self.agent_id, f"Successfully generated {task_count} tasks", extra={'task_count': task_count})
                    # Reload tasks into coordinator - this will happen below
                else:
                    # File was written but doesn't have proper format
                    print(f"  [{self.agent_id}] [WARNING] CLI wrote file but format may be incorrect")
                    print(f"  [{self.agent_id}] [WARNING] File preview: {file_content[:300]}")
                    # Try to extract tasks from CLI response as fallback
                    if generated_content and "###" in generated_content:
                        # Extract task blocks from response
                        import re
                        task_blocks = re.findall(r'### .+?(?=### |$)', generated_content, re.DOTALL)
                        if task_blocks:
                            with open(tasks_file, 'w', encoding='utf-8') as f:
                                f.write('\n'.join(task_blocks))
                            print(f"  [{self.agent_id}] [SUCCESS] Extracted and wrote tasks from CLI response")
                        else:
                            return False
                    else:
                        return False
            else:
                # CLI didn't write the file, try to extract from response
                if generated_content and "###" in generated_content:
                    # Extract task blocks from response
                    import re
                    task_blocks = re.findall(r'### .+?(?=### |$)', generated_content, re.DOTALL)
                    if task_blocks:
                        with open(tasks_file, 'w', encoding='utf-8') as f:
                            f.write('\n'.join(task_blocks))
                        print(f"  [{self.agent_id}] [SUCCESS] Extracted and wrote tasks from CLI response")
                    else:
                        print(f"  [{self.agent_id}] [ERROR] CLI didn't write file and response has no tasks")
                        return False
                else:
                    print(f"  [{self.agent_id}] [ERROR] CLI didn't write file and response is invalid")
                    return False
            
            generate_elapsed = time.time() - generate_start_time
            print(f"  [{self.agent_id}] [SUCCESS] Generated tasks.md from requirements")
            
            # #region debug log
            _debug_log("supervisor_agent.py:1328", "_generate_tasks_from_requirements: About to reload tasks", {
                "tasks_file": tasks_file,
                "file_exists": os.path.exists(tasks_file)
            }, "H3")
            # #endregion
            
            # Reload tasks into coordinator
            try:
                from ..utils.task_config_parser import TaskConfigParser
                parser = TaskConfigParser(self.project_dir)
                
                # #region debug log
                _debug_log("supervisor_agent.py:1335", "_generate_tasks_from_requirements: About to parse tasks", {}, "H3")
                # #endregion
                
                new_tasks = parser.parse_tasks()
                
                # #region debug log
                _debug_log("supervisor_agent.py:1340", "_generate_tasks_from_requirements: Parsed tasks", {
                    "new_tasks_count": len(new_tasks)
                }, "H3")
                # #endregion
                
                # Check if we're merging with existing tasks or loading fresh tasks
                existing_task_ids = set(self.coordinator.tasks.keys())
                new_task_ids = {task.id for task in new_tasks}
                is_merging = len(existing_task_ids.intersection(new_task_ids)) > 0
                
                # Only reset incorrectly completed tasks if we're NOT merging with existing tasks
                # When merging, we preserve existing task states (handled in merge logic below)
                reset_count = 0
                skipped_count = 0
                if not is_merging:
                    # Fresh load - check for incorrectly completed tasks
                    # CRITICAL: Never reset tasks that are already COMPLETED in the coordinator
                    # This ensures completed task count never goes backwards (per Manifesto requirement)
                    for task in new_tasks:
                        # If task is marked completed but shouldn't be (no artifacts, dependencies not met, etc.)
                        if task.status == TaskStatus.COMPLETED:
                            # CRITICAL CHECK: If task already exists in coordinator and is COMPLETED, never reset it
                            # This prevents completed task count from going backwards
                            if task.id in self.coordinator.tasks:
                                existing_task = self.coordinator.tasks[task.id]
                                if existing_task.status == TaskStatus.COMPLETED:
                                    # Task is already completed in coordinator - preserve it
                                    skipped_count += 1
                                    continue
                            
                            # Check if it should actually be completed
                            should_be_completed = False
                            should_reset = False
                            
                            # Check if task has artifacts that exist
                            has_artifacts = False
                            if task.artifacts and len(task.artifacts) > 0:
                                # Check if at least one artifact exists
                                for artifact in task.artifacts:
                                    artifact_path = os.path.join(self.project_dir, artifact) if self.project_dir and not os.path.isabs(artifact) else artifact
                                    if os.path.exists(artifact_path):
                                        has_artifacts = True
                                        break
                            
                            if has_artifacts and task.progress >= 100:
                                should_be_completed = True
                            
                            # Check if task was recently completed (within last 30 minutes)
                            recently_completed = False
                            if task.completed_at:
                                time_since_completion = datetime.now() - task.completed_at
                                if time_since_completion.total_seconds() < 1800:  # 30 minutes
                                    recently_completed = True
                            
                            # CRITICAL: Never reset tasks that have a completed_at timestamp
                            # This ensures completed task count never goes backwards (per Manifesto requirement)
                            # Once a task has been completed (has completed_at), it should stay completed
                            if task.completed_at:
                                # Task has been completed before - preserve it to prevent count from going backwards
                                should_reset = False
                                skipped_count += 1
                            # Only reset if ALL of these conditions are met:
                            # 1. Not should_be_completed (no artifacts or low progress)
                            # 2. NOT recently completed (to avoid resetting tasks that just finished)
                            # 3. Low progress (< 30%) AND no artifacts (very strict criteria)
                            # 4. Task is NOT already in coordinator as COMPLETED (checked above)
                            # 5. Task has NO completed_at timestamp (checked above)
                            # This ensures we only reset tasks that are clearly incorrectly completed
                            # and prevents completed task count from going backwards
                            elif not should_be_completed:
                                if recently_completed:
                                    # Task was recently completed - preserve it even if artifacts don't exist yet
                                    should_reset = False
                                    skipped_count += 1
                                elif task.progress < 30 and not has_artifacts:
                                    # Task has very low progress AND no artifacts - likely incorrectly completed
                                    # But only reset if it's a new task being loaded for the first time
                                    # and has never been completed (no completed_at)
                                    should_reset = True
                                else:
                                    # Task has some progress or artifacts - preserve it
                                    should_reset = False
                                    skipped_count += 1
                            else:
                                # Task should be completed - preserve it
                                should_reset = False
                                skipped_count += 1
                            
                            if should_reset:
                                # Reset to pending/ready based on dependencies
                                # Only reset tasks that are being loaded for the first time
                                if task.dependencies:
                                    task.status = TaskStatus.PENDING
                                else:
                                    task.status = TaskStatus.READY
                                task.progress = 0
                                task.assigned_agent = None
                                task.completed_at = None
                                reset_count += 1
                    
                    if reset_count > 0:
                        print(f"  [{self.agent_id}] [FIX] Reset {reset_count} incorrectly completed tasks to ready/pending (preserved {skipped_count} legitimate completions)")
                else:
                    print(f"  [{self.agent_id}] [INFO] Merging with existing tasks - preserving existing task states")
                
                for task in new_tasks:
                    if task.id not in self.coordinator.tasks:
                        # New task - add it (may have been reset above if it was incorrectly completed)
                        self.coordinator.add_task(task)
                    else:
                        # Existing task - preserve its status unless we're absolutely sure it's incorrect
                        existing_task = self.coordinator.tasks[task.id]
                        
                        # If existing task is completed, preserve it unless:
                        # 1. The new task was explicitly reset (status changed from COMPLETED to READY/PENDING with 0 progress)
                        # 2. AND the existing task has no artifacts AND very low progress
                        if existing_task.status == TaskStatus.COMPLETED:
                            # Check if this task was reset in the reset logic above
                            was_reset = (task.status != TaskStatus.COMPLETED and 
                                        task.status in [TaskStatus.READY, TaskStatus.PENDING] and 
                                        task.progress == 0)
                            
                            if was_reset:
                                # Task was reset - but only apply reset if existing task also has no artifacts
                                # This prevents resetting tasks that were legitimately completed by agents
                                has_existing_artifacts = False
                                if existing_task.artifacts and len(existing_task.artifacts) > 0:
                                    for artifact in existing_task.artifacts:
                                        artifact_path = os.path.join(self.project_dir, artifact) if self.project_dir and not os.path.isabs(artifact) else artifact
                                        if os.path.exists(artifact_path):
                                            has_existing_artifacts = True
                                            break
                                
                                # Only reset if existing task has no artifacts AND was completed recently (within last hour)
                                # This means it was likely auto-completed incorrectly
                                recently_completed = False
                                if existing_task.completed_at:
                                    time_since_completion = datetime.now() - existing_task.completed_at
                                    if time_since_completion.total_seconds() < 3600:  # 1 hour
                                        recently_completed = True
                                
                                if not has_existing_artifacts and recently_completed and existing_task.progress < 30:
                                    # Existing task was likely incorrectly completed - apply reset
                                    existing_task.status = task.status
                                    existing_task.progress = task.progress
                                    existing_task.assigned_agent = None
                                    existing_task.completed_at = None
                                    print(f"  [{self.agent_id}] [FIX] Reset existing task {task.id} from completed to {task.status.value} (no artifacts, recently completed, low progress)")
                                else:
                                    # Preserve existing completion - it's likely legitimate
                                    task.status = existing_task.status
                                    task.progress = existing_task.progress
                                    task.assigned_agent = existing_task.assigned_agent
                                    task.completed_at = existing_task.completed_at
                            else:
                                # Task wasn't reset - preserve the existing completion
                                task.status = existing_task.status
                                task.progress = existing_task.progress
                                task.assigned_agent = existing_task.assigned_agent
                                task.completed_at = existing_task.completed_at
                        else:
                            # Existing task is not completed - update it with new status if different
                            if task.status != existing_task.status:
                                existing_task.status = task.status
                                existing_task.progress = task.progress
                
                print(f"  [{self.agent_id}] [SUCCESS] Loaded {len(new_tasks)} tasks into coordinator")
                self.fixes_applied.append(f"Generated {len(new_tasks)} tasks from requirements.md")
                
                # Mark template tasks as completed so agents don't work on them
                template_keywords = ['example task', 'template', 'criterion 1', 'criterion 2', 'this is an example']
                template_tasks_marked = 0
                for task in self.coordinator.tasks.values():
                    task_text = f"{task.title} {task.description}".lower()
                    is_template = any(keyword in task_text for keyword in template_keywords)
                    if is_template and task.status != TaskStatus.COMPLETED:
                        # Mark template task as completed
                        from datetime import datetime
                        task.status = TaskStatus.COMPLETED
                        task.progress = 100
                        task.completed_at = datetime.now()
                        if task.assigned_agent:
                            if task.assigned_agent in self.coordinator.agent_workloads:
                                self.coordinator.agent_workloads[task.assigned_agent] = max(
                                    0, self.coordinator.agent_workloads[task.assigned_agent] - 1
                                )
                            task.assigned_agent = None
                        template_tasks_marked += 1
                        # Persist to tasks.md
                        self._persist_task_completion(task)
                
                if template_tasks_marked > 0:
                    print(f"  [{self.agent_id}] [FIX] Marked {template_tasks_marked} template tasks as completed")
                    self.fixes_applied.append(f"Marked {template_tasks_marked} template tasks as completed")
                
                if LOGGING_AVAILABLE:
                    AgentLogger.info(self.agent_id, "Successfully generated tasks from requirements", extra={
                        'tasks_generated': len(new_tasks),
                        'elapsed': generate_elapsed,
                        'requirements_size': len(requirements_content),
                        'template_tasks_marked': template_tasks_marked
                    })
                
                # #region debug log
                _debug_log("supervisor_agent.py:1358", "_generate_tasks_from_requirements: About to return True", {
                    "new_tasks_count": len(new_tasks),
                    "coordinator_tasks_count": len(self.coordinator.tasks)
                }, "H3")
                # #endregion
                
                return True
            except Exception as parse_error:
                print(f"  [{self.agent_id}] [ERROR] Failed to parse/reload tasks: {parse_error}")
                import traceback
                traceback.print_exc()
                
                # #region debug log
                _debug_log("supervisor_agent.py:1368", "_generate_tasks_from_requirements: Exception parsing tasks", {
                    "exception": str(parse_error),
                    "exception_type": type(parse_error).__name__,
                    "traceback": traceback.format_exc()
                }, "H3")
                # #endregion
                
                # Even if parsing fails, if file was written, consider it partial success
                if os.path.exists(tasks_file):
                    print(f"  [{self.agent_id}] [WARNING] Tasks file written but parsing failed - file exists")
                    return True  # Return True since file was created
                return False
            
        except Exception as e:
            print(f"  [{self.agent_id}] [ERROR] Failed to generate tasks: {e}", flush=True)
            if LOGGING_AVAILABLE:
                AgentLogger.error(self.agent_id, f"Failed to generate tasks: {e}", extra={
                    'exception_type': type(e).__name__,
                    'exception_message': str(e)
                })
            import traceback
            import sys
            error_trace = traceback.format_exc()
            print(f"  [{self.agent_id}] [ERROR] Traceback:\n{error_trace}", flush=True)
            sys.stdout.flush()
            return False
        
        # If we reach here without returning, something went wrong
        print(f"  [{self.agent_id}] [ERROR] Task generation completed but no return statement was reached", flush=True)
        if LOGGING_AVAILABLE:
            AgentLogger.error(self.agent_id, "Task generation completed but no return statement was reached")
        import sys
        sys.stdout.flush()
        return False
    
    def _analyze_requirements_for_team_size(self, requirements_content: str) -> Optional[Dict[str, int]]:
        """
        Analyze requirements to determine optimal team size.
        Returns a dict with recommended counts for each agent type.
        """
        if not requirements_content:
            return None
        
        # Count requirements/sections to estimate complexity
        requirement_count = requirements_content.count('### Requirement') + requirements_content.count('## Requirement')
        if requirement_count == 0:
            # Fallback: count numbered requirements or major sections
            requirement_count = requirements_content.count('Requirement ') + requirements_content.count('REQ-')
        
        # Count parallel development opportunities
        parallel_keywords = ['parallel', 'independent', 'simultaneous', 'concurrent', 'can be developed', 'can start']
        parallel_mentions = sum(1 for keyword in parallel_keywords if keyword.lower() in requirements_content.lower())
        
        # Estimate based on requirements count and parallel opportunities
        # Base: 1 developer per 2-3 requirements, minimum 2 developers
        base_developers = max(2, requirement_count // 2)
        
        # Increase if there are many parallel opportunities
        if parallel_mentions > 5:
            base_developers = max(base_developers, 3)
        if parallel_mentions > 10:
            base_developers = max(base_developers, 4)
        
        # Cap at reasonable maximum (6 developers)
        recommended_developers = min(base_developers, 6)
        
        # Testers: 1 tester per 4-5 requirements, minimum 1, maximum 3
        recommended_testers = max(1, min(3, requirement_count // 4))
        
        print(f"  [{self.agent_id}] [ANALYSIS] Requirements analysis:")
        print(f"    - Requirements found: {requirement_count}")
        print(f"    - Parallel opportunities: {parallel_mentions}")
        print(f"    - Recommended: {recommended_developers} developers, {recommended_testers} testers")
        
        return {
            'developers': recommended_developers,
            'testers': recommended_testers
        }
    
    def get_optimal_team_size(self) -> Optional[Dict[str, int]]:
        """Get the optimal team size recommendation from requirements analysis"""
        return self.optimal_team_size
    
    def get_supervisor_report(self) -> Dict:
        """Get a report of supervisor activities"""
        return {
            'last_audit': self.last_audit_time.isoformat(),
            'issues_found': len(self.issues_found),
            'fixes_applied': len(self.fixes_applied),
            'recent_issues': self.issues_found[-10:],
            'recent_fixes': self.fixes_applied[-10:],
            'optimal_team_size': self.optimal_team_size
        }

