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
    # advisory — docs/gdd 는 원본 문면이라 고칠 수 없다. 실패로 만들지 않고 잔재 수만 보여 준다
    # (실패로 두면 사람이 게이트를 통과시키려고 GDD 를 손대게 된다 · docs/dev/GDD_이름_갱신_절차.md).
    ("gdd", "GDD 원본 문면 ↔ 현행 이름 대조", [sys.executable, "tools/check_gdd_names.py", "--quiet"]),
    # 직업 표 개정 대기 목록이 데이터와 어긋났는지만 본다 — GDD 에 옛 이름이 남은 것은 실패가 아니다.
    # (목록이 낡으면 목록을 다시 뽑는다. GDD 를 고치는 신호로 읽히면 안 된다)
    ("gddjob", "GDD 직업 표 개정 대기 목록",
     [sys.executable, "tools/gdd_job_pending.py", "--quiet"]),
    # 개정 반영본 사본이 원본 + 개정 목록과 같은가. 원본 docs/gdd 는 여기서도 안 건드린다.
    ("gddrev", "GDD 개정 반영본 사본",
     [sys.executable, "tools/gen_gdd_revised.py", "--quiet"]),
    ("text", "데이터 문장 깨짐", [sys.executable, "tools/check_data_text.py"]),
    # 테스트 센터 페이지는 값을 JSON 으로 박아 둔 정적 생성물이다(원본 생성기 없음).
    # 종의 스탯·티어·좌표를 data/ 에서 다시 계산해 어긋나면 --check 로 막고, --write 로 맞힌다.
    ("pages", "테스트 센터 페이지 내장값 ↔ data/",
     [sys.executable, "sim/center/sync_pages.py", "--quiet"]),
    # 융합 부모가 카탈로그에 없으면 페이지는 그 쌍을 못 그리고 게임에서는 융합이 성립하지 않는다.
    # (2026-10-18 에 부모 3건이 dangling 이었다 — 이름을 손으로 맞추는 대신 게이트가 막는다)
    ("fusion", "융합 참조 무결성 (F-1~F-6)",
     [sys.executable, "tools/check_fusion.py"]),
    ("gacha", "소환 규칙 재현 (확정 #32·#11)", [sys.executable, "sim/gacha.py"]),
    # 같은 숫자가 등록소·파이썬·GDScript 세 곳에 산다. 한 곳만 고치면 게이트는 통과하는데
    # 게임과 시뮬이 다른 값으로 도는 상태가 된다(부록 A #3). 등록소가 정본이다.
    ("numbers", "정본 수치 드리프트 (N-1~N-3)",
     [sys.executable, "tools/check_numbers.py"]),
    # 전투 몬스터 138종의 구조·참조 무결성. 이름·글자만 보던 게이트로는 aiDecision 이 빠지거나
    # prey 가 없는 id 를 가리켜도 통과했다 — 게임은 그 개체를 조용히 기본값으로 돌린다.
    ("monsters", "몬스터 구조·참조 무결성 (M-1~M-10)",
     [sys.executable, "tools/check_monsters.py"]),
    # 07 §8 의 개체수 모델 — 원본 `audit_sim.py` 포팅. 구조 검사가 맞아도 계절 순환이
    # 숫자로 돌지 않으면 그 규칙은 문서에만 있는 것이다. 마르코프·φ·Holling·10% 법칙을
    # 지금 데이터로 다시 돌린다 (S-1~S-7 · Godot 패리티 픽스처 P-1 · 26바이옴 × 12계절 · 약 3.5초).
    ("ecosim", "계절 순환 모델 재현 (S-1~S-7 · P-1)",
     [sys.executable, "sim/ecology.py"]),
    # 저층 사육 마물 — 도감 377 불변식 · 성격 기준 · 전투 개체 승격을 대조한다.
    # (2026-10-18 에 마물이 표에는 있는데 게임에는 없는 상태를 만들어서 넣었다)
    ("husbandry", "저층 사육 마물 정합",
     [sys.executable, "sim/center/sims/gen_husbandry_roster.py", "--check"]),
    # 직업 AI 프로필 — P0-1~P0-7 + 스탤 키 혼입 금지 (J 가 CP 경로에 닿지 못하게).
    ("jobai", "직업 AI 프로필 (P0-1~7)",
     [sys.executable, "tools/check_job_profiles.py"]),
    # 성격 데이터 — `data/personalities.json` 이 생성기 출력과 같은지 (손으로 고치면 드리프트).
    # 표가 바뀌면 생성기를 다시 돌린다: 05 §5-1 role 적합도 · gacha_test 상수.
    ("personality", "성격 데이터 드리프트 (13 main · 52 sub)",
     [sys.executable, "tools/gen_personalities.py", "--check"]),
    # 바이옴 에셋 키 — biomes.json 의 topologyKit·slots 에서 파생한 키만 담는다 (메시 아님).
    # 손으로 고치면 사본과 어긋나고, 정본(biomes.json)과 다른 세계 이름이 생긴다.
    ("biomeassets", "바이옴 에셋 키 드리프트 (biomes 파생)",
     [sys.executable, "tools/gen_biome_assets.py", "--check"]),
    # 지형 키트 `.glb` — 생성기(표준 라이브러리)가 뽑은 바이트와 커밋된 결과물이 같은가.
    # 손으로 메시를 고치면 다음 사람이 같은 결과를 못 만든다 (art-source/README.md 규칙 1).
    ("kitart", "지형 키트 .glb 드리프트 (생성기 파생)",
     [sys.executable, "tools/gen_kit_glb.py", "--check"]),
    # 계약 단위 검사만 돈다 (`--unit`) — 게이트 실행은 위에서 이미 했다.
    #   마커(`[PASS]/[FAIL] <단계 id>`)는 이 파일이 각 단계 출력에서 직접 본다(run_step +
    #   marker_gap). 그래서 계약 검사가 게이트를 두 번 돌리지 않는다 (예전엔 그래서 런이 2배).
    ("contract", "계약 단위 검사 (표식은 gate_all 이 직접 본다)",
     [sys.executable, "tools/test_gate_contract.py", "--unit"]),
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


