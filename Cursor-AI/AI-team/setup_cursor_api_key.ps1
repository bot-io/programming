# Setup script for Cursor AI API Key
# Run this script to set the API key for the current PowerShell session

$apiKey = "key_7a4d3336f35055d9410722baa2b3902b9e3c9ac1cd3a9123f8f0f729063418d8"

# Set environment variable for current session
$env:OPENAI_API_KEY = $apiKey

Write-Host "========================================"
Write-Host "Cursor AI API Key Configured"
Write-Host "========================================"
Write-Host ""
Write-Host "[OK] OPENAI_API_KEY set for current session"
Write-Host ""
Write-Host "To make this permanent, add to your PowerShell profile:"
Write-Host "  `$env:OPENAI_API_KEY = '$apiKey'"
Write-Host ""
Write-Host "Or set as system environment variable:"
Write-Host "  [System.Environment]::SetEnvironmentVariable('OPENAI_API_KEY', '$apiKey', 'User')"
Write-Host ""
Write-Host "Testing connection..."
Write-Host ""

# Test the connection
python -c "import os; from ai_client import create_ai_client; client = create_ai_client(); print('AI Client:', 'Available' if client and client.is_available() else 'Not Available'); print('Provider:', client.provider if client else 'None')"

Write-Host ""
Write-Host "You can now run the agent team:"
Write-Host "  cd dual_reader_3.0"
Write-Host "  python run_team.py"

