#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""gen_gdd_revised.py — GDD 개정 반영본을 만든다 (원본 docs/gdd 는 그대로 둔다).

왜 있나:
  docs/gdd/ 는 원본 저장소 문면이라 고치지 않는다. 그런데 "새 이름으로 읽히는 GDD"가 필요할 때가
  있다 — 구현·검수·번역이 옛 이름을 다시 찾아 헤매지 않도록. 그래서 원본을 복사한 뒤 **직업 표의
  옛 이름만** 새 이름으로 바꾼 사본을 따로 만든다. 원본은 한 글자도 안 바뀐다.

무엇을 바꾸나:
  tools/gdd_job_pending.py 가 뽑은 개정 대기 목록 그대로다 — 파일·줄·칸 단위. 그 밖의 문면
  (산문·개정 이력 행·몬스터 이름·동철 표기)은 손대지 않는다. 사본은 "원본 + 직업 표 개정"이지
  새로 쓴 GDD 가 아니다.

사용법:
  ./.venv/bin/python tools/gen_gdd_revised.py --write   # docs/gdd_개정본/ 생성·갱신
  ./.venv/bin/python tools/gen_gdd_revised.py           # 사본이 현행인지 검사 (게이트 `gddrev`)

종료 코드:
  0  사본 = 원본 + 현재 개정 목록
  1  사본이 낡았다 (--write 로 다시 만든다)
  2  설정 오류 (docs/gdd 없음)
"""
import argparse
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))

import gdd_job_pending as pend  # noqa: E402 — 목록 추출 로직을 한 곳에 둔다
from gate_contract import run  # noqa: E402

SRC = ROOT / "docs" / "gdd"
DST = ROOT / "docs" / "gdd_개정본"
README = DST / "README_개정본.md"


def build():
    """{파일 이름: (개정 반영 본문, 바뀐 칸 수)} — 원본은 읽기만 한다."""
    jobs, kws = pend.vocabulary()
    found = pend.scan(pend.pairs_of(jobs, kws), jobs)

    # 파일별 (줄 → 칸 → [(옛, 새)]) 로 모은다.
    edits = {}
    for name, lineno, ci, toks, _cell in found:
        per_line = edits.setdefault(name, {}).setdefault(lineno, {})
        per_line.setdefault(ci, []).extend((o, n) for o, n, _ in toks)

    out = {}
    for path in sorted(SRC.glob("*.md")):
        lines = path.read_text(encoding="utf-8").splitlines(keepends=True)
        per_line = edits.get(path.name, {})
        changed = 0
        for lineno, cells in per_line.items():
            raw = lines[lineno - 1]
            row = raw.rstrip("\n")
            parts = row.split("|")
            for ci, toks in cells.items():
                # split('|') 는 앞 빈 칸 때문에 인덱스가 하나 밀린다 — 셀 i 는 parts[i+1].
                idx = ci + 1
                cell = parts[idx]
                for old, now in sorted(toks, key=lambda t: -len(t[0])):
                    if old not in cell:
                        raise SystemExit("칸 위치가 어긋났다: %s:%d 칸%d 에 %r 이 없다"
                                         % (path.name, lineno, ci + 1, old))
                    cell = cell.replace(old, now)
                    changed += 1
                parts[idx] = cell
            lines[lineno - 1] = "|".join(parts) + ("\n" if raw.endswith("\n") else "")
        out[path.name] = ("".join(lines), changed)
    return out


README_TEXT = """# GDD 개정 반영본 — 생성물

> `./.venv/bin/python tools/gen_gdd_revised.py --write` 가 만든다. 손으로 고치지 않는다.

`docs/gdd/` 는 원본 문면이라 고치지 않는다. 이 폴더는 그 원본을 **읽기용으로 복사**한 뒤,
직업 표에 남은 옛 이름만 현행 이름으로 바꾼 사본이다.

- 바뀐 곳: [GDD_직업_개정_대기.md](../l10n/GDD_직업_개정_대기.md) 에 적힌 파일·줄·칸 그대로
- 안 바뀐 곳: 산문, 개정 이력 행, 몬스터·용어 이름, 동철 표기
- 정본은 여전히 `data/` 와 `docs/gdd/` 다. 이 폴더는 "새 이름으로 읽으면 어떻게 읽히나"를 보는 사본이다

원본에 개정본이 들어오면 `docs/gdd/` 를 교체하고 `tools/gen_gdd_revised.py --write` 로 다시 만든다.
"""


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--write", action="store_true", help="docs/gdd_개정본/ 를 다시 만든다")
    ap.add_argument("--quiet", action="store_true", help="요약 한 줄만 (게이트용)")
    args = ap.parse_args()

    if not SRC.is_dir():
        print("설정 오류 — docs/gdd 가 없다", file=sys.stderr)
        return 2

    built = build()
    total = sum(c for _, c in built.values())
    names = sorted(built)

    if args.write:
        if DST.exists():
            for old in DST.glob("*.md"):
                old.unlink()
        DST.mkdir(parents=True, exist_ok=True)
        for name in names:
            (DST / name).write_text(built[name][0], encoding="utf-8")
        README.write_text(README_TEXT, encoding="utf-8")
        print("WROTE docs/gdd_개정본/ — 파일 %d개 · 바뀐 칸 %d개" % (len(names), total))
        return 0

    existing = sorted(p.name for p in DST.glob("*.md") if p.name != README.name)
    stale = existing != names
    for name in names:
        if not stale and (DST / name).read_text(encoding="utf-8") != built[name][0]:
            stale = True
            break
    if not stale and README.exists() and README.read_text(encoding="utf-8") != README_TEXT:
        stale = True

    if stale:
        print("STALE — docs/gdd_개정본/ 이 원본 + 개정 목록과 다르다. `--write` 로 다시 만든다.")
        return 1
    print(("OK — " if not args.quiet else "") +
          "GDD 개정본 %d파일 · 바뀐 칸 %d개 · 원본 = docs/gdd" % (len(names), total))
    return 0


if __name__ == "__main__":
    sys.exit(run("gddrev", main))
