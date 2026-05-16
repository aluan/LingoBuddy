#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

docker compose up -d mongodb redis >/dev/null

if lsof -nP -iTCP:3000 -sTCP:LISTEN >/dev/null 2>&1; then
  echo "Backend already listening on :3000"
  lsof -nP -iTCP:3000 -sTCP:LISTEN
  exit 0
fi

mkdir -p build
cd backend
npm run build >/dev/null
cd "$ROOT"

# Run compiled Nest app directly. This is more stable than backgrounding `npm run start`.
nohup node "$ROOT/backend/dist/main.js" > "$ROOT/build/backend.log" 2>&1 < /dev/null &
echo $! > "$ROOT/build/backend.pid"

for i in {1..20}; do
  if curl -fsS --max-time 2 http://127.0.0.1:3000/video-learning/list >/dev/null; then
    echo "Backend started on http://127.0.0.1:3000"
    echo "LAN: http://$(ipconfig getifaddr en0 2>/dev/null || echo 192.168.3.17):3000"
    lsof -nP -iTCP:3000 -sTCP:LISTEN
    exit 0
  fi
  sleep 1
done

echo "Backend failed to start. Last log lines:" >&2
tail -120 "$ROOT/build/backend.log" >&2
exit 1
