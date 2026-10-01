# Mate

Git 저장소: **https://github.com/thruthesky/mate**

개인용 AI 에이전트 작업 서버입니다. Flutter Web 콘솔, PHP API, MariaDB 기록 저장소, Node/TypeScript 실행 관리자와 작업별 Docker 컨테이너로 구성합니다.

브라우저에서 Codex 또는 데모 작업을 맡기고, 진행 기록·변경 코드·테스트 결과를 확인하며 같은 작업에 후속 요청을 보내거나 실행을 중단할 수 있습니다. 브라우저를 닫아도 서버가 실행 중이면 작업은 계속됩니다.

상세 기획은 [docs/PLAN.md](docs/PLAN.md), 운영 절차는 [docs/OPERATIONS.md](docs/OPERATIONS.md)를 확인하세요.

## 가장 쉬운 설치: AI 도구에 복사해서 요청하기

아래 **설치 프롬프트 전체**를 복사해서 터미널 명령을 실행할 수 있는 AI 도구에 붙여넣으세요. `[ ]` 항목에 설치 대상과 원하는 폴더를 적으면 AI가 해당 환경을 확인하고 설치를 진행할 수 있습니다. 일반 채팅만 가능한 AI는 명령을 안내하므로 사용자가 직접 실행해야 합니다.

개인 컴퓨터는 운영체제와 설치 위치를, VPS는 **원격 접속 정보**도 함께 알려 주세요. VPS 접속에는 서버 IP 또는 호스트명, SSH 사용자명, SSH 포트, SSH 키 파일 경로 또는 비밀번호 인증 여부, sudo 사용 가능 여부가 필요합니다. 비밀번호는 접속 시 직접 입력하고, SSH 개인키·Codex 인증 파일의 내용은 프롬프트에 붙여넣지 마세요.

빈 항목은 AI가 필요한 정보만 질문하도록 했습니다. 로컬 기본 위치는 `~/apps/ai/mate`, 기본 접속은 `http://127.0.0.1:8787`입니다. VPS도 같은 폴더에 설치할 수 있으며, 처음에는 SSH 터널로 접속하면 도메인이 없어도 사용할 수 있습니다.

### 복사용 설치 프롬프트

