#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""review_docs.py — 폰즈 문서 기계 검수기.

왜 있나:
  이 저장소는 원본 저장소 `haejoonlim/soul-commander`(비공개)의 GDD/PLAN/JSON 을
  아직 읽을 수 없는 상태에서 출발했다. 그래서 원본 숫자·결정이 2차 인용으로 들어올 위험이
  크다. 이 스크립트는 사람이 원문을 읽지 않아도 기계적으로 확인 가능한 결함만 찾는다.

무엇을 하나 (검사 7종):
  BROKEN_REFERENCE   저장소 경로처럼 보이는 참조가 실제로 없음
  BROKEN_LINK        마크다운 로컬 링크 대상이 없음
  DUPLICATE_H1       docs/ 안 두 문서의 H1 제목이 동일
  DANGLING_SSOT      SSOT 라고 주장하면서 존재하는 파일을 지목하지 않음
  NUMBER_CONFLICT    추적 상수가 문서마다 다른 값 (registry 파일 필요)
  CONST_DRIFT        같은 상수가 코드/데이터에서 다른 값으로 선언됨
  UNVERIFIED_CLAIM   원본 저장소에 대한 숫자 주장에 '원본 미검증' 표시가 없음

정밀도 우선 원칙 (오탐 방지):
  - 원본 저장소 경로(design-docs/, fons-web-ver/, unity/, Scripts/ ...)는 이 저장소에
    없는 것이 정상이므로 참조 검사에서 제외한다.
  - 아직 안 만든 것이 정상인 미래 산출물은 PLANNED_PATHS 로 명시 제외한다.
  - 코드블록(```) 안은 사람용 서술이 아니므로 참조/주장 검사에서 건너뛴다.
  - 확장자 없는 것, 와일드카드(*), 자리표시(... , < >), 절대경로(/ ~ ./ ../)는 경로로 보지 않는다.
  - 파일명 표지는 단어 경계로 판정한다 ('DEV_PLAN.md' 안의 'PLAN.md' 는 원본 표지가 아니다).
  - 번호 목록의 서수('1. ', '2) ')는 숫자 주장으로 보지 않는다.
  - 결정 번호(D-265 등)의 숫자는 값이 아니라 인용 부호이므로 주장으로 보지 않는다.
  - 면제 건수를 항상 함께 출력한다. 조용히 넘기지 않는다.

사용법:
  ./.venv/bin/python tools/review_docs.py
  ./.venv/bin/python tools/review_docs.py --list-checks
  ./.venv/bin/python tools/review_docs.py --json tools/review_report.json

종료 코드:
  0  발견 없음
  1  발견 있음
  2  사용법/설정 오류
"""
import argparse
import json
import re
import sys
from pathlib import Path

# ---------------------------------------------------------------- 상수 정의

CHECK_ORDER = [
    "BROKEN_REFERENCE",
    "BROKEN_LINK",
    "DUPLICATE_H1",
    "DANGLING_SSOT",
    "NUMBER_CONFLICT",
    "CONST_DRIFT",
    "UNVERIFIED_CLAIM",
]

CHECK_DESC = {
    "BROKEN_REFERENCE": "저장소 경로로 보이는 참조가 실제로 없음 (원본/미래 산출물 제외)",
    "BROKEN_LINK": "마크다운 로컬 링크 대상 파일이 없음",
    "DUPLICATE_H1": "docs/ 안 두 문서의 H1 제목이 동일",
    "DANGLING_SSOT": "SSOT 라고 주장하지만 존재하는 파일을 지목하지 않음",
    "NUMBER_CONFLICT": "추적 상수가 문서마다 다른 값으로 적힘 (registry 필요)",
    "CONST_DRIFT": "같은 상수가 코드/데이터에서 다른 값으로 선언됨",
    "UNVERIFIED_CLAIM": "원본 저장소에 대한 숫자 주장에 '원본 미검증' 표시가 없음",
}

# 원본 저장소에만 있는 경로 접두어. 이 저장소에 없는 것이 정상이다.
ORIGINAL_PREFIXES = (
    "design-docs/",
    "fons-web-ver/",
    "unity/",
    "loop/",
    "fons-launcher/",
    "Scripts/",
    "ProjectSettings/",
    "soul-commander/",
    "Assets/",
    "game3d/",
)

# 원본 저장소를 가리키는 문면 표지. 이게 있는 줄은 '원본 이야기'로 본다.
ORIGINAL_MARKERS = (
    "soul-commander",
    "fons-web-ver",
    "design-docs",
    "GDD_v8",
    "PLAN.md",
    "unity/Assets",
    "unity/PORTING_MAP",
    "fons-launcher",
    "loop/HANDOFF",
    ".mjs",
)

# 원본 저장소의 결정 번호(D-265 등). 숫자 주장 검사에서 '원본 참조' 신호로 쓴다.
DECISION_RE = re.compile(r"(?<![A-Za-z0-9_])D-\d+")

# 이 표시가 있는 줄(또는 바로 윗줄)의 숫자 주장은 '검증 표시됨'으로 본다.
UNVERIFIED_MARKERS = ("원본 미검증", "미검증", "미확인")

# 아직 안 만든 것이 정상인 미래 산출물. 여기 있으면 참조 검사에서 면제.
PLANNED_PATHS = (
    "docs/README.md",
    "docs/gdd",
    "docs/web-plan",
    "docs/handoff",
    "docs/handoff/HANDOFF.md",
    "docs/handoff/STATUS.md",
    "godot/data",
    "godot/scenes",
    "godot/scenes/title.tscn",
    "godot/export_presets.cfg",
    "godot/scripts/autoload/save_manager.gd",
    "godot/scripts/sim/summon.gd",
    "godot/scripts/sim/estate.gd",
    "godot/scripts/sim/party.gd",
    "godot/scripts/sim/tower.gd",
    "godot/scripts/sim/economy.gd",
    "godot/scripts/world",
    "godot/scripts/world/scene.gd",
    "godot/scripts/world/estate_3d.gd",
    "godot/scripts/world/explore_3d.gd",
    "godot/scripts/world/monparts.gd",
    "godot/scripts/world/title.gd",
    "godot/tests/test_game.gd",
    "godot/tests/test_w1.gd",
    "godot/tests/test_w2.gd",
    "godot/tests/test_w3.gd",
    "godot/tests/test_w4.gd",
    "godot/tests/test_g0.gd",
    "godot/tests/test_g1.gd",
    "godot/tests/test_g2.gd",
    "godot/tests/test_g3.gd",
    "godot/tests/test_g4.gd",
    "tools/check_unity_health.sh",
    "tools/run_editmode_tests.sh",
    "tools/edit_guard.py",
    "build",
)

# 문서가 쓰는 짧은 경로(예: `sim/combat.gd`)를 실제 위치로 풀어 볼 기준 디렉터리들.
RESOLVE_BASES = (
    "",
    "docs/",
    "godot/",
    "godot/scripts/",
    "godot/scripts/sim/",
    "godot/scripts/world/",
    "godot/scripts/autoload/",
    "godot/tests/",
    "data/",
    "sim/",
    "tools/",
)

SKIP_DIRS = {
    ".git",
    ".venv",
    ".godot",
    "addons",
    "node_modules",
    "build",
    "__pycache__",
}

PATHY_RE = re.compile(r"^[A-Za-z0-9_][A-Za-z0-9_./-]*\.[A-Za-z0-9]+$")
SCHEME_RE = re.compile(r"^[A-Za-z][A-Za-z0-9+.-]*://")
FENCE_RE = re.compile(r"^\s*(```|~~~)")
STANDALONE_NUM_RE = re.compile(r"(?<![A-Za-z0-9_])[0-9]+(?:[.,][0-9]+)?(?![A-Za-z0-9_])")
# 목록 번호('1. ', '2) ', '- 3. ')는 숫자 주장이 아니다.
# 이걸 걸러내지 않으면 원본을 언급한 모든 번호 목록 항목이 오탐이 된다.
LIST_ORDINAL_RE = re.compile(r"^\s*(?:[-*+]\s+)?[0-9]+[.)]\s+")
MD_LINK_RE = re.compile(r"\[([^\]]*)\]\(([^)]+)\)")
BACKTICK_RE = re.compile(r"`([^`]+)`")
TABLE_SEP_RE = re.compile(r"^\s*\|?[\s:|-]+\|?\s*$")

