#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""gdd_job_pending.py — GDD 직업 표의 개정 대기 목록을 뽑는다 (원본 문면은 건드리지 않는다).

왜 있나:
  docs/gdd/ 는 원본 저장소 기획서의 문면 그대로다 (docs/README.md 규칙 2, AGENTS.md §3).
  그래서 데이터에서 직업·키워드 이름을 바꿔도 GDD 의 직업 표는 옛 이름을 계속 들고 있다.
  check_gdd_names.py 가 이름 전체(몬스터·용어 포함)를 대조하는 데 비해, 이 도구는 **직업 표만**
  본다 — 표 행 안에서 옛 직업·키워드 이름이 현행 이름과 어긋난 자리를 파일·줄·칸 단위로 뽑아,
  원본 저장소에 그대로 올릴 수 있는 개정 요청 목록으로 만든다.

무엇을 직업 표로 보나:
  · 마크다운 표 행(`|` 로 시작)만 본다. 산문은 대상이 아니다 (기계가 문장을 고칠 수 없다).
  · 이름이 직업 표의 이름인지는 data/job_tree.json 으로 정한다 — 직업 34(L1·L2·L3)와
    그 아래 키워드 94. 용어집 폐기 표기 중 현행 이름이 이 안에 있는 것만 후보가 된다.
  · 행에 현행 직업 이름이 있거나, 첫 칸이 빈 이어짐 행(병합 칸)이면 직업 표 행으로 본다.
    첫 칸이 빈 행을 앞 행의 직업에 붙이는 이유: `|  | **항전** | 1 | 근성 | …` 처럼 L2 칸이
    병합된 키워드 표에서 아래 행들이 직업 이름을 안 들고 있기 때문이다.
  · 개정 이력 행(차수·`→`·`구 …` 가 있는 행)은 뺀다. 그 행의 옛 이름은 틀린 것이 아니라
    "무엇이 어떻게 바뀌었나"를 적은 기록이다.

