#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""gen_gdd_revised.py — GDD 개정 반영본을 만든다 (원본 docs/gdd 는 그대로 둔다).

왜 있나:
  docs/gdd/ 는 원본 저장소 문면이라 고치지 않는다. 그런데 "새 이름으로 읽히는 GDD"가 필요할 때가
  있다 — 구현·검수·번역이 옛 이름을 다시 찾아 헤매지 않도록. 그래서 원본을 복사한 뒤 **직업 표의
  옛 이름만** 새 이름으로 바꾼 사본을 따로 만든다. 원본은 한 글자도 안 바뀐다.

무엇을 바꾸나:
  두 가지다.
  ① tools/gdd_job_pending.py 가 뽑은 직업 표 개정 대기 목록 — 파일·줄·칸 단위.
  ② `REVISIONS` — GDD 문서가 `data/biomes.json`·`monsters.json` 과 어긋난 지점을 사본에서만 바로잡는다.
     (바이옴 계층 13/8/5 · 종 수 · habitat 코드 수 · category 분포 · 문지기 등재 상태)
  ③ `docs/l10n/동철_판정.json` 에서 사람이 `옛 이름` 으로 고른 자리 — 표 밖 줄까지 옮긴다.
  그 밖의 문면(산문·개정 이력 행·몬스터 이름·`다른 뜻` 판정)은 손대지 않는다. 사본은 "원본 + 개정 목록"이지
  새로 쓴 GDD 가 아니다. 원문 앵커가 정확히 1회 없으면 조용히 넘기지 않고 생성이 실패한다.

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

import check_gdd_names as names  # noqa: E402 — 판정 반영·초안 규칙을 한 곳에 둔다
import check_glossary as cg  # noqa: E402 — 낱말 경계 치환을 한 곳에 둔다
import gdd_job_pending as pend  # noqa: E402 — 직업 표 목록을 한 곳에 둔다
from gate_contract import run  # noqa: E402

SRC = ROOT / "docs" / "gdd"
DST = ROOT / "docs" / "gdd_개정본"
VERDICTS = ROOT / "docs" / "l10n" / "동철_판정.json"
README = DST / "README_개정본.md"