BAD_TOKENS = (
    "*",
    "..",
    "...",
    "<",
    ">",
    "?",
    "{",
    "}",
    "$",
    "|",
    '"',
    "'",
    ",",
    ";",
    "=",
    "+",
    "@",
    "!",
)


# ---------------------------------------------------------------- 도구 함수


def norm(p):
    """경로 문자열 정규화: 백슬래시 통일, ./ 제거, 중복 슬래시 축약."""
    p = p.strip().replace("\\", "/")
    while p.startswith("./"):
        p = p[2:]
    while "//" in p:
        p = p.replace("//", "/")
    if p.endswith("/") and len(p) > 1:
        p = p[:-1]
    return p


def is_planned(path):
    path = norm(path)
    for planned in PLANNED_PATHS:
        if path == planned or path.startswith(planned + "/"):
            return True
    return False


def is_path_like(tok):
    """저장소 경로로 보이는가. 오탐을 줄이려 조건을 빡빡하게 건다."""
    tok = tok.strip()
    if not tok or " " in tok or "\t" in tok or "\n" in tok:
        return False
    if SCHEME_RE.match(tok):
        return False
    if tok.startswith(("/", "~", "./", "../")):
        return False
    for bad in BAD_TOKENS:
        if bad in tok:
            return False
    if "/" not in tok:
        return False  # 맨 파일명만 있으면 어느 디렉터리인지 알 수 없다
    if not PATHY_RE.match(tok):
        return False
    return "." in tok.rsplit("/", 1)[-1]


