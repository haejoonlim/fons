# Godot Porting Map — 폰즈 (FONS) 원본 → GDScript 매핑

원본 Unity 저장소를 2026-10-17에 클론해서 읽고 다시 쓴 표다 (원본 대조).
원본의 자체 포팅 문서 `unity/PORTING_MAP.md` 는 구 Godot 구현 `.gd` 201개의 참고 색인이고,
v8.0 리부트에서 "코드 직접 이식 대상이 아니다"로 강등돼 있다 (원본 대조).
그래서 이 표의 이관 원본은 **웹 시뮬 코어 TS**와 **정본 데이터 JSON**이다 — Unity C#은 이름만 참고하고 복사하지 않는다.

## 1. 이관 원칙

| 항목 | 어디서 오나 | 비고 |
|---|---|---|
| 규칙·수치 | 이 저장소의 [original/01_확정_규칙.md](../original/01_확정_규칙.md) | 값의 출처를 한 곳에 모은다 (원본 대조) |
| 런타임 데이터 | 원본 원본 저장소의 데이터 폴더의 JSON 17종 (원본 대조) | 목록은 [original/03_데이터_영지_탑.md](../original/03_데이터_영지_탑.md) |
| 포팅 원본 코드 | 원본 `fons-web-ver/app/src/` 의 TS (원본 대조) | 아래 §2 표가 전수다 |
| 버릴 것 | Unity C#·에셋·웹 표현층 | 아래 §3·§4 |
| 포팅 절차 | [MIGRATION_PLAN.md](../../MIGRATION_PLAN.md) | 이 표는 "무엇이 어디로 가나"만 다룬다 |

숫자를 코드에 넣기 전에는 언제나 `docs/original/` 을 먼저 확인한다. 거기 없는 값은 추측하지 않는다.

## 2. 웹 시뮬 코어 TS → GDScript (전수, 원본 대조)

원본 `fons-web-ver/app/src/` 의 실제 파일은 TypeScript 19개 + CSS 1개다 (원본 대조).
`economy.ts` 라는 파일은 **없다** — 경제는 `economy_snapshot.ts` 와 `estate_web.ts` 에 있다 (원본 대조).

| 원본 (fons-web-ver/app/src) | Godot (`godot/core` · `godot/game`) | 비고 |
|---|---|---|
| `fons-web-ver/app/src/summon.ts` | `godot/core/summon.gd` | 소환 코어 — `mulberry32`·`rollGrade`·`summonOne`·13단계 로그 (원본 대조) |
| `fons-web-ver/app/src/party.ts` | `godot/core/party.gd` | 편제 5인·영구사망·보상 (원본 대조) |
| `fons-web-ver/app/src/combat.ts` | `godot/core/combat.gd` | 데미지·관통·위치보정·전술게이지 — 착수됨 |
| `fons-web-ver/app/src/tower.ts` | `godot/core/tower.gd` | 탑·바이옴 카드·D 곡선 |
| `fons-web-ver/app/src/estate.ts` | `godot/core/estate.gd` | 영지 |
| `fons-web-ver/app/src/estate_web.ts` | `godot/core/estate.gd` | 웹 전용 시설 재설계 오버라이드 — 본게임은 정본 JSON 기준으로 되돌린다 |
| `fons-web-ver/app/src/economy_snapshot.ts` | `godot/core/economy.gd` | 수지표 스냅샷 |
| `fons-web-ver/app/src/game.ts` | `godot/autoload/game_state.gd` | 게임 루프·공유 금고·최고층·소멸 판정 |
| `fons-web-ver/app/src/game3d/states.ts` | `godot/game/world/scene.gd` | 상태머신을 씬 전환으로 옮긴다 |
| `fons-web-ver/app/src/game3d/scene.ts` | `godot/game/world/scene.gd` | 공용 렌더러·리사이즈·dispose |
| `fons-web-ver/app/src/game3d/title.ts` | `godot/game/world/title.gd` | 타이틀 |
| `fons-web-ver/app/src/game3d/estate3d.ts` | `godot/game/world/estate_3d.gd` | 영지 3D 섬·도보·추적캠 |
| `fons-web-ver/app/src/game3d/explore3d.ts` | `godot/game/world/explore_3d.gd` | 층 탐험 3D |
| `fons-web-ver/app/src/game3d/monparts.ts` | `godot/game/world/monparts.gd` | 몬스터 파츠 조형 |
| `fons-web-ver/app/src/battle3d.ts` | `godot/game/world/battle_3d.gd` | 실시간 3D 전투 (WASD 파티장 + AI 4인) (원본 대조) |
| `fons-web-ver/app/src/summon3d.ts` | `godot/game/world/summon_fx.gd` | 3D 소환 연출 (결정→섬광→어셈블→오라→턴테이블) |
| `fons-web-ver/app/src/main.ts` | (대응 없음) | Vite 진입점·해시 라우터 — Godot 은 씬 전환으로 대체 |
| `fons-web-ver/app/src/visual.ts` | (대응 없음) | 웹 표현층 — 가져오지 않는다 |
| `fons-web-ver/app/src/sound.ts` | (대응 없음) | 사운드 훅 — Godot AudioServer 로 재작성 |
| `fons-web-ver/app/src/style.css` | (대응 없음) | 웹 스타일 |

`godot/core/` 는 씬 없는 규칙·계산(RefCounted), `godot/game/` 은 씬과 그 씬 전용 스크립트,
`godot/autoload/` 는 전역 상태를 맡는다. 3D 월드는 `godot/game/world/` 이고 아직 비어 있으며 Phase 3 에서 만든다.