# 데이터 대조 개정 — docs/gdd 원본은 그대로 두고 사본에만 반영한다.
# (파일, 원문, 개정문) · 원문이 정확히 1회 없으면 생성이 실패한다 (원본이 바뀐 신호).
# 근거는 전부 data/ 실측이다 — 새 수치를 만들지 않는다. 층 스케일식의 계수는 재산정 전이라
# 숫자를 바꾸지 않고 "미정" 주석만 붙인다.
REVISIONS = (
    (
        "GDD_v8.0_06_바이옴.md",
        "**기존 20개 바이옴(10+9+1) + 천정 신설 6바이옴이 5층 블록 단위로 나눠 갖는**",
        "**기존 21개 바이옴(하층 13 + 중층 8) + 상층 신설 5바이옴이 5층 블록 단위로 나눠 갖는**",
    ),
    (
        "GDD_v8.0_06_바이옴.md",
        "| G1 하부 탑 | 10 | 1~50 | 10 | 그룹 내 랜덤 배정 |\n"
        "| G2 중부 탑 | 9 | 51~95 | 9 | 그룹 내 랜덤 배정 |\n"
        "| G3 정점 | 1 | 96~100 | 1 | 고정 (정점 돌파 — ★6 마일스톤) |\n"
        "| **G4 천정** | 6 | 101~130 | 6 | **신설 (확정 #52)** — 얼은 지상권 6테마: 동결 해양 · 수정 숲 · 무풍 고원 · 유리 사막 · 붕괴 천창 · 이데아 관문 |",
        "| G1 하층 | 13 | 1~65 | 13 | 그룹 내 랜덤 배정 (biomes.json v1.3 자체 실측) |\n"
        "| G2 중층 | 8 | 66~105 | 8 | 그룹 내 랜덤 배정 — 구 G3 정점 역할은 슬롯 21 역류폭포 |\n"
        "| **G4 상층** | 5 | 106~130 | 5 | **신설 (확정 #52)** — 얼은 지상권 5테마: 동결 해양 · 수정 숲 · 유리 사막 · 붕괴 천창 · 이데아 관문 |",
    ),
    (
        "GDD_v8.0_06_바이옴.md",
        "적 스탯 = 기본 스탯 × scale × biome.difficulty.mult\n```",
        "적 스탯 = 기본 스탯 × scale × biome.difficulty.mult\n```\n\n"
        "> 개정 대조 (2026-10-23 · biomes.json v1.3 자체 실측) — 데이터의 층대는 하층 1~65 · 중층 66~105 · 상층 106~130 이다.\n"
        "> 위 G1~G3 식의 계수는 이 층대로 재산정되지 않았다 — **수치 미정**, 새 값을 여기서 만들지 않는다.",
    ),
    (
        "GDD_v8.0_06_바이옴.md",
        "- **데이터:** `data/biomes.json` — 20종 정의",
        "- **데이터:** `data/biomes.json` — 26종 정의 (자체 실측)",
    ),
    (
        "GDD_v8.0_06_바이옴.md",
        "① biomes 20종 카운트 ② habitat 코드 40종 전부 매핑·중복 0 ③ ambient/codex floors와 habitat 정합 ④ groups 층 범위 합 = 1~100 (빈 곳·겹침 0)",
        "① biomes 26종 카운트 ② habitat 코드 46종 전부 매핑·중복 0 ③ ambient/codex floors와 habitat 정합 ④ groups 층 범위 합 = 1~130 (빈 곳·겹침 0) — 자체 실측",
    ),
    (
        "GDD_v8.0_06_바이옴.md",
        "3. **휴식 없음** — 96~100층 구간에 회복 이벤트 0개. 5블록 연속 돌파 구조.",
        "3. **휴식 없음** — 101~105층 구간에 회복 이벤트 0개. 5블록 연속 돌파 구조. (구 G3 정점 → 현 중층 슬롯 21 역류폭포 · biomes.json v1.3 자체 실측)",
    ),
    (
        "GDD_v8.0_06_바이옴.md",
        "96~100층은 모든 요소가 겹치는 정점 돌파 구간(★6 마일스톤)을, 101~130층(천정 — 신설)은 마나 희박·응고 역류체의 상승 최종 구간을 만든다(개정안 §3).",
        "101~105층은 모든 요소가 겹치는 정점 돌파 구간(★6 마일스톤)을, 106~130층(상층 — 신설)은 마나 희박·응고 역류체의 상승 최종 구간을 만든다(개정안 §3 · biomes.json v1.3 자체 실측).",
    ),
    (
        "GDD_v8.0_05_영웅생성.md",
        "바이옴(26종 select — G4 6종 포함)",
        "바이옴(26종 select — 상층 5종 포함)",
    ),
    (
        "GDD_v8.0_07_통합생태계.md",
        "(가안 — 20종 시절 작성 · G4 6종 확장은 06 참조)",
        "(가안 — 20종 시절 작성 · 상층 5종 확장은 06 참조)",
    ),
    (
        "GDD_v8.0_07_통합생태계.md",
        "**현재 도감 총계 377종 = 전투 133 + 비전투 244** (2026-10-02 실측 — 02 문서 §1 정본 표현)",
        "**2026-10-02 스냅샷 도감 총계 377종 = 전투 133 + 비전투 244** (02 문서 §1 표기) — 현 데이터는 **전투 162 + 비전투 215** (2026-10-26 자체 실측 · 이동 29종 = 2026-10-18 사육 5종 + 2026-10-23 블록 16·17·20 5종 + 2026-10-26 먹이층 19종 승격)",
    ),
    (
        "GDD_v8.0_02_생태사전.md",
        "도감 총계 **377종 = 13×29** (레거시 253 + 정령 21 + 균등화 64 + 폴백 13 + 편성 품질 13 + 원천연안 13).",
        "도감 총계 **377종 = 13×29** (레거시 253 + 정령 21 + 균등화 64 + 폴백 13 + 편성 품질 13 + 원천연안 13).\n\n"
        "> 개정 대조 (2026-10-26 · 자체 실측) — 현 데이터는 **전투 162 + 비전투 215** 다. 위 133/244 분해는\n"
        "> 2026-10-02 스냅샷이고, 그 사이 비전투 → 전투로 **29종이 승격**됐다 (2026-10-18 사육 마물 5종 ·\n"
        "> 2026-10-23 블록 16·17·20 5종 · 2026-10-26 먹이층 19종 — `docs/design/피식자_보강_설계.md`).\n"
        "> 합계 377 은 동일하다.",
    ),
    (
        "GDD_v8.0_00_확정사항.md",
        "**20종 (10+9+1) · 5층 블록 슬롯 배정** — G1 10종 1~50층 랜덤 · G2 9종 51~95층 랜덤 · G3 정점 1종 96~100층 고정(최종 스테이지: G1·G2 모디퍼 전부 활성 + 보스HP ×1.2 + 휴식 없음)",
        "**26종 (13+8+5) · 5층 블록 슬롯 배정** — 하층 13종 1~65층 랜덤 · 중층 8종 66~105층 랜덤(구 G3 정점 역할은 슬롯 21 역류폭포: G1·G2 모디퍼 전부 활성 + 보스HP ×1.2 + 휴식 없음) · 상층 5종 106~130층 (자체 실측)",
    ),
    (
        "GDD_v8.0_00_확정사항.md",
        "**※ 수치 보완 (2026-09-21 — 확정 #52 G4 전파)**: G4 천정 6종 101~130층 신설 → **합계 26종**",
        "**※ 수치 보완 (2026-10-23 — biomes.json v1.3 자체 실측)**: 하층 13 · 중층 8 · 상층 5 = **합계 26종**",
    ),
    (
        "GDD_v8.0_00_확정사항.md",
        "(어둠4·극한5·혼돈4·물가3·평온4 = 20종)",
        "(어둠4·극한11·혼돈4·물가3·평온4 = 26종 · 자체 실측)",
    ),
    (
        "GDD_v8.0_00_확정사항.md",
        "**26 바이옴 확정**(5층×26블록 = 10+9+1+6)",
        "**26 바이옴 확정**(5층×26블록 = 13+8+5 · biomes.json v1.3 자체 실측)",
    ),
    (
        "GDD_v8.0_00_확정사항.md",
        "G4는 난이도 정점이라 신규 바이옴 계수·모디퍼 없이 scale 곡선만(06 G4 행 · biomes.json v1.1 26종 반영)",
        "상층은 난이도 정점이라 신규 바이옴 계수·모디퍼 없이 scale 곡선만(06 상층 행 · biomes.json v1.3 26종 반영)",
    ),
    (
        "GDD_v8.0_00_확정사항.md",
        "(20/20 · 구역 5 = 깊이 단계",
        "(26/26 · 구역 5 = 깊이 단계",
    ),
    (
        "GDD_v8.0_00_확정사항.md",
        "정본 biomes.json 20종+G4 6종 = 26세계",
        "정본 biomes.json 21종+상층 5종 = 26세계",
    ),
    (
        "GDD_v8.0_00_확정사항.md",
        "G1~G3 20종 biomes.json gatekeeper 등재(name+epithet) · G4 6종 문서 전용(구현 단계 추가 시 함께)",
        "26종 전부 biomes.json gatekeeper 등재(name+epithet · 자체 실측) — 상층 5종 포함",
    ),
    (
        # 표기 관례 (스타일가이드 §8) — 태그 칸이 사람 이름처럼 읽히지 않게 열 이름에 `태그` 를 붙인다.
        "GDD_v8.0_09_스킬시스템.md",
        "| 각인 가중 | 각인 거부 | AI 특수",
        "| 각인 가중 태그 | 각인 거부 태그 | AI 특수",
    ),
    (
        "GDD_v8.0_09_스킬시스템.md",
        "- **문맥 태그 13종 (행동과 결합되는 상황 라벨)**",
        "> 표기 (2026-10-24 · 자체 판정) — 태그 104종 가운데 `건축가`·`대장장이`·`조약사`·`의사` 넷은 적성 13종과 철자가 같다. 태그 칸에서 이 넷은 사람이 아니라 행동 분류다.\n"
        "> 표 열 이름에 `태그` 를 붙이고, 문장에서는 `태그:` 머리표를 쓴다. 사람을 가리킬 때는 `의사 1명` 처럼 명수를 붙인다.\n"
        "> 표기 정본은 `docs/l10n/표기_스타일가이드.md` §8.\n"
        "\n"
        "- **문맥 태그 13종 (행동과 결합되는 상황 라벨)**",
    ),
    (
        # `태그와 동명 적성 1:1` 은 사실이 아니다 — 철자가 겹지는 넷만 밝힌다 (스타일가이드 §8).
        "GDD_v8.0_09_스킬시스템.md",
        "— 태그와 동명 적성 1:1",
        "— 태그와 철자가 같은 적성은 넷: 건축가·대장장이·조약사·의사",
    ),
    (
        "GDD_v8.0_09_스킬시스템.md",
        "장비정비·조약사 스코어 ×1.2",
        "장비정비·조약사 태그 스코어 ×1.2",
    ),
    (
        "GDD_v8.0_01_등급_전투력.md",
        "20종 = 어둠4·극한5·혼돈4·물가3·평온4",
        "26종 = 어둠4·극한11·혼돈4·물가3·평온4 (biomes.json v1.3 자체 실측)",
    ),
    (
        "GDD_v8.0_08_먹이그물.md",
        "현 도감 총계 377종 = 전투 133 + 비전투 244",
        "현 도감 총계 377종 = 전투 138 + 비전투 239 (자체 실측)",
    ),
)


