# Manus Agent Browser

Frontend **Manus UI asli** (Vue 3, tidak diubah) + **backend agent FastAPI** (LangChain) yang menjalankan browser sungguhan lewat CDP + live VNC.

Yang digunakan dalam proyek ini hanya 3 bagian inti:

```
├── backend/     FastAPI agent (LangChain + NVIDIA NIM, MongoDB, Redis, Tavily)
│   └── frontend -> symlink ../frontend (dist Manus disajikan langsung oleh FastAPI)
├── frontend/    Manus UI asli (Vue 3 + Vite, dist sudah ter-build, tidak dimodifikasi)
├── sandbox/     Service supervisor: Xvfb + Chrome (CDP) + x11vnc + websockify
└── scripts/     Skrip menjalankan stack & test E2E
```

## Arsitektur

- **Agent loop**: plan → step → tool calls (`browser_*`, search, file) → validation → jawaban final, mengalir ke UI lewat **SSE** (format event Manus asli: `message_chunk`, `plan`, `step`, `tool`, `validation`, `done`).
- **Browser**: Chrome for Testing dijalankan pada Xvfb `:1`, dikendalikan agent via **CDP** (`:8222`), dan bisa dipantau langsung dari UI Manus (panel komputer + *Jump to live*) melalui **VNC** (`:5900` → WebSocket `:5901` diproxy backend).
- **Auth**: JWT (register/login password).
- **Penyimpanan**: MongoDB Atlas (sesi & pesan) + Redis Labs (queue/cache).

## Port

| Port | Layanan |
|------|---------|
| 81   | Gateway → backend |
| 3000 | Backend FastAPI (API + frontend Manus + proxy VNC) |
| 8080 | Sandbox API (standalone) |
| 8222 | Chrome CDP |
| 5900/5901 | x11vnc / websockify (VNC) |

## Menjalankan

```bash
# 1. Dependensi Python (venv)
uv venv ~/.venv && source ~/.venv/bin/activate
uv pip install -e backend
pip install websockify dnspython

# 2. Konfigurasi
cp backend/.env.example backend/.env   # lalu isi kunci Anda

# 3. Jalankan
bash scripts/start_sandbox_stack.sh    # Xvfb + Chrome CDP + VNC + sandbox API :8080
bash scripts/start_backend.sh          # backend :3000 (melayani UI Manus di /)

# 4. (Opsional tapi disarankan) Watchdog self-healing —
#    auto-restart Chrome CDP / sandbox API / VNC jika ada yang mati,
#    sehingga task agent tidak macet:
setsid nohup bash scripts/watchdog.sh > /dev/null 2>&1 &
```

Buka UI lewat gateway **port 81** (atau `http://localhost:3000`), daftar akun, lalu kirim task — agent akan menyusun rencana, memanggil tool browser (kartu tool bisa diklik untuk melihat komputer), dan menjawab secara streaming.

## Test E2E

```bash
python scripts/e2e_chat_test.py
```

Menguji: register → login → buat sesi → kirim task browser → verifikasi alur SSE lengkap (streaming jawaban, kartu tool, validasi, jawaban final).

## Konfigurasi (.env)

Lihat `backend/.env.example` — berisi semua variabel: `API_KEY`, `API_BASE`, `MODEL_NAME`, `VISION_*`, `MONGODB_*`, `REDIS_*`, `TAVILY_API_KEY`, `AUTH_PROVIDER`, `JWT_*`, `SANDBOX_*`.

> **Catatan**: `backend/.env` sengaja tidak di-commit (berisi kunci asli). Selalu isi `.env` secara lokal.

## Keamanan

- Jangan pernah commit kunci asli ke repo publik.
- Jika kunci pernah terekspos, rotasi di penyedianya (NVIDIA, MongoDB Atlas, Redis Labs, Tavily).
