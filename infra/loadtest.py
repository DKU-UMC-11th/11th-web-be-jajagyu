"""2주차/3주차 한계 측정 구동기.
zero-downtime-lab(localhost:9376)에 단계별 시나리오를 보낸다. 단계마다 회원을 새로 만든다.
(평점에 (회원, 영화) 유니크 제약이 있어서, 같은 회원으로 {{counter}} 를 다시 쓰면 409 가 나온다.)

사용: python infra/loadtest.py <ALB주소> <출력.json> [rps,rps,...] [durationSec] [warmupSec]
(재시작 직후에는 JVM 이 덜 데워져 있어서, warmupSec 을 주면 측정 전에 200rps 로 먼저 데운다.)
예)   python infra/loadtest.py umc-alb-xxxx.elb.amazonaws.com docs/week2-infra/loadtest-before.json 200,400,600,800 40
"""
import json, sys, time, uuid, urllib.request, urllib.error

LAB = "http://localhost:9376"


def call(method, url, body=None, headers=None):
    req = urllib.request.Request(url, method=method, data=json.dumps(body).encode() if body is not None else None,
                                 headers={"Content-Type": "application/json", **(headers or {})})
    try:
        with urllib.request.urlopen(req, timeout=30) as r:
            return r.status, json.loads(r.read() or b"null")
    except urllib.error.HTTPError as e:
        return e.code, json.loads(e.read() or b"null")


def new_member(alb):
    tag = uuid.uuid4().hex[:8]
    email, pw = f"lab-{tag}@test.local", "Test1234!"
    s, _ = call("POST", f"http://{alb}/members", {"email": email, "password": pw, "nickname": f"u{tag[:6]}"})
    assert s == 201, f"signup {s}"
    s, b = call("POST", f"http://{alb}/auth/login", {"email": email, "password": pw})
    assert s == 200, f"login {s}"
    return b["result"]["accessToken"]


def main():
    alb, out = sys.argv[1], sys.argv[2]
    steps = [int(x) for x in (sys.argv[3] if len(sys.argv) > 3 else "200,400,600,800").split(",")]
    dur = int(sys.argv[4]) if len(sys.argv) > 4 else 40
    warm = int(sys.argv[5]) if len(sys.argv) > 5 else 0
    results = []
    for rps in ([0] if warm else []) + steps:
        tok = new_member(alb)
        is_warm = rps == 0 and warm > 0
        if is_warm:
            rps = 200
        # 시작 전에 한 건을 손으로 보내 201 확인 (movieId 는 부하 쪽 {{counter}} 와 겹치지 않게 큰 값)
        s, _ = call("POST", f"http://{alb}/movie-records", {"movieId": 999999, "score": 5, "comment": "t", "addToFavorites": True},
                    {"Authorization": f"Bearer {tok}"})
        assert s == 201, f"precheck {s}"
        scenario = {
            "name": f"한계 측정 {rps}rps",
            "target": {"url": f"http://{alb}/movie-records", "method": "POST",
                       "headers": {"Content-Type": "application/json", "Authorization": f"Bearer {tok}"},
                       "body": '{"movieId": {{counter}}, "score": 5, "comment": "lab", "addToFavorites": true}',
                       "timeoutMs": 5000},
            "success": {"statusCodes": [200, 201]},
            "load": {"rps": rps, "durationSec": warm if is_warm else dur},
            "analysis": {"slowThresholdMs": 1000, "baselineSec": 8, "minConsecutiveFailures": 3},
        }
        s, b = call("POST", f"{LAB}/api/runs", scenario)
        assert s == 201, f"run start {s} {b}"
        rid, t0 = b["runId"], int(time.time())
        while True:
            time.sleep(3)
            _, sm = call("GET", f"{LAB}/api/runs/{rid}")
            if sm.get("status") not in ("running", "pending", None) and sm.get("finishedAt") or sm.get("status") in ("finished", "done", "completed", "stopped"):
                break
        t1 = int(time.time())
        if is_warm:
            print("[warmup done]", flush=True); time.sleep(10); continue
        results.append({"rps": rps, "runId": rid, "start": t0, "end": t1, "summary": sm})
        print(f"[{rps} rps] status={sm.get('status')}", flush=True)
        json.dump(results, open(out, "w", encoding="utf-8"), ensure_ascii=False, indent=2)
        time.sleep(30)  # 단계 사이에 식힌다 (풀/큐 정리)


main()