def run_step(cmd):
    """단계를 돌리며 출력을 그대로 흘리고, 마지막 비어 있지 않은 줄을 붙잡는다.

    자식에 `-u` 를 붙이는 이유: stdout 이 파이프면 블록 버퍼링이라 단계가 끝날 때까지
    아무것도 안 보인다. 자식만 무버퍼로 돌려 지금까지처럼 생중계한다.
    """
    # `-u` 는 파이썬 단계에만 붙는다 (bash·Godot 단계에 붙이면 엉뚱한 인자가 된다).
    argv = [cmd[0], "-u"] + list(cmd[1:]) if cmd[0] == sys.executable else list(cmd)
    proc = subprocess.Popen(argv, cwd=HERE, stdout=subprocess.PIPE, text=True)
    lines = []
    for line in proc.stdout:
        if not line.endswith("\n"):
            line += "\n"     # 마지막 줄에 개행이 없으면 다음 출력과 붙어 버린다
        print(line, end="", flush=True)
        if line.strip():
            lines.append(line.rstrip("\n"))
    proc.stdout.close()
    return proc.wait(), lines


def marker_gap(step_id, rc, lines):
    """계약 G-2 — 마지막 줄이 `[PASS] <id>` / `[FAIL] <id>` 인가. 아니면 이유를 돌려준다."""
    want = "[PASS] %s" % step_id if rc == 0 else "[FAIL] %s" % step_id
    last = lines[-1] if lines else ""
    if last == want or (rc != 0 and last.startswith(want + " —")):
        return None
    return "게이트 계약 위반 — 마지막 줄이 %r (기대 %r)" % (last, want)


GODOT_STEP = ("godot", "GDScript 단위 테스트 (GUT)", ["bash", "tools/test_godot.sh"])


def main(godot=False):
    ran, failures = [], []
    # Godot 은 임포트 때문에 14초쯤 걸린다 — 기본 런(2.8초)에 넣지 않고 `--godot` 로만 돌린다.
    # (`gate_all.py --godot` = GDScript 까지 포함한 전수 검증)
    steps = STEPS + ([GODOT_STEP] if godot else [])
    for step_id, title, cmd in steps:
        print("+", " ".join(cmd), flush=True)
        ran.append(step_id)
        rc, lines = run_step(cmd)
        gap = marker_gap(step_id, rc, lines)
        if rc != 0:
            print(f"[{step_id}] FAIL — {title} (exit {rc})", flush=True)
            failures.append({"step": step_id, "rc": rc, "msg": title + (" · " + gap if gap else "")})
        elif gap:
            # 통과했는데 표식이 없거나 다르다 — 자동화가 이 단계를 못 알아본다.
            print(f"[{step_id}] FAIL — {gap}", flush=True)
            failures.append({"step": step_id, "rc": 1, "msg": gap})

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
    sys.exit(main(godot="--godot" in sys.argv[1:]))
