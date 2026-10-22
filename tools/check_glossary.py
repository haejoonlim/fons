#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""check_glossary.py — 용어집 표기가 정본에 실제로 있는지 검사한다.

왜 있나:
  docs/l10n/용어집.md 는 "이렇게 쓴다"를 정하는 문서다. 그런데 손으로 적으면
  데이터에 없는 이름을 지어내거나, 폐기된 표기를 표준으로 되돌려 놓기 쉽다.
  그래서 용어집의 모든 코드 표기(`...`)를 모아 정본 코퍼스에서 찾는다.

정본 코퍼스:
  data/*.json  — 고유명사 철자 정본
  docs/gdd/*.md — 시스템 용어 뜻 정본

규칙:
  - 용어집의 `...` 표기는 코퍼스에 **낱말 단위로** 있어야 한다 (exit 1).
    부분 문자열 대조를 쓰면 `골드러시` 하나 때문에 `골드` 가 통과한다 — 그래서 경계를 본다.
  - 폐기 표기는 코퍼스(데이터·GDD)에 남아 있어도 된다 (역사 기록이므로).
  - 폐기 표기가 **쓰는 표면**(docs/, sim/center/pages/, godot/)에 남아 있으면 보고한다.
    경고다 (--strict 로만 exit 1). 다음 두 경우는 빼고 본다:
      · 근거에 "동철 주의"가 적힌 표기 — `수호`(defend 미션)·`화염`(원소)처럼 다른 뜻으로도 쓰인다
      · 바로 앞에 `구 `가 붙은 표기 — 폐기를 밝히는 이력 표기 (`서고 (구 대도서관)`)

사용법:
  ./.venv/bin/python tools/check_glossary.py
  ./.venv/bin/python tools/check_glossary.py --list        # 검사 대상 표기 출력
  ./.venv/bin/python tools/check_glossary.py --deprecated  # 폐기 표기 잔재 보고
  ./.venv/bin/python tools/check_glossary.py --deprecated --strict

종료 코드:
  0  전부 정본에 있음 (--strict 아닌 이상 폐기 잔재는 경고)
  1  없는 표기 있음 / --strict 에서 폐기 잔재 있음
  2  사용법/설정 오류
"""
import argparse
import json
import re
import sys
from pathlib import Path

from gate_contract import run

ROOT = Path(__file__).resolve().parent.parent
GLOSSARY = ROOT / "docs" / "l10n" / "용어집.md"
DATA = ROOT / "data"
GDD = ROOT / "docs" / "gdd"

CODE_SPAN = re.compile(r"`([^`\n]+)`")

# 데이터 키가 복수형·복합형이라 단독 토큰으로는 없는 ID.
# (검사는 "그 표기가 이름으로 존재하는가"이므로 접두 일치까지 인정한다.)
ID_PREFIX_OK = ("subrace", "edict")

# 폐기 표기를 보고할 표면 — 쓰는 쪽. 원본·이력 문서는 뺀다.
SURFACE_GLOBS = (
    "docs/**/*.md",
    "sim/center/pages/*.html",
    "godot/**/*.gd",
)
#   · GDD_이름_대조표.md — 폐기 표기를 현행과 짝지은 표. 옛 이름이 표에 있는 것이 목적이므로 뺀다.
#   · GDD_직업_개정_대기.md — 같은 이유. 직업 표의 옛 이름을 현행과 짝지은 개정 요청 목록이다.
SURFACE_SKIP = ("/gdd/", "/gdd_개정본/", "/original/", "용어집.md", "GDD_이름_대조표.md",
                 "GDD_직업_개정_대기.md")


# 낱말 경계 — 정규식 `[가-힣A-Za-z]` 와 같은 문자만 본다.
# (2026-10-18: 표기 306개를 각각 정규식으로 훑으면 1.9MB 코퍼스에서 7.5초가 걸렸다.
#  같은 판정을 str.find + 문자 비교로 옮겨 0.2초가 됐고, 결과는 306개 전부 같다.)


def latin_char(ch: str) -> bool:
    return "a" <= ch <= "z" or "A" <= ch <= "Z"


def word_char(ch: str) -> bool:
    """`[가-힣A-Za-z]` 에 속하는가."""
    return latin_char(ch) or "\uac00" <= ch <= "\ud7a3"


def find_token(token: str, text: str, prefix: bool = False) -> bool:
    """낱말 경계를 지키면서 token 이 text 에 있는가.

    prefix=False  앞뒤에 한글·라틴 문자가 없어야 한다 (예전 token_re 와 같은 판정
                  — 표기 306건·경계 합성 문자열에서 결과가 전부 같음을 확인했다)
    prefix=True   뒤에 라틴 문자가 와야 한다 (ID_PREFIX_OK — `subrace_경로` 같은 항목)
    """
    start, n, end = 0, len(token), len(text)
    while True:
        i = text.find(token, start)
        if i < 0:
            return False
        if i == 0 or not word_char(text[i - 1]):
            j = i + n
            if prefix:
                if j < end and latin_char(text[j]):
                    return True
            elif j >= end or not word_char(text[j]):
                return True
        start = i + 1


def present(token: str, haystack: str) -> bool:
    """표기가 정본 코퍼스에 있는가 — 이름 그대로, 또는 ID 접두 규칙으로."""
    if find_token(token, haystack):
        return True
    return token in ID_PREFIX_OK and find_token(token, haystack, prefix=True)


