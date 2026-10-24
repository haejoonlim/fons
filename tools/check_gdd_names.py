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
  ./.venv/bin/python tools/check_gdd_names.py --pending  # docs/l10n/GDD_이름_개정_요청.md 갱신 (원본에 올릴 목록)
  ./.venv/bin/python tools/check_gdd_names.py --choices  # docs/design/동철_판정.html 갱신 (사람이 고르는 화면)
  ./.venv/bin/python tools/check_gdd_names.py --strict   # GDD 재수입 뒤 확인용 — 남으면 exit 1

대조표는 "이 옛 이름은 이 현행 이름이다" 를 보이고, 개정 요청 목록은 같은 간극을 **줄 단위**로
보인다 — 파일·줄·원문·제안이라 원본 저장소에 그대로 올릴 수 있다 (gdd_job_pending.py 와 같은 결).
용어집이 `동철 주의` 로 표시한 표기는 목록에는 올리되 `제안` 을 비운다 — 글자가 다른 뜻으로도
쓰여 기계가 치환하면 문장이 깨지기 때문이다 (판정은 gdd_job_pending.doubt_tokens).
그 자리는 `--choices` 가 만드는 화면에서 사람이 하나씩 고른다. 고른 결과는
`docs/l10n/동철_판정.json` 에 쌓이고, 이 도구가 읽어 `다른 뜻` 자리를 빼고 `옛 이름` 자리에 초안을 붙인다.

종료 코드:
  0  대조 끝 (--strict 아닌 이상 GDD 잔재는 실패가 아니다)
  1  --strict 에서 잔재 있음
  2  설정 오류 (용어집·GDD 없음)