def classify_ref(root, rel):
    """참조 하나를 원본/존재/미래/없음 으로 분류."""
    rel = norm(rel)
    if not rel:
        return "original"
    for prefix in ORIGINAL_PREFIXES:
        if rel.startswith(prefix):
            return "original"
    for base in RESOLVE_BASES:
        joined = norm(base + rel) if base else rel
        if (root / joined).exists():
            return "exists"
    for base in RESOLVE_BASES:
        joined = norm(base + rel) if base else rel
        if is_planned(joined):
            return "planned"
    if is_planned(rel):
        return "planned"
    return "missing"


# 표지가 단어 문자로 시작하면 앞에 단어 경계를 요구한다.
# 순수 in 검사로는 'DEV_PLAN.md' / 'MIGRATION_PLAN.md' 안의 'PLAN.md' 까지
# 원본 저장소 문면으로 오인해, 우리 저장소 문서를 원본 언급으로 잘못 분류한다 (오탐).
ORIGINAL_MARKER_RES = tuple(
    re.compile((r"(?<![A-Za-z0-9_])" if m[0].isalnum() else "") + re.escape(m))
    for m in ORIGINAL_MARKERS
)


def line_has_original(line):
    """이 줄이 원본 저장소를 가리키는 줄인가."""
    if any(rx.search(line) for rx in ORIGINAL_MARKER_RES):
        return True
    return bool(DECISION_RE.search(line))


def collect_docs(root, data_dir):
    """검사 대상 문서 수집 (md 전체 + data 디렉터리 안 json)."""
    out = []
    for p in sorted(root.rglob("*.md")):
        try:
            rel = p.relative_to(root)
        except ValueError:
            continue
        if any(part in SKIP_DIRS for part in rel.parts[:-1]):
            continue
        out.append(p)
    data_root = root / data_dir
    if data_root.is_dir():
        for p in sorted(data_root.glob("*.json")):
            out.append(p)
    return out


