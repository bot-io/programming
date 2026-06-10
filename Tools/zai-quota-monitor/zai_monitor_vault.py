#!/usr/bin/env python3
"""
Z.AI Usage Monitor -- Vault-Integrated Deterministic Script
Polls Z.AI quota API, writes to Obsidian vault, sends Telegram alerts.
Day (08-23): spare_capacity=true below 70%. Night: below 95%.
"""
import json, os, sys, csv, urllib.request, urllib.error
from datetime import datetime, timezone, timedelta
from pathlib import Path

VAULT = Path(r"D:\programming\docs")
HERMES = VAULT / "Hermes"
SUB_FILE = HERMES / "status" / "subscription.md"
CSV_FILE = HERMES / "status" / "usage-history.csv"
ALERT_FILE = HERMES / "status" / ".alert-state.json"

def sofia_offset():
    now = datetime.now(timezone.utc)
    y = now.year
    m31 = datetime(y, 3, 31)
    ml = m31 - timedelta(days=(m31.weekday()+1)%7)
    o31 = datetime(y, 10, 31)
    ol = o31 - timedelta(days=(o31.weekday()+1)%7)
    if ml.replace(hour=1) <= now.replace(tzinfo=None) < ol.replace(hour=1):
        return 3
    return 2

def sofia_now():
    return datetime.now(timezone(timedelta(hours=sofia_offset())))

def utc_to_sofia(dt):
    return dt.astimezone(timezone(timedelta(hours=sofia_offset())))

def _env(name):
    ep = Path.home() / "AppData" / "Local" / "hermes" / ".env"
    pf = name + "="
    if ep.exists():
        for line in ep.read_text(encoding="utf-8").splitlines():
            ls = line.strip()
            if ls.startswith(pf) and not ls.startswith("#"):
                v = ls.split("=", 1)[1].strip()
                if v: return v
    return os.environ.get(name, "")

def load_api_key():
    k = _env("GLM_API_KEY")
    if not k: print("ERROR: GLM_API_KEY not found", file=sys.stderr); sys.exit(1)
    return k

def load_tg():
    return _env("TELEGRAM_BOT_TOKEN"), _env("TELEGRAM_HOME_CHANNEL")

def fetch(api_key):
    url = "https://api.z.ai/api/monitor/usage/quota/limit"
    req = urllib.request.Request(url, method="GET")
    req.add_header("Authorization", api_key)
    req.add_header("Content-Type", "application/json")
    req.add_header("User-Agent", "Hermes-Monitor/2.0")
    try:
        with urllib.request.urlopen(req, timeout=10) as resp:
            data = json.loads(resp.read().decode("utf-8"))
    except (urllib.error.HTTPError, urllib.error.URLError) as e:
        print(f"ERROR: API failed: {e}", file=sys.stderr); sys.exit(1)
    if not data.get("success"):
        print(f"ERROR: {data.get('msg')}", file=sys.stderr); sys.exit(1)
    return data

def is_spare(pct, st):
    return pct < 70 if 8 <= st.hour < 23 else pct < 95

def write_sub(pct, rst, spare, st):
    SUB_FILE.parent.mkdir(parents=True, exist_ok=True)
    SUB_FILE.write_text(
        f"---\nupdated: {st.strftime('%Y-%m-%dT%H:%M:%S')} Sofia\nsource: zai-monitor\n---\n\n"
        f"# Z.AI Subscription Status\n\n"
        f"| Field | Value |\n|-------|-------|\n"
        f"| Window Usage | {pct}% |\n"
        f"| Spare Capacity | {'true' if spare else 'false'} |\n"
        f"| Next Reset | {rst} |\n"
        f"| Checked At | {st.strftime('%Y-%m-%d %H:%M')} Sofia time |\n",
        encoding="utf-8")

