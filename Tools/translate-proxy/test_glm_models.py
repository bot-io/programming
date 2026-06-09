import json, subprocess, os

env_path = "C:/Users/Svetlin/AppData/Local/hermes/.env"
key = None
with open(env_path) as f:
    for line in f:
        stripped = line.strip()
        if stripped.startswith("GLM_API_KEY=") and len(stripped) > 12:
            key = stripped.split("=", 1)[1].strip()
            break

if not key:
    print("ERROR: No key found")
    exit(1)

print(f"Key: {key[:8]}...{key[-4:]}")

models = ["glm-4.7-flash", "glm-4-flash", "glm-4.7-flashx"]
base = "https://open.bigmodel.cn/api/paas/v4/chat/completions"

for model in models:
    payload = json.dumps({
        "model": model,
        "messages": [{"role": "user", "content": "Say hi in Spanish, one sentence only"}],
        "max_tokens": 50
    })
    print(f"\n--- Model: {model}")
    try:
        result = subprocess.run(
            ["curl", "-s", "-w",
             "\nHTTP_CODE: %{http_code}\nTIME: %{time_total}s\n",
             "-X", "POST", base,
             "-H", "Content-Type: application/json",
             "-H", "Authorization: Bearer " + str(key),
             "-d", payload,
             "--connect-timeout", "5", "--max-time", "15"],
            capture_output=True, text=True, timeout=20
        )
        out = result.stdout or "(empty)"
        print(out[-500:])
    except Exception as e:
        print(f"Error: {e}")
