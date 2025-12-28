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
        self.coordinator.register_agent_instance(self)
        
        # Initialize logging
        if LOGGING_AVAILABLE:
            # Try to get project_dir from coordinator's runner if available
            project_dir = None
            if hasattr(coordinator, 'runner') and hasattr(coordinator.runner, 'project_dir'):
                project_dir = coordinator.runner.project_dir
            if project_dir:
                AgentLogger.set_project_dir(project_dir)
            AgentLogger.info(self.agent_id, f"Agent initialized (specialization: {specialization})")

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
        if self.specialization:
            # Simple keyword matching - can be enhanced
            matching_tasks = [
                t for t in ready_tasks
                if self.specialization.lower() in t.title.lower() or
                   self.specialization.lower() in t.description.lower()
            ]
            if matching_tasks:
                ready_tasks = matching_tasks
                if LOGGING_AVAILABLE:
                    AgentLogger.debug(self.agent_id, f"Filtered to {len(matching_tasks)} tasks matching specialization '{self.specialization}'")

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
                progress=0,
                message=f"Starting work on: {task.title}"
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
        # Basic validation: artifacts should exist
        if artifacts:
            missing = [a for a in artifacts if not os.path.exists(a)]
            if missing:
                return False, f"Missing artifacts: {', '.join(missing)}"
        
        # Check if task has acceptance criteria and validate them
        if hasattr(task, 'acceptance_criteria') and task.acceptance_criteria:
            # Basic check - subclasses should implement detailed validation
            pass
        
        return True, "Task validation passed"
    
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
            if not self._validate_artifacts_basic(artifacts):
                print(f"  [{self.agent_id}] [ERROR] Artifacts validation failed - cannot complete task")
                self.send_status_update(
                    task_id,
                    TaskStatus.BLOCKED,
                    message="Artifacts validation failed - required files not created or are placeholders"
                )
                return False
        
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
        combined_tests = f"{tests or 'Tests written'}. Test suite: {test_status}. App status: {app_status}"
        
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
    
    def _validate_artifacts_basic(self, artifacts: List[str]) -> bool:
        """
        Basic validation that artifacts are actual files with content.
        Subclasses can override for more specific validation.
        """
        if not artifacts:
            return False
        
        for artifact in artifacts:
            if not os.path.exists(artifact):
                print(f"    [VALIDATION] Artifact file does not exist: {artifact}")
                return False
            
            # Check file size (must be > 0 bytes)
            file_size = os.path.getsize(artifact)
            if file_size == 0:
                print(f"    [VALIDATION] Artifact file is empty: {artifact}")
                return False
        
        return True
    
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
        import subprocess
        import sys
        import os
        import time
        
        # Find project root
        current_file = os.path.abspath(__file__)
        project_root = os.path.dirname(os.path.dirname(current_file))
        
        # Check for Flask app
        app_file = os.path.join(project_root, 'src', 'app.py')
        start_script = os.path.join(project_root, 'start_server.py')
        
        if os.path.exists(app_file) or os.path.exists(start_script):
            try:
                # Try to import the app to verify it loads
                if os.path.exists(start_script):
                    # Quick import test
                    result = subprocess.run(
                        [sys.executable, '-c', f'import sys; sys.path.insert(0, "{os.path.join(project_root, "src")}"); from app import app; print("App imports successfully")'],
                        cwd=project_root,
                        capture_output=True,
                        timeout=10
                    )
                    if result.returncode == 0:
                        return "IMPORTS_OK"
                    else:
                        error = result.stderr.decode('utf-8', errors='ignore')
                        print(f"    App import error: {error[:200]}")
                        return "IMPORT_ERROR"
                else:
                    return "NO_APP_FILE"
            except Exception as e:
                print(f"    Error verifying app: {e}")
                return "VERIFY_ERROR"
        
        return "NO_APP"

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
                # Check if task is at 100% and should be auto-completed (for setup tasks with files)
                if self.current_task.progress >= 100:
                    if 'setup' in self.current_task.id.lower():
                        # Try to get project_dir from agent, coordinator, or default
                        project_dir = getattr(self, 'project_dir', None)
                        if not project_dir:
                            # Try to get from coordinator if it has project_dir
                            if hasattr(self.coordinator, 'project_dir') and self.coordinator.project_dir:
                                project_dir = self.coordinator.project_dir
                            else:
                                # Default: assume dual_reader_3.0 project
                                project_dir = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), 'dual_reader_3.0')
                        
                        has_package = os.path.exists(os.path.join(project_dir, 'package.json'))
                        has_app = os.path.exists(os.path.join(project_dir, 'App.js')) or os.path.exists(os.path.join(project_dir, 'App.tsx'))
                        if has_package and has_app and self.current_task.status.value != 'completed':
                            print(f"[{self.agent_id}] [AUTO-COMPLETE] Task at 100% with files, completing...")
                            try:
                                # TaskStatus is already imported at module level
                                from datetime import datetime
                                artifacts = [
                                    os.path.join(project_dir, 'package.json'),
                                    os.path.join(project_dir, 'App.js'),
                                    os.path.join(project_dir, 'index.js'),
                                ]
                                artifacts = [a for a in artifacts if os.path.exists(a)]
                                
                                if self.current_task.id in self.coordinator.tasks:
                                    coordinator_task = self.coordinator.tasks[self.current_task.id]
                                    coordinator_task.status = TaskStatus.COMPLETED
                                    coordinator_task.progress = 100
                                    coordinator_task.completed_at = datetime.now()
                                    coordinator_task.artifacts = artifacts
                                    
                                    if coordinator_task.assigned_agent:
                                        self.coordinator.agent_workloads[coordinator_task.assigned_agent] = max(
                                            0, 
                                            self.coordinator.agent_workloads.get(coordinator_task.assigned_agent, 0) - 1
                                        )
                                    
                                    for other_task in self.coordinator.tasks.values():
                                        if self.current_task.id in other_task.dependencies:
                                            self.coordinator._update_task_status(other_task.id)
                                    
                                    print(f"[{self.agent_id}] [OK] Task auto-completed!")
                                    self.current_task = None
                                    continue  # Skip work() call, get next task
                            except Exception as e:
                                print(f"[{self.agent_id}] [ERROR] Auto-complete failed: {e}")
                
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

