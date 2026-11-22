# 10주차 백엔드 - 배포하고 결과물 완성하기

## ☑️ 실습 인증

### 배포 결과
| 항목 | 값 |
|---|---|
| 스택 | Spring Boot (JAR), Java 21 |
| 서버 | EC2 `t3.small` (Amazon Linux 2023), 리전 ap-northeast-2 |
| DB | RDS MySQL 8.0 `db.t3.micro`, DB 이름 `umc_movie`, 퍼블릭 액세스 꺼짐 |
| API 주소 | `http://15.165.39.171:8080` (80 포트도 8080으로 연결). 실습이 끝나면 삭제되는 임시 주소임(점검 기록 `api-check-output.txt`는 첫 배포 주소로 찍었고, 재배포 뒤 주소가 바뀜) |
| 문서 | `http://15.165.39.171:8080/swagger-ui.html` |

### 핵심 API 점검 (공개 주소, `api-check-output.txt`)
토큰과 비밀번호는 출력하지 않았고 `***masked***`로 가렸음.

| 단계 | 요청 | 결과 |
|---|---|---|
| 1 | `POST /members` | 201 `COMMON201` |
| 2 | `POST /auth/login` | 200 `COMMON200` (accessToken 가림) |
| 3 | `GET /members/me` 토큰 없이 / 토큰 있이 | 401 `AUTH401_2` / 200 |
| 4 | `POST /ratings`, `GET /members/{memberId}/ratings` | 201, 200 (방금 등록한 평점이 보임) |
| 5 | `POST /favorites`, `GET /favorites/550`, `GET /favorites` | 201, 200 `isFavorite: true`, 200 (1건) |
| 6 | 빈 목록 `GET /favorites` | 200 `result: []` |
| 6 | 중복 즐겨찾기 / 중복 평점 | 409 `FAVORITE409_1` / 409 `RATING409_1` |
| 6 | 검증 실패 `movieId: 0` | 400 `COMMON4001` |

모두 `isSuccess`, `code`, `message`, `result` 형식으로 내려왔음.

### 확인 포인트
| 질문 | 확인 방법과 결과 |
|---|---|
| 개발/운영 설정을 분리했나? | `application.yml`(공통), `application-local.yml`(기본), `application-prod.yml`. 서버 환경 파일에 `SPRING_PROFILES_ACTIVE=prod` |
| 운영 스키마 자동 변경이 꺼져 있나? | `application-prod.yml`의 `ddl-auto: validate`. 테이블은 준비된 `01_schema.sql`로만 만들고, 앱은 검증만 함 |
| 프론트 Origin에서 API 응답을 읽을 수 있나? | `FRONTEND_ORIGIN` 환경 변수를 CORS 허용 목록에 더함. 허용/거절을 `CorsTest` 3개로 검증하고, Vercel에서는 같은 출처 프록시(`/api/backend`)를 써서 혼합 콘텐츠와 CORS를 모두 피함 |
| SSH를 닫아도 서버가 살아 있나? | SSH 포트(22)를 처음부터 열지 않았고(보안 그룹에 없음, 키 페어 없음) 서버 접속은 SSM으로만 함. 앱은 `systemd` 서비스(`active`, `enabled`)라서 재부팅 뒤에도 다시 시작됨 |
| DB가 EC2에서만 접근되나? | DB 보안 그룹 3306 인바운드 소스가 CIDR이 아니라 앱 보안 그룹 하나뿐이고, RDS `PubliclyAccessible: false` |
| 비밀 값이 Git에 없나? | DB 비밀번호와 JWT 키는 실행 때 생성해 SSM Parameter Store(SecureString)에만 저장. 서버의 `/etc/movie-app.env`는 권한 600. `.gitignore`에 `*.pem`, `.env.local`, `.env.production` 추가 |

### 테스트 통과
`./gradlew build` 테스트 14개 통과 (9주차 11개 + CORS 3개). 통과 화면은 9주차 `docs/week9/mission/13-tests-all-passed.png`와 같은 방식의 Gradle 리포트.

### 비용 확인과 리소스 정리 계획
- 예상 비용(서울 리전 기준 대략): EC2 t3.small 시간당 약 0.03달러, RDS db.t3.micro 시간당 약 0.02달러, 스토리지 20GB는 월 몇 달러 수준. 몇 시간 쓰면 수백~천 원대이고, 안 지우면 하루에 몇 천 원씩 나감.
- 모든 리소스에 `Project=umc-w10` 태그를 붙였음.
- 정리 순서: 점검과 캡처 → `infra/week10/99-cleanup.sh`로 **EC2 종료 → RDS 삭제(스냅샷 없음) → 보안 그룹 → S3 버킷 → SSM 파라미터 → IAM** 삭제 → 콘솔에서 남은 스토리지와 스냅샷이 없는지 확인.

