import json, subprocess, os

env_path = "C:/Users/Svetlin/AppData/Local/hermes/.env"
key = None
with open(env_path) as f:
    for line in f:
        stripped = line.strip()
        if stripped.startswith("GLM_API_KEY=") and not stripped.startswith("#") and len(stripped) > 12:
            key = stripped.split("=", 1)[1].strip()
            break

if not key:
    print("ERROR: no key")
    exit(1)

base = "https://api.z.ai/api/paas/v4/chat/completions"
payload = json.dumps({
    "model": "glm-4.7-flash",
    "messages": [{"role": "user", "content": "Say hi in Spanish"}],
    "max_tokens": 50
})

print("Testing: " + base)
print("Key prefix: " + key[:8])
auth_val = "Bearer " + key
result = subprocess.run(
    ["curl", "-s", "-w",
     "\nHTTP_CODE: %{http_code}\nTIME: %{time_total}s\n",
     "-X", "POST", base,
     "-H", "Content-Type: application/json",
     "-H", "Authorization: " + auth_val,
     "-d", payload,
     "--connect-timeout", "5", "--max-time", "15"],
    capture_output=True, text=True, timeout=20
)
print(result.stdout)