```text
Git 저장소: https://github.com/thruthesky/mate

Mate를 아래 대상의 Docker에 실제로 설치해 주세요.
Mate는 개인용 AI 에이전트 작업 서버입니다. 웹에서 Codex/데모 작업을
실행하고, 진행 기록·코드 diff·테스트 결과 확인, 후속 요청, 중단을 지원합니다.
현재는 내장 샘플 프로젝트를 사용하는 단일 사용자 검증 버전입니다.

[내 설치 정보]
- 설치 대상: [현재 개인 컴퓨터 / 개인 VPS]
- 대상 운영체제: [Windows / Linux 배포판·버전 / macOS / 모르면 확인]
- 원하는 설치 폴더: [예: ~/apps/ai/mate 또는 /opt/mate, 비우면 ~/apps/ai/mate]
- 접속 방식: [기본: 로컬 또는 SSH 터널 / 별도 도메인과 HTTPS]
- 사용할 에이전트: [기본: 인증 없이 데모 먼저 / Codex도 연결]
- 원하는 웹 포트: [기본: 8787]

[VPS에 설치할 때 추가할 원격 접속 정보 — 로컬 설치면 생략]
- 서버 IP 또는 호스트명: [예: vps.example.com]
- SSH 사용자명: [예: ubuntu]
- SSH 포트: [기본: 22]
- SSH 인증: [기존 SSH 별칭 / 내 컴퓨터의 키 파일 경로 / 비밀번호 직접 입력]
- SSH 별칭 또는 키 파일 경로: [예: my-vps 또는 ~/.ssh/id_ed25519]
- sudo 권한: [가능 / 불가능 / 확인 필요]
- 도메인: [없음 / 사용할 도메인 — HTTPS 접속을 원할 때]
비밀번호·개인키·API 키·인증 JSON 내용은 채팅에 요구하지 말고,
필요하면 내가 로컬 터미널에서 입력하거나 안전한 파일로 제공하게 해 주세요.

[실행 지침]
1. 설명으로 끝내지 말고 명령을 실행해 설치와 검증까지 완료해 주세요.
   빈 정보 중 꼭 필요한 것만 물어보고, 대상 OS·CPU·메모리·디스크,
   Docker 실행 상태와 설치 폴더/포트 충돌부터 확인해 주세요.
   VPS를 선택했다면 SSH로 대상 서버에서 설치하세요.
2. 저장소를 원하는 폴더로 clone하고 README.md, compose.yaml,
   .env.example, scripts/configure.py와 docs/OPERATIONS.md를 읽으세요.
   기존 폴더가 있으면 내용과 Git 상태를 먼저 확인하고 덮어쓰지 마세요.
   scripts/deploy-m1.sh의 m1 SSH 별칭·고정 경로·호스트명을
   일반 PC나 VPS에 그대로 적용하지 마세요.
3. OS에 맞게 의존성을 준비하세요.
   - Windows: WSL2 Ubuntu와 Docker Desktop의 Linux 컨테이너를 사용하고,
     해당 Ubuntu에 WSL Integration을 켜세요. 이후 명령은 Ubuntu에서
     실행하고, 저장소는 /mnt/c 대신 WSL 홈의 원하는 폴더에 두세요.
   - macOS: CPU에 맞는 Docker Desktop을 설치하고 실행하세요.
   - Linux/VPS: 배포판에 맞는 Docker Engine과 Compose 플러그인을
     설치하고 Docker 데몬을 시작하세요.
   Git, Python 3, Flutter SDK(Dart >=3.10.0, <4.0.0)를 준비하세요.
   Flutter는 설치 위치에서 웹을 빌드할 때 필요합니다. VPS에 Flutter를
   두기 어려우면 로컬에서 빌드한 build/web을 서버에 안전하게 전송하세요.
   PHP·MariaDB·Node 런타임은 Docker 이미지 안에 있으므로 호스트 설치는
   필수가 아닙니다. 호스트에서 Codex CLI를 설치할 때만 Node/npm도 준비하세요.
   Docker·Flutter의 공식 설치 문서를 사용하고 기존 서비스는 보존하세요.
4. 저장소 루트에서 flutter pub get과
   flutter build web --release --no-web-resources-cdn을 실행하세요.
   build/web/index.html이 있어야 합니다.
   python3 scripts/configure.py --host 127.0.0.1로 무작위 비밀값을 만드세요.
   이 스크립트는 기존 .env를 재생성하지 않으므로 재설치 때 값을 보존하고,
   새 설치에서는 replace-with-로 시작하는 예시 비밀값이 없는지 확인하세요.
   .env.example은 MATE_BIND=0.0.0.0이므로 .env에서 반드시
   MATE_BIND=127.0.0.1로 변경하세요. 원하는 MATE_PORT를 반영하고
   configure.py를 다시 실행해 .secrets/access.txt의 포트를 갱신하세요.
   동시에 실행할 작업 수·CPU·메모리·시간 한도를 장비에 맞게 설정하세요.
5. docker build -t mate-agent:0.1.0 agent를 먼저 실행한 뒤,
   docker compose up -d --build --wait로 서비스를 시작하세요.
   Compose는 작업용 mate-agent 이미지를 자동으로 빌드하지 않습니다.
   Compose 프로젝트 이름 mate와 작업 이미지 태그가 고정되어 있으므로
   기본 구성은 Docker 엔진 하나당 Mate 한 개로 설치하세요.
6. 먼저 인증이 필요 없는 데모로 설치를 검증하세요. Codex도 원하면
   agent/Dockerfile에 고정된 버전과 호환되는 CLI로 로그인하세요.
   configure.py --codex-auth는 대상 사용자의 ~/.codex/auth.json을 읽으므로
   파일 기반 저장을 사용하고, VPS에서는 device login 또는 SSH를 통한
   인증 파일 전송을 사용하세요. 로그인·인증 전송은 사용자와 진행하세요.
   python3 scripts/configure.py --codex-auth --host 127.0.0.1을 실행하고
   docker compose restart worker로 적용하세요. 인증 파일 내용은 출력하거나
   커밋하지 마세요. Codex 계정 사용량은 사용자의 계정에서 소비됩니다.
7. docker compose ps와 http://127.0.0.1:웹포트/api/health를 확인하고,
   개인 접속 링크로 로그인하여 워커가 online인지, 데모 작업이 완료되는지,
   기록·diff·테스트 결과와 후속 요청·중단 기능까지 확인하세요.
   scripts/smoke.py는 기본 한도(MAX_CONCURRENT=2, TASK_CPU=2,
   TASK_MEMORY=2g)를 전제로 하므로 기본 한도라면 실행해 검증하세요.
   한도를 바꿨다면 웹에서 해당 설정으로 확인하고 검증 범위를 보고하세요.
   실제 Codex 테스트는 Codex 연결을 요청한 경우에 실행하세요.
8. VPS에서는 공개 8787 포트를 열지 말고 로컬 PC에서
   ssh -N -L 127.0.0.1:8787:127.0.0.1:웹포트 -p SSH포트 사용자@서버
   형태로 SSH 터널을 연결하세요. 브라우저는 http://127.0.0.1:8787을 사용합니다.
   공개 도메인 접속을 선택한 경우 HTTPS 역방향 프록시와 접근 제한을
   구성하고 개인용 서버로 유지하세요. 개인 접속 링크의 주소 부분만 바꾸세요.
9. 재부팅 후 시작 방식도 안내하세요. Linux는 Docker 데몬 자동 시작과
   Compose의 restart 정책을 확인하고, Windows/macOS는 Docker Desktop이
   실행되어야 합니다. scripts/install-autostart.py는 macOS 전용이며
   로그인 전 무인 시작이나 진행 중이던 작업의 자동 재개를 보장하지 않습니다.
10. 다른 앱의 컨테이너·볼륨·Docker 설정을 변경하거나 전체 prune을 하지 마세요.
    기존 Mate 데이터도 보존하고 docker compose down -v를 실행하지 마세요.
    비밀값을 로그에 출력하지 마세요. 개인 링크는 .secrets/access.txt에 저장하고
    사용자에게 파일 위치와 접속 방법을 알려 주세요.
    끝나면 실제 설치 경로, 접속 주소, SSH 터널 명령(VPS인 경우),
    시작·중단·로그 확인 명령, 검증 결과와 미완료 사항을 짧게 보고하세요.
```

