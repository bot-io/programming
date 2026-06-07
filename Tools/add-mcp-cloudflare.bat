@echo off
echo Adding Cloudflare MCP servers to Hermes config...
set CONFIG=%USERPROFILE%\AppData\Local\hermes\config.yaml
set TEMPFILE=%TEMP%\hermes_config_temp.yaml

REM Find line "lsp:" and the next non-empty line after "servers: {}"
REM Insert mcp_servers block after that

powershell -NoProfile -Command ^
  "$cfg = Get-Content '%CONFIG%' -Raw; " ^
  "$pattern = '(lsp:.*?servers: \{\}\s+)'; " ^
  "$mcp = @\""
mcp_servers:
  cloudflare:
    url: https://mcp.cloudflare.com/mcp
  cloudflare-docs:
    url: https://docs.mcp.cloudflare.com/mcp
  cloudflare-bindings:
    url: https://bindings.mcp.cloudflare.com/mcp
  cloudflare-builds:
    url: https://builds.mcp.cloudflare.com/mcp
  cloudflare-observability:
    url: https://observability.mcp.cloudflare.com/mcp

\"@; " ^
  "if ($cfg -match '(?m)^mcp_servers:\s*$') { Write-Host 'mcp_servers already exists.'; exit 1 }; " ^
  "$newCfg = $cfg -replace $pattern, ('${1}' + $mcp); " ^
  "$newCfg | Out-File -FilePath '%TEMPFILE%' -Encoding utf8 -NoNewline; " ^
  "Move-Item -Force '%TEMPFILE%' '%CONFIG%'"

if errorlevel 1 (
  echo Failed to add mcp_servers. Check if it already exists.
  exit /b 1
)

echo Done! Cloudflare MCP servers added.
echo Restart Hermes to load them (e.g., run: hermes restart or close and reopen your terminal).