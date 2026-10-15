# Godot Porting Map — 폰즈 (FONS) (soul-commander → 폰즈)

원본 `unity/PORTING_MAP.md`(v0.1-godot-final) 승계. Unity C#은 버리고 매핑만 유지 (원본 미검증 — 원본 문서 열람 불가).

## TS 시뮬 → GDScript

| 원본 (fons-web-ver/app/src) | Godot (godot/scripts) | 비고 |
|---|---|---|
| `game.ts` (상태머신, title/combat/result/estate) | `autoload/game_state.gd` | canonical state, 세이브는 SaveManager로 |
| `combat.ts` (DamageFormula) | `sim/combat.gd` | TS 1:1, D-267 1:1 (원본 미검증) |
| `summon.ts` | `sim/summon.gd` | free/pity/lineage/multi, unlock/realpath |
| `estate.ts` + `estate_web.ts` | `sim/estate.gd` | S2 death, S3_2/3_3/3_4 |
| `party.ts` | `sim/party.gd` | formation/passive |
| `tower.ts` | `sim/tower.gd` | floor/progress |
| `economy_snapshot.ts` | `sim/economy.gd` | baseline + snapshot |
| `game3d/states.ts`, `scene.ts` | `world/scene.gd` 개념 | Godot SceneTree로 대체 |
| `game3d/estate3d.ts` | `world/estate_3d.gd` | 영지 3D 최소신 |
| `game3d/explore3d.ts` | `world/explore_3d.gd` | 탐험 3D (WASD+AI 4종) |
| `game3d/monparts.ts` | `world/monparts.gd` | 몬스터 파츠 합성 |
| `game3d/title.ts` | `world/title.gd` | 타이틀 |

## Unity C# → GDScript (재작성, 복사 금지)

- `Scripts/Battle/*` → `sim/combat.gd` + `world/battle_*.gd`
- `Scripts/Summon/*` → `sim/summon.gd` + `sim/gacha.gd`
- `Scripts/Estate/*` → `sim/estate.gd`
- `Scripts/Core/GameState.cs` → `autoload/game_state.gd`
- `Scripts/Data/*` → `autoload/data_loader.gd` (JSON SSOT 로드)
- `Scripts/Save/*` → `autoload/save_manager.gd` (별도 신규)
- `Scripts/UI/*` → Godot Control 신으로 재작성
- `Scripts/Audio/*` → Godot AudioServer로 재작성

## 검증 매핑

| 원본 verify | Godot 대응 |
|---|---|
| `verify_game.mjs` 22/22 (원본 미검증) | `tests/test_game.gd` |
| `verify_w1~w4.mjs` | `tests/test_w1..w4.gd` (또는 gate_all.py) |
| `verify_g0~g4, g3scope.mjs` | `tests/test_g*.gd` |
| `verify_direct.mjs`, `verify_battle.mjs` | `tests/test_combat.gd` |
| `verify_assets.mjs`, `verify_fx.mjs`, `verify_monparts.mjs` (원본 미검증) | Phase 3 이후 (에셋 재생성 후) |

## 렌더/MSAA 참고 (원본 기록)

- 원본 이슈: URP + `@react-three/fiber` 조합에서 MSAA/후처리 충돌 기록 있음.
- Godot에서는 3D 시작 시 MSAA 3D=2x, 스케일링 Bilateral, SSAO/SSR 끔으로 시작.
