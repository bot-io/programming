"""
AI Client - Wrapper for LLM APIs (OpenAI, Anthropic, etc.)
Allows agents to generate code using AI instead of templates.
"""

import os
from typing import Optional, Dict, Any, List
import json


class AIClient:
    """Unified interface for LLM APIs"""
    
    def __init__(self, provider: str = "openai", api_key: Optional[str] = None):
        """
        Initialize AI client.
        
        Args:
            provider: "openai" or "anthropic"
            api_key: API key (if None, tries to get from environment)
        """
        self.provider = provider.lower()
        self.api_key = api_key or self._get_api_key()
        self.client = None
        
        if self.api_key:
            self._init_client()
    
    def _get_api_key(self) -> Optional[str]:
        """Get API key from environment variables"""
        if self.provider == "openai":
            # Check for Cursor API key first (starts with "key_")
            cursor_key = os.getenv("CURSOR_API_KEY")
            if cursor_key:
                print(f"[AI_CLIENT] Found CURSOR_API_KEY - will use Cursor API endpoint")
                return cursor_key
            
            # Check OPENAI_API_KEY - could be OpenAI key or Cursor key
            openai_key = os.getenv("OPENAI_API_KEY")
            if openai_key:
                # If it's a Cursor key (starts with "key_"), use it with Cursor endpoint
                if openai_key.startswith("key_"):
                    print(f"[AI_CLIENT] OPENAI_API_KEY appears to be a Cursor key (starts with 'key_') - will use Cursor API endpoint")
                    return openai_key
                # Otherwise, it's a standard OpenAI key
                return openai_key
        elif self.provider == "anthropic":
            return os.getenv("ANTHROPIC_API_KEY")
        return None
    
    def _init_client(self):
        """Initialize the appropriate client"""
        if not self.api_key:
            return
        
        try:
            if self.provider == "openai":
                import openai
                # Check if using Cursor API key (starts with "key_")
                is_cursor = self.api_key.startswith("key_")
                
                if is_cursor:
                    # Cursor API keys may work with standard OpenAI endpoint
                    # Cursor's API is OpenAI-compatible, so try standard endpoint first
                    # If that doesn't work, we'll try Cursor-specific endpoints
                    cursor_endpoints = [
                        None,  # Try standard OpenAI endpoint first
                        "https://api.cursor.sh/openai/v1",  # Cursor's OpenAI-compatible endpoint
                        "https://api.cursor.com/openai/v1",  # Alternative endpoint
                    ]
                    
                    client_initialized = False
                    for base_url in cursor_endpoints:
                        try:
                            if base_url is None:
                                print(f"[AI_CLIENT] Trying Cursor API key with standard OpenAI endpoint...")
                                self.client = openai.OpenAI(api_key=self.api_key)
                            else:
                                print(f"[AI_CLIENT] Trying Cursor endpoint: {base_url}")
                                self.client = openai.OpenAI(
                                    api_key=self.api_key,
                                    base_url=base_url
                                )
                            print(f"[AI_CLIENT] Cursor API client initialized successfully")
                            client_initialized = True
                            break
                        except Exception as e:
                            if base_url is None:
                                print(f"[AI_CLIENT] Standard OpenAI endpoint failed: {e}")
                            else:
                                print(f"[AI_CLIENT] Endpoint {base_url} failed: {e}")
                            continue
                    
                    if not client_initialized:
                        print(f"[AI_CLIENT] WARNING: Cursor API key failed with all endpoints")
                        print(f"[AI_CLIENT] Note: Cursor API keys (starting with 'key_') are typically for Cursor's admin API,")
                        print(f"[AI_CLIENT]       not for direct LLM access. You may need to use your own OpenAI/Anthropic API key.")
                        print(f"[AI_CLIENT]       Cursor allows users to input their own LLM provider keys in settings.")
                        self.client = None
                else:
                    # Use standard OpenAI endpoint for OpenAI keys
                    self.client = openai.OpenAI(api_key=self.api_key)
                    print(f"[AI_CLIENT] OpenAI client initialized successfully")
            elif self.provider == "anthropic":
                import anthropic
                self.client = anthropic.Anthropic(api_key=self.api_key)
                print(f"[AI_CLIENT] Anthropic client initialized successfully")
        except ImportError as e:
            print(f"[WARNING] {self.provider} package not installed. Install with: pip install {self.provider}")
            print(f"[WARNING] ImportError details: {e}")
            self.client = None
        except Exception as e:
            print(f"[ERROR] Failed to initialize {self.provider} client: {e}")
            self.client = None
    
    def is_available(self) -> bool:
        """Check if AI client is available and configured"""
        return self.client is not None and self.api_key is not None
    
    def generate_code(
        self,
        prompt: str,
        context: str = "",
        language: str = "python",
        model: Optional[str] = None,
        temperature: float = 0.7,
        max_tokens: Optional[int] = None
    ) -> str:
        """
        Generate code using AI.
        
        Args:
            prompt: The task/requirement description
            context: Additional context (requirements, existing code, etc.)
            language: Programming language
            model: Model to use (defaults based on provider)
            temperature: Sampling temperature
            max_tokens: Maximum tokens to generate
        
        Returns:
            Generated code as string
        """
        if not self.is_available():
            raise RuntimeError(f"AI client not available. Check API key for {self.provider}.")
        
        # Build full prompt
        full_prompt = self._build_prompt(prompt, context, language)
        
        # Get model
        if not model:
            model = self._get_default_model()
        
        # Generate
        if self.provider == "openai":
            return self._generate_openai(full_prompt, model, temperature, max_tokens)
        elif self.provider == "anthropic":
            return self._generate_anthropic(full_prompt, model, temperature, max_tokens)
        else:
            raise ValueError(f"Unknown provider: {self.provider}")
    
    def _build_prompt(self, prompt: str, context: str, language: str) -> str:
        """Build the full prompt for code generation"""
        system_prompt = f"""You are an expert software developer specializing in {language} and modern software development practices.

Your task is to generate complete, production-ready code based on requirements. The code should be:
- Well-structured and maintainable
- Include proper error handling
- Follow best practices for the language
- Include helpful comments where appropriate
- Be ready to use without modification

Generate ONLY the code, no explanations unless specifically requested."""
        
        user_prompt = f"""Generate {language} code for the following task:

{prompt}

{f'Additional Context:\n{context}' if context else ''}

Provide complete, working code that implements the requirements."""
        
        return {
            "system": system_prompt,
            "user": user_prompt
        }
    
    def _get_default_model(self) -> str:
        """Get default model for provider"""
        # Check if using Cursor API key - Cursor uses OpenAI-compatible API
        if os.getenv("CURSOR_API_KEY") and self.provider == "openai":
            # Cursor AI typically uses gpt-4 or similar models
            return "gpt-4-turbo-preview"  # Cursor-compatible model
        
        if self.provider == "openai":
            return "gpt-4-turbo-preview"  # or "gpt-4" or "gpt-3.5-turbo"
        elif self.provider == "anthropic":
            return "claude-3-opus-20240229"  # or "claude-3-sonnet-20240229"
        return "gpt-4"
    
    def _generate_openai(self, prompt_dict: Dict[str, str], model: str, temperature: float, max_tokens: Optional[int]) -> str:
        """Generate using OpenAI API (or Cursor AI which is OpenAI-compatible)"""
        messages = [
            {"role": "system", "content": prompt_dict["system"]},
            {"role": "user", "content": prompt_dict["user"]}
        ]
        
        kwargs = {
            "model": model,
            "messages": messages,
            "temperature": temperature
        }
        
        if max_tokens:
            kwargs["max_tokens"] = max_tokens
        
        # Check if using Cursor API
        is_cursor = self.api_key and self.api_key.startswith("key_")
        if is_cursor:
            print(f"[AI_CLIENT] Generating code using Cursor AI (OpenAI-compatible API)")
        
        try:
            response = self.client.chat.completions.create(**kwargs)
            if is_cursor:
                print(f"[AI_CLIENT] Cursor AI generation successful")
            return response.choices[0].message.content
        except Exception as e:
            if is_cursor:
                print(f"[AI_CLIENT] Error with Cursor API: {e}")
                print(f"[AI_CLIENT] Attempting to diagnose the issue...")
                # Try to provide helpful error information
                error_str = str(e)
                if "401" in error_str or "unauthorized" in error_str.lower():
                    print(f"[AI_CLIENT] Authentication error - check if Cursor API key is valid")
                elif "404" in error_str or "not found" in error_str.lower():
                    print(f"[AI_CLIENT] Endpoint not found - Cursor API endpoint may have changed")
                elif "connection" in error_str.lower() or "timeout" in error_str.lower():
                    print(f"[AI_CLIENT] Connection error - check network connectivity")
            raise
    
    def _generate_anthropic(self, prompt_dict: Dict[str, str], model: str, temperature: float, max_tokens: Optional[int]) -> str:
        """Generate using Anthropic API"""
        messages = [
            {"role": "user", "content": f"{prompt_dict['system']}\n\n{prompt_dict['user']}"}
        ]
        
        kwargs = {
            "model": model,
            "messages": messages,
            "temperature": temperature,
            "max_tokens": max_tokens or 4096
        }
        
        response = self.client.messages.create(**kwargs)
        return response.content[0].text
    
    def generate_with_retry(
        self,
        prompt: str,
        context: str = "",
        language: str = "python",
        max_retries: int = 3,
        **kwargs
    ) -> str:
        """Generate code with retry logic"""
        for attempt in range(max_retries):
            try:
                return self.generate_code(prompt, context, language, **kwargs)
            except Exception as e:
                if attempt == max_retries - 1:
                    raise
                print(f"[AI] Generation attempt {attempt + 1} failed: {e}. Retrying...")
                import time
                time.sleep(2 ** attempt)  # Exponential backoff
        
        raise RuntimeError("Failed to generate code after retries")


