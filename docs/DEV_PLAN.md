# DEV PLAN — 폰즈 (FONS) Godot 재구축 개발 플랜

작성 2026-10-16. 엔진 Godot 4.7.2 stable. 원본은 비공개 레포 `haejoonlim/soul-commander` 안의 FONS (원본 미검증 — 레포 비공개로 내용 열람 불가).

---

## 1. 이 문서의 지위

이 문서는 **작업 순서와 검증 기준**을 정하는 문서다. 게임 내용의 기준 문서가 아니며, 내용의 기준은 원본 GDD다 (원본 미검증 — 열람 불가).

SSOT 우선순위 (위가 강함. 아래 1~4는 원본 저장소 `soul-commander`의 문서·데이터이고 현재 열람 불가 — 원본 미검증. 5만 이 저장소에 있다):

1. `design-docs/GDD_v8.0_00_확정사항.md` 및 `01~09, 99` (원본 GDD, 원본 미검증)
2. `fons-web-ver/PLAN.md` §6-2 (원본 검증 테이블, 원본 미검증)
3. `D-265`, `D-267` 등 원본 결정 기록 (원본 미검증)
4. `unity/Assets/Resources/Data/*.json` (설정 SSOT, 원본 미검증)
5. **이 문서** (`docs/DEV_PLAN.md`)

규칙:

- 이 문서와 원본이 충돌하면 **원본이 이긴다.** 이 문서를 근거로 원본 수치를 바꾸지 않는다.
- 이 문서에 적힌 원본 유래 수치는 **전부 2차 정보(손으로 옮겨 적은 메모)** 다. 원본 대조 전까지 `원본 미검증`으로 취급한다.
- 원본을 못 읽은 상태에서 게임 내용(스토리, 몬스터, 밸런스, 스킬 수치)을 **새로 만들어 넣지 않는다.**

---

## 2. 제품 정의

### 2.1 확인된 사실

| 항목 | 내용 | 출처 |
|---|---|---|
| 게임명 | FONS, 국문 표기 **폰즈** | 기존 문서 |
| 원본 스택 | Unity 6 LTS + URP Full 3D + Vite/TS/Three.js 웹 시뮬레이터 | 원본 레포 구조 |
| 원본 구조 | Unity 본편 + 웹 시뮬레이터 + macOS 런처(`fons-launcher`)가 한 레포 | 원본 레포 구조 |
| 이관 대상 | 문서(GDD·PLAN), 설정 JSON, 시뮬레이터 숫자 로직 | 확정 |
| 재제작 대상 | 모든 아트 에셋, Unity C# 전체, 웹 표현층, 씬/프리팹 | 확정 |
| 데이터 흐름 | Unity `Resources/Data/*.json` → (원본 `sync_web_data.py`) → 웹 시뮬 `public/data`. 폰즈에서는 `tools/sync_data.py`가 같은 역할 | 원본 스크립트 개념 |
| 시스템 이름(부분) | 가챠(summon), 전투(combat), 영지(estate), 파티(party), 탑(tower), 경제(economy), 3D(estate3d/explore3d/monparts) | 원본 소스 파일명 |

### 2.2 미확인 사항 (원본 GDD 확인 필요)

- 코어 루프의 정확한 순서와 상태 전이 규칙 (현재 `game_state.gd`의 `TITLE → SUMMON → COMBAT → RESULT → ESTATE → TOWER`는 파일명에서 유추한 **임시안**)
- 세계관·생태계 시스템의 실제 규칙 (`ecology_codex.json`, `ecology_energy_channels.json` 내용 미확인)
- 몬스터 수, 종족 수, 스킬 수, 장비 수, 직업 트리 깊이
- 원소 상성 매트릭스의 실제 값
- 세이브 포맷과 버전 관리 정책
- 목표 플랫폼/해상도/프레임 목표의 원본 확정값
- 출시 형태(스팀/itch 등)와 스코프

이 항목들은 **원본 확보 후 최우선으로 채운다.** 그 전까지 관련 코드는 스텁으로 두고, 스텁에 `원본 GDD 확인 필요` 주석을 남긴다.

---

## 3. 확정 수치·게이트 표

전부 2차 정보. 원본 대조는 Phase 0의 완료 조건이다.

