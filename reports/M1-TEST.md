# M1 설치·검증 결과

검증일: 2026-10-01, Asia/Seoul. 상세 계획은 [PLAN.md](../docs/PLAN.md), 운영은 [OPERATIONS.md](../docs/OPERATIONS.md)에서 확인한다.

## 결과

M1에 개인용 첫 검증 버전을 설치하고 실제 Codex 수정·테스트·세션 재개를 확인했다. 데모 21개, 복구 9개, 실제 Codex 11개로 총 **41개 통합 검증 항목 통과**. Flutter 정적 분석·Web release 빌드, TypeScript 정적 검사, PHP lint와 Python/shell 구문 검사도 통과했다.

검증 시 생성한 작업과 실행 기록은 서버의 작업 목록에 보존되어 있다. 개발 중 처음 발견한 실패 기록도 삭제하지 않았다.

## 설치 환경

| 항목 | 값 |
| --- | --- |
| 장비 | Apple M1 Max · ARM64 · 호스트 RAM 64GB |
| 운영체제 | macOS 26.5.2 |
| 접속 | SSH `m1` / `M1-MacBook-16.local` |
| 설치 경로 | `/Users/thruthesky/apps/ai/mate` |
| 웹 | `http://M1-MacBook-16.local:8787` / 확인된 IP `192.168.45.69` |
| Docker | 29.2.0, Linux ARM64 VM |
| Docker VM 자원 | CPU 10, 약 7.75GiB RAM |
| Codex | CLI 0.159.2 고정, M1 기존 개인 로그인 사용 |
| 데이터 | MariaDB 11.4 named volume + 작업별 코드/session volume |
| 제한 | 동시에 2개, 작업당 CPU 2 / 메모리 2GiB / PID 256 / 900초 |
| 자동 시작 | 사용자 LaunchAgent `com.mate.personal-server`, 로그인 후 Docker·Compose 시작 |

상시 서비스 4개 `mate-db-1`, `mate-api-1`, `mate-web-1`, `mate-worker-1` 실행을 확인했다. 종료된 작업 컨테이너는 정지 상태로 남겨 코드와 세션을 보존했다. 다른 프로젝트의 서비스는 중단·수정하지 않았다.

개인 접속 키가 들어 있는 링크는 개발 Mac 및 M1의 `.secrets/access.txt`에 보존했다. 키와 auth 파일은 결과 보고서·Git에 포함하지 않았다.

## 실제 Codex 검증

작업 ID: `60be24ff964051399e4d45f13c1670f1`.

세션 ID: `01a0f571-c1b9-7ce0-b649-e6bbac760b2e`.

1. 최초 요청: `sum.js`의 `a - b` 오류를 `a + b`로 수정. 기존 assertion을 유지한 실제 `node --test` 결과는 **3 passed / 0 failed**, exit 0.
2. 후속 요청: 같은 task, 코드 volume, session volume과 동일 Codex thread 재사용. `multiply.js`와 양수·음수 테스트를 추가. 실제 결과는 **5 passed / 0 failed**, exit 0.
3. 각 실행 전 승인 대기 확인, 승인 후 실행. 각 실행의 결과·diff·검증 출력·토큰 사용량을 DB에 저장.

| 실행 | input_tokens | cached_input_tokens | output_tokens | 종료 |
| --- | ---: | ---: | ---: | --- |
| 최초 수정 | 58,138 | 55,040 | 337 | completed |
| 같은 세션 후속 | 104,161 | 99,712 | 754 | completed |

모델은 계정의 CLI 기본값을 사용했다. 공급자가 보고한 토큰을 그대로 기록했고 요금 환산이나 비용 상한을 적용한 것은 아니다. 두 실제 실행은 로그인 계정의 사용량을 소비했다.

## 데모·복구 검증

