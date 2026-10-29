#!/usr/bin/env bash
# Godot 한 번에 하나 — 여러 에이전트가 같은 체크아웃에서 Godot 을 동시에 돌리면
# `.godot/` 임포트 캐시와 GUT 결과 파일이 서로를 덮어쓴다 (조용히 틀린 통과가 난다).
#
# 왜 mkdir 인가: macOS 에는 flock 이 없고, `shlock` 은 기본 설치가 아니다.
# mkdir 은 원자적이라 두 프로세스가 동시에 성공할 수 없다.
#
# 사용:
#   ./tools/godot_lock.sh godot --headless --path godot -s tools/floor_report.gd -- --gk
#   ./tools/godot_lock.sh ./tools/test_godot.sh
#
# 잠금은 TMPDIR 에 있다. 30분 넘게 안 풀린 잠금은 죽은 프로세스의 잔해로 보고 회수한다.
set -euo pipefail

if [ $# -eq 0 ]; then
  echo "사용법: tools/godot_lock.sh <명령...>" >&2
  exit 2
fi

LOCK="${TMPDIR:-/tmp}/fons-godot.lock"
STALE_MIN=30
TRIES=600 # 2초 × 600 = 20분

for _ in $(seq 1 "$TRIES"); do
  if mkdir "$LOCK" 2>/dev/null; then
    printf '%s\n' "$$" >"$LOCK/pid"
    trap 'rm -rf "$LOCK"' EXIT
    "$@"
    exit $?
  fi
  # -mmin -N 은 "N분 안에 수정됨"만 출력한다. 아무것도 없으면 오래된 잠금이다.
  if [ -d "$LOCK" ] && [ -z "$(find "$LOCK" -maxdepth 0 -mmin "-$STALE_MIN" 2>/dev/null)" ]; then
    echo "[lock] 30분 넘은 잠금 회수: $LOCK" >&2
    rm -rf "$LOCK"
    continue
  fi
  sleep 2
done

echo "[FAIL] godot 잠금 대기 초과(20분): $LOCK" >&2
exit 1
