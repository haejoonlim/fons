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

# 게이트 계약 G-1·G-2 (`tools/gate_contract.py`) — 마지막 줄이 `[PASS] godot` /
# `[FAIL] godot — 이유`, 종료코드는 0 또는 1. 표식은 stdout 으로 낸다 (gate_all 이 거기서 읽는다).
fail() {
  echo "[FAIL] godot — $1"
  exit 1
}

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
  fail "GUT 결과 파일 없음"
fi

tests="$(grep -o 'tests="[0-9]*"' "$JUNIT" | head -1 | grep -o '[0-9]*' || true)"
if [ -z "${tests:-}" ] || [ "$tests" -eq 0 ]; then
  echo "FAIL: GUT가 테스트를 0건 실행했습니다 (그린으로 보이지만 아무것도 검증하지 않았습니다)." >&2
  fail "GUT 0건 실행 (거짓 통과)"
fi

# --- 거짓 통과 방지 2: 파일이 있는데 실행되지 않은 스크립트 ---
# 2026-10-18 실측: `test_encounter.gd` 가 없는 클래스(`FonsEncounter`)를 참조해 **파싱에 실패**했는데
# GUT 는 그 파일을 조용히 건너뛰고 나머지 35건을 전부 통과로 보고했다 (exit 0, "All tests passed").
# 즉 새 테스트를 쓰고도 안 돌아간 것을 알 수 없었다 — 이 저장소가 이미 두 번 겪은 침묵 실패다.
# 그래서 junit 의 testsuite 수를 디스크의 test_*.gd 수와 맞춘다.
ran_scripts="$(grep -o 'testsuite name="[^"]*"' "$JUNIT" | sed 's/.*name="//;s/"$//' | sort || true)"
expected_scripts="$(cd "$HERE/godot" && find tests -name 'test_*.gd' | sort)"
missing_scripts="$(comm -13 <(echo "$ran_scripts") <(echo "$expected_scripts") | sed '/^$/d' || true)"
if [ -n "$missing_scripts" ]; then
  echo "FAIL: 아래 테스트 스크립트가 실행되지 않았습니다 (파싱 실패? 클래스 이름 오타?):" >&2
  echo "$missing_scripts" | sed 's/^/  - /' >&2
  fail "테스트 스크립트 누락 (실행 안 됨)"
fi

if [ "$gut_status" -ne 0 ]; then
  echo "FAIL: GUT 실패 (exit=$gut_status), 실행된 테스트 $tests 건" >&2
  # `${tests}건` — 중괄호 없이 `$tests건` 으로 쓰면 bash 3.2 가 한글 첫 바이트를 변수명으로
  # 물어 ``tests\xea': unbound variable'' 로 죽는다 (2026-10-18 실측).
  fail "GUT 실패 (exit=$gut_status) · 테스트 ${tests}건"
fi

echo "OK: GUT $tests tests passed (junit: $JUNIT)"
echo "[PASS] godot"
