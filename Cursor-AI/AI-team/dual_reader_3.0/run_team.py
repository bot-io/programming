"""
Run AI Agent Team for Dual Reader 3.0 using configuration files
"""

import sys
import os

# Add parent directory to path
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from generic_project_runner import GenericProjectRunner

# Import mobile agents
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from mobile_agents import MobileDeveloperAgent, MobileTesterAgent


def main():
    """Run the Dual Reader 3.0 agent team from configuration files"""
    
    # Get project directory (where this script is located)
    project_dir = os.path.dirname(os.path.abspath(__file__))
    
    # Create runner with agent classes
    runner = GenericProjectRunner(
        project_dir=project_dir,
        agent_classes={
            'developer': MobileDeveloperAgent,
            'tester': MobileTesterAgent
        }
    )
    
    # Run the team
    runner.run(save_interval=10, status_interval=3)


if __name__ == '__main__':
    main()