def create_ai_client(provider: Optional[str] = None, api_key: Optional[str] = None) -> Optional[AIClient]:
    """
    Create an AI client, trying different providers if needed.
    
    Args:
        provider: Preferred provider ("openai" or "anthropic")
        api_key: API key (if None, tries environment variables)
    
    Returns:
        AIClient instance or None if no API key found
    """
    print(f"[AI_CLIENT] create_ai_client called: provider={provider}, api_key provided={bool(api_key)}")
    
    # Try specified provider first
    if provider:
        client = AIClient(provider=provider, api_key=api_key)
        if client.is_available():
            print(f"[AI_CLIENT] Successfully created client with provider={provider}")
            return client
        else:
            print(f"[AI_CLIENT] Provider {provider} not available (api_key={bool(client.api_key)}, client={bool(client.client)})")
    
    # Try OpenAI (prioritize OPENAI_API_KEY over CURSOR_API_KEY)
    print(f"[AI_CLIENT] Trying OpenAI provider...")
    client = AIClient(provider="openai", api_key=api_key)
    if client.is_available():
        print(f"[AI_CLIENT] Successfully created OpenAI client")
        return client
    else:
        print(f"[AI_CLIENT] OpenAI not available (api_key={bool(client.api_key)}, client={bool(client.client)})")
        if client.api_key:
            api_key_preview = client.api_key[:10] + "..." if len(client.api_key) > 10 else client.api_key
            print(f"[AI_CLIENT] API key preview: {api_key_preview} (starts with 'key_': {client.api_key.startswith('key_') if client.api_key else False})")
    
    # Try Anthropic
    print(f"[AI_CLIENT] Trying Anthropic provider...")
    client = AIClient(provider="anthropic", api_key=api_key)
    if client.is_available():
        print(f"[AI_CLIENT] Successfully created Anthropic client")
        return client
    else:
        print(f"[AI_CLIENT] Anthropic not available (api_key={bool(client.api_key)}, client={bool(client.client)})")
    
    # No API key found
    print(f"[AI_CLIENT] No available AI provider found. Check environment variables: CURSOR_API_KEY, OPENAI_API_KEY, ANTHROPIC_API_KEY")
    return None

