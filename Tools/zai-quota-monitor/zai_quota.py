#!/usr/bin/env python3
"""
Z.AI / GLM Token Usage Monitor
================================
Queries the Z.AI quota API and displays remaining token usage
for the current 5-hour rolling window.

API endpoint: GET https://api.z.ai/api/monitor/usage/quota/limit
Auth: Bearer GLM_API_KEY from ~/.hermes/.env

Usage:
  python zai_quota.py              # Show quota status
  python zai_quota.py --json       # Raw JSON output
  python zai_quota.py --warn 95    # Exit 1 if usage >= 95% (for scripts)
  python zai_quota.py --cron       # Cron-friendly summary (compact)
"""

import json
import os
import sys
import urllib.request
import urllib.error
from datetime import datetime, timezone, timedelta
from pathlib import Path

# Sofia, Bulgaria: UTC+3 (EEST summer) / UTC+2 (EET winter)
SOFIA_OFFSET_SUMMER = 3
SOFIA_OFFSET_WINTER = 2


def get_sofia_offset():
    """Simple DST detection: DST in Bulgaria is last Sunday of March to last Sunday of October."""
    now = datetime.now(timezone.utc)
    year = now.year
    # Last Sunday of March
    mar31 = datetime(year, 3, 31)
    mar_last_sun = mar31 - timedelta(days=(mar31.weekday() + 1) % 7)
    # Last Sunday of October
    oct31 = datetime(year, 10, 31)
    oct_last_sun = oct31 - timedelta(days=(oct31.weekday() + 1) % 7)
    
    dst_start = mar_last_sun.replace(hour=1)  # 01:00 UTC = 03:00 EET
    dst_end = oct_last_sun.replace(hour=1)
    
    if dst_start <= now.replace(tzinfo=None) < dst_end:
        return SOFIA_OFFSET_SUMMER
    return SOFIA_OFFSET_WINTER


def sofia_now():
    """Current time in Sofia, Bulgaria."""
    offset = get_sofia_offset()
    return datetime.now(timezone(timedelta(hours=offset)))


def load_api_key():
    """Load GLM_API_KEY from Hermes .env file."""
    env_path = Path.home() / "AppData" / "Local" / "hermes" / ".env"
    if not env_path.exists():
        print("ERROR: ~/.hermes/.env not found", file=sys.stderr)
        sys.exit(1)
    
    for line in env_path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if line.startswith("GLM_API_KEY=") and not line.startswith("#"):
            key = line.split("=", 1)[1].strip()
            if key:
                return key
    
    # Fallback to environment variable
    key = os.environ.get("GLM_API_KEY", "")
    if not key:
        print("ERROR: GLM_API_KEY not found in .env or environment", file=sys.stderr)
        sys.exit(1)
    return key


def fetch_quota(api_key):
    """Fetch quota from Z.AI API."""
    url = "https://api.z.ai/api/monitor/usage/quota/limit"
    req = urllib.request.Request(url, method="GET")
    req.add_header("Authorization", api_key)
    req.add_header("Content-Type", "application/json")
    req.add_header("User-Agent", "Hermes-Quota-Monitor/1.0")
    
    try:
        with urllib.request.urlopen(req, timeout=10) as resp:
            data = json.loads(resp.read().decode("utf-8"))
    except urllib.error.HTTPError as e:
        body = e.read().decode("utf-8", errors="replace")
        print(f"ERROR: API returned HTTP {e.code}: {body}", file=sys.stderr)
        sys.exit(1)
    except urllib.error.URLError as e:
        print(f"ERROR: Network error: {e.reason}", file=sys.stderr)
        sys.exit(1)
    
    if not data.get("success") or data.get("code") != 200:
        print(f"ERROR: API error: {data.get('msg', 'Unknown')}", file=sys.stderr)
        sys.exit(1)
    
    return data


def format_tokens(count):
    """Format token count as human-readable string."""
    if count >= 1_000_000:
        return f"{count / 1_000_000:.1f}M"
    elif count >= 1_000:
        return f"{count / 1_000:.0f}K"
    return str(count)


