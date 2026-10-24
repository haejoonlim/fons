#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""check_cjk.py — 한국어 문자열에 입력기(IME)로 섞여 들어간 한자를 막는다.

왜 있나 (원본 이식, 원본 check_cjk_injection.py):
  원본 저장소에서 '唤喚'·'判处'·'群体'·'직업技能' 이 **화면에 나오는 정본 문자열**에
  들어 있었다. 컴파일도 되고 게이트도 통과했다. 폰즈에서 같은 병을 먼저 찾았다
  (2026-10-24, 이 검사를 넣기 전 실측):

    data/basic_attacks.json:1252   "전장에铺는"            ← 铺
    godot/core/run_state.gd:20     "원본이、职业 id 로"     ← 、 职业
    sim/center/pages/promotion_lab.html:77  "S2~S5 에서接线된다"  ← 接线

  셋 다 사람이 읽으면 뜻이 통해 넘어간 자리다. 그래서 기계가 본다.

무엇을 허용하나:
  한자를 **전부** 금지하지 않는다. 도감·가챠가 이름의 일부로 쓰는 병기
  (`열조류(熱藻類)`·`개가(凱歌)`)는 판본이다. ALLOW_TERMS 에 적힌 것만 통과한다.
  새 병기를 쓰려면 여기 한 줄을 추가한다 — 그 줄이 리뷰에 남는다.

  판정 순서:
    1) 줄에 `cjk-ok` 가 있으면 건너뛴다 (이 검사기를 설명하는 문장용)
    2) `한글(漢字)` · `漢字(한글)` 괄호 병기를 지운다
    3) 남은 한자·CJK 문장부호(、。)가 ALLOW_CHARS 밖이면 실패

무엇을 안 보나 (의도):
  · docs/ — GDD 8권·docs/original 은 원본 문면이라 고칠 수 없고(docs/README.md 규칙 2),
    docs/dev 는 이력 서술에 한자를 인용한다. 여기서 실패로 만들면 사람이 원본을 손대게 된다.
  · sim/center/sims/ — 설계 기록 생성기. 창술 용어(刺·抛·攔)·使役 같은 설계 어휘를
    주석에 그대로 쓴다. 생성물(페이지)은 스캔 대상이므로 유입은 결국 페이지에서 잡힌다.
  · .claude/ · node_modules/ · .venv/ · .godot/ — 외부·생성물.

  제외 구간은 **몇 파일인지 세어 보고한다**. 조용히 스킵된 구간이 쌓이면 아무도 확인하지 않는다.

스캔 범위가 비면 통과가 아니다:
  파일 수가 MIN_FILES 미만이면 실패다. 폴더를 옮기거나 경로가 틀리면 "유입 0건" 이
  조용히 참이 되기 때문이다(원본이 같은 이유로 하한을 뒀다).

사용:
  ./.venv/bin/python tools/check_cjk.py
  ./.venv/bin/python tools/check_cjk.py --selftest   # 판정을 심은 텍스트로 되짚는다
  ./.venv/bin/python tools/check_cjk.py --list       # 허용 병기 목록
종료: 유입 발견 1 · 깨끗 0 · 사용 오류 2
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

HAN = re.compile("[\u3400-\u4dbf\u4e00-\u9fff\uf900-\ufaff]")
# 위 범위는 반드시 \u 로 쓴다 — 문자를 소스에 직접 두면 편집기·폰트에 따라 경계가 밀린다.
CJK_PUNCT = re.compile("[\u3001\u3002]")   # 、(모점) · 。(고리점)