def deprecated_re(token: str) -> re.Pattern:
    """폐기 표기용 — '구 비홀더'처럼 폐지를 밝힌 이력 표기는 잔재가 아니다."""
    return re.compile(r"(?<!구 )(?<![가-힣A-Za-z])" + re.escape(token) + r"(?![가-힣A-Za-z])")


def deprecated_pairs(text: str):
    """용어집 \"폐기 표기\" 표에서 (구 표기, 현행, 근거) 를 뽑는다."""
    if "## 폐기 표기" not in text:
        return []
    section = text.split("## 폐기 표기", 1)[1]
    rows = [line for line in section.splitlines() if line.startswith("|")]
    out = []
    for row in rows[2:]:
        cells = [c.strip() for c in row.strip().strip("|").split("|")]
        if len(cells) < 2:
            continue
        why = cells[2] if len(cells) > 2 else ""
        if "동철" in why:
            continue   # 다른 뜻으로도 쓰이는 글자 — 기계가 선별할 수 없다
        for old in cells[0].split("` · `"):
            old = old.strip(" `")
            if old:
                out.append((old, cells[1].strip(" `"), why))
    return out


def surface_files():
    seen = set()
    for pattern in SURFACE_GLOBS:
        for path in ROOT.glob(pattern):
            rel = str(path.relative_to(ROOT))
            if any(skip in f"/{rel}" for skip in SURFACE_SKIP):
                continue
            if rel not in seen:
                seen.add(rel)
                yield path


def corpus() -> str:
    """정본 코퍼스 텍스트. JSON은 구조를 몰라도 되므로 문자열만 훑는다."""
    chunks = []
    for path in sorted(DATA.glob("*.json")):
        chunks.append(path.read_text(encoding="utf-8"))
    for path in sorted(GDD.glob("*.md")):
        chunks.append(path.read_text(encoding="utf-8"))
    return "\n".join(chunks)


def tokens(text: str):
    seen, out = set(), []
    for raw in CODE_SPAN.findall(text):
        token = raw.strip()
        # 경로·명령은 표기가 아니라 실행 예시다
        # 실행 예시(경로·명령·플래그)는 표기가 아니다.
        if not token or token.startswith(("./", "~", "-", "npx ", "docs/")):
            continue
        if "/" in token and token.rsplit(".", 1)[-1] in {"md", "json", "py", "gd", "html"}:
            continue
        # 파일 이름도 표기가 아니다 (인라인으로 적힌 도구 이름 포함).
        if "." in token and token.rsplit(".", 1)[-1] in {"md", "json", "py", "gd", "html", "sh", "cfg", "tscn"}:
            continue
        if token not in seen:
            seen.add(token)
            out.append(token)
    return out


def report_deprecated(glossary_text: str, strict: bool) -> int:
    pairs = deprecated_pairs(glossary_text)
    if not pairs:
        print("용어집에 \"폐기 표기\" 표가 없다 — 검사할 것이 없다")
        return 0
    hits = []
    for path in surface_files():
        text = path.read_text(encoding="utf-8")
        rel = str(path.relative_to(ROOT))
        for old, now, why in pairs:
            if old not in text:      # 부분 문자열 선별 — 정규식 1회보다 싸다 (의미 불변)
                continue
            found = deprecated_re(old).findall(text)
            if found:
                hits.append((rel, old, now, len(found)))
    if not hits:
        print(f"DEPRECATED OK — 폐기 표기 {len(pairs)}종, 쓰는 표면에 잔재 없음")
        return 0

    by_file = {}
    for rel, old, now, n in hits:
        by_file.setdefault(rel, []).append((old, now, n))
    print(f"폐기 표기 잔재 — {len(by_file)}개 파일 · {sum(n for *_, n in hits)}건")
    for rel in sorted(by_file):
        rows = sorted(by_file[rel], key=lambda r: -r[2])
        print(f"  {rel}")
        for old, now, n in rows:
            print(f"    `{old}` ×{n} → {now}")
    print("\n같은 철자가 현행 용어와 겹치는 말(예: 수호 = defend 미션)은 문맥을 보고 판단한다.")
    return 1 if strict else 0


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--list", action="store_true", help="검사 대상 표기만 출력")
    parser.add_argument("--deprecated", action="store_true", help="폐기 표기 잔재만 보고")
    parser.add_argument("--strict", action="store_true", help="폐기 잔재도 실패로 본다")
    args = parser.parse_args()

    if not GLOSSARY.exists():
        print(f"용어집이 없다: {GLOSSARY}", file=sys.stderr)
        return 2

    haystack = corpus()
    if not haystack:
        print("정본 코퍼스가 비었다 (data/·docs/gdd/ 확인)", file=sys.stderr)
        return 2

    glossary_text = GLOSSARY.read_text(encoding="utf-8")
    if args.deprecated:
        return report_deprecated(glossary_text, args.strict)

    checked = tokens(glossary_text)
    if args.list:
        for token in checked:
            print(token)
        return 0

    missing = [token for token in checked if not present(token, haystack)]
    if missing:
        print(f"GLOSSARY FAIL — 정본에 없는 표기 {len(missing)}건")
        for token in missing:
            print(f"  ? {token}")
        print("데이터나 GDD에 먼저 넣거나, 표기를 고친다.")
        return 1

    print(f"GLOSSARY OK — 표기 {len(checked)}건 전부 정본에 있음")
    return 0


if __name__ == "__main__":
    sys.exit(run("glossary", main))