def apply_revisions(name, text):
    """데이터 대조 개정을 적용한다. 앵커가 1회가 아니면 실패 — 조용히 어긋나면 안 된다."""
    for fname, old, new in REVISIONS:
        if fname != name:
            continue
        n = text.count(old)
        if n != 1:
            raise SystemExit("개정 앵커가 %d회다 (1회여야 한다): %s — %r" % (n, fname, old[:60]))
        text = text.replace(old, new)
    return text


def judged_lines():
    """사람이 `옛 이름` 으로 판정한 줄 — {파일: {줄: {옛: (현행, 근거)}}}.

    판정한 줄은 **그 줄의 옛 이름을 전부** 옮긴다. 한 자리만 옮기면 같은 줄에서
    `목수 · 대장장이 · 조세` 처럼 옛 이름과 새 이름이 섞여 읽힌다.
    `다른 뜻` 으로 판정한 자리는 건드리지 않는다 (apply_verdicts 가 빼 준다).
    """
    if not VERDICTS.exists():
        return {}
    gtext = (ROOT / "docs" / "l10n" / "용어집.md").read_text(encoding="utf-8")
    hits, _ = names.scan(cg.deprecated_pairs(gtext, keep_doubt=True))
    live, _forced, _stats = names.apply_verdicts(hits, names.load_verdicts())
    forced = {(k.rsplit(":", 2)[0], int(k.rsplit(":", 2)[1]))
              for k, v in names.load_verdicts().items() if v[1] == names.RENAME}
    out = {}
    for old, rec in live.items():
        for fn, ln, _line in rec["at"]:
            if (fn, ln) in forced:
                out.setdefault(fn, {}).setdefault(ln, {})[old] = (rec["now"], rec["why"])
    return out


