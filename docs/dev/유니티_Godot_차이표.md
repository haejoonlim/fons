# 유니티 원본 ↔ Godot 기능 차이표

기준일 2026-10-24. Unity 쪽은 `~/soul-commander` 의 `unity/Assets/Scripts` 를 직접 세어 적었다 (자체 실측). 파일명만 적는다 — 그 트리는 이 저장소에 없다. Godot 쪽은 `godot/` 현재 트리다. 상태는 셋만 쓴다.

- **완료** — 원본 기능이 Godot 에서 같은 규칙으로 돈다(테스트 있음)
- **부분** — 규칙이나 데이터 일부만 있다. 화면·연출·예외 처리가 빠졌다.
- **없음** — Godot 에 대응 코드가 없다.

우선순위는 "이게 없으면 다음 검증을 못 한다"를 기준으로 매겼다.

- **P0** — 게임 루프가 성립하지 않는다(소환·파티·전투 손맛 바닥)
- **P1** — 한 판을 끝까지 돌릴 수 없다(영지·스토리·전직·상성)
- **P2** — 있으면 좋지만 지금 게이트를 막지 않는다(3D 연출·오디오·AI 고도화)

## 1. 전투

| # | 기능 | Unity 근거 | Godot 현재 | 상태 | 우선순위 |
|---|---|---|---|---|---|
| 1 | 기본 공격 102종(직업 17 × 계열 6) | `CareerBasicAttacks.cs` | `core/basic_attacks.gd` — 데이터에서 표를 만들고 키워드 6종 배율 적용 | 완료 | — |
| 2 | 전투 상태 효과(치유·보호막·도발) | `BattleSystem.cs`·`BattleUnit.cs`·`PatternEffectResolver` | `core/status.gd` + `battle.gd` — 대상 선택(최저 HP·도발자·아군)·보호막 흡수·도발 만료 | 부분 | P1 |
| 3 | 나머지 상태(출혈·화상·빙결·기절·저주·재생) | 같은 곳 | 없음(치유·보호막·도발만) | 없음 | P1 |
| 4 | 전투 텔레그래프·패턴 예고 | `TelegraphEngine.cs`·`Battle/Patterns` | 없음 | 없음 | P2 |
| 5 | 타격감(히트스톱·셰이크·데미지 숫자) | `CombatFeel.cs`·`Fx` | 없음(숫자만 갱신) | 없음 | P2 |
| 6 | 실시간 이동 전투 | `BattleSystem.cs`(틱 이동·사거리) | 턴 기반 `core/battle.gd` | 없음 | P2 |
| 7 | 원소 상성·속성 판정 | `ElementalAffinity.cs`·`ElementalMatrix.cs`·`ElementalRoll.cs` | 데이터만 있고 전투 계산에 안 붙는다 | 없음 | P1 |
| 8 | 웨이브 생성·조우 | `WaveBuilder.cs`·`EncounterDirector` | `core/encounter.gd` — 온도·군집·면역 반영 | 완료 | — |

## 2. 영웅·성장

| # | 기능 | Unity 근거 | Godot 현재 | 상태 | 우선순위 |
|---|---|---|---|---|---|
| 9 | 소환 파이프라인(등급·종족·직업·특성) | `Summon.cs`·`HeroFactory.cs` | `core/gacha.gd` — 등급 확률·천장만. 종족·직업·특성 생성 없음 | 부분 | P0 |
| 10 | 영웅 로스터·장비·초월 | `HeroRecord.cs`·`Equipment`·`Transcendence` | 장비 합산(`equipment.gd`)은 있고 로스터·초월은 없다. 시작 파티가 고정 | 부분 | P0 |
| 11 | 전직·승급(직업 트리·계수) | `CareerPromotionEngine.cs`·`ProgressionData.cs` | `progression.gd` — 전직 단계 계수만 | 부분 | P1 |
| 12 | 파티 편성·영구사망·전당 부활 | `Party`·`Permadeath.cs`·`Hospital.cs` | `run_state.gd` — 사망 표시만, 편성·부활 없음 | 부분 | P0 |
| 13 | 스킬 각인·성장·발동 | `SkillDataModels.cs`·`AI` | `skill_book.gd`(각인·레벨·승격·열기) + `skill_effect.gd`(피해·속도 계열만). 방어·회복·효과 계열은 대기 | 부분 | P1 |

