# M1 운영

## 접속

설치 경로 `~/apps/ai/mate`, 주소 `http://M1-MacBook-16.local:8787`. 설치 중 확인된 IPv4는 `192.168.45.69`이며 DHCP에 따라 바뀔 수 있다. LAN에서 `.local`이 해석되지 않으면 현재 IP를 사용한다. 접속 키가 포함된 개인 URL은 `.secrets/access.txt`에서 확인한다. 브라우저를 다시 열면 해당 링크 또는 키로 로그인한다.

## 서비스 확인·중단·시작

```bash
ssh m1
export PATH=/opt/homebrew/bin:/usr/local/bin:$PATH
cd ~/apps/ai/mate
docker compose ps
docker compose logs --tail=50 worker api
docker compose stop       # 기록 보존, 서비스 중단
docker compose up -d      # 다시 시작
```

`docker compose down -v`는 DB 데이터를 삭제하므로 일반 중단에 사용하지 않는다. Docker 전체 prune, 다른 프로젝트 container 중단도 사용하지 않는다. 작업 환경은 `mate-task-<task ID>`, volume은 `mate-work-*`와 `mate-session-*`이며 label `mate.managed=task`를 확인한다.

## 개인 로그인 준비

```bash
codex login
python3 scripts/configure.py --codex-auth
docker compose restart worker
```

새 작업은 설정한 auth 사본으로 시작한다. 기존 작업의 auth는 작업 session volume에서 유지되고 자동으로 host login을 갱신하지 않는다. 해당 session 인증이 만료/취소되면 작업별 재인증 기능을 추가하거나 관리자만 인증 사본을 교체해야 한다. `.secrets`·`.env`·session volume을 외부에 공유하지 않는다.

## 제한 조정

`.env`의 `MAX_CONCURRENT`, `TASK_CPU`, `TASK_MEMORY`, `RUN_TIMEOUT_SECONDS`, `CODEX_MODEL`을 변경하고 `docker compose up -d`로 worker를 재생성한다. 기존 작업 컨테이너의 CPU/메모리 설정은 생성 시 값이 유지된다. 기존 환경의 제한 변경은 관리자 기능 후속 구현이며 새 작업으로 검증한다.

## 재부팅

설치 스크립트는 사용자 LaunchAgent `com.mate.personal-server`를 등록한다. 로그인하면 Docker Desktop을 열고 준비 후 `docker compose up -d`로 Mate를 시작한다. 로그는 `logs/startup*.log`에 보존한다. 로그인 전 완전 무인 부팅은 지원하지 않는다. 실행 중이던 task는 워커가 실제 컨테이너를 정지하고 interrupted로 기록한다. 웹에서 후속 요청을 보내 재개한다.

자동 시작 제거는 Mate 항목만 대상으로 한다.

```bash
launchctl bootout gui/$(id -u)/com.mate.personal-server
rm ~/Library/LaunchAgents/com.mate.personal-server.plist
```

## 백업

백업은 DB와 task workspace/session을 함께 보존해야 한다. 재현 가능한 개인 DB 백업 예시는 다음과 같다. 암호는 docker 내부 환경에서 읽으며 출력하지 않는다.

```bash
mkdir -p backups
chmod 700 backups
docker compose exec -T db sh -c 'exec mariadb-dump -umate -p"$MARIADB_PASSWORD" --single-transaction mate' > backups/mate.sql
chmod 600 backups/mate.sql
```

volume 백업 전 실행을 끝내고 worker를 중단한다. 해당 task ID와 DB backup 시점을 맞추고 Docker volume export로 코드/세션을 보존한다. 자동 백업·자동 정리·백업 복원 테스트는 후속 운영 단계다. 현재 작업 volume을 임의 삭제하면 재개 기능을 잃는다.

## 테스트

M1의 설치 폴더에서 실행한다. 테스트 결과를 서버의 작업 목록에 남긴다.

```bash
python3 scripts/smoke.py
python3 scripts/smoke.py --recovery
python3 scripts/smoke.py --codex
```

실제 Codex 테스트는 계정 사용량을 소비한다. 샘플 프로젝트에서만 실행한다. `--recovery`는 Mate worker만 강제 재시작한다. 평소 실제 작업을 돌리는 동안에는 이 테스트를 실행하지 않는다.