def build():
    """{파일 이름: (개정 반영 본문, 바뀐 칸 수)} — 원본은 읽기만 한다."""
    jobs, kws = pend.vocabulary()
    found = pend.scan(pend.pairs_of(jobs, kws), jobs)
    judged = judged_lines()

    # 파일별 (줄 → 칸 → [(옛, 새)]) 로 모은다.
    edits = {}
    for name, lineno, ci, toks, _cell in found:
        per_line = edits.setdefault(name, {}).setdefault(lineno, {})
        per_line.setdefault(ci, []).extend((o, n) for o, n, _ in toks)

    out = {}
    for path in sorted(SRC.glob("*.md")):
        lines = path.read_text(encoding="utf-8").splitlines(keepends=True)
        per_line = edits.get(path.name, {})
        per_judged = judged.get(path.name, {})
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
                    cell = cg.replace_token(cell, old, now)
                    changed += 1
                parts[idx] = cell
            lines[lineno - 1] = "|".join(parts) + ("\n" if raw.endswith("\n") else "")
        # 사람이 판정한 줄 — 표 밖 줄까지, 그 줄의 옛 이름을 전부 옮긴다.
        for lineno, toks in per_judged.items():
            text = lines[lineno - 1]
            new_text = names.suggested(text, toks, set())
            if new_text != text:
                changed += 1
            lines[lineno - 1] = new_text
        out[path.name] = (apply_revisions(path.name, "".join(lines)), changed)
    return out


README_TEXT = """# GDD 개정 반영본 — 생성물

> `./.venv/bin/python tools/gen_gdd_revised.py --write` 가 만든다. 손으로 고치지 않는다.

`docs/gdd/` 는 원본 문면이라 고치지 않는다. 이 폴더는 그 원본을 **읽기용으로 복사**한 뒤,
직업 표의 옛 이름과 **데이터와 어긋난 서술**을 바로잡은 사본이다.

- 바뀐 곳 ①: [GDD_직업_개정_대기.md](../l10n/GDD_직업_개정_대기.md) 에 적힌 파일·줄·칸 그대로
- 바뀐 곳 ②: `tools/gen_gdd_revised.py` 의 `REVISIONS` — biomes/monsters 실측과 어긋난 바이옴 계층·종 수·category·문지기 서술
- 바뀐 곳 ③: `docs/l10n/동철_판정.json` 이 `옛 이름` 으로 판정한 자리 (적성·태그·산문 포함)
- 안 바뀐 곳: 그 밖의 산문, 개정 이력 행, 몬스터·용어 이름, `다른 뜻` 으로 판정한 동철 표기
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
          "GDD 개정본 %d파일 · 바뀐 칸 %d개 · 데이터 대조 개정 %d건 · 원본 = docs/gdd"
          % (len(names), total, len(REVISIONS)))
    return 0


if __name__ == "__main__":
    sys.exit(run("gddrev", main))
