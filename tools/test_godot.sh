#!/usr/bin/env bash
# Godot 쪽 검증을 한 번에 돌린다: 리소스 임포트 -> GUT.
#
# 왜 두 단계인가:
#   새로 클론한 상태(.godot 임포트 캐시 없음)에서 GUT를 바로 돌리면
#   "Some GUT class_names have not been imported" 에러를 찍고
#   **테스트를 하나도 실행하지 않은 채 exit 0** 으로 끝난다. 침묵하는 거짓 통과다.
#   그래서 임포트를 먼저 하고, 끝나고 실제로 테스트가 돌았는지 junit 결과로 확인한다.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$HERE/godot"

JUNIT="$HERE/godot/.gut_junit.xml"
rm -f "$JUNIT"

echo "+ godot --headless --import"
godot --headless --import

echo "+ godot --headless -s addons/gut/gut_cmdln.gd -gexit"
set +e
godot --headless -s addons/gut/gut_cmdln.gd -gexit
gut_status=$?
set -e

# --- 거짓 통과 방지: 실제로 테스트가 돌았는지 확인한다 ---
if [ ! -f "$JUNIT" ]; then
  echo "FAIL: GUT 결과 파일이 없습니다 ($JUNIT) — 테스트가 실행되지 않았습니다." >&2
  exit 1
fi

tests="$(grep -o 'tests="[0-9]*"' "$JUNIT" | head -1 | grep -o '[0-9]*' || true)"
if [ -z "${tests:-}" ] || [ "$tests" -eq 0 ]; then
  echo "FAIL: GUT가 테스트를 0건 실행했습니다 (그린으로 보이지만 아무것도 검증하지 않았습니다)." >&2
  exit 1
fi

if [ "$gut_status" -ne 0 ]; then
  echo "FAIL: GUT 실패 (exit=$gut_status), 실행된 테스트 $tests 건" >&2
  exit "$gut_status"
fi

echo "OK: GUT $tests tests passed (junit: $JUNIT)"