| 수치 / 게이트 | 값 (2차 정보) | 출처 표기 | 검증 상태 |
|---|---|---|---|
| W0 가챠 뽑기 횟수 | 130 | PLAN.md §6-2 | 원본 미검증 |
| 가챠 shaped 확률 | 5% (기대값 130 × 0.05 = 6.5) | PLAN.md §6-2, D-265 | 원본 미검증 |
| legacy 커버리지 | 0.95 | D-265 | 원본 미검증 |
| D-267 데미지 공식 | `max(1, atk - defense) * crit_mult` | D-267 | 원본 미검증 |
| 원본 게이트 목록 | `verify_game.mjs` 22/22, `verify_w1~w4`, `verify_g0~g4`, `verify_g3scope`, `verify_direct`, `verify_battle`, `verify_assets`, `verify_fx`, `verify_monparts` | PLAN.md | 원본 미검증 |
| 영지 하위 기능 | S2 death, S3_2 status, S3_3 HUD, S3_4 pattern | 파일명 유추 | 원본 미검증 |
| 소환 하위 기능 | free / pity / lineage / multi, unlock / realpath / relations / reroll | 파일명 유추 | 원본 미검증 |

**오전사 위험 관리 (원본 미검증):** 위 수치는 한 번의 세션에서 손으로 옮긴 값이다. `D-265`, `D-267`이 무엇을 결정한 사안인지조차 아직 모른다. Phase 0에서 원문을 확보하는 즉시 §3 표 전체를 원문 인용으로 교체하고, 코드 상수(`sim/gacha.py`, `godot/scripts/sim/gacha.gd`, `godot/tests/test_gacha.gd`)를 한 커밋에서 함께 고친다.

---

## 4. 기술 결정과 근거

### 4.1 엔진

Godot **4.7.2 stable** (이 머신에 설치·검증 완료). Unity C#은 전부 버리고 GDScript로 재작성한다. Unity 프로젝트 파일(`ProjectSettings/`, `.meta`, Addressables)은 가져오지 않는다.

### 4.2 렌더러: Compatibility (`gl_compatibility`)

`godot/project.godot`에 이미 `renderer/rendering_method="gl_compatibility"`로 설정돼 있다. 유지한다.

근거: 이 머신은 macOS 12.7.6 / Intel x86_64 / i5-6500이다. macOS에는 네이티브 Vulkan이 없고 Godot의 Forward+·Mobile은 MoltenVK 경로를 탄다. Godot 4.7에서 Intel Mac + Forward+/Mobile 조합의 검은 창·Vulkan device loss 보고가 있으며, Compatibility는 RenderingDevice를 요구하지 않아 이 경로를 피한다. Godot 문서도 Compatibility를 구형 하드웨어용·최대 호환 옵션으로 설명한다.

**호환성 모드에서 잃는 것** (기획 시 전제로 삼는다):

- 없음: SDFGI, VoxelGI, SSIL, SSR, 볼류메트릭 포그, 서브서피스 스캐터링, 데칼, 피사계 심도(DOF), 컴퓨트 셰이더, TAA, FSR2, FXAA, SMAA
- 있음: SSAO, 글로우, 기본 depth/height 포그, 3D MSAA, SSAA, 베이크된 라이트맵 **렌더링**
- 주의: 라이트맵 **베이킹**은 RenderingDevice가 필요한 하드웨어를 요구한다. 이 Mac에서의 베이킹 가능 여부는 **미검증**이며 Phase 3 착수 시 실측한다.

### 4.3 성능 시작값 (가정이 아니라 측정 시작점)

| 설정 | 시작값 | 비고 |
|---|---|---|
| 3D 렌더 스케일 | 1.0 (1920×1080) | GPU 병목이 확인되면 0.85 → 0.75 순으로 내린다 |
| MSAA 3D | 2× | Compatibility에서는 이것과 SSAA만 선택 가능 |
| 그림자 | 그림자 캐스팅 라이트 최소, 그림자 맵 크기 축소 | 소형/원거리 라이트는 그림자 끔 |
| 조명 | 정적 지형은 베이크 우선 | 베이킹 가능성 미검증 |
| 재질/셰이더 | 재사용, 투명 오버드로 최소화, 원거리 LOD/컬링 | 드로우콜 병목이면 해상도보다 이쪽이 효과적 |

**목표 60fps @ 1080p는 목표이지 보장이 아니다.** Phase 3 종료 시 익스포트 빌드로 실측한다.

### 4.4 자산 파이프라인

