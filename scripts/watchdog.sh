#!/bin/bash
# Self-healing watchdog for the Manus agent-browser stack.
# Cek tiap 10 detik: Chrome CDP :8222, sandbox API :8080.
# Yang TIDAK disentuh: backend :3000 (punya skrip start sendiri).
LOGDIR=/home/z/my-project/logs
LOG=$LOGDIR/watchdog.log
export LD_LIBRARY_PATH=/home/z/sandbox-opt/usr/lib/x86_64-linux-gnu:${LD_LIBRARY_PATH:-}
CHROME=/home/z/.agent-browser/browsers/chrome-154.0.8037.92/chrome

start_chrome() {
  pkill -f "remote-debugging-port=8222" 2>/dev/null
  sleep 1
  rm -f /tmp/.X1-lock 2>/dev/null
  # Xvfb dulu kalau mati
  if ! pgrep -f "Xvfb :1" > /dev/null; then
    nohup Xvfb :1 -screen 0 1280x1029x24 -nolisten tcp > "$LOGDIR/xvfb.log" 2>&1 &
    sleep 2
  fi
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
  echo "$(date '+%F %T') Chrome restarted" >> "$LOG"
}

start_sandbox_api() {
  cd /home/z/my-project/manusletgo123/sandbox
  nohup env SANDBOX_STANDALONE=1 PROTECTED_PATHS=/home/z/my-project/manusletgo123 LOG_LEVEL=INFO \
    /home/z/.venv/bin/python -m uvicorn app.main:app --host 0.0.0.0 --port 8080 >> "$LOGDIR/sandbox-api.log" 2>&1 &
  cd /home/z/my-project
  echo "$(date '+%F %T') sandbox API restarted" >> "$LOG"
}

echo "$(date '+%F %T') watchdog started (pid $$)" >> "$LOG"
while true; do
  sleep 10
  curl -s --max-time 3 http://localhost:8222/json/version > /dev/null 2>&1 || start_chrome
  curl -s --max-time 3 http://localhost:8080/api/v1/supervisor/status > /dev/null 2>&1 || start_sandbox_api
  # VNC bridges (x11vnc + websockify) — best effort
  pgrep -f "x11vnc -display :1" > /dev/null || \
    nohup /home/z/sandbox-opt/usr/bin/x11vnc -display :1 -nopw -shared -listen 0.0.0.0 -xkb -forever -rfbport 5900 >> "$LOGDIR/x11vnc.log" 2>&1 &
  pgrep -f "websockify 0.0.0.0:5901" > /dev/null || \
    nohup /home/z/.venv/bin/websockify 0.0.0.0:5901 localhost:5900 >> "$LOGDIR/websockify.log" 2>&1 &
done