정본 관계:
  data/job_tree.json  >  이 목록  >  docs/gdd/*.md (원본 문면, 개정 전까지 낡은 것이 정상)

사용법:
  ./.venv/bin/python tools/gdd_job_pending.py            # 목록이 낡았는지 검사 (exit 0/1)
  ./.venv/bin/python tools/gdd_job_pending.py --write     # docs/l10n/GDD_직업_개정_대기.md 갱신
  ./.venv/bin/python tools/gdd_job_pending.py --quiet     # 한 줄 요약만 (게이트용)

종료 코드:
  0  목록이 현행과 같다
  1  목록이 낡았다 (GDD 에 옛 이름이 남은 것은 실패가 아니다 — 아래 참고)
  2  설정 오류 (job_tree·용어집·GDD 없음)

  목록이 낡았다는 것과 GDD 에 옛 이름이 남았다는 것은 다르다. 남은 이름은 정상이고(원본이니까),
  목록이 낡은 것만 실패다 — 목록을 다시 뽑으면 되고, GDD 를 고칠 이유가 되지 않는다.
"""
import argparse
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
GDD = ROOT / "docs" / "gdd"
OUT = ROOT / "docs" / "l10n" / "GDD_직업_개정_대기.md"
TREE = ROOT / "data" / "job_tree.json"
GLOSSARY = ROOT / "docs" / "l10n" / "용어집.md"

sys.path.insert(0, str(ROOT / "tools"))
import check_glossary as cg  # noqa: E402 — 폐기 표기 파싱을 한 곳에 둔다
from gate_contract import run  # noqa: E402

# 개정 이력 행 — 옛 이름이 의도적으로 남은 줄.
HISTORY = re.compile(r"\d+차|→|구 ")
WORD = r"(?<![가-힣A-Za-z])%s(?![가-힣A-Za-z])"


def vocabulary():
    """(직업 이름 집합, 키워드 이름 집합) — job_tree.json 이 정본."""
    tree = json.loads(TREE.read_text(encoding="utf-8"))
    jobs = {j["name"] for j in tree["jobs"]}
    kws = {k["name"] for j in tree["jobs"] for k in (j.get("keywords") or [])}
    return jobs, kws


def pairs_of(jobs, kws):
    """용어집 폐기 표기 중 현행 이름이 직업·키워드인 것만."""
    text = GLOSSARY.read_text(encoding="utf-8")
    return [(o, n, why) for o, n, why in cg.deprecated_pairs(text) if n in jobs | kws]


def doubt_tokens():
    """용어집이 "동철 주의"로 표시한 옛 이름 — 다른 뜻으로도 쓰여 기계가 바로 치환할 수 없다."""
    text = GLOSSARY.read_text(encoding="utf-8")
    if "## 폐기 표기" not in text:
        return set()
    out = set()
    for row in text.split("## 폐기 표기", 1)[1].splitlines():
        if not row.startswith("|"):
            continue
        cells = [c.strip() for c in row.strip().strip("|").split("|")]
        if len(cells) < 3 or "동철" not in cells[2]:
            continue
        for old in cells[0].split("` · `"):
            old = old.strip(" `")
            if old:
                out.add(old)
    return out


def job_res(jobs):
    return [(j, re.compile(WORD % re.escape(j))) for j in jobs]


def cells_of(row):
    return [c.strip() for c in row.strip().strip("|").split("|")]


def is_table_row(line):
    """표 행인가 — 구분선(`|---|:--|`)은 표 행이 아니다."""
    s = line.strip()
    return s.startswith("|") and not set(s) <= set("|-: ")


def scan(pairs, jobs):
    """직업 표 행에서 (파일, 줄, 칸, 원문, 현행, 근거, 그 칸의 원문) 을 모은다.

    칸마다 표기 정규식을 다 돌리면 오래 걸린다 — 먼저 `o in c` 로 걸러 낸다. 들어 있지 않은
    표기는 정규식이 맞을 수 없으므로 결과는 같다.
    """
    res = job_res(jobs)
    compiled = [(o, n, why, cg.deprecated_re(o)) for o, n, why in pairs]
    found = []
    for path in sorted(GDD.glob("*.md")):
        last_job = None          # 병합 칸 이어짐 — 앞 행의 직업
        for lineno, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
            if not is_table_row(line):
                if not line.strip():
                    last_job = None
                continue
            row = line.strip()
            cells = cells_of(row)
            # 어느 직업의 표인가 — 이어짐 문맥은 hit 가 없는 행에서도 갱신한다.
            row_job = None
            for _, rx in res:
                for c in cells:
                    m = rx.search(c)
                    if m:
                        row_job = m.group(0)
                        break
                if row_job:
                    break
            if row_job:
                last_job = row_job
            hit = {}
            for ci, c in enumerate(cells):
                for o, n, why, old_rx in compiled:
                    if o in c and old_rx.search(c):
                        hit.setdefault(ci, []).append((o, n, why))
            if not hit:
                continue
            merged = cells[0] == "" and last_job is not None   # 병합 칸 안의 행
            # 직업 칸이 통째로 옛 직업 이름인 행 (병합 칸 없이 독립된 표에서도 포착)
            old_job = any(cells[ci].strip("*` ") == o and n in jobs
                          for ci, toks in hit.items() for o, n, _ in toks)
            if not (row_job or merged or old_job):
                continue
            if HISTORY.search(row):
                continue
            for ci, toks in hit.items():
                found.append((path.name, lineno, ci, toks, cells[ci]))
    return found


def counts(found):
    """(행, 칸, 건수, 표기 종류) — 표기 수는 옛 이름 기준이다."""
    return (len({(f[0], f[1]) for f in found}), len(found),
            sum(len(f[3]) for f in found),
            len({o for f in found for o, _, _ in f[3]}))


def cut(s, n=38):
    s = s.replace("|", "\\|").replace("\n", " ")
    return s if len(s) <= n else s[:n - 1] + "…"


def render(found, jobs, kws, doubt=()):
    checked = set()
    files = []
    for f in found:
        if f[0] not in files:
            files.append(f[0])
    rows, ncell, total, ntok = counts(found)
    lines = [
        "# GDD 직업 표 개정 대기 — 생성물",
        "",
        "> `./.venv/bin/python tools/gdd_job_pending.py --write` 가 만든다. 손으로 고치지 않는다.",
        "> 대상: docs/gdd/*.md 의 표 행 · 기준: data/job_tree.json 이름(직업 %d · 키워드 %d) + 용어집 폐기 표기."
        % (len(jobs), len(kws)),
        "",
        "`docs/gdd/` 는 원본 문면이라 고치지 않는다. 이 파일은 그 대신 **무엇을 어디서 바꿔야 하는지**를",
        "파일·줄·칸 단위로 뽑아 둔 개정 요청서다. GDD 개정본이 들어오면 다시 뽑아 목록을 비운다.",
        "",
        "## 1. 요약",
        "",
        "| 항목 | 값 |",
        "|---|---|",
        "| 개정 대기 행 | %d |" % rows,
        "| 칸 | %d |" % ncell,
        "| 표기 | %d종 |" % ntok,
        "| 건수 | %d |" % total,
        "| 파일 | %d개 |" % len(files),
        "",
    ]
    if not found:
        lines += ["_개정 대기 없음 — GDD 직업 표가 현행 이름과 같다._", "",
                  "## 2. 파일별 개정 대기", "", "_없음_", "",
                  "## 3. 이름별로 모아 보기", "", "_없음_", ""]
    else:
        lines += [
            "## 2. 파일별 개정 대기",
            "",
            "`칸` 은 그 행의 몇 번째 칸인지(1부터)다. `제안` 은 그 칸의 옛 이름을 전부 현행으로 바꾼 글이다.",
            "",
        ]
        for name in files:
            rows = [f for f in found if f[0] == name]
            n = sum(len(r[3]) for r in rows)
            # 숫자는 제목에 두지 않는다 — 문서 검수가 '원본에 대한 숫자 주장' 으로 읽는다.
            lines += ["### %s" % name, "",
                      "%d행 / %d건 — 자체 실측 (이 도구의 검사 출력)"
                      % (len({r[1] for r in rows}), n), ""]
            lines += ["| 줄 | 칸 | 원문 | 현행 | 제안 | 근거 |", "|---|---|---|---|---|---|"]
            for _, lineno, ci, toks, cell in rows:
                new = cell
                for old, now, _ in sorted(toks, key=lambda t: -len(t[0])):
                    new = cg.replace_token(new, old, now)
                left = sorted(t for t in doubt if re.search(WORD % re.escape(t), cell))
                tail = " †" if left else ""
                if left:
                    checked.add(" · ".join(left))
                lines.append("| %d | %d | %s | %s | %s%s | %s |"
                             % (lineno, ci + 1,
                                cut(" · ".join(o for o, _, _ in toks), 24),
                                cut(" · ".join(n for _, n, _ in toks), 24),
                                cut(new), tail, cut(toks[0][2], 44)))
            lines.append("")

        if checked:
            lines += ["† 이 칸에는 동철 표기(%s)가 섞여 있다. 용어집이 기계 치환에서 뺀 글자다 —"
                      " 사람이 읽고 판단한다." % ", ".join(sorted(checked)), ""]

        lines += ["## 3. 이름별로 모아 보기", "",
                  "| 현행 이름 | 건수 | 위치 |", "|---|---|---|"]
        by_now = {}
        for f in found:
            for o, now, why in f[3]:
                by_now.setdefault(now, []).append((f[0], f[1]))
        for now, rows in sorted(by_now.items(), key=lambda kv: (-len(kv[1]), kv[0])):
            where = ", ".join("%s:%d" % (r[0].replace("GDD_v8.0_", ""), r[1]) for r in rows[:4])
            more = len(rows) - 4
            lines.append("| %s | %d | %s%s |"
                         % (now, len(rows), where, " 외 %d" % more if more > 0 else ""))
        lines.append("")

    lines += [
        "## 4. 적용 순서",
        "",
        "1. 이 목록을 원본 저장소에 그대로 올린다 — 파일·줄·칸 단위라 그대로 반영된다.",
        "2. 원본에서 GDD 개정본이 나오면 `docs/gdd/` 를 교체하고 `--write` 로 목록을 다시 뽑는다.",
        "3. 목록이 비면 개정 완료다. `tools/check_gdd_names.py --strict` 로 잔재 0 을 한 번 더 확인한다.",
        "",
        "이 저장소에서 GDD 를 고쳐 해결하지 않는다 — 다음 재수입 때 조용히 되돌아간다.",
        "[GDD_이름_갱신_절차.md](../dev/GDD_이름_갱신_절차.md)",
        "",
        "## 5. 이 목록이 잡지 않는 것",
        "",
        "- **동철 표기** — `물기`·`대가`·`사냥꾼`처럼 다른 뜻으로도 쓰는 옛 이름은 목록에 올리지 않고",
        "  † 표시만 한다. 용어집이 기계 대조에서 빼 둔 글자라 사람이 읽고 정한다.",
        "- **산문** — 표 밖 문장에 남은 옛 이름. 문면 그대로라 기계 치환 대상이 아니다.",
        "- **수치** — `L2 24종` 같은 개수. 이름이 아니라 값이라 이 목록에 없다.",
        "",
    ]
    return "\n".join(lines)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--write", action="store_true", help="docs/l10n/GDD_직업_개정_대기.md 를 다시 쓴다")
    ap.add_argument("--quiet", action="store_true", help="요약 한 줄만 (게이트용)")
    args = ap.parse_args()

    for path in (TREE, GLOSSARY, GDD):
        if not path.exists():
            print("설정 오류 — 없다: %s" % path, file=sys.stderr)
            return 2

    jobs, kws = vocabulary()
    found = scan(pairs_of(jobs, kws), jobs)
    text = render(found, jobs, kws, doubt_tokens())
    old = OUT.read_text(encoding="utf-8") if OUT.exists() else ""
    stale = old != text

    rows, cells, hits, toks = counts(found)
    if args.write:
        OUT.write_text(text, encoding="utf-8")
        print("WROTE %s — 대기 %d행 / %d칸 · %d건 · 표기 %d종"
              % (OUT.relative_to(ROOT), rows, cells, hits, toks))
        return 0

    summary = "GDD 직업 표 — 대기 %d행 / %d칸 · %d건 · 표기 %d종" % (rows, cells, hits, toks)
    if not stale:
        print(("OK — " if not args.quiet else "") + summary + " · 목록 = 현행")
        return 0

    print("STALE — 목록이 현행과 다르다. `--write` 로 다시 뽑는다.")
    print("  " + summary)
    if not args.quiet:
        print("  파일: docs/l10n/GDD_직업_개정_대기.md")
    return 1


if __name__ == "__main__":
    sys.exit(run("gddjob", main))
