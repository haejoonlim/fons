"""Phase gates: docs + sim/gacha.py. Godot GUT tests run inside Godot (Phase 2+).

실행: ./.venv/bin/python tools/gate_all.py
      ./.venv/bin/python tools/gate_all.py --history[=N]   # 런 원장 추이

성공하면 예전과 같은 줄이 나온다 (`DOCS OK …` · `GATE OK: …` · `GATE ALL OK`).

2026-10-17 — 런 원장(ledger)을 붙였다:
  예전에는 첫 실패에서 `sys.exit` 으로 그 자리에서 멈췄다. 그래서 출력이 "실패 1건"처럼
  보였고, 뒤 단계가 한 번도 안 돌았다는 사실은 어디에도 남지 않았다. 또 "이 실패가 계속
  깨지는 것인지, 방금 새로 깨진 것인지" 를 알 수 없었다.
  이제 모든 단계를 끝까지 돌리고 **실패한 단계만** 요약한 뒤, 매 런을
  `tools/gate_ledger.jsonl` (gitignore) 에 한 줄씩 남긴다. 로그 기록 실패는 경고만 내고
  판정에 영향을 주지 않는다 — 로그가 게이트를 잡아먹으면 안 된다.
  테스트 센터(sim/center)의 [🛡 게이트 상태] 탭이 이 파일을 읽어 추이를 그린다.
"""
import json
import os
import subprocess
import sys
import time
from pathlib import Path

HERE = Path(__file__).resolve().parent.parent
LEDGER = HERE / "tools" / "gate_ledger.jsonl"
LEDGER_KEEP = 500   # 원장에 남기는 최근 런 수
MODE = "full"       # 폰즈 게이트는 모드가 하나다 (스킵 갈래를 두지 않는다)

# (단계 id, 설명, 명령) — 순서 그대로 돈다. 실패해도 다음 단계로 간다.
STEPS = [
    ("docs", "필수 산출물·구조·데이터", [sys.executable, "tools/check_docs.py"]),
    ("glossary", "용어집 표기 ↔ 정본 대조", [sys.executable, "tools/check_glossary.py"]),
    ("text", "데이터 문장 깨짐", [sys.executable, "tools/check_data_text.py"]),
    ("gacha", "소환 규칙 재현 (확정 #32·#11)", [sys.executable, "sim/gacha.py"]),
]


def _step_key(s):
    """단계 id 정렬 키 — 숫자면 숫자로, 아니면 이름으로 (원본 게이트 1.7·2/2 형식 호환)."""
    import re
    m = re.match(r"^(\d+)(?:[.\-/](\d+))?", s or "")
    return (int(m.group(1)), int(m.group(2) or 0), s or "") if m else (99, 0, s or "")


def ledger_read(path=None):
    """원장 읽기 — 반쯤 쓰인 줄은 건너뛴다 (한 줄이 전체 추이를 못 보게 만들면 안 된다)."""
    p = Path(path or LEDGER)
    if not p.exists():
        return []
    recs = []
    for line in p.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line:
            continue
        try:
            rec = json.loads(line)
        except json.JSONDecodeError:
            continue
        if isinstance(rec, dict):
            recs.append(rec)
    return recs


def ledger_trend(recs):
    """추이 — (단계별 실패 런 수, 최신부터 연속 실패, 최신 런 통과 여부, 안 돈 단계)."""
    counts = {}
    streak = {}
    for rec in recs:
        for step in {f.get("step") for f in (rec.get("failures") or []) if f.get("step")}:
            counts[step] = counts.get(step, 0) + 1
    # 연속 실패는 **단계마다 따로** "끊기지 않은 접미사" 를 센다.
    #   한 번에 훑으며 전체를 끊으면, 다른 단계가 해소된 순간에 아직 이어지고 있는 단계의
    #   연속까지 같이 끊긴다 (a 단계 3연속 · b 단계가 중간에 해소 → a 가 2로 줄어 보였다).
    steps = {f.get("step") for rec in recs for f in (rec.get("failures") or []) if f.get("step")}
    for step in steps:
        n = 0
        for rec in reversed(recs):
            fails = {f.get("step") for f in (rec.get("failures") or []) if f.get("step")}
            if step not in fails:
                break
            n += 1
        if n:
            streak[step] = n
    passed = (recs[-1].get("rc") == 0) if recs else None
    gone, gone_skipped = [], False
    if len(recs) >= 2:
        prev, latest = recs[-2], recs[-1]
        if (prev.get("mode") or "") != (latest.get("mode") or ""):
            gone_skipped = True   # 모드가 다르면 "안 돈 단계" 로 오판하지 않는다
        else:
            gone = sorted(set(prev.get("ran") or []) - set(latest.get("ran") or []), key=_step_key)
    return {"counts": counts, "streak": streak, "passed": passed,
            "gone": gone, "gone_skipped": gone_skipped}


