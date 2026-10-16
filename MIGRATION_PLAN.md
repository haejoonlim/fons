# Migration Plan — soul-commander/FONS → 폰즈

> **접근 상태 (2026-10-17 갱신): 원본을 읽었다.**
> `haejoonlim/soul-commander`는 비공개 레포였고, SSH 키(`~/.ssh/fons_soulcommander_ed25519`)를 계정에 등록한 뒤
> `~/soul-commander`로 클론했다 (213MB · 커밋 252개 — 자체 실측).
> 그래서 이 문서의 원본 경로·파일명·개수는 이제 **전부 원본 대조값**이다.
> 근거는 사실표 4종이다 — [docs/original/00_읽는법.md](docs/original/00_읽는법.md) ·
> [01_확정_규칙.md](docs/original/01_확정_규칙.md) · [02_웹버전_포팅.md](docs/original/02_웹버전_포팅.md) ·
> [03_데이터_영지_탑.md](docs/original/03_데이터_영지_탑.md).
> **이전 판은 원본을 읽지 못한 상태에서 쓴 2차 정보였고, 그중 일부는 원본에 없는 값이었다 (§7).**
> 값이 이 문서와 사실표에서 다르면 **사실표가 맞다.**

## 0. 원칙

- 에셋·Unity C#은 **다시 만든다**. 이 레포에 복사하지 않는다.
- 문서·설정(JSON)·시뮬레이터 숫자만 남긴다.
- JSON의 단일 출처는 원본 저장소의 `unity/Assets/Resources/Data/`이고, 이 레포는 `tools/sync_data.py`로만 가져온다.
- 숫자의 근거는 사실표다. 원본에 없는 값을 추측해서 쓰지 않는다 — 이전 판이 그 실수를 했다.
- 웹 표현층(Vite/CSS/Three.js 씬)은 버리고, **시뮬 코어만** GDScript로 포팅한다.

## 1. 원본 인벤토리 (2026-10-17 대조 완료)

### 1-1. 데이터 — 17종, 전부 이관 대상

`unity/Assets/Resources/Data/`에 **17종**이 있다 (원본 대조). 이름은 `data/manifest.json`과 이미 일치한다.

```
ambient.json                  biomes.json                ecology_codex.json
ecology_energy_channels.json  elemental_affinity.json    elemental_matrix.json
equipment.json                estate.json                fusion_pairs.json
job_tree.json                 monster_personality.json   monsters.json
races.json                    scenes.json                skills_catalog.json
synergy.json                  world_laws.json
```

- 이 중 `skills_catalog.json` · `fusion_pairs.json` **2종만** 원본 스크립트가 한글 키 정본에서 생성한 것이고, 나머지 15종은 원본에서 직접 저작한 파일이다 (원본 대조).
- 그래도 **이관 원본은 17종 전부 이 폴더**다. 정본 경로와 재생성 명령은 [03_데이터_영지_탑.md](docs/original/03_데이터_영지_탑.md) §1에 적어 뒀다 (원본 대조).
- `.meta`와 `.gitkeep`은 Unity 전용 부산물이므로 가져오지 않는다.
- 이전 판의 "15종+"와 manifest의 18개 이름은 **틀렸다**. 없던 파일 3개(`estate_web.json`·`state.json`·`game_const.json`)를 넣고, 있던 파일 2개(`scenes.json`·`world_laws.json`)를 빠뜨린 목록이었다 (원본 대조).

### 1-2. 문서·계획 — 가져올 것

