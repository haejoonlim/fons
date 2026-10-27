#!/usr/bin/env bash
# 종족 시트를 다시 뽑아 게임 저장소로 가져온다 — 손 복사 금지 (art-source/README 규칙 1).
#
#   ./art-source/export/sync_race_sprites.sh              # 빌드 + 복사 + 임포트
#   ./art-source/export/sync_race_sprites.sh --no-build   # 이미 뽑힌 시트만 복사
#
# 생성기(`mpfb_sprite.py`)는 이 저장소 밖에 있다. MPFB 확장·사람 베이스 메시 캐시·
# morph_plan.json 이 그쪽 머신 자원이라 저장소로 옮기면 재현이 더 어려워진다.
# 그래서 "경로를 고정"하는 쪽으로 규칙을 지킨다: 이 스크립트가 유일한 통로다.
#
#   MPS_SRC   생성기 폴더 (기본 ~/Desktop/FONS_Character_Assets)
#   BLENDER   Blender 실행 파일
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SRC="${MPS_SRC:-$HOME/Desktop/FONS_Character_Assets}"
BLENDER="${BLENDER:-/Applications/Blender.app/Contents/MacOS/Blender}"
SHEETS="$SRC/races/mpfb/sheets"
DST="$HERE/godot/assets/art/sprites/races/mpfb"
RACES=14

BUILD=1
if [[ "${1:-}" == "--no-build" ]]; then
  BUILD=0
elif [[ -n "${1:-}" ]]; then
  echo "unknown option: $1 (쓰는 법: $0 [--no-build])" >&2
  exit 2
fi

die() {
  echo "[FAIL] $1" >&2
  exit 1
}

[[ -d "$SRC/export" ]] || die "생성기 폴더가 없다: $SRC/export — MPS_SRC 로 지정한다"
[[ -x "$BLENDER" ]] || die "Blender 가 없다: $BLENDER — BLENDER 로 지정한다"

if (( BUILD )); then
  echo "+ 빌드 — $SRC/export/mpfb_sprite.py (종족 $RACES)"
  ( cd "$SRC" && MPS_WORKERS="${MPS_WORKERS:-2}" "$BLENDER" -b --threads 2 \
      --python export/mpfb_sprite.py ) || die "빌드가 실패했다"

  echo "+ 프레임 게이트 — export/check_frames.py"
  set +e
  ( cd "$SRC" && "$BLENDER" -b --threads 4 --python export/check_frames.py ) 2>&1 \
    | grep -E "^(KEYS|MIN_PAIR_DIFF|MAX_BASE_SPREAD|MIN_MARGIN|OK|FAIL)"
  gate=${PIPESTATUS[0]}
  set -e
  (( gate == 0 )) || die "프레임 게이트 실패 — 시트를 복사하지 않는다"
fi

[[ -d "$SHEETS" ]] || die "시트 폴더가 없다: $SHEETS"
pngs=$(find "$SHEETS" -maxdepth 1 -name '*.png' | wc -l | tr -d ' ')
jsons=$(find "$SHEETS" -maxdepth 1 -name '*.json' | wc -l | tr -d ' ')
[[ "$pngs" -eq "$RACES" ]] || die "시트 png 가 $RACES 장이 아니다: $pngs"
[[ "$jsons" -eq "$RACES" ]] || die "시트 json 이 $RACES 개가 아니다: $jsons"

mkdir -p "$DST"
# 이전 차례에 있던 종족이 남아 돌아다니지 않게 지우고 새로 넣는다.
rm -f "$DST"/*.png "$DST"/*.json "$DST"/*.png.import
cp "$SHEETS"/*.png "$SHEETS"/*.json "$DST/"

echo "+ godot 임포트"
( cd "$HERE/godot" && godot --headless --import >/dev/null 2>&1 ) \
  || die "godot --headless --import 실패"

echo "OK — 종족 $RACES종 시트를 $DST 로 옮겼다"
