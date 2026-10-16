# 폰즈 (FONS) — Godot 재구축

원본은 Unity 6 LTS + URP 3D 본편과 Vite/TS 웹 시뮬레이터로 만들던 게임이고,
그 원본 저장소 `haejoonlim/soul-commander` 를 **2026-10-17에 클론해서 읽었다** (원본 대조).
이 저장소는 그 게임을 **Godot 4.7.2로 다시 만드는** 작업장이다.

- **가져오는 것**: 정본 문서의 규칙·수치, 런타임 데이터 JSON, 검증 게이트 개념
- **다시 만드는 것**: 모든 에셋과 모든 코드 (Unity C#은 복사하지 않는다)

> **먼저 읽을 것: [HANDOFF.md](HANDOFF.md)** — 현재 상태, 함정, 다음 사람이 할 일.
> 원본에서 확인한 값은 [docs/original/00_읽는법.md](docs/original/00_읽는법.md) 에 모아 두었다. 이 README는 개요와 사용법만 다룬다.

## 지금 상태 (2026-10-17 자체 실측)

| 항목 | 상태 | 근거 |
|---|---|---|
| 개발 환경 | 설치·검증 완료 | `./.venv/bin/python tools/check_env.py --strict` → exit 0 |
| Godot 프로젝트 | 임포트·기동 확인 | `godot --headless --import` → exit 0 |
| GUT 테스트 | 2 스크립트 / 8 테스트 / 8 통과 / 25 단언 (자체 실측) | `./tools/test_godot.sh` → exit 0 |
| 소환 숫자 게이트 | 통과 — 원본 확정 확률표 재현 (자체 실측) | `./.venv/bin/python sim/gacha.py` → exit 0 |
| Python 게이트 | 통과 · 필수 산출물 29종 (자체 실측) | `./.venv/bin/python tools/gate_all.py` → exit 0 |
| 문서 검수 도구 | 동작 (검사 7종, advisory) | `./.venv/bin/python tools/review_docs.py` |
| 원본 클론·대조 | 완료 — `~/soul-commander` (자체 실측) | 원본에서 확인한 값은 [docs/original/](docs/original/00_읽는법.md) 4종에 있다 |
| 런타임 데이터 이관 | 완료 — 17종 × 2 (data/ · godot/data/) (자체 실측) | `tools/sync_data.py` |
| 3D 월드 | 없음 — 타이틀 자리표시자뿐 | `godot/scenes/title.tscn` |

**되는 것**: Godot 프로젝트가 열리고, GUT 8개가 통과하고, 숫자 게이트가 원본 값으로 돈다.
**안 되는 것**: 게임을 플레이할 수 없다. 데이터 17종은 들어왔지만 시뮬 코어 포팅이 아직 안 됐다 (자체 실측).

## 개발 환경

Godot 4.7.2 + Blender 4.5.14 LTS + ffmpeg 9.0.2 + GUT 9.6.1 + Python venv가 이 머신에 설치돼 있다.
버전·경로·재설치 명령은 [SETUP.md](SETUP.md).

```bash
./.venv/bin/python tools/check_env.py --strict   # 툴체인 확인
./tools/test_godot.sh                            # Godot 임포트 + GUT 테스트
./.venv/bin/python sim/gacha.py                  # 소환 규칙 게이트 (원본 확정값 재현)
./.venv/bin/python tools/gate_all.py             # 문서 존재 + 소환 숫자 게이트
./.venv/bin/python tools/review_docs.py          # 문서 기계 검수 (advisory — 게이트 아님)
```

`tools/review_docs.py` 는 **advisory**다. 지적이 0이 아니어도 빌드 실패가 아니다 — 판단이 섞인 권고가 있기 때문이다.
숫자 주장의 출처 표시(`(원본 대조)`·`(자체 실측)`·`(원본 미검증)`)는 이 검사기가 강제한다.

**GUT를 직접 돌리지 말 것.** 새 클론에서 아래 명령을 그냥 실행하면 테스트를 하나도 돌리지 않고
`exit 0`으로 끝난다(침묵하는 거짓 통과). 반드시 `tools/test_godot.sh`를 쓴다.

```bash
# 금지 — 새 클론에서 거짓 통과가 난다
cd godot && godot --headless -s addons/gut/gut_cmdln.gd -gexit
```

데이터를 옮길 때는 `tools/sync_data.py` 를 쓴다. manifest에 있는 파일이 원본에 하나라도 없으면
**실패(exit 1)** 한다 — 조용히 건너뛰면 데이터가 빠진 채 게이트가 통과하기 때문이다.
일부만 확인하려면 `--allow-missing` 을 명시한다.

```bash
./.venv/bin/python tools/sync_data.py --src ~/soul-commander/unity/Assets/Resources/Data --dst data
```

## 폴더 구조

```
폰즈/
  README.md
  HANDOFF.md          # 인수인계문서 (먼저 읽기)
  SETUP.md            # 툴체인 설치·재현
  MIGRATION_PLAN.md   # 원본 → 이 저장소 이관 계획·처분표
  docs/
    DEV_PLAN.md       # 게임 개발 플랜 (Phase 0~5, WBS, 게이트, 리스크)
    DOC_REVIEW.md     # 문서 검수 기록
    GODOT_PORTING_MAP.md  # 원본 TS/C# → GDScript 매핑표
    original/         # 원본을 읽고 확인한 값의 대조 자료 (여기가 값의 근거다)
      00_읽는법.md
      01_확정_규칙.md
      02_웹버전_포팅.md
      03_데이터_영지_탑.md
  data/
    README.md         # JSON 이관 규칙 + 현재 상태
    manifest.json     # 이관 대상 파일 목록 (원본과 전수 대조 완료)
  sim/
    README.md         # 소환 규칙 게이트 설명 + 다음 작업
    gacha.py          # 소환 게이트 — 원본 확정 규칙 재현 (에셋 없음)
  godot/              # Godot 4.7.2 프로젝트 (여기가 게임 본체)
    project.godot
    .gutconfig.json
    scenes/title.tscn
    data/             # tools/sync_data.py가 채우는 런타임용 설정 (현재 README뿐)
    scripts/autoload/ # game_state.gd, data_loader.gd
    scripts/sim/      # gacha.gd, combat.gd
    tests/            # test_gacha.gd, test_combat.gd
    addons/gut/       # GUT 9.6.1 (벤더링)
  tools/
    check_env.py      # 툴체인 닥터
    check_docs.py     # 필수 산출물 29종 존재 검사
    gate_all.py       # 문서 + 소환 게이트
    sync_data.py      # 원본 JSON → data/ 복사 (없는 파일이면 실패)
    review_docs.py    # 문서 기계 검수 (검사 7종, advisory)
    tracked_numbers.json  # 추적 상수 registry (v2 — 원본 대조 확정값)
    test_godot.sh     # Godot 임포트 + GUT (거짓 통과 방지)
```

## 원본에서 가져올 것 / 버릴 것

**가져올 것** (경로와 존재를 원본에서 확인했다 — 원본 대조):
정본 문서 `design-docs/GDD_v8.0_*` · 개발 기준 `design-docs/GDD_v8.0_03_개발플랜.md` ·
결정 로그 `design-docs/결정로그/` · 런타임 데이터 `unity/Assets/Resources/Data/*.json` 17종 (원본 대조) ·
웹 시뮬 코어 `fons-web-ver/app/src/` TS와 `fons-web-ver/verify_*.mjs` 15종 (원본 대조) ·
`unity/PORTING_MAP.md` 의 매핑 개념 · 루트 인수인계 문서.

**버릴 것** (다시 만든다):
Unity의 `Assets/Art`, `Prefabs`, `Scenes`, `TextMesh Pro`, C# 스크립트 전부,
웹 표현층(Vite/TSX/CSS), macOS 런처, `.meta`와 `ProjectSettings/`.
구 Godot 문서 `design-docs/archive/`(v7.12)와 `godot-ver.zip` 은 원본 저장소에도 없다 (원본 대조).

자세한 처분표는 [MIGRATION_PLAN.md](MIGRATION_PLAN.md), 포팅 매핑은
[docs/GODOT_PORTING_MAP.md](docs/GODOT_PORTING_MAP.md).

## 확정 수치와 출처

이전 판에 적혀 있던 `PULLS = 130`("W0 게이트 = 130회 소환")과 `expected_shaped = 6.5` 는 **원본에 없는 값이었다**.
원본의 130은 탑 130층 · 티켓 130마석 · `LEVEL_CAP` 130 · `MP_PER_CRYSTAL` 130 · ★4 하드 천장 130회다 (원본 대조).
D-265 도 소환 게이트가 아니라 층 미션 시스템이다. 값과 출처는 [docs/original/01_확정_규칙.md](docs/original/01_확정_규칙.md) 에 있다.

| 상수 | 값 | 출처 |
|---|---|---|
| `SHAPED_RATE` | 0.05 | 확정 #11 · D-276 (원본 대조) |
| `LEGACY_RATE` | 0.95 | 확정 #11 · D-276 (원본 대조) |
| `LEGACY_SPECIES` | 20 | 확정 #11 · D-276 (원본 대조) |
| `TICKET_COST` | 130 | 확정 #16 (원본 대조) |
| `SOFT_PITY_START` | 70 | 확정 #32 (원본 대조) |
| `SOFT_PITY_STEP` | 0.02 | 확정 #32 (원본 대조) |
| `HARD_PITY_4` | 130 | 확정 #32 (원본 대조) |
| `LEY_PER_CRYSTAL` | 60 | D-267 (원본 대조) |
| `MP_PER_CRYSTAL` | 130 | D-267 (원본 대조) |
| `LEVEL_CAP` | 130 | 확정 #34 (원본 대조) |

이 값들은 이제 밸런스 근거로 쓸 수 있다. 다만 원본이 스스로 어긋나는 항목은 양쪽을 병기해 두었다 —
[docs/GODOT_PORTING_MAP.md](docs/GODOT_PORTING_MAP.md) §5.

## 렌더러 결정 (고정)

`gl_compatibility`(OpenGL)로 간다. 이 머신이 Intel macOS라 Forward+/Mobile이
MoltenVK를 거치고, Godot 4.7에서 검은 화면·Vulkan device loss 보고가 있는 경로를 피한다.
대가는 명확하다: SDFGI, VoxelGI, SSIL, SSR, 볼류메트릭 포그, 서브서피스 스캐터링,
데칼, DOF, 컴퓨트 셰이더, TAA/FSR2/FXAA/SMAA를 못 쓴다. SSAO와 MSAA 3D는 쓸 수 있다.
바꾸기 전에 [docs/DEV_PLAN.md](docs/DEV_PLAN.md) §4를 읽을 것.

## 작업 순서 (요약)

0. **Phase 0** — 원본 이관 (원본이 확보됐다. `tools/sync_data.py` 로 JSON 17종을 옮긴다)
1. **Phase 1** — 소환 숫자 게이트 재현 (완료 — `sim/gacha.py` 가 확정 #32·#11 을 재현한다)
2. **Phase 2** — Godot 시뮬 코어 포팅 (combat → summon → estate → party → tower)
3. **Phase 3** — 3D 최소 신 (title → estate3d → explore3d → monparts)
4. **Phase 4** — 게이트·CI·빌드
5. **Phase 5** — 수직 슬라이스

각 Phase의 완료 정의와 검증 명령은 [docs/DEV_PLAN.md](docs/DEV_PLAN.md) §5.