| 원본 경로 | 내용 | 처분 |
|---|---|---|
| `design-docs/GDD_v8.0_00~09, 99` | 정본 11종 (00 확정사항 ~ 99 운영가이드) (원본 대조) | `docs/gdd/`로 복사, 수정 금지 |
| `design-docs/AGENTS.md` · `README.md` | 프로젝트 전역 지침·리포맵 (원본 대조) | `docs/gdd/`에 함께 |
| `design-docs/결정로그/D-251~D-280` | 결정 기록 (append-only) (원본 대조) | `docs/gdd/결정로그/` |
| `design-docs/설계/` · `제안서/` · `_기록/` | 확정 상세·미확정 후보·검수 기록 (원본 대조) | 정본 아님 — 인용 금지 표기와 함께 보관 |
| `fons-web-ver/PLAN.md` · `GAME_PLAN_3D.md` | 웹 W0~W4 · 3D G0~G4 플랜과 검증표 (원본 대조) | `docs/web-plan/` |
| `fons-web-ver/docs/` | 웹 에셋 기준·플레이테스트 기록 (원본 대조) | `docs/web-plan/` (에셋 자체는 버림) |
| `unity/PORTING_MAP.md` | 구 Godot `.gd` 201개 참고 색인 — v8.0 리부트로 "직접 이식 대상 아님"으로 강등 (원본 대조) | `docs/GODOT_PORTING_MAP.md`로 승계 |
| `unity/README.md` | Unity 프로젝트 안내 (원본 대조) | `docs/` 발췌 |
| `인수인계_2026-09-27.md` · `loop/` | 인수인계·오케스트레이터 정의 (원본 대조) | `docs/handoff/` 아카이브 |
| `CLAUDE.md` · `GPT에셋발주_*.txt` | 작업 규칙 · 에셋 발주 프롬프트 **(원본 대조)** | 발주 프롬프트는 에셋 재제작 때 참고 |

- 원본의 정본은 **11개 GDD 문서(00~09·99) + `unity/Assets/Resources/Data/`의 JSON**이다. `설계/`·`제안서/`·`_기록/`·`결정로그/`는 근거 자료이지 확정 규칙의 정본이 아니다 (원본 대조).

### 1-3. 포팅할 것 — 시뮬레이터 소스

`fons-web-ver/app/src/`에 TypeScript **19개 + CSS 1개**가 있다 (원본 대조). `game3d/`는 6개다 (원본 대조).

```
main.ts              summon.ts            party.ts             combat.ts
battle3d.ts          summon3d.ts          tower.ts             estate.ts
estate_web.ts        economy_snapshot.ts  game.ts              visual.ts
sound.ts             style.css
game3d/states.ts     game3d/scene.ts      game3d/title.ts      game3d/estate3d.ts
game3d/explore3d.ts  game3d/monparts.ts
```

- **`economy.ts`는 없다.** 이전 판이 포팅 대상으로 적었지만 실제 이름은 `economy_snapshot.ts`다 (원본 대조).
- `estate_web.ts`는 웹 전용 시설 재설계 오버라이드다 — 정본 JSON을 바꾸지 않으므로 **참고만** 하고 포팅 대상은 `estate.ts`다 (원본 대조).
- 3D는 전부 절차적 지오메트리다. `app/src/assets/`에는 이미지 3개뿐이므로 포팅할 에셋이 없다 (원본 대조).

### 1-4. 버릴 것