# ── 판본 병기 (여기 없는 한자는 유입으로 본다) ─────────────────────────────
ALLOW_TERMS = (
    ("열조류(熱藻類)", "도감 — 화산 텍스처 학명 병기"),
    ("조류(潮流)", "도감 연해 — 자원 설명"),
    ("먹광(墨光)", "도감 서고 — 인공 자원"),
    ("등재(登記)", "도감 — 등재 표기"),
    ("무(空)", "정령 이름 — 무(空) 정령"),
    ("대사(大使)", "가챠 칭호 — 이슬의 대사"),
    ("대곡(大谷)", "가챠 칭호 — 대곡의 굴착자"),
    ("신석(神石)", "가챠 칭호 — 신석의 감정사"),
    ("맥석(脈石)", "가챠 칭호 — 맥석의 읽는 자"),
    ("개가(凱歌)", "가챠 칭호 — 전장의 개가"),
    ("지도(地圖)", "가챠 칭호 — 상처의 지도"),
    ("대기(待機)", "가챠 칭호 — 말없는 대기"),
    ("시(詩)", "가챠 칭호 — 시의 신관"),
    ("마부(馬夫)", "가챠 칭호 — 번개 마부"),
    ("전승(戰勝)", "가챠 칭호 — 전승의 화신"),
)
ALLOW_CHARS = frozenset("".join(t for t, _ in ALLOW_TERMS))

# 괄호 병기 — 지운 뒤 남은 한자만 본다.
PAIR_KO_HAN = re.compile("[\uac00-\ud7a3]{0,6}\\([" + HAN.pattern[1:-1] + "]+\\)")
PAIR_HAN_KO = re.compile("[" + HAN.pattern[1:-1] + "]+\\([\uac00-\ud7a3]{1,8}\\)")

SCOPE = (
    ("data", (".json",)),
    ("godot", (".gd",)),
    ("tools", (".py", ".sh")),
    ("sim", (".py", ".html")),
)
# 제외 구간 — 검사하지 않되 몇 파일인지 보고한다.
SKIP_DIRS = {
    "docs": "원본 문면·이력 (고칠 수 없다)",
    "sim/center/sims": "설계 기록 생성기 (창술·설계 한자 어휘)",
    ".claude": "외부 스킬",
}
PRUNE = {".git", ".venv", ".godot", "node_modules", "__pycache__", "build", ".pytest_cache"}

MAX_LINE = 96
# 2026-10-24 실측 118개. 하한을 90 으로 둔다.
MIN_FILES = 90


def _walk(root, exts, skip=()):
    base = os.path.join(ROOT, root)
    if not os.path.isdir(base):
        return
    for dirpath, dirnames, filenames in os.walk(base):
        dirnames[:] = [d for d in dirnames
                       if d not in PRUNE
                       and os.path.relpath(os.path.join(dirpath, d), ROOT) not in skip]
        for fn in filenames:
            if fn.endswith(exts):
                yield os.path.join(dirpath, fn)


def _rel(path):
    return os.path.relpath(path, ROOT).replace(os.sep, "/")


def iter_scope():
    for root, exts in SCOPE:
        for path in _walk(root, exts, skip=set(SKIP_DIRS)):
            yield path


def count_skipped():
    n = 0
    for root, _why in SKIP_DIRS.items():
        n += sum(1 for _ in _walk(root, (".py", ".sh", ".gd", ".html", ".json", ".md")))
    return n


def judge_line(line):
    """줄 하나의 유입 — (char, 이유) 또는 None. 본검사와 자가진단이 같은 함수를 쓴다."""
    if "cjk-ok" in line:
        return None
    rest = PAIR_HAN_KO.sub("", PAIR_KO_HAN.sub("", line))
    for m in HAN.finditer(rest):
        if m.group() not in ALLOW_CHARS:
            return m.group(), "한자"
    m = CJK_PUNCT.search(rest)
    if m:
        return m.group(), "CJK 문장부호"
    return None


