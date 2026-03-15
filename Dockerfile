# ──────────────────────────────────────────────────────────────
# Geonara — Single-Container Dockerfile for Railway / Render / Fly.io
# Runs both FastAPI backend and Next.js frontend in one container.
# ──────────────────────────────────────────────────────────────

# ── Stage 1: Build the Next.js frontend ──
FROM node:20-alpine AS frontend-builder
WORKDIR /app/frontend
COPY frontend/package*.json ./
RUN npm ci
COPY frontend/ .
ENV NEXT_TELEMETRY_DISABLED=1
ARG NEXT_PUBLIC_API_URL=""
ENV NEXT_PUBLIC_API_URL=$NEXT_PUBLIC_API_URL
RUN npm run build

# ── Stage 2: Final runtime image ──
FROM python:3.10-slim-bookworm

WORKDIR /app

# Install Node.js 20 and supervisord
RUN apt-get update && apt-get install -y --no-install-recommends \
        curl supervisor \
    && curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get install -y --no-install-recommends nodejs \
    && rm -rf /var/lib/apt/lists/*

# ── Backend setup ──
WORKDIR /app/backend
COPY backend/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt \
    && playwright install --with-deps chromium

COPY backend/package*.json ./
RUN npm ci --omit=dev

COPY backend/ .

# ── Frontend setup — copy standalone build from Stage 1 ──
WORKDIR /app/frontend
COPY --from=frontend-builder /app/frontend/public ./public
COPY --from=frontend-builder /app/frontend/.next/standalone ./
COPY --from=frontend-builder /app/frontend/.next/static ./.next/static

# ── Supervisor config — runs both processes ──
WORKDIR /app
# Startup script — handles PORT properly at runtime
COPY <<'SCRIPT' /app/start.sh
#!/bin/sh
set -e
export PORT="${PORT:-3000}"
export BACKEND_URL="http://localhost:8000"
echo "[Geonara] Starting backend on :8000 and frontend on :${PORT}"
supervisord -c /etc/supervisor/conf.d/geonara.conf
SCRIPT
RUN chmod +x /app/start.sh

COPY <<'EOF' /etc/supervisor/conf.d/geonara.conf
[supervisord]
nodaemon=true
user=root
logfile=/dev/stdout
logfile_maxbytes=0
pidfile=/tmp/supervisord.pid

[program:backend]
command=uvicorn main:app --host 0.0.0.0 --port 8000
directory=/app/backend
autostart=true
autorestart=true
startretries=3
startsecs=10
stdout_logfile=/dev/stdout
stdout_logfile_maxbytes=0
stderr_logfile=/dev/stderr
stderr_logfile_maxbytes=0

[program:frontend]
command=node server.js
directory=/app/frontend
autostart=true
autorestart=true
startretries=3
startsecs=5
environment=HOSTNAME="0.0.0.0",BACKEND_URL="http://localhost:8000"
stdout_logfile=/dev/stdout
stdout_logfile_maxbytes=0
stderr_logfile=/dev/stderr
stderr_logfile_maxbytes=0
EOF

# Railway/Render/Fly.io inject PORT — frontend listens on it, backend on 8000 internally
ENV PORT=3000

EXPOSE ${PORT}

HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:8000/api/live-data/fast && curl -f http://localhost:${PORT}/ || exit 1

CMD ["/app/start.sh"]
