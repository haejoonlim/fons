#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""게이트 계약 검사 — `tools/gate_contract.py` 의 G-1~G-4 를 실측한다.

검사하는 것:
  C-1  종료코드 정규화 — None→0, 0·1·2 유지, 계약 밖(7) 은 1
  C-2  마지막 줄 — 통과면 `[PASS] <id>`, 실패면 `[FAIL] <id> — <이유>`
  C-3  예외 — traceback 대신 `[FAIL] <id> — 내부 오류: …`
  C-4  `--json` — stdout 은 JSON 하나, 표식 줄은 stderr
  C-5  실제 게이트 10종 — exit 0 · `[PASS]` 한 줄 · traceback 없음
  C-8  게이트 자신의 실패 메시지가 깨지지 않는가 (`sim/gacha.py` 의 `%` 포맷 assert)
       (GDD 두 단계 `gddjob`·`gddrev` 는 각 1.9초라 여기서 빼고 `gate_all` 실행으로 본다)
  C-6  실패하는 게이트(`check_gdd_names.py --strict`) — 표식이 종료코드와 일치
  C-7  문자열 SystemExit(`raise SystemExit('FAIL — 이유')`) — 이유가 줄에 살아남는다

실행: ./.venv/bin/python tools/test_gate_contract.py          (exit 0 = 계약 준수, 실패한 검사만 출력)
      ./.venv/bin/python tools/test_gate_contract.py -v       (전부 출력)
      ./.venv/bin/python tools/test_gate_contract.py --unit   (게이트 실행 생략 — `gate_all` 이
            자기 런에서 표식을 직접 보므로, 계약 검사가 게이트를 두 번 돌리지 않게 한다)
