# Migration Plan — soul-commander/FONS → 폰즈

> **접근 상태 (2026-10-16): 원본을 읽을 수 없다.**
> `haejoonlim/soul-commander`는 **비공개 레포**이고 이 머신에는 GitHub 자격증명도 `gh` CLI도 없다(계정 공개 레포 3개에 `soul-commander` 없음, `git ls-remote` 인증 실패, 로컬 클론 없음 — 이 진단은 실측이고, 원본 내용은 열람 불가로 원본 미검증).
> 따라서 이 문서의 원본 경로·파일명·개수는 전부 **2차 정보(원본 미검증)** 이며, 이전 세션의 디렉터리 열람 기록에서 온 것이다. 내용을 읽고 확인한 것이 아니다.
> 첫 작업은 원본에 접근한 뒤 **아래 인벤토리를 실제 트리와 대조(diff)하는 것**이다. 대조 전에는 어떤 파일도 "있을 것"으로 가정하고 이관하지 않는다.

## 0. 원칙

- 에셋·Unity C#은 **다시 만든다**. 이 레포에 복사하지 않는다.
- 문서·설정(JSON)·시뮬레이터 숫자만 남긴다.
- JSON은 SSOT. 손으로 고치지 않고 원본에서 `tools/sync_data.py`로 가져온다.
- 수치는 `PLAN.md §6-2` + `GDD_v8.0_00` + `D-265/D-267`을 SSOT로 삼는다. (원본 미검증 — 문서 ID 체계만 이전 세션에서 확인)
- 웹 표현층(Vite/TSX/CSS)은 버리고, 시뮬 코어만 GDScript로 포팅한다.

## 1. 원본 인벤토리 (원본 미검증 — 열람 기록 기반, 대조 필요)

| 원본 경로 | 내용 | 처분 |
|---|---|---|
| `design-docs/GDD_v8.0_00~09, 99` | GDD SSOT (원본 미검증) | `docs/gdd/`로 복사, 수정금지 |
| `design-docs/README.md`, `AGENTS.md`, `_tools/` | 게이트/작업규칙 | 개념만 `tools/`로 승계 |
| `fons-web-ver/PLAN.md`, `GAME_PLAN_3D.md` | W0~W4, G0~G4 플랜, 검증표 | `docs/web-plan/` 복사 |
| `fons-web-ver/docs/ASSETS_P0.md`, `PLAYTEST_G4.md` | 에셋 기준, 플레이테스트 결과 | `docs/` 복사 (에셋 자체는 버림) |
| `fons-web-ver/app/src/*.ts` (game/combat/summon/party/estate/tower/economy) | 시뮬 코어 | `godot/scripts/sim/*.gd`로 포팅 |
| `fons-web-ver/app/src/game3d/*` | 3D 상태/신 개념 | `godot/scripts/world/*.gd`로 포팅 |
| `fons-web-ver/verify_*.mjs` (20개 — **개수 미검증**) | 숫자 게이트 | `godot/tests/*.gd` + `tools/gate_all.py`로 포팅 |
| `unity/Assets/Resources/Data/*.json` | 설정 SSOT 15종+ (**개수 미검증**) | `data/`로 복사 (`.meta` 제외) |
| `unity/Assets/Scripts/**` C# | 전부 | 버림, GDScript 재작성 |
| `unity/Assets/Art`, `Prefabs`, `Scenes` | 에셋 | 버림 |
| `unity/PORTING_MAP.md` | Godot 매핑 초안 | `docs/GODOT_PORTING_MAP.md`로 승계 |
| `loop/HANDOFF.md`, `STATUS.md`, `인수인계_2026-09-27.md` | 인수인계 (원본 미검증) | `docs/handoff/` 아카이브 |
| `fons-launcher/` | mac 런처 | 범위 밖, 버림 |
| `tools/check_unity_health.sh`, `run_editmode_tests.sh`, `edit_guard.py` | Unity 전용 | 버리고 `tools/check_docs.py`만 개념 승계 |

**대조 체크리스트 (원본 접근 즉시 실행):**

- [ ] 각 경로가 실제로 존재하는지 하나씩 확인하고, 없는 항목은 이 표에서 삭제 또는 수정
- [ ] `fons-web-ver/app/src/*.ts` 실제 파일 목록 확정 (위 목록에 없는 모듈이 더 있는지)
- [ ] `verify_*.mjs` 실제 개수·이름 확정
- [ ] `unity/Assets/Resources/Data/` 실제 JSON 전량 나열 → `data/manifest.json`과 diff
- [ ] `design-docs/` 실제 파일명 확정 (`GDD_v8.0_00_확정사항.md` 규칙이 맞는지)
- [ ] 원본의 `loop/HANDOFF.md`·`STATUS.md`를 읽고 이 문서의 가정과 어긋나는 부분 수정

## 2. 새 GitHub 레포 만들기

레포·프로젝트 이름은 **폰즈**로 확정한다.

