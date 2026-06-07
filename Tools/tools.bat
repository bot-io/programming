@echo off
REM Add Tools folder to PATH for current session
REM Usage: call this from cmd or add to your profile
REM   call D:\programming\Tools\tools.bat

set "PATH=D:\programming\Tools\zai-quota-monitor;D:\programming\Tools\switch-llm;%PATH%"
echo Tools added to PATH:
echo   quota.bat    - Check Z.AI token usage
echo   switch.bat   - Switch Hermes LLM model
