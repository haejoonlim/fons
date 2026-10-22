#!/usr/bin/env python3
"""server.py — 테스트 센터 정적 서빙 + 실시간 시뮬·스냅샷·게이트 API (폰즈 · 2026-10-17)

원본 저장소(soul-commander)의 design-docs/_tools/gacha_server.py 를 폰즈로 옮긴 것.
바뀐 것은 **경로와 게이트 목록**뿐이고 API 계약은 그대로다.

실행:
    ./.venv/bin/python sim/center/server.py [포트]      (기본 8741)
    → http://localhost:8741/  (= test_center.html)

정적 루트는 sim/center/pages/ 다. 탭 HTML·gacha.html·생태도감.html·직업트리_전체도.html 이
모두 거기 있으므로 iframe 은 같은 폴더 상대경로로 열린다 (원본의 "루트 밖 HTML 허용" 규칙은
필요 없어져 지웠다 — 경로 탈출 구멍도 함께 사라진다).

API:
    GET  /api/sims               시뮬 레지스트리 (이름·설명·조절 파라미터 규격)
    GET  /api/sim/<이름>[?k=v]   시뮬 1개 실시간 실행 → {exit·seconds·stdout·stderr·cmd}
    POST /api/snapshots          전 시뮬 재실행 → pages/snapshots.json·js 재생성 (폴링)
    GET  /api/snapshots/status
    POST /api/gates[?only=<id>]  폰즈 게이트 실행 (폴링)
    GET  /api/gates/status
    GET  /api/gate-ledger?limit=20  gate_all 런 원장 + 추이
    GET  /__gacha_hash           gacha.html 해시 (파일 저장 → 자동 리로드)

게이트 판정식은 여기서 **다시 구현하지 않는다**. 원장 판정은 tools/gate_all.py 의
ledger_read/ledger_trend 를 그대로 쓴다 — 두 구현이 갈라지면 화면은 초록인데 게이트가
우는 상태가 조용히 생긴다. 단계마다 그 스크립트를 서브프로세스로 돌릴 뿐이다.
"""
import hashlib
import http.server
import importlib.util
import json
import os
import subprocess
import sys
import threading
import time
import urllib.parse
import uuid

HERE = os.path.dirname(os.path.abspath(__file__))            # sim/center
REPO = os.path.normpath(os.path.join(HERE, "..", ".."))      # 폰즈 루트
PAGES = os.path.join(HERE, "pages")                          # 정적 루트
sys.path.insert(0, HERE)
from run_snapshots import SIMS, run_one, execute, write_outputs  # noqa: E402

PORT = int(sys.argv[1]) if len(sys.argv) > 1 else 8741

# 시뮬별 조절 파라미터 규격 — (키, 라벨, 기본값, 최소, 최대)
# base args(SIMS)에 기본값이 반영돼 있어 미지정 시 그대로, 지정 시 그 위치만 교체한다.
SIM_PARAMS = {
    "gacha": [("floor", "층수", 50, 1, 100), ("pulls", "연차수", 10, 1, 50)],
    "proficiency": [("n", "영웅수", 2000, 100, 10000), ("days", "일수", 30, 1, 365)],
}
SIM_DESC = {n: d for n, _, d in SIMS}
SIM_BASE_ARGS = {n: list(a) for n, a, _ in SIMS}
SIM_LOCK = threading.Lock()  # 동시 실행 1개 — 몬테카를로 시뮬 병행은 CPU 포화라 차단