def read_lines(path):
    try:
        text = path.read_text(encoding="utf-8", errors="replace")
    except OSError:
        return []
    lines = text.splitlines()
    if len(lines) == 1 and not lines[0].strip():
        return []
    return lines


def split_fences(lines):
    """코드블록 안/밖 분리. 반환: (prose[(no, text)], fenced_line_numbers set)."""
    prose = []
    fenced = set()
    inside = False
    for no, ln in enumerate(lines, start=1):
        if FENCE_RE.match(ln):
            inside = not inside
            fenced.add(no)
            continue
        if inside:
            fenced.add(no)
        else:
            prose.append((no, ln))
    return prose, fenced


def prev_prose_line(prose, index):
    if index <= 0:
        return ""
    return prose[index - 1][1]


# ---------------------------------------------------------------- 검사들


def check_broken_reference(root, docs, stats):
    findings = []
    for path in docs:
        rel = str(path.relative_to(root))
        lines = read_lines(path)
        prose, _ = split_fences(lines)
        for i, (no, line) in enumerate(prose):
            if line_has_original(line) or line_has_original(prev_prose_line(prose, i)):
                stats["exempt"] += 1
                continue
            for tok in BACKTICK_RE.findall(line):
                if not is_path_like(tok):
                    continue
                outcome = classify_ref(root, tok)
                if outcome in ("exists", "original", "planned"):
                    stats["exempt"] += 1
                    continue
                findings.append(
                    (rel, no, "저장소 경로로 보이지만 없습니다: `%s`" % norm(tok))
                )
    return findings


def check_broken_link(root, docs, stats):
    findings = []
    for path in docs:
        rel = str(path.relative_to(root))
        if path.suffix.lower() != ".md":
            continue
        base = path.parent
        for no, line in enumerate(read_lines(path), start=1):
            for text, target in MD_LINK_RE.findall(line):
                t = target.strip()
                if not t or t.startswith("#"):
                    continue
                if SCHEME_RE.match(t) or t.startswith("mailto:"):
                    continue
                if any(bad in t for bad in ("*", "...", "<", ">")):
                    stats["exempt"] += 1
                    continue
                clean = t.split("#", 1)[0]
                if not clean:
                    continue
                candidates = [base / clean, root / norm(clean)]
                if any(c.exists() for c in candidates):
                    stats["exempt"] += 1
                    continue
                findings.append(
                    (rel, no, "링크 대상이 없습니다: [%s](%s)" % (text, target))
                )
    return findings


def check_duplicate_h1(root, docs, docs_dir, stats):
    titles = {}
    for path in docs:
        rel = str(path.relative_to(root))
        if not (rel == docs_dir or rel.startswith(docs_dir.rstrip("/") + "/")):
            continue
        for line in read_lines(path):
            if line.startswith("# "):
                title = line[2:].strip()
                if title:
                    titles.setdefault(title, []).append(rel)
                break
    findings = []
    for title in sorted(titles):
        files = titles[title]
        if len(files) > 1:
            for rel in files:
                findings.append((rel, 1, "H1 제목이 중복입니다: '%s'" % title))
    return findings


def check_dangling_ssot(root, docs, stats):
    findings = []
    for path in docs:
        rel = str(path.relative_to(root))
        lines = read_lines(path)
        prose, _ = split_fences(lines)
        for no, line in prose:
            if "SSOT" not in line and "단일 출처" not in line:
                continue
            if line.lstrip().startswith("#"):
                continue
            if TABLE_SEP_RE.match(line):
                continue
            if line_has_original(line):
                stats["exempt"] += 1
                continue
            tokens = [t for t in BACKTICK_RE.findall(line) if is_path_like(t)]
            if not tokens:
                findings.append(
                    (rel, no, "SSOT 라고 주장하지만 존재하는 파일을 지목하지 않습니다")
                )
                continue
            if any(classify_ref(root, t) in ("exists", "planned") for t in tokens):
                stats["exempt"] += 1
                continue
            findings.append(
                (rel, no, "SSOT 로 지목한 파일이 없습니다: %s"
                 % ", ".join("`%s`" % norm(t) for t in tokens))
            )
    return findings