## 운영체제별 준비

| 설치 대상 | 준비 방법 | 명령을 실행할 곳 |
| --- | --- | --- |
| Windows PC | WSL2 Ubuntu + Docker Desktop, Ubuntu의 WSL Integration 활성화 | WSL Ubuntu 터미널, 예: `~/apps/ai/mate` |
| Linux PC / Linux VPS | Docker Engine + Docker Compose 플러그인 | 로컬 터미널 또는 서버 SSH 세션 |
| macOS | Apple Silicon/Intel에 맞는 Docker Desktop을 설치하고 실행 | macOS 터미널 |

Windows에서 WSL이 없다면 관리자 PowerShell에서 `wsl --install -d Ubuntu`를 실행하고 필요한 재부팅과 Ubuntu 사용자 생성을 마치세요. [Docker Desktop Windows 설치](https://docs.docker.com/desktop/setup/install/windows-install/)와 [WSL Integration 설정](https://docs.docker.com/desktop/features/wsl/)을 따르세요. 아래 Bash 명령은 PowerShell이 아닌 **Ubuntu 터미널**에서 실행합니다.

Linux는 [Docker Engine 설치](https://docs.docker.com/engine/install/)에서 자신의 배포판을 선택하세요. Ubuntu VPS는 [Ubuntu 설치 절차](https://docs.docker.com/engine/install/ubuntu/)를 따라 Compose 플러그인까지 설치합니다. 현재 Compose는 `/var/run/docker.sock`을 사용하므로 이 소켓이 있는 일반 Docker Engine 환경이 필요합니다. [Docker 사용자 권한 설정](https://docs.docker.com/engine/install/linux-postinstall/) 후 설치 사용자로 `docker info`가 성공하는지 확인하세요. rootless Docker는 소켓 경로 등 추가 설정이 필요합니다.

macOS는 [Docker Desktop Mac 설치](https://docs.docker.com/desktop/setup/install/mac-install/)를 따르세요. Windows WSL/Linux/macOS 모두 Git, Python 3, [Flutter SDK](https://docs.flutter.dev/install/manual)를 준비하고 `git --version`, `python3 --version`, `flutter --version`, `docker info`, `docker compose version`이 성공하는지 확인하세요. Flutter SDK의 Dart 버전은 이 저장소의 `pubspec.yaml` 범위(`>=3.10.0 <4.0.0`)에 맞아야 합니다. 웹 빌드에는 Android Studio나 Xcode 전체 설치가 필요하지 않습니다.

작업 한도 기본값은 동시 2개·작업당 CPU 2개·메모리 2GB입니다. 서버 서비스와 빌드에도 자원이 필요하므로 작은 VPS는 `.env`의 `MAX_CONCURRENT`를 1로 낮추고 자원 한도를 조정하세요. Windows/macOS는 Docker Desktop에 배정된 메모리도 확인하세요. 아래 절차는 기존 M1 검증 구성을 바탕으로 한 일반 설치 안내이며, Windows/Linux의 실기기 검증 결과를 의미하지는 않습니다.

## 직접 설치하기: 공통 Docker 절차

의존성 준비 후 Windows의 WSL Ubuntu, Linux 또는 macOS 터미널에서 실행하세요. VPS라면 먼저 `ssh -p SSH포트 사용자@서버`로 접속합니다. 설치 폴더를 바꾸려면 `MATE_INSTALL_DIR`만 수정하세요. 해당 폴더가 이미 있으면 clone 대신 기존 내용을 확인하고 사용하세요.

```bash
MATE_INSTALL_DIR="$HOME/apps/ai/mate"
mkdir -p "$(dirname "$MATE_INSTALL_DIR")"
git clone https://github.com/thruthesky/mate.git "$MATE_INSTALL_DIR"
cd "$MATE_INSTALL_DIR"

flutter pub get
flutter build web --release --no-web-resources-cdn
python3 scripts/configure.py --host 127.0.0.1
```

`.env`에서 `MATE_BIND=127.0.0.1`로 변경하세요. 기본 웹 포트는 `MATE_PORT=8787`입니다. 포트를 바꿨다면 `python3 scripts/configure.py --host 127.0.0.1`을 다시 실행해 개인 링크도 갱신하세요. 설정 스크립트는 처음에만 비밀값을 만들며 기존 `.env`를 보존합니다. `.env.example`을 그대로 복사해 만든 예시 비밀값은 실제 설치에 사용하지 마세요.

```bash
# 작업 컨테이너용 이미지는 Compose 시작 전에 별도로 빌드합니다.
docker build -t mate-agent:0.1.0 agent
docker compose up -d --build --wait
docker compose ps
curl --fail http://127.0.0.1:8787/api/health
```

사용자 컴퓨터에서 `http://127.0.0.1:8787`을 열고 `.secrets/access.txt`의 개인 링크로 로그인하세요. VPS라면 아래 SSH 터널을 먼저 연결합니다. 웹 포트를 변경했다면 명령의 포트도 맞추세요. 키가 들어 있는 개인 링크는 본인만 확인하세요.

먼저 데모 작업을 실행하여 워커·진행 기록·diff·테스트 결과를 확인하세요. 기본 자원 한도를 유지했다면 `python3 scripts/smoke.py`로 통합 검증도 할 수 있습니다. 이 검증은 샘플 작업과 기록을 실제로 생성합니다.

### Codex 연결하기 (선택)

데모는 AI 로그인 없이 실행됩니다. 실제 Codex 작업에는 별도 인증이 필요합니다. 호스트에 Node/npm과 Codex CLI를 준비한다면 작업 이미지와 같은 버전은 `agent/Dockerfile`의 `CODEX_VERSION`을 확인하세요(현재 `0.159.2`).

```bash
npm install -g @openai/codex@0.159.2
# 자신의 계정으로 로그인하고 auth.json 파일에 저장합니다.
codex -c 'cli_auth_credentials_store="file"' login
# 브라우저 없는 VPS에서는 위 로그인 대신 device login을 사용합니다.
# codex -c 'cli_auth_credentials_store="file"' login --device-auth
python3 scripts/configure.py --codex-auth --host 127.0.0.1
docker compose restart worker
```

로그인은 **설치 대상에서 configure.py를 실행하는 사용자**의 `~/.codex/auth.json`에 저장되어야 합니다. macOS 키체인 등에만 저장된 인증은 이 설치 스크립트가 읽지 못합니다. VPS의 device login을 쓸 수 없으면 로컬에서 로그인한 인증 파일을 SSH/SCP로 대상 사용자 홈에 안전하게 전달하는 방법도 있습니다. [공식 Codex 인증 안내](https://learn.chatgpt.com/docs/auth)의 파일 저장·원격 로그인 절차를 확인하세요. `.secrets/codex-auth.json`과 개인 접속 키는 Git에 포함하지 않습니다.

연결 후 웹에서 Codex 작업을 실행하거나 `python3 scripts/smoke.py --codex`로 확인하세요. 실제 Codex 검증은 계정 사용량을 소비합니다. API 키 인증도 Codex CLI에서 처리하며, 이 버전의 Mate는 `.env`에 API 키만 추가하는 방식으로 연결되지 않습니다.

### VPS 접속과 재시작

VPS를 설치하는 AI에게 앞의 원격 접속 정보(IP/호스트, 사용자, SSH 포트, 인증 방식, sudo 권한)를 함께 전달하세요. `MATE_BIND=127.0.0.1`로 설치하면 서버의 8787 포트를 인터넷에 열지 않아도 됩니다. **사용자 컴퓨터**의 터미널에서 다음 값을 자신의 정보로 바꾸고 실행하세요.

```bash
# 예: 서버 SSH 포트 22, 서버 Mate 포트 8787
ssh -N -L 127.0.0.1:8787:127.0.0.1:8787 -p 22 ubuntu@vps.example.com
# 특정 SSH 키가 필요하면 ssh에 -i ~/.ssh/내키 옵션을 추가하세요.
```

터널을 켜 둔 동안 사용자 컴퓨터의 브라우저에서 `http://127.0.0.1:8787`로 접속합니다. 로컬 8787이 사용 중이면 `-L 127.0.0.1:18787:127.0.0.1:8787`로 바꾸고 브라우저는 18787로 접속하세요. 개인 링크의 호스트·포트 부분도 브라우저 주소에 맞춥니다. 터널을 닫아도 VPS의 Mate 작업은 계속 실행됩니다. 도메인으로 접속하려면 별도로 HTTPS 역방향 프록시와 접근 제한을 구성하세요. 현재 버전은 개인 접속 키를 사용하는 단일 사용자 서버입니다.

설치 폴더에서 다음 명령으로 운영합니다.

```bash
docker compose stop                     # 기록을 보존하며 중단
docker compose up -d                    # 다시 시작
docker compose logs --tail=50 worker api # 로그 확인
```

Linux/VPS는 Docker 데몬이 부팅 시 시작되어야 Compose의 `restart: unless-stopped` 정책이 적용됩니다. 수동으로 중단한 서비스는 `docker compose up -d`로 다시 시작하세요. Windows/macOS는 Docker Desktop이 실행되어야 합니다. macOS 로그인 시 자동 시작을 원하면 `python3 scripts/install-autostart.py`를 사용할 수 있으며 이 스크립트는 **macOS 전용**입니다. 워커 재시작으로 중단된 작업은 웹에서 후속 요청으로 재개합니다. 백업은 [운영 문서](docs/OPERATIONS.md)를 확인하고, 데이터를 보존하려면 `docker compose down -v`나 Docker 전체 정리를 실행하지 마세요.

## 기존 M1 Mac 전용 배포

전제: M1의 Docker Desktop 실행, SSH `m1` 접속 가능, 개발 Mac의 Flutter·Node 설치. 실제 Codex 사용에는 M1의 기존 `codex login`이 필요합니다.

```bash
bash scripts/deploy-m1.sh
```

설치 위치는 M1의 `~/apps/ai/mate`, 접속 주소는 `http://M1-MacBook-16.local:8787`입니다. 설치 후 개발 Mac의 `.secrets/access.txt`에 접속 키가 포함된 개인 링크를 저장합니다. 접속 키와 인증 파일은 Git에서 제외합니다.

## 구현된 기능

- 샘플 프로젝트의 작업 생성, Codex/데모 실행, 실행 전 승인·거절
- 영구 진행 기록, 코드 diff, 실제 `node --test` 결과, Codex 토큰 사용량
- 같은 작업의 후속 요청과 Codex 세션 재개
- 사용자 중단 시 컨테이너의 하위 프로세스까지 종료
- 워커 재시작 후 중단된 실행 기록 보존과 명시적 후속 요청
- CPU·메모리·동시 실행·시간 제한, 개인 접속 키 인증

현재는 단일 사용자·단일 M1·내장 샘플 프로젝트용 검증 버전입니다. 임의 저장소 연결, Claude, 명령별 대화형 승인, 비용 상한, 다중 워커는 후속 범위입니다. 일반 대화가 작업을 자동 분류하는 중앙 챗봇은 아직 없습니다. 요청은 사용자가 선택한 작업에서 실행합니다.

```bash
flutter analyze
(cd worker && npm ci --ignore-scripts && npm run check)
php -l api/index.php
# M1 설치 후 API/실제 Docker 통합 테스트
python3 scripts/smoke.py
python3 scripts/smoke.py --codex
```

LAN 개인 테스트 구성은 HTTP입니다. 인터넷 공개 전에는 HTTPS, 사용자별 인증·권한과 비밀키 프록시를 추가해야 합니다.