def progress_bar(percentage, width=30):
    """Create a visual progress bar."""
    filled = int(width * percentage / 100)
    empty = width - filled
    
    if percentage >= 95:
        bar_char = "█"
        color = "\033[91m"  # Red
    elif percentage >= 80:
        bar_char = "█"
        color = "\033[93m"  # Yellow
    else:
        bar_char = "█"
        color = "\033[92m"  # Green
    
    reset = "\033[0m"
    return f"{color}{bar_char * filled}{'░' * empty}{reset}"


def get_current_model():
    """Read current model from Hermes config.yaml."""
    config_path = Path.home() / "AppData" / "Local" / "hermes" / "config.yaml"
    if not config_path.exists():
        return None
    import re
    content = config_path.read_text(encoding="utf-8")
    match = re.search(r"^\s*default:\s*(.+)$", content, re.MULTILINE)
    if match:
        return match.group(1).strip()
    return None


GLM_MODELS = {
    "glm-4.7-flash":  {"tier": 0, "cost": "FREE", "desc": "Best free model"},
    "glm-4.5-flash":  {"tier": 0, "cost": "FREE", "desc": "Older free model"},
    "glm-4.7-flashx": {"tier": 1, "cost": "$0.07/$0.40/M", "desc": "Fast & cheap"},
    "glm-4.5-air":    {"tier": 2, "cost": "$0.20/$1.10/M", "desc": "Balanced"},
    "glm-4.7":        {"tier": 3, "cost": "$0.60/$2.20/M", "desc": "High quality"},
    "glm-5.1":        {"tier": 4, "cost": "$1.40/$4.40/M", "desc": "Best GLM"},
}


