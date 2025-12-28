"""
Run AI Agent Team for Dual Reader 3.2 using configuration files
Waits for Dual Reader 3.1 to complete before starting
"""
# -*- coding: utf-8 -*-

import sys
import os
import io
import time

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

# Import completion checker
from check_3_1_completion import check_3_1_completion


def wait_for_3_1_completion(check_interval: int = 30):
    """
    Wait for Dual Reader 3.1 to complete before starting 3.2.
    
    Args:
        check_interval: How often to check for completion (seconds)
    """
    print("=" * 100)
    print("DUAL READER 3.2 - WAITING FOR 3.1 COMPLETION")
    print("=" * 100)
    print()
    print("This team will start automatically once Dual Reader 3.1 is completed.")
    print(f"Checking every {check_interval} seconds...")
    print()
    
    last_status = None
    check_count = 0
    
    while True:
        is_completed, message = check_3_1_completion()
        check_count += 1
        
        # Print status if it changed
        if message != last_status:
            print(f"[Check #{check_count}] {message}")
            last_status = message
        
        if is_completed:
            print()
            print("=" * 100)
            print("✅ DUAL READER 3.1 IS COMPLETE!")
            print("=" * 100)
            print()
            print("Starting Dual Reader 3.2 team in 5 seconds...")
            print()
            time.sleep(5)
            break
        
        # Wait before next check
        time.sleep(check_interval)
    
    return True


def main():
    """Run the Dual Reader 3.2 agent team from configuration files"""
    
    # Get project directory (where this script is located)
    project_dir = os.path.dirname(os.path.abspath(__file__))
    
    print("=" * 100)
    print("DUAL READER 3.2 - AI TEAM")
    print("=" * 100)
    print()
    print("NOTE: This team is currently unscheduled.")
    print("To start the team manually, remove the exit() call below.")
    print()
    
    # Exit early - team is unscheduled
    exit(0)
    
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

