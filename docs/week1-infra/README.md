# 1주차 인프라 - 신뢰할 수 있는 배포 파이프라인 (1)

## 구성
```
사용자 → ALB(umc-alb, :80, umc-alb-sg)
          └ 타겟 그룹 umc-app-tg (:8080, 헬스체크 /health, deregistration_delay 30s)
              └ ASG umc-asg (min 2 / max 4 / desired 2, Launch Template umc-app-lt)
                  └ EC2 t3.small ×2 (Docker, umc-app-sg: ALB에서 오는 8080만 허용)
                        └ RDS MySQL 8.0 (umc-db, umc-db-sg: 앱 SG에서 오는 3306만 허용)
설정/비밀값: SSM Parameter Store /umc/*  (db-password, jwt-secret = SecureString)
이미지: ECR umc-movie  (태그 규칙: 버전-yy-mm-dd-N, 예: v1.0.1-26-11-16-2)
```
코드: `infra/` (env.sh, 01-base.sh, 02-alb.sh, swap.sh, userdata.sh, deploy.sh, 99-cleanup.sh)

## 4.2 최종 결과 (zero-downtime-lab, 20 rps, 대상 `GET /members/email/{email}`)
| 항목 | 단일 배포 (EC2 1대) | 무중단 배포 (ALB + ASG 2대) |
|---|---|---|
| 총 요청 | 2,001 | 6,000 |
| 실패 | 253 (network 236, timeout 17) | **0** |
| 실패율 | 13% | **0%** |
| 순단 | 1회 | **0회** |
| 총 다운타임 | 12.7초 | **0.0초** |
| p95 지연 | 52ms | 32ms |

캡처: `01-single-deploy-downtime.png`, `02-alb-rolling-zero-downtime.png`, 배포 로그 `deploy-run.log`
(캡처는 측정이 끝난 실행 결과를 측정 도구 화면에 다시 불러와 찍었음. 위쪽 설정 폼은 기본값으로 보임.)

## 핵심 키워드 (~했음)
- **무중단 배포**: 새 버전으로 바꾸는 동안에도 요청을 계속 받아 주는 배포 방식이라고 이해했음. 단일 서버는 컨테이너를 내렸다 올리는 동안 12.7초 끊겼음.
- **ALB / 타겟 그룹**: 요청을 여러 서버에 나눠 주고, 헬스체크(`/health`)에 실패한 서버는 자동으로 제외한다는 것을 확인했음.
- **Deregistration delay(draining)**: 타겟을 빼도 처리 중이던 요청은 30초 동안 끝낼 시간을 준다는 것을 배포 로그의 `draining...`으로 확인했음.
- **Rolling 배포**: 한 대를 빼고 → 교체하고 → 다시 넣는 것을 한 대씩 반복해서 항상 한 대 이상이 요청을 받게 하는 방식이었음.
- **Auto Scaling Group / Launch Template**: 서버 수를 유지하고, 새로 뜨는 서버를 같은 설정(user-data)으로 만들어 주는 장치라고 이해했음.
- **SSM Parameter Store**: 이미지 주소와 DB 비밀번호 같은 값을 코드/이미지 밖에 두고 서버가 시작할 때 읽게 했음. 비밀값은 SecureString으로 저장했음.
- **Graceful shutdown**: `server.shutdown=graceful`과 `docker stop -t 30`으로 종료 신호를 받으면 처리 중인 요청을 마친 뒤 내려가게 했음.

## 학습 후기 (~했음)
1. 배포할 때 서버를 한 대만 쓰면 12.7초 동안 253건이 실패한다는 것을 수치로 직접 확인했음. "잠깐이니까 괜찮다"고 생각했던 시간이 사용자 입장에서는 오류였음.
2. 서버를 두 대로 늘리는 것만으로는 부족하고, 앞에서 트래픽을 나눠 주고 빼 주는 ALB와 "빼고 → 바꾸고 → 넣고" 순서를 지키는 배포 스크립트가 있어야 0초가 된다는 것을 이해했음.
3. 헬스체크 경로가 인증 인터셉터에 막혀 있으면 서버가 정상이어도 ALB가 죽은 것으로 판단하기 때문에 `/health`를 공개 경로로 열어야 했음.

## 트러블슈팅 (~했음)
- **Docker 로그인 오류**: `docker login`이 Windows 자격증명 저장소 오류(`The stub received bad data`)로 실패했음. 저장소를 쓰지 않는 별도 `DOCKER_CONFIG`에 ECR 인증값을 직접 넣어서 푸시했음.
- **DB 이름 불일치**: `sql/01_schema.sql`이 `umc_movie` DB를 만들어서 RDS 기본 DB(`movie`)에는 테이블이 없었고, 앱이 `missing table [favorite]`로 계속 재시작했음. SSM의 `db-name`을 `umc_movie`로 고쳐서 해결했음.
- **측정 대상 선택**: 처음에 회원가입(POST)으로 측정했더니 비밀번호 해시(bcrypt) 때문에 t3.small이 20rps를 못 버텨서 배포와 상관없이 실패가 났음. 가벼운 조회 API로 바꿔서 배포 영향만 측정했음.
- **닉네임 길이**: 측정 본문의 닉네임에 uuid를 넣었다가 12자 제한 검증(400)에 걸렸음.
- **Git Bash 경로 변환**: SSM 파라미터 이름 `/umc/image`가 `C:/Program Files/Git/umc/image`로 바뀌어 오류가 났음. `MSYS_NO_PATHCONV=1`로 해결했음.
