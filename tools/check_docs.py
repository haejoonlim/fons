"""Fail if a required artifact is missing.

Concept from the original repo's design-docs/_tools gates, widened so the
new project's plan, setup, handoff and audit files are actually guarded.
Run: python3 tools/check_docs.py   (exit 0 = all present, 1 = something is missing)
"""
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
