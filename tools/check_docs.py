"""Fail if a required artifact is missing.

Concept from the original repo's design-docs/_tools gates, widened so the
new project's plan, setup, handoff and audit files are actually guarded.
Run: python3 tools/check_docs.py   (exit 0 = all present, 1 = something is missing)
"""
import json
from pathlib import Path

HERE = Path(__file__).resolve().parent.parent

REQUIRED = [
    # 최상위 문서
    "README.md",
    "SETUP.md",
    "HANDOFF.md",
    "MIGRATION_PLAN.md",
    # 계획/검수 문서
    "docs/DEV_PLAN.md",
    "docs/DOC_REVIEW.md",
    "docs/GODOT_PORTING_MAP.md",
    # 원본 대조 자료 (원본을 읽고 확인한 값의 근거)
    "docs/original/00_읽는법.md",
    "docs/original/01_확정_규칙.md",
    "docs/original/02_웹버전_포팅.md",
    "docs/original/03_데이터_영지_탑.md",
    # 설정
    "data/README.md",
    "data/manifest.json",
    # 시뮬레이터
    "sim/README.md",
    "sim/gacha.py",
    # 도구
    "tools/sync_data.py",
    "tools/review_docs.py",
    "tools/tracked_numbers.json",
    "tools/test_godot.sh",
    # Godot 프로젝트
    "godot/project.godot",
    "godot/.gutconfig.json",
    "godot/scenes/title.tscn",
    "godot/data/README.md",
    "godot/scripts/autoload/game_state.gd",
    "godot/scripts/autoload/data_loader.gd",
    "godot/scripts/sim/gacha.gd",
    "godot/scripts/sim/combat.gd",
    "godot/tests/test_gacha.gd",
    "godot/tests/test_combat.gd",
]

missing = [r for r in REQUIRED if not (HERE / r).exists()]
if missing:
    print("MISSING:")
    for m in missing:
        print("  -", m)
    raise SystemExit(1)
print("DOCS OK: %d files present" % len(REQUIRED))

# 이관 데이터가 실제로 들어와 있는지 본다. manifest 는 원본 트리와 대조한 확정 목록이다.
# 목록만 있고 파일이 없으면 게임은 빈 데이터로 돌아가는데, 그건 화면상으로 안 보인다.
manifest_path = HERE / "data" / "manifest.json"
if not manifest_path.exists():
    print("MISSING: data/manifest.json")
    raise SystemExit(1)
manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
wanted = manifest.get("files") or []
data_missing = [n for n in wanted if not (HERE / "data" / n).exists()]
if data_missing:
    print("MISSING DATA (%d/%d):" % (len(data_missing), len(wanted)))
    for n in data_missing:
        print("  -", n)
    print("힌트: tools/sync_data.py --src <원본>/unity/Assets/Resources/Data --dst data")
    raise SystemExit(1)
print("DATA OK: %d/%d in data/" % (len(wanted), len(wanted)))
