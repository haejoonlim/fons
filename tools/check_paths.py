#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""check_paths.py — 코드에 박힌 절대경로와 옛 저장소 이름을 막는다.

왜 있나 (원본 이식, 원본 check_no_hardcoded_path.py):
  원본에서 폴더를 개명했더니 두 종류가 터졌다.
   ① 하드코딩 절대경로 — 스크립트 4종이 FileNotFoundError 로 죽었다. 죽어서 보이는 쪽.
   ② 옛 이름 잔재 — 네임스페이스 상수가 옛 이름이라 사내 타입을 전부 외부로 오분류했다.
      조용히 틀린 답을 내는 쪽이라 더 위험하다.
  폰즈도 `soul-commander` → `폰즈` 개명을 거쳤고, 원본 클론은 2026-10-24 에 지웠다.
  지워진 경로를 코드가 아직 가리키면 이 머신에서만 도는 코드가 된다.

무엇을 잡나 (게이트를 막는다):
  · 코드 안의 /Users/<이름>/… · /home/<이름>/… · C:\\Users\\… 절대경로
  · 코드 안의 옛 이름 (soul-commander · SoulCommander · 소울커맨더)

무엇을 안 잡나 (오탐 방어):
  · 주석·문서 문자열 — 이력 서술은 사실이다. 그래서 코드는 주석을 지운 뒤 본다.
  · `__file__` · `BASH_SOURCE` 로 계산한 경로 — 이게 정답이다.
  · `~` · `$HOME` 으로 시작하는 기본값 — 배포 위치가 달라도 풀린다.
  · ALLOW_FILES / 줄 끝 `path-ok` — 이유를 남긴 예외만.

무엇을 안 보나:
  · docs/ — 마이그레이션 기록이 옛 경로를 인용한다(지워진 클론을 그렇게 부른 게 사실).
  · .claude/ — 외부 스킬. 고치지 않는 남의 문서다.

사용:
  ./.venv/bin/python tools/check_paths.py
  ./.venv/bin/python tools/check_paths.py --selftest   # 판정을 심은 텍스트로 되짚는다
