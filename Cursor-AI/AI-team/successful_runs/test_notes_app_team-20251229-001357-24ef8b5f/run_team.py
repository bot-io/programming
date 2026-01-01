"""
Run AI Agent Team using configuration files

This is a generic runner that works with any project type.
The system relies purely on requirements.md - no project-specific assumptions.

The supervisor will analyze requirements.md to:
- Determine project type (Flutter, React, Python, etc.)
- Determine optimal team size
- Generate appropriate tasks
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
    runner = GenericProjectRunner(
        project_dir=project_dir,
        agent_classes={
            'developer': GenericDeveloperAgent,
            'tester': GenericTesterAgent
        },
        # agent_counts={},  # Omit for autonomous sizing (supervisor determines from requirements.md)
        enable_parallel_optimization=True  # Enable parallel execution optimizer
    )
    
    # Run the team
    runner.run(save_interval=10, status_interval=3)


if __name__ == '__main__':
    main()