- Blender 4.5.14 LTS에서 **glTF/`.glb` 익스포트**가 기본 경로다. `.blend` 직접 임포트는 Blender가 설치돼 있어야 동작하는 편의 경로이므로 CI·인수인계에서는 쓰지 않는다.
- 블렌더 소스 파일과 익스포트된 `.glb`의 정본은 어느 쪽인지 **리포 규칙으로 못박는다**(권장: `.blend`를 정본, `.glb`는 산출물로 커밋).
- 대용량 바이너리는 git-lfs(3.8.0, 설치 완료)로 추적한다. `.gitattributes`를 Phase 3 시작 전에 만든다.

### 4.5 테스트

- GUT(리포 내 `godot/addons/gut`, 벤더링된 버전 9.6.1) + `.gutconfig.json` (`dirs: ["res://tests"]`, `prefix: "test_"`, `suffix: ".gd"`, `should_exit: true`).
- 실행: **`./tools/test_godot.sh`** (임포트 → GUT → junit 검사). 이 스크립트는 테스트가 0건이면 실패로 종료한다.
- **금지:** `cd godot && godot --headless -s addons/gut/gut_cmdln.gd -gexit`를 단독으로 쓰지 않는다. `.godot` 임포트 캐시가 없는 새 사본에서는 테스트를 한 건도 실행하지 않고도 exit 0을 반환한다 — 거짓 통과다(부록 A #10).
- 파이썬 게이트: `./.venv/bin/python tools/gate_all.py`.

### 4.6 익스포트

- 프리셋 이름 `macOS`. 로컬 테스트는 Codesign **Built-in (ad-hoc only)**, Notarization **Disabled**로 충분하다. `rcedit`은 macOS에서 불필요하다.
- 번들 식별자는 실제 리버스 도메인으로 채운다(`application/bundle_identifier`).
- 명령: `godot --headless --path godot --export-release "macOS" build/FONS.app` — **출력 디렉터리가 미리 존재해야 한다.**

### 4.7 버전 관리 규칙

- `.uid` 사이드카 파일은 **커밋한다**(Godot 4.4+). 스크립트 이동 시 `.uid`도 같이 옮긴다.
- 엔진 업그레이드 후에는 **Project > Tools > Upgrade Project Files…** 를 실행한다(4.6부터 `.tscn`의 `load_steps` 미기록·노드 고유 ID 저장으로 포맷이 바뀌어 대량 diff가 생긴다).
- 빌드 산출물(`build/`), Godot 캐시(`.godot/`), JUnit 결과(`.gut_junit.xml`)는 커밋하지 않는다.

---

## 5. 마일스톤

규모는 작업량 밴드(S = 며칠, M = 1~2주, L = 2주 이상)이며, **날짜는 원본 GDD로 스코프가 확정된 뒤 산정**한다. 순서는 확정이다 — 뒤 단계는 앞 단계의 게이트를 통과해야 시작한다.

### Phase 0 — 원본 이관

- **목표:** 원본 문서·설정을 이 리포로 옮겨 §3의 미검증 수치를 전부 사실로 바꾼다.
- **작업:**
  1. 원본 레포 접근 확보 (§9 참조)
  2. `docs/gdd/`에 GDD 원문 복사 (수정 금지, 원문 그대로)
  3. `docs/web-plan/`에 `PLAN.md`, `GAME_PLAN_3D.md` 복사 (파일명·개수 원본 미검증)
  4. `tools/sync_data.py --src <원본>/unity/Assets/Resources/Data --dst data` 실행, 이어서 `--dst godot/data` (경로 원본 미검증 — 실제 트리 대조 후 실행)
  5. `data/manifest.json`을 **실제 원본 파일명과 대조해** 확정 (현재 목록은 추정이다)
  6. §3 수치 표를 원문 인용으로 교체
- **산출물:** `docs/gdd/*`, `docs/web-plan/*`, `data/*.json`, `godot/data/*.json`, 갱신된 `data/manifest.json`, 갱신된 `docs/DEV_PLAN.md` §3
- **완료 정의:** `./.venv/bin/python tools/check_docs.py` 통과 + `data/manifest.json`의 모든 파일이 `data/`에 존재 + §3 표에 `원본 미검증` 문구가 0건
- **선행 조건:** 없음 (지금 차단됨 — §9)
- **규모:** S (접근만 뚫리면 짧다)

### Phase 1 — 숫자 게이트 재현

- **목표:** 게임 규칙을 엔진 없이 파이썬으로 먼저 확정한다. 여기서 숫자가 틀리면 뒤가 전부 무의미하다.
- **작업:**
  1. `sim/gacha.py`를 원본 규칙에 맞게 재작성 (현재는 `random() < 0.05` 단순 구현)
  2. 원본 `verify_w1~w4`의 검증 조건을 파이썬 함수로 옮긴다
  3. 결정론적 난수(고정 시드)로 골든 테이블을 만들고 `sim/golden/`에 저장
  4. 코드 상수를 한 곳에서만 정의한다 (현재 `sim/gacha.py` 0.05 / `godot/scripts/sim/gacha.gd` 0.05 / `godot/tests/test_gacha.gd` 6.5로 3중 중복 → **단일 출처 위반, 수정 대상**)
- **산출물:** `sim/gacha.py`, `sim/verify_*.py`, `sim/golden/*.json`, `sim/README.md`
- **완료 정의:** `./.venv/bin/python sim/gacha.py` → `GATE OK`, `./.venv/bin/python tools/gate_all.py` → `GATE ALL OK`, 골든 테이블과 재실행 결과 일치
- **선행 조건:** Phase 0
- **규모:** M

### Phase 2 — Godot 시뮬 코어 포팅

- **목표:** 파이썬으로 확정한 숫자를 GDScript로 옮기고 GUT로 잠근다.
- **작업 순서 (의존 순):** `combat` → `summon`(가챠) → `estate` → `party` → `tower` → `economy` → `game_state`(상태머신)
  - 각 모듈은 `전역 상수 정의 → 순수 함수 → GUT 테스트` 순으로 만든다.
  - `data/*.json`을 읽는 부분은 `autoload/data_loader.gd`만 창구로 쓴다(직접 `FileAccess` 금지).
  - 상태머신은 원본 `game.ts`의 실제 전이를 확인한 뒤 확정한다 (§2.2)
- **산출물:** `godot/scripts/sim/*.gd`, 갱신된 `game_state.gd`, `godot/tests/test_*.gd`
- **완료 정의:** `./tools/test_godot.sh` → 전부 통과(비-0 종료 없음). **GUT 단독 실행의 exit 0은 증거로 인정하지 않는다**(부록 A #10). 파이썬 골든 테이블과 GDScript 결과 값 일치
- **선행 조건:** Phase 1
- **규모:** L

### Phase 3 — 3D 최소 신

- **목표:** 화면이 실제로 뜨고 60fps 목표가 측정 가능한 상태가 된다.
- **작업:**
  1. `title.tscn` — 자리표시자 생성 **완료(2026-10-16)**. Phase 3에서 정식 타이틀 화면으로 교체한다
  2. `world/estate_3d.gd` → `explore_3d.gd` → `monparts.gd` 순으로 최소 기능
  3. Blender에서 파일럿 에셋 1세트를 만들어 `.glb` 익스포트 → 임포트 경로 검증
  4. §4.3 성능 시작값으로 익스포트 빌드 실측
- **산출물:** `godot/scenes/*.tscn`, `godot/scripts/world/*.gd`, `godot/assets/`, `godot/export_presets.cfg`, `build/FONS.app`
- **완료 정의:** `godot --path godot --headless --import` exit 0, GUT 통과 유지, `build/FONS.app` 실행되어 타이틀 → 영지 화면까지 도달, 프레임 타임 실측치 기록
- **선행 조건:** Phase 2
- **규모:** L

### Phase 4 — 게이트·CI·빌드 자동화

- **목표:** 사람이 기억하지 않아도 검증이 돌아가게 만든다.
- **작업:**
  1. `tools/gate_all.py`에 GUT 호출을 포함시켜 단일 진입점으로 만든다
  2. `tools/check_docs.py`의 `REQUIRED` 목록 — **9개에서 25개로 확장 완료(2026-10-16)**. 남은 항목: `godot/export_presets.cfg`와 `.github/workflows/gate.yml`은 생성 시점에 추가한다
  3. GitHub Actions: `chickensoft-games/setup-godot@v2` + `godot --headless --editor --path godot --import --quit` + GUT. 파이프로 출력을 거를 때는 `set -o pipefail`로 Godot의 실패 종료 코드가 묻히지 않게 한다
  4. `tools/review_docs.py`를 **자문 단계로** 돌려 리포트를 남긴다. **하드 게이트로 연결하지 않는다** — 원본 대조 전에는 지적 대부분이 "원본 미검증 2차 정보"라서 항상 빨간불이 되고, 그러면 게이트를 끄거나 검사기를 약화시키게 된다. 승격은 원본 대조 후 `UNVERIFIED_CLAIM` 0건이 된 뒤에만 검토한다 (§7)
- **산출물:** `.github/workflows/gate.yml`, 갱신된 `tools/*`, `docs/gdd`/`data` 정합성 리포트
- **완료 정의:** CI에서 docs 게이트 + 파이썬 게이트 + `./tools/test_godot.sh`가 모두 통과하고, 일부러 깨뜨린 테스트에서 CI가 **실패**하는 것을 확인. `review_docs.py`는 자문 리포트로만 첨부하며 CI 실패 조건에 넣지 않는다
- **선행 조건:** Phase 3
- **규모:** M

### Phase 5 — 수직 슬라이스

- **목표:** 코어 루프 한 바퀴가 세이브/로드를 포함해 끊김 없이 돈다.
- **작업:**
  1. 타이틀 → 소환 1회 → 파티 편성 → 전투 1회 → 결과 → 영지 진입 → 저장 → 재실행 → 이어하기
  2. `autoload/save_manager.gd` 신규 작성, 세이브 스키마 버전 필드 포함
  3. 슬라이스 전용 원본 게이트(`verify_game` 대응)를 GUT로 이식
- **산출물:** 세이브/로드 구현, 슬라이스 시나리오 테스트, 플레이 가능한 `build/FONS.app`
- **완료 정의:** 세이브 → 재실행 → 이어하기가 데이터 손실 없이 동작, GUT 슬라이스 테스트 통과, 실측 프레임 기록 유지
- **선행 조건:** Phase 4
- **규모:** L

---

## 6. 작업 분해(WBS) 요약

| ID | 작업 | Phase | 선행 | 산출물 | 규모 |
|---|---|---|---|---|---|
| P0-1 | 원본 레포 접근 확보 | 0 | — | 접근 수단 | S |
| P0-2 | GDD 원문 이관 | 0 | P0-1 | `docs/gdd/*` | S |
| P0-3 | PLAN/3D 플랜 이관 | 0 | P0-1 | `docs/web-plan/*` | S |
| P0-4 | 설정 JSON 이관 + manifest 확정 | 0 | P0-1 | `data/*.json` | S |
| P0-5 | §3 수치표 원문 대조 교체 | 0 | P0-2 | 갱신된 DEV_PLAN | S |
| P1-1 | 가챠 파이썬 재작성 | 1 | P0-4 | `sim/gacha.py` | M |
| P1-2 | W1~W4 검증 이식 | 1 | P1-1 | `sim/verify_*.py` | M |
| P1-3 | 골든 테이블 생성 | 1 | P1-2 | `sim/golden/*.json` | S |
| P1-4 | 상수 중복 정리(대상 파일 미정 — 원본 대조 후 값 확정) | 1 | P1-1 | `data/game_const.json` (예정, 아직 없음) | S |
| P2-1 | combat.gd + GUT (경로: `godot/scripts/sim/combat.gd`) | 2 | P1-4 | `godot/scripts/sim/combat.gd` | M |
| P2-2 | summon.gd + GUT | 2 | P2-1 | `godot/scripts/sim/summon.gd` | L |
| P2-3 | estate.gd + GUT | 2 | P2-2 | `godot/scripts/sim/estate.gd` | L |
| P2-4 | party/tower/economy | 2 | P2-3 | `godot/scripts/sim/{party,tower,economy}.gd` | M |
| P2-5 | 상태머신 확정 | 2 | P0-2 | `game_state.gd` | M |
| P3-1 | title.tscn 정식 교체 | 3 | P2-5 | `godot/scenes/title.tscn` | S |
| P3-2 | estate_3d 최소신 | 3 | P3-1 | `godot/scripts/world/estate_3d.gd` | L |
| P3-3 | explore_3d 최소신 | 3 | P3-2 | `godot/scripts/world/explore_3d.gd` | L |
| P3-4 | monparts 최소신 | 3 | P3-3 | `godot/scripts/world/monparts.gd` | M |
| P3-5 | 파일럿 에셋 + glTF 파이프라인 | 3 | P3-1 | `assets/*.glb` | M |
| P3-6 | 성능 실측 | 3 | P3-4 | 측정 리포트 | S |
| P4-1 | gate_all에 GUT 통합 | 4 | P2 | `tools/gate_all.py` | S |
| P4-2 | check_docs 목록 갱신 | 4 | P0 | `tools/check_docs.py` | S |
| P4-3 | GitHub Actions | 4 | P4-1 | `.github/workflows/gate.yml` | M |
| P4-4 | 문서 검수 자동화 연결 (자문 리포트 — 하드 게이트 아님) | 4 | P4-2 | `tools/review_docs.py`, `tools/gate_all.py` | M |
| P5-1 | 저장/불러오기 | 5 | P3 | `godot/scripts/autoload/save_manager.gd` | L |
| P5-2 | 수직 슬라이스 시나리오 | 5 | P5-1 | 테스트 + 빌드 | L |

---

## 7. 검증 전략

원칙: **명령을 실행해서 종료 코드가 0인 것만 통과로 인정한다.** 파일이 존재한다는 것, 빌드가 됐다는 것은 요청된 동작이 동작한다는 증거가 아니다.

| 검증 명령 | 무엇을 증명하는가 | 통과 기준 |
|---|---|---|
| `./.venv/bin/python tools/check_env.py --strict` | 툴체인이 이 머신에 있다 | exit 0 |
| `./.venv/bin/python tools/check_docs.py` | 필수 문서·스크립트 골격이 있다 | exit 0 |
| `./.venv/bin/python sim/gacha.py` | 가챠 수치 게이트 재현 | `GATE OK` 출력 + exit 0 |
| `./.venv/bin/python tools/gate_all.py` | docs + sim 통합 게이트 | `GATE ALL OK` + exit 0 |
| `./tools/test_godot.sh` (임포트 → GUT → junit 검사) | GDScript 시뮬 코어의 동작 | 전부 통과 + exit 0. **GUT 단독 실행의 exit 0은 증거가 아니다** — 임포트 캐시가 없으면 테스트 0건으로도 0을 반환한다 |
| `godot --path godot --headless --import` | 스크립트가 파싱되고 리소스가 임포트된다 | exit 0, 에러 0건 |
| `mkdir -p build && godot --headless --path godot --export-release "macOS" build/FONS.app` | 실제 실행 파일이 만들어진다 | `build/FONS.app` 생성 |
| `./.venv/bin/python tools/review_docs.py` | 리포 문서 간 수치·경로 모순이 없다 (**자문 검수 — 하드 게이트 아님. `tools/gate_all.py`에 연결하지 않는다**) | 목표: 지적 0건 + exit 0. 현 단계에서 지적은 곧 "원본 미검증 2차 정보" 목록이므로 **0건이 아니어도 실패로 취급하지 않는다**. 원본 대조 후 0건이 되면 그때 하드 게이트로 승격한다 |
| (수동) 익스포트 빌드 실행 + 프레임 측정 | 성능 목표 달성 | 측정값 기록 (목표 60fps) |

주의: `godot ... | tee` 처럼 출력을 파이프로 거르면 Godot의 실패 종료 코드가 묻힌다. 반드시 `set -o pipefail` 또는 종료 코드 별도 캡처를 쓴다.

---

## 8. 리스크 등록부

| 리스크 | 영향 | 완화 | 조기 경보 신호 |
|---|---|---|---|
| 원본 문서 접근 불가 (비공개 레포) | Phase 0~5 전부 정지. 수치·기획을 확정할 수 없다 | GitHub 연동 또는 로컬 clone 확보 (§9). 그 전까지는 원본 비의존 작업(파이프라인·툴링)만 진행 | `docs/gdd/`가 비어 있음 |
| Intel macOS 렌더러 불확실성 | 검은 창·디바이스 로스로 개발 자체가 막힘 | Compatibility 고정. Forward+/Mobile은 쓰지 않는다 | 3D 신 첫 실행 시 창이 검게 뜸 |
| 3D 성능 미검증 | 목표 프레임 미달 시 기획 축소 필요 | §4.3 시작값 + Phase 3에서 실측. 해상도가 아니라 드로우콜·그림자를 먼저 본다 | 프로파일러에서 그림자/오버드로 우세 |
| 수치 오전사 | 게임 규칙이 원본과 달라져 밸런스 전면 재작업 | Phase 0에서 §3 표를 원문 인용으로 교체, 코드 상수와 한 커밋에서 동기화 | 원본과 대조 시 5%·130·0.95 중 하나라도 다름 |
| 상수 3중 중복 | 한 곳만 고쳐서 게임/테스트가 서로 다른 값을 신뢰 | P1-4에서 `sim/gacha.py`·`godot/scripts/sim/gacha.gd`·`godot/tests/test_gacha.gd`의 중복 상수를 한 출처로 통합, 리뷰 게이트로 드리프트 감지 | `review_docs.py`의 CONST_DRIFT 지적 |
| 자산 재제작 비용 | 일정 초과 | Phase 3에서 파일럿 1세트로 파이프라인만 확정. 양산은 스코프 확정 후 | 에셋 1개 제작에 예상의 2배 이상 소요 |
| 라이트맵 베이킹 불가 (Compatibility + Intel) | 조명 품질 저하 | 베이킹 불가 시 실시간 라이트 수를 하드 리밋으로 관리 | 베이킹 시도 시 RenderingDevice 관련 에러 |
| `.tscn`/엔진 버전 업그레이드 대량 diff | 리뷰 불가·머지 사고 | 엔진 버전 고정(4.7.2), 업그레이드는 전용 커밋 + Upgrade Project Files | 커밋에 무관한 씬 파일 수백 개 변경 |

---

## 9. 차단 사항과 해소 방법

**현재 차단: 원본 문서·설정 전체에 접근할 수 없다.**

- `haejoonlim/soul-commander`는 **비공개** 레포다. 비인증 GitHub API 조회는 404를 반환한다. 그 결과 원본 문서 내용은 이 머신에서 원본 미검증 상태다.
- 이 머신에는 `gh` CLI가 없고, GitHub 자격증명·`.netrc`·키체인 항목도 없다.
- 로컬 디스크(Desktop·Documents·Downloads·iCloud)와 Spotlight 전체 검색에서 GDD/원본 프로젝트 사본은 발견되지 않았다.
- 이전 세션에서 GitHub 연동 도구로 읽은 것은 **디렉터리 목록 수준**이며, GDD 본문·`PLAN.md` 본문·JSON 내용은 어디에도 저장돼 있지 않다.

해소 경로 (택 1):

1. Freebuff GitHub 연동을 연결한 뒤, 에이전트가 원본 파일을 직접 읽고 이관한다 (권장)
2. 이 머신에 원본을 clone한다:
   ```bash
   git clone https://github.com/haejoonlim/soul-commander.git ~/soul-commander
   ```
   그 뒤 `tools/sync_data.py --src ~/soul-commander/unity/Assets/Resources/Data --dst data`
3. 원본 문서 파일만이라도 이 리포 `docs/gdd/`에 직접 붙여 넣는다

신규 원격 레포 생성도 같은 차단에 걸린다(현재 `gh` 없음). 원격 생성 명령은 `MIGRATION_PLAN.md`에 정리돼 있다.

---

## 10. 다음 액션

### 지금 당장 (원본 없이 가능한 것)

1. ~~메인 신 부재~~ — **완료(2026-10-16):** `godot/scenes/title.tscn` 자리표시자 생성 (부록 A #1)
2. ~~`check_docs.py` 목록 갱신~~ — **완료(2026-10-16):** 25개 항목으로 확장 (부록 A #7)
3. ~~상수 단일 출처 정리~~ — **의도적 보류:** 원본 대조(Phase 0) 전에 통합하면 원본 미검증 숫자를 확정 상수로 굳힌다. 순서를 지킨다 — ① 원본 대조 → ② 값 확정 → ③ 통합(`tools/tracked_numbers.json`을 추적 상수의 단일 출처로 삼는다). Phase 1-4로 미룬다 (§3, 부록 A #3)
4. ~~`.gitignore`에 `build/` 추가~~ — **완료(2026-10-16):** `build/`·`*.app/`·`*.dmg` 추가. 남은 확인: `.uid`·`export_presets.cfg`가 무시되지 않는지 (부록 A #9)
5. ~~`tools/review_docs.py` 게이트 연결~~ — **결정 변경:** 하드 게이트로 연결하지 않는다. 자문 도구로 돌리되, 원본 대조 후 지적 0건이 되면 승격을 검토한다 (§7)
6. `.gitattributes` 작성 (git-lfs 대비)

### 원본 확보 직후

1. Phase 0 전체 실행 — GDD·PLAN·JSON 이관, `manifest.json` 실제 파일명 대조
2. §3 수치표를 원문 인용으로 교체하고, 코드 상수를 같은 커밋에서 동기화
3. §2.2 미확인 항목을 채워 코어 루프와 상태 전이 확정
4. 원본 게이트(`verify_game` 22/22 등)를 실제로 실행해 현재 리포의 파이썬/GDScript 대응물과 1:1 매핑표 확정
5. 스코프 확정 후 Phase별 날짜 산정 (이 문서 §5에 반영)

---

## 부록 A — 즉시 수정 대상으로 확인된 결함

이번 검수에서 **실물 파일을 읽고** 확인한, 현재 리포 자체의 결함이다. 원본 문서와 무관하게 지금 고칠 수 있다.

| # | 위치 | 결함 | 수정 |
|---|---|---|---|
| 1 | `godot/project.godot` | `run/main_scene="res://scenes/title.tscn"`인데 `godot/scenes/` 디렉터리와 `title.tscn`이 없다. 실행하면 메인 신 로드 실패 | **수정 완료(2026-10-16):** 자리표시자 `title.tscn` 생성. 정식 교체는 Phase 3-1 |
| 2 | `godot/project.godot` | `godot/data/`를 `DataLoader`가 읽도록 설계돼 있으나, 디렉터리 자체가 없다(`sync_data.py` 미실행 상태) | **수정 완료(2026-10-16):** `godot/data/README.md` 생성(자리표시자 겸 규칙 문서). JSON 내용은 Phase 0-4 후 |
| 3 | `sim/gacha.py`(130/0.05/0.95), `godot/scripts/sim/gacha.gd`(`PULLS`/`SHAPED_BONUS`/`LEGACY_COVERAGE`), `godot/tests/test_gacha.gd`(130/6.5/0.05/0.95) | 같은 상수가 3곳에 중복 정의. 한 곳만 고치면 게임과 테스트가 다른 값을 신뢰 | **의도적 보류(2026-10-16):** 순서를 강제한다 — ① 원본 대조 → ② 값 확정 → ③ 단일 출처화. Phase 1-4에서 통합 |
| 4 | `docs/GODOT_PORTING_MAP.md` | 제목이 리포명 확정 전 표기(`fons`)로 남아 있었다 | **수정 완료(2026-10-16):** `폰즈`로 통일 |
| 5 | `README.md` | "새 레포 구조" 예시가 `fons/`로 적혀 있고 디렉터리명은 `폰즈` — 문서와 실제 경로 불일치 | **수정(2026-10-16, coordinator)** — 이 플랜 작성자는 그 파일을 직접 확인하지 못했다(미검증) |
| 6 | `data/manifest.json` | 원본 대조 전 추정 목록이며 `notes`에도 그렇게 적혀 있다. `game_const.json`, `races.json` 등 실재 여부 미확인 | Phase 0-4에서 확정 |
| 7 | `tools/check_docs.py` | `REQUIRED`에 `SETUP.md`, `docs/DEV_PLAN.md`, `godot/export_presets.cfg` 등이 빠져 게이트가 실제 골격을 다 보지 못한다 | **수정 완료(2026-10-16):** 9개 → 25개 항목. `export_presets.cfg`는 Phase 3에서 생성 시 추가 |
| 8 | `sim/gacha.py` | `random.Random(265)` 시드 기반 단순 구현이라 원본 가챠 규칙(천장·계보·다중 뽑기)과 무관. 게이트가 통과해도 아무것도 증명하지 못한다 | Phase 1-1에서 원본 규칙으로 재작성 |
| 9 | `.gitignore` | `build/`(익스포트 산출물) 제외 규칙이 없다. 반대로 `.uid`·`export_presets.cfg`는 커밋돼야 하는데 명시가 없다 | **수정 완료(2026-10-16):** `build/`·`*.app/`·`*.dmg` 추가. `.uid`·`export_presets.cfg`는 무시되지 않음을 유지 |
| 10 | `godot/addons/gut` 실행 경로 | `.godot` 임포트 캐시가 없는 새 사본에서 GUT 단독 실행은 테스트를 **0건 돌리고도 exit 0**을 반환한다(침묵하는 거짓 통과). 이전 세션이 보고한 "6 tests passing"은 전달된 파일만으로 재현되지 않았다 | **수정 완료(2026-10-16):** `tools/test_godot.sh`로 임포트 → GUT → junit(테스트 0건이면 실패) 순서를 고정. GUT 단독 실행 금지 |