## 3. 영지·경제

| # | 기능 | Unity 근거 | Godot 현재 | 상태 | 우선순위 |
|---|---|---|---|---|---|
| 14 | 영지 격자 건설·시설 배치 | `EstateSystem.cs`·`EstateGrid.cs` | `estate.gd` — 날짜 진행만 | 부분 | P1 |
| 15 | 시설 수지·런 경제 | `RunEconomy.cs`·`EstateBank.cs` | 없음 | 없음 | P1 |
| 16 | 병원·공명·마나 은행 | `Hospital.cs`·`EstateBank.cs` | 없음 | 없음 | P2 |
| 17 | 탐험 블록 계약·배치 | `ExploreLayout.cs`·`PilotExplorationScene.cs` | `floor_run.gd` — 방 선택만 | 부분 | P1 |

## 4. 스토리·목표

| # | 기능 | Unity 근거 | Godot 현재 | 상태 | 우선순위 |
|---|---|---|---|---|---|
| 18 | 스토리 디렉터·사건 선택 | `StoryDirector.cs` | 없음 | 없음 | P1 |
| 19 | 미션·문지기·지역 목표 | `Core/MissionDirector`·`Gatekeeper` | `explore.gd` — 지역 목표만 | 부분 | P1 |
| 20 | 사슬 사냥 | `ChainHunt.cs` | 없음 | 없음 | P2 |
| 21 | 엔딩 게이트 | `EndingGate.cs` | 없음 | 없음 | P2 |

## 5. 시스템·표현

| # | 기능 | Unity 근거 | Godot 현재 | 상태 | 우선순위 |
|---|---|---|---|---|---|
| 22 | 저장·마이그레이션 | `SaveManager.cs`·`SaveMigration.cs` | `core/save.gd` + `autoload/save_manager.gd` — 슬롯 1개, 구버전 승계 | 완료 | — |
| 23 | UI 화면(타이틀·영지·도감·설정) | `UI/`·`GameRoot.UI` | 타이틀·전투 HUD·파티 패널만 | 부분 | P1 |
| 24 | 3D 표현(바이옴·실루엣·이펙트) | `Core/Visuals`·`ProceduralMesh.cs` | `view_3d.gd` 최소 배치 | 부분 | P2 |
| 25 | 오디오 | `Audio`·`SoundHooks` | 없음 | 없음 | P2 |
| 26 | AI 신경 정책·교사 게이트 | `NeuralPolicyRunner.cs`·`TeacherGateTelemetry.cs` | `brain.gd`·`fusion.gd` 휴리스틱만 | 부분 | P2 |
| 27 | 데이터 정본·게이트 | `ProgressionData.cs` | `data/*.json` + `tools/gate_all.py`(10종) | 완료 | — |

## 6. 권하는 순서

1. **P0 셋을 먼저** — 소환 파이프라인(9) → 로스터·장비(10) → 파티·영구사망(12). 셋이 붙어야 "한 판"이 생긴다. 지금은 고정 파티로 층만 오르므로 소환·성장 검증을 못 한다.
2. **P1 앞단** — 원소 상성(7)과 나머지 상태(3)는 전투 코드 한 곳(`battle.gd`)에서 끝난다. 영지(14·15)는 경제 수치가 등록소에 있어 데이터부터 넣는다.
3. **P1 뒷단** — 전직(11)·스킬(13)·스토리(18)·UI(23). 화면이 늘어나는 구간이라 한 화면씩 끊어 만든다.
4. **P2 는 미룬다** — 3D·오디오·신경 정책은 Godot 이 playable 해진 뒤에 판단한다. 지금 옮기면 손맛 검증 없이 코드만 늘어난다.

원본이 스스로 어긋나는 지점은 [GODOT_PORTING_MAP.md](GODOT_PORTING_MAP.md) 5절에 적혀 있다. 이 표는 그 결정을 다시 열지 않고 "무엇이 아직 없는가"만 센다.