# ── 폰즈 게이트 ────────────────────────────────────────────────────────────────
# (id, 제목, 실행 인수, 화면에 보여줄 명령, 상한 초)
#   · docs·gacha 는 tools/gate_all.py 의 단계와 **같은 스크립트**다 — 여기서 따로 판정하지 않는다.
#   · godot 은 Godot 임포트 + GUT (수 분) — 스냅샷에는 넣지 않고 여기서만 돌린다.
#   · review 는 advisory(판단이 섞인 권고)지만 화면에서는 실패로 보이므로 제목에 그렇게 적는다.
GATES = [
    ("docs", "필수 산출물·구조·데이터", ["tools/check_docs.py"], "python3 tools/check_docs.py", 120),
    ("pages", "테스트 센터 페이지 내장값 ↔ data/",
     ["sim/center/sync_pages.py", "--quiet"], "python3 sim/center/sync_pages.py", 120),
    ("gacha", "소환 규칙 재현 (확정 #32·#11)", ["sim/gacha.py"], "python3 sim/gacha.py", 120),
    ("review", "문서 기계 검수 (advisory — 실패가 곧 빌드 실패는 아님)",
     ["tools/review_docs.py"], "python3 tools/review_docs.py", 120),
    ("env", "툴체인 doctor", ["tools/check_env.py"], "python3 tools/check_env.py", 120),
    ("godot", "Godot 임포트 + GUT", ["tools/test_godot.sh"], "bash tools/test_godot.sh", 900),
    ("all", "커밋 전 전체 (gate_all)", ["tools/gate_all.py"],
     "python3 tools/gate_all.py", 300),
]
GATE_CMD = {g[0]: g[2] for g in GATES}

SNAP_JOB = {"id": None, "running": False, "done": False, "error": None,
            "startedAt": None, "finishedAt": None, "result": None}
SNAP_LOCK = threading.Lock()
GATE_JOB = {"id": None, "running": False, "done": False, "error": None,
            "startedAt": None, "finishedAt": None, "result": None, "only": ""}
JOB_LOCK = threading.Lock()


