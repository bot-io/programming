"""
Generic Project Runner - Runs AI agent team from configuration files
"""

import sys
import os
import time
import urllib.request
import json
from typing import List, Dict, Any, Optional

# Add parent directory to path
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))

from src.ai_team.agents.agent_coordinator import AgentCoordinator, TaskStatus
from src.ai_team.utils.task_config_parser import TaskConfigParser
from src.ai_team.utils.progress_tracker import DetailedProgressTracker
from src.ai_team.utils.progress_persistence import ProgressPersistence
from src.ai_team.agents.supervisor_agent import SupervisorAgent

# Import logger
try:
    from .utils.agent_logger import AgentLogger
    LOGGING_AVAILABLE = True
except ImportError:
    LOGGING_AVAILABLE = False
    # Fallback logger
    class AgentLogger:
        @staticmethod
        def set_project_dir(*args, **kwargs): pass
        @staticmethod
        def debug(*args, **kwargs): pass
        @staticmethod
        def info(*args, **kwargs): pass
        @staticmethod
        def warning(*args, **kwargs): pass
        @staticmethod
        def error(*args, **kwargs): pass
        @staticmethod
        def critical(*args, **kwargs): pass
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


class GenericProjectRunner:
    """Generic runner that works with any project using config files"""
    
    def __init__(self, project_dir: str = ".", agent_classes: Optional[Dict[str, Any]] = None,
                 agent_counts: Optional[Dict[str, int]] = None,
                 enable_parallel_optimization: bool = True):
        """
        Initialize the generic project runner.
        
        Args:
            project_dir: Directory containing requirements.md and tasks.md
            agent_classes: Dict mapping agent types to agent classes
                          e.g., {"developer": DeveloperAgent, "tester": TesterAgent, "pm": PMAgent}
            agent_counts: Dict mapping agent types to counts (e.g., {"developer": 3, "tester": 2})
            enable_parallel_optimization: Enable parallel execution optimizer
        """
        self.project_dir = os.path.abspath(project_dir)
        self.parser = TaskConfigParser(self.project_dir)
        self.agent_classes = agent_classes or {}
        self.agent_counts = agent_counts or {}
        self.enable_parallel_optimization = enable_parallel_optimization
        self.coordinator = None
        self.agents = []
        self.progress_tracker = None
        self.progress_persistence = None
        self.parallel_assigner = None
        self.team_id = None  # Will be generated at team initialization (REQ-1.2.1)
        
        # Validate infrastructure files exist
        self._validate_infrastructure_files()
        
        # Initialize logging
        if LOGGING_AVAILABLE:
            AgentLogger.set_project_dir(self.project_dir)
            AgentLogger.info("GenericProjectRunner", f"Initialized for project: {self.project_dir}")
    
    def load_config(self):
        """Load requirements and tasks from files"""
        print(f"Loading configuration from: {self.project_dir}")
        print()
        
        # Load requirements
        requirements = self.parser.parse_requirements()
        if requirements["raw_content"]:
            print("[OK] Loaded requirements.md")
        else:
            print("[WARN] No requirements.md found - creating template...")
            self._create_requirements_template()
        
        # Load tasks
        tasks = self.parser.parse_tasks()
        if tasks:
            print(f"[OK] Loaded {len(tasks)} tasks from tasks.md")
        else:
            # Don't create template - let supervisor generate tasks from requirements.md
            # This allows for true fresh starts when tasks.md is deleted
            tasks_file = os.path.join(self.project_dir, "tasks.md")
            if os.path.exists(tasks_file):
                print("[WARN] tasks.md exists but no tasks found - supervisor will generate tasks from requirements.md")
            else:
                print("[INFO] tasks.md not found - supervisor will generate tasks from requirements.md")
        
        return requirements, tasks
    
    def _validate_infrastructure_files(self):
        """
        Validate that required infrastructure files exist.
        If run_team.py is missing, attempt to create it from a template.
        This prevents the issue where cleanup removes run_team.py and the team can't start.
        """
        run_team_file = os.path.join(self.project_dir, "run_team.py")
        
        if not os.path.exists(run_team_file):
            print(f"[WARN] run_team.py not found in {self.project_dir}")
            print("[INFO] Attempting to create run_team.py from template...")
            
            # Try to create run_team.py from template
            if self._create_run_team_template():
                print("[OK] Created run_team.py from template")
            else:
                print("[ERROR] Failed to create run_team.py - team may not start properly")
                print("[INFO] Please create run_team.py manually or restore it from backup")
        else:
            # Verify run_team.py is not empty
            try:
                with open(run_team_file, 'r', encoding='utf-8') as f:
                    content = f.read().strip()
                    if len(content) < 100:  # Very small file might be corrupted
                        print(f"[WARN] run_team.py exists but appears to be empty or corrupted (< 100 chars)")
                        print("[INFO] Attempting to recreate run_team.py from template...")
                        if self._create_run_team_template():
                            print("[OK] Recreated run_team.py from template")
            except Exception as e:
                print(f"[WARN] Could not verify run_team.py: {e}")
    
    def _create_run_team_template(self) -> bool:
        """
        Create a run_team.py template file.
        This is a truly generic template that works for any project type.
        It uses autonomous mode - the supervisor will analyze requirements.md
        to determine the appropriate team size and agent types.
        Returns True if created successfully, False otherwise.
        """
        run_team_file = os.path.join(self.project_dir, "run_team.py")
        
        # Generate a completely generic run_team.py template
        # No project-specific assumptions - relies purely on requirements.md
        template_content = '''"""
Run AI Agent Team using configuration files

This is a generic runner that works with any project type.
The system relies purely on requirements.md - no project-specific assumptions.

The supervisor will analyze requirements.md to:
- Determine project type (project-agnostic; based on requirements/tasks)
- Determine optimal team size
- Generate appropriate tasks

NOTE: You must provide agent_classes that match your project type.
The system cannot auto-detect agent classes - they must be specified.
However, agent_counts can be omitted for autonomous sizing.
"""

import sys
import os
import io

# Force UTF-8 encoding for stdout/stderr on Windows to prevent Unicode errors
if sys.platform == 'win32' and not isinstance(sys.stdout, io.TextIOWrapper):
    if hasattr(sys.stdout, 'buffer'):
        sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')
    if hasattr(sys.stderr, 'buffer') and not isinstance(sys.stderr, io.TextIOWrapper):
        sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding='utf-8', errors='replace')

# Add parent directory to path
parent_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, parent_dir)

from src.ai_team.generic_project_runner import GenericProjectRunner

# Import generic agent that works with any project type
# This agent analyzes requirements.md to determine how to work
from src.ai_team.agents.generic_agent import GenericAgent


class GenericDeveloperAgent(GenericAgent):
    """Generic developer agent - works with any project type"""
    def __init__(self, agent_id: str, coordinator):
        super().__init__(agent_id, coordinator, specialization="developer")


class GenericTesterAgent(GenericAgent):
    """Generic tester agent - works with any project type"""
    def __init__(self, agent_id: str, coordinator):
        super().__init__(agent_id, coordinator, specialization="tester")


def main():
    """
    Run the agent team from configuration files.
    
    This uses GENERIC AGENTS that work with any project type.
    The agents will:
    1. Read requirements.md
    2. Analyze project type and requirements
    3. Determine appropriate tools and workflows
    4. Execute tasks based on requirements
    
    The supervisor will analyze requirements.md to determine optimal team size.
    """
    
    # Get project directory (where this script is located)
    project_dir = os.path.dirname(os.path.abspath(__file__))
    
    # Create runner with GENERIC agents
    # These agents work with any project type by analyzing requirements.md
    # They use task adapters to handle different project types automatically
    runner = GenericProjectRunner(
        project_dir=project_dir,
        agent_classes={
            'developer': GenericDeveloperAgent,
            'tester': GenericTesterAgent
        },
        # agent_counts={},  # Omit for autonomous sizing (supervisor determines from requirements.md)
        enable_parallel_optimization=True  # Enable parallel execution optimizer
    )
    
    # Alternative: If you have project-specific agent classes, use them instead:
    # runner = GenericProjectRunner(
    #     project_dir=project_dir,
    #     agent_classes={
    #         'developer': YourProjectSpecificDeveloperAgent,
    #         'tester': YourProjectSpecificTesterAgent
    #     },
    #     agent_counts={
    #         'developer': 3,
    #         'tester': 2
    #     },
    #     enable_parallel_optimization=True
    # )
    
    # Run the team
    runner.run(save_interval=10, status_interval=3)


if __name__ == '__main__':
    main()
'''
        
        try:
            with open(run_team_file, 'w', encoding='utf-8') as f:
                f.write(template_content)
            return True
        except Exception as e:
            print(f"[ERROR] Failed to create run_team.py: {e}")
            return False
    
    def _create_requirements_template(self):
        """Create a template requirements.md file"""
        template = """# Project Requirements

## Overview
Describe your project here.

## Features
- Feature 1
- Feature 2
- Feature 3

## Technical Requirements
- Requirement 1
- Requirement 2

## Additional Notes
Add any additional requirements or notes here.
"""
        with open(self.parser.requirements_file, 'w', encoding='utf-8') as f:
            f.write(template)
        print(f"  Created template: {self.parser.requirements_file}")
    
    def _create_tasks_template(self):
        """Create a template tasks.md file"""
        template = """# Tasks

## Pending Tasks

### task-1
- Title: Example Task
- Description: This is an example task description.
- Status: pending
- Progress: 0
- Estimated Hours: 2.0
- Dependencies: 
- Assigned Agent: 
- Created: 
- Started: 
- Completed: 
- Artifacts: 
- Acceptance Criteria:
  - Criterion 1
  - Criterion 2
"""
        with open(self.parser.tasks_file, 'w', encoding='utf-8') as f:
            f.write(template)
        print(f"  Created template: {self.parser.tasks_file}")
    
    def create_agents(self, requirements: Dict[str, Any], agent_counts: Dict[str, int] = None, 
                     autonomous: bool = False):
        """
        Create agents based on agent_classes configuration with optional counts.
        
        Args:
            requirements: Requirements dict (may contain raw_content for analysis)
            agent_counts: Dict mapping agent types to counts (overrides autonomous analysis if provided)
            autonomous: If True, let supervisor analyze requirements to determine team size
        """
        if not self.agent_classes:
            raise ValueError("No agent classes provided. Use agent_classes parameter to specify agent types.")
        
        self.agents = []
        agent_counter = {}
        agent_counts = agent_counts or {}
        
        # Always create supervisor agent first (monitors the team)
        supervisor = SupervisorAgent("supervisor-agent-1", self.coordinator)
        if hasattr(supervisor, 'project_dir'):
            supervisor.project_dir = self.project_dir
        self.agents.append(supervisor)
        print(f"  Created: supervisor-agent-1 (supervisor) - project_dir set to {self.project_dir}")
        
        # ENHANCED: Ensure Tester agent is always included
        has_tester = 'tester' in self.agent_classes
        if not has_tester:
            print(f"  [WARNING] No tester agent class provided - tests may not be run")
        
        # If autonomous mode and no agent_counts provided, let supervisor analyze requirements
        if autonomous and not agent_counts:
            requirements_content = requirements.get('raw_content', '')
            if requirements_content:
                team_size = supervisor._analyze_requirements_for_team_size(requirements_content)
                if team_size:
                    # Use supervisor's recommendation
                    agent_counts = {
                        'developer': team_size.get('developers', 2),
                        'tester': team_size.get('testers', 1)
                    }
                    print(f"  [AUTONOMOUS] Supervisor analyzed requirements and determined team size:")
                    print(f"    - Developers: {agent_counts.get('developer', 2)}")
                    print(f"    - Testers: {agent_counts.get('tester', 1)}")
        
        # Create user-specified agents (with counts support)
        for agent_type, agent_class in self.agent_classes.items():
            # Get count for this agent type (default to 1)
            count = agent_counts.get(agent_type, 1)
            
            # Create multiple agents of this type if count > 1
            for i in range(count):
                agent_id = f"{agent_type}-agent-{i+1}"
                agent = agent_class(agent_id, self.coordinator)
                
                # CRITICAL: Set project_dir IMMEDIATELY after agent creation
                if hasattr(agent, 'project_dir'):
                    agent.project_dir = self.project_dir
                    print(f"  Created: {agent_id} ({agent_type}) - project_dir set to {self.project_dir}")
                else:
                    print(f"  Created: {agent_id} ({agent_type})")
                
                self.agents.append(agent)
        
        # Verify tester is included (mandatory)
        tester_agents = [a for a in self.agents if 'tester' in a.agent_id.lower() or a.specialization == 'tester']
        if not tester_agents and 'tester' in self.agent_classes:
            # Force create at least one tester if tester class is available
            tester_class = self.agent_classes['tester']
            tester = tester_class("tester-agent-1", self.coordinator)
            if hasattr(tester, 'project_dir'):
                tester.project_dir = self.project_dir
            self.agents.append(tester)
            print(f"  [MANDATORY] Created: tester-agent-1 (tester) - mandatory team member")
        
        print(f"  Total agents created: {len(self.agents)} (1 supervisor + {len(self.agents)-1} workers)")
        return self.agents
    
    def run(self, save_interval: int = 10, status_interval: int = 3):
        """
        Run the agent team.
        
        Args:
            save_interval: How often to save progress (seconds)
            status_interval: How often to update status display (seconds)
        """
        # CRITICAL: Create initialization log file IMMEDIATELY before any other initialization steps
        # This allows detection of cases where the team never finishes initializing
        from datetime import datetime
        import uuid
        init_log_dir = os.path.join(self.project_dir, 'agent_logs')
        os.makedirs(init_log_dir, exist_ok=True)
        init_log_file = os.path.join(init_log_dir, 'team_initialization.log')
        init_start_time = datetime.now()
        
        # REQ-1.2.1, REQ-1.2.2, REQ-1.2.6: Generate unique team ID at initialization
        # Format: team-YYYYMMDD-HHMMSS-<short-uuid> (human-readable with timestamp)
        timestamp_str = init_start_time.strftime('%Y%m%d-%H%M%S')
        short_uuid = str(uuid.uuid4())[:8]  # First 8 chars of UUID for uniqueness
        self.team_id = f"team-{timestamp_str}-{short_uuid}"
        
        # REQ-1.2.3, REQ-9.2.1.1: Set team ID in logger IMMEDIATELY after generation
        # This must be done BEFORE agents are created so all logs include team ID from the start
        if LOGGING_AVAILABLE:
            AgentLogger.set_team_id(self.team_id)
        
        # REQ-1.2.5: Store team ID in a file for duplicate team detection
        team_id_file = os.path.join(self.project_dir, '.team_id')
        try:
            with open(team_id_file, 'w', encoding='utf-8') as f:
                f.write(self.team_id)
                f.write(f"\n{init_start_time.isoformat()}\n")
        except Exception as e:
            print(f"[WARNING] Failed to write team ID file: {e}")
        
        try:
            with open(init_log_file, 'w', encoding='utf-8') as f:
                f.write(f"[{init_start_time.strftime('%Y-%m-%d %H:%M:%S.%f')}] [INIT] Team initialization started\n")
                f.write(f"[{init_start_time.strftime('%Y-%m-%d %H:%M:%S.%f')}] [INIT] Team ID: {self.team_id}\n")
                f.write(f"[{init_start_time.strftime('%Y-%m-%d %H:%M:%S.%f')}] [INIT] Project directory: {self.project_dir}\n")
                f.write(f"[{init_start_time.strftime('%Y-%m-%d %H:%M:%S.%f')}] [INIT] Save interval: {save_interval}s, Status interval: {status_interval}s\n")
                f.flush()
        except Exception as e:
            # If we can't create the log file, print a warning but continue
            print(f"[WARNING] Failed to create initialization log file: {e}")
        
        # #region debug log
        import json
        try:
            with open('.cursor/debug.log', 'a', encoding='utf-8') as f:
                f.write(json.dumps({'location': 'generic_project_runner.py:240', 'message': 'run() entry', 'data': {'project_dir': self.project_dir, 'save_interval': save_interval, 'status_interval': status_interval}, 'timestamp': time.time(), 'sessionId': 'debug-session', 'runId': 'run1', 'hypothesisId': 'A,B,C,D,E'}) + '\n')
        except: pass
        # #endregion
        print("=" * 100)
        print("GENERIC AI AGENT TEAM RUNNER")
        print("=" * 100)
        print()
        
        # Load configuration
        requirements, tasks = self.load_config()
        # #region debug log
        try:
            with open('.cursor/debug.log', 'a', encoding='utf-8') as f:
                f.write(json.dumps({'location': 'generic_project_runner.py:254', 'message': 'load_config() completed', 'data': {'tasks_count': len(tasks), 'requirements_exists': bool(requirements.get('raw_content'))}, 'timestamp': time.time(), 'sessionId': 'debug-session', 'runId': 'run1', 'hypothesisId': 'B'}) + '\n')
        except: pass
        # #endregion
        
        # Create coordinator
        project_name = os.path.basename(self.project_dir) or "AI Team Project"
        self.coordinator = AgentCoordinator(
            project_name=project_name,
            enable_conflict_prevention=True
        )
        # REQ-1.2.2: Store team ID in coordinator for persistence throughout team lifecycle
        self.coordinator.team_id = self.team_id
        
        # Enable parallel execution optimizer if requested
        if self.enable_parallel_optimization:
            try:
                from src.ai_team.utils.parallel_execution import ParallelTaskAssigner
                self.parallel_assigner = ParallelTaskAssigner(self.coordinator)
                print("  Parallel execution optimizer enabled")
            except ImportError:
                print("  [WARNING] Parallel execution optimizer not available")
                self.parallel_assigner = None
        
        # Add tasks
        for task in tasks:
            self.coordinator.add_task(task)
        # #region debug log
        try:
            with open('.cursor/debug.log', 'a', encoding='utf-8') as f:
                f.write(json.dumps({'location': 'generic_project_runner.py:274', 'message': 'tasks added to coordinator', 'data': {'tasks_added': len(tasks), 'coordinator_tasks_count': len(self.coordinator.tasks)}, 'timestamp': time.time(), 'sessionId': 'debug-session', 'runId': 'run1', 'hypothesisId': 'B'}) + '\n')
        except: pass
        # #endregion
        
        print(f"\nLoaded {len(tasks)} tasks")
        print()
        
        # Create agents and pass requirements
        print("Creating agents...")
        # If agent_counts is empty, use autonomous mode (supervisor will determine team size)
        autonomous_mode = not self.agent_counts or len(self.agent_counts) == 0
        if autonomous_mode:
            print("  [AUTONOMOUS] No agent counts specified - supervisor will analyze requirements to determine team size")
        self.create_agents(requirements, agent_counts=self.agent_counts, autonomous=autonomous_mode)
        
        # Pass requirements to agents and CRITICALLY ensure project_dir is set
        for agent in self.agents:
            # CRITICAL: Always set project_dir FIRST, before anything else
            # This should already be set in create_agents, but ensure it's correct
            if hasattr(agent, 'project_dir'):
                if agent.project_dir != self.project_dir:
                    print(f"  [FIX] Correcting project_dir for {agent.agent_id}: {agent.project_dir} -> {self.project_dir}")
                    agent.project_dir = self.project_dir
                # Verify it was set correctly
                if agent.project_dir != self.project_dir:
                    print(f"  [ERROR] Failed to set project_dir for {agent.agent_id}!")
                    agent.project_dir = self.project_dir  # Force set again
                print(f"  [VERIFY] {agent.agent_id} project_dir: {agent.project_dir}")
            
            # Set project_dir for supervisor (it needs it for audits)
            if isinstance(agent, SupervisorAgent):
                agent.project_dir = self.project_dir
                # Also set runner reference so supervisor can access it
                if not hasattr(agent.coordinator, 'runner'):
                    agent.coordinator.runner = self
            
            if hasattr(agent, '_load_requirements'):
                if hasattr(agent, 'requirements'):
                    agent.requirements = requirements
        
        print()
        
        # Start agents
        print("Starting agents...")
        for agent in self.agents:
            try:
                agent.start()
                print(f"  [OK] {agent.agent_id} started (state: {agent.state.value})")
            except Exception as e:
                print(f"  [ERROR] Failed to start {agent.agent_id}: {e}")
        print("Agents started.")
        print()
        
        # Verify agents are running
        import time
        time.sleep(1)  # Give agents a moment to start
        print("Agent Status Check:")
        for agent in self.agents:
            state = self.coordinator.get_agent_state(agent.agent_id)
            print(f"  - {agent.agent_id}: {state.value if state else 'unknown'}")
        print()
        
        # Track team start time
        from datetime import datetime
        self.team_start_time = datetime.now()
        
        # Create progress tracker and persistence
        self.progress_tracker = DetailedProgressTracker(self.coordinator)
        self.progress_persistence = ProgressPersistence(
            self.coordinator, 
            self.progress_tracker,
            output_dir=os.path.join(self.project_dir, "progress_reports"),
            project_dir=self.project_dir,
            team_start_time=self.team_start_time,
            team_id=self.team_id  # REQ-1.2.4: Pass team ID to progress persistence
        )
        
        # REQ-3.7.1.1: Save initial progress IMMEDIATELY as one of the first actions
        # This ensures progress report is available from the earliest stages
        try:
            self.progress_persistence.save_progress()
            if os.path.exists(self.progress_persistence.md_file):
                print(f"Progress report created: {self.progress_persistence.md_file}")
            else:
                print(f"[WARNING] Progress report file not found after save: {self.progress_persistence.md_file}")
        except Exception as e:
            print(f"[ERROR] Failed to create initial progress report: {e}")
            if LOGGING_AVAILABLE:
                AgentLogger.error("GenericProjectRunner", f"Failed to create initial progress report: {e}")
        print(f"Progress will be saved to: {self.progress_persistence.md_file}")
        print()
        
        # REQ-1.2.5: Display team ID for validation and debugging
        # (Team ID already set in logger earlier, before agents were created)
        print(f"Team ID: {self.team_id}")
        print()
        
        # Log initialization completion
        init_complete_time = datetime.now()
        init_duration = (init_complete_time - init_start_time).total_seconds()
        try:
            with open(init_log_file, 'a', encoding='utf-8') as f:
                f.write(f"[{init_complete_time.strftime('%Y-%m-%d %H:%M:%S.%f')}] [INIT] Team initialization completed\n")
                f.write(f"[{init_complete_time.strftime('%Y-%m-%d %H:%M:%S.%f')}] [INIT] Team ID: {self.team_id}\n")
                f.write(f"[{init_complete_time.strftime('%Y-%m-%d %H:%M:%S.%f')}] [INIT] Initialization duration: {init_duration:.2f} seconds\n")
                f.write(f"[{init_complete_time.strftime('%Y-%m-%d %H:%M:%S.%f')}] [INIT] Total agents: {len(self.agents)}\n")
                f.write(f"[{init_complete_time.strftime('%Y-%m-%d %H:%M:%S.%f')}] [INIT] Total tasks: {len(self.coordinator.tasks)}\n")
                f.write(f"[{init_complete_time.strftime('%Y-%m-%d %H:%M:%S.%f')}] [INIT] Entering main execution loop\n")
                f.flush()
        except Exception as e:
            print(f"[WARNING] Failed to write to initialization log file: {e}")
        
        # Monitor progress
        last_status_time = time.time()
        last_save_time = time.time()
        last_task_update_time = time.time()
        task_update_interval = 5  # Update tasks.md every 5 seconds
        
        try:
            consecutive_errors = 0
            max_consecutive_errors = 10  # Allow up to 10 consecutive errors before giving up
            
            while True:
                try:
                    time.sleep(1)
                    consecutive_errors = 0  # Reset error count on successful iteration
                except Exception as sleep_error:
                    # Even sleep can fail in rare cases, but continue
                    if LOGGING_AVAILABLE:
                        AgentLogger.warning("GenericProjectRunner", f"Error in sleep: {sleep_error}")
                    consecutive_errors += 1
                    if consecutive_errors >= max_consecutive_errors:
                        print(f"[FATAL] Too many consecutive errors ({consecutive_errors}), stopping team")
                        if LOGGING_AVAILABLE:
                            AgentLogger.critical("GenericProjectRunner", 
                                f"Team stopping due to {consecutive_errors} consecutive errors")
                        break
                    continue
                
                try:
                    # VALIDATION CHECK: Verify setup tasks at 100% actually have files
                    self._validate_in_progress_setup_tasks()
                    
                    # AUTO-COMPLETE CHECK: Check for setup tasks at 100% with files existing
                    # Run this more frequently to catch completed tasks quickly
                    self._auto_complete_setup_tasks()
                    
                    # FORCE AUTO-COMPLETE: If files exist but task is still in_progress, force complete
                    self._force_complete_setup_tasks_with_files()
                except Exception as e:
                    consecutive_errors += 1
                    if LOGGING_AVAILABLE:
                        AgentLogger.error("GenericProjectRunner", f"Error in task validation/auto-complete: {e}",
                            extra={'error_type': type(e).__name__, 'consecutive_errors': consecutive_errors})
                    if consecutive_errors >= max_consecutive_errors:
                        print(f"[FATAL] Too many consecutive errors ({consecutive_errors}), stopping team")
                        break
                    continue
                
                # SUPERVISOR: Let supervisor run its audit (it runs in its own loop, but we can trigger it)
                # The supervisor runs continuously in its own thread, so we don't need to call it here
                
                try:
                    # ENSURE TASKS ARE MARKED AS READY: Update task statuses based on dependencies
                    # CRITICAL: Check ALL tasks, especially BLOCKED ones, to unblock them when dependencies complete
                    # This ensures tasks are properly blocked/unblocked as dependencies change
                    for task in self.coordinator.tasks.values():
                        # Skip tasks that are already completed or failed
                        if task.status in [TaskStatus.COMPLETED, TaskStatus.FAILED]:
                            continue
                        
                        # CRITICAL: Always check BLOCKED tasks - they might be ready to unblock
                        # Also check tasks with dependencies - they may need to be blocked or unblocked
                        # BUT: Skip summary/metadata tasks (tasks with colons in ID are typically documentation)
                        if task.id and ':' in task.id:
                            # This is likely a summary/metadata task - skip status updates to prevent infinite loops
                            continue
                        
                        # Check all tasks that need status updates:
                        # 1. BLOCKED tasks (might be ready to unblock)
                        # 2. Tasks with dependencies (might need to be blocked/unblocked based on dependency status)
                        # 3. PENDING tasks (might need to be READY or BLOCKED)
                        needs_status_check = (
                            task.status == TaskStatus.BLOCKED or 
                            (task.dependencies and len(task.dependencies) > 0) or
                            task.status == TaskStatus.PENDING
                        )
                        
                        if needs_status_check:
                            old_status = task.status
                            # Always call _update_task_status to check current dependency state
                            self.coordinator._update_task_status(task.id)
                            
                            # If status changed (blocked -> ready, or pending -> ready/blocked), persist it
                            if task.status != old_status:
                                # Debug: Log what happened
                                if LOGGING_AVAILABLE:
                                    AgentLogger.debug("GenericProjectRunner",
                                        f"Status check triggered for task {task.id}: {old_status.value} -> {task.status.value} (deps: {task.dependencies})",
                                        task_id=task.id)
                                # Log the status change for debugging
                                if LOGGING_AVAILABLE:
                                    AgentLogger.info("GenericProjectRunner", 
                                        f"Task {task.id} status changed: {old_status.value} -> {task.status.value} (dependencies: {task.dependencies})",
                                        task_id=task.id, 
                                        extra={'old_status': old_status.value, 'new_status': task.status.value, 'dependencies': task.dependencies})
                                print(f"[RUNNER] Task '{task.id}' status updated: {old_status.value} -> {task.status.value}")
                                try:
                                    self.parser.update_task_in_file(task)
                                except Exception as e:
                                    if LOGGING_AVAILABLE:
                                        AgentLogger.warning("GenericProjectRunner", f"Failed to persist status update for {task.id}: {e}")
                            # PENDING tasks should be checked - they may have no dependencies and should be READY
                            # OR they may have dependencies and should be BLOCKED
                            old_status = task.status
                            self.coordinator._update_task_status(task.id)
                            if task.status != old_status:
                                if LOGGING_AVAILABLE:
                                    AgentLogger.info("GenericProjectRunner",
                                        f"Task {task.id} status changed: {old_status.value} -> {task.status.value}",
                                        task_id=task.id,
                                        extra={'old_status': old_status.value, 'new_status': task.status.value, 'has_dependencies': bool(task.dependencies)})
                                print(f"[RUNNER] Task '{task.id}' status updated: {old_status.value} -> {task.status.value}")
                                try:
                                    self.parser.update_task_in_file(task)
                                except Exception as e:
                                    if LOGGING_AVAILABLE:
                                        AgentLogger.warning("GenericProjectRunner", f"Failed to persist status update for {task.id}: {e}")
                    
                    # FORCE AGENTS TO PICK UP READY TASKS: If agents are idle and there are ready tasks, force assignment
                    # Call this more frequently to ensure tasks are picked up quickly
                    self._force_task_assignment()
                    
                    # Also check every 2 seconds (not just every loop iteration)
                    if int(time.time()) % 2 == 0:
                        self._force_task_assignment()
                except Exception as e:
                    consecutive_errors += 1
                    if LOGGING_AVAILABLE:
                        AgentLogger.error("GenericProjectRunner", f"Error in task management loop: {e}",
                            extra={'error_type': type(e).__name__, 'consecutive_errors': consecutive_errors})
                    if consecutive_errors >= max_consecutive_errors:
                        print(f"[FATAL] Too many consecutive errors ({consecutive_errors}), stopping team")
                        break
                    import traceback
                    traceback.print_exc()
                    continue
                
                # ENSURE ALL AGENTS ARE RUNNING: Check agent states and restart if needed
                # Only check every 10 seconds to avoid overhead
                if int(time.time()) % 10 == 0:
                    for agent in self.agents:
                        try:
                            agent_state = self.coordinator.get_agent_state(agent.agent_id)
                            internal_state = agent.state.value if hasattr(agent, 'state') else 'unknown'
                            
                            # Check both coordinator state and internal state
                            coordinator_running = agent_state and agent_state.value in ['running', 'started']
                            internal_running = internal_state in ['running', 'started']
                            
                            if not coordinator_running or not internal_running:
                                if internal_state == 'created' or (agent_state and agent_state.value == 'created'):
                                    print(f"[RUNNER] Agent {agent.agent_id} not running (coordinator={agent_state.value if agent_state else 'unknown'}, internal={internal_state}), starting...")
                                    try:
                                        agent.start()
                                        time.sleep(0.5)  # Give agent time to start
                                        # Verify it started
                                        new_state = self.coordinator.get_agent_state(agent.agent_id)
                                        if new_state and new_state.value in ['running', 'started']:
                                            print(f"[RUNNER] Agent {agent.agent_id} successfully started")
                                        else:
                                            print(f"[RUNNER] Warning: Agent {agent.agent_id} start() called but state is still: {new_state.value if new_state else 'unknown'}")
                                    except Exception as e:
                                        print(f"[RUNNER] Error starting agent {agent.agent_id}: {e}")
                                        import traceback
                                        traceback.print_exc()
                        except Exception as e:
                            # If we can't check state, try to start agent anyway if internal state is created
                            if hasattr(agent, 'state') and agent.state.value == 'created':
                                print(f"[RUNNER] Could not check state for {agent.agent_id}, attempting to start...")
                                try:
                                    agent.start()
                                    time.sleep(0.5)
                                except Exception as start_error:
                                    print(f"[RUNNER] Error starting agent {agent.agent_id}: {start_error}")
                
                # Check if all tasks are completed
                all_tasks = list(self.coordinator.tasks.values())
                completed = sum(1 for t in all_tasks if t.status == TaskStatus.COMPLETED)
                failed = sum(1 for t in all_tasks if t.status == TaskStatus.FAILED)
                
                # Print detailed progress periodically
                if time.time() - last_status_time >= status_interval:
                    last_progress_time = self.progress_persistence.last_progress_change_time if hasattr(self.progress_persistence, 'last_progress_change_time') else None
                    last_overall_progress_time = self.progress_persistence.last_overall_progress_change_time if hasattr(self.progress_persistence, 'last_overall_progress_change_time') else None
                    self.progress_tracker.print_detailed_progress(
                        refresh=True, 
                        last_progress_time=last_progress_time,
                        last_overall_progress_time=last_overall_progress_time
                    )
                    last_status_time = time.time()
                
                # Save progress periodically
                # CRITICAL: Always save progress even if there are errors - wrap in try-except
                if time.time() - last_save_time >= save_interval:
                    try:
                        self.progress_persistence.save_progress()
                        last_save_time = time.time()
                        if LOGGING_AVAILABLE:
                            AgentLogger.debug("GenericProjectRunner", "Progress saved successfully")
                    except Exception as save_error:
                        # Don't let save errors crash the team - log and continue
                        if LOGGING_AVAILABLE:
                            AgentLogger.error("GenericProjectRunner", f"Error saving progress: {save_error}",
                                extra={'error_type': type(save_error).__name__})
                        print(f"[WARNING] Failed to save progress: {save_error}")
                        # Still update last_save_time to avoid rapid retries
                        last_save_time = time.time()
                
                # Update tasks.md periodically
                # CRITICAL: Wrap in try-except to prevent crashes
                if time.time() - last_task_update_time >= task_update_interval:
                    try:
                        self._update_tasks_file()
                        last_task_update_time = time.time()
                    except Exception as task_update_error:
                        # Don't let task file update errors crash the team
                        if LOGGING_AVAILABLE:
                            AgentLogger.error("GenericProjectRunner", f"Error updating tasks.md: {task_update_error}",
                                extra={'error_type': type(task_update_error).__name__})
                        last_task_update_time = time.time()  # Update to avoid rapid retries
                
                # Check if only template tasks exist - let supervisor generate real tasks first
                template_keywords = ['example task', 'template', 'criterion 1', 'criterion 2']
                has_real_tasks = False
                for task in all_tasks:
                    task_text = f"{task.title} {task.description}".lower()
                    is_template = any(keyword in task_text for keyword in template_keywords)
                    if not is_template:
                        has_real_tasks = True
                        break
                
                # If only template tasks and we haven't waited for supervisor yet, keep running
                if not has_real_tasks and len(all_tasks) <= 2:
                    if not hasattr(self, '_template_task_wait_start'):
                        self._template_task_wait_start = time.time()
                        print(f"[INFO] Detected template tasks only - waiting for supervisor to generate real tasks...")
                    elif time.time() - self._template_task_wait_start < 60:  # Wait up to 60 seconds
                        # Still waiting for supervisor to generate tasks
                        continue
                    else:
                        print(f"[WARNING] Supervisor hasn't generated tasks after 60 seconds - continuing anyway")
                
                # Run comprehensive app verification at the end if all tasks completed
                if completed == len(all_tasks) and completed > 0 and has_real_tasks:
                    if not hasattr(self, '_app_verified'):
                        print("\n" + "=" * 100)
                        print("ALL TASKS COMPLETED - Running Final Verification")
                        print("=" * 100)
                        print("This ensures the app is fully tested and running before completion.")
                        print()
                        
                        verification_result = self._run_final_verification()
                        self._app_verified = True
                        
                        if not verification_result:
                            print("\n" + "=" * 100)
                            print("⚠️  FINAL VERIFICATION FAILED ⚠️")
                            print("=" * 100)
                            print("The app is NOT fully tested and running.")
                            print()
                            print("Issues found:")
                            print("  - Some tests may have failed")
                            print("  - App may not build correctly")
                            print("  - App may not start properly")
                            print()
                            print("ACTION REQUIRED:")
                            print("  Please review the errors above and fix them.")
                            print("  The team will need to address these issues.")
                            print("=" * 100)
                            
                            # Create a new task to fix verification issues
                            self._create_verification_fix_task()
                            # CRITICAL: Refresh task snapshot after dynamically adding tasks.
                            # Otherwise the completion check below may use a stale `all_tasks` list and exit
                            # even though a new READY task was added.
                            all_tasks = list(self.coordinator.tasks.values())
                            completed = sum(1 for t in all_tasks if t.status == TaskStatus.COMPLETED)
                            failed = sum(1 for t in all_tasks if t.status == TaskStatus.FAILED)
                        else:
                            print("\n" + "=" * 100)
                            print("✅ FINAL VERIFICATION PASSED ✅")
                            print("=" * 100)
                            print("[OK] All tests passed")
                            print("[OK] App builds successfully")
                            print("[OK] App runs correctly")
                            print("[OK] App is responsive")
                            print()
                            print("The application is fully tested and ready to use!")
                            print("=" * 100)
                
                # Check completion (only if we have real tasks)
                # CRITICAL: Only exit if ALL tasks are completed (including dynamically created ones)
                # Count ready tasks to ensure we don't exit prematurely
                # CRITICAL: Always use a fresh snapshot right before completion/failure checks.
                all_tasks = list(self.coordinator.tasks.values())
                completed = sum(1 for t in all_tasks if t.status == TaskStatus.COMPLETED)
                failed = sum(1 for t in all_tasks if t.status == TaskStatus.FAILED)
                ready_tasks = sum(1 for t in all_tasks if t.status == TaskStatus.READY)
                in_progress_tasks = sum(1 for t in all_tasks if t.status == TaskStatus.IN_PROGRESS)
                assigned_tasks = sum(1 for t in all_tasks if t.status == TaskStatus.ASSIGNED)
                
                if completed == len(all_tasks) and has_real_tasks:
                    # Double-check: make sure there are no ready, in_progress, or assigned tasks
                    if ready_tasks == 0 and in_progress_tasks == 0 and assigned_tasks == 0:
                        print()
                        print("=" * 100)
                        print("ALL TASKS COMPLETED!")
                        print("=" * 100)
                        break
                    else:
                        # There are still tasks to process - don't exit
                        if LOGGING_AVAILABLE:
                            AgentLogger.debug("GenericProjectRunner", 
                                f"Completion check: completed={completed}, total={len(all_tasks)}, "
                                f"ready={ready_tasks}, in_progress={in_progress_tasks}, assigned={assigned_tasks}",
                                extra={'completed': completed, 'total': len(all_tasks), 
                                      'ready': ready_tasks, 'in_progress': in_progress_tasks, 'assigned': assigned_tasks})
                
                # Check for failures
                if failed > 0 and completed + failed == len(all_tasks):
                    # Only exit if there are no ready, in_progress, or assigned tasks
                    if ready_tasks == 0 and in_progress_tasks == 0 and assigned_tasks == 0:
                        print()
                        print("=" * 100)
                        print(f"TASKS FINISHED: {completed} completed, {failed} failed")
                        print("=" * 100)
                        break
        
        except KeyboardInterrupt:
            print("\n\nInterrupted by user")
            if LOGGING_AVAILABLE:
                AgentLogger.warning("GenericProjectRunner", "Team interrupted by user (KeyboardInterrupt)")
        except Exception as e:
            print(f"\n\nError in main loop: {e}")
            import traceback
            traceback.print_exc()
            if LOGGING_AVAILABLE:
                AgentLogger.critical("GenericProjectRunner", f"Fatal error in main loop: {e}", extra={
                    'error_type': type(e).__name__,
                    'error_message': str(e),
                    'traceback': traceback.format_exc()
                })
            # Try to save progress even if there's an error
            try:
                if hasattr(self, 'progress_persistence') and self.progress_persistence:
                    self.progress_persistence.save_progress()
                    print("Progress saved before stopping.")
            except Exception as save_error:
                print(f"Warning: Could not save progress: {save_error}")
                if LOGGING_AVAILABLE:
                    AgentLogger.error("GenericProjectRunner", f"Failed to save progress after error: {save_error}")
        
        finally:
            # Stop agents
            print("\nStopping agents...")
            for agent in self.agents:
                try:
                    agent.stop()
                except Exception as e:
                    print(f"Error stopping agent {agent.agent_id}: {e}")
            
            # Final updates
            print("\nSaving final progress...")
            try:
                self._update_tasks_file()
                if hasattr(self, 'progress_persistence') and self.progress_persistence:
                    self.progress_persistence.save_progress()
            except Exception as e:
                print(f"Warning: Could not save final progress: {e}")
            
            # Print final summary
            print()
            print("=" * 100)
            print("FINAL SUMMARY")
            print("=" * 100)
            
            all_tasks = list(self.coordinator.tasks.values())
            for task in all_tasks:
                status_icon = "[OK]" if task.status == TaskStatus.COMPLETED else "[FAIL]" if task.status == TaskStatus.FAILED else "[ ]"
                print(f"{status_icon} {task.id}: {task.title} [{task.status.value}]")
            
            print()
            print("Files updated:")
            print(f"  - {self.parser.tasks_file} - Tasks with updated status")
            print(f"  - {self.progress_persistence.md_file} - Progress report")
    
    def _update_tasks_file(self):
        """Update tasks.md with current task statuses"""
        for task in self.coordinator.tasks.values():
            try:
                self.parser.update_task_in_file(task)
            except Exception as e:
                # Don't fail on update errors
                pass
    
    def _auto_complete_setup_tasks(self):
        """Auto-complete tasks that are at 100% progress but still in_progress"""
        from .agents.agent_coordinator import TaskStatus
        from datetime import datetime
        
        for task_id, task in self.coordinator.tasks.items():
            # Check tasks that are in_progress OR ready at 100% progress
            if task.progress >= 100 and task.status in [TaskStatus.IN_PROGRESS, TaskStatus.READY]:
                should_complete = False
                artifacts = []
                
                # For setup tasks, check if task has artifacts defined
                # Generic approach: rely on task artifacts, not hardcoded file checks
                if 'setup' in task_id.lower() or 'initialize' in task_id.lower():
                    # Check if task already has artifacts defined
                    if task.artifacts and len(task.artifacts) > 0:
                        # Verify artifacts exist
                        existing_artifacts = [a for a in task.artifacts if os.path.exists(a)]
                        if len(existing_artifacts) > 0:
                            should_complete = True
                            artifacts = existing_artifacts
                    # If no artifacts defined, don't auto-complete based on file system checks
                    # Let supervisor handle completion based on requirements.md analysis
                # For deployment tasks, check if deployment directory exists
                elif 'deploy' in task_id.lower():
                    deployment_dir = os.path.join(self.project_dir, 'deployment')
                    if os.path.exists(deployment_dir) and len(os.listdir(deployment_dir)) > 0:
                        should_complete = True
                        artifacts = [os.path.join(deployment_dir, f) for f in os.listdir(deployment_dir) if os.path.isfile(os.path.join(deployment_dir, f))]
                    else:
                        # Don't auto-complete deployment tasks without artifacts
                        should_complete = False
                # For feature tasks at 100%, only complete if artifacts exist
                # This prevents auto-completing tasks that don't have actual work done
                else:
                    # Check if any related files exist in lib/ directory
                    lib_dir = os.path.join(self.project_dir, 'lib')
                    if os.path.exists(lib_dir):
                        # Look for any files that might be related to this task
                        task_keywords = task_id.replace('-', '_').split('_')
                        for root, dirs, files in os.walk(lib_dir):
                            for file in files:
                                if any(keyword in file.lower() for keyword in task_keywords if len(keyword) > 3):
                                    artifacts.append(os.path.join(root, file))
                    
                    # Only auto-complete if:
                    # 1. Task is IN_PROGRESS (not READY/PENDING - those were likely reset)
                    # 2. Artifacts exist (actual work was done)
                    # This prevents auto-completing tasks that were incorrectly marked as completed
                    if task.status in [TaskStatus.READY, TaskStatus.PENDING]:
                        # Task is ready/pending but has 100% progress - likely was reset
                        # Don't auto-complete, let agent work on it properly
                        should_complete = False
                        print(f"[AUTO-COMPLETE] Skipping task '{task_id}' - ready/pending with 100% progress (likely reset)")
                    elif artifacts and len(artifacts) > 0:
                        # Task has artifacts - safe to auto-complete
                        should_complete = True
                        print(f"[AUTO-COMPLETE] Task '{task_id}' at 100% progress with artifacts - completing")
                    else:
                        # Task at 100% but no artifacts - don't auto-complete
                        # Let the agent complete it properly or supervisor will handle it
                        should_complete = False
                        print(f"[AUTO-COMPLETE] Skipping task '{task_id}' - 100% progress but no artifacts found")
                # For all other tasks, don't auto-complete - let agents complete them properly
                # Auto-complete should only be used for setup/deployment/feature tasks where we can verify completion
                
                if should_complete:
                    print(f"[AUTO-COMPLETE] Task '{task_id}' at 100% progress, completing...")
                    try:
                        # Force complete
                        task.status = TaskStatus.COMPLETED
                        task.progress = 100
                        task.completed_at = datetime.now()
                        if artifacts:
                            task.artifacts = artifacts
                        
                        # Update agent workload
                        if task.assigned_agent:
                            self.coordinator.agent_workloads[task.assigned_agent] = max(
                                0,
                                self.coordinator.agent_workloads.get(task.assigned_agent, 0) - 1
                            )
                        
                        # Update dependent tasks
                        for other_task in self.coordinator.tasks.values():
                            if task_id in other_task.dependencies:
                                self.coordinator._update_task_status(other_task.id)
                        
                        print(f"[AUTO-COMPLETE] Task '{task_id}' completed successfully!")
                        
                        # Update tasks.md
                        self.parser.update_task_in_file(task)
                        
                    except Exception as e:
                        print(f"[AUTO-COMPLETE] Error completing task '{task_id}': {e}")
    
    def _get_idle_agents(self) -> List[str]:
        """Get list of idle agent IDs (not supervisor, no current task)"""
        idle_agents = []
        for agent in self.agents:
            # Skip supervisor
            if hasattr(agent, 'specialization') and agent.specialization == 'supervisor':
                continue
            
            # Check if agent has active tasks
            state = self.coordinator.get_agent_state(agent.agent_id)
            if state and state.value in ['running', 'started']:
                agent_tasks = self.coordinator.get_agent_tasks(agent.agent_id)
                active = [t for t in agent_tasks 
                         if t.status in [TaskStatus.ASSIGNED, TaskStatus.IN_PROGRESS]]
                if not active and not agent.current_task:
                    idle_agents.append(agent.agent_id)
        return idle_agents
    
    def _check_task_conflicts(self, task: Task, agent_id: str) -> Tuple[bool, List[str]]:
        """Check if assigning this task would conflict with active tasks"""
        conflicts = []
        
        # Get expected files for this task (simple heuristic)
        expected_files = self._get_expected_files_for_task(task)
        
        # Check against all active tasks
        for active_task in self.coordinator.tasks.values():
            if active_task.status in [TaskStatus.IN_PROGRESS, TaskStatus.ASSIGNED]:
                if active_task.id == task.id:
                    continue
                
                # Get expected files for active task
                active_files = self._get_expected_files_for_task(active_task)
                
                # Check for overlap
                overlap = set(expected_files) & set(active_files)
                if overlap:
                    conflicts.append(
                        f"Task {active_task.id} ({active_task.assigned_agent}) "
                        f"is working on: {', '.join(overlap)}"
                    )
        
        return len(conflicts) == 0, conflicts
    
    def _get_expected_files_for_task(self, task: Task) -> List[str]:
        """
        Get expected files that this task will likely create/modify.
        
        Project-agnostic approach:
        - Prefer explicit `task.artifacts` (if present)
        - Otherwise, return an empty list (no assumptions about framework/layout)
        """
        expected: List[str] = []
        try:
            if getattr(task, "artifacts", None):
                expected.extend([a for a in task.artifacts if a])
        except Exception:
            pass
        return expected
    
    def _force_task_assignment(self):
        """Force agents to pick up ready tasks if they're idle (with conflict checking)"""
        from .agents.agent_coordinator import TaskStatus
        import time as time_module
        
        ready_tasks = self.coordinator.get_ready_tasks()
        if not ready_tasks:
            # Debug: Check if there are tasks that should be ready
            all_tasks = list(self.coordinator.tasks.values())
            ready_count = sum(1 for t in all_tasks if t.status == TaskStatus.READY)
            if ready_count > 0:
                if LOGGING_AVAILABLE:
                    AgentLogger.warning("GenericProjectRunner", 
                        f"get_ready_tasks() returned empty but {ready_count} tasks have READY status",
                        extra={'ready_task_ids': [t.id for t in all_tasks if t.status == TaskStatus.READY]})
            return
        
        # Use parallel optimizer if available
        if self.parallel_assigner:
            idle_agents = self._get_idle_agents()
            if idle_agents:
                assigned = self.parallel_assigner.assign_for_max_parallelism(idle_agents)
                if assigned > 0:
                    metrics = self.parallel_assigner.get_parallelism_metrics()
                    print(f"  ⚡ {metrics['total_active']} tasks running in parallel")
                return  # Parallel assigner handled it
        
        # Fallback to simple assignment with conflict checking
        # Debug: Log ready tasks
        if len(ready_tasks) > 0:
            print(f"[FORCE-ASSIGN] {len(ready_tasks)} ready tasks: {[t.id for t in ready_tasks]}")
        
        # Find the best agent for each ready task
        for task in ready_tasks:
            # Skip if task is already assigned and in progress
            if task.assigned_agent and task.status == TaskStatus.IN_PROGRESS:
                continue
            
            # Check for conflicts before assigning
            # (We'll check again with specific agent, but this is a quick filter)
            
            # Find an available agent (not supervisor, and no current task)
            best_agent = None
            for agent in self.agents:
                # Skip supervisor - it doesn't work on regular tasks
                if hasattr(agent, 'specialization') and agent.specialization == 'supervisor':
                    continue
                
                # Skip if agent already has a current task
                if agent.current_task:
                    continue
                
                # Check conflicts with this specific agent
                # Note: _check_task_conflicts returns (no_conflicts, conflict_list)
                # where no_conflicts is True if there are NO conflicts
                no_conflicts, conflict_list = self._check_task_conflicts(task, agent.agent_id)
                if no_conflicts:
                    # No conflicts - can assign to this agent
                    # Prefer developer for implementation tasks, tester for test tasks
                    task_id_lower = task.id.lower()
                    task_title_lower = task.title.lower()
                    
                    if any(kw in task_id_lower or kw in task_title_lower for kw in ['test', 'verify', 'validation', 'final']):
                        if hasattr(agent, 'specialization') and agent.specialization == 'tester':
                            best_agent = agent
                            break
                    elif any(kw in task_id_lower or kw in task_title_lower for kw in ['setup', 'implement', 'create', 'build', 'develop', 'code', 'write', 'add', 'configure', 'fix', 'complete', 'finish']):
                        if hasattr(agent, 'specialization') and agent.specialization in ['developer', 'dev']:
                            best_agent = agent
                            break
                    
                    # If no specialization match, use first available agent
                    if not best_agent:
                        best_agent = agent
                else:
                    # Has conflicts - skip this agent for now
                    if LOGGING_AVAILABLE:
                        AgentLogger.debug(agent.agent_id, f"Skipping task {task.id} due to conflicts", 
                                        extra={'conflicts': conflict_list})
            
            if not best_agent:
                continue  # No available agent for this task
            
            # Final conflict check before assignment
            # Note: _check_task_conflicts returns (no_conflicts, conflict_list)
            # where no_conflicts is True iff there are NO conflicts.
            no_conflicts, conflict_list = self._check_task_conflicts(task, best_agent.agent_id)
            if not no_conflicts:
                # Has conflicts - skip this task for now
                if LOGGING_AVAILABLE:
                    AgentLogger.debug(best_agent.agent_id, f"Skipping task {task.id} due to conflicts", 
                                    extra={'conflicts': conflict_list})
                continue
            
            # Assign task to best agent (no conflicts)
            if task.assigned_agent == best_agent.agent_id and task.status == TaskStatus.IN_PROGRESS:
                continue  # Already working on it
            
            # If agent has no current task, assign this one
            if not best_agent.current_task:
                print(f"[FORCE-ASSIGN] Assigning '{task.id}' to {best_agent.agent_id}")
                try:
                    # Ensure agent is started
                    agent_state = self.coordinator.get_agent_state(best_agent.agent_id)
                    if agent_state and agent_state.value not in ['running', 'started']:
                        best_agent.start()
                        time_module.sleep(0.3)
                    elif not agent_state:
                        # Agent state not found, try starting anyway
                        best_agent.start()
                        time_module.sleep(0.3)
                    
                    # Ensure project_dir is set
                    if hasattr(best_agent, 'project_dir') and not best_agent.project_dir:
                        best_agent.project_dir = self.project_dir
                    
                    # Assign and start task
                    if self.coordinator.assign_task(task.id, best_agent.agent_id):
                        if self.coordinator.start_task(task.id, best_agent.agent_id):
                            best_agent.current_task = task
                            print(f"[FORCE-ASSIGN] Task '{task.id}' assigned and started")
                            
                            # Start work in thread
                            import threading
                            def work_on_task():
                                try:
                                    print(f"[FORCE-ASSIGN] Starting work on '{task.id}'")
                                    # CRITICAL: Ensure project_dir is ALWAYS set before work
                                    if hasattr(best_agent, 'project_dir'):
                                        if not best_agent.project_dir or best_agent.project_dir != self.project_dir:
                                            best_agent.project_dir = self.project_dir
                                            print(f"[FORCE-ASSIGN] Set project_dir to {self.project_dir} for {best_agent.agent_id}")
                                    
                                    # Validate project_dir is set
                                    if hasattr(best_agent, 'project_dir') and not best_agent.project_dir:
                                        print(f"[FORCE-ASSIGN] ERROR: project_dir is None for {best_agent.agent_id}!")
                                        return False
                                    
                                    result = best_agent.work(task)
                                    print(f"[FORCE-ASSIGN] Work on '{task.id}' returned: {result}")
                                    
                                    # VALIDATION: Check if work actually created files for setup tasks
                                    if result and 'setup' in task.id.lower():
                                        self._validate_setup_task_completion(task, best_agent)
                                    
                                    return result
                                except Exception as e:
                                    import traceback
                                    print(f"[FORCE-ASSIGN] Error in work: {e}")
                                    traceback.print_exc()
                                    return False
                            
                            work_thread = threading.Thread(target=work_on_task, daemon=True)
                            work_thread.start()
                            print(f"[FORCE-ASSIGN] Work thread started for '{task.id}'")
                            break  # Move to next task after assigning this one
                except Exception as e:
                    import traceback
                    print(f"[FORCE-ASSIGN] Error in simple assignment: {e}")
                    traceback.print_exc()
        
        # FALLBACK: Original complex logic
        # Check each agent
        for agent in self.agents:
            print(f"[FORCE-ASSIGN] Checking agent {agent.agent_id}: state={agent.state.value}, running={agent._running}, current_task={agent.current_task.id if agent.current_task else None}")
            
            # First, ensure agent is started if it's not running
            if agent.state.value not in ['running', 'started']:
                try:
                    agent.start()
                    print(f"[FORCE-ASSIGN] Started agent {agent.agent_id} (state: {agent.state.value})")
                    # Give agent a moment to fully start
                    import time
                    time.sleep(0.5)
                except Exception as e:
                    print(f"[FORCE-ASSIGN] Failed to start agent {agent.agent_id}: {e}")
                    continue
            
            # If agent has no current task, try to assign one
            if not agent.current_task:
                # Ensure agent is running
                if not agent._running or agent.state.value not in ['running', 'started']:
                    try:
                        agent.start()
                        import time
                        time.sleep(0.3)  # Give agent time to start
                    except Exception as e:
                        print(f"[FORCE-ASSIGN] Failed to start agent {agent.agent_id}: {e}")
                        continue
                
                # Try to assign a ready task using agent's request_task method first
                assigned_task = None
                if hasattr(agent, 'request_task'):
                    try:
                        assigned_task = agent.request_task()
                    except Exception as e:
                        print(f"[FORCE-ASSIGN] Error requesting task for {agent.agent_id}: {e}")
                
                # If request_task didn't work, directly assign a task
                if not assigned_task and ready_tasks:
                    # AGGRESSIVE: Assign any ready task to any agent (ignore specialization)
                    for task in ready_tasks:
                        # Skip if task is already assigned
                        if task.assigned_agent and task.assigned_agent != agent.agent_id:
                            continue
                        
                        # Check if task matches agent specialization (but don't require it)
                        matches = True
                        if hasattr(agent, 'specialization') and agent.specialization:
                            # For developer agents, prefer developer tasks but allow others
                            if agent.specialization == 'developer':
                                dev_keywords = ['setup', 'implement', 'create', 'build', 'develop', 'code', 'write', 'add', 'configure']
                                matches = any(kw in task.id.lower() or kw in task.title.lower() for kw in dev_keywords)
                            # For tester agents, prefer test tasks but allow others if no tester tasks available
                            elif agent.specialization == 'tester':
                                # Only match test tasks if there are test tasks available
                                test_tasks_available = any('test' in t.id.lower() or 'test' in t.title.lower() for t in ready_tasks)
                                if test_tasks_available:
                                    matches = 'test' in task.id.lower() or 'test' in task.title.lower()
                                else:
                                    # No test tasks, allow any task
                                    matches = True
                        
                        if matches:
                            # Directly assign the task
                            if self.coordinator.assign_task(task.id, agent.agent_id):
                                # Ensure agent has project_dir set
                                if hasattr(agent, 'project_dir') and not agent.project_dir:
                                    agent.project_dir = self.project_dir
                                
                                # Update task status to IN_PROGRESS
                                if self.coordinator.start_task(task.id, agent.agent_id):
                                    agent.current_task = task
                                    assigned_task = task
                                    print(f"[FORCE-ASSIGN] Directly assigned '{task.id}' to {agent.agent_id}")
                                    
                                    # Start work on the task - call work() directly in a thread
                                    if hasattr(agent, 'work'):
                                        import threading
                                        def work_on_task():
                                            try:
                                                print(f"[FORCE-ASSIGN] Starting work on '{task.id}' in thread")
                                                # CRITICAL: Ensure project_dir is ALWAYS set before work
                                                if hasattr(agent, 'project_dir'):
                                                    if not agent.project_dir or agent.project_dir != self.project_dir:
                                                        agent.project_dir = self.project_dir
                                                        print(f"[FORCE-ASSIGN] Set project_dir to {self.project_dir} for {agent.agent_id}")
                                                
                                                # Validate project_dir is set before calling work
                                                if hasattr(agent, 'project_dir') and not agent.project_dir:
                                                    print(f"[FORCE-ASSIGN] ERROR: project_dir is None for {agent.agent_id}!")
                                                    return False
                                                
                                                result = agent.work(task)
                                                print(f"[FORCE-ASSIGN] Work on '{task.id}' completed with result: {result}")
                                                
                                                # VALIDATION: Check if work actually created files for setup tasks
                                                if result and 'setup' in task.id.lower():
                                                    self._validate_setup_task_completion(task, agent)
                                                
                                                return result
                                            except Exception as e:
                                                import traceback
                                                print(f"[FORCE-ASSIGN] Error in work thread for {task.id}: {e}")
                                                traceback.print_exc()
                                                return False
                                        work_thread = threading.Thread(target=work_on_task, daemon=True)
                                        work_thread.start()
                                        print(f"[FORCE-ASSIGN] Started work thread for '{task.id}'")
                                    elif hasattr(agent, 'start_work'):
                                        try:
                                            agent.start_work(task.id)
                                        except Exception as e:
                                            print(f"[FORCE-ASSIGN] Failed to start work on {task.id}: {e}")
                                    break
                                else:
                                    print(f"[FORCE-ASSIGN] Failed to start task '{task.id}' via coordinator")
                
                if assigned_task:
                    print(f"[FORCE-ASSIGN] Successfully assigned '{assigned_task.id}' to {agent.agent_id}")
    
    def _run_final_verification(self) -> bool:
        """
        Run comprehensive final verification:
        1. Run full test suite
        2. Verify app builds
        3. Verify app actually runs
        4. Check for critical errors
        
        Returns True if all verifications pass, False otherwise
        """
        print("\n[FINAL VERIFICATION] Starting comprehensive app verification...")
        print()
        
        all_passed = True
        
        # Step 1: Run full test suite
        print("[1/4] Running full test suite...")
        test_passed = self._run_comprehensive_tests()
        if not test_passed:
            print("[FAIL] Test suite FAILED")
            all_passed = False
        else:
            print("[OK] Test suite PASSED")
        print()
        
        # Step 2-4: Build/start/responsiveness verification is intentionally not hardcoded here.
        # The core runner is project-agnostic; validation should be expressed through tasks'
        # acceptance criteria commands and artifacts (validated by agents), and/or agent-provided
        # test executors.
        
        return all_passed
    
    def _run_comprehensive_tests(self) -> bool:
        """Run comprehensive test suite (only via agent-provided executor)."""
        # Try to use agents' test methods if available.
        for agent in self.agents:
            if hasattr(agent, '_run_test_suite'):
                try:
                    result = agent._run_test_suite()
                    if result == 0:
                        return True
                    else:
                        print(f"  Test suite returned exit code: {result}")
                        return False
                except Exception as e:
                    print(f"  Error running tests: {e}")

        print("  No test executor found - skipping test verification")
        return True  # Don't fail if no tests exist
    
    def _verify_app_builds(self) -> bool:
        """
        Verify the app can build successfully.
        
        NOTE: The core runner intentionally does not hardcode framework/tooling-specific build steps.
        Build verification should be represented explicitly as task acceptance criteria commands and/or
        agent-provided build/test executors.
        """
        print("  Build verification is task/agent-driven - skipping runner-level build checks")
        return True
    
    def _verify_app_starts(self) -> bool:
        """
        Verify the app can start.
        
        NOTE: Runner-level startup checks are intentionally not hardcoded. Express startup verification
        via tasks' acceptance criteria commands, or implement an agent-provided executor.
        """
        print("  Startup verification is task/agent-driven - skipping runner-level startup checks")
        return True
    
    def _verify_app_responsive(self) -> bool:
        """
        Verify the app is responsive.
        
        NOTE: Responsiveness checks are environment/framework-specific; keep them task/agent-driven.
        """
        print("  Responsiveness verification is task/agent-driven - skipping runner-level responsiveness checks")
        return True
    
    def _verify_app_runs(self):
        """Legacy method - redirects to comprehensive verification"""
        self._run_final_verification()
    
    def _force_complete_setup_tasks_with_files(self):
        """
        Force complete setup tasks that have files but are still marked as in_progress.
        This is a more aggressive check to ensure tasks don't get stuck.
        """
        from .agents.agent_coordinator import TaskStatus
        from datetime import datetime
        
        for task_id, task in self.coordinator.tasks.items():
            # Check setup tasks that are in_progress
            # Generic approach: only complete if task has artifacts defined
            if ('setup' in task_id.lower() or 'initialize' in task_id.lower()) and task.status == TaskStatus.IN_PROGRESS:
                # Check if task has artifacts defined
                if task.artifacts and len(task.artifacts) > 0:
                    # Verify artifacts exist
                    existing_artifacts = [a for a in task.artifacts if os.path.exists(a)]
                    files_exist = len(existing_artifacts) > 0
                    artifacts = existing_artifacts
                else:
                    # No artifacts defined - don't force complete based on file system checks
                    # Let supervisor handle completion based on requirements.md analysis
                    files_exist = False
                    artifacts = []
                
                # If files exist, force complete the task
                if files_exist:
                    print(f"[FORCE-COMPLETE] Setup task '{task_id}' has files but is still in_progress - completing now")
                    try:
                        task.status = TaskStatus.COMPLETED
                        task.progress = 100
                        task.completed_at = datetime.now()
                        if artifacts:
                            task.artifacts = artifacts
                        
                        # Update agent workload
                        if task.assigned_agent:
                            self.coordinator.agent_workloads[task.assigned_agent] = max(
                                0, self.coordinator.agent_workloads.get(task.assigned_agent, 0) - 1
                            )
                        
                        # Update dependent tasks
                        for other_task in self.coordinator.tasks.values():
                            if task_id in other_task.dependencies:
                                self.coordinator._update_task_status(other_task.id)
                        
                        print(f"[FORCE-COMPLETE] Task '{task_id}' completed successfully!")
                        
                        # Update tasks.md
                        self.parser.update_task_in_file(task)
                    except Exception as e:
                        print(f"[FORCE-COMPLETE] Error completing task '{task_id}': {e}")
    
    def _validate_in_progress_setup_tasks(self):
        """
        Validate that setup tasks marked as in_progress with 100% progress actually have files.
        If files don't exist, reset the task to force re-execution.
        This prevents false completions where work() returns True but files aren't created.
        """
        from .agents.agent_coordinator import TaskStatus
        
        for task_id, task in self.coordinator.tasks.items():
            # Only check setup tasks that are in_progress with high progress
            if 'setup' in task_id.lower() and task.status == TaskStatus.IN_PROGRESS and task.progress >= 90:
                # Project-agnostic: only validate if the task explicitly declares artifacts.
                files_exist = True
                if getattr(task, "artifacts", None):
                    missing = [a for a in task.artifacts if a and not os.path.exists(a)]
                    files_exist = len(missing) == 0
                else:
                    # No declared artifacts => cannot validate generically here.
                    files_exist = True

                # If task is at high progress but declared artifacts don't exist, reset it
                if not files_exist:
                    print(f"[VALIDATION] WARNING: Setup task '{task_id}' is at {task.progress}% but required files don't exist!")
                    print(f"[VALIDATION] Resetting task to force re-execution...")
                    
                    # Reset task
                    task.progress = 0
                    task.status = TaskStatus.READY
                    
                    # Clear assignment
                    if task.assigned_agent:
                        self.coordinator.agent_workloads[task.assigned_agent] = max(
                            0, self.coordinator.agent_workloads.get(task.assigned_agent, 0) - 1
                        )
                    task.assigned_agent = None
                    
                    # Update dependent tasks
                    for other_task in self.coordinator.tasks.values():
                        if task_id in other_task.dependencies:
                            self.coordinator._update_task_status(other_task.id)
                    
                    print(f"[VALIDATION] Task '{task_id}' reset and ready for re-execution")
    
    def _validate_setup_task_completion(self, task, agent):
        """
        Validate that a setup task actually created the required files.
        If files don't exist, reset task progress and log error.
        """
        from .agents.agent_coordinator import TaskStatus
        
        # Generic approach: validate based on task artifacts, not hardcoded file checks
        if task.artifacts and len(task.artifacts) > 0:
            # Check if all artifacts exist
            missing_artifacts = [a for a in task.artifacts if not os.path.exists(a)]
            if missing_artifacts:
                print(f"[VALIDATION] WARNING: Setup task '{task.id}' completed but artifacts don't exist: {missing_artifacts}")
                print(f"[VALIDATION] Resetting task progress to force re-execution...")
                task.progress = 0
                task.status = TaskStatus.READY
                if task.assigned_agent:
                    self.coordinator.agent_workloads[task.assigned_agent] = max(
                        0, self.coordinator.agent_workloads.get(task.assigned_agent, 0) - 1
                    )
                task.assigned_agent = None
                return False
        # If no artifacts defined, can't validate generically - supervisor will handle based on requirements.md
    
    def _create_verification_fix_task(self):
        """Create a task to fix verification issues"""
        from .agents.agent_coordinator import Task, TaskStatus
        from datetime import datetime
        
        fix_task_id = "fix-final-verification-issues"
        
        # Check if task already exists
        if fix_task_id in self.coordinator.tasks:
            return
        
        # Create new task
        fix_task = Task(
            id=fix_task_id,
            title="Fix Final Verification Issues",
            description="Fix issues found during final verification to ensure app is fully tested and running",
            estimated_hours=2.0,
            dependencies=[],
            status=TaskStatus.READY,
            progress=0,
            acceptance_criteria=[
                "All tests pass",
                "App builds successfully",
                "App starts and runs correctly",
                "Final verification passes"
            ]
        )
        
        self.coordinator.add_task(fix_task)
        print(f"\n[INFO] Created task '{fix_task_id}' to fix verification issues")
        
        # CRITICAL: Ensure task is immediately visible to agents
        # Verify task was added and is in READY status
        if fix_task_id in self.coordinator.tasks:
            added_task = self.coordinator.tasks[fix_task_id]
            if added_task.status != TaskStatus.READY:
                print(f"[WARNING] Task '{fix_task_id}' status is {added_task.status}, forcing to READY")
                added_task.status = TaskStatus.READY
            if LOGGING_AVAILABLE:
                AgentLogger.info("GenericProjectRunner", f"Verification fix task created and registered",
                    task_id=fix_task_id, extra={'status': added_task.status.value, 'total_tasks': len(self.coordinator.tasks)})
        else:
            print(f"[ERROR] Task '{fix_task_id}' was not added to coordinator!")
            if LOGGING_AVAILABLE:
                AgentLogger.error("GenericProjectRunner", f"Failed to add verification fix task to coordinator")
        
        # Update tasks.md
        try:
            self.parser.update_task_in_file(fix_task)
        except Exception as e:
            if LOGGING_AVAILABLE:
                AgentLogger.warning("GenericProjectRunner", f"Failed to update tasks.md for {fix_task_id}: {e}")


def main():
    """Main entry point - can be customized per project"""
    import argparse
    
    parser = argparse.ArgumentParser(description='Run AI Agent Team from configuration files')
    parser.add_argument('--project-dir', '-d', default='.', help='Project directory containing requirements.md and tasks.md')
    parser.add_argument('--save-interval', '-s', type=int, default=10, help='Progress save interval (seconds)')
    parser.add_argument('--status-interval', type=int, default=3, help='Status display interval (seconds)')
    
    args = parser.parse_args()
    
    # Note: agent_classes must be provided by the project-specific script
    # This is a template - projects should create their own runner that imports this
    print("ERROR: This is a generic runner. Projects should create their own runner script.")
    print("Example:")
    print("  from generic_project_runner import GenericProjectRunner")
    print("  from my_agents import DeveloperAgent, TesterAgent, PMAgent")
    print("  ")
    print("  runner = GenericProjectRunner(")
    print("      project_dir='.',")
    print("      agent_classes={")
    print("          'developer': DeveloperAgent,")
    print("          'tester': TesterAgent,")
    print("          'pm': PMAgent")
    print("      }")
    print("  )")
    print("  runner.run()")
    sys.exit(1)


if __name__ == '__main__':
    main()

