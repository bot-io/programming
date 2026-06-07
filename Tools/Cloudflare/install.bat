@echo off
REM Cloudflare Agent Setup (Windows)
REM Calls install.ps1 to add Cloudflare MCP servers to Hermes config.yaml.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0install.ps1"