def _gate_all_module():
    """tools/gate_all.py 를 모듈로 읽는다 — 원장 판정의 단일 출처(다시 구현하지 않는다)."""
    path = os.path.join(REPO, "tools", "gate_all.py")
    spec = importlib.util.spec_from_file_location("gate_all", path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def build_args(name, qs):
    """쿼리스트링 → 시뮬 인수 리스트. (args, None) 또는 (None, 에러메시지)"""
    if name not in SIM_BASE_ARGS:
        return None, f"알 수 없는 시뮬: {name} (가능: {', '.join(SIM_BASE_ARGS)})"
    args = list(SIM_BASE_ARGS[name])
    specs = SIM_PARAMS.get(name, [])
    known = {k for k, *_ in specs}
    unknown = set(qs) - known
    if unknown:
        return None, (f"지원하지 않는 파라미터: {', '.join(sorted(unknown))} "
                      f"(가능: {', '.join(sorted(known)) or '없음'})")
    for i, (key, label, default, lo, hi) in enumerate(specs):
        raw = (qs.get(key) or [None])[0]
        if raw is None:
            continue
        try:
            v = int(raw)
        except ValueError:
            return None, f"{label}({key})는 정수여야 합니다"
        if not lo <= v <= hi:
            return None, f"{label}({key})는 {lo}~{hi} 범위여야 합니다"
        args[1 + i] = str(v)
    return args, None


class CenterHandler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=PAGES, **kwargs)

    def do_GET(self):
        parsed = urllib.parse.urlparse(self.path)
        path = parsed.path.rstrip("/")
        if path == "":       # "/" → 센터 입구
            return self._redirect("/test_center.html")
        if path == "/__gacha_hash":
            return self._gacha_hash()
        if path == "/api/sims":
            return self._api_sims()
        if path == "/api/snapshots/status":
            return self._api_snap_status()
        if path == "/api/gates/status":
            return self._api_job_status(GATE_JOB)
        if path == "/api/gate-ledger":
            return self._api_gate_ledger()
        if path.startswith("/api/sim/"):
            name = urllib.parse.unquote(path.split("/")[-1])
            return self._api_sim(name, urllib.parse.parse_qs(parsed.query))
        super().do_GET()

    def do_POST(self):
        p = urllib.parse.urlparse(self.path).path.rstrip("/")
        if p == "/api/snapshots":
            return self._api_snapshots()
        if p == "/api/gates":
            return self._api_gates()
        self.send_error(404)

    # ── 게이트 ────────────────────────────────────────────────────────────
    def _api_gates(self):
        qs = urllib.parse.parse_qs(urllib.parse.urlparse(self.path).query)
        only = (qs.get("only", [""])[0] or "").strip()
        known = {g[0] for g in GATES}
        if only and only not in known:
            return self._json(400, json.dumps(
                {"error": f"그런 게이트가 없다: {only}", "known": sorted(known)},
                ensure_ascii=False))
        label = f"게이트 {only} 단독" if only else "게이트 " + "·".join(g[0] for g in GATES)
        with JOB_LOCK:
            GATE_JOB["only"] = only
        self._start_job(GATE_JOB, _gate_worker, label)

    def _api_gate_ledger(self):
        qs = urllib.parse.parse_qs(urllib.parse.urlparse(self.path).query)
        try:
            limit = max(1, min(200, int(qs.get("limit", ["20"])[0])))
        except ValueError:
            limit = 20
        try:
            GA = _gate_all_module()
        except Exception as exc:  # 원장 모듈이 깨졌다고 서버가 죽으면 안 된다
            return self._json(200, json.dumps(
                {"error": f"gate_all.py 를 읽지 못했습니다: {exc}", "total": 0,
                 "runs": [], "counts": {}, "streak": {}, "resolved": [], "gone": [],
                 "goneSkipped": False, "passedRuns": 0, "latestOk": None,
                 "path": "tools/gate_ledger.jsonl"}, ensure_ascii=False))
        recs = GA.ledger_read()
        window = recs[-limit:]
        t = GA.ledger_trend(window)
        runs, prev = [], None
        for rec in window:
            fails = sorted({f.get("step") for f in (rec.get("failures") or []) if f.get("step")},
                           key=GA._step_key)
            runs.append({"ts": rec.get("ts"), "mode": rec.get("mode"),
                         "rc": int(rec.get("rc") or 0), "fails": fails,
                         "new": [s for s in fails if prev is not None and s not in prev],
                         "ran": len(rec.get("ran") or [])})
            prev = set(fails)
        latest = set(runs[-1]["fails"]) if runs else set()
        before = set(runs[-2]["fails"]) if len(runs) >= 2 else set()
        body = {"path": os.path.relpath(GA.LEDGER, REPO),
                "total": len(recs), "window": len(window),
                "runs": runs, "passedRuns": sum(1 for r in runs if r["rc"] == 0),
                "resolved": sorted(before - latest, key=GA._step_key),
                "counts": t["counts"], "streak": t["streak"], "latestOk": t["passed"],
                "gone": t["gone"], "goneSkipped": t["gone_skipped"]}
        return self._json(200, json.dumps(body, ensure_ascii=False))

    def _start_job(self, job, worker, label):
        """시작은 즉시 반환하고, 진행은 status 폴링 — 스냅샷과 같은 계약."""
        if not SIM_LOCK.acquire(blocking=False):
            return self._json(409, json.dumps({"error": "이미 실행 중 — 끝날 때까지 기다리세요"}))
        job_id = uuid.uuid4().hex[:8]
        with JOB_LOCK:
            job.update({"id": job_id, "running": True, "done": False, "error": None,
                        "startedAt": time.strftime("%H:%M:%S"), "finishedAt": None,
                        "result": None, "only": job.get("only", "")})
        threading.Thread(target=worker, args=(job,), daemon=True).start()
        self._json(200, json.dumps({"started": True, "job": job_id, "label": label}))

    def _api_job_status(self, job):
        with JOB_LOCK:
            self._json(200, json.dumps({k: v for k, v in job.items()}, ensure_ascii=False))

    # ── 스냅샷 ────────────────────────────────────────────────────────────
    def _api_snapshots(self):
        acquired = False
        with SNAP_LOCK:
            if SNAP_JOB["running"]:
                return self._json(409, json.dumps(
                    {"error": "스냅샷 재실행이 이미 진행 중입니다", "job": SNAP_JOB["id"]},
                    ensure_ascii=False))
            if not SIM_LOCK.acquire(blocking=False):
                return self._json(409, json.dumps(
                    {"error": "다른 시뮬 실행 중 — 잠시 후 재시도하세요"}, ensure_ascii=False))
            acquired = True  # SIM_LOCK 은 백그라운드 워커가 최종 반환
            job = str(uuid.uuid4())[:8]
            SNAP_JOB.update({"id": job, "running": True, "done": False, "error": None,
                             "startedAt": time.strftime("%H:%M:%S"), "finishedAt": None,
                             "result": None})
        if acquired:
            threading.Thread(target=_snap_worker, args=(job,), daemon=True).start()
            self._json(200, json.dumps({"started": True, "job": job}, ensure_ascii=False))

    def _api_snap_status(self):
        with SNAP_LOCK:
            snap = dict(SNAP_JOB)
        self._json(200, json.dumps(snap, ensure_ascii=False))

    # ── 실시간 시뮬 ────────────────────────────────────────────────────────
    def _api_sims(self):
        payload = {"sims": [
            {"name": n, "desc": d,
             "defaultCmd": "python3 sim/center/sims/" + " ".join(SIM_BASE_ARGS[n]),
             "params": [{"key": k, "label": lb, "def": df, "min": lo, "max": hi}
                        for k, lb, df, lo, hi in SIM_PARAMS.get(n, [])]}
            for n, _, d in SIMS]}
        self._json(200, json.dumps(payload, ensure_ascii=False))

    def _api_sim(self, name, qs):
        args, err = build_args(name, qs)
        if err:
            return self._json(400, json.dumps({"error": err}, ensure_ascii=False))
        if not SIM_LOCK.acquire(blocking=False):
            return self._json(409, json.dumps(
                {"error": "다른 시뮬 실행 중 — 잠시 후 재시도하세요"}, ensure_ascii=False))
        try:
            try:
                r = run_one(name, args, SIM_DESC.get(name, ""))
            except subprocess.TimeoutExpired:
                r = {"name": name, "cmd": "python3 " + " ".join(args),
                     "desc": SIM_DESC.get(name, ""), "exit": -1, "seconds": 300,
                     "stdout": "(300초 초과 — 타임아웃)", "stderr": "", "trimmed": False}
            sys.stderr.write('[center] /api/sim/%s → exit %s · %.1fs\n'
                             % (name, r.get("exit"), r.get("seconds", 0)))
            self._json(200, json.dumps(r, ensure_ascii=False))
        finally:
            SIM_LOCK.release()

    def _gacha_hash(self):
        target = os.path.join(PAGES, "gacha.html")
        try:
            with open(target, "rb") as f:
                digest = hashlib.sha256(f.read()).hexdigest()[:16]
            self._json(200, f'{{"hash":"{digest}"}}')
        except OSError as ex:
            self._json(500, f'{{"error":"{ex}"}}')

    # ── 응답 헬퍼 ─────────────────────────────────────────────────────────
    def _redirect(self, to):
        self.send_response(302)
        self.send_header("Location", to)
        self.send_header("Content-Length", "0")
        self.end_headers()

    def _json(self, code, body):
        data = body.encode()
        self.send_response(code)
        self.send_header('Content-Type', 'application/json; charset=utf-8')
        self.send_header('Cache-Control', 'no-store')
        self.send_header('Access-Control-Allow-Origin', '*')  # file:// 허브에서도 호출 가능
        self.send_header('Content-Length', str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def log_message(self, fmt, *args):
        sys.stderr.write('[center] %s\n' % (fmt % args))


def _snap_worker(job):
    """스냅샷 재실행 — 본체는 run_snapshots.execute/write_outputs 하나뿐이다.

    (원본에서 서버가 main() 을 통째로 복사했다가 데이터 지문 필드가 빠진 사고가 있었다.
     두 벌로 쓰지 않는다.)
    """
    import run_snapshots as rs
    try:
        data, fails = rs.execute(None, log=lambda m: print(m, flush=True))
        rs.write_outputs(data)
        with SNAP_LOCK:
            SNAP_JOB.update({"running": False, "done": True,
                             "finishedAt": time.strftime("%H:%M:%S"),
                             "result": {"total": len(data["sims"]),
                                        "seconds": data["totalSeconds"], "fails": fails,
                                        "uncommitted": len(data["uncommittedData"]),
                                        "writers": data["dataWriters"]}})
        print(f"[center] 스냅샷 완료 — {len(data['sims'])}/{data['expectedTotal']}종 · "
              f"{data['totalSeconds']}초 · {'전부 OK' if not fails else 'FAIL: ' + ', '.join(fails)}",
              flush=True)
    except Exception as ex:
        with SNAP_LOCK:
            SNAP_JOB.update({"running": False, "done": True, "error": str(ex),
                             "finishedAt": time.strftime("%H:%M:%S")})
    finally:
        SIM_LOCK.release()


def _run_one_gate(gid, title, args, display, timeout):
    """게이트 하나 실행 → stdout+stderr 전문을 담아 돌려준다.

    마지막 한 줄만 보내면 "왜 실패했나" 를 알 수 없다 — 원인은 대개 중간에 있다.
    """
    t1 = time.time()
    py = sys.executable
    if args and args[0].endswith(".sh"):
        cmd = ["bash"] + args
    else:
        cmd = [py] + args
    try:
        r = subprocess.run(cmd, capture_output=True, text=True, cwd=REPO, timeout=timeout)
        rc, out = r.returncode, (r.stdout or "") + (r.stderr or "")
    except subprocess.TimeoutExpired as e:
        rc = 124
        out = ((e.stdout or "") if isinstance(e.stdout, str) else "") \
            + f"\n[{gid}] {timeout}초 초과 — 느린 것이지 통과가 아니다"
    lines = [l for l in out.strip().split("\n") if l.strip()]
    detail = next((l.strip() for l in reversed(lines) if l.strip()), "")
    return {"id": gid, "title": title, "ok": rc == 0,
            "seconds": round(time.time() - t1, 1),
            "detail": (detail if rc == 0 else next((l.strip() for l in lines if l.strip()), ""))[:200],
            "log": out[-20000:], "lines": len(lines), "script": display, "selftest": False}


def _gate_worker(job):
    results, t0 = [], time.time()
    try:
        only = job.get("only", "")
        targets = [g for g in GATES if not only or g[0] == only]
        if only and not targets:
            raise ValueError(f"그런 게이트가 없다: {only}")
        for gid, title, args, display, timeout in targets:
            res = _run_one_gate(gid, title, args, display, timeout)
            results.append(res)
            print(f"[center] [{gid}] {'OK' if res['ok'] else 'FAIL'} · {title}", flush=True)
        n_ok = sum(1 for r in results if r["ok"])
        with JOB_LOCK:
            GATE_JOB.update({"running": False, "done": True,
                             "finishedAt": time.strftime("%H:%M:%S"),
                             "result": {"gates": results, "pass": n_ok, "total": len(results),
                                        "only": only, "seconds": round(time.time() - t0, 1)}})
        print(f"[center] 게이트 완료 — {n_ok}/{len(results)} 통과", flush=True)
    except Exception as ex:
        with JOB_LOCK:
            GATE_JOB.update({"running": False, "done": True, "error": str(ex),
                             "finishedAt": time.strftime("%H:%M:%S")})
    finally:
        SIM_LOCK.release()


if __name__ == '__main__':
    def _sync_pages_on_start():
        """페이지 내장 JSON 을 data/ 기준으로 맞춘다 — 생성기가 없으니 시작할 때 --write."""
        try:
            r = subprocess.run([sys.executable, os.path.join(HERE, "sync_pages.py"),
                                "--write", "--quiet"],
                               capture_output=True, text=True, cwd=REPO, timeout=120)
            last = ((r.stdout or "") + (r.stderr or "")).strip().splitlines()
            print(f"[center] 페이지 동기화 — {last[-1] if last else '출력 없음'}", flush=True)
        except Exception as ex:  # 동기화 실패가 서버를 막지는 않는다 (페이지는 옛 이름으로 뜬다)
            print(f"[center] 페이지 동기화 건너뜀: {ex}", flush=True)

    _sync_pages_on_start()
    with http.server.ThreadingHTTPServer(('127.0.0.1', PORT), CenterHandler) as httpd:
        print(f'[center] http://localhost:{PORT}/test_center.html  (파일 저장 → 자동 리로드)')
        print(f'[center] 실시간 시뮬 API: /api/sims · /api/sim/<이름> · 게이트 /api/gates')
        print(f'[center] 정적 루트: {PAGES}')
        print(f'[center] 인터프리터: {sys.executable}')
        print('[center] 중지: Ctrl+C')
        try:
            httpd.serve_forever()
        except KeyboardInterrupt:
            print('\n[center] 종료')
