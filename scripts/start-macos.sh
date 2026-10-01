#!/usr/bin/env bash
set -euo pipefail
export PATH=/opt/homebrew/bin:/usr/local/bin:/Applications/Docker.app/Contents/Resources/bin:/usr/bin:/bin:/usr/sbin:/sbin
cd "$(dirname "$0")/.."
open -a Docker
for attempt in $(seq 1 120); do
  if docker info >/dev/null 2>&1; then
    exec docker compose up -d
  fi
  sleep 5
done
echo 'Docker Desktop did not become ready within 10 minutes.' >&2
exit 1