## 3. Unity C# 영역 → 처분

경로 접두어만 참고한다. 실제 클래스 파일은 읽고 재작성한다.

| 원본 Unity 영역 | 처분 | Godot 대응 |
|---|---|---|
| 원본 전투 구현 | 재작성 | `godot/core/combat.gd` |
| 원본 소환 구현 | 재작성 | `godot/core/summon.gd` |
| 원본 영지 구현 | 재작성 | `godot/core/estate.gd` |
| 원본 코어 구현 | 재작성 | `godot/autoload/game_state.gd` |
| 원본 데이터 계층 | 재작성 | `godot/autoload/data_loader.gd` |
| 원본 세이브 구현 | 재작성 | `godot/autoload/save_manager.gd` |
| 원본 UI 구현 | 재작성 | Godot Control 씬 |
| 원본 오디오 구현 | 재작성 | Godot AudioServer |
| 원본 AI 구현 | 이식 대상 | P0 유틸리티 AI (기본×스탯×성격벡터×적성×스킬×문맥×습관 + 개체 시드) (원본 대조) |
| 원본 아트·프리팹·씬 | **버림** | 에셋은 재제작한다 |
| 원본 저장소의 데이터 폴더 | **가져옴** | JSON 17종을 `data/` 로 복사 (원본 대조) |

## 4. 검증 매핑

원본의 검증 스크립트는 실제로 **15개**다 — "20여개"라는 표현은 원본에 근거가 없다 (원본 대조).
`verify_game.mjs` 의 최신 기록값은 **42/42** 다 (원본 대조). 이 저장소의 대응 검증은 GUT 테스트와 파이썬 게이트다.

| 원본 verify (fons-web-ver) | 검증 대상 | 이 저장소 대응 |
|---|---|---|
| `fons-web-ver/verify_w1.mjs` | 소환 등급 분포·천장 가뭄 (N=100000) (원본 대조) | `sim/gacha.py` + `godot/tests/unit/test_gacha.gd` |
| `fons-web-ver/verify_w2.mjs` | 1~5층 전투 1런 (원본 대조) | `godot/tests/unit/test_w2.gd` (미작성) |
| `fons-web-ver/verify_w3.mjs` | 탑·바이옴 카드·도감 377 (원본 대조) | `godot/tests/unit/test_w3.gd` (미작성) |
| `fons-web-ver/verify_w4.mjs` | 영지 수지표 baseline | `godot/tests/unit/test_w4.gd` (미작성) |
| `fons-web-ver/verify_game.mjs` | 게임 루프·영지·은행 (LEY) | `godot/tests/unit/test_game.gd` (미작성) |
| `fons-web-ver/verify_direct.mjs` | 실시간 직접조작 | `godot/tests/unit/test_combat.gd` |
| `fons-web-ver/verify_battle.mjs` | 텍스트 턴 전투 | `godot/tests/unit/test_combat.gd` |
| `fons-web-ver/verify_g0.mjs` | 상태 전이 | `godot/tests/unit/test_g0.gd` (미작성) |
| `fons-web-ver/verify_g1.mjs` | 도보·영지 3D | `godot/tests/unit/test_g1.gd` (미작성) |
| `fons-web-ver/verify_g2.mjs` | 탐험 E2E | `godot/tests/unit/test_g2.gd` (미작성) |
| `fons-web-ver/verify_g3scope.mjs` | 사거리 범위 감시 | `godot/tests/unit/test_g3.gd` (미작성) |
| `fons-web-ver/verify_g4.mjs` | 메타·도감 등록·사운드 | `godot/tests/unit/test_g4.gd` (미작성) |
| `fons-web-ver/verify_assets.mjs` | 몬스터 에셋 매핑 | Phase 3 이후 (에셋 재생성 후) (원본 대조) |
| `fons-web-ver/verify_fx.mjs` | 3D 소환 연출 | Phase 3 이후 (원본 대조) |
| `fons-web-ver/verify_monparts.mjs` | 몬스터 파츠 조형 | Phase 3 이후 (원본 대조) |

## 5. 원본이 스스로 어긋나는 지점 (양쪽 다 기록, 조용히 고르지 않는다)

| 항목 | 값 A | 값 B | 실제 |
|---|---|---|---|
| 런타임 데이터 JSON 개수 | 10 (`unity/README.md`) | 13 (`unity/PORTING_MAP.md`) | 폴더에 17개 (원본 대조) |
| `verify_direct` 통과 수 | 12 (`GAME_PLAN_3D.md`) | 16 (스크립트 본문) | 최신은 스크립트 본문 (원본 대조) |
| `gacha_test.py` 개체 변량 | 상수 0.07 (±7%) | 같은 파일 주석 (±8%) | 상수와 주석이 어긋남 (원본 대조) |
| 직업 트리 규모 | L1 7 · L2 26 · 키워드 94 | L1 7 · L2 28 · L3 82 · 트리 117 | 개편 차수 차이 (원본 대조) |

## 6. 렌더/MSAA 참고

- 원본은 URP + Three.js 계열 조합에서 MSAA·후처리 충돌을 기록했다.
- Godot 은 3D 시작 시 MSAA 3D 2x, 스케일링 Bilateral, SSAO·SSR 끔으로 시작한다.
- 렌더러를 바꾸기 전에 [DEV_PLAN.md](DEV_PLAN.md) §4 를 읽는다. 이 머신은 Intel macOS 라 `gl_compatibility` 고정이다.
