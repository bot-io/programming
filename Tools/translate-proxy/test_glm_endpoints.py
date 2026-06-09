import json, subprocess, os

env_path = "C:/Users/Svetlin/AppData/Local/hermes/.env"
key = None
with open(env_path) as f:
    for line in f:
        if line.startswith("GLM_API_KEY="):
            key = line.split("=", 1)[1].strip()
            break

if not key:
    print("No GLM_API_KEY found")
    exit(1)

print(f"Key: {key[:8]}...{key[-4:]} (len={len(key)})")

payload = json.dumps({
    "model": "glm-4.7-flash",
    "messages": [{"role": "user", "content": "Say hi in Spanish"}],
    "max_tokens": 50
})

endpoints = [
    ("Z.AI coding", "https://api.z.ai/api/coding/paas/v4/chat/completions"),
    ("Z.AI paas", "https://api.z.ai/api/paas/v4/chat/completions"),
    ("BigModel direct", "https://open.bigmodel.cn/api/paas/v4/chat/completions"),
]

for name, url in endpoints:
    print(f"\n--- {name}: {url}")
    try:
        result = subprocess.run(
            ["curl", "-s", "-w", "\nHTTP_CODE: %{http_code}\nTIME: %{time_total}s\n",
             "-X", "POST", url,
             "-H", "Content-Type: application/json",
             "-H", f"Authorization: Bearer {key}",
             "-d", payload,
             "--connect-timeout", "5", "--max-time", "15"],
            capture_output=True, text=True, timeout=20
        )
        out = result.stdout
        print(out[-400:] if len(out) > 400 else out)
    except Exception as e:
        print(f"Error: {e}")
