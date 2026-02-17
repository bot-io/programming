# AI Team Configuration Guide

This guide explains how to configure the AI Team system to use different LLM providers and custom endpoints.

## Overview

The AI Team system supports multiple LLM providers through a unified configuration system. You can switch between providers by editing the `ai_team_settings.local.json` file.

## Configuration File

### Location
- **File**: `ai_team_settings.local.json`
- **Example**: `ai_team_settings.example.json`
- **Status**: Gitignored (safe for API keys)

### Configuration Precedence

The system checks configuration in this order (highest to lowest priority):

1. **Environment variables** (e.g., `GEMINI_API_KEY`)
2. **Settings file** (`ai_team_settings.local.json`)
3. **Default values**

## Supported Providers

### 1. Google Gemini

**Configuration:**
```json
{
  "AI_PROVIDER": "gemini",
  "GEMINI_API_KEY": "your_gemini_api_key_here",
  "GEMINI_MODEL": "gemini-1.5-pro",
  "GEMINI_BASE_URL": null
}
```

**Environment Variables:**
- `GEMINI_API_KEY` (or `GOOGLE_API_KEY` as fallback)
- `GEMINI_MODEL` (optional, defaults to `gemini-1.5-pro`)
- `GEMINI_BASE_URL` (optional, for custom Gemini-compatible endpoints)