def load_registry(root):
    p = root / "tools" / "tracked_numbers.json"
    if not p.exists():
        return None
    try:
        data = json.loads(p.read_text(encoding="utf-8"))
    except (OSError, ValueError) as exc:
        raise ValueError("tools/tracked_numbers.json 를 읽을 수 없습니다: %s" % exc)
    if not isinstance(data, dict) or not isinstance(data.get("numbers"), list):
        raise ValueError("tools/tracked_numbers.json 형식 오류: 'numbers' 배열이 필요합니다")
    return data


def check_number_conflict(root, docs, registry, stats):
    if registry is None:
        return None
    findings = []
    docs_text = {}
    for path in docs:
        docs_text[str(path.relative_to(root))] = "\n".join(read_lines(path))
    for entry in registry["numbers"]:
        name = str(entry.get("name", "")).strip()
        value = str(entry.get("value", "")).strip()
        if not name or not value:
            continue
        aliases = [name] + [str(a) for a in entry.get("aliases", []) if str(a).strip()]
        sources = set(str(s) for s in entry.get("sources", []))
        pattern = "|".join(re.escape(a) for a in sorted(aliases, key=len, reverse=True))
        if not pattern:
            continue
        value_re = re.compile(r"(?:%s)\D{0,12}?([0-9]+(?:\.[0-9]+)?)" % pattern)
        for rel, text in sorted(docs_text.items()):
            if sources and rel not in sources:
                continue
            seen = set(value_re.findall(text))
            for found in sorted(seen):
                if found != value:
                    findings.append(
                        (rel, 1, "`%s` 값이 registry(%s)와 다릅니다: %s"
                         % (name, value, found))
                    )
        stats["checked"] += 1
    return findings


PY_ASSIGN_RE = re.compile(
    r"^([A-Za-z_][A-Za-z0-9_]*)\s*(?::\s*[A-Za-z_\[][^=]*)?=\s*(-?[0-9]+(?:\.[0-9]+)?)\s*(?:#.*)?$"
)
GD_ASSIGN_RE = re.compile(
    r"^\s*(?:const|static\s+const|var)\s+([A-Za-z_][A-Za-z0-9_]*)\s*(?::=\s*|:\s*[A-Za-z_][A-Za-z0-9_\[\]]*\s*=\s*)(-?[0-9]+(?:\.[0-9]+)?)"
)


def check_const_drift(root, stats):
    decls = {}  # (tail, value) -> [locations]

    def add(name, value, loc):
        tail = name.split("_")[-1].upper()
        decls.setdefault((tail, value), set()).add(loc)

    sim_dir = root / "sim"
    if sim_dir.is_dir():
        for p in sorted(sim_dir.glob("*.py")):
            for no, line in enumerate(read_lines(p), start=1):
                m = PY_ASSIGN_RE.match(line)
                if m:
                    add(m.group(1), str(m.group(2)), "%s:%d" % (p.name, no))
    gd_files = []
    gd_root = root / "godot" / "scripts"
    if gd_root.is_dir():
        gd_files = sorted(gd_root.rglob("*.gd"))
    for p in gd_files:
        rel = str(p.relative_to(root))
        for no, line in enumerate(read_lines(p), start=1):
            m = GD_ASSIGN_RE.match(line)
            if m:
                add(m.group(1), str(m.group(2)), "%s:%d" % (rel, no))
    data_dir = root / "data"
    if data_dir.is_dir():
        for p in sorted(data_dir.glob("*.json")):
            try:
                obj = json.loads(p.read_text(encoding="utf-8"))
            except (OSError, ValueError):
                continue
            if not isinstance(obj, dict):
                continue
            for key in sorted(obj):
                val = obj[key]
                if isinstance(val, bool):
                    continue
                if isinstance(val, (int, float)):
                    add(key, str(val), "%s:%s" % (p.name, key))

    stats["checked"] += len(decls)
    tails = {}
    for (tail, value), locs in decls.items():
        tails.setdefault(tail, {})[value] = sorted(locs)
    findings = []
    for tail in sorted(tails):
        values = tails[tail]
        if len(values) < 2:
            continue
        for value in sorted(values):
            for loc in values[value]:
                findings.append(
                    (loc, 0, "이름 꼬리말 '%s' 상수가 파일마다 다른 값입니다: %s"
                     % (tail, ", ".join("%s=%s" % (v, len(values[v]))
                                        for v in sorted(values))))
                )
    return findings


