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

# --- 편집 중 실행 방지: 실행 전에 시각을 찍는다 ---
# 다른 에이전트나 사람이 소스를 고치는 도중에 돌리면 통과·실패가 실행마다 뒤집힌다.
# 2026-10-25 실측: 같은 코드에서 테스트 수가 451 → 465 → 471 → 475 로 늘었고,
# 실패 파일도 test_estate.gd(8건) → test_main.gd(7건) → 0건 으로 갈아탔다.
# 그때 초록이었던 실행도, 이후 편집을 반영하지 않은 결과라 근거로 쓸 수 없다.
# 그래서 실행이 끝난 뒤 이 시각 이후에 바뀐 소스가 있으면 초록을 내지 않고 실패한다.
# 템플릿에 `X` 를 넣는다 — BSD(macOS)는 없어도 붙여 주지만 GNU(CI 리눅스)는
# `too few X's in template` 으로 죽는다. 2026-10-27 CI 첫 실행이 이것 때문에 실패했다.
STAMP="$(mktemp "${TMPDIR:-/tmp}/fons_gate_stamp.XXXXXX")"
trap 'rm -f "$STAMP"' EXIT

# 게이트 계약 G-1·G-2 (`tools/gate_contract.py`) — 마지막 줄이 `[PASS] godot` /
# `[FAIL] godot — 이유`, 종료코드는 0 또는 1. 표식은 stdout 으로 낸다 (gate_all 이 거기서 읽는다).
fail() {
  echo "[FAIL] godot — $1"
  exit 1
}

# --- 임포트 단계에 시간 상한을 둔다 ---
# 2026-10-29 실측: 마운트된 볼륨 하나(/Volumes/BOOTCAMP)의 사용자 공간 파일시스템
# 데몬이 죽어 마운트가 고아가 되자, 그 볼륨의 메타데이터 조회가 커널에서 영원히 블록됐다.
# Godot 에디터는 시작할 때 마운트된 볼륨을 열거하므로(샘플러: NSFileManager
# mountedVolumeURLsIncludingResourceValuesForKeys -> __getattrlist) `--import` 가
# 첫 줄만 찍고 10분 넘게 멈췄고, 같은 이유로 `/sbin/mount` 까지 멈췄다.
# 상한이 없으면 게이트가 조용히 매달린다. 임포트가 상한을 넘기면 건너뛰고 GUT 로 간다 —
# 임포트는 편의 단계이고, 거짓 통과를 실제로 막는 것은 아래 junit 검사다
# (0건 실행·스크립트 누락). 둘은 그대로 둔다.
IMPORT_TIMEOUT="${FONS_IMPORT_TIMEOUT:-180}"

bounded() { # bounded <초> <명령...> — 넘기면 SIGKILL, 137 반환
  local secs="$1"
  shift
  "$@" &
  local cmd_pid=$!
  ( sleep "$secs"; kill -9 "$cmd_pid" 2>/dev/null ) &
  local watcher=$!
  local rc=0
  wait "$cmd_pid" || rc=$?
  kill "$watcher" 2>/dev/null || true
  wait "$watcher" 2>/dev/null || true
  return "$rc"
}

echo "+ godot --headless --import (상한 ${IMPORT_TIMEOUT}초)"
import_status=0
bounded "$IMPORT_TIMEOUT" godot --headless --import || import_status=$?
import_skipped=0
if [ "$import_status" -eq 137 ] || [ "$import_status" -eq 143 ]; then
  import_skipped=1
  echo "WARN: 임포트가 ${IMPORT_TIMEOUT}초 안에 끝나지 않아 건너뜁니다 (GUT 는 계속 돈다)." >&2
  echo "      흔한 원인: 응답하지 않는 마운트 볼륨 때문에 Godot 이 볼륨 열거에서 블록." >&2
  # 백틱을 쓰지 않는다 — 쌍따옴표 안의 백틱은 명령 치환으로 실행돼, 멈춘 볼륨을
  # 진단하려는 문구가 그 자리에서 같이 멈춘다 (2026-10-29 실측, 직접 밟음).
  echo "      확인(macOS): ls -la /Volumes/* 중 멈추는 볼륨이 있는지. 재부팅하면 풀린다." >&2
elif [ "$import_status" -ne 0 ]; then
  fail "임포트 실패 (exit=$import_status)"
fi

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

# --- 편집 중 실행 방지: GUT 가 도는 동안 소스가 바뀌었는지 ---
# `.godot/`(임포트 캐시)는 Godot 이 스스로 만지므로 뺀다. junit 결과 파일은 필터에 안 걸린다.
changed="$(find . -path ./.godot -prune -o -type f \
  \( -name '*.gd' -o -name '*.tscn' -o -name '*.tres' -o -name '*.json' -o -name 'project.godot' \) \
  -newer "$STAMP" -print 2>/dev/null | sed 's|^\./||' | head -20 || true)"
if [ -n "$changed" ]; then
  echo "FAIL: 실행 중에 아래 소스가 바뀌었습니다 — 편집 중 실행이라 결과를 신뢰할 수 없습니다:" >&2
  echo "$changed" | sed 's/^/  - /' >&2
  echo "편집을 멈춘 뒤 다시 돌리세요." >&2
  fail "실행 중 소스 변경 (편집 중 실행)"
fi

if [ "$gut_status" -ne 0 ]; then
  echo "FAIL: GUT 실패 (exit=$gut_status), 실행된 테스트 $tests 건" >&2
  # `${tests}건` — 중괄호 없이 `$tests건` 으로 쓰면 bash 3.2 가 한글 첫 바이트를 변수명으로
  # 물어 ``tests\xea': unbound variable'' 로 죽는다 (2026-10-18 실측).
  fail "GUT 실패 (exit=$gut_status) · 테스트 ${tests}건"
fi

if [ "$import_skipped" -eq 1 ]; then
  echo "주의: 임포트를 건너뛴 실행입니다 (기존 .godot 캐시 사용). 위 WARN 을 확인하세요."
fi
echo "OK: GUT $tests tests passed (junit: $JUNIT)"
echo "[PASS] godot"
