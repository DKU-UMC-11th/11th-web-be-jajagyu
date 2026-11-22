# 2주차 인프라 - 관측 가능한 시스템 만들기

## 구성 (1주차 스택 위에 관측을 얹었음)
```
EC2 t3.small (ASG, Docker) ─ app 컨테이너(Spring Boot, /actuator/prometheus)
                           └ alloy 컨테이너(--network host) ─ Fleet Management(원격 설정 3개) ─ Grafana Cloud Prometheus
RDS MySQL (db.t3.micro, 비공개) ← exporter 전용 사용자(SELECT, PROCESS, REPLICATION CLIENT)
```
- 앱: `spring-boot-starter-actuator` + `micrometer-registry-prometheus`, `http.server.requests` 히스토그램과 SLO 버킷(50ms~3s) 설정. 인터셉터가 `/actuator/**`를 막고 있어서 예외로 열었음.
- 수집: Alloy 파이프라인 3개 `umc_host_metrics`, `umc_mysql_metrics`, `umc_app_metrics`(`os = linux`, Active). 파일은 `pipelines/`.
- 값은 SSM Parameter Store `/umc/gc-*`, `/umc/mysql-dsn`(SecureString)에서 읽고 코드/Git에는 없음.
- 대시보드: `dashboard-spring.json` (워크북 JSON을 Spring/Micrometer 지표 이름으로 바꿨음. 이벤트 루프 지연 → Hikari 대기 요청 수).

## 증거 화면 (`screenshots/`)
| 파일 | 내용 |
|---|---|
| 01-fleet-pipelines-active.jpg | Fleet Management 파이프라인 3개가 Active |
| 02-fleet-inventory.jpg | 수집기(Alloy) 목록. 5개 중 3개는 교체되어 종료된 인스턴스의 기록 |
| 03-dashboard-load-200-800.jpg | 서버 2대 기준 200→800 RPS 구간 대시보드 |
| 04-dashboard-1node-top.jpg | 서버 1대 기준 200→800 RPS, RPS/지연/에러율/Hikari/DB 커넥션 |
| 05-dashboard-1node-infra.jpg | 같은 구간의 CPU/메모리/디스크 |

## SLO 정의서
대상은 사용자 쓰기 경로 `POST /movie-records`(트랜잭션 안에서 쿼리 5번)로 잡았음.

| 구분 | SLI (무엇을 재나) | SLO (목표) | 근거 |
|---|---|---|---|
| 가용성 | 5xx/타임아웃이 아닌 요청 비율 | 28일 기준 99.5% 이상 | 아직 서비스 이력이 없어 보수적으로 시작. 월 약 3.6시간까지 허용 |
| 지연 | `histogram_quantile(0.95, ...)` p95 | 300ms 이하 (정상 부하 400 RPS 이하) | 서버 1대 400 RPS에서 서버 측 p95 67ms, 클라이언트 측 112ms였음. 3배 안팎 여유를 둠 |
| 지연(꼬리) | p99 | 1초 이하 | 5초 타임아웃 전에 사용자가 체감하는 한계 |
| 에러율 | `5xx / 전체` (5분) | 1% 미만 | 측정 구간 400 RPS 이하에서 0% |

- 알림 기준(선택 미션): p95 1초 이상이 1분 이상이면 알림. 5xx 비율 질의에는 `or vector(0)`를 붙여 No Data를 막을 계획이었음.
- 측정을 지킬 수 있는 부하 상한은 아래 한계 측정 결과의 약 400 RPS(서버 1대)로 봄.

## 한계 측정 리포트
### 방법
- 부하 도구: zero-downtime-lab, 단계당 40초, 단계 사이 30초 휴지, 구동 스크립트 `infra/loadtest.py`.
- 단계마다 회원을 새로 만들어 토큰을 받고(평점 (회원, 영화) 유니크 제약 때문에 409 방지), 시작 전에 손으로 1건 보내 201 확인.
- 시나리오: `POST /movie-records`, `movieId={{counter}}`, 성공 코드 200/201, 타임아웃 5초.
- 서버 지표는 Grafana(Prometheus)에서 각 단계 시작~종료 시각으로 조회함. 원본: `loadtest-before*.json`.

### 결과 1) 서버 2대 (t3.small x2, Hikari 풀 10)
| 목표 RPS | 처리량 | p95 | 실패 | CPU(최대) | threads_connected | threads_running |
|---|---|---|---|---|---|---|
| 200 | 199.7/s | 175ms | 0 | 94%* | 23 | 3 |
| 400 | 381.4/s | 90ms | 0 | 88% | 23 | 3 |
| 600 | 595.1/s | 59ms | 0 | 74% | 23 | 5 |
| 800 | 754.6/s | 119ms | 0 | 77% | 23 | 6 |

\* 첫 단계라 JVM 워밍업 영향으로 추정함(확인하지는 않았음).

- 꺾이지 않았음. 그런데 이 도구는 발사 타이머 때문에 500 RPS 이하에서만 신뢰할 수 있고(상한 1000), 800 목표에서 실제 발사는 약 755/s였음(클라이언트 드롭 1,765건). 즉 약 755 RPS 이상은 이 도구로 확인할 수 없음.