| 원본 경로 | 이유 |
|---|---|
| `unity/Assets/Scripts/**` (C#) | 전부 GDScript로 재작성 (원본 대조) |
| `unity/Assets/Art` · `Prefabs` · `Scenes` · `Icon.png` · `TextMesh Pro` | 에셋 재제작 (원본 대조) |
| `ProjectSettings/` · 모든 `.meta` | Unity 전용 (원본 대조) |
| `fons-web-ver/app/src/style.css` · `app/src/assets/` | 웹 표현층 (원본 대조) |
| `fons-launcher/` | macOS 런처 — 범위 밖 (원본 대조) |
| `tools/` · `.githooks/` (Unity·동시편집 가드) | 개념만 승계 (원본 대조) |
| 구 Godot `archive/` | **원본이 2026-09-21에 이미 삭제했다** — 존재하지 않으므로 참조할 것도 없다 (원본 대조) |
| `godot-ver.zip` (구 Godot 구현 전량) | 원본도 **미추적·로컬 보관분**이고 "부활 금지"로 못박아 뒀다 (원본 대조) |

### 1-5. 원본이 스스로 어긋나는 곳 — 한쪽을 고르지 않고 양쪽 다 기록

| 항목 | 값 A | 값 B | 실제 |
|---|---|---|---|
| 런타임 JSON 개수 | `10` (`unity/README.md`) | `13` (`unity/PORTING_MAP.md`) | 폴더에 **17** (원본 대조) |
| 게이트잭팟 계수 | `75` (`GDD_v8.0_00`) | `85` (`D-265`·`D-267`) | 2026-09-17에 85로 개정 — 시뮬은 85 (원본 대조) |
| 전투 몬스터 수 | `56종` (`GDD_v8.0_00` #10) | `133종` (AGENTS.md §2) | `monsters.json` 실측 **133** (원본 대조) |
| `verify_direct` 통과 수 | `12` (`GAME_PLAN_3D.md`) | `16/16` (`verify_direct.mjs` 본문) | 파일 본문이 최신 (원본 대조) |
| 직업 트리 규모 | L1 7 · L2 26 · 키워드 94 | L1 7 · L2 28 · L3 82 | 개편 차수 차이 — `job_tree.json` v3.4.0 기준 (원본 대조) |

- 이런 충돌을 만나면 **추측하지 말고 파일 본문을 읽는다.** 그래도 갈리면 양쪽을 적고 사용자에게 확인한다 (원본 저장소의 자체 규칙 §6-3과 같다).

## 2. 새 GitHub 레포 만들기

이름은 **폰즈**로 확정한다. 원격은 **아직 만들지 않았다** — 저장소 생성 도구(`gh`)가 이 머신에 없기 때문이다 (자체 실측).

```bash
# GitHub 웹에서 haejoonlim/<레포명> 을 private 으로 먼저 만든 뒤:
cd ~/Desktop/폰즈
git remote add origin git@github.com:haejoonlim/<레포명>.git
git push -u origin main
```

- SSH 키(`~/.ssh/fons_soulcommander_ed25519`)가 등록돼 있으므로 push는 이 키로 가능하다 (자체 실측).
- 비ASCII 레포명은 URL에서 퍼센트 인코딩될 수 있다. 표시명은 `폰즈`, 경로가 어색하면 영문 슬러그를 쓴다.
- 원본 저장소는 private이므로 새 레포도 private을 권한다 — 미확정 계획과 원본 발췌가 들어 있다.

## 3. 데이터 이관 (Phase 0)

```bash
# 1) 대조 — 2026-10-17에 이미 끝났고 diff 0 이다. 재확인용으로만 쓴다.
ls ~/soul-commander/unity/Assets/Resources/Data/*.json | xargs -n1 basename | sort > /tmp/original_data.txt
python3 -c "import json;print('\n'.join(sorted(json.load(open('data/manifest.json'))['files'])))" > /tmp/manifest_data.txt
diff /tmp/original_data.txt /tmp/manifest_data.txt

# 2) 복사 — 원본 저장소와 Godot 런타임 양쪽으로
./.venv/bin/python tools/sync_data.py --src ~/soul-commander/unity/Assets/Resources/Data --dst data
./.venv/bin/python tools/sync_data.py --src ~/soul-commander/unity/Assets/Resources/Data --dst godot/data

# 3) 게이트
./.venv/bin/python tools/check_docs.py
```

- `sync_data.py`는 이제 **없는 파일이 하나라도 있으면 exit 1**이다. 이전 판의 "건너뛰고 exit 0" 동작은 그대로 두면 데이터가 조용히 빠진 채 게이트가 통과하는 실패 모드였다. 일부만 확인하려면 `--allow-missing`을 명시한다 (자체 실측).
- JSON 내용은 손으로 고치지 않는다. 밸런스 변경은 정본(GDD) 개정과 함께 별도 커밋으로만 한다.
- 복사는 2026-10-17에 실행했다: `data/` 17종 + `godot/data/` 17종 (자체 실측). 누락 감사는 `tools/check_docs.py`가 매 게이트 실행에서 한다.

## 4. 시뮬레이터 포팅 순서

원본 소스는 `fons-web-ver/app/src/`의 TypeScript다. 포팅은 이제 **실제 파일을 읽고** 할 수 있다.

| 순서 | 원본 | 대상 | 상태 |
|---|---|---|---|
| 1 | `fons-web-ver/app/src/summon.ts` | `godot/scripts/sim/gacha.gd` (13단계 생성 파이프라인까지 이 파일에서 이어 간다 — 분리할 경우에만 `godot/scripts/sim/summon.gd`) | **부분 완료** — 확정 #32 확률표·#11 종족 롤을 옮겼고 게이트로 검증한다 (자체 실측). 남은 것: 13단계 생성 파이프라인·pity 카운터 |
| 2 | `fons-web-ver/app/src/combat.ts` | `godot/scripts/sim/combat.gd` | 착수 전 — 관통식·위치보정·전술게이지 (확정 #6) (원본 대조) |
| 3 | `fons-web-ver/app/src/party.ts` | `godot/scripts/sim/party.gd` | 착수 전 — 5인·영구사망·보상 (확정 #3·#4) (원본 대조) |
| 4 | `fons-web-ver/app/src/estate.ts` | `godot/scripts/sim/estate.gd` | 착수 전 — 시설·인구·세금·식량 (원본 대조) |
| 5 | `fons-web-ver/app/src/tower.ts` · `economy_snapshot.ts` | `godot/scripts/sim/tower.gd` · `economy.gd` | 착수 전 (원본 대조) |
| 6 | `fons-web-ver/app/src/game.ts` | `godot/scripts/autoload/game_state.gd` | 부분 — 상태머신 골격만 (자체 실측) |
| 7 | `fons-web-ver/app/src/game3d/` | `godot/scripts/world/` | 착수 전 — game3d 6종 대응 (원본 대조) |

- 각 단계의 완료 조건은 `godot/tests/test_*.gd`와 `tools/gate_all.py` 통과다.
- 원본 게이트 중 포팅할 것: `verify_w1.mjs`(소환 분포 — `N = 100000`) · `verify_w2.mjs`(전투 1런) · `verify_w3.mjs`(탑·도감) · `verify_w4.mjs`(영지 수지) — 전부 VERIFY OK 상태다 (원본 대조).
- `verify_*.mjs`는 **15개**다. 이전 판의 "20여개"는 원본에 근거가 없었다 (원본 대조).
- `verify_game.mjs`의 최신 기록값은 **42/42**다. 이전 판의 22/22는 낡은 이력 값이었다 (원본 대조).
- 참고: 원본의 `design-docs/_tools/gacha_test.py`는 **보고용 시뮬레이터이고 통과/실패 게이트가 아니다** (원본 대조). 게이트로 삼을 대상이 아니므로 이 레포의 `sim/gacha.py`는 그 파일을 흉내내지 않고, 확정 수치를 직접 선언하고 분포를 검증하는 방식으로 만들었다 (자체 실측).

## 5. 버릴 것 재확인 (실수 방지)

- `unity/Assets/Art`, `Prefabs`, `Scenes`, `Icon.png`, `TextMesh Pro` 복사 금지 (원본 대조)
- `unity/Assets/Scripts` C# 복사 금지 (원본 대조)
- `fons-web-ver/app/src/assets`, `style.css` 복사 금지 (원본 대조)
- `ProjectSettings/`, `.meta` 복사 금지 (원본 대조)
- **Unity 잔재(`*.meta`, `ProjectSettings/`)가 이 저장소에 들어오면 안 된다** — 들어오면 Godot 프로젝트가 오염된다 (자체 실측).

## 6. 완료 정의

- [x] 원본 인벤토리 대조 완료 — 실제 트리를 읽고 확정했다 (원본 대조)
- [x] `data/manifest.json` ↔ 원본 diff 0 (17종) (원본 대조)
- [ ] `docs/gdd/`에 GDD 정본 11종 복사 + 문서 검수 통과
- [ ] `docs/web-plan/`에 PLAN·GAME_PLAN_3D 복사
- [ ] `data/` · `godot/data/`에 17종 실제 복사 (`check_docs.py` 통과까지)
- [x] `sim/gacha.py` 단독 실행으로 소환 확률표 재현 — 확정 #32·#11 (자체 실측)
- [x] `godot/`가 Godot 4.7.2에서 열리고 GUT 통과 (자체 실측)
- [x] `docs/GODOT_PORTING_MAP.md`에 TS→GDScript 매핑표 작성
- [ ] 포팅 순서 2~7 착수 (§4)

## 7. 이전 판이 원본에 없다고 확인된 주장 (재발 방지용 기록)

| 이전 판의 주장 | 원본 대조 결과 |
|---|---|
| `PULLS = 130` · "W0 게이트 130회 소환" · `expected_shaped = 6.5` | 원본에 **없다**. 또는 130은 소환 횟수가 아니다 (원본 대조) |
| D-265를 소환·가챠 게이트로 표기 | D-265는 **층 미션 시스템**이다 (원본 대조) |
| D-267의 정의문을 "아무도 읽지 않았다" | 읽었다 — **마석본위제 화폐·은행** (원본 대조) |
| `verify_*.mjs`가 20개 | 실제 **15개** (원본 대조) |
| `verify_game.mjs` 22/22 | 최신 **42/42** (원본 대조) |
| `Data/*.json`이 15종+ | 실제 **17종** (원본 대조) |
| 포팅 대상에 `economy.ts` | 그런 파일 **없다** — `economy_snapshot.ts`다 (원본 대조) |
