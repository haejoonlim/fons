# 폰즈 (FONS) — Godot 재구축

원본은 Unity 6 LTS + URP 3D 본편과 Vite/TS 웹 시뮬레이터로 만들던 게임이고,
그 원본 저장소는 `haejoonlim/soul-commander`(**비공개**)다 (원본 미검증).

이 저장소는 그 게임을 **Godot 4.7.2로 다시 만드는** 작업장이다.

- **가져오는 것**: 문서·설정(JSON)·시뮬레이터 숫자·검증 게이트 개념
- **다시 만드는 것**: 모든 에셋과 모든 코드 (Unity C#은 복사하지 않는다)

> **먼저 읽을 것: [HANDOFF.md](HANDOFF.md)** — 현재 상태, 막힌 지점, 다음 사람이 할 일.
> 이 README는 프로젝트 개요와 사용법만 다룬다.

## 지금 상태 (2026-10-16 실측)

| 항목 | 상태 | 근거 |
|---|---|---|
| 개발 환경 | 설치·검증 완료 | `./.venv/bin/python tools/check_env.py --strict` → exit 0 |
| Godot 프로젝트 | 임포트·기동 확인 | `godot --headless --import` → exit 0 |
| GUT 테스트 | 2 스크립트 / 6 테스트 / 6 통과 | `./tools/test_godot.sh` → exit 0 |
| Python 게이트 | 통과 | `./.venv/bin/python tools/gate_all.py` → exit 0 |
| 문서 검수 도구 | 동작 (검사 7종) | `./.venv/bin/python tools/review_docs.py` |
| 원본 문서 이관 | **차단** | 원본 저장소 비공개, 자격증명 없음 |
| 원본 문서 검수 | **불가** | 위와 같은 이유 — [docs/DOC_REVIEW.md](docs/DOC_REVIEW.md) |

## 개발 환경

Godot 4.7.2 + Blender 4.5.14 LTS + ffmpeg 9.0.2 + GUT 9.6.1 + Python venv가 이 머신에 설치돼 있다.
버전·경로·재설치 명령은 [SETUP.md](SETUP.md).

```bash
./.venv/bin/python tools/check_env.py --strict   # 툴체인 확인
./tools/test_godot.sh                            # Godot 임포트 + GUT 테스트
./.venv/bin/python tools/gate_all.py             # 문서 존재 + 가챠 숫자 게이트
./.venv/bin/python tools/review_docs.py          # 문서 기계 검수 (advisory)
```

**GUT를 직접 돌리지 말 것.** 새 클론에서 아래 명령을 그냥 실행하면 테스트를 하나도 돌리지 않고
`exit 0`으로 끝난다(침묵하는 거짓 통과). 반드시 `tools/test_godot.sh`를 쓴다.

```bash
# 금지 — 새 클론에서 거짓 통과가 난다
cd godot && godot --headless -s addons/gut/gut_cmdln.gd -gexit
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
    DOC_REVIEW.md     # 문서 검수 기록 (무엇을 검수했고 무엇이 불가한지)
    GODOT_PORTING_MAP.md  # 원본 TS/C# → GDScript 매핑표
  data/
    README.md         # JSON 이관 규칙 + 현재 상태
    manifest.json     # 이관 대상 파일 목록 (원본 미검증 추정 목록)
  sim/
    README.md         # 시뮬레이터 포팅 표 + 알려진 결함
    gacha.py          # W0 숫자 게이트 재현 (에셋 없음)
  godot/              # Godot 4.7.2 프로젝트 (여기가 게임 본체)
    project.godot
    .gutconfig.json
    scenes/title.tscn
    data/             # tools/sync_data.py가 채우는 런타임용 설정 (현재 비어 있음)
    scripts/autoload/ # game_state.gd, data_loader.gd
    scripts/sim/      # gacha.gd, combat.gd
    tests/            # test_gacha.gd, test_combat.gd
    addons/gut/       # GUT 9.6.1 (벤더링)
  tools/
    check_env.py      # 툴체인 닥터
    check_docs.py     # 필수 산출물 25종 존재 검사
    gate_all.py       # 문서 + 가챠 게이트
    sync_data.py      # 원본 JSON → data/ 복사
    review_docs.py    # 문서 기계 검수 (검사 7종, advisory)
    tracked_numbers.json  # 추적 상수 registry
    test_godot.sh     # Godot 임포트 + GUT (거짓 통과 방지)
```

## 원본에서 가져올 것 / 버릴 것

**가져올 것** (원본 미검증 — 실제 경로는 원본 트리와 대조 후 확정):
`design-docs/GDD_v8.0_*` GDD 일체, `fons-web-ver/PLAN.md`, `GAME_PLAN_3D.md`,
`unity/Assets/Resources/Data/*.json`(설정), 시뮬 코어 TS와 `verify_*.mjs` 게이트,
`unity/PORTING_MAP.md`, `loop/`의 인수인계 문서.

**버릴 것** (다시 만든다):
Unity의 `Assets/Art`, `Prefabs`, `Scenes`, `TextMesh Pro`, C# 스크립트 전부,
웹 표현층(Vite/TSX/CSS), macOS 런처, `.meta`와 `ProjectSettings/`.

자세한 처분표는 [MIGRATION_PLAN.md](MIGRATION_PLAN.md), 포팅 매핑은
[docs/GODOT_PORTING_MAP.md](docs/GODOT_PORTING_MAP.md).

## 렌더러 결정 (고정)

`gl_compatibility`(OpenGL)로 간다. 이 머신이 Intel macOS라 Forward+/Mobile이
MoltenVK를 거치고, Godot 4.7에서 검은 화면·Vulkan device loss 보고가 있는 경로를 피한다.
대가는 명확하다: SDFGI, VoxelGI, SSIL, SSR, 볼류메트릭 포그, 서브서피스 스캐터링,
데칼, DOF, 컴퓨트 셰이더, TAA/FSR2/FXAA/SMAA를 못 쓴다. SSAO와 MSAA 3D는 쓸 수 있다.
바꾸기 전에 [docs/DEV_PLAN.md](docs/DEV_PLAN.md) §4를 읽을 것.

## 작업 순서 (요약)

0. **Phase 0** — 원본 이관 (차단됨: 저장소 접근 필요)
1. **Phase 1** — 숫자 게이트 재현 (`sim/gacha.py`, 원본과 대조 필요)
2. **Phase 2** — Godot 시뮬 코어 포팅 (combat → summon → estate → party → tower)
3. **Phase 3** — 3D 최소 신 (title → estate3d → explore3d → monparts)
4. **Phase 4** — 게이트·CI·빌드
5. **Phase 5** — 수직 슬라이스

각 Phase의 완료 정의와 검증 명령은 [docs/DEV_PLAN.md](docs/DEV_PLAN.md) §5.

## 숫자에 대한 경고

이 저장소가 아직 말하는 `130`, `0.05`, `0.95`, `D-265`, `D-267`은 전부 **원본 미검증**이다.
이전 세션에서 원본 파일 일부를 보고 옮겨 적은 2차 인용이고, D-265/D-267의 정의문은 아무도 읽지 않았다.
원본을 확보하기 전까지 이 값들을 확정 수치로 인용하거나 밸런스 근거로 쓰면 안 된다.
