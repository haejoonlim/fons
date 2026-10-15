# sim/ — 숫자 시뮬레이터 (에셋 없음)

- `gacha.py`: W0 130연 게이트 재현용. `./.venv/bin/python sim/gacha.py` → GATE OK (상수 미검증).
- GDScript 본체는 `godot/scripts/sim/`:
  - `gacha.gd` (W0), `combat.gd` (D-267), 이후 `summon.gd`, `estate.gd`, `party.gd`, `tower.gd`, `economy.gd` 순으로 포팅. (이 순서는 원본 미검증 가정 — 원본 대조 후 확정)
- 원본: `soul-commander/fons-web-ver/app/src/*.ts`, `game3d/*`, `verify_*.mjs` — **원본 미검증**. 원본 소스는 아직 한 줄도 읽지 못했다(레포 비공개).
- 에셋·표현층은 다루지 않는다.

## 알려진 결함 — 숫자 3중 하드코딩 (SSOT 위반)

같은 W0 상수(`130`, `0.05`, `0.95`)가 **세 곳에 독립적으로** 박혀 있다:

| 파일 | 표기 |
|---|---|
| `sim/gacha.py` | `PULLS = 130`, `SHAPED_RATE = 0.05`, `LEGACY_COVERAGE = 0.95` |
| `godot/scripts/sim/gacha.gd` | `PULLS := 130`, `SHAPED_BONUS := 0.05`, `LEGACY_COVERAGE := 0.95` |
| `godot/tests/test_gacha.gd` | 기대값 `130`, `6.5`, `0.05`, `0.95` (숫자를 다시 적음) |

**왜 문제인가:**
1. 한 곳만 고치면 파이썬 시뮬레이터와 Godot 런타임이 조용히 다른 게임이 된다 — 이 저장소에서 가장 비싼 종류의 버그다.
2. `test_gacha.gd`가 기대값을 자기 안에 다시 적기 때문에, 상수를 잘못 고쳐도 테스트가 **같이 틀려서 통과**한다. 즉 이 테스트는 드리프트를 못 잡는다.
3. `assert_almost_eq(FonsGacha.expected_shaped(), 6.5)`는 `130 × 0.05`를 계산한 값과 6.5를 비교하므로, 상수를 바꾸면 깨진다 — 그런데 그 6.5도 하드코딩이다.

**의도한 수정 (Phase 1 첫 작업):**
- 숫자의 **단일 권위 소스**를 하나 정한다 — 예정 파일 `data/game_const.json` (**아직 없다**. 원본 대조로 값이 확정된 뒤에 만든다). 지금은 `sim/gacha.py`·`godot/scripts/sim/gacha.gd`·`godot/tests/test_gacha.gd` 세 곳이 유일한 (미검증) 사본이다.
- `sim/gacha.py`는 그 JSON을 읽고, `godot/scripts/sim/gacha.gd`도 같은 JSON을 읽는다. GDScript 쪽은 `DataLoader.load_json("game_const.json")` 경로를 쓴다.
- 테스트는 값을 **다시 적지 않고** JSON에서 읽어 비교한다. 그래야 JSON을 고쳤을 때 테스트가 실제로 깨진다.
- 추가로 `tools/review_docs.py`가 코드 상수와 JSON·문서 표기의 불일치를 잡도록 한다.

**단, 이 상수들이 원본 GDD와 일치하는지는 아직 미확인이다.** `130 / 0.05 / 0.95`는 이전 세션이 원본 문서를 읽지 못한 채 적어 넣은 값이다. 원본 접근 후 `PLAN.md §6-2`·`D-265`와 대조해 확정한다 — 다중 하드코딩을 먼저 정리하면 **틀린 숫자를 한 곳에 예쁘게 모으는** 결과가 될 수 있으므로, 순서는 ① 원본 대조 → ② 값 확정 → ③ 단일 소스화 로 한다.
