#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""check_fusion.py — 스킬 융합 참조 무결성 검사 (exit 0 = 통과).

왜 있나:
  `data/fusion_pairs.json` 은 부모를 **카탈로그 실명**으로 적는다. 카탈로그를 다시 뽑거나
  스킬 이름을 바꾸면 부모 이름이 조용히 dangling 이 된다 — 페이지는 그 쌍을 그리지 못하고,
  게임에서는 융합이 성립하지 않는다. 2026-10-18 에 부모 3건(강철지시·뇌전상술·중첩흡수)이
  실제로 그 상태였다. 이름을 손으로 맞추는 대신 깨진 참조를 게이트가 막는다.

무엇을 보는가:
  F-1  pairs 수 = meta.count (117) · 카탈로그 수 = meta.count (1300) · 카드 이름 중복 없음
  F-2  부모 두 이름이 카탈로그에 있고, 그 카드 레어도 = 부모_레어도
  F-3  자식_레어도 = max(부모 레어도) + 1 (L 상한 6)
  F-4  한 쌍의 두 부모가 같은 카드가 아니다
  F-5  자식 이름이 쌍마다 고유하다
  F-6  R5(S+S→L) 자식은 카탈로그 L(레어도 6) 실명이고, 부모는 S(5) 카드다

정본 관계:
  data/skills_catalog.json  >  data/fusion_pairs.json  (부모는 카탈로그를 따라간다)

사용법:
  ./.venv/bin/python tools/check_fusion.py
