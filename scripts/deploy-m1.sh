#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
target="${1:-m1}"
[[ "$target" =~ ^[a-zA-Z0-9_.@-]+$ ]] || { echo 'Invalid SSH target'; exit 1; }
flutter pub get
flutter analyze
(cd worker && npm ci --ignore-scripts && npm run check)
flutter build web --release --no-web-resources-cdn
ssh "$target" 'mkdir -p ~/apps/ai/mate'
rsync -az --exclude=.git --exclude=.env --exclude=.secrets --exclude=node_modules --exclude=.dart_tool \
  --exclude=AGENTS.md ./ "$target:apps/ai/mate/"
ssh "$target" 'export PATH=/opt/homebrew/bin:/usr/local/bin:$PATH; cd ~/apps/ai/mate; python3 scripts/configure.py --codex-auth; docker build -t mate-agent:0.1.0 agent && docker compose up -d --build --wait && python3 scripts/install-autostart.py && docker compose ps'
mkdir -p .secrets
chmod 700 .secrets
scp "$target:apps/ai/mate/.secrets/access.txt" .secrets/access.txt
chmod 600 .secrets/access.txt
echo 'M1 배포 완료. 개인 접속 주소: .secrets/access.txt'
