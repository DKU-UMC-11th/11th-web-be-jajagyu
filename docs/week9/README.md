# 9주차 백엔드 - 함께 테스트하고 다듬기

## ☑️ 실습 인증

| 인증 항목 | 결과 | 캡처 |
|---|---|---|
| Swagger 문서 화면 전체 목록 | 인증/영화 기록/회원/즐겨찾기/평점 5개 묶음에 15개 API가 모두 표시됨. 토큰이 필요한 API에만 자물쇠가 붙음 | `01-swagger-all-apis.png` |
| 즐겨찾기 등록 API를 펼친 화면 | 설명, 요청 예시(`movieId: 550`), 201/401/409 응답 예시가 문서에 적힘 | `02-swagger-favorites-post-documented.png` |
| Authorize로 토큰을 넣고 `POST /favorites` 성공(201) | `COMMON201` | `03-swagger-favorites-201.png` |
| 한 번 더 호출해서 409 | `FAVORITE409_1` (문서에 적은 실패 응답 예시와 같음) | `04-swagger-favorites-409.png` |
| Authorize에서 Logout 후 호출 | 401 `AUTH401_2` | `05-swagger-favorites-401.png` |
| 단위/통합 테스트 모두 통과 | 11개 중 11개 성공 (단위 4, 통합 7) | `09-tests-green-again.png` (`05-tests-all-passed.png`도 같은 결과) |
| 중복 검사를 지웠을 때 실패한 테스트 | 11개 중 3개 실패 | `06-broken-summary.png` + 아래 오류 메시지 |

> 03~05 캡처의 curl 줄에는 테스트 계정의 토큰이 보임. 1시간 뒤 만료되고 내 컴퓨터의 서버에서만 유효한 값이라 괜찮지만, 신경 쓰이면 그 줄을 가려서 올릴 것.

### 중복 검사를 지웠을 때 (실습 6)
`FavoriteService.create()`의 `FAVORITE409_1` 던지는 `if` 블록을 주석 처리하고 `./gradlew test`를 실행했음. 결과는 `11 tests completed, 3 failed`였고, 원래대로 되돌리자 11개가 모두 초록불로 돌아왔음.

```
FavoriteApiTest > 이미 즐겨찾기한 영화를 다시 등록하면 409와 FAVORITE409_1을 응답한다 FAILED
  java.lang.AssertionError: JSON path "$.code" expected:<FAVORITE409_1> but was:<COMMON4091>

FavoriteServiceTest > 이미 즐겨찾기한 영화면 FAVORITE409_1 예외를 던지고 저장하지 않는다 FAILED
  java.lang.AssertionError: Expecting actual throwable to be an instance of: ApiException
  but was: java.lang.NullPointerException: Cannot invoke "Favorite.getFavoriteId()" because "favorite" is null
    at FavoriteResponse.from(FavoriteResponse.java:13)

FavoriteServiceTest > 아직 즐겨찾기하지 않은 영화면 즐겨찾기를 저장한다 FAILED
  org.mockito.exceptions.misusing.UnnecessaryStubbingException: Unnecessary stubbings detected.
```

**한 문장:** 통합 테스트는 DB UNIQUE 제약이 중복을 막았지만 응답 `code`가 약속한 `FAVORITE409_1`이 아니라 `COMMON4091`로 나와 실패했고, 단위 테스트는 가짜 Repository가 중복을 걸러 주는 코드가 없어져 예외 대신 저장 흐름으로 들어가 `NullPointerException`이 나서 실패했음.

## 🔥 필수 미션: 문서 채우고 평점 API 테스트하기
### 1) 문서화 (모든 API에 한 줄 설명 + 토큰 필요 여부 + 실패 응답)
| API | 토큰 | 문서에 적은 실패 응답 |
|---|---|---|
| `POST /ratings` 평점 등록 | 필요 🔒 | 400 `COMMON4001`, 401 `AUTH401_2/3/4`, 409 `RATING409_1` |
| `PATCH /ratings/{ratingId}` 수정 | 필요 🔒 | 400, 401, 403 `RATING403_1`, 404 `RATING404_1` |
| `DELETE /ratings/{ratingId}` 삭제 | 필요 🔒 | 401, 403 `RATING403_1`, 404 `RATING404_1` |
| `GET /members/{memberId}/ratings` 유저별 평점 | 공개 | 400(page/size), 404 `MEMBER404_1` |
| `GET /members/me` 내 정보 조회 | 필요 🔒 | 401, 404 `MEMBER404_1` |
| `PATCH /members/me` 내 정보 수정 | 필요 🔒 | 400, 401, 409 `MEMBER409_1` |
| `GET /favorites` 내 즐겨찾기 목록 | 필요 🔒 | 401 |
| `GET /favorites/{movieId}` 즐겨찾기 여부 | 필요 🔒 | 401 (미등록도 200 + `isFavorite: false`) |
| `DELETE /favorites/{movieId}` 해제 | 필요 🔒 | 401, 404 `FAVORITE404_1` |
| (추가) 회원가입, 로그인, 영화 기록 | 가입/로그인 공개, 영화 기록 🔒 | 400, 401 `AUTH401_1`, 409 |

