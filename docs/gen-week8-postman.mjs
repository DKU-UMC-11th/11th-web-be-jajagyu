// node docs/gen-week8-postman.mjs  ->  docs/week8-postman-collection.json 생성
import fs from "fs";

const bearer = [{ key: "Authorization", value: "Bearer {{token}}" }];
const json = [{ key: "Content-Type", value: "application/json" }];

const req = (name, method, path, { body, auth = true, expect, script = [] } = {}) => ({
  name,
  event: [{
    listen: "test",
    script: { type: "text/javascript", exec: [
      `pm.test("status ${expect}", () => pm.response.to.have.status(${expect}));`, ...script,
    ] },
  }],
  request: {
    method,
    header: [...(auth ? bearer : []), ...(body ? json : [])],
    body: body ? { mode: "raw", raw: JSON.stringify(body, null, 2) } : undefined,
    url: { raw: `{{baseUrl}}${path}`, host: ["{{baseUrl}}"], path: path.split("/").filter(Boolean) },
  },
});

const code = (c) => `pm.test("code ${c}", () => pm.expect(pm.response.json().code).to.eql("${c}"));`;

const items = [
  {
    name: "0-1. 회원가입 (매번 새 계정 생성)",
    event: [
      { listen: "prerequest", script: { type: "text/javascript", exec: [
        "pm.collectionVariables.set('email', 'w8_' + Date.now() + '@example.com');",
      ] } },
      { listen: "test", script: { type: "text/javascript", exec: [
        "pm.test('status 201', () => pm.response.to.have.status(201));",
      ] } },
    ],
    request: {
      method: "POST", header: json,
      body: { mode: "raw", raw: '{\n  "email": "{{email}}",\n  "nickname": "neon",\n  "password": "{{password}}"\n}' },
      url: { raw: "{{baseUrl}}/members", host: ["{{baseUrl}}"], path: ["members"] },
    },
  },
  {
    name: "0-2. 로그인 (토큰 자동 저장)",
    event: [{ listen: "test", script: { type: "text/javascript", exec: [
      "pm.test('status 200', () => pm.response.to.have.status(200));",
      "pm.collectionVariables.set('token', pm.response.json().result.accessToken);",
    ] } }],
    request: {
      method: "POST", header: json,
      body: { mode: "raw", raw: '{\n  "email": "{{email}}",\n  "password": "{{password}}"\n}' },
      url: { raw: "{{baseUrl}}/auth/login", host: ["{{baseUrl}}"], path: ["auth", "login"] },
    },
  },
  req("1. POST /favorites 성공 (201)", "POST", "/favorites", { body: { movieId: 550 }, expect: 201 }),
  req("2. POST /favorites 중복 (409 FAVORITE409_1)", "POST", "/favorites", { body: { movieId: 550 }, expect: 409, script: [code("FAVORITE409_1")] }),
  req("3. GET /favorites 내 목록 (200)", "GET", "/favorites", { expect: 200 }),
  req("4. GET /favorites/550 (isFavorite: true)", "GET", "/favorites/550", {
    expect: 200, script: ["pm.test('isFavorite true', () => pm.expect(pm.response.json().result.isFavorite).to.eql(true));"],
  }),
  req("5. DELETE /favorites/550 해제 (200, result null)", "DELETE", "/favorites/550", { expect: 200 }),
  req("6. GET /favorites/550 (isFavorite: false)", "GET", "/favorites/550", {
    expect: 200, script: ["pm.test('isFavorite false', () => pm.expect(pm.response.json().result.isFavorite).to.eql(false));"],
  }),
  req("7. GET /favorites 빈 배열 (200, [])", "GET", "/favorites", { expect: 200 }),
  req("8. POST /movie-records 성공 (201, rating + favorite)", "POST", "/movie-records", {
    body: { movieId: 238, score: 5, comment: "다시 보고 싶은 영화입니다.", addToFavorites: true }, expect: 201,
  }),
  req("9. POST /movie-records 중복 (409 RATING409_1)", "POST", "/movie-records", {
    body: { movieId: 238, score: 5, comment: "다시 보고 싶은 영화입니다.", addToFavorites: true }, expect: 409, script: [code("RATING409_1")],
  }),
  { name: "── 실습 4: 실패 상황 ──", item: [
    req("A. 토큰 없이 POST /favorites (401 AUTH401_2)", "POST", "/favorites", { body: { movieId: 550 }, auth: false, expect: 401, script: [code("AUTH401_2")] }),
    req("B. 즐겨찾기 안 한 영화 여부 (200, false)", "GET", "/favorites/999", { expect: 200 }),
    req("C. 없는 즐겨찾기 해제 (404 FAVORITE404_1)", "DELETE", "/favorites/999", { expect: 404, script: [code("FAVORITE404_1")] }),
    req("D. movieId 0 전송 (400)", "POST", "/favorites", { body: { movieId: 0 }, expect: 400 }),
  ] },
];

const collection = {
  info: {
    name: "UMC 8주차 - 즐겨찾기 / 영화 기록",
    schema: "https://schema.getpostman.com/json/collection/v2.1.0/collection.json",
  },
  variable: [
    { key: "baseUrl", value: "http://localhost:8080" },
    { key: "email", value: "" },
    { key: "password", value: "Test1234!" },
    { key: "token", value: "" },
  ],
  item: items,
};

fs.writeFileSync(new URL("./week8-postman-collection.json", import.meta.url), JSON.stringify(collection, null, 2));
console.log("ok");
