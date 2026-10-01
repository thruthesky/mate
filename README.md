# Mate

개인용 AI 에이전트 작업 서버입니다. Flutter Web 콘솔, PHP API, MariaDB 기록 저장소, Node/TypeScript 실행 관리자와 작업별 Docker 컨테이너로 구성합니다.

상세 기획은 [docs/PLAN.md](docs/PLAN.md), 운영 절차는 [docs/OPERATIONS.md](docs/OPERATIONS.md)를 확인하세요.

## M1 Mac 설치

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