### 결과 2) 서버 1대 (ASG 1대로 축소, 도구 범위 안에서 한계를 보려고)
| 목표 RPS | 처리량 | p95 | 실패 (유형) | CPU(평균) | threads_connected | threads_running |
|---|---|---|---|---|---|---|
| 200 | 198.3/s | 140ms | 0 | 44% | 13 | 3 |
| 400 | 399.3/s | 112ms | 0 | 65% | 13 | 6 |
| 600 | 502.5/s | 2,522ms | 0 (지연 급증, 느린 요청 15,552건) | 82% | 13 | 4 |
| 800 | 514.5/s | 4,310ms | 247 (timeout) | 80% | 13 | 4 |

서버 측 지표(Grafana): 서버 p95가 67ms(400) → 1,239ms(600) → 1,155ms(800), Hikari 활성 커넥션 최대 10/10, 대기 요청은 400에서 176, 600과 800에서 189까지 올랐음.

> **처리량이 꺾이는 지점은 약 500 RPS 이다. (서버 1대 기준)**
> 목표를 올려도 처리량이 약 500~515/s에서 멈추고 p95가 140ms → 2.5초 이상으로 치솟음.

### 읽은 것
- 실패율이 아닌 **지연이 먼저 무너졌음**. 600에서는 실패가 0인데 p50이 1.3초임. 800에서야 타임아웃이 보였음.
- 포화 vs 시나리오 오류 구분: 실패 유형이 timeout 위주이고 p95/p99가 치솟고 처리량이 목표를 못 따라감 → **시나리오 오류가 아니라 포화**.
- DB는 한가했음. `threads_running`은 4~6, `threads_connected`는 13(앱 풀 10 + 수집기 등)이라 DB가 일을 못 따라가는 것이 아님.
- 대신 앱의 **Hikari 풀이 10/10으로 가득 차고 대기 요청이 쌓였음**(400에서 이미 176). 한 요청이 커넥션 하나를 쿼리 5번 동안 쥐고 있어서 동시에 처리하는 요청이 풀 크기에 묶이는 것으로 보임.
- CPU도 80%대로 높아서 풀만의 문제인지는 아직 단정 못 함. 3주차에서 풀을 늘리고 쿼리 왕복을 줄인 뒤 다시 재어 어느 쪽이 병목인지 확인할 계획.

### 측정의 한계
- 클라이언트가 집 PC이고 도구 정확도가 500 RPS 이하라서, 400~600 구간은 클라이언트 드롭(600: 2,927건, 800: 9,175건)이 섞여 있음. 800 RPS 숫자는 목표가 아니라 실제 발사량(약 515~755/s)으로 읽어야 함.
- 서버 2대 결과와 1대 결과를 따로 적었음. 3주차 개선 전/후 비교는 같은 조건(1대)에서 할 예정.

## 트러블슈팅
- **앱이 기동하자마자 죽음**: 운영 설정이 `ddl-auto: validate`인데 새 RDS가 비어 있어서였음. `sql/01_schema.sql`을 한 번 적용했음. 스키마 파일이 `umc_movie` DB를 만들게 되어 있어서 `movie` DB에 테이블만 만들도록 `CREATE DATABASE`/`USE` 줄을 뺐음.
- **Alloy의 mysql 파이프라인에 값이 없었음**: 인스턴스가 뜰 때 `mysql-dsn`이 아직 SSM에 없었음. DSN을 넣은 뒤 Alloy 컨테이너를 다시 만들었음.
- **워크북 PromQL이 Node 지표 이름 기준**: Spring은 `http_server_requests_seconds_*`와 `hikaricp_*`를 쓰므로 질의와 대시보드를 바꿨음.
- **`/actuator/prometheus`가 로그인 인터셉터에 막힘**: `/actuator/**`를 예외로 열었음. 대신 ALB 주소로도 지표가 보이는 상태라 측정이 끝나면 닫는 것이 좋음.

## 핵심 키워드 (~했음)
- **Alloy / Fleet Management**: 각 서버에 수집기를 하나씩 두고, 수집 설정은 서버가 아니라 Grafana에서 원격으로 내려주는 구조라고 이해했음. 설정은 최대 5분 간격으로 반영됨.
- **히스토그램과 p95/p99**: 백분위수는 평균을 낼 수 없어서 버킷별 개수를 저장하고 `rate`, `sum by (le)`, `histogram_quantile`로 합쳐서 계산한다는 것을 확인했음.
- **포화 신호**: RPS가 오르는데 처리량이 안 오르고 p95만 오르는 지점이 한계였음. 실패가 늘었다고 다 포화는 아니라서 실패 유형(timeout vs 4xx/5xx)으로 구분했음.
- **SLI/SLO**: 사용자가 겪는 것(지연, 에러율, 가용성)을 숫자로 정의하고 목표를 정해 두는 것이라고 이해했음.

## 후기
- 대시보드를 만드는 것보다 도구가 믿을 수 있는 범위를 아는 것이 더 중요했음. 처음 측정에서 꺾이는 지점이 안 나와 서버를 1대로 줄여 다시 쟀고, 그 조건을 리포트에 그대로 적었음.
- 실패가 0인데도 p50이 1초를 넘는 구간이 있어서, 성공률만 보면 장애를 놓칠 수 있다는 것을 알았음.