- 컨트롤러에는 `@Tag`, `@Operation`, `@ApiResponses`를, 인증이 필요한 API에는 `@SecurityRequirement(name = "bearerAuth")`를 붙였음. 토큰에서 꺼내는 `memberId` 파라미터는 `@Parameter(hidden = true)`로 문서에서 숨겼음(프론트가 보낼 값이 아니기 때문).
- 요청 DTO에는 `@Schema(description, example)`로 입력 규칙과 예시 값을 넣어서 Swagger 입력창에 미리 채워지게 했음.
- 인프라용 `/health`는 `@Hidden`으로 문서에서 뺐음.

**문서화한 Swagger 화면 캡처 (`mission/`)**: 각 API를 펼쳐서 한 줄 설명, 자물쇠, 성공/실패 응답의 상태 코드와 `code`가 보이게 했음. 실패 응답에는 성공 모양의 자동 예시가 붙어 오해를 줘서, 설명(상태 코드 + `code`)만 보이게 고쳤음.
| 묶음 | 캡처 |
|---|---|
| 평점 (등록/수정/삭제/유저별 조회) | `mission/10-swagger-ratings-documented.png` |
| 회원 (내 정보 조회/수정 등) | `mission/11-swagger-members-documented.png` |
| 즐겨찾기 (목록/여부/해제/등록) | `mission/12-swagger-favorites-all-documented.png` |

### 2) 평점 테스트 (제출물: 테스트 코드)
| 구분 | 테스트 | 파일 |
|---|---|---|
| 단위 | 같은 영화에 평점을 중복 등록하면 409와 `RATING409_1` 예외를 던지고 저장하지 않는다 | `src/test/java/com/umc/movie/service/RatingServiceTest.java` |
| 단위 | 남의 평점을 수정하려 하면 403과 `RATING403_1` 예외를 던지고 평점을 바꾸지 않는다 | 같은 파일 |
| 통합 | 토큰 없이 평점을 등록하면 401과 `AUTH401_2`를 응답하고 저장하지 않는다 | `src/test/java/com/umc/movie/controller/RatingApiTest.java` |
| 통합 | 토큰을 담아 평점을 등록하면 201과 저장된 별점을 응답한다 | 같은 파일 |

실습 테스트도 함께 만들었음: `FavoriteServiceTest`(단위 2), `FavoriteApiTest`(통합 5: 401, 201, 409, 여부 조회 200 false, Swagger 공개 경로).

실행: `./gradlew test` → 11개 모두 통과 (`mission/13-tests-all-passed.png`).

## 🎯 핵심 키워드 (~했음)
- **Swagger / OpenAPI**: OpenAPI는 API를 설명하는 규격(JSON, `/v3/api-docs`)이고 Swagger UI는 그 JSON을 사람이 보기 좋게 그려 주는 화면(`/swagger-ui.html`)이었음. 코드를 읽어 문서를 만들어서 손으로 쓴 표처럼 코드와 어긋나지 않고, Try it out으로 Postman 없이 바로 호출할 수 있었음. 다만 설명, 예시, 실패 응답은 사람이 적어야 해서 토큰 필요 여부 같은 정보는 직접 챙겨야 했음.
- **단위 테스트**: 클래스 하나(주로 Service)의 판단을 의존 대상을 가짜로 바꿔서 빠르게 확인했음. 중복이면 예외를 던지고 저장하지 않는지처럼 DB 없이 확인할 수 있었음. URL 오타나 인증 설정 누락은 잡지 못함.
- **통합 테스트**: 컨트롤러, 인터셉터(인증), 검증, DB까지 진짜로 돌려서 요청부터 응답까지 전체 흐름을 확인했음. 느리지만 "연결이 틀렸다"를 잡음. 개발 DB 대신 H2 메모리 DB와 `@Transactional`로 데이터가 남지 않게 했음.
- **Mock, Stub**: 둘 다 진짜 대신 끼우는 가짜인데, Stub은 "이렇게 대답해라"를 정해 두는 것(`given(...).willReturn(...)`), Mock은 호출됐는지까지 검증하는 것(`verify(...)`)으로 이해했음. Mockito의 `@Mock`은 두 역할을 다 할 수 있었음.
- **given-when-then**: 상황을 만들고(given), 동작을 실행하고(when), 결과를 확인(then)하는 구조로, Postman으로 하던 "이 상태에서 이걸 누르면 이게 나와야 해"를 코드로 옮긴 것이었음. 테스트 이름도 이 문장으로 써서 실패했을 때 무엇이 깨졌는지 바로 읽히게 했음.
- **회귀 테스트**: 예전에 되던 것이 지금도 되는지 확인하는 테스트였음. 실습 6에서 중복 검사를 지우자 사람이 아니라 테스트가 먼저 알려 줬음.

