"""Fail if a required artifact is missing, or the folder structure regressed.

Concept from the original repo's design-docs/_tools gates, widened so the
new project's plan, setup, handoff and audit files are actually guarded.
Run: python3 tools/check_docs.py   (exit 0 = all present, 1 = something is missing)
"""
import filecmp
import json
from pathlib import Path

HERE = Path(__file__).resolve().parent.parent


def _stop(reason):
    """G-2 (`tools/gate_contract.py`) — 이 스크립트는 선형이라 마지막 줄만 직접 맡는다."""
    print("[FAIL] docs — %s" % reason, flush=True)
    raise SystemExit(1)

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
    "docs/dev/AGENT_SKILLS.md",
    "docs/design/PLAN_2D_FIRST.md",
    "docs/design/PROMPT_2D_FIRST.md",
    # 상층 밸런스 결정 — 111~130 을 열지 않는 이유와 재개 조건이 사라지면 같은 논의를 처음부터 다시 한다.
    "docs/design/상층_개방_결정.md",
    # 문서 서식 — 없으면 매번 같은 칸을 새로 만들고, 만든 사람마다 다른 칸을 쓴다.
    "docs/templates/README.md",
    "docs/templates/밸런스_조정_기록.md",
    "docs/templates/난이도_곡선표.md",
    "docs/templates/버그_기록.md",
    # 결정 기록 (구조를 바꾼 이유가 사라지면 다음 사람이 같은 실수를 반복한다)
    "docs/adr/README.md",
    "docs/adr/0001-repo-layout.md",
    "docs/adr/0002-data-ssot.md",
    "docs/adr/0003-2d-first-vector3-sim.md",
    "docs/adr/0004-renderer-gl-compatibility.md",
    "docs/adr/0005-stat-coeff-axes.md",
    "docs/adr/0006-job-coef-mapping.md",
    "docs/adr/0007-encounter-depth-tier.md",
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
    # 몬스터 구조·참조 게이트 — 없어지면 138종의 모양을 아무도 안 본다.
    "tools/check_monsters.py",
    # 외부 스킬의 라이선스 원문 — 없으면 재배포 조건을 못 지킨다 (docs/dev/AGENT_SKILLS.md).
    "third_party/awesome-gamedev-agent-skills/LICENSE",
    "third_party/gstack-game/LICENSE",
    "third_party/Claude-Code-Game-Studios/LICENSE",
    # 스킬을 핀 SHA로 받고 설치본을 대조하는 도구 — 이게 없으면 어느 커밋에서 온 스킬인지 사라진다.
    "tools/fetch_skills.py",
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
    # 06 §3.4 생태 조우 편성 — 원본 Unity `EcologyEncounter` 의 GDScript 포팅.
    "godot/core/encounter.gd",
    # 전투 턴 루프 — 웹 `combatStep` 포팅.
    "godot/core/battle.gd",
    # 편성 → 전투 배선 (층 한 판).
    "godot/core/floor_run.gd",
    "godot/game/view/view_contract.gd",
    "godot/game/view/view_factory.gd",
    "godot/game/view/projection.gd",
    "godot/game/view/view_2d/view_2d.tscn",
    "godot/tests/unit/test_gacha.gd",
    "godot/tests/unit/test_combat.gd",
    "godot/tests/unit/test_projection.gd",
    "godot/tests/unit/test_view_2d.gd",
    "godot/tests/unit/test_view_factory.gd",
    # 데이터 로더가 런타임에 모든 JSON 을 읽는지 — 파일이 있어도 못 읽으면 게임은 빈 채로 돈다.
    "godot/tests/unit/test_data_loader.gd",
    # 편성 계약 — 130층 전수(후보 0 금지 · 3~5종 · world/boss 미출현 · 접촉 회전).
    "godot/tests/unit/test_encounter.gd",
    # 턴 순서·전술게이지·대상 선택 — 원본 로그와 8줄 대조 포함.
    "godot/tests/unit/test_battle.gd",
    # 층 한 판 — 130층 전수 종결·승자 판정·결정론.
    "godot/tests/unit/test_floor_run.gd",
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
    _stop("필수 산출물 %d개 없음" % len(missing))
print("DOCS OK: %d files present" % len(REQUIRED))

regressed = [d for d in FORBIDDEN_DIRS if (HERE / d).exists()]
if regressed:
    print("STRUCTURE REGRESSION — 옛 배치가 되살아났습니다 (docs/adr/0001-repo-layout.md):")
    for d in regressed:
        print("  -", d)
    _stop("옛 배치가 되살아남")
print("STRUCTURE OK: 옛 배치 없음 (%d개 확인)" % len(FORBIDDEN_DIRS))

# 이관 데이터가 실제로 들어와 있는지 본다. manifest 는 원본 트리와 대조한 확정 목록이다.
# 목록만 있고 파일이 없으면 게임은 빈 데이터로 돌아가는데, 그건 화면상으로 안 보인다.
manifest_path = HERE / "data" / "manifest.json"
if not manifest_path.exists():
    print("MISSING: data/manifest.json")
    _stop("data/manifest.json 없음")
manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
wanted = manifest.get("files") or []
data_missing = [n for n in wanted if not (HERE / "data" / n).exists()]
if data_missing:
    print("MISSING DATA (%d/%d):" % (len(data_missing), len(wanted)))
    for n in data_missing:
        print("  -", n)
    print("힌트: data/ 가 유일한 정본 사본이다. 원본이 다시 생겼을 때만 "
          "tools/sync_data.py --src <원본 데이터 폴더> --dst data")
    _stop("data/ 파일 %d개 없음" % len(data_missing))
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
    _stop("godot/data/ 가 data/ 와 다름")
print("MIRROR OK: %d files identical (data/ = godot/data/)" % len(wanted))
print("[PASS] docs")
