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
  UNVERIFIED_CLAIM   원본 저장소에 대한 숫자 주장에 출처 표시('원본 미검증'·'원본 대조'·'자체 실측')가 없음

정밀도 우선 원칙 (오탐 방지):
  - 원본 저장소 경로(design-docs/, fons-web-ver/, unity/, Scripts/ ...)는 이 저장소에
    없는 것이 정상이므로 참조 검사에서 제외한다.
  - 아직 안 만든 것이 정상인 미래 산출물은 PLANNED_PATHS 로 명시 제외한다.
  - 코드블록(```) 안은 사람용 서술이 아니므로 참조/주장 검사에서 건너뛴다.
  - 확장자 없는 것, 와일드카드(*), 자리표시(... , < >), 절대경로(/ ~ ./ ../)는 경로로 보지 않는다.
  - 파일명 표지는 단어 경계로 판정한다 ('DEV_PLAN.md' 안의 'PLAN.md' 는 원본 표지가 아니다).
  - 번호 목록의 서수('1. ', '2) ')는 숫자 주장으로 보지 않는다.
  - 결정 번호(D-265 등)와 문서 절 참조(§9)의 숫자는 값이 아니라 인용 부호이므로 주장으로 보지 않는다.
  - 숫자 주장에 붙는 표시는 두 가지다: '원본 미검증'(아직 대조 못 한 2차 인용) 또는
    '원본 대조'(원본을 읽고 확인한 값). 어느 쪽이든 표시가 없으면 여전히 발견이다.
  - 표(|로 시작하는 줄)는 바로 윗 행의 표시를 물려받지 않는다. 표는 행 하나가 사실
    하나이므로, 윗 행의 표시가 다음 행까지 덮으면 표시 없는 주장이 면제로 새어 나간다.
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
    "CONST_DRIFT": "같은 이름의 상수가 코드/데이터에서 다른 값으로 선언됨",
    "UNVERIFIED_CLAIM": "원본 저장소에 대한 숫자 주장에 출처 표시('원본 미검증'·'원본 대조'·'자체 실측')가 없음",
}

# 원본 저장소에만 있는 경로 접두어. 이 저장소에 없는 것이 정상이다.
ORIGINAL_PREFIXES = (
    "design-docs/",
    "fons-web-ver/",
    "app/src/",
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

# 문서 절 참조(§9) — 결정 번호와 같은 이유로 값이 아니라 인용 부호다.
# 이걸 빼지 않으면 '§9의 절차를 밟는다' 같은 문장이 숫자 주장으로 오탐된다.
SECTION_RE = re.compile(r"§\s*\d+")

# 숫자 주장에 붙는 출처 표시 세 종류 — 숫자의 ' 어디서 왔나'를 적게 한다.
#   미검증 계열 — 아직 원본과 대조하지 않은 2차 인용
#   대조 계열   — 원본을 실제로 읽고 확인한 값 (2026-10-17 원본 클론 이후 추가)
#   실측 계열   — 원본이 아니라 이 머신에서 직접 측정한 값
# 표시가 여러 개인 것은 출처를 구분해 적기 위함이지, 면제를 늘리기 위함이 아니다 —
# 표시가 아예 없으면 세 경우 모두 발견이고, 잘못된 표시를 다는 것은 거짓 기록이다.
UNVERIFIED_MARKERS = ("원본 미검증", "미검증", "미확인")
VERIFIED_MARKERS = ("원본 대조", "대조 완료")
MEASURED_MARKERS = ("자체 실측",)
CLAIM_MARKERS = UNVERIFIED_MARKERS + VERIFIED_MARKERS + MEASURED_MARKERS

# 반박 표기 — 원본에 없다고 밝히며 그 값을 인용하는 줄은 드리프트가 아니다.
# (원본 저장소도 같은 취지의 '문맥 인식 면제 — 철회·폐기·역사' 규칙을 쓴다.)
REFUTATION_MARKERS = ("원본에 없음", "폐기", "철회", "구값", "삭제", "틀림")

# 아직 안 만든 것이 정상인 미래 산출물. 여기 있으면 참조 검사에서 면제.
PLANNED_PATHS = (
    "docs/README.md",
    "docs/gdd",
    "docs/adr",
    "docs/art",
    "docs/audio",
    "godot/data",
    "godot/assets",
    "art-source",
    "audio-source",
    "godot/game/ui/title/title.tscn",
    "godot/export_presets.cfg",
    "godot/autoload/save_manager.gd",
    "godot/core/summon.gd",
    "godot/core/estate.gd",
    "godot/core/party.gd",
    "godot/core/tower.gd",
    "godot/core/economy.gd",
    "godot/game/world",
    "godot/game/world/scene.gd",
    "godot/game/world/estate_3d.gd",
    "godot/game/world/explore_3d.gd",
    "godot/game/world/monparts.gd",
    "godot/game/world/title.gd",
    "godot/tests/unit/test_game.gd",
    "godot/tests/unit/test_w1.gd",
    "godot/tests/unit/test_w2.gd",
    "godot/tests/unit/test_w3.gd",
    "godot/tests/unit/test_w4.gd",
    "godot/tests/unit/test_g0.gd",
    "godot/tests/unit/test_g1.gd",
    "godot/tests/unit/test_g2.gd",
    "godot/tests/unit/test_g3.gd",
    "godot/tests/unit/test_g4.gd",
    "tools/check_unity_health.sh",
    "tools/run_editmode_tests.sh",
    "tools/edit_guard.py",
    "build",
)

# 문서가 쓰는 짧은 경로(예: `sim/combat.gd`)를 실제 위치로 풀어 볼 기준 디렉터리들.
RESOLVE_BASES = (
    "",
    "docs/",
    "docs/dev/",
    "docs/design/",
    "docs/adr/",
    "godot/",
    "godot/core/",
    "godot/autoload/",
    "godot/game/",
    "godot/game/main/",
    "godot/game/view/",
    "godot/game/ui/",
    "godot/game/world/",
    "godot/tests/unit/",
    "data/",
    "sim/",
    "tools/",
    "art-source/",
    "audio-source/",
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

# 원본에서 문면 그대로 복사한 문서는 이 리포의 출처 표기 규칙 대상이 아니다.
# 고치지 않는 글이라 검사하면 지적만 쌓이고 진짜 문제가 묻힌다.
# (docs/gdd/README.md 가 성질과 지위를 설명한다.)
IMPORTED_DOC_DIRS = {
    "gdd",
    # 원본 GDD 사본을 직업 표만 바꿔 다시 만든 사본 — 글은 여전히 원본 문면이다
    # (tools/gen_gdd_revised.py 의 생성물).
    "gdd_개정본",
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


def imported_data_names(root, data_dir):
    """`data/manifest.json` 이 나열한 "원본에서 가져온 런타임 데이터" 이름.

    이 파일들은 이 저장소가 쓴 주장이 아니라 원본 데이터의 복사본이다.
    문서 검사(참조·링크·SSOT·숫자 주장)는 사람이 쓴 문서에만 적용해야 한다 —
    복사본을 문장으로 읽으면 원본 JSON 안의 문자열을 우리 주장으로 오인한다.
    """
    p = root / data_dir / "manifest.json"
    if not p.exists():
        return set()
    try:
        obj = json.loads(p.read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return set()
    files = obj.get("files")
    if not isinstance(files, list):
        return set()
    return set(str(f) for f in files)


def collect_docs(root, data_dir):
    """검사 대상 문서 수집 (md 전체 + data 디렉터리 안 json).

    manifest 가 나열한 이관 데이터 JSON 은 제외한다 (imported_data_names 참조).
    """
    out = []
    imported = imported_data_names(root, data_dir)
    for p in sorted(root.rglob("*.md")):
        try:
            rel = p.relative_to(root)
        except ValueError:
            continue
        if any(part in SKIP_DIRS for part in rel.parts[:-1]):
            continue
        if any(part in IMPORTED_DOC_DIRS for part in rel.parts[:-1]):
            continue
        out.append(p)
    data_root = root / data_dir
    if data_root.is_dir():
        for p in sorted(data_root.glob("*.json")):
            if p.name in imported:
                continue
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


def inherits_prev(line):
    """이 줄이 바로 윗줄의 문맥을 물려받아도 되는가.

    표 행(|로 시작)은 아니다 — 표에서 행 하나는 사실 하나이므로,
    윗 행이 '원본 이야기'라거나 '원본 대조' 표시를 달았다고 해서
    바로 아래 행까지 그 상태가 번지면 안 된다 (정밀도 결함).
    """
    return not line.lstrip().startswith("|")


# ---------------------------------------------------------------- 검사들


def check_broken_reference(root, docs, stats):
    findings = []
    for path in docs:
        rel = str(path.relative_to(root))
        lines = read_lines(path)
        prose, _ = split_fences(lines)
        for i, (no, line) in enumerate(prose):
            if line_has_original(line) or (
                inherits_prev(line) and line_has_original(prev_prose_line(prose, i))
            ):
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
    docs_lines = {}
    for path in docs:
        prose, _ = split_fences(read_lines(path))
        docs_lines[str(path.relative_to(root))] = prose
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
        for rel, lines in sorted(docs_lines.items()):
            if sources and rel not in sources:
                continue
            for no, line in lines:
                if any(mark in line for mark in REFUTATION_MARKERS):
                    stats["exempt"] += 1
                    continue
                seen = set(value_re.findall(line))
                for found in sorted(seen):
                    if found != value:
                        findings.append(
                            (rel, no, "`%s` 값이 registry(%s)와 다릅니다: %s"
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
        # 전체 이름으로 묶는다. 예전에는 마지막 꼬리말(_RATE·_SEED ...)로 묶어서
        # SHAPED_RATE=0.05 와 LEGACY_RATE=0.95 가 '다른 상수의 드리프트'로 보고됐다 —
        # 꼬리말이 같은 다른 상수를 같은 것으로 본 정밀도 결함이었다.
        decls.setdefault((name.upper(), value), set()).add(loc)

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
        # manifest 가 나열한 이관 데이터는 '우리 상수의 선언 장소'가 아니다 —
        # 원본 복사본과 우리 코드의 우연한 이름 충돌을 드리프트로 보고하지 않는다.
        imported = imported_data_names(root, "data")
        for p in sorted(data_dir.glob("*.json")):
            if p.name in imported:
                continue
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
    names = {}
    for (name, value), locs in decls.items():
        names.setdefault(name, {})[value] = sorted(locs)
    findings = []
    for name in sorted(names):
        values = names[name]
        if len(values) < 2:
            continue
        for value in sorted(values):
            for loc in values[value]:
                findings.append(
                    (loc, 0, "상수 '%s' 가 파일마다 다른 값입니다: %s"
                     % (name, ", ".join("%s=%s" % (v, len(values[v]))
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
            claim_text = SECTION_RE.sub("§", claim_text)
            if not STANDALONE_NUM_RE.search(claim_text):
                continue
            if inherits_prev(line):
                window = line + "\n" + prev_prose_line(prose, i)
            else:
                window = line
            if any(mark in window for mark in CLAIM_MARKERS):
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