def print_quota(data, json_output=False):
    """Print formatted quota information."""
    if json_output:
        print(json.dumps(data, indent=2))
        return
    
    limits = data.get("data", {}).get("limits", [])
    
    if not limits:
        print("No quota data available.")
        return
    
    now_sofia = sofia_now()
    print(f"{'=' * 50}")
    print(f"  Z.AI / GLM Token Usage Monitor")
    print(f"  Sofia time: {now_sofia.strftime('%Y-%m-%d %H:%M:%S')}")
    print(f"{'=' * 50}")
    
    max_percentage = 0
    should_warn = False
    
    for limit in limits:
        limit_type = limit.get("type", "")
        percentage = limit.get("percentage", 0)
        next_reset = limit.get("nextResetTime")
        
        max_percentage = max(max_percentage, percentage)
        
        if limit_type == "TOKENS_LIMIT":
            usage_total = limit.get("usage", 0)
            current = limit.get("currentValue", 0)
            remaining_pct = 100 - percentage
            
            print(f"\n  📊 Token Quota (5-hour window)")
            print(f"  {progress_bar(percentage)} {percentage}% used")
            
            if usage_total and current:
                print(f"  Used:     {format_tokens(current)} tokens")
                print(f"  Total:    {format_tokens(usage_total)} tokens")
                print(f"  Remaining: {format_tokens(max(0, usage_total - current))} tokens ({remaining_pct:.0f}%)")
            else:
                print(f"  Remaining: {remaining_pct:.0f}%")
            
            if next_reset:
                reset_dt = datetime.fromtimestamp(next_reset / 1000, tz=timezone.utc)
                delta = reset_dt - datetime.now(timezone.utc)
                if delta.total_seconds() > 0:
                    hours = int(delta.total_seconds() // 3600)
                    mins = int((delta.total_seconds() % 3600) // 60)
                    reset_sofia = reset_dt.astimezone(timezone(timedelta(hours=get_sofia_offset())))
                    print(f"  Resets in: {hours}h {mins}m (at {reset_sofia.strftime('%H:%M')} Sofia time)")
            
            if percentage >= 95:
                should_warn = True
                print(f"\n  ⚠️  CRITICAL: Token usage at {percentage:.1f}%!")
                print(f"  ⚠️  Consider switching to a free model (GLM-4.7-Flash)")
            elif percentage >= 80:
                print(f"\n  ⚡ Warning: Token usage at {percentage:.1f}%")
        
        elif limit_type == "TIME_LIMIT":
            usage_total = limit.get("usage", 0)
            current = limit.get("currentValue", 0)
            remaining = usage_total - current
            print(f"\n  🔍 MCP Search Limit")
            print(f"  Used: {current} / {usage_total} ({remaining} remaining)")
    
    print(f"\n{'=' * 50}")
    
    return max_percentage


def print_cron_summary(data):
    """Print a compact cron-friendly summary with actionable info."""
    limits = data.get("data", {}).get("limits", [])
    if not limits:
        print("No quota data available.")
        return 0
    
    for limit in limits:
        if limit.get("type") != "TOKENS_LIMIT":
            continue
        
        percentage = limit.get("percentage", 0)
        usage_total = limit.get("usage", 0)
        current = limit.get("currentValue", 0)
        next_reset = limit.get("nextResetTime")
        
        # Build usage detail string (API may or may not include usage/currentValue)
        if usage_total and current:
            remaining = max(0, usage_total - current)
            detail = f"({format_tokens(remaining)} remaining of {format_tokens(usage_total)})"
        else:
            detail = f"({100 - percentage:.0f}% remaining)"
        
        # Reset time in Sofia
        reset_str = "unknown"
        if next_reset:
            reset_dt = datetime.fromtimestamp(next_reset / 1000, tz=timezone.utc)
            delta = reset_dt - datetime.now(timezone.utc)
            reset_sofia = reset_dt.astimezone(timezone(timedelta(hours=get_sofia_offset())))
            if delta.total_seconds() > 0:
                hours = int(delta.total_seconds() // 3600)
                mins = int((delta.total_seconds() % 3600) // 60)
                reset_str = f"{hours}h {mins}m (at {reset_sofia.strftime('%H:%M')} Sofia time)"
            else:
                reset_str = f"imminent ({reset_sofia.strftime('%H:%M')} Sofia time)"
        
        # Current model info
        current_model = get_current_model()
        model_info = GLM_MODELS.get(current_model, {}) if current_model else {}
        model_tier = model_info.get("tier", "?")
        model_cost = model_info.get("cost", "unknown")
        
        # Determine emoji based on usage
        if percentage >= 95:
            emoji = "🔴"
        elif percentage >= 80:
            emoji = "🟡"
        elif percentage >= 60:
            emoji = "🟠"
        else:
            emoji = "🟢"
        
        print(f"{emoji} Z.AI Token Usage: {percentage}% used {detail}")
        print(f"🕐 Resets in: {reset_str}")
        print(f"📋 Current model: `{current_model or 'unknown'}` (Tier {model_tier}, {model_cost})")
        
        if percentage >= 95:
            print()
            print("⚠️ **CRITICAL** — Quota almost exhausted!")
            print()
            print("To switch to a free model:")
            print('1. Send: `switch glm-4.7-flash`')
            print("2. Then send: `/reset`")
            print("This switches to GLM-4.7-Flash (FREE, Tier 0)")
        elif percentage >= 80:
            print()
            print("⚡ Usage is high. Consider switching to a lower tier:")
            print('`switch glm-4.7-flash` (FREE) then `/reset`')
        elif percentage >= 60:
            print()
            print("💡 Usage moderate. If it rises, switch to `glm-4.7-flash` (FREE)")
        
        return percentage
    
    return 0


def main():
    json_output = "--json" in sys.argv
    cron_mode = "--cron" in sys.argv
    warn_threshold = None
    for i, arg in enumerate(sys.argv):
        if arg == "--warn" and i + 1 < len(sys.argv):
            warn_threshold = float(sys.argv[i + 1])
    
    api_key = load_api_key()
    data = fetch_quota(api_key)
    
    if cron_mode:
        max_pct = print_cron_summary(data)
    else:
        max_pct = print_quota(data, json_output=json_output)
    
    # Exit with code 1 if above threshold (for script/cron use)
    if warn_threshold is not None and max_pct is not None:
        if max_pct >= warn_threshold:
            sys.exit(1)
    
    sys.exit(0)


if __name__ == "__main__":
    main()
