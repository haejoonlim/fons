#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""check_gdd_names.py — GDD 원본 문면에 남은 폐기 표기를 현행 이름과 대조한다.

왜 있나:
  docs/gdd/ 는 원본 문면이라 고치지 않는다 (docs/README.md 규칙 2, AGENTS.md §3).
  그래서 데이터에서 이름을 바꿔도 GDD 사본은 옛 이름을 계속 들고 있다. 손으로 맞추려
  들면 두 가지가 무너진다 — 원본 문면이 오염되고, 다음 재수입에서 그 수정이 조용히 사라진다.
  그래서 'GDD를 고친다' 대신 '간극을 보이게 만든다'. 폐기 표기(용어집)를 기준으로
  GDD 안의 옛 이름과 현행 이름을 짝지어 표로 낸다.

정본 관계:
  data/*.json 이름  >  이 대조표  >  docs/gdd/*.md (원본 문면, 개정 전까지 낡은 것이 정상)

사용법:
  ./.venv/bin/python tools/check_gdd_names.py            # 대조만 (advisory, exit 0)
  ./.venv/bin/python tools/check_gdd_names.py --write    # docs/l10n/GDD_이름_대조표.md 갱신
  ./.venv/bin/python tools/check_gdd_names.py --strict   # GDD 재수입 뒤 확인용 — 남으면 exit 1

종료 코드:
  0  대조 끝 (--strict 아닌 이상 GDD 잔재는 실패가 아니다)
  1  --strict 에서 잔재 있음
  2  설정 오류 (용어집·GDD 없음)
"""
import argparse
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
GDD = ROOT / "docs" / "gdd"
GLOSSARY = ROOT / "docs" / "l10n" / "용어집.md"
MONSTERS = ROOT / "data" / "monsters.json"
OUT = ROOT / "docs" / "l10n" / "GDD_이름_대조표.md"

sys.path.insert(0, str(ROOT / "tools"))
import check_glossary as cg  # noqa: E402  — 폐기 표기 파싱을 한 곳에 둔다
from gate_contract import run  # noqa: E402


def scan(pairs):
    """폐기 표기별 (현행, 근거, [(GDD 파일, 줄번호)]) 를 모은다.

    줄마다 표기 53종 정규식을 다 돌리면 3.5초였나다. 정규식은 문자 클래스 경계가 필요해서
    남기고, 먼저 `old in line` 로 걸러 낸다 — 안 들어 있는 표기는 정규식이 맞을 수 없다.
    """
    docs = sorted(GDD.glob("*.md"))
    compiled = [(old, now, why, cg.deprecated_re(old)) for old, now, why in pairs]
    hits = {}
    for path in docs:
        for lineno, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
            for old, now, why, rx in compiled:
                if old not in line or not rx.search(line):
                    continue
                rec = hits.setdefault(old, {"now": now, "why": why, "at": []})
                rec["at"].append((path.name, lineno))
    return hits, len(docs)


def fmt_where(at, limit=3):
    # 파일 이름은 `GDD_v8.0_` 접두를 뗀다 — docs/gdd 안에서만 짝을 찾으면 되고,
    # 접두를 그대로 적으면 문서 검수가 이 줄을 '원본 저장소 숫자 주장' 으로 오인한다.
    names = [f"{fn.replace('GDD_v8.0_', '')}:{ln}" for fn, ln in at[:limit]]
    more = len(at) - len(names)
    return ", ".join(names) + (f" 외 {more}" if more > 0 else "")


def table(rows):
    out = ["| GDD 표기 | 현행 | GDD 위치 | 횟수 |", "|---|---|---|---|"]
    for old, rec in rows:
        out.append(f"| {old} | {rec['now']} | {fmt_where(rec['at'])} | {len(rec['at'])} |")
    return "\n".join(out)


def monster_names():
    """현행 몬스터 이름 — 폐기 표기의 현행 이름이 여기 있으면 몬스터 개명이다."""
    data = json.loads(MONSTERS.read_text(encoding="utf-8"))
    return {m["name"] for m in data["monsters"]}


def split_hits(hits, names):
    """(몬스터 개명, 그 외) — 근거 문장이 아니라 데이터로 가른다."""
    monsters = [(o, r) for o, r in hits.items() if r["now"] in names]
    others = [(o, r) for o, r in hits.items() if r["now"] not in names]
    return monsters, others


def render(hits, ndocs, names):
    monsters, others = split_hits(hits, names)
    monsters.sort(key=lambda kv: (-len(kv[1]["at"]), kv[0]))
    others.sort(key=lambda kv: (-len(kv[1]["at"]), kv[0]))

    lines = [
        "# GDD 이름 대조표 — 생성물",
        "",
        "> `./.venv/bin/python tools/check_gdd_names.py --write` 가 만든다. 손으로 고치지 않는다.",
        f"> 대상: docs/gdd/ 안 md {ndocs}개 · 기준: [용어집](용어집.md) 폐기 표기.",
        "> 위치는 그 폴더 안 파일 이름의 줄 번호다.",
        "",
        "`docs/gdd/` 는 원본 문면이라 고치지 않는다. 그래서 데이터에서 이름을 바꾸면",
        "GDD 사본은 개정 전까지 옛 이름을 들고 있는 것이 **정상**이다. 이 표는 그 간극을 메운다 —",
        "GDD를 읽다가 낯선 이름을 만나면 여기서 현행 이름을 찾는다.",
        "",
        "## 몬스터 이름",
        "",
        "데이터가 이긴다. GDD 표의 옛 이름은 같은 개체의 개정 전 이름이다.",
        "",
        table(monsters) if monsters else "_없음_",
        "",
        "## 그 외 폐기 표기",
        "",
        "용어·직업·키워드처럼 GDD 개정 전 이름. 같은 방식으로 읽는다.",
        "",
        table(others) if others else "_없음_",
        "",
        "## 절차",
        "",
        "[docs/dev/GDD_이름_갱신_절차.md](../dev/GDD_이름_갱신_절차.md) — 개명할 때 어디를 어떤 순서로 고치고,",
        "GDD 개정본이 들어왔을 때 무엇으로 확인하는가.",
        "",
    ]
    return "\n".join(lines)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--write", action="store_true", help="docs/l10n/GDD_이름_대조표.md 를 다시 쓴다")
    ap.add_argument("--strict", action="store_true", help="잔재가 있으면 exit 1 (GDD 재수입 뒤 확인용)")
    ap.add_argument("--quiet", action="store_true", help="요약 한 줄만 (게이트용)")
    args = ap.parse_args()

    if not GLOSSARY.exists():
        print(f"용어집이 없다: {GLOSSARY}", file=sys.stderr)
        return 2
    if not GDD.is_dir():
        print(f"GDD 폴더가 없다: {GDD}", file=sys.stderr)
        return 2

    pairs = cg.deprecated_pairs(GLOSSARY.read_text(encoding="utf-8"))
    names = monster_names()
    hits, ndocs = scan(pairs)
    monsters, _ = split_hits(hits, names)
    total = sum(len(r["at"]) for r in hits.values())

    if args.write:
        OUT.write_text(render(hits, ndocs, names), encoding="utf-8")
        print(f"WROTE {OUT.relative_to(ROOT)} — 몬스터 {len(monsters)}종 · 전체 {len(hits)}표기 / {total}건")

    if not hits:
        print(f"GDD CLEAN — docs/gdd {ndocs}개에 폐기 표기 없음")
        return 0

    print(f"GDD STALE — docs/gdd {ndocs}개에 폐기 표기 {len(hits)}종 / {total}건"
          f" (몬스터 {len(monsters)}종 · 그 외 {len(hits) - len(monsters)}종)")
    if not args.quiet:
        for old, rec in sorted(monsters, key=lambda kv: -len(kv[1]["at"])):
            print(f"  · {old} → {rec['now']}  ({fmt_where(rec['at'])})")
        print("  원본 문면이라 고치지 않는다 — 현행 이름은 docs/l10n/GDD_이름_대조표.md")
    else:
        print("  원본 개정 대기 — 대조표: docs/l10n/GDD_이름_대조표.md")
    return 1 if args.strict else 0


if __name__ == "__main__":
    sys.exit(run("gdd", main))
