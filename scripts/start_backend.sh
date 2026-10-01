#!/bin/bash
# Start manusletgo123 FastAPI backend on :3000 (Caddy :81 default -> 3000)
LOGDIR=/home/z/my-project/logs
# stop previous instances of THIS backend only (port-specific!)
# JANGAN pakai pola "uvicorn app.main:app" — itu juga membunuh sandbox API :8080
pkill -f "uvicorn app.main:app --host 0.0.0.0 --port 3000" 2>/dev/null
pkill -f "next dev" 2>/dev/null
pkill -f "bun run dev" 2>/dev/null
sleep 2
cd /home/z/my-project/manusletgo123/backend
echo "===== restart $(date '+%F %T') =====" >> "$LOGDIR/backend.log"
nohup /home/z/.venv/bin/python -m uvicorn app.main:app --host 0.0.0.0 --port 3000 >> "$LOGDIR/backend.log" 2>&1 &
sleep 8
echo "=== backend health (direct) ==="
curl -s --max-time 5 http://localhost:3000/health; echo
echo "=== via caddy :81 ==="
curl -s --max-time 5 http://localhost:81/api/v1/health; echo
curl -s --max-time 5 http://localhost:81/ | head -c 120; echo
echo "=== log tail ==="
tail -6 "$LOGDIR/backend.log"
