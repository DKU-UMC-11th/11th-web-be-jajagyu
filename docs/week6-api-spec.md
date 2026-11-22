# 6주차 API 명세 (영화 평점 서비스)

Base URL: `http://localhost:8080`
인증: 없음 (7주차에 토큰으로 대체 예정, 지금은 `memberId`를 경로로 받음)
Content-Type: `application/json` (요청 본문이 있는 API)

## 공통 응답 형식

성공과 실패 모두 같은 틀을 사용한다. (조회 API의 성공 응답과 204는 제외)

```json
{ "isSuccess": true, "code": "COMMON201", "message": "...", "result": {} }
```

| 필드 | 설명 |
|---|---|
| isSuccess | 성공 여부 |
| code | 결과 코드 (아래 오류 코드 표 참고) |
| message | 사람이 읽는 설명 (실패 시 이유) |
| result | 성공 시 데이터, 실패 시 `null` |

## API 목록

| 기능 | Method | 경로 | 성공 상태 |
|---|---|---|---|
| 회원가입 | POST | `/members` | 201 Created |
| 평점 등록 | POST | `/members/{memberId}/ratings` | 201 Created |
| 평점 수정 | PATCH | `/members/{memberId}/ratings/{ratingId}` | 200 OK |
| 평점 삭제 | DELETE | `/members/{memberId}/ratings/{ratingId}` | 204 No Content |
| 평점 조회 (5주차) | GET | `/members/{memberId}/ratings` | 200 OK |

---

## 1. 회원가입 `POST /members`

### 요청 본문

| 필드 | 타입 | 필수 | 규칙 |
|---|---|---|---|
| email | string | O | 이메일 형식, 빈 값 불가 |
| password | string | O | 대문자/소문자/숫자/특수문자(`!@#$%^&*`) 모두 포함, 8자 이상 |
| nickname | string | O | 2자 이상 12자 이하 |

```json
{ "email": "umc@example.com", "password": "Umc!1234", "nickname": "moviefan" }
```

### 성공 201

비밀번호는 응답에 포함하지 않고, DB에는 bcrypt 해시(60자)만 저장한다.

```json
{
  "isSuccess": true,
  "code": "COMMON201",
  "message": "회원가입에 성공했습니다.",
  "result": { "memberId": 1, "email": "umc@example.com", "nickname": "moviefan" }
}
```

### 실패

| 상태 | code | 원인 |
|---|---|---|
| 400 | COMMON4001 | 입력 규칙 위반 (message에 위반 이유) |
| 400 | COMMON4002 | 요청 본문 JSON 형식 오류 |
| 409 | MEMBER4091 | 이미 사용 중인 이메일 |
| 409 | MEMBER4092 | 이미 사용 중인 닉네임 |

```json
{ "isSuccess": false, "code": "MEMBER4091", "message": "이미 사용 중인 이메일입니다.", "result": null }
```

---

## 2. 평점 등록 `POST /members/{memberId}/ratings`

### 경로 변수
- `memberId`: 평점을 남기는 회원 ID

### 요청 본문

| 필드 | 타입 | 필수 | 규칙 |
|---|---|---|---|
| movieId | number | O | TMDB 영화 ID, 양수 |
| score | number | O | 1 이상 5 이하 정수 |
| comment | string | X | 500자 이하 |

```json
{ "movieId": 550, "score": 5, "comment": "좋았음" }
```

### 성공 201 (`result`는 생성된 ratingId)

```json
{ "isSuccess": true, "code": "COMMON201", "message": "평점 등록에 성공했습니다.", "result": 4 }
```

### 실패

| 상태 | code | 원인 |
|---|---|---|
| 400 | COMMON4001 | 별점 범위, 후기 길이, 필수값 누락 등 |
| 400 | COMMON4002 | 요청 본문 JSON 형식 오류 |
| 404 | COMMON404 | 존재하지 않는 회원 |
| 409 | RATING4091 | 같은 회원이 같은 영화에 이미 평점 등록 |

---

## 3. 평점 수정 `PATCH /members/{memberId}/ratings/{ratingId}`

### 요청 본문

| 필드 | 타입 | 필수 | 규칙 |
|---|---|---|---|
| score | number | O | 1 이상 5 이하 정수 |
| comment | string | X | 500자 이하 (생략하면 후기가 비워짐) |

```json
{ "score": 3, "comment": "다시 보니 별로" }
```

### 성공 200

```json
{ "isSuccess": true, "code": "COMMON200", "message": "평점 수정에 성공했습니다.", "result": null }
```

### 실패

| 상태 | code | 원인 |
|---|---|---|
| 400 | COMMON4001 | 별점 범위, 후기 길이 위반 |
| 403 | COMMON403 | 평점 작성자가 `memberId`와 다름 |
| 404 | COMMON404 | 존재하지 않는 평점 |

---

## 4. 평점 삭제 `DELETE /members/{memberId}/ratings/{ratingId}`

요청 본문 없음.

### 성공 204 (본문 없음)

### 실패

| 상태 | code | 원인 |
|---|---|---|
| 403 | COMMON403 | 평점 작성자가 `memberId`와 다름 |
| 404 | COMMON404 | 존재하지 않는 평점 |

---

## 5. 평점 조회 (5주차) `GET /members/{memberId}/ratings`

- 쿼리: `page`(0 이상), `size`(1~100) 선택. 없으면 전체를 최신순으로 반환
- 성공 200: 평점 배열 (감싸지 않은 배열)

```json
[{ "ratingId": 4, "movieId": 550, "score": 3, "comment": "edit", "createdAt": "2026-11-03T16:27:25", "updatedAt": "2026-11-03T16:27:25" }]
```

- 실패: 존재하지 않는 회원 404 (`COMMON404`), 잘못된 page/size 400 (`COMMON400`)

---

## 오류 코드 정리

| code | 상태 | 의미 |
|---|---|---|
| COMMON4001 | 400 | 입력 검증 실패 |
| COMMON4002 | 400 | 요청 본문 형식 오류 |
| COMMON403 | 403 | 본인 평점이 아님 |
| COMMON404 | 404 | 대상 없음 (회원/평점) |
| MEMBER4091 | 409 | 이메일 중복 |
| MEMBER4092 | 409 | 닉네임 중복 |
| RATING4091 | 409 | 평점 중복 |
| COMMON4091 | 409 | 그 외 DB 유니크 제약 위반 |

## 검증 계층

1. DTO 검증(`@Valid`): 형식, 범위 → 400
2. 서비스 검증: 존재 여부, 중복, 소유자 → 403/404/409
3. DB 제약: `UNIQUE`(이메일, 닉네임, member+movie). 동시 요청으로 1, 2번을 통과해도 DB가 막고, 전역 예외 처리가 같은 형식의 409로 바꿔 준다.