def check_unverified_claim(root, docs, stats):
    findings = []
    for path in docs:
        rel = str(path.relative_to(root))
        if path.suffix.lower() not in (".md", ".json"):
            continue
        lines = read_lines(path)
        prose, _ = split_fences(lines)
        for i, (no, line) in enumerate(prose):
            if not line_has_original(line):
                continue
            # 숫자 '주장'만 본다. 다음은 주장이 아니라 참조/표기이므로 제외한다:
            #   - 목록 서수('1. ', '2) ')
            #   - 결정 번호(D-265, D-267) : 인용 부호이지 값이 아니다
            claim_text = LIST_ORDINAL_RE.sub("", line, count=1)
            claim_text = DECISION_RE.sub("D", claim_text)
            if not STANDALONE_NUM_RE.search(claim_text):
                continue
            window = line + "\n" + prev_prose_line(prose, i)
            if any(mark in window for mark in UNVERIFIED_MARKERS):
                stats["exempt"] += 1
                continue
            findings.append(
                (rel, no, "원본 저장소 숫자 주장에 '원본 미검증' 표시가 없습니다")
            )
    return findings


# ---------------------------------------------------------------- 실행


def run_checks(root, docs_dir, data_dir):
    docs = collect_docs(root, data_dir)
    stats = {"exempt": 0, "checked": 0}
    results = []

    runners = [
        ("BROKEN_REFERENCE", lambda: check_broken_reference(root, docs, stats)),
        ("BROKEN_LINK", lambda: check_broken_link(root, docs, stats)),
        ("DUPLICATE_H1", lambda: check_duplicate_h1(root, docs, docs_dir, stats)),
        ("DANGLING_SSOT", lambda: check_dangling_ssot(root, docs, stats)),
    ]
    for name, fn in runners:
        results.append({"name": name, "status": "run", "findings": fn(),
                        "skip_reason": None})

    registry = None
    try:
        registry = load_registry(root)
    except ValueError as exc:
        results.append({"name": "NUMBER_CONFLICT", "status": "skip",
                        "findings": [], "skip_reason": str(exc)})
        registry = False
    if registry is not False:
        if registry is None:
            results.append({
                "name": "NUMBER_CONFLICT", "status": "skip", "findings": [],
                "skip_reason": "registry 없음 (tools/tracked_numbers.json)",
            })
        else:
            out = check_number_conflict(root, docs, registry, stats)
            results.append({"name": "NUMBER_CONFLICT", "status": "run",
                            "findings": out or [], "skip_reason": None})

    out = check_const_drift(root, stats)
    results.append({"name": "CONST_DRIFT", "status": "run",
                    "findings": out or [], "skip_reason": None})

    out = check_unverified_claim(root, docs, stats)
    results.append({"name": "UNVERIFIED_CLAIM", "status": "run",
                    "findings": out or [], "skip_reason": None})

    results.sort(key=lambda r: CHECK_ORDER.index(r["name"]))
    for res in results:
        res["findings"].sort(key=lambda f: (str(f[0]), f[1], str(f[2])))
    return docs, stats, results