**Getting an API Key:**
1. Visit [Google AI Studio](https://makersuite.google.com/app/apikey)
2. Create a new API key
3. Add the key to your settings file or environment

### 2. OpenAI (and Compatible Services)

**Configuration:**
```json
{
  "AI_PROVIDER": "openai",
  "OPENAI_API_KEY": "your_openai_api_key_here",
  "OPENAI_MODEL": "gpt-4-turbo-preview",
  "OPENAI_BASE_URL": null
}
```

**Environment Variables:**
- `OPENAI_API_KEY`
- `OPENAI_MODEL` (optional)
- `OPENAI_BASE_URL` (optional, for custom OpenAI-compatible endpoints)

**Supported OpenAI-compatible services:**
- Official OpenAI API
- Azure OpenAI (set `OPENAI_BASE_URL` to your Azure endpoint)
- Local LLM servers with OpenAI-compatible API (vLLM, LM Studio, etc.)
- Any other OpenAI-compatible service

**Using a Local LLM Server:**
```json
{
  "AI_PROVIDER": "openai",
  "OPENAI_API_KEY": "dummy-key",
  "OPENAI_MODEL": "local-model",
  "OPENAI_BASE_URL": "http://localhost:8000/v1"
}
```

### 3. Anthropic Claude

**Configuration:**
```json
{
  "AI_PROVIDER": "anthropic",
  "ANTHROPIC_API_KEY": "your_anthropic_api_key_here",
  "ANTHROPIC_MODEL": "claude-3-opus-20240229",
  "ANTHROPIC_BASE_URL": null
}
```

**Environment Variables:**
- `ANTHROPIC_API_KEY`
- `ANTHROPIC_MODEL` (optional)
- `ANTHROPIC_BASE_URL` (optional, for custom Claude-compatible endpoints)

## Quick Setup Guide

### Step 1: Copy Example Configuration

```bash
cp ai_team_settings.example.json ai_team_settings.local.json
```

### Step 2: Configure Your Provider

Edit `ai_team_settings.local.json` and set:

1. **Provider**: Choose `"gemini"`, `"openai"`, or `"anthropic"`
2. **API Key**: Add your API key for the chosen provider
3. **Model** (optional): Specify the model to use
4. **Base URL** (optional): Set custom endpoint if needed

### Step 3: Verify Configuration

Run the AI team and check for initialization messages:

```bash
python run_team.py
```

Look for messages like:
- `[AI_CLIENT] Gemini REST client initialized successfully`
- `[AI_CLIENT] Using custom OpenAI-compatible endpoint: http://localhost:8000/v1`

## Advanced Configuration

### Using Custom LLM Endpoints

The system supports any OpenAI-compatible or Anthropic-compatible endpoint:

**Example 1: Local vLLM Server**
```json
{
  "AI_PROVIDER": "openai",
  "OPENAI_API_KEY": "dummy",
  "OPENAI_BASE_URL": "http://localhost:8000/v1"
}
```

**Example 2: LM Studio**
```json
{
  "AI_PROVIDER": "openai",
  "OPENAI_API_KEY": "lm-studio-key",
  "OPENAI_BASE_URL": "http://localhost:1234/v1"
}
```

**Example 3: Ollama with OpenAI Compatibility**
```json
{
  "AI_PROVIDER": "openai",
  "OPENAI_API_KEY": "ollama",
  "OPENAI_BASE_URL": "http://localhost:11434/v1"
}
```

**Example 4: Custom Gemini-Compatible Endpoint**
```json
{
  "AI_PROVIDER": "gemini",
  "GEMINI_API_KEY": "your-key",
  "GEMINI_BASE_URL": "https://your-custom-endpoint.com"
}
```

### Using Environment Variables

Instead of (or in addition to) the settings file, you can use environment variables:

**Linux/Mac:**
```bash
export AI_PROVIDER="gemini"
export GEMINI_API_KEY="your_api_key_here"
python run_team.py
```

**Windows (PowerShell):**
```powershell
$env:AI_PROVIDER="gemini"
$env:GEMINI_API_KEY="your_api_key_here"
python run_team.py
```

**Windows (Command Prompt):**
```cmd
set AI_PROVIDER=gemini
set GEMINI_API_KEY=your_api_key_here
python run_team.py
```

## Switching Between Providers

To switch providers:

1. **Edit** `ai_team_settings.local.json`
2. **Change** `AI_PROVIDER` to your desired provider
3. **Update** the corresponding API key
4. **Run** the team again

Example switching from Gemini to OpenAI:
```json
{
  "AI_PROVIDER": "openai",  // Changed from "gemini"
  "OPENAI_API_KEY": "sk-...",  // Add OpenAI key
  "GEMINI_API_KEY": ""  // Remove or leave Gemini key
}
```

## Troubleshooting

### "AI client not available" Error

**Cause**: API key not configured or invalid

**Solutions**:
1. Check that `ai_team_settings.local.json` exists
2. Verify the API key is correct
3. Check that `AI_PROVIDER` matches your API key
4. Try using environment variables instead

### "Authentication error" with Cursor Keys

**Cause**: Cursor API keys (`key_*`) are for Cursor's admin API, not direct LLM access

**Solutions**:
1. Use your own OpenAI/Anthropic API key instead
2. Or configure Cursor to use your LLM provider in Cursor settings

### Custom Endpoint Not Working

**Cause**: Base URL format incorrect or service not OpenAI-compatible

**Solutions**:
1. Verify the endpoint path ends in `/v1` (for OpenAI-compatible)
2. Check that the service supports the model you specified
3. Test the endpoint with curl first:
   ```bash
   curl http://localhost:8000/v1/models
   ```

### Module Import Errors

**Cause**: Required Python packages not installed

**Solutions**:
- For OpenAI: `pip install openai`
- For Anthropic: `pip install anthropic`
- Gemini uses stdlib only (no extra packages needed)

## Security Best Practices

1. **Never commit** `ai_team_settings.local.json` to version control
2. **Use environment variables** for production deployments
3. **Rotate API keys** regularly
4. **Limit API key permissions** to only what's needed
5. **Use separate keys** for development and production

## Testing Configuration

Test your configuration without running the full team:

```python
from src.ai_team.utils.ai_client import create_ai_client

# Test with current settings
client = create_ai_client()
print(f"Provider: {client.provider}")
print(f"Available: {client.is_available()}")

# Test a simple generation
if client.is_available():
    result = client.generate_code(
        prompt="Write a hello world function",
        language="python"
    )
    print("Generated code:", result[:100])
```
