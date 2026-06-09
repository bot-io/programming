import subprocess, os

env_path = "C:/Users/Svetlin/AppData/Local/hermes/.env"
key = None
with open(env_path) as f:
    for line in f:
        stripped = line.strip()
        if stripped.startswith("GLM_API_KEY=") and len(stripped) > 12:
            key = stripped.split("=", 1)[1].strip()
            break

if key:
    print(key)
else:
    print("ERROR: no key found")
    exit(1)