```bash
# 이 머신에는 gh CLI도 GitHub 자격증명도 없다 → 레포 생성은 수동 또는 Freebuff GitHub 연결 후
git init -b main
git add .
git commit -m "chore: scaffold 폰즈 godot rebuild (docs/data/sim only)"
git remote add origin git@github.com:haejoonlim/폰즈.git
git push -u origin main
```

- GitHub 웹에서 `haejoonlim/폰즈`를 **private**으로 먼저 만든 뒤 위 `git remote add`부터 실행하면 된다.
- 비ASCII 레포명은 URL·clone 경로에서 퍼센트 인코딩/punycode로 보일 수 있다. 표시명은 `폰즈`로 두고, 클론 경로가 어색하면 그때만 URL을 그대로 쓰면 된다.
- 원격 push는 자격증명(SSH 키 또는 토큰)이 준비된 뒤에만 가능하다. 준비 전에는 로컬 커밋까지만.

## 3. 데이터 이관 (Phase 0)

```bash
# 1) 먼저 manifest를 원본 트리와 대조한다 (아래는 대조 전 추측 목록)
ls ../soul-commander/unity/Assets/Resources/Data/*.json | xargs -n1 basename | sort > /tmp/original_data.txt
python3 -c "import json;print('\n'.join(sorted(json.load(open('data/manifest.json'))['files'])))" > /tmp/manifest_data.txt
diff /tmp/original_data.txt /tmp/manifest_data.txt   # ← 차이 0이 될 때까지 manifest 수정

# 2) manifest 확정 후에만 복사
python3 tools/sync_data.py --src ../soul-commander/unity/Assets/Resources/Data --dst data
python3 tools/sync_data.py --src ../soul-commander/unity/Assets/Resources/Data --dst godot/data
python3 tools/check_docs.py
```

- `data/manifest.json`은 **한 번도 원본과 대조된 적 없는 추측 목록**이다(파일 자체가 그렇게 적고 있다). diff 없이 복사를 돌리면 조용히 누락된다.
- `data/manifest.json`에 있는 파일만 복사. `.meta`, `.gitkeep` 제외.
- JSON 내용 수정 금지. 밸런스 변경은 별도 PR + GDD 개정으로만.

## 4. 시뮬레이터 포팅 순서

1. `sim/gacha.py` → `godot/scripts/sim/gacha.gd` (W0: 130연, shaped 5%+legacy, D-265) — **상수 중복 제거 먼저** (sim/README.md 참조). 수치 `130`·`5%`·`0.95`는 원본 미검증
2. `combat.ts` → `combat.gd` (DamageFormula TS 1:1, D-267 1:1 — 원본 미검증)
3. `summon.ts` → `summon.gd` (free/pity/lineage/multi, unlock/realpath/relations/reroll)
4. `estate.ts` → `estate.gd` (S2 death, S3_2 status, S3_3 HUD, S3_4 pattern)
5. `party.ts` → `party.gd`, `tower.ts` → `tower.gd`, `economy_snapshot.ts` → `economy.gd`
6. `game.ts` 상태머신 → `autoload/game_state.gd`
7. `game3d/*` → `world/estate_3d.gd`, `explore_3d.gd`, `monparts.gd`, `title.gd`

각 단계마다 `godot/tests/test_*.gd` + `tools/gate_all.py` 통과를 완료 조건으로 한다.
원본 게이트(원본 미검증): `verify_game.mjs 22/22`, `verify_w1~w4`, `verify_g0~g4`, `verify_direct`, `verify_battle`.

**주의:** 위 1~7의 원본 `.ts` 파일을 아직 한 줄도 읽지 못했다. 포팅 "1:1"은 목표이고, 실제 착수는 원본 소스 확보 후다. 그 전까지는 이 목록을 포팅 대상 목록이 아니라 **스캐폴드 가정**으로 취급한다.

## 5. 버릴 것 재확인 (실수 방지)

- `unity/Assets/Art`, `Prefabs`, `Scenes`, `Icon.png`, `TextMesh Pro` 복사 금지
- `unity/Assets/Scripts` C# 복사 금지 (참고용 링크만)
- `fons-web-ver/app/src/assets`, `style.css`, `public/icons.svg` 복사 금지
- `ProjectSettings/`, `.meta` 복사 금지

## 6. 완료 정의

- [ ] 원본 인벤토리 대조 완료 (§1 체크리스트 전 항목)
- [ ] `data/manifest.json` ↔ 원본 diff 0, `data/`에 전 파일 존재, `check_docs.py` 통과
- [ ] GDD 원문 `docs/gdd/` 복사 + 문서 검수(review_docs) 통과
- [ ] `sim/gacha.py` 단독 실행으로 W0 게이트 재현
- [ ] `godot/`가 Godot 4.7.2에서 열리고 `tests/` 통과 (GUT exit 0)
- [ ] `docs/GODOT_PORTING_MAP.md`에 TS→GDScript 매핑표 완성
