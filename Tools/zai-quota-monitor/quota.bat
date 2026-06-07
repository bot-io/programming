@echo off
REM Z.AI Quota Monitor - shows remaining token usage
REM Usage: quota.bat [--json] [--warn 95]
python "%~dp0zai_quota.py" %*