def print_report(root, docs, stats, results):
    total = sum(len(r["findings"]) for r in results)
    ran = sum(1 for r in results if r["status"] == "run")
    skipped = sum(1 for r in results if r["status"] == "skip")

    print("폰즈 문서 검수 — review_docs.py")
    print("루트: %s" % root)
    print("문서 %d개 / 검사 %d개 (실행 %d, 건너뜀 %d)"
          % (len(docs), len(results), ran, skipped))
    print("")

    for res in results:
        if res["status"] == "skip":
            print("[SKIP] %s — %s" % (res["name"], res["skip_reason"]))
            continue
        n = len(res["findings"])
        if n == 0:
            print("[ OK ] %s — 발견 없음" % res["name"])
            continue
        print("[FIND] %s — %d건" % (res["name"], n))
        for path, line, msg in res["findings"]:
            if line:
                print("        %s:%d  %s" % (path, line, msg))
            else:
                print("        %s  %s" % (path, msg))
    print("")
    print("요약: 발견 %d건 / 면제 %d건 / 상수 %d개 대조"
          % (total, stats["exempt"], stats["checked"]))
    print("검사 정의: --list-checks")
    return total


def build_json(root, docs, stats, results):
    return {
        "root": str(root),
        "summary": {
            "documents": len(docs),
            "checks": len(results),
            "checks_run": sum(1 for r in results if r["status"] == "run"),
            "checks_skipped": sum(1 for r in results if r["status"] == "skip"),
            "findings": sum(len(r["findings"]) for r in results),
            "exemptions": stats["exempt"],
            "constants_compared": stats["checked"],
        },
        "checks": [
            {
                "name": r["name"],
                "status": r["status"],
                "skip_reason": r["skip_reason"],
                "findings": [
                    {"path": p, "line": ln, "message": m}
                    for (p, ln, m) in r["findings"]
                ],
            }
            for r in results
        ],
    }


def main(argv=None):
    ap = argparse.ArgumentParser(
        prog="review_docs.py",
        description="폰즈 문서 기계 검수기 (오프라인, 표준 라이브러리만 사용)",
    )
    ap.add_argument("--root", default=None,
                    help="저장소 루트 (기본: 이 스크립트의 상위 디렉터리)")
    ap.add_argument("--docs-dir", default="docs", help="문서 디렉터리 (기본: docs)")
    ap.add_argument("--data-dir", default="data", help="데이터 디렉터리 (기본: data)")
    ap.add_argument("--json", dest="json_out", default=None,
                    help="검수 결과를 JSON 으로 저장할 경로")
    ap.add_argument("--list-checks", action="store_true",
                    help="검사 목록과 설명만 출력하고 종료")
    args = ap.parse_args(argv)

    if args.list_checks:
        for name in CHECK_ORDER:
            print("%-18s %s" % (name, CHECK_DESC[name]))
        return 0

    if args.root:
        root = Path(args.root).expanduser().resolve()
    else:
        root = Path(__file__).resolve().parent.parent
    if not root.is_dir():
        print("오류: 루트 디렉터리가 아닙니다: %s" % root)
        return 2
    if not (root / args.docs_dir).is_dir():
        print("알림: 문서 디렉터리 없음 — %s (해당 검사는 SKIP)" % (root / args.docs_dir))

    docs, stats, results = run_checks(root, args.docs_dir, args.data_dir)
    total = print_report(root, docs, stats, results)

    if args.json_out:
        out = Path(args.json_out).expanduser()
        if not out.is_absolute():
            out = root / out
        try:
            out.write_text(
                json.dumps(build_json(root, docs, stats, results),
                           ensure_ascii=False, indent=2, sort_keys=False) + "\n",
                encoding="utf-8",
            )
        except OSError as exc:
            print("오류: JSON 저장 실패: %s" % exc)
            return 2
        print("JSON 저장: %s" % out)

    return 1 if total else 0


if __name__ == "__main__":
    sys.exit(main())
