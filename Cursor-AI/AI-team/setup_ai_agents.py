"""
Setup script to install required packages for AI-powered agents.
"""

import subprocess
import sys
import os

def install_package(package):
    """Install a Python package"""
    try:
        subprocess.check_call([sys.executable, "-m", "pip", "install", package])
        print(f"[OK] Installed {package}")
        return True
    except subprocess.CalledProcessError:
        print(f"[ERROR] Failed to install {package}")
        return False

def main():
    print("=" * 60)
    print("AI Agent Setup - Installing Required Packages")
    print("=" * 60)
    print()
    
    packages = [
        "openai>=1.0.0",
        "anthropic>=0.18.0"
    ]
    
    print("Installing packages for AI code generation...")
    print()
    
    success = True
    for package in packages:
        if not install_package(package):
            success = False
    
    print()
    if success:
        print("=" * 60)
        print("[SUCCESS] All packages installed!")
        print("=" * 60)
        print()
        print("Next steps:")
        print("1. Set your API key as an environment variable:")
        print("   - For OpenAI: export OPENAI_API_KEY='your-key-here'")
        print("   - For Anthropic: export ANTHROPIC_API_KEY='your-key-here'")
        print()
        print("2. Or create a .env file in the project root:")
        print("   OPENAI_API_KEY=your-key-here")
        print("   ANTHROPIC_API_KEY=your-key-here")
        print()
        print("3. Run your agent team - they will automatically use AI if API keys are set")
    else:
        print("=" * 60)
        print("[WARNING] Some packages failed to install")
        print("=" * 60)
        print("You can still use template-based generation without AI")

if __name__ == "__main__":
    main()