종료: 위반 1 · 깨끗 0 · 사용 오류 2
"""
import argparse
import os
import re
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, HERE)
from gate_contract import run  # noqa: E402

SCOPE = (("tools", (".py", ".sh")),
         ("sim", (".py", ".html", ".js")),
         ("godot", (".gd",)))
PRUNE = {".git", ".venv", ".godot", "node_modules", "__pycache__", "build", ".pytest_cache"}
SKIP_DIRS = {".claude": "외부 스킬 — 고치지 않는 문서"}

ABS_PATH = re.compile(r"(/Users/[A-Za-z0-9._-]+/[^\s\"'`)\]}]*"
                     r"|/home/[A-Za-z0-9._-]+/[^\s\"'`)\]}]*"
                     r"|[A-Za-z]:\\?Users\\?[^\s\"'`)\]}]+)")
OLD_NAMES = ("soul-commander", "SoulCommander", "소울커맨더")
# 개명을 **설명하는** 문맥은 잔재가 아니다. (주석은 이미 지워지므로 문자열에만 남는다)
RENAME_NOTE = re.compile(r"(soul-commander|SoulCommander|소울커맨더)\s*(→|->|⇒)\s*(폰즈|fons|Fons|FONS)"
                         r"|(개명|리네임|폴더 변경|rename)")

# 이 파일은 정의상 옛 이름이 **대상**이다. 사유를 적고 통과시킨다.
ALLOW_FILES = {
    "tools/archive_clone.py": "아카이브에서 파일을 꺼내는 도구 — 아카이브 이름이 대상",
}

MAX_LINE = 96
# 2026-10-24 실측 71개. 하한을 50 으로 둔다.
MIN_FILES = 50


def _walk(root, exts):
    base = os.path.join(ROOT, root)
    if not os.path.isdir(base):
        return
    for dirpath, dirnames, filenames in os.walk(base):
        dirnames[:] = [d for d in dirnames
                       if d not in PRUNE
                       and os.path.relpath(os.path.join(dirpath, d), ROOT) not in SKIP_DIRS]
        for fn in filenames:
            if fn.endswith(exts):
                yield os.path.join(dirpath, fn)


def _rel(path):
    return os.path.relpath(path, ROOT).replace(os.sep, "/")


def iter_scope():
    for root, exts in SCOPE:
        for path in _walk(root, exts):
            yield path


def count_skipped():
    """제외 구간의 파일 수 — 조용히 스킵된 구간이 쌓이면 아무도 확인하지 않는다."""
    n = 0
    for root in SKIP_DIRS:
        for _dirpath, dirnames, filenames in os.walk(os.path.join(ROOT, root)):
            dirnames[:] = [d for d in dirnames if d not in PRUNE]
            n += len(filenames)
    return n


def strip_comments(text, ext):
    """주석을 지운다 — 주석에 남은 옛 이름·경로는 이력이지 잔재가 아니다.

    문자열 리터럴은 남긴다. 문자열로 옛 경로를 조립하면 그건 실제 동작이다.
    """
    if ext == ".html":
        return re.sub(r"<!--(?:.|\n)*?-->", lambda m: "\n" * m.group().count("\n"), text)
    if ext == ".py":
        # 독스트링도 이력 서술이다("원본 저장소는 …"). 줄 번호가 밀리지 않게 개행은 남긴다.
        text = re.sub(r'"""(?:.|\n)*?"""', lambda m: "\n" * m.group().count("\n"), text)
        text = re.sub(r"'''(?:.|\n)*?'''", lambda m: "\n" * m.group().count("\n"), text)
    if ext == ".gd":
        out = []
        for line in text.splitlines(keepends=True):
            i = line.find("#")
            out.append(line if i < 0 else line[:i] + "\n")
        return "".join(out)
    # .py / .sh / .js — 따옴표 균형으로 # 이 주석인지 가른다.
    out = []
    for line in text.splitlines(keepends=True):
        in_s = in_d = False
        cut = None
        for i, ch in enumerate(line):
            if ch == "'" and not in_d:
                in_s = not in_s
            elif ch == '"' and not in_s:
                in_d = not in_d
            elif ch == "#" and not in_s and not in_d:
                cut = i
                break
        out.append(line if cut is None else line[:cut] + "\n")
    return "".join(out)


def judge_line(line, is_code=True, raw=None):
    """줄 하나의 위반 — (종류, 값) 또는 None. 본검사와 자가진단이 같은 함수를 쓴다.

    `path-ok` 는 주석에 붙이는 표시라 주석을 지우기 전(raw) 줄에서 본다.
    """
    if "path-ok" in (raw if raw is not None else line):
        return None
    for m in ABS_PATH.finditer(line):
        return "절대경로", m.group().rstrip("/")
    for old in OLD_NAMES:
        if old not in line or not is_code:
            continue
        if RENAME_NOTE.search(line):
            continue
        return "옛 이름", old
    return None


def scan(paths=None):
    files = 0
    errors = []
    for path in (iter_scope() if paths is None else paths):
        rel = _rel(path)
        if rel in ALLOW_FILES or os.path.abspath(path) == os.path.abspath(__file__):
            continue
        files += 1
        ext = os.path.splitext(path)[1]
        try:
            with open(path, encoding="utf-8", errors="replace") as fh:
                raw = fh.read()
        except OSError as exc:
            errors.append("  %s  읽기 실패: %s" % (rel, exc))
            continue
        raw_lines = raw.splitlines()
        for i, (src, line) in enumerate(zip(raw_lines, strip_comments(raw, ext).splitlines()), 1):
            hit = judge_line(line, raw=src)
            if not hit:
                continue
            kind, value = hit
            ctx = line.strip()
            if len(ctx) > MAX_LINE:
                ctx = ctx[:MAX_LINE] + "…"
            why = ("하드코딩 — __file__·BASH_SOURCE 로 계산한다" if kind == "절대경로"
                   else "옛 이름이 코드에 남아 있다 — 폰즈 기준으로 고친다")
            errors.append("  %s:%d  [%s] %s  %s\n      → %s" % (rel, i, kind, value, ctx, why))
    return files, errors


def _selftest():
    """본검사와 같은 scan()·judge_line 을 돌린다 — 하네스만 통과하는 상태를 막는다."""
    fails = []
    cases = [
        ('SRC=/Users/haejoon/work/x.sh', ".sh", True, "하드코딩 절대경로"),
        ('SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/x.sh"', ".sh", False, "BASH_SOURCE 계산"),
        ('_here = os.path.dirname(os.path.abspath(__file__))', ".py", False, "__file__ 계산"),
        ('DATA = Path.home() / "work"', ".py", False, "~ 기본값"),
        ('# /Users/haejoon/work 폴더', ".py", False, "주석 속 경로"),
        ('INTERNAL_NS = "SoulCommander"', ".py", True, "코드의 옛 이름"),
        ('# 폴더 개명(2026-09-27 soul-commander → 폰즈)', ".py", False, "리네임 설명 주석"),
        ('NOTE = "soul-commander → 폰즈 로 옮겼다"', ".py", False, "리네임 설명 문자열"),
        ('TAR = Path.home() / "soul-commander-archive"', ".py", True, "옛 이름 경로"),
        ('TAR = "x"  # path-ok 아카이브 대상', ".py", False, "path-ok 예외"),
    ]
    with tempfile.TemporaryDirectory() as td:
        paths = []
        for i, (content, ext, _bad, _desc) in enumerate(cases):
            p = os.path.join(td, "t%d%s" % (i, ext))
            with open(p, "w", encoding="utf-8") as fh:
                fh.write(content + "\n")
            paths.append((p, ext))
        files, errors = scan([p for p, _ in paths])
        if files != len(cases):
            fails.append("scan() 이 %d개를 봐야 하는데 %d개만 봤다" % (len(cases), files))
        for (content, _ext, want_bad, desc), (p, _e) in zip(cases, paths):
            hit = any(os.path.basename(p) + ":" in e for e in errors)
            if want_bad and not hit:
                fails.append("막아야 하는데 통과 — %s" % desc)
            if not want_bad and hit:
                fails.append("통과시켜야 하는데 잡음 — %s" % desc)

    if MIN_FILES <= 0:
        fails.append("스캔 하한이 없다 — 파일 0개를 통과로 본다")

    for f in fails:
        print("[paths] 자가진단 실패 — " + f)
    return 1 if fails else 0


def main():
    ap = argparse.ArgumentParser(add_help=True)
    ap.add_argument("--selftest", action="store_true")
    args = ap.parse_args()
    if args.selftest:
        return _selftest()

    files, errors = scan()
    skipped = count_skipped()
    if files < MIN_FILES:
        print("[paths] FAIL — 스캔 %d개 < 하한 %d개. 범위가 깨졌다(폴더 개명·경로 오타). "
              "'위반 0건' 은 참이 아니다." % (files, MIN_FILES))
        return 1
    if errors:
        print("[paths] 위반 %d건" % len(errors))
        for e in errors[:40]:
            print(e)
        if len(errors) > 40:
            print("  … 외 %d건" % (len(errors) - 40))
        return 1
    print("[paths] OK — 절대경로 0건 · 옛 이름 0건 (검사 %d개 · 제외 %d개 · 예외 파일 %d개)"
          % (files, skipped, len(ALLOW_FILES)))
    return 0


if __name__ == "__main__":
    sys.exit(run("paths", main))
