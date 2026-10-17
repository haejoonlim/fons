"""문서별 번역투 밀도를 세어 점수표로 보여준다 — 고치지 않고 **재는** 도구.

왜 있나:
  humanizer 교정은 문장을 읽는 일이라 파일이 11개만 넘어도 어디부터 손댈지 모른다.
  그래서 패턴별로 세고, 길이로 나눠 밀도를 낸다. 순위가 곧 작업 순서다.

무엇을 세나 (전부 "문장이 아니라 글자"로 잡히는 것만):
  TRANSLATE  번역투 — `~에 대한` `~를 통해` `~되어진다` `~에 의해` `~로 인해`
  NOMINAL    명사화 — `~것이다` `~는 것이다` `이는` 로 받는 문장
  ADJECTIVE  `~적` 형용사 남용 (`구조적 적자` 같은 기술 용어는 사람이 빼야 한다)
  PASSIVE    피동 `~되다` `~지다`
  ARROW      화살표 압축 `→` — 표 안은 문체 계약, 산문은 후보
  NEST       괄호 중첩 (한 줄에 괄호 2쌍 이상)

밀도 = 건수 ÷ 1,000자. 점수가 높을수록 손댈 곳이 많다.
점수는 **절대 평가가 아니다** — 같은 패턴을 많이 쓰는 문서가 위로 올 뿐이다.

사용법:
  ./.venv/bin/python tools/humanizer_scan.py                 # docs/ 전체
  ./.venv/bin/python tools/humanizer_scan.py docs/l10n       # 폴더 지정

exit 0 = 표만 출력한다 (검사 실패 개념이 없다). 게이트에 넣지 않는다.
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DEFAULT_ROOT = ROOT / "docs"

PATTERNS = {
    "TRANSLATE": re.compile(r"에 대한|를 통해|을 통해|되어진|되어지는|에 의해|로 인해|에 관해|에 대해"),
    "NOMINAL": re.compile(r"(?:것이다|것입니다|이는\s|이것은\s)"),
    "ADJECTIVE": re.compile(r"[가-힣]+적\s"),
    "PASSIVE": re.compile(r"되었|되어|어진|지어진|만들어진"),
    "ARROW": re.compile(r"→"),
}
NEST = re.compile(r"\([^)\n]*\(|（[^）\n]*（")

# 원본 문면은 재지 않는다 (고치지 않는 글).
# 번역투_교정_예시.md 도 뺀다 — 나쁜 문장을 일부러 붙여 둔 카탈로그라 늘 1위가 된다.
SKIP = (".git", "original")
SKIP_FILES = ("번역투_교정_예시.md", "UI_문구_규칙.md")


def score(text: str):
    body = "\n".join(line for line in text.splitlines() if not line.lstrip().startswith("#"))
    counts = {name: len(rx.findall(body)) for name, rx in PATTERNS.items()}
    nest_lines = sum(1 for line in body.splitlines() if NEST.search(line))
    counts["NEST"] = nest_lines
    chars = len(re.sub(r"\s", "", body)) or 1
    total = sum(counts.values())
    return counts, chars, total, total / chars * 1000


def main() -> int:
    base = Path(sys.argv[1]) if len(sys.argv) > 1 else DEFAULT_ROOT
    if not base.is_absolute():
        base = ROOT / base
    if not base.exists():
        print(f"없는 경로: {base}", file=sys.stderr)
        return 2

    rows = []
    # 화면 문면도 같은 규칙으로 센다. HTML 은 태그·스크립트가 섮여 밀도가 낮게 나온다 — 순위용이다.
    files = sorted(list(base.rglob("*.md")) + list(base.rglob("*.html")))
    for path in files:
        rel = str(path.relative_to(ROOT))
        if any(part in rel.split("/") for part in SKIP):
            continue
        if path.name in SKIP_FILES:
            continue
        counts, chars, total, density = score(path.read_text(encoding="utf-8"))
        rows.append((density, rel, chars, total, counts))

    if not rows:
        print("잴 문서가 없다")
        return 0

    rows.sort(reverse=True)
    head = f"{'밀도':>6} {'건수':>4} {'글자':>6}  파일"
    print(head)
    print("-" * len(head))
    for density, rel, chars, total, counts in rows:
        print(f"{density:6.2f} {total:4d} {chars:6d}  {rel}")
    print()
    names = ["TRANSLATE", "NOMINAL", "ADJECTIVE", "PASSIVE", "ARROW", "NEST"]
    print("패턴별 (상위 5개 파일)")
    for name in names:
        top = sorted(rows, key=lambda r: -r[4][name])[:5]
        picked = [f"{rel.split('/')[-1]} {c[name]}" for _, rel, _, _, c in top if c[name]]
        print(f"  {name:<9} {' · '.join(picked) if picked else '—'}")
    print("\n밀도는 상대 지표다. 0순위부터 읽고, 표 안 화살표와 기술 용어는 빼고 본다.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
