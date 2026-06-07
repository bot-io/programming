@echo off
REM Hermes LLM Model Switcher
REM Usage:
REM   switch.bat                - Interactive menu
REM   switch.bat glm-4.7-flash  - Switch to specific model
REM   switch.bat --list         - List available models
REM   switch.bat --current      - Show current model
python "%~dp0switch_llm.py" %*
