# Cloudflare Agent Setup (PowerShell)
# Permalink: https://developers.cloudflare.com/agent-setup/prompt.md
# Adds Cloudflare MCP servers to Hermes config.yaml (idempotent).

$ErrorActionPreference = 'Stop'

$hermesConfig = Join-Path $env:USERPROFILE 'AppData\Local\hermes\config.yaml'
if (-not (Test-Path -LiteralPath $hermesConfig)) {
  Write-Error "Hermes config not found at $hermesConfig"
  exit 1
}

$cfg = Get-Content -LiteralPath $hermesConfig -Raw
if ($cfg -match '(?m)^mcp_servers:\s*$') {
  Write-Host 'mcp_servers already exists in config.yaml. No changes made.'
  exit 0
}

$pattern = '(servers: \{\}\r?\n)'
$mcp = @'
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

'@
if ($cfg -notmatch $pattern) {
  Write-Error 'Could not find "servers: {}" followed by newline in config.yaml to insert after.'
  exit 1
}
$newCfg = $cfg -replace $pattern, ($matches[0] + $mcp)
$tempFile = Join-Path $env:TEMP 'hermes_config_temp.yaml'
$newCfg | Out-File -LiteralPath $tempFile -Encoding utf8 -NoNewline
Move-Item -LiteralPath $tempFile -Destination $hermesConfig -Force
Write-Host 'Added mcp_servers block to config.yaml.'

Write-Host ''
Write-Host '====================================================================='
Write-Host '  Cloudflare Agent Setup Complete'
Write-Host '====================================================================='
Write-Host ''
Write-Host '  [OK] Skills  <path>'
Write-Host "  [OK] MCPs    $hermesConfig"
Write-Host ''
Write-Host 'Restart your Hermes session to load the MCP servers.'
Write-Host ''
Write-Host 'OAuth will trigger automatically on first Cloudflare tool use.'
Write-Host 'The cloudflare-docs server is public and requires no authentication.'
Write-Host ''
Write-Host 'Verify at: https://developers.cloudflare.com/agent-setup/prompt.md'
Write-Host ''