"""Fail if a required artifact is missing, or the folder structure regressed.

Concept from the original repo's design-docs/_tools gates, widened so the
new project's plan, setup, handoff and audit files are actually guarded.
Run: python3 tools/check_docs.py   (exit 0 = all present, 1 = something is missing)
"""
import filecmp
import json
from pathlib import Path

HERE = Path(__file__).resolve().parent.parent

REQUIRED = [
    # 최상위 문서
    "README.md",
    "SETUP.md",
    "HANDOFF.md",
    "MIGRATION_PLAN.md",
    # 문서 지도 · 계획/검수 (docs/README.md 가 입구다)
    "docs/README.md",
    "docs/dev/DEV_PLAN.md",
    "docs/dev/DOC_REVIEW.md",
    "docs/dev/GODOT_PORTING_MAP.md",
    "docs/dev/STRUCTURE_RESEARCH.md",
    "docs/design/PLAN_2D_FIRST.md",
    "docs/design/PROMPT_2D_FIRST.md",
    # 결정 기록 (구조를 바꾼 이유가 사라지면 다음 사람이 같은 실수를 반복한다)
    "docs/adr/README.md",
    "docs/adr/0001-repo-layout.md",
    "docs/adr/0002-data-ssot.md",
    "docs/adr/0003-2d-first-vector3-sim.md",
    "docs/adr/0004-renderer-gl-compatibility.md",
    # 아트·오디오 규칙의 정본
    "docs/art/ART_BIBLE.md",
    "docs/audio/AUDIO_GUIDE.md",
    # 원본 대조 자료 (원본을 읽고 확인한 값의 근거)
    "docs/original/00_읽는법.md",
    "docs/original/01_확정_규칙.md",
    "docs/original/02_웹버전_포팅.md",
    "docs/original/03_데이터_영지_탑.md",
    # 원본 소스(엔진 밖)와 런타임 에셋(엔진 안)의 경계 — 규칙만 있어도 자리는 지킨다
    "art-source/README.md",
    "audio-source/README.md",
    "godot/assets/README.md",
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
    # Godot 프로젝트 — 씬은 그 씬 전용 스크립트와 같은 폴더에 있다 (ADR 0001)
    "godot/project.godot",
    "godot/.gutconfig.json",
    "godot/game/main/main.tscn",
    "godot/game/main/main.gd",
    "godot/game/ui/title/title.tscn",
    "godot/data/README.md",
    "godot/autoload/game_state.gd",
    "godot/autoload/data_loader.gd",
    "godot/core/gacha.gd",
    "godot/core/combat.gd",
    "godot/game/view/view_contract.gd",
    "godot/game/view/view_factory.gd",
    "godot/game/view/projection.gd",
    "godot/game/view/view_2d/view_2d.tscn",
    "godot/tests/unit/test_gacha.gd",
    "godot/tests/unit/test_combat.gd",
    "godot/tests/unit/test_projection.gd",
    "godot/tests/unit/test_view_2d.gd",
    "godot/tests/unit/test_view_factory.gd",
]

# 구조 회귀 방지 — 옛 배치가 되살아나면 여기서 걸린다.
# (씬이 스크립트와 다른 폴더로 흩어지면 ADR 0001 의 근접 배치가 무너진다.)
FORBIDDEN_DIRS = [
    "godot/scripts",
    "godot/scenes",
]

missing = [r for r in REQUIRED if not (HERE / r).exists()]
if missing:
    print("MISSING:")
    for m in missing:
        print("  -", m)
    raise SystemExit(1)
print("DOCS OK: %d files present" % len(REQUIRED))

regressed = [d for d in FORBIDDEN_DIRS if (HERE / d).exists()]
if regressed:
    print("STRUCTURE REGRESSION — 옛 배치가 되살아났습니다 (docs/adr/0001-repo-layout.md):")
    for d in regressed:
        print("  -", d)
    raise SystemExit(1)
print("STRUCTURE OK: 옛 배치 없음 (%d개 확인)" % len(FORBIDDEN_DIRS))

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
    print("힌트: data/ 가 유일한 정본 사본이다. 원본이 다시 생겼을 때만 "
          "tools/sync_data.py --src <원본 데이터 폴더> --dst data")
    raise SystemExit(1)
print("DATA OK: %d/%d in data/" % (len(wanted), len(wanted)))

# 데이터 정본(data/)과 런타임 사본(godot/data/)이 같은지 본다.
# DataLoader 는 `res://data`(= godot/data)를 읽는다. 거기가 어긋나면 게이트는 초록인데
# 게임은 옛 데이터로 돈다 — 2026-10-17 에 job_tree·races 가 실제로 그렇게 어긋나 있었다.
# 사본은 손으로 고치지 않는다: data/ 를 고친 뒤 같은 파일을 복사한다.
copy_dir = HERE / "godot" / "data"
absent = [n for n in wanted if not (copy_dir / n).exists()]
drift = [n for n in wanted if (copy_dir / n).exists()
         and not filecmp.cmp(HERE / "data" / n, copy_dir / n, shallow=False)]
if absent or drift:
    print("DATA MIRROR DRIFT — godot/data/ 가 data/ 와 다릅니다:")
    for n in absent:
        print("  - 없음:", n)
    for n in drift:
        print("  - 다름:", n)
    print("힌트: cp data/<파일> godot/data/ (사본을 손으로 고치지 않는다 — data/ 가 정본)")
    raise SystemExit(1)
print("MIRROR OK: %d files identical (data/ = godot/data/)" % len(wanted))
