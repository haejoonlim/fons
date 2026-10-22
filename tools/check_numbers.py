#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""check_numbers.py — 정본 수치 드리프트 검사 (exit 0 = 통과).

왜 있나:
  같은 숫자가 등록소(`tools/tracked_numbers.json`)·파이썬 시뮬(`sim/gacha.py`)·
  게임 사본(`godot/core/gacha.gd`) 세 곳에 산다. 한 곳만 고치면 게이트는 통과하는데
  게임과 시뮬이 다른 값으로 도는 상태가 된다(부록 A #3 — 130 이 원본에 없는 오전사였다).

무엇을 보는가:
  N-1  파이썬 시뮬 상수 = 등록소 값
  N-2  GDScript 사본 상수 = 등록소 값, 그리고 등록소 상수가 두 사본 중 한쪽에만 있지는 않은지
       (선언은 있는데 리터럴이 아니라 값을 못 읽은 경우도 실패 — 조용히 검사에서 빠지면 안 된다)
  N-3  확률표: 등급 이름 순서와 확률이 파이썬 ↔ GDScript 에서 같고, 합이 100.00(%)

  등록소에 있는 값이 두 파일 어디에도 없으면 실패가 아니라 '미적용'으로 세어 보여 준다
  (LEY_PER_CRYSTAL 처럼 다른 모듈이 쓰는 값이 있다).

정본 관계:
  tools/tracked_numbers.json  >  sim/gacha.py  >  godot/core/gacha.gd
  사본을 손으로 맞추지 않는다. 값을 바꿀 때는 등록소를 먼저 고치고 이 검사를 돌린다.

왜 import 대신 ast 로 읽나 (2026-10-18 실측):
  이 맥의 파이썬은 `sys.pycache_prefix = ~/Library/Caches/com.apple.python` 이다.
  그래서 소스를 고쳤는데 크기는 같고 mtime 초가 같은 경우 낡은 바이트코드가 그대로 돈다.
  실측: sim/gacha.py 의 130 을 999 로 바꿨다가 되돌렸더니 import 결과가 계속 999 였다.
  AST 로 읽으면 바이트코드 캐시를 거치지 않으므로 이런 거짓 통과·거짓 실패가 없다.

사용법:
  ./.venv/bin/python tools/check_numbers.py
"""
import ast
import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
REGISTRY = os.path.join(HERE, "tracked_numbers.json")

sys.path.insert(0, HERE)
from gate_contract import run  # noqa: E402

PY_FILE = "sim/gacha.py"
GD_FILE = "godot/core/gacha.gd"
TOL = 1e-9
GD_CONST = re.compile(
    r"^const\s+([A-Za-z_][A-Za-z0-9_]*)\s*(?::\s*[A-Za-z_][A-Za-z0-9_\[\]]*)?\s*:?=\s*(.+?)\s*$", re.M)
GD_COMMENT = re.compile(r"\s+#.*$")   # ponytail: 문자열 리터럴 안의 # 은 구분 못 한다. 지금 데이터에는 없다.


def load_json(path):
    with open(path, encoding="utf-8") as fh:
        return json.load(fh)


def load_python_consts(rel):
    """모듈 수준 대입을 ast 로 읽는다. import 하지 않으므로 바이트코드 캐시를 안 탄다."""
    path = os.path.join(ROOT, rel)
    with open(path, encoding="utf-8") as fh:
        tree = ast.parse(fh.read(), filename=rel)
    consts, lines, unreadable = {}, {}, set()
    for node in tree.body:
        # `X = 1` 과 `X: int = 1` 둘 다 받는다. 타입 주석이 붙은 선언을 놓치면 검사에서 사라진다.
        if isinstance(node, ast.Assign) and len(node.targets) == 1 \
                and isinstance(node.targets[0], ast.Name):
            name, value = node.targets[0].id, node.value
        elif isinstance(node, ast.AnnAssign) and isinstance(node.target, ast.Name) \
                and node.value is not None:
            name, value = node.target.id, node.value
        else:
            continue
        lines[name] = node.lineno
        try:
            consts[name] = ast.literal_eval(value)
        except (ValueError, TypeError, SyntaxError):
            unreadable.add(name)  # 표현식 등 — 가만히 건너뛰면 검사에서 사라진다
    return consts, lines, unreadable


def load_gdscript_consts(rel):
    path = os.path.join(ROOT, rel)
    with open(path, encoding="utf-8") as fh:
        text = fh.read()
    consts, lines, unreadable = {}, {}, set()
    for m in GD_CONST.finditer(text):
        name, raw = m.group(1), GD_COMMENT.sub("", m.group(2))
        lines[name] = text[: m.start()].count("\n") + 1
        try:
            consts[name] = json.loads(raw)  # GDScript 리터럴은 JSON 과 호환된다
        except ValueError:
            unreadable.add(name)
    return consts, lines, unreadable


def same(a, b):
    if isinstance(a, bool) or isinstance(b, bool):
        return a == b
    if isinstance(a, (int, float)) and isinstance(b, (int, float)):
        return abs(float(a) - float(b)) <= TOL
    return a == b


def main():
    if not os.path.exists(REGISTRY):
        print("FAIL — 등록소가 없다: tools/tracked_numbers.json")
        return 1

    reg = load_json(REGISTRY)
    entries = reg.get("numbers") or []
    if not entries:
        print("FAIL — 등록소에 numbers 가 비어 있다")
        return 1

    try:
        py_consts, py_lines, py_unreadable = load_python_consts(PY_FILE)
        gd_consts, gd_lines, gd_unreadable = load_gdscript_consts(GD_FILE)
    except OSError as exc:
        print("FAIL — 사본을 읽지 못했다: %s" % exc)   # 예외 traceback 대신 정상 종료 코드로
        return 1

    fails = []
    applied = 0

    for entry in entries:
        name = entry.get("name")
        raw = entry.get("value")
        note = entry.get("note") or ""
        if not name:
            fails.append("등록소 항목에 name 이 없다: %r" % (entry,))
            continue
        try:
            want = json.loads(raw)
        except (TypeError, ValueError):
            want = raw  # 숫자로 안 읽히면 문자열 그대로 비교한다

        hit = False

        # N-1 — 파이썬
        if name in py_consts:
            hit = True
            if not same(py_consts[name], want):
                fails.append("N-1 %s:%d — %r ≠ 등록소 %r (%s)"
                             % (PY_FILE, py_lines[name], py_consts[name], want, note))

        # N-2 — GDScript
        if name in gd_consts:
            hit = True
            if not same(gd_consts[name], want):
                fails.append("N-2 %s:%d — %r ≠ 등록소 %r (%s)"
                             % (GD_FILE, gd_lines[name], gd_consts[name], want, note))

        # 선언은 있는데 값을 읽지 못한 경우(표현식 등) — 비교 불가도 실패다.
        if name in py_unreadable or name in gd_unreadable:
            where = PY_FILE if name in py_unreadable else GD_FILE
            fails.append("%s %s:%d — %s 값을 읽지 못했다 (리터럴이 아님?)"
                         % ("N-1" if where == PY_FILE else "N-2", where,
                            (py_lines if where == PY_FILE else gd_lines).get(name, 0), name))
            continue

        # N-2 — 등록소 상수가 두 사본 중 한쪽에만 있을 때. 값이 같아도 "검사되지 않았을" 뿐이다.
        # 어느 쪽에도 없는 값(LEY_PER_CRYSTAL 등)은 다른 모듈이 쓰는 값이므로 오류가 아니다.
        if (name in py_consts) != (name in gd_consts):
            missing = GD_FILE if name in py_consts else PY_FILE
            fails.append("N-2 %s 에 상수 %s 가 없다 (등록소 %r · %s)"
                         % (missing, name, want, note))

        if hit:
            applied += 1

    # N-3 — 확률표: 파이썬과 GDScript 가 같은 표를 들고 있어야 한다
    py_bands = [tuple(x) for x in py_consts.get("RARITY_BANDS", ())]
    gd_grades = [str(g) for g in gd_consts.get("RARITY_GRADES", [])]
    gd_pcts = gd_consts.get("RARITY_PERCENT", [])
    py_grades = [g for g, _ in py_bands]
    py_pcts = [p for _, p in py_bands]

    if not py_bands:
        fails.append("N-3 %s — RARITY_BANDS 를 못 읽었다" % PY_FILE)
    elif abs(sum(py_pcts) - 100.0) > TOL:
        fails.append("N-3 %s — 확률표 합 %.6f ≠ 100.00" % (PY_FILE, sum(py_pcts)))

    if py_grades != gd_grades:
        fails.append("N-3 등급 순서가 다르다 — %s %r ≠ %s %r"
                     % (PY_FILE, py_grades, GD_FILE, gd_grades))
    if len(py_pcts) != len(gd_pcts):
        fails.append("N-3 확률 개수가 다르다 — %s %d ≠ %s %d"
                     % (PY_FILE, len(py_pcts), GD_FILE, len(gd_pcts)))
    for p1, p2, grade in zip(py_pcts, gd_pcts, py_grades):
        if not same(p1, p2):
            fails.append("N-3 %s:%d — %s 확률 %r ≠ %s %r"
                         % (GD_FILE, gd_lines.get("RARITY_PERCENT", 0), grade, p2, PY_FILE, p1))

    covered = len(py_grades) + applied
    skipped = [e["name"] for e in entries
               if e.get("name") and e["name"] not in py_consts and e["name"] not in gd_consts
               and e["name"] not in py_unreadable and e["name"] not in gd_unreadable]

    print("check_numbers — N-1~N-3")
    print("  등록소 %d개 (적용 %d) · 확률표 %d등급 · 합 %.2f%%"
          % (len(entries), applied, len(py_grades), sum(py_pcts)))
    if skipped:
        print("  미적용(다른 모듈이 쓰는 값): %s" % ", ".join(skipped))
    for f in fails:
        print("  [FAIL] " + f)
    print("  → %s" % ("통과" if not fails else "실패 %d건" % len(fails)))
    return 1 if fails else 0


if __name__ == "__main__":
    sys.exit(run("numbers", main))