def append_csv(st, pct, rst, spare, alert):
    CSV_FILE.parent.mkdir(parents=True, exist_ok=True)
    new = not CSV_FILE.exists() or CSV_FILE.stat().st_size == 0
    with open(CSV_FILE, "a", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        if new: w.writerow(["timestamp","usage_pct","next_reset_sofia","spare_capacity","threshold_alert"])
        w.writerow([st.strftime("%Y-%m-%dT%H:%M:%S"), pct, rst, str(spare).lower(), alert or ""])

def load_alerts():
    if ALERT_FILE.exists():
        try: return json.loads(ALERT_FILE.read_text(encoding="utf-8"))
        except: pass
    return {"windows": {}}

def save_alerts(s):
    ALERT_FILE.parent.mkdir(parents=True, exist_ok=True)
    ALERT_FILE.write_text(json.dumps(s, indent=2), encoding="utf-8")

def send_tg(tok, cid, text):
    url = f"https://api.telegram.org/bot{tok}/sendMessage"
    body = json.dumps({"chat_id": cid, "text": text, "parse_mode": "Markdown"}).encode("utf-8")
    req = urllib.request.Request(url, data=body, method="POST")
    req.add_header("Content-Type", "application/json")
    try:
        with urllib.request.urlopen(req, timeout=10) as resp:
            r = json.loads(resp.read().decode("utf-8"))
            if not r.get("ok"): print(f"WARN: TG: {r}", file=sys.stderr)
    except Exception as e:
        print(f"WARN: TG failed: {e}", file=sys.stderr)

def check_alert(pct, rms, state, tok, cid):
    wid = str(rms) if rms else "unknown"
    aw = state.get("windows", {})
    hi = None
    if pct >= 95 and aw.get(wid) != "95": hi = "95"
    elif pct >= 80 and aw.get(wid) not in ("80","95"): hi = "80"
    if not hi: return None
    if tok and cid:
        em = "🔴" if hi == "95" else "🟡"
        msg = f"{em} Z.AI Usage Alert: {pct}% used\nThreshold: {hi}%\n"
        if rms:
            rd = utc_to_sofia(datetime.fromtimestamp(rms/1000, tz=timezone.utc))
            d = rd - sofia_now()
            if d.total_seconds() > 0:
                msg += f"Resets in: {int(d.total_seconds()//3600)}h {int((d.total_seconds()%3600)//60)}m (at {rd.strftime('%H:%M')} Sofia)\n"
        if hi == "95":
            msg += "\nSwitch to free: `switch glm-4.7-flash` then `/reset`"
        else:
            msg += "\nConsider: `switch glm-4.7-flash` (FREE)"
        send_tg(tok, cid, msg)
    aw[wid] = hi
    if len(aw) > 3:
        for k in sorted(aw.keys())[:-3]: del aw[k]
    state["windows"] = aw
    save_alerts(state)
    return hi

def main():
    test = "--test" in sys.argv
    ak = load_api_key()
    tok, cid = load_tg()
    data = fetch(ak)
    pct, rms = 0, None
    for lim in data.get("data",{}).get("limits",[]):
        if lim.get("type") == "TOKENS_LIMIT":
            pct = lim.get("percentage", 0)
            rms = lim.get("nextResetTime"); break
    st = sofia_now()
    rs = "unknown"
    if rms:
        rd = utc_to_sofia(datetime.fromtimestamp(rms/1000, tz=timezone.utc))
        rs = rd.strftime("%Y-%m-%d %H:%M") + " Sofia"
    spare = is_spare(pct, st)
    write_sub(pct, rs, spare, st)
    state = load_alerts()
    alert = None
    if test:
        if tok and cid:
            send_tg(tok, cid,
                "🧪 **Test Notification**\n\nZ.AI usage monitoring is working.\n"
                f"Current usage: {pct}%\nSpare capacity: {'true' if spare else 'false'}\n"
                f"Time: {st.strftime('%H:%M')} Sofia\n\n_Sent from vault-integrated monitor script_")
            print(f"Test notification sent to Telegram chat {cid}")
        else:
            print("ERROR: No TG config", file=sys.stderr); sys.exit(1)
    else:
        alert = check_alert(pct, rms, state, tok, cid)
    append_csv(st, pct, rs, spare, alert or "")
    if not test:
        print(f"Z.AI: {pct}% | spare: {spare} | reset: {rs}")
    # Refresh the live dashboard
    try:
        subprocess.run([sys.executable, r"C:\Users\Svetlin\AppData\Local\hermes\scripts\update-now-dashboard.py"], timeout=10)
    except Exception:
        pass

if __name__ == "__main__":
    main()