"""
import contextlib
import io
import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))
from gate_contract import FAIL, PASS, USAGE, run, verdict  # noqa: E402

# (경로, 단계 id, 인자) — `tools/gate_all.py` STEPS 와 같다.
GATES = [
    ("tools/check_docs.py", "docs", []),
    ("tools/check_glossary.py", "glossary", []),
    ("tools/check_gdd_names.py", "gdd", []),
    ("tools/check_data_text.py", "text", []),
    ("tools/check_cjk.py", "cjk", []),
    ("tools/check_paths.py", "paths", []),
    ("tools/check_manual_fields.py", "manfields", []),
    ("tools/check_manual_values.py", "manvalues", []),
    ("tools/check_fusion.py", "fusion", []),
    ("tools/check_numbers.py", "numbers", []),
    ("tools/check_monsters.py", "monsters", []),
    ("tools/check_job_profiles.py", "jobai", []),
    ("sim/gacha.py", "gacha", []),
    ("sim/center/sims/gen_husbandry_roster.py", "husbandry", ["--check"]),
    ("sim/center/sims/gen_block_roster.py", "blockroster", ["--check"]),
    ("sim/center/sync_pages.py", "pages", ["--quiet"]),
]
SLOW = [("tools/gdd_job_pending.py", "gddjob"), ("tools/gen_gdd_revised.py", "gddrev")]

VERBOSE = "-v" in sys.argv[1:]
UNIT = "--unit" in sys.argv[1:]      # 게이트 실행(C-4 게이트분·C-5·C-6) 생략
results = []


def check(name, ok, detail=""):
    results.append((name, bool(ok), detail))
    if ok and not VERBOSE:
        return
    print(("  OK   " if ok else "  FAIL ") + name + (("  " + detail) if detail and not ok else ""))


def capture(fn):
    """(종료코드, stdout, stderr) — 계약은 두 스트림을 구분해서만 말한다."""
    out, err = io.StringIO(), io.StringIO()
    with contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
        code = fn()
    return code, out.getvalue(), err.getvalue()


# C-1 / C-2 — 종료코드 정규화와 마지막 줄
def code_case(label, value, want_code):
    code, out, _ = capture(lambda: verdict("g", value))
    tag = "[PASS] g" if want_code == PASS else "[FAIL] g"
    check("C-1/C-2 %s" % label, code == want_code and out.strip().splitlines()[-1].startswith(tag),
          "code=%r last=%r" % (code, out.strip().splitlines()[-1:]))


code_case("None 은 0", None, PASS)
code_case("0 유지", PASS, PASS)
code_case("1 유지", FAIL, FAIL)
code_case("2(사용 오류) 유지", USAGE, USAGE)
code_case("7 은 1 로 정규화", 7, FAIL)

# C-2 — 실패 이유가 줄에 붙는다
code, out, _ = capture(lambda: verdict("g", FAIL, "왜 실패했는지"))
check("C-2 실패 이유가 줄에 붙음", out.strip() == "[FAIL] g — 왜 실패했는지", repr(out))

# C-3 — 예외는 traceback 이 아니라 한 줄 실패
def _boom():
    raise ValueError("깨짐")


code, out, err = capture(lambda: run("g", _boom, json_mode=False))
check("C-3 예외 → [FAIL] 내부 오류", code == FAIL and "[FAIL] g — 내부 오류: ValueError: 깨짐" in out,
      "code=%r out=%r" % (code, out))
check("C-3 traceback 본문이 stdout 에 없음", "Traceback (most recent call last)" not in out, repr(out))
check("C-3 마지막 프레임은 stderr 에 남음", "ValueError: 깨짐" in err, repr(err))

# C-3 — 게이트가 직접 sys.exit 한 경우도 코드가 정규화된다
def _exit0():
    raise SystemExit(0)


def _exit2():
    raise SystemExit(2)


check("C-3 sys.exit(0) → 0", capture(lambda: run("g", _exit0, json_mode=False))[0] == PASS)
check("C-3 sys.exit(2) → 2", capture(lambda: run("g", _exit2, json_mode=False))[0] == USAGE)

# C-4 — --json 이면 stdout 이 비고 표식은 stderr
code, out, err = capture(lambda: run("g", lambda: PASS, json_mode=True))
check("C-4 --json 이면 stdout 비어 있음", code == PASS and out == "", "out=%r" % out)
check("C-4 --json 표식은 stderr", err.strip() == "[PASS] g", repr(err))


# C-5 — 실제 게이트
def gate_run(script, *args):
    r = subprocess.run([sys.executable, str(ROOT / script), *args],
                       cwd=str(ROOT), capture_output=True, text=True)
    return r.returncode, r.stdout, r.stderr


if UNIT:
    print("  (C-5 생략 — --unit: 표식은 gate_all 이 자기 런에서 본다)")
else:
    for script, gate, args in GATES:
        code, out, err = gate_run(script, *args)
        lines = [ln for ln in out.splitlines() if ln.strip()]
        marks = [ln for ln in lines if ln.startswith(("[PASS]", "[FAIL]"))]
        check("C-5 %s exit 0" % script, code == 0, "code=%r" % (code,))
        check("C-5 %s [PASS] %s 한 줄" % (script, gate),
              len(marks) == 1 and marks[0] == "[PASS] %s" % gate, repr(marks))
        check("C-5 %s 마지막 줄이 표식" % script, bool(lines) and lines[-1] == "[PASS] %s" % gate,
              repr(lines[-1:]))
        check("C-5 %s traceback 없음" % script,
              "Traceback (most recent call last)" not in (out + err))

# C-8 — 게이트가 실패를 알릴 때 그 이유가 실제로 나오는가.
#      `sim/gacha.py` 는 예전에 `100%가` 로 쓴 % 포맷 때문에 assert 가 터지는 순간
#      AssertionError 대신 ValueError 를 냈다 (이유가 통째로 사라짐).
import importlib.util  # noqa: E402

_spec = importlib.util.spec_from_file_location("gacha_probe", ROOT / "sim" / "gacha.py")
_gacha = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(_gacha)
_saved, _reason = _gacha.RARITY_BANDS, None
_gacha.RARITY_BANDS = (("★1", 70.04),)          # 합 100 을 깨뜨린다
try:
    with contextlib.redirect_stdout(io.StringIO()):
        try:
            _gacha.main()
        except AssertionError as exc:
            _reason = "AssertionError: %s" % exc
        except Exception as exc:                 # 메시지 포맷이 깨지면 여기로 온다
            _reason = "%s: %s" % (type(exc).__name__, exc)
finally:
    _gacha.RARITY_BANDS = _saved
check("C-8 실패 이유가 AssertionError 로 살아남음",
      bool(_reason) and _reason.startswith("AssertionError:") and "100%가 아닙니다" in _reason,
      repr(_reason))

# C-7 — 문자열 SystemExit 은 이유가 줄에 살아남아야 한다 (husbandry 의 fail() 형식)


def _string_exit():
    raise SystemExit("FAIL — 개체가 어디에도 없다: 시궁쥐")


code, out, _ = capture(lambda: run("g", _string_exit, json_mode=False))
check("C-7 문자열 SystemExit → 이유 보존",
      code == FAIL and out.strip() == "[FAIL] g — FAIL — 개체가 어디에도 없다: 시궁쥐", repr(out))

if not UNIT:
    # C-6 — 실패 경로: GDD --strict 는 지금 잔재가 있어 1 이 나온다 (0 이 되면 그때는 통과로 본다)
    code, out, err = gate_run("tools/check_gdd_names.py", "--strict", "--quiet")
    want = "[PASS] gdd" if code == 0 else "[FAIL] gdd"
    last = [ln for ln in out.splitlines() if ln.strip()][-1:]
    check("C-6 실패 게이트 표식 = 종료코드", code in (0, 1) and last == [want],
          "code=%r last=%r" % (code, last))
    check("C-6 실패 게이트 traceback 없음", "Traceback (most recent call last)" not in (out + err))

    # C-4 — 실제 --json 게이트: stdout 이 순수 JSON
    code, out, err = gate_run("tools/check_job_profiles.py", "--json")
    try:
        body = json.loads(out)
        pure = isinstance(body, dict) and "fail" in body
    except json.JSONDecodeError:
        pure = False
    check("C-4 jobai --json stdout 이 순수 JSON", code == 0 and pure, repr(out[:120]))
    check("C-4 jobai --json 표식은 stderr", "[PASS] jobai" in err, repr(err[:120]))

bad = [r for r in results if not r[1]]
print("\n계약 검사 %d건 — 통과 %d / 실패 %d" % (len(results), len(results) - len(bad), len(bad)))
if bad:
    for name, _, detail in bad:
        print("  · %s %s" % (name, detail))
    print("\n[FAIL] contract — %d건" % len(bad))
    sys.exit(1)
print("[PASS] contract")
sys.exit(0)
