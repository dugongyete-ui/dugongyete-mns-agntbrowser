#!/usr/bin/env python3
"""E2E test: register -> login -> create session -> chat SSE streaming."""
import json, sys, time, httpx

BASE = "http://localhost:3000/api/v1"
EMAIL = "zai-test@manus.local"
PASSWORD = "ManusTest2026!"
FULLNAME = "zai Tester"

c = httpx.Client(timeout=30)

# 1. register (ignore "already exists" error)
r = c.post(f"{BASE}/auth/register", json={"fullname": FULLNAME, "email": EMAIL, "password": PASSWORD})
print("REGISTER:", r.status_code, r.json().get("code"), r.json().get("msg", "")[:60])

# 2. login
r = c.post(f"{BASE}/auth/login", json={"email": EMAIL, "password": PASSWORD})
if r.json().get("code") != 0:
    print("LOGIN FAILED:", r.text[:300]); sys.exit(1)
data = r.json()["data"]
tok = data["access_token"]
print("LOGIN OK: user =", data["user"].get("email"), "| token len =", len(tok))
H = {"Authorization": f"Bearer {tok}"}

# 3. create session
r = c.put(f"{BASE}/sessions", json={"agent_profile_id": None}, headers=H)
if r.json().get("code") != 0:
    print("SESSION FAILED:", r.text[:300]); sys.exit(1)
sid = r.json()["data"]["session_id"]
print("SESSION OK:", sid)

# 4. chat via SSE
task = "Gunakan browser untuk membuka https://example.com lalu sebutkan judul halaman utamanya. Jawab singkat."
t0 = time.time()
n = 0
with c.stream("POST", f"{BASE}/sessions/{sid}/chat",
              json={"message": task, "timestamp": int(time.time()), "event_id": None, "attachments": None},
              headers=H, timeout=180) as resp:
    print("SSE HTTP:", resp.status_code)
    cur_event = None
    for line in resp.iter_lines():
        if line.startswith("event:"):
            cur_event = line[6:].strip()
        elif line.startswith("data:"):
            payload = line[5:].strip()
            n += 1
            el = time.time() - t0
            try:
                d = json.loads(payload)
            except Exception:
                d = payload[:120]
            # compact print
            if cur_event in ("message_chunk",):
                content = d.get("content", d) if isinstance(d, dict) else d
                print(f"[{el:6.1f}s] {cur_event}: {str(content)[:100]}")
            elif cur_event == "tool":
                st = d.get("status", "?") if isinstance(d, dict) else "?"
                tl = d.get("tool_name", d.get("name", "?")) if isinstance(d, dict) else "?"
                print(f"[{el:6.1f}s] tool: {tl} -> {st}")
            elif cur_event == "message":
                print(f"[{el:6.1f}s] message(first-response): {str(d)[:150]}")
            else:
                print(f"[{el:6.1f}s] {cur_event}: {str(d)[:150]}")
            if cur_event in ("done", "error", "fail"):
                break
        elif n == 0 and line.strip() == "" :
            pass
print(f"TOTAL EVENTS: {n} in {time.time()-t0:.1f}s")
