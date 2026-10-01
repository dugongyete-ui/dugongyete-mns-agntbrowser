#!/bin/bash
# Sandbox stack for manusletgo123 on z.ai sandbox (no root, no Docker)
# Components: Xvfb :1 | Chrome CDP :8222 | x11vnc :5900 | websockify :5901 | sandbox API :8080
LOGDIR=/home/z/my-project/logs
mkdir -p "$LOGDIR" /home/z/runner/users
export LD_LIBRARY_PATH=/home/z/sandbox-opt/usr/lib/x86_64-linux-gnu:${LD_LIBRARY_PATH:-}
CHROME=/home/z/.agent-browser/browsers/chrome-154.0.8037.92/chrome

# 0. stop previous instances (idempotent restart)
pkill -f "Xvfb :1" 2>/dev/null
pkill -f "remote-debugging-port=8222" 2>/dev/null
pkill -f "x11vnc -display :1" 2>/dev/null
pkill -f "websockify 0.0.0.0:5901" 2>/dev/null
pkill -f "uvicorn app.main:app --host 0.0.0.0 --port 8080" 2>/dev/null
sleep 1
rm -f /tmp/.X1-lock

# 1. Xvfb (virtual display)
nohup Xvfb :1 -screen 0 1280x1029x24 -nolisten tcp > "$LOGDIR/xvfb.log" 2>&1 &
sleep 2

# 2. Chrome for Testing with CDP on :8222
nohup env DISPLAY=:1 "$CHROME" \
  --user-data-dir=/home/z/.sandbox-chrome-profile \
  --window-size=1280,1029 --window-position=0,0 --start-maximized \
  --no-sandbox --disable-dev-shm-usage --disable-setuid-sandbox \
  --disable-accelerated-2d-canvas --disable-gpu \
  --disable-features=WelcomeExperience,SigninPromo \
  --no-first-run --no-default-browser-check --disable-infobars --test-type \
  --disable-popup-blocking --disable-gpu-sandbox --no-xshm \
  --disable-notifications --disable-extensions \
  --disable-component-extensions-with-background-pages \
  --disable-prompt-on-repost --disable-dialogs --disable-modal-dialogs \
  --disable-web-security --disable-site-isolation-trials \
  --remote-debugging-port=8222 \
  --disable-crash-reporter --metrics-recording-only \
  about:blank > "$LOGDIR/chrome.log" 2>&1 &
sleep 3

# 3. x11vnc (VNC server on X display :1)
nohup /home/z/sandbox-opt/usr/bin/x11vnc -display :1 -nopw -shared -listen 0.0.0.0 -xkb -forever -rfbport 5900 > "$LOGDIR/x11vnc.log" 2>&1 &

# 4. websockify (VNC websocket bridge 5901 -> 5900)
nohup /home/z/.venv/bin/websockify 0.0.0.0:5901 localhost:5900 > "$LOGDIR/websockify.log" 2>&1 &

# 5. Sandbox API service (:8080)
cd /home/z/my-project/manusletgo123/sandbox
nohup env SANDBOX_STANDALONE=1 PROTECTED_PATHS=/home/z/my-project/manusletgo123 LOG_LEVEL=INFO \
  /home/z/.venv/bin/python -m uvicorn app.main:app --host 0.0.0.0 --port 8080 > "$LOGDIR/sandbox-api.log" 2>&1 &

sleep 3
echo "=== listening ports ==="
ss -tln | rg "8080|8222|5900|5901" || echo "PORTS MISSING"
echo "=== supervisor status (backend handshake) ==="
curl -s --max-time 5 http://localhost:8080/api/v1/supervisor/status | head -c 300; echo
echo "=== CDP check ==="
curl -s --max-time 5 http://localhost:8222/json/version | head -c 300; echo
