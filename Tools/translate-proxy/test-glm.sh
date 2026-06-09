#!/bin/bash
GLM_KEY=$(grep "^GLM_API_KEY=" /c/Users/Svetlin/AppData/Local/hermes/.env | cut -d= -f2)
curl -s -w "\nHTTP_CODE: %{http_code}\nTIME: %{time_total}s\n" \
  -X POST "https://api.z.ai/api/paas/v4/chat/completions" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${GLM_KEY}" \
  -d '{"model":"glm-4.7-flash","messages":[{"role":"user","content":"Say hi in Spanish"}],"max_tokens":50}' \
  --connect-timeout 5 --max-time 15
