"""
Run AI Agent Team for Dual Reader 3.1 using configuration files
"""
# -*- coding: utf-8 -*-

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

# Import mobile agents (they will detect Flutter from requirements.md)
# The agents are in dual_reader_3.0 but work for any project
sys.path.insert(0, os.path.join(parent_dir, 'dual_reader_3.0'))
from mobile_agents import MobileDeveloperAgent as FlutterDeveloperAgent, MobileTesterAgent as FlutterTesterAgent


def main():
    """Run the Dual Reader 3.1 agent team from configuration files"""
    
    # Get project directory (where this script is located)
    project_dir = os.path.dirname(os.path.abspath(__file__))
    
    # Create runner with agent classes and counts for parallel execution
    runner = GenericProjectRunner(
        project_dir=project_dir,
        agent_classes={
            'developer': FlutterDeveloperAgent,
            'tester': FlutterTesterAgent
        },
        agent_counts={
            'developer': 3,  # 3 developers working in parallel
            'tester': 2      # 2 testers for faster testing
        },
        enable_parallel_optimization=True  # Enable parallel execution optimizer
    )
    
    # Run the team
    runner.run(save_interval=10, status_interval=3)


if __name__ == '__main__':
    main()

