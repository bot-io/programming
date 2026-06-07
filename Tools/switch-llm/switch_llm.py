#!/usr/bin/env python3
"""
Hermes LLM Model Switcher
===========================
Switch Hermes Agent's active model to a different GLM model.
Edits the config.yaml file and restarts the gateway.

Free GLM models (Tier 0 — $0):
  glm-4.7-flash      — Best free model, good quality
  glm-4.5-flash      — Older free model, still decent

Cheap GLM models:
  glm-4.7-flashx     — $0.07/$0.40 per M tokens
  glm-4.5-air        — $0.20/$1.10 per M tokens

Premium GLM models:
  glm-4.7            — $0.60/$2.20 per M tokens
  glm-5.1            — $1.40/$4.40 per M tokens

Usage:
  python switch_llm.py                    # Interactive menu
  python switch_llm.py glm-4.7-flash      # Switch to specific model
  python switch_llm.py --list             # List available models
  python switch_llm.py --current          # Show current model
"""

import os
import sys
import re
from pathlib import Path

CONFIG_PATH = Path.home() / "AppData" / "Local" / "hermes" / "config.yaml"

# Available GLM models organized by tier
MODELS = {
    # Tier 0: Free
    "glm-4.7-flash": {
        "tier": 0,
        "cost": "FREE",
        "desc": "Best free model. Good quality for most tasks.",
    },
    "glm-4.5-flash": {
        "tier": 0,
        "cost": "FREE",
        "desc": "Older free model. Decent quality.",
    },
    # Tier 1: Ultra-cheap
    "glm-4.7-flashx": {
        "tier": 1,
        "cost": "$0.07/$0.40 per M",
        "desc": "Fast and cheap. Good for code edits and simple tasks.",
    },
    # Tier 2: Cheap
    "glm-4.5-air": {
        "tier": 2,
        "cost": "$0.20/$1.10 per M",
        "desc": "Balanced cost/quality. Good for multi-file work.",
    },
    "glm-4-32b-0414-128k": {
        "tier": 2,
        "cost": "$0.10/$0.10 per M",
        "desc": "128K context, very cheap.",
    },
    # Tier 3: Mid
    "glm-4.7": {
        "tier": 3,
        "cost": "$0.60/$2.20 per M",
        "desc": "High quality. Good for architecture and complex debug.",
    },
    "glm-4.5": {
        "tier": 3,
        "cost": "$0.60/$2.20 per M",
        "desc": "High quality, 355B params.",
    },
    # Tier 4: Premium
    "glm-5.1": {
        "tier": 4,
        "cost": "$1.40/$4.40 per M",
        "desc": "Best GLM model. Major coding leap.",
    },
}


def get_current_model():
    """Read current model from config.yaml."""
    if not CONFIG_PATH.exists():
        return None
    content = CONFIG_PATH.read_text(encoding="utf-8")
    match = re.search(r"^\s*default:\s*(.+)$", content, re.MULTILINE)
    if match:
        return match.group(1).strip()
    return None


def set_model(model_name):
    """Update the model in config.yaml."""
    if model_name not in MODELS:
        print(f"ERROR: Unknown model '{model_name}'")
        print(f"Available: {', '.join(MODELS.keys())}")
        sys.exit(1)
    
    if not CONFIG_PATH.exists():
        print(f"ERROR: Config not found at {CONFIG_PATH}")
        sys.exit(1)
    
    content = CONFIG_PATH.read_text(encoding="utf-8")
    
    # Replace the model.default line
    new_content = re.sub(
        r"^(\s*)default:\s+.+$",
        r"\1default: " + model_name,
        content,
        count=1,
        flags=re.MULTILINE,
    )
    
    if new_content == content:
        print("ERROR: Could not find 'default:' line in config.yaml")
        sys.exit(1)
    
    CONFIG_PATH.write_text(new_content, encoding="utf-8")
    
    info = MODELS[model_name]
    tier_str = f"Tier {info['tier']}" if info['tier'] > 0 else "FREE"
    print(f"✅ Model switched to: {model_name}")
    print(f"   {info['desc']}")
    print(f"   Cost: {info['cost']} ({tier_str})")
    print(f"\n⚠️  Send /reset to Hermes to apply the change.")


def list_models():
    """List all available models."""
    current = get_current_model()
    
    print("\n" + "=" * 60)
    print("  Available GLM Models (Z.AI)")
    print("=" * 60)
    
    current_tier = -1
    for name, info in sorted(MODELS.items(), key=lambda x: (x[1]["tier"], x[0])):
        if info["tier"] != current_tier:
            current_tier = info["tier"]
            tier_label = "FREE" if current_tier == 0 else f"Tier {current_tier}"
            print(f"\n  --- {tier_label} ---")
        
        marker = " ← current" if name == current else ""
        print(f"  {name}{marker}")
        print(f"    {info['desc']}")
        print(f"    Cost: {info['cost']}")
    
    print(f"\n{'=' * 60}")
    if current:
        print(f"  Current model: {current}")
    print(f"  Usage: switch_llm.py <model-name>")
    print(f"{'=' * 60}\n")


def interactive_menu():
    """Show interactive model selection menu."""
    current = get_current_model()
    
    print("\n🔄 Hermes LLM Model Switcher")
    print(f"   Current: {current or 'unknown'}")
    print()
    
    # Show free models first
    free_models = {k: v for k, v in MODELS.items() if v["tier"] == 0}
    all_models = list(MODELS.keys())
    
    for i, name in enumerate(all_models):
        info = MODELS[name]
        tier = "FREE" if info["tier"] == 0 else f"Tier {info['tier']}"
        marker = " ←" if name == current else ""
        print(f"  [{i + 1}] {name} ({tier}, {info['cost']}){marker}")
    
    print(f"  [0] Cancel")
    print()
    
    try:
        choice = input("Select model (number or name): ").strip()
    except (EOFError, KeyboardInterrupt):
        print("\nCancelled.")
        return
    
    if choice == "0" or choice.lower() in ("cancel", "q", "quit"):
        print("Cancelled.")
        return
    
    # Try as number
    try:
        idx = int(choice) - 1
        if 0 <= idx < len(all_models):
            set_model(all_models[idx])
            return
    except ValueError:
        pass
    
    # Try as model name
    if choice in MODELS:
        set_model(choice)
    else:
        print(f"Unknown model: {choice}")
        print(f"Available: {', '.join(MODELS.keys())}")


def main():
    if "--list" in sys.argv or "-l" in sys.argv:
        list_models()
        return
    
    if "--current" in sys.argv:
        current = get_current_model()
        if current:
            info = MODELS.get(current, {})
            print(f"Current model: {current}")
            if info:
                print(f"  {info.get('desc', '')}")
                print(f"  Cost: {info.get('cost', 'unknown')}")
        else:
            print("Could not determine current model.")
        return
    
    # Check for model name argument
    args = [a for a in sys.argv[1:] if not a.startswith("-")]
    if args:
        set_model(args[0])
    else:
        interactive_menu()


if __name__ == "__main__":
    main()
