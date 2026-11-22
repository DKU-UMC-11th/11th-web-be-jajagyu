# 8주차 Postman 실습 인증 가이드

## 준비
1. MySQL 실행, 백엔드 8080 실행 (JWT 환경 변수 포함)
2. Postman → Import → `docs/week8-postman-collection.json`
3. 컬렉션을 열고 순서대로 **Send** (또는 컬렉션 Run). 회원가입 → 로그인에서 토큰이 자동 저장되고, 이후 요청에 자동으로 붙는다.
   - 실행할 때마다 새 계정을 만들기 때문에 항상 깨끗한 상태에서 시작한다.

## 캡처 목록 (실습 인증 순서)
| 인증 항목 | 요청 |
|---|---|
| POST /favorites 성공 응답 | `1. POST /favorites 성공` |
| 같은 요청의 중복 오류 응답 | `2. POST /favorites 중복` |
| GET /favorites 목록 응답 | `3. GET /favorites` |
| GET /favorites/{movieId} 여부 응답 | `4. GET /favorites/550` |
| DELETE /favorites/{movieId} 해제 응답 | `5. DELETE /favorites/550` |
| POST /movie-records 성공 (rating + favorite) | `8. POST /movie-records 성공` |
| (미션) 영화 기록 중복 | `9. POST /movie-records 중복` |
| (실습 4) 실패 상황 | `A`~`D` 폴더 |

> 2번, 4번 캡처는 5번 해제 전에 찍어야 한다. 순서대로 Send 하면 된다.
> 3번 목록에는 550번 영화가 1개 보여야 하고, 7번 목록은 `[]` 이다.

## 트랜잭션 코드 캡처
`src/main/java/com/umc/movie/service/MovieRecordService.java` 의 `@Transactional` 이 붙은 `create()` 메서드.

**한 문장:** 평점과 즐겨찾기가 하나의 사용자 행동이므로, 둘 중 하나만 저장되는 어중간한 상태를 막으려고 `@Transactional` 하나로 묶어 모두 저장하거나 모두 취소(rollback)되게 했다.

## 학습 후기 예시 (~했음)
1. 트랜잭션이 없으면 평점만 저장되고 즐겨찾기는 저장되지 않는 상황이 생겨서, 사용자가 의도한 기록과 DB 상태가 달라질 수 있음을 알았음.
2. 서버의 중복 검사는 `FAVORITE409_1` 같은 명확한 오류 메시지를 주기 위한 것이고, DB UNIQUE 제약은 동시 요청까지 막는 마지막 안전망이라 둘 다 둔다는 것을 이해했음.
