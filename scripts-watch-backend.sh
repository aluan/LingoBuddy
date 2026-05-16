#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"
while true; do
  if ! curl -fsS --max-time 2 http://127.0.0.1:3000/video-learning/list >/dev/null; then
    echo "[$(date)] backend down; restarting" >> build/backend-watch.log
    ./scripts-start-backend.sh >> build/backend-watch.log 2>&1 || true
  fi
  sleep 5
done