"""
import argparse
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
GDD = ROOT / "docs" / "gdd"
GLOSSARY = ROOT / "docs" / "l10n" / "용어집.md"
MONSTERS = ROOT / "data" / "monsters.json"
JOBS = ROOT / "data" / "job_tree.json"
OUT = ROOT / "docs" / "l10n" / "GDD_이름_대조표.md"
PENDING = ROOT / "docs" / "l10n" / "GDD_이름_개정_요청.md"
# 동철 표기 판정 — 화면(docs/design/동철_판정.html)에서 고른 결과를 붙여 넣는 자리.
# 기계는 판정을 대신하지 않는다. 고른 자리만 목록에서 빼거나 `제안` 에 올린다.
VERDICTS = ROOT / "docs" / "l10n" / "동철_판정.json"
CHOICES = ROOT / "docs" / "design" / "동철_판정.html"

sys.path.insert(0, str(ROOT / "tools"))
import check_glossary as cg  # noqa: E402  — 폐기 표기 파싱을 한 곳에 둔다
import gdd_job_pending as gjp  # noqa: E402  — 동철 표기 판정을 한 곳에 둔다
from gate_contract import run  # noqa: E402

# 개정 이력 줄 — 차수·개칭 이력·화살표로 "무엇이 어떻게 바뀌었나" 를 적은 줄.
# 여기 남은 옛 이름은 틀린 것이 아니라 기록이다. 목록에는 올리되 `이력` 으로 표시해
# 기계적으로 치환하지 않게 한다.
HISTORY = re.compile(r"\d+차|구 ")

# 판정 두 갈래 — 이 자리가 옛 이름인가, 같은 글자의 다른 뜻인가.
RENAME, HOMONYM = "옛 이름", "다른 뜻"


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
                rec["at"].append((path.name, lineno, line))
    return hits, len(docs)


def load_verdicts():
    """`파일:줄:표기` → (표기, 판정). 파일이 없거나 깨졌으면 판정 없이 간다."""
    if not VERDICTS.exists():
        return {}
    try:
        raw = json.loads(VERDICTS.read_text(encoding="utf-8")).get("판정", {})
    except (ValueError, AttributeError):
        print(f"판정 파일을 읽지 못했다: {VERDICTS}", file=sys.stderr)
        return {}
    out = {}
    for key, v in raw.items():
        if isinstance(v, dict) and v.get("판정") in (RENAME, HOMONYM) and v.get("표기"):
            out[key] = (v["표기"], v["판정"])
    return out


def apply_verdicts(hits, verdicts):
    """판정을 반영한다 — `다른 뜻` 자리는 빼고, `옛 이름` 자리는 치환 대상으로 올린다.

    돌려주는 `forced` 는 (표기, 파일, 줄) 묶음이다. 동철 표기는 기본적으로 `제안` 이 비지만
    사람이 '옛 이름' 이라 고른 자리는 초안이 생긴다.
    """
    if not verdicts:
        return hits, set(), (0, 0)
    forced, renamed, dropped = set(), 0, 0
    out = {}
    for old, rec in hits.items():
        keep = []
        for fn, ln, line in rec["at"]:
            v = verdicts.get(f"{fn}:{ln}:{old}")
            if v and v[0] == old:
                if v[1] == HOMONYM:
                    dropped += 1
                    continue
                forced.add((old, fn, ln))
                renamed += 1
            keep.append((fn, ln, line))
        if keep:
            out[old] = {"now": rec["now"], "why": rec["why"], "at": keep}
    return out, forced, (renamed, dropped)


def fmt_where(at, limit=3):
    # 파일 이름은 `GDD_v8.0_` 접두를 뗀다 — docs/gdd 안에서만 짝을 찾으면 되고,
    # 접두를 그대로 적으면 문서 검수가 이 줄을 '원본 저장소 숫자 주장' 으로 오인한다.
    names = [f"{fn.replace('GDD_v8.0_', '')}:{ln}" for fn, ln, _ in at[:limit]]
    more = len(at) - len(names)
    return ", ".join(names) + (f" 외 {more}" if more > 0 else "")


def table(rows):
    out = ["| GDD 표기 | 현행 | GDD 위치 | 횟수 |", "|---|---|---|---|"]
    for old, rec in rows:
        out.append(f"| {old} | {rec['now']} | {fmt_where(rec['at'])} | {len(rec['at'])} |")
    return "\n".join(out)


def keyword_owner():
    """현행 이름 → 그 키워드를 가진 유일한 직업 이름. 둘 이상이면 판단 근거가 못 되므로 넣지 않는다.

    GDD 줄에 그 직업 이름이 같이 나오면 키워드 이름일 가능성이 높다 — 화면이 그 힌트만 보인다.
    """
    own = {}
    for job in json.loads(JOBS.read_text(encoding="utf-8"))["jobs"]:
        for kw in job.get("keywords", []):
            own.setdefault(kw["name"], []).append(job["name"])
    return {kw: names[0] for kw, names in own.items() if len(names) == 1}


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
        "용어집이 동철 주의로 표시한 표기(숙련·기동·물기 등)도 표에 있다 — 다른 뜻으로도 쓰는 글자라",
        "이 표는 읽는 용도이고 일괄 치환의 근거가 아니다. 개정 요청 목록에서도 그런 줄은 `제안` 이 비어 있다.",
        "자리마다 사람이 고르는 화면은 [동철_판정.html](../design/동철_판정.html) (`--choices`).",
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
        "원본 저장소에 올릴 **파일·줄 단위 요청서**는 [GDD_이름_개정_요청.md](GDD_이름_개정_요청.md)",
        "(`check_gdd_names.py --pending` 이 만든다).",
        "",
    ]
    return "\n".join(lines)


def cut(s, n=56):
    s = " ".join(s.replace("|", "\\|").split())
    return s if len(s) <= n else s[:n - 1] + "…"


def cut_around(s, token, n=64):
    """줄머리가 아니라 **그 표기 주변**을 보인다 — 긴 줄에서는 앞부분만 잘라 내면
    원문과 제안이 그림자처럼 같아 보인다."""
    s = " ".join(s.replace("|", "\\|").split())
    i = s.find(token)
    if i < 0:
        return cut(s, n)
    half = max(0, (n - len(token)) // 2)
    start = max(0, i - half)
    end = min(len(s), start + n)
    start = max(0, end - n)
    return ("…" if start > 0 else "") + s[start:end] + ("…" if end < len(s) else "")


def by_line(items):
    """(파일, 줄) 하나에 걸린 표기를 모은다 — 한 줄에 옛 이름이 넷이면 행도 하나다."""
    out = {}
    for old, rec in items:
        for fn, ln, line in rec["at"]:
            slot = out.setdefault((fn, ln), {"line": line, "tokens": {}})
            slot["tokens"][old] = (rec["now"], rec["why"])
    return out


def suggested(line, tokens, skip):
    """그 줄의 옛 이름을 현행으로 바꿔 본 글. 사람이 판단해야 하는 표기(`skip`)는 그대로 둔다."""
    new = line
    for old, (now, _why) in sorted(tokens.items(), key=lambda kv: -len(kv[0])):
        if now == "삭제" or old in skip:
            continue
        # `간호→의사` 처럼 옛 이름과 현행을 나란히 적은 줄은 이미 답을 써 둔 것이다.
        # 치환하면 `의사→의사` 가 된다.
        if re.search(re.escape(old) + r"\s*\*{0,2}\s*→", new):
            continue
        new = cg.replace_token(new, old, now)
    return new


def pending_table(items, doubt, forced):
    slots = by_line(items)
    out = []
    for fn in sorted({k[0] for k in slots}):
        out += ["### %s" % fn, "",
                "| 줄 | 표기 | 원문 | 제안 | 주의 | 출처 |",
                "|---|---|---|---|---|---|"]
        for key in sorted((k for k in slots if k[0] == fn), key=lambda k: k[1]):
            slot = slots[key]
            line = slot["line"]
            toks = slot["tokens"]
            old = " · ".join(sorted(toks))
            now = " · ".join(sorted({v[0] for v in toks.values()}))
            first = min(toks, key=lambda o: line.find(o))
            flags = []
            if HISTORY.search(line):
                flags.append("이력")
            if set(toks) & doubt:
                flags.append("동철")
            if now == "삭제":
                flags.append("삭제")
            # `제안` 의 초점은 첫 **치환 가능한** 표기다 — 동철·삭제 표기를 초점으로 삼으면
            # 그 자리는 바뀌지 않으므로 보일 것이 없다 (줄 앞마리만 잘리게 된다).
            skip = {o for o in toks if o in doubt and (o, key[0], key[1]) not in forced}
            draftable = [o for o in toks if o not in skip and toks[o][0] != "삭제"]
            if draftable:
                anchor = min(draftable, key=lambda o: line.find(o))
                after = cut_around(suggested(line, toks, skip), toks[anchor][0])
            else:
                after = "—"
            # `출처` — 인용한 문면은 GDD 것이고 위치(파일·줄)는 이 도구의 실행 출력이다.
            out.append("| %d | %s | %s | %s | %s | 자체 실측 |" % (
                key[1], cut(old, 30), cut_around(line, first), after,
                " · ".join(flags) or "—"))
        out.append("")
    return out


def render_pending(hits, ndocs, forced=(), stats=(0, 0)):
    names = monster_names()
    doubt = gjp.doubt_tokens()
    monsters, others = split_hits(hits, names)
    monsters.sort(key=lambda kv: (-len(kv[1]["at"]), kv[0]))
    others.sort(key=lambda kv: (-len(kv[1]["at"]), kv[0]))

    total = sum(len(r["at"]) for r in hits.values())
    nlines = len({(fn, ln) for r in hits.values() for fn, ln, _ in r["at"]})
    files = {fn for r in hits.values() for fn, _, _ in r["at"]}
    doubtful = sorted(o for o in hits if o in doubt)
    deleted = sorted(o for o, r in hits.items() if r["now"] == "삭제")
    # 초안을 보일 수 있는 줄 — 동철·삭제 표기가 한 자라도 있으면 사람이 읽는다.
    auto = sum(1 for s in by_line([*monsters, *others]).values()
               if any(o not in doubt and v[0] != "삭제" for o, v in s["tokens"].items()))
    # 판정을 반영한 뒤의 수치 — 1절이 보이는 표와 어긋나지 않게 함께 적는다.
    judged = ("| 동철 판정 | 옛 이름 %d자리 · 다른 뜻 %d자리 ([동철_판정.json](동철_판정.json)) |"
              % stats) if any(stats) else "| 동철 판정 | 아직 없음 — [판정 화면](../design/동철_판정.html) |"

    lines = [
        "# GDD 이름 개정 요청 — 생성물",
        "",
        "> `./.venv/bin/python tools/check_gdd_names.py --pending` 가 만든다. 손으로 고치지 않는다.",
        f"> 장부: [GDD 이름 대조표](GDD_이름_대조표.md) · 기준: [용어집](용어집.md) 폐기 표기"
        f" · 대상: docs/gdd/ 안 md {ndocs}개",
        "",
        "`docs/gdd/` 는 원본 문면이라 이 저장소에서 고치지 않는다 (docs/README.md 규칙 2).",
        "이 파일은 그 대신 **원본 저장소에 올릴 개정 요청**을 파일·줄 단위로 뽑아 둔 것이다.",
        "정본 관계: `data/*.json` 이름 > 이 목록 > `docs/gdd/*.md` (개정 전까지 낡은 것이 정상).",
        "",
        "## 1. 요약",
        "",
        "| 항목 | 값 |",
        "|---|---|",
        f"| 개정 요청 | {total}건 |",
        f"| 표기 | {len(hits)}종 (몬스터 {len(monsters)} · 그 외 {len(others)}) |",
        f"| 줄 | {nlines} (몬스터·용어가 한 줄에 섞이면 2·3절에 둘 다 나온다) |",
        f"| 파일 | {len(files)}개 |",
        f"| 제안 있는 줄 | {auto} (나머지 {nlines - auto}줄은 사람이 읽는다) |",
        f"| 사람 판단 | {len(doubtful) + len(deleted)}종"
        f" (동철 {len(doubtful)} · 삭제 {len(deleted)}) |",
        judged,
        "",
    ]

    if not hits:
        return "\n".join(lines + ["_개정 대기 없음 — GDD 가 현행 이름과 같다._", ""])

    lines += [
        "## 2. 몬스터 이름",
        "",
        "데이터가 이긴다. 아래 옛 이름은 목록 맨 위의 대조표에 폐기로 등록된 같은 개체의 개정 전 이름이다.",
        "",
    ]
    lines += pending_table(monsters, doubt, forced) if monsters else ["_없음_", ""]
    lines += [
        "## 3. 그 외 폐기 표기",
        "",
        "용어·직업·키워드처럼 GDD 개정 전 이름. 같은 방식으로 읽는다.",
        "",
    ]
    lines += pending_table(others, doubt, forced) if others else ["_없음_", ""]

    lines += ["## 4. 이름별로 모아 보기", "",
              "| 현행 | 옛 표기 | 건수 | 위치 |", "|---|---|---|---|"]
    for old, rec in sorted(hits.items(), key=lambda kv: (-len(kv[1]["at"]), kv[0])):
        where = ", ".join("%s:%d" % (fn.replace("GDD_v8.0_", ""), ln)
                          for fn, ln, _ in rec["at"][:4])
        more = len(rec["at"]) - 4
        lines.append("| %s | %s | %d | %s%s |" % (
            rec["now"], old, len(rec["at"]), where, " 외 %d" % more if more > 0 else ""))
    lines.append("")

    lines += [
        "## 5. 적용 순서",
        "",
        "1. 이 표를 원본 저장소에 그대로 올린다 — 파일·줄 단위다.",
        "2. **줄 번호는 지금 문면 기준이다.** 위에서부터 고치면 아래 번호가 밀리므로 파일 안에서",
        "   **아래에서 위로** 적용하거나, 치환을 한 번에 돌리고 `--pending` 으로 다시 대조한다.",
        "3. GDD 개정본이 들어오면 `docs/gdd/` 를 교체하고 `--write` 와 `--pending` 을 다시 돌린다.",
        "4. 목록이 비면 개정 완료다. `tools/check_gdd_names.py --strict` 로 잔재 0 을 확인한다.",
        "",
        "## 6. 이 목록이 잡지 않는 것",
        "",
        "`제안` 은 기계 치환 초안이지 판정이 아니다. 같은 글자가 다른 뜻으로 쓰인 자리",
        "(예: `숙련 보정` 의 숙련도)는 문맥을 읽고 건너뛴다.",
        "",
        "- **이력 줄** — 차수(`47차`)나 `구 …` 가 들어간 줄은 그 옛 이름이 틀린 것이 아니라 기록이다.",
        "  `주의` 에 `이력` 이라 적었다 — 치환 전에 줄을 읽는다.",
        "- **동철 표기** — 용어집이 '동철 주의'로 표시한 글자는 목록에는 올리되 `제안` 을 비웠다",
        f"  (지금 {len(doubtful)}종). 다른 뜻으로도 쓰는 글자라 기계가 치환하면 문장이 깨진다.",
        "  `주의` 에 `동철` 이 붙는다 — 줄을 읽고 손으로 고친다.",
        "  자리마다 [동철 판정 화면](../design/동철_판정.html)에서 '옛 이름·다른 뜻' 을 고르면",
        "  판정이 [동철_판정.json](동철_판정.json) 을 거쳐 이 목록에 반영된다.",
        "- **삭제 표기** — 현행이 `삭제` 인 옛 이름은 쓸 대체 이름이 없다. 줄 전체를 사람이 고친다.",
        "- **수치** — `L2 24종` 같은 개수는 이름이 아니라 값이다. 이 목록에 없다.",
        "",
        "[GDD_이름_갱신_절차.md](../dev/GDD_이름_갱신_절차.md) — 개명할 때 어느 순서로 고치는가.",
        "",
    ]
    return "\n".join(lines)


CHOICES_TMPL = """<!DOCTYPE html>
<html lang="ko">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>GDD 동철 표기 판정 — 폰즈</title>
<style>
  :root{--bg:#12121a;--panel:#1b1b26;--panel2:#22222f;--line:#33334a;--text:#e8e8f2;
    --dim:#9a9ab4;--accent:#c9a227;--pick:#7ee2b8;--warn:#ff9f6e}
  *{box-sizing:border-box}
  body{margin:0;background:var(--bg);color:var(--text);line-height:1.55;padding:24px 20px 120px;
    font-family:-apple-system,BlinkMacSystemFont,"Apple SD Gothic Neo","Noto Sans KR",sans-serif}
  header{max-width:980px;margin:0 auto}
  h1{font-size:20px;margin:0 0 6px}
  .lead{color:var(--dim);font-size:13px;margin:0 0 14px;max-width:760px}
  .lead b{color:var(--text)}
  .tools{display:flex;gap:10px;align-items:center;flex-wrap:wrap;margin-bottom:6px}
  .tools input[type=search]{flex:1;min-width:180px;background:#15151f;border:1px solid var(--line);
    border-radius:6px;color:var(--text);padding:8px 10px;font-size:13px}
  .tools label{font-size:12.5px;color:var(--dim);display:flex;gap:6px;align-items:center}
  .count{font-size:12.5px;color:var(--dim)}
  .count b{color:var(--pick)}
  .badge{font-size:11px;color:var(--accent);margin-left:8px}
  .hintchip{font-size:10.5px;color:#1a1a12;background:var(--accent);border-radius:4px;
    padding:1px 5px;margin-left:6px;font-weight:700}
  .bulk{display:flex;gap:6px;margin:7px 0 0}
  .bulk button{font-size:11.5px;padding:4px 9px;border-radius:5px}
  .picks{display:grid;gap:7px;margin-top:9px}
  .pick{border-top:1px solid var(--line);padding-top:7px}
  .pick:first-child{border-top:0;padding-top:0}
  .pick .pname{font-size:13.5px;font-weight:600}
  .pick.done .old{color:var(--pick)}
  .pick .why{margin:3px 0 0;font-size:11px}
  .pick .opts{margin-top:5px}
  .pick .opts label{min-width:150px;padding:5px 9px;font-size:12.5px}
  h3.sec{max-width:980px;margin:22px auto 8px;font-size:13.5px;border-left:3px solid var(--accent);
    padding-left:10px}
  h3.sec small{color:var(--dim);font-weight:400;font-size:12px;margin-left:6px}
  main{max-width:980px;margin:0 auto;display:grid;gap:10px}
  .card{background:var(--panel);border:1px solid var(--line);border-radius:8px;padding:13px 15px}
  .card.done{border-color:#3d6b58}
  .card.hide{display:none}
  .top{display:flex;align-items:baseline;gap:8px;flex-wrap:wrap}
  .old{font-size:14.5px;font-weight:700;color:var(--warn)}
  .arrow{color:var(--dim)}
  .now{color:var(--pick);font-weight:700;font-size:14px}
  .meta{font-size:11.5px;color:var(--dim);margin-left:auto;font-family:ui-monospace,Menlo,monospace}
  .line{font-size:12.6px;color:#cfcfe0;margin:8px 0 0;padding:8px 10px;background:#16161f;
    border-radius:6px;border-left:2px solid #4a4a66;cursor:pointer}
  .line .more{color:var(--accent);font-size:11.5px;margin-left:4px}
  mark{background:#3a3320;color:#ffe9a8;padding:0 2px;border-radius:3px}
  .why{font-size:11.5px;color:var(--dim);margin:6px 0 0}
  .opts{display:flex;gap:8px;margin-top:9px;flex-wrap:wrap}
  .opts label{flex:1;min-width:190px;display:flex;align-items:center;gap:8px;padding:7px 10px;
    border:1px solid var(--line);border-radius:6px;cursor:pointer;background:var(--panel2);font-size:13px}
  .opts label:hover{border-color:#4a4a66}
  .opts label.sel{border-color:#3d6b58;background:#1c2a24}
  .opts input{accent-color:#4fbf90;margin:0}
  footer{position:fixed;left:0;right:0;bottom:0;background:#0e0e15;border-top:1px solid var(--line);
    padding:11px 20px;display:flex;gap:10px;align-items:center;flex-wrap:wrap}
  footer .count{margin-right:auto}
  button{background:var(--panel2);color:var(--text);border:1px solid var(--line);border-radius:6px;
    padding:8px 13px;font-size:13px;cursor:pointer}
  button:hover{border-color:#5a5a78}
  button.primary{background:var(--accent);color:#1a1a12;border-color:var(--accent);font-weight:700}
  textarea{width:100%;max-width:980px;margin:16px auto 0;background:#15151f;border:1px solid var(--line);
    border-radius:6px;color:var(--text);padding:12px;font-size:12px;height:180px;display:none;
    font-family:ui-monospace,SFMono-Regular,Menlo,monospace}
</style>
</head>
<body>
<header>
  <h1>GDD 동철 표기 판정</h1>
  <p class="lead">
    용어집이 <b>동철 주의</b> 로 표시한 __K__종이 GDD __L__줄 __N__자리에 나온다. 같은 글자가 <b>이름</b>으로도
    <b>보통명사</b>로도 쓰여서, 기계가 일괄 치환하면 문장이 깨진다. 카드마다 묻는 것은 하나다 —
    <b>이 자리의 글자가 옛 스킬·직업·몬스터 이름인가?</b><br>
    목록·표의 이름 칸이나 “스킬 ○○” 처럼 이름으로 쓰였으면 <b>옛 이름</b> — 바뀔 이름을 카드에 적었다.
    문장 속 동작·도구·일반명사로 쓰였으면 <b>다른 뜻</b> — 글자를 그대로 둔다.<br>
    <b>길잡이 키워드</b> 같은 표시는 그 현행 이름이 그 직업에만 붙은 키워드이고, 이 줄에 그 직업 이름이
    함께 나온다는 뜻이다 — 이름으로 읽을 근거가 하나 더 있는 셈이다.<br>
    고른 결과는 아래 <b>판정 JSON 복사</b> 로 떠서 <code>docs/l10n/동철_판정.json</code> 에 붙여 넣고,
    <code>check_gdd_names.py --pending</code> 을 다시 돌린다.
  </p>
  <div class="tools">
    <input id="q" type="search" placeholder="파일 이름·표기로 거르기">
    <label><input type="checkbox" id="todo"> 미정만 보기</label>
    <span id="count" class="count"></span>
  </div>
</header>
<main id="list"></main>
<textarea id="out" spellcheck="false" readonly></textarea>
<footer>
  <span id="pad" class="count"></span>
  <button id="json">JSON 보기</button>
  <button class="primary" id="copy">판정 JSON 복사</button>
</footer>
<script>
const ROWS = __DATA__;
const FILE = "docs/l10n/동철_판정.json";
const STORE = "fons.homonym";
let picked = JSON.parse(localStorage.getItem(STORE) || "{}");

const list = document.getElementById("list");
const FULL = new Map();
const TRIM = new Map();
let last = "";
for (const r of ROWS) {
  const wid = `${r.f}:${r.n}`;
  if (r.f !== last) {
    const h = document.createElement("h3");
    h.className = "sec";
    h.innerHTML = `${esc(r.f)} <small>${ROWS.filter(x => x.f === r.f).length}줄</small>`;
    list.appendChild(h);
    last = r.f;
  }
  const card = document.createElement("div");
  card.className = "card";
  card.dataset.w = wid;
  card.dataset.f = r.f;
  const toks = r.toks.map(t => t.o);
  card.dataset.toks = toks.join(" ");
  FULL.set(wid, mark(r.line, toks, 0));
  TRIM.set(wid, mark(r.line, toks, 190));
  card.innerHTML = `
    <div class="top"><span class="meta">${esc(r.f.replace("GDD_v8.0_", ""))}:${r.n}</span>
      ${r.toks.length > 1 ? `<span class="badge">${r.toks.length}표기</span>` : ""}</div>
    <p class="line" data-open="">${TRIM.get(wid)}</p>
    ${r.toks.length > 1 ? `<div class="bulk">
      <button data-bulk="다른 뜻">이 줄 모두 다른 뜻</button>
      <button data-bulk="옛 이름">이 줄 모두 옛 이름</button></div>` : ""}
    <div class="picks">${r.toks.map(tokRow).join("")}</div>`;
  list.appendChild(card);
}

// 한 줄에 동철 표기가 여럿이면 카드 하나에 선택 줄을 여럿 둔다 — 같은 줄을 되풀이해 보이지 않게.
function tokRow(t) {
  // 조사는 받침을 본다 — 투창'으로' · 의사'로'. 현행이 `삭제` 면 부를 이름이 없다고 적는다.
  const tail = t.now.charCodeAt(t.now.length - 1);
  const jong = t.now === "삭제" ? 0 : (tail - 0xAC00) % 28;
  const ro = jong === 0 || jong === 8 ? "로" : "으로";
  const alt = t.now === "삭제"
    ? "<b>옛 이름</b> — 여기서는 이름. 현행 이름이 없다(삭제 표기)"
    : `<b>옛 이름</b> — <code>${esc(t.now)}</code>${ro} 바꾼다`;
  return `
    <div class="pick" data-k="${esc(t.k)}">
      <div class="pname"><span class="old">${esc(t.o)}</span><span class="arrow">→</span>
        <span class="now">${esc(t.now)}</span>
        ${t.hint ? `<span class="hintchip">${esc(t.hint)} 키워드</span>` : ""}</div>
      <div class="opts">
        <label><input type="radio" name="${esc(t.k)}" value="다른 뜻">
          <span><b>다른 뜻</b> — 보통명사. <code>${esc(t.o)}</code> 그대로 둔다</span></label>
        <label><input type="radio" name="${esc(t.k)}" value="옛 이름">
          <span>${alt}</span></label>
      </div>
      <p class="why">용어집 근거: ${esc(clean(t.why))}</p>
    </div>`;
}

function esc(s) {
  return String(s).replace(/[&<>"]/g, c => ({"&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;"}[c]));
}
// GDD 는 마크다운 표다 — 카드 안에서는 \"코드처럼\" 보이므로 장식만 지운다.
function clean(s) {
  return String(s).replace(/\\"/g, '"').replace(/\*\*/g, "").replace(/`/g, "")
    .replace(/\s*\|\s*/g, " · ").replace(/^\s*·\s*|\s*·\s*$/g, "").replace(/\s+/g, " ").trim();
}
function mark(line, tokens, cap) {
  let t = clean(line);
  let more = "";
  if (cap && t.length > cap) {
    t = t.slice(0, cap).replace(/\s+\S*$/, "") + "…";
    more = '<span class="more">더 보기</span>';
  }
  let out = esc(t);
  for (const tok of (Array.isArray(tokens) ? tokens : [tokens])) {
    out = out.replace(esc(tok), `<mark>${esc(tok)}</mark>`);
  }
  return out + more;
}
function paint() {
  document.querySelectorAll(".pick").forEach(p => {
    const v = picked[p.dataset.k];
    p.classList.toggle("done", !!v);
    p.querySelectorAll("input").forEach(i => {
      i.checked = v === i.value;
      i.closest("label").classList.toggle("sel", v === i.value);
    });
  });
  document.querySelectorAll(".card").forEach(card => {
    const keys = [...card.querySelectorAll(".pick")].map(p => p.dataset.k);
    card.classList.toggle("done", keys.length > 0 && keys.every(k => picked[k]));
  });
  const n = Object.values(picked).length;
  const said = `__N__자리 중 <b>${n}</b> 고름`;
  document.getElementById("count").innerHTML = said;
  document.getElementById("pad").innerHTML = said;
  filter();
}
function filter() {
  const q = document.getElementById("q").value.trim();
  const todo = document.getElementById("todo").checked;
  document.querySelectorAll(".card").forEach(card => {
    const left = [...card.querySelectorAll(".pick")].filter(p => !picked[p.dataset.k]);
    const hit = (!q || (card.dataset.f + " " + card.dataset.toks).includes(q))
      && (!todo || left.length > 0);
    card.classList.toggle("hide", !hit);
  });
  document.querySelectorAll("h3.sec").forEach(h => {
    let n = h.nextElementSibling, shown = 0;
    while (n && n.classList.contains("card")) {
      if (!n.classList.contains("hide")) shown++;
      n = n.nextElementSibling;
    }
    h.classList.toggle("hide", !shown);
  });
}
function dump() {
  const 판정 = {};
  document.querySelectorAll(".pick").forEach(p => {
    const v = picked[p.dataset.k];
    if (v) 판정[p.dataset.k] = {표기: p.querySelector(".old").textContent.trim(), 판정: v};
  });
  return JSON.stringify({
    _설명: "GDD 동철 표기 판정 — docs/design/동철_판정.html 에서 고른 결과. " +
      "check_gdd_names.py 가 읽어 `다른 뜻` 자리를 목록에서 빼고 `옛 이름` 자리에 `제안` 을 붙인다.",
    판정
  }, null, 2);
}
list.addEventListener("click", e => {
  const bulk = e.target.closest("[data-bulk]");
  if (bulk) {
    const value = bulk.dataset.bulk;
    bulk.closest(".card").querySelectorAll(".pick").forEach(p => { picked[p.dataset.k] = value; });
    localStorage.setItem(STORE, JSON.stringify(picked));
    paint();
    return;
  }
  const el = e.target.closest(".line");
  if (!el) return;
  const k = el.closest(".card").dataset.w;
  const open = el.dataset.open === "1";
  el.innerHTML = open ? TRIM.get(k) : FULL.get(k);
  el.dataset.open = open ? "" : "1";
});
list.addEventListener("change", e => {
  const pick = e.target.closest(".pick");
  if (!pick) return;
  picked[pick.dataset.k] = e.target.value;
  localStorage.setItem(STORE, JSON.stringify(picked));
  paint();
});
document.getElementById("q").addEventListener("input", filter);
document.getElementById("todo").addEventListener("change", filter);
document.getElementById("json").addEventListener("click", () => {
  const box = document.getElementById("out");
  box.value = dump();
  box.style.display = box.style.display === "block" ? "none" : "block";
});
document.getElementById("copy").addEventListener("click", async e => {
  const text = dump();
  try {
    await navigator.clipboard.writeText(text);
    e.target.textContent = FILE + " 에 붙여 넣으세요 — 복사됨";
  } catch (err) {
    const box = document.getElementById("out");
    box.value = text;
    box.style.display = "block";
    box.select();
    e.target.textContent = "복사가 막혔다 — 아래 상자를 직접 복사";
  }
  setTimeout(() => { e.target.textContent = "판정 JSON 복사"; }, 4000);
});
paint();
</script>
</body>
</html>
"""


def render_choices(hits):
    """한 줄에 동철 표기가 여럿이면 카드 하나에 선택 줄을 여럿 둔다 — 같은 줄을 되풀이하지 않는다."""
    doubt = gjp.doubt_tokens()
    owner = keyword_owner()
    slots = {}
    for old, rec in hits.items():
        if old not in doubt:
            continue
        for fn, ln, line in rec["at"]:
            slot = slots.setdefault((fn, ln), {"f": fn, "n": ln, "line": line, "toks": []})
            job = owner.get(rec["now"])
            slot["toks"].append({"o": old, "now": rec["now"], "why": rec["why"],
                                 "k": "%s:%d:%s" % (fn, ln, old),
                                 "hint": job if job and job in line else ""})
    rows = [slots[k] for k in sorted(slots)]
    for row in rows:
        row["toks"].sort(key=lambda t: row["line"].find(t["o"]))
    ntok = sum(len(row["toks"]) for row in rows)
    kinds = {t["o"] for row in rows for t in row["toks"]}
    html = (CHOICES_TMPL
            .replace("__DATA__", json.dumps(rows, ensure_ascii=False))
            .replace("__N__", str(ntok))
            .replace("__L__", str(len(rows)))
            .replace("__K__", str(len(kinds))))
    return html, ntok, len(kinds), len(rows)


def selftest() -> int:
    """판정 반영 규칙 자기 검사 — 사람 손을 타지 않는 네 경우만 본다."""
    hits = {"숙련": {"now": "추적", "why": "동철 주의",
                    "at": [("a.md", 1, "숙련 보정"), ("a.md", 2, "숙련 보정")]}}
    verdicts = {"a.md:1:숙련": ("숙련", HOMONYM), "a.md:2:숙련": ("숙련", RENAME),
                "a.md:9:조류": ("조류", HOMONYM)}
    live, forced, stats = apply_verdicts(hits, verdicts)
    assert stats == (1, 1), stats
    assert [a[1] for a in live["숙련"]["at"]] == [2], live
    assert forced == {("숙련", "a.md", 2)}, forced
    md = render_pending(live, 1, forced, stats)
    assert "추적 보정" in md, "옛 이름 판정이 초안으로 안 갔다"
    assert "옛 이름 1자리" in md, "요약 미반영"
    empty = {"x": {"now": "y", "why": "", "at": [("a.md", 3, "x")]}}
    assert apply_verdicts(empty, {})[1] == set(), "판정 없으면 그대로일 것"
    # 치환 초안의 두 함정 — 합성어를 건드리거나, 이미 써 둔 개명 표기를 다시 쓴다.
    assert (cg.replace_token("대장간의 불꽃 = 대장 390", "대장", "대장장이")
            == "대장간의 불꽃 = 대장장이 390"), "낱말 경계 치환 실패"
    mapped = "> 개명 4건(간호→**의사**)"
    assert suggested(mapped, {"간호": ("의사", "")}, set()) == mapped, "개명 표기를 다시 썼다"
    print("VERDICT OK — 다른 뜻 1자리 제외 · 옛 이름 1자리 초안")
    return 0


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--write", action="store_true", help="docs/l10n/GDD_이름_대조표.md 를 다시 쓴다")
    ap.add_argument("--pending", action="store_true",
                    help="docs/l10n/GDD_이름_개정_요청.md 를 다시 쓴다 (파일·줄 단위)")
    ap.add_argument("--choices", action="store_true",
                    help="docs/design/동철_판정.html 을 다시 쓴다 (동철 표기 자리별 선택 화면)")
    ap.add_argument("--strict", action="store_true", help="잔재가 있으면 exit 1 (GDD 재수입 뒤 확인용)")
    ap.add_argument("--selftest", action="store_true", help="동철 판정 반영 규칙 자기 검사")
    ap.add_argument("--quiet", action="store_true", help="요약 한 줄만 (게이트용)")
    args = ap.parse_args()

    if args.selftest:
        return selftest()

    if not GLOSSARY.exists():
        print(f"용어집이 없다: {GLOSSARY}", file=sys.stderr)
        return 2
    if not GDD.is_dir():
        print(f"GDD 폴더가 없다: {GDD}", file=sys.stderr)
        return 2

    # 동철 표기까지 받아야 목록에 남는다 — `제안` 은 suggested() 가 비운다.
    pairs = cg.deprecated_pairs(GLOSSARY.read_text(encoding="utf-8"), keep_doubt=True)
    names = monster_names()
    hits, ndocs = scan(pairs)
    # 판정은 목록·화면에만 반영한다 — 대조표는 '낯선 이름을 찾는 표' 이라 그대로 둔다.
    live, forced, stats = apply_verdicts(hits, load_verdicts())
    monsters, _ = split_hits(hits, names)
    total = sum(len(r["at"]) for r in live.values())

    if args.write:
        OUT.write_text(render(hits, ndocs, names), encoding="utf-8")
        raw = sum(len(r["at"]) for r in hits.values())
        print(f"WROTE {OUT.relative_to(ROOT)} — 몬스터 {len(monsters)}종 · 전체 {len(hits)}표기 / {raw}건")

    if args.pending:
        PENDING.write_text(render_pending(live, ndocs, forced, stats), encoding="utf-8")
        print(f"WROTE {PENDING.relative_to(ROOT)} — 개정 요청 {total}건 · {len(live)}표기"
              f" (판정: 옛 이름 {stats[0]} · 다른 뜻 {stats[1]})")

    if args.choices:
        html, ntok, nmarks, nlines = render_choices(live)
        CHOICES.write_text(html, encoding="utf-8")
        print(f"WROTE {CHOICES.relative_to(ROOT)} — 동철 {nmarks}종 / {nlines}줄 / {ntok}자리")

    if not live:
        print(f"GDD CLEAN — docs/gdd {ndocs}개에 폐기 표기 없음")
        return 0

    print(f"GDD STALE — docs/gdd {ndocs}개에 폐기 표기 {len(live)}종 / {total}건"
          f" (몬스터 {len(monsters)}종 · 그 외 {len(live) - len(monsters)}종)")
    if not args.quiet:
        for old, rec in sorted(monsters, key=lambda kv: -len(kv[1]["at"])):
            print(f"  · {old} → {rec['now']}  ({fmt_where(rec['at'])})")
        print("  원본 문면이라 고치지 않는다 — 현행 이름은 docs/l10n/GDD_이름_대조표.md")
    else:
        print("  원본 개정 대기 — 대조표: docs/l10n/GDD_이름_대조표.md")
    return 1 if args.strict else 0


if __name__ == "__main__":
    sys.exit(run("gdd", main))