## 📢 학습 후기 (~했음)
1. 중복 검사를 지웠을 때 통합 테스트는 DB UNIQUE 제약 덕분에 중복 저장은 막혔지만 응답 code가 `COMMON4091`로 바뀌어서 실패했음. 그래서 "DB 제약이 마지막 안전망"과 "서비스의 사전 검사는 약속된 오류 code를 주는 역할"이 서로 다른 일이라는 것을 실제 결과로 확인했음.
2. 단위 테스트에서 가짜 Repository는 시킨 대로만 대답해서, 코드를 지우면 예외 대신 NPE가 났음. 실패 메시지에 무엇을 기대했고 무엇이 왔는지가 적혀 있어서 원인을 바로 찾을 수 있었음.
3. 문서를 코드에 붙이니 컨트롤러가 길어졌지만, 프론트가 "토큰 필요한가, 실패하면 어떤 code인가"를 코드를 열어 보지 않고 알 수 있게 된 점이 가장 큰 변화였음.
4. 아직 이해가 부족한 부분은 Mockito의 엄격한 stub 검사(`UnnecessaryStubbingException`)가 왜 필요한지임. 쓰지 않는 stub이 남으면 테스트가 실제 코드와 어긋난 신호라는 설명은 이해했지만 더 써 보고 싶음.

## ⚡ 트러블슈팅 (~했음)
### No.1 Swagger 어노테이션이 `@Hidden`을 파라미터에 못 씀
- **이슈**: 토큰에서 꺼내는 `memberId` 파라미터를 문서에서 숨기려고 `@Hidden @RequestAttribute(...)`를 붙였더니 컴파일 오류가 났음.
  `error: annotation interface not applicable to this kind of declaration`
- **원인**: `@Hidden`은 클래스/메서드용이고 파라미터에는 쓸 수 없음.
- **해결**: 파라미터에는 `@Parameter(hidden = true)`를 썼음. 컴파일 통과.
- **배운 점**: 같은 "숨김"이라도 대상(클래스, 메서드, 파라미터)에 따라 쓰는 어노테이션이 다름.

### No.2 `@Schema`가 중복되어 컴파일 오류
- **이슈**: DTO에 예시 값을 넣다가 `error: Schema is not a repeatable annotation interface`가 났음.
- **원인**: 스크립트로 같은 `@Schema`를 두 번 넣었음. 같은 변경을 다시 적용하면 중복되는 것을 확인하지 않았음.
- **해결**: 연속으로 같은 줄을 제거하고 `git diff`로 의도한 줄만 남았는지 확인했음.
- **배운 점**: 자동으로 파일을 고친 뒤에는 diff로 한 번씩 확인해야 함.

### No.3 중복 검사를 지우자 예상보다 많은 테스트가 실패
- **이슈**: 중복 테스트 2개만 실패할 줄 알았는데 `createFavorite` 단위 테스트까지 3개가 실패했음. `UnnecessaryStubbingException: Unnecessary stubbings detected.`
- **원인**: 중복 검사 코드를 지우자 `existsBy...` stub이 한 번도 호출되지 않았고, Mockito가 쓰지 않은 stub을 오류로 처리했음.
- **해결**: 실습 6의 목적이어서 코드를 되돌렸고 11개가 모두 통과했음.
- **배운 점**: 테스트가 실패하는 개수는 코드와 테스트가 얼마나 단단히 연결돼 있는지도 알려 줌.

## 참고
- 선택 미션(`POST /movie-records` 트랜잭션 롤백 테스트)은 하지 않았음.
- 실행: `./gradlew test`, 서버를 켠 뒤 `http://localhost:8080/swagger-ui.html`