def scan(paths=None):
    """(검사 수, 오류 목록, 문자 집계)."""
    files = 0
    errors = []
    seen = {}
    for path in (iter_scope() if paths is None else paths):
        files += 1
        rel = _rel(path)
        if os.path.abspath(path) == os.path.abspath(__file__):
            continue          # 이 파일은 규칙표에 한자 예시를 담아야 한다
        try:
            with open(path, encoding="utf-8", errors="replace") as fh:
                lines = fh.readlines()
        except OSError as exc:
            errors.append("  %s  읽기 실패: %s" % (rel, exc))
            continue
        for i, line in enumerate(lines, 1):
            hit = judge_line(line)
            if not hit:
                continue
            ch, why = hit
            seen[ch] = seen.get(ch, 0) + 1
            ctx = line.strip()
            if len(ctx) > MAX_LINE:
                ctx = ctx[:MAX_LINE] + "…"
            errors.append("  %s:%d  [%s] %s  %s" % (rel, i, ch, why, ctx))
    return files, errors, seen


def _selftest():
    """심은 텍스트로 판정을 되짚는다 — 본검사와 같은 judge_line 을 쓴다."""
    fails = []
    cases = [
        ('{"note": "群体 침"}', True, "심은 유입(群体)"),
        ('{"note": "전장에铺는"}', True, "심은 유입(铺)"),
        ("## 값은 원본이、职业 id 로", True, "심은 유입(、职业)"),
        ('{"name": "열조류(熱藻類)"}', False, "판본 병기"),
        ("먹광(墨光) · 무(空) 정령", False, "판본 병기 둘"),
        ("중국 창술 刺(찌르기)·抛", True, "허용 목록 밖 한자"),
        ("# 群体 cjk-ok", False, "탈출 표기"),
        ("평범한 한국어 문장 — 게이트 확인", False, "정상 문장"),
    ]
    for text, want_bad, desc in cases:
        got = judge_line(text) is not None
        if got != want_bad:
            fails.append("%s — %s" % (desc, "잡았다" if got else "놓쳤다"))

    with tempfile.TemporaryDirectory() as td:
        bad = os.path.join(td, "bad.json")
        with open(bad, "w", encoding="utf-8") as fh:
            fh.write('{"note": "群体 침"}\n')
        files, errors, seen = scan([bad])
        if files != 1 or not errors:
            fails.append("scan() 이 심은 파일을 못 잡았다 (files=%d)" % files)
        if "群" not in seen:
            fails.append("문자 집계(群)가 비었다 — 어느 글자가 유입인지 못 되짚는다")

    if MIN_FILES <= 0:
        fails.append("스캔 하한이 없다 — 파일 0개를 통과로 본다")

    for f in fails:
        print("[cjk] 자가진단 실패 — " + f)
    return 1 if fails else 0


def main():
    ap = argparse.ArgumentParser(add_help=True)
    ap.add_argument("--selftest", action="store_true")
    ap.add_argument("--list", action="store_true")
    args = ap.parse_args()

    if args.list:
        for term, why in ALLOW_TERMS:
            print("  %s  — %s" % (term, why))
        return 0
    if args.selftest:
        return _selftest()

    files, errors, seen = scan()
    skipped = count_skipped()
    if files < MIN_FILES:
        print("[cjk] FAIL — 스캔 %d개 < 하한 %d개. 범위가 깨졌다(폴더 개명·경로 오타). "
              "'유입 0건' 은 참이 아니다." % (files, MIN_FILES))
        return 1
    if errors:
        print("[cjk] 한자 유입 %d건 — 허용 병기 %d종 외는 금지" % (len(errors), len(ALLOW_TERMS)))
        for e in errors[:60]:
            print(e)
        if len(errors) > 60:
            print("  … 외 %d건" % (len(errors) - 60))
        print("  고치는 법: 유입이면 지운다. 판본 병기면 ALLOW_TERMS 에 한 줄 추가. "
              "인용이 불가피하면 그 줄에 cjk-ok.")
        return 1
    print("[cjk] OK — 한자 유입 0건 (검사 %d개 · 제외 %d개 · 허용 병기 %d종)"
          % (files, skipped, len(ALLOW_TERMS)))
    return 0


if __name__ == "__main__":
    sys.exit(run("cjk", main))