- 인증 없는 접근 401, 사용자/worker 키의 역할 교차 접근 401, 허용되지 않은 agent 400.
- 실행 승인 저장, 승인 전 실행 차단, 승인 중복 결정 409, 거절 시 cancelled.
- 실제 Git diff와 `node --test` 출력 저장, 새 HTTP 연결에서 이벤트 재조회, cursor 중복 없음.
- 후속 요청에서 같은 환경 재사용과 별도 run 생성, 실행 중 후속 요청 409.
- 사용자 중단 후 컨테이너 종료, 중단 전에 생성한 `demo-progress.txt`의 diff 보존.
- 독립 작업 3개를 생성하면 2개 running / 1개 queued, 각 작업의 workspace volume 구분.
- runtime 비 root, root FS read-only, cap drop ALL, no-new-privileges, CPU/메모리/PID 제한 실측.
- mount는 자기 workspace/session volume 2개뿐이며 Docker socket 없음.
- 긴 데모 실행 중 **Mate worker만 SIGKILL** 후 재시작: interrupted 기록, 원래 prompt 자동 재실행 없음, 실행 중 파일 변경 diff 보존.
- 명시적 후속 요청 후 환경을 재사용해 정상 완료.

## 브라우저 검증

실제 LAN 주소에 접속하여 로그인, 저장된 작업 재조회, 새 데모 작업 생성, 동일 작업의 후속 입력, diff·검증 탭을 확인했다. 데스크톱 1440×960, 모바일 390×844 화면을 확인했으며 최종 페이지의 브라우저 콘솔 오류는 0개였다.

화면 근거:

- [작업 콘솔](console.png)
- [실제 Codex 후속 diff](codex-diff.png)
- [실제 Codex 테스트 결과](codex-tests.png)
- [모바일 작업 화면](mobile.png)

## 발견·수정한 문제

- 내부 전용 Docker 네트워크만 연결하면 M1의 포트가 게시되지 않아 Nginx에 외부 접속용 edge 네트워크를 추가했다. API/DB/worker는 내부 네트워크에 유지했다.
- ALL capability drop 상태에서 root exec가 UID 1000의 mode-700 session directory에 접근할 수 없었다. 인증 파일을 task UID로 stdin을 통해 mode 600으로 쓰도록 수정했다. 비밀 내용은 로그·명령 인자에 출력하지 않았다.
- 재시작으로 중단된 실행에서도 완료 전까지의 변경을 보여 주도록 복구 시 Git diff를 저장했다.

## 운영 상태와 검증 범위

검증 당시 idle 상시 서비스 메모리는 DB 약 162MiB, worker 약 61MiB, API 약 12MiB, Nginx 약 9MiB였다. host 디스크 여유는 약 46GiB였다. Docker VM 안의 메모리 한도를 기준으로 동시 실행을 보수적으로 2개로 유지했다.

현재 기능은 **개인용·단일 M1·내장 Node 샘플 프로젝트**에 한정한다. 실제 저장소 CRUD/clone, Claude, 중앙 대화 라우팅, 명령별 승인, HTTPS, 비용 hard limit, volume disk quota와 다중 worker는 후속 기획이다. 개인 auth를 비신뢰 코드로부터 분리하는 secret proxy와 네트워크 egress 제한도 후속 범위다.

OS 전체 재부팅, 로그인 전 무인 복귀, 실제 배포/외부 쓰기, DB backup 복원은 테스트하지 않았다. 자동 시작 LaunchAgent 등록과 현재 세션에서의 시작은 확인했고, 실행 복구 경로는 worker 강제 재시작으로 확인했다.

## 재현 근거

자동 테스트 스크립트는 [smoke.py](../scripts/smoke.py)이며 M1 설치 폴더에서 실행한다.

- [데모 통합 결과](smoke-demo.json)
- [복구 통합 결과](smoke-recovery.json)
- [실제 Codex 통합 결과](smoke-codex.json)
- [M1 서비스·실행·diff·검증·사용량 원본](m1-evidence.json)