"""
import json
import os
import sys
from collections import Counter

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
DATA = os.path.join(ROOT, "data")

sys.path.insert(0, HERE)
from gate_contract import run  # noqa: E402
CATALOG = os.path.join(DATA, "skills_catalog.json")
FUSION = os.path.join(DATA, "fusion_pairs.json")

R5_CHILD_RARITY = 6  # L


def load(path, label):
    """필수 정본 읽기 — 없거나 깨졌으면 traceback 이 아니라 (None, 실패 문구)."""
    try:
        with open(path, encoding="utf-8") as fh:
            return json.load(fh), None
    except OSError as e:
        return None, "%s 읽기 실패: %s" % (label, e)
    except json.JSONDecodeError as e:
        return None, "%s JSON 깨짐: %s" % (label, e)


def main():
    if not os.path.exists(FUSION):
        print("FAIL — 정본이 없다: data/fusion_pairs.json")
        return 1
    if not os.path.exists(CATALOG):
        print("FAIL — 정본이 없다: data/skills_catalog.json")
        return 1

    fusion, err = load(FUSION, "data/fusion_pairs.json")
    if err:
        print("FAIL — " + err)
        return 1
    catalog, err = load(CATALOG, "data/skills_catalog.json")
    if err:
        print("FAIL — " + err)
        return 1

    pairs = fusion.get("pairs") or []
    meta = fusion.get("meta") if isinstance(fusion.get("meta"), dict) else {}
    skills = catalog.get("skills") or []

    fails = []

    # 구조가 아니면 traceback 대신 실패로 끝낸다. name 이 없거나 중복인 카드도 여기서 적는다 —
    # dict 컴프리는 뒤 카드로 조용히 덮어써서 그 카드를 참조하는 쌍이 통과했다.
    if not isinstance(pairs, list) or not all(isinstance(p, dict) for p in pairs):
        print("FAIL — pairs 가 객체 배열이 아니다")
        return 1
    if not isinstance(skills, list) or not all(isinstance(s, dict) for s in skills):
        print("FAIL — catalog.skills 가 객체 배열이 아니다")
        return 1
    no_name = [s for s in skills if not isinstance(s.get("name"), str)]
    if no_name:
        print("FAIL — 이름 없는 카드 %d장" % len(no_name))
        return 1
    cards = {s["name"]: s for s in skills}
    if len(cards) != len(skills):
        dup = sorted(n for n, c in Counter(s["name"] for s in skills).items() if c > 1)
        fails.append("F-1 카탈로그 이름 중복 %d건: %s" % (len(dup), ", ".join(dup[:10])))

    # F-1 — 수 (융합 쌍과 카탈로그 둘 다 적힌 수와 일치해야 한다)
    if meta.get("count") != len(pairs):
        fails.append("F-1 meta.count %r ≠ 실제 %d쌍" % (meta.get("count"), len(pairs)))
    cat_meta = catalog.get("meta") or {}
    if cat_meta.get("count") != len(skills):
        fails.append("F-1 카탈로그 meta.count %r ≠ 실제 %d종"
                     % (cat_meta.get("count"), len(skills)))

    parents_seen = Counter()
    children = Counter()

    for i, p in enumerate(pairs, 1):
        p1, p2 = p.get("parent1"), p.get("parent2")
        r1, r2 = p.get("parent_rarity1"), p.get("parent_rarity2")
        cr = p.get("child_rarity")
        child = p.get("child_name")
        tag = "pairs[%d] %s+%s→%s" % (i, p1, p2, child)

        # F-2 — 부모가 카탈로그에 있고 레어도가 맞는다
        for name, want in ((p1, r1), (p2, r2)):
            card = cards.get(name)
            if card is None:
                fails.append("F-2 %s — 카탈로그에 없는 부모 %r" % (tag, name))
                continue
            if card.get("rarity") != want:
                fails.append("F-2 %s — 부모 %r 레어도 %r ≠ 카드 %r"
                             % (tag, name, want, card.get("rarity")))
            parents_seen[name] += 1

        # F-3 — 레어도는 정수 1~6 이어야 한다. 문자열·0·음수는 비교를 건너뛰며 빠져나갔다.
        for value, lo, hi, label in ((r1, 1, 5, "부모1"), (r2, 1, 5, "부모2"),
                                     (cr, 2, 6, "자식")):
            if isinstance(value, bool) or not isinstance(value, int) or not lo <= value <= hi:
                fails.append("F-3 %s — %s 레어도 %r (정수 %d~%d)"
                             % (tag, label, value, lo, hi))

        # F-3 — 자식 레어도 = max(부모)+1
        if isinstance(r1, int) and isinstance(r2, int) and cr != max(r1, r2) + 1:
            fails.append("F-3 %s — 자식 레어도 %r ≠ max(부모)+1=%d"
                         % (tag, cr, max(r1, r2) + 1))

        # F-4 — 같은 카드끼리 융합 금지
        if p1 == p2:
            fails.append("F-4 %s — 두 부모가 같은 카드" % tag)

        children[child] += 1

        # F-6 — R5 자식은 카탈로그 L 실명
        if cr == R5_CHILD_RARITY:
            card = cards.get(child)
            if card is None:
                fails.append("F-6 %s — R5 자식이 카탈로그에 없다" % tag)
            elif card.get("rarity") != R5_CHILD_RARITY:
                fails.append("F-6 %s — R5 자식 %r 레어도 %r ≠ L"
                             % (tag, child, card.get("rarity")))
            if (r1, r2) != (5, 5):
                fails.append("F-6 %s — R5 부모 레어도 %r,%r ≠ S,S" % (tag, r1, r2))

    # F-5 — 자식 이름 고유
    for name, n in children.items():
        if n > 1:
            fails.append("F-5 자식 이름 중복 %r ×%d" % (name, n))

    r5 = sum(1 for p in pairs if p.get("child_rarity") == R5_CHILD_RARITY)
    print("check_fusion — F-1~F-6")
    print("  쌍 %d (R5 %d) · 카탈로그 %d종 · 부모 %d종"
          % (len(pairs), r5, len(cards), len(parents_seen)))
    for f in fails:
        print("  [FAIL] " + f)
    print("  → %s" % ("통과" if not fails else "실패 %d건" % len(fails)))
    return 1 if fails else 0


if __name__ == "__main__":
    sys.exit(run("fusion", main))