def ledger_append(ran, rc, failures, path=None, keep=LEDGER_KEEP, mode=MODE, repaired=None):
    """런 한 줄 기록 — 실패해도 예외를 던지지 않는다 (로그가 게이트를 죽이면 안 된다)."""
    p = Path(path or LEDGER)
    rec = {"ts": time.strftime("%Y-%m-%dT%H:%M:%S"), "mode": mode, "rc": int(rc or 0),
           "ran": list(ran), "failures": list(failures)}
    if repaired:
        rec["repaired"] = list(repaired)
    try:
        p.parent.mkdir(parents=True, exist_ok=True)
        lines = []
        if p.exists():
            lines = [l for l in p.read_text(encoding="utf-8").splitlines() if l.strip()]
        lines.append(json.dumps(rec, ensure_ascii=False))
        p.write_text("\n".join(lines[-keep:]) + "\n", encoding="utf-8")
    except OSError as exc:
        print(f"[gate] ⚠ 런 원장 기록 실패 (판정에는 영향 없음): {exc}", file=sys.stderr)
    return rec


def print_history(n=10, path=None):
    recs = ledger_read(path)[-n:]
    if not recs:
        print("런 기록이 없습니다 — gate_all 을 한 번 돌리면 여기에 쌓입니다.")
        return 0
    t = ledger_trend(recs)
    for i, rec in enumerate(recs):
        fails = sorted({f.get("step") for f in (rec.get("failures") or []) if f.get("step")},
                       key=_step_key)
        prev = recs[i - 1].get("failures") if i else []
        prev_steps = {f.get("step") for f in (prev or [])}
        tag = "✅ rc=0" if rec.get("rc") == 0 else f"❌ rc={rec.get('rc')}"
        new = [s for s in fails if i and s not in prev_steps]
        row = ", ".join(f"[{s}]{' 🆕' if s in new else ''}" for s in fails) or "실패 0건"
        print(f"  {rec.get('ts', '?')}  {tag}  {row}")
    passed_runs = sum(1 for r in recs if r.get("rc") == 0)
    print(f"\n  최근 {len(recs)}런 중 통과 {passed_runs}/{len(recs)}")
    for step in sorted(t["counts"], key=_step_key):
        bar = "█" * min(t["counts"][step], 20)
        print(f"  [{step}] {bar} {t['counts'][step]}/{len(recs)} · 연속 {t['streak'].get(step, 0)}")
    if t["gone"]:
        print("  ⚠ 직전 런에는 돌았는데 최신 런에서 안 돈 단계: "
              + " ".join(f"[{s}]" for s in t["gone"]))
    elif t["gone_skipped"]:
        print("  (직전 런과 모드가 달라 '안 돈 단계' 비교는 생략)")
    return 0 if t["passed"] else 1


def main():
    ran, failures = [], []
    for step_id, title, cmd in STEPS:
        print("+", " ".join(cmd), flush=True)
        ran.append(step_id)
        r = subprocess.run(cmd, cwd=HERE)
        if r.returncode != 0:
            print(f"[{step_id}] FAIL — {title} (exit {r.returncode})")
            failures.append({"step": step_id, "rc": r.returncode, "msg": title})

    ledger_append(ran, failures[0]["rc"] if failures else 0, failures)

    if failures:
        print(f"\n❌ gate_all 실패 — {len(failures)}단계 실패 · 나머지 단계는 모두 실행됨 (커밋 불가)")
        for f in failures:
            print(f"   · [{f['step']}] {f['msg']}")
        print("   → 위 단계만 고치고 다시 돌리면 된다. 추이: tools/gate_all.py --history")
        return failures[0]["rc"] or 1
    print("GATE ALL OK")
    return 0


if __name__ == "__main__":
    for _arg in sys.argv[1:]:
        if _arg == "--history" or _arg.startswith("--history="):
            try:
                _n = int(_arg.split("=", 1)[1]) if "=" in _arg else 10
            except ValueError:
                _n = 10
            sys.exit(print_history(_n))
    sys.exit(main())
