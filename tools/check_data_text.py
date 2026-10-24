"""데이터 JSON 의 문장이 깨졌는지 본다 — 값이 아니라 **글자 자체**를 검사한다.

왜 필요한가: 데이터는 생성기 여러 개가 이어 쓰는 파일이라, 한 번 글자가 깨지면
(예: `가시erte 투척`·`무덤_two더지`·` lunges`) JSON 은 멀쩡하고 게이트도 통과한 채 UI 까지 간다.
스키마 검사도, 용어 대조도 이걸 못 잡는다 — 키와 값의 '모양'은 맞기 때문이다.

규칙 넷:
  EMPTY      name 계열이 빈 값 (카드에 이름 없는 몬스터가 뜬다)
  SPACE      앞뒤 공백 (` lunges` 는 앞 공백 하나로 정렬이 틀어진다)
  MIXED      한글에 **소문자 낱말**이 붙음 — `가시erte`·`수 metre를`·`소리로Communication`
             대문자 약어(UI·HP·N·m·SPD)는 정상이라 대문자는 보지 않는다.
             2자도 본다 — `가시te` 처럼 짧게 깨지는 경우가 있어 3자 기준은 비켜 갔다
             (2자로 넓힌 뒤 data/*.json 전체 0건 = 지금 데이터에는 오탐이 없다)
  UNDERSCORE 한글에 밑줄이 붙음 — `무덤_two더지`

ALLOW 에 적은 문구는 MIXED·UNDERSCORE 에서 뺀다. 사람이 정상이라고 확인한 것만, 늘리지 않는다.

exit 1 = 깨진 값이 있음. gate_all 이 이 종료코드를 그대로 쓴다.
"""
import glob
import json
import re
import sys

from gate_contract import run

PATHS = ("data/*.json",)

ALLOW = ("assassin", "D-267_", "마석본위제_화폐_은행", "r-전략종", "자유도원칙_Unity구현사양",
         "저층_사육_마물_근거", "로스터_보강_화산_사막_심연")  # 근거 문서 파일명 인용
# (docs/design/저층_사육_마물_근거.md · docs/design/로스터_보강_화산_사막_심연.md)

# 비면 UI 가 빈다고 판단한 키만.
REQUIRED_KEYS = ("name", "name_ko", "epithet", "desc", "telegraph")
# 값이 문장인 키 — 깨짐 규칙은 여기 전부 본다.
TEXT_KEYS = REQUIRED_KEYS + ("description", "effect", "counter", "note", "title")

LATIN_AFTER = re.compile(r"[가-힣]([A-Za-z]{2,})")
LATIN_BEFORE = re.compile(r"([A-Za-z]{2,})[가-힣]")
UNDERSCORE = re.compile(r"[가-힣]_|_[가-힣]")


def mixed_word(s):
    """한글에 붙은 라틴 낱말 — 소문자를 포함한 2자 이상만. 대문자 약어(SPD·UI)는 정상."""
    for rx in (LATIN_AFTER, LATIN_BEFORE):
        for m in rx.finditer(s):
            word = m.group(1)
            if any(c.islower() for c in word):
                return m
    return None


def check_text(s, key, where, out):
    if key in REQUIRED_KEYS and not s.strip():
        out.append(("EMPTY", where, "빈 값"))
        return
    if s != s.strip():
        out.append(("SPACE", where, repr(s)))
    bare = s
    for ok in ALLOW:
        bare = bare.replace(ok, "")
    m = mixed_word(bare)
    if m:
        out.append(("MIXED", where, f"…{bare[max(0, m.start() - 10):m.end() + 10]}…"))
    m = UNDERSCORE.search(bare)
    if m:
        out.append(("UNDERSCORE", where, f"…{bare[max(0, m.start() - 10):m.end() + 10]}…"))


def walk(node, path, out):
    if isinstance(node, dict):
        for key, val in node.items():
            if isinstance(val, str) and key in TEXT_KEYS:
                check_text(val, key, f"{path}/{key}", out)
            else:
                walk(val, f"{path}/{key}", out)
    elif isinstance(node, list):
        for i, val in enumerate(node):
            walk(val, f"{path}[{i}]", out)


def main() -> int:
    found = []
    files = 0
    for pattern in PATHS:
        for path in sorted(glob.glob(pattern)):
            try:
                data = json.load(open(path, encoding="utf-8"))
            except json.JSONDecodeError as e:
                print(f"PARSE FAIL {path}: {e}")
                return 1
            except (OSError, UnicodeDecodeError) as e:
                print(f"READ FAIL {path}: {e}")
                return 1
            files += 1
            walk(data, path, found)

    if files == 0:
        # glob 이 아무것도 못 찾은 상태의 통과는 거짓 통과다 (data/ 가 사라져도 초록불이었다).
        print(f"FAIL — 검사할 데이터가 없다: {', '.join(PATHS)}")
        return 1

    if not found:
        print(f"DATA TEXT OK: {files} files — 깨진 문장 없음")
        return 0

    by_kind = {}
    for kind, where, snippet in found:
        by_kind.setdefault(kind, []).append((where, snippet))
    for kind in ("EMPTY", "SPACE", "MIXED", "UNDERSCORE"):
        rows = by_kind.get(kind)
        if not rows:
            continue
        print(f"[ FAIL ] {kind} — {len(rows)}건")
        for where, snippet in rows:
            print(f"  {where}  {snippet}")
    print(f"\n{len(found)}건 — 값을 고치거나, 정상 표기면 ALLOW 에 근거와 함께 추가한다")
    return 1


if __name__ == "__main__":
    sys.exit(run("text", main))