### 화면과 설정 증거
- Swagger 화면(EC2 주소): `screenshots/01-swagger-on-ec2.png`
- 빌드와 테스트 통과(터미널): `screenshots/02-terminal-gradle-build-success.png` (`BUILD SUCCESSFUL`, 테스트 14개 실패 0)
- 배포 주소 핵심 요청/응답(터미널, 토큰 가림): `screenshots/03-terminal-api-check-deployed.png` (회원가입 201, 로그인 200, 토큰 없이 401, 평점·즐겨찾기 201, 중복 409, 검증 400)
- AWS 콘솔 EC2 실행 중 화면: `screenshots/04-aws-console-ec2-running.png` (계정 ID 가림)
- AWS 콘솔 보안 그룹: `screenshots/07-aws-console-security-groups.png`, DB 보안 그룹 인바운드는 3306 하나이고 소스가 앱 보안 그룹: `05-aws-console-db-sg-inbound.png`, RDS 화면에서도 인바운드 소스가 앱 보안 그룹뿐: `06-aws-console-rds-sg-only-app.png` (계정 ID 가림, DB 주소가 보이는 화면은 쓰지 않음)
- 보안 그룹 인바운드, RDS `PubliclyAccessible: false`, EC2 키 페어 없음: `aws-config-check.txt` (CLI 출력)
- 비용: Cost Explorer로 11월 일별 비용을 조회했더니 이번 실습 전까지 0달러였고, 오늘 사용분은 반영까지 약 하루가 걸려 아직 보이지 않았음. 정리 뒤 며칠 지나 다시 확인해야 함.

## 구성 파일
- `src/main/resources/application*.yml`: 환경 분리
- `config/WebConfig.java`: `frontend.origin`(환경 변수 `FRONTEND_ORIGIN`)을 CORS에 추가
- `infra/week10/`: 리소스 생성(`01-create.sh`), EC2 실행(`02-launch-ec2.sh`, `userdata.sh`), 정리(`99-cleanup.sh`)

## 🎯 핵심 키워드 (~했음)
- **개발 환경/운영 환경**: 코드는 같아도 DB 주소, 허용할 Origin, 비밀 값, 스키마 정책이 환경마다 달라서 프로필로 나눴음. 운영은 `ddl-auto: validate`로 두어 앱이 실제 데이터를 바꾸지 않게 했음.
- **빌드 산출물(JAR)**: `./gradlew build`가 컴파일, 테스트, 실행 가능한 JAR 생성까지 하고, EC2에는 JAR과 같은 메이저 버전의 JDK 21만 있으면 실행되는 것을 확인했음. 테스트가 실패하면 JAR이 만들어지지 않아서 배포 전 점검 역할도 했음.
- **EC2와 RDS**: EC2는 앱이 실행되는 곳, RDS는 데이터가 머무는 곳이고, 요청은 브라우저 → EC2 → RDS 순서로 흘렀음.
- **VPC와 보안 그룹**: 보안 그룹은 "누가 어느 포트로 들어올 수 있나"를 정하는 방화벽이었음. 앱 포트는 공개하고, DB 포트는 인터넷이 아니라 앱 보안 그룹만 소스로 지정했음.
- **환경변수와 비밀 값**: 비밀번호와 JWT 키는 코드/Git에 두지 않고 실행 환경으로 전달했음. 여기서는 SSM Parameter Store에 저장하고 서버가 시작할 때 읽어 권한 600 파일로 넘겼음.
- **CORS와 Origin**: CORS는 브라우저가 스스로에게 거는 제약이라 서버끼리 부르는 테스트나 Postman에서는 안 보임. Origin은 스킴+호스트+포트이고 경로는 붙이지 않음. 허용하지 않은 Origin의 사전 요청(OPTIONS)은 403이 나는 것을 테스트로 확인했음.

## 📢 학습 후기 (~했음)
1. 내 컴퓨터에서 성공한 테스트는 `localhost`의 로컬 DB를 쓰지만, 외부 주소의 요청은 보안 그룹, 환경 변수, DB 연결, CORS가 모두 맞아야 성공해서 확인할 것이 훨씬 많았음.
2. 가장 신경 쓴 부분은 HTTPS 프론트에서 HTTP API를 부를 때의 혼합 콘텐츠였음. 서버를 HTTPS로 바꾸는 대신 프론트의 같은 출처 프록시(`rewrites`)로 풀었고, 로컬에서 브라우저가 한 호스트로만 요청하는 것을 확인했음.
3. 배포 자체보다 "무엇을 어떻게 확인했는지"를 남기는 것이 중요했음. 점검 스크립트로 토큰은 가리고 상태 코드와 `code`만 기록해서 다시 따라 할 수 있게 했음.

## ⚡ 트러블슈팅 (~했음)
### No.1 점검 스크립트에서 `/members/undefined/ratings` 400
- **이슈**: 배포된 API를 점검하는데 유저별 평점 조회가 `GET /members/undefined/ratings`로 나가 400을 받았음.
- **원인**: 내 정보 조회(`/members/me`) 응답에 `memberId`가 없는데 점검 스크립트가 거기서 값을 읽으려 했음. 서버가 아니라 점검 코드의 문제였음.
- **해결**: 회원가입 응답의 `memberId`를 쓰도록 고쳐 다시 실행했고 200과 방금 등록한 평점이 보였음.
- **배운 점**: 오류 응답만 보지 말고 요청 주소가 의도한 값으로 만들어졌는지 먼저 확인해야 함.

### No.2 (사전 대응) 혼합 콘텐츠
- 증상은 아직 겪지 않고 워크북의 안내를 보고 미리 대응한 항목임. HTTPS 프론트가 `http://{EC2_IP}:8080`을 직접 부르면 브라우저가 차단할 수 있어서, 프론트에서 `/api/backend/*`로 요청하고 Vercel 서버가 대신 전달하게 했음.

## 선택 미션
`POST /movie-records` 배포 환경 롤백 점검은 하지 않았음.
