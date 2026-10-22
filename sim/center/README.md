# sim/center/ — 테스트 센터 (폰즈)

게임 설계가 **실제로 작동하는지** 눈으로 확인하는 곳. 원본 저장소
`soul-commander` 의 `design-docs/_tools/` 에 있던 것을 폰즈로 옮긴 것이다
(2026-10-17). 옮기면서 바꾼 것은 **경로와 게이트 목록**뿐이고, 시뮬 본체는 손대지 않았다.

## 실행

```bash
./.venv/bin/python sim/center/run_snapshots.py       # 시뮬 22종 1회 실행 → pages/snapshots.js
./.venv/bin/python sim/center/server.py 8741         # 서버 → http://localhost:8741/
```

`server.py` 는 정적 서빙 + 실시간 API 를 함께 한다. 파일을 저장하면 브라우저가 스스로
새로고침한다(`/__gacha_hash`).

| API | 하는 일 |
|---|---|
| `GET /api/sims` | 시뮬 22종 목록·설명·조절 파라미터 |
| `GET /api/sim/<이름>?k=v` | 시뮬 1개 즉시 실행 (동시 1개 제한 · 409) |
| `POST /api/snapshots` | 전 시뮬 재실행 → `pages/snapshots.js` 재생성 (진행은 `/api/snapshots/status`) |
| `POST /api/gates[?only=id]` | 폰즈 게이트 실행 (진행은 `/api/gates/status`) |
| `GET /api/gate-ledger` | `tools/gate_all.py` 런 원장 + 추이 |

## 폴더

```
sim/center/
  server.py           # 정적 서빙 + /api/sim · /api/snapshots · /api/gates · /api/gate-ledger
  run_snapshots.py    # SIMS 정본 — 시뮬 실행·stdout 캡처·데이터 지문
  sync_pages.py       # 페이지 생성물을 data/ 에서 다시 계산 (게이트 `pages` · 서버 시작 시 --write)
  sims/               # 시뮬 본체 22종 + 형제 모듈 (gacha_test · sim_economy …)
  pages/              # 서버 루트 — 탭 HTML 6종 (test_center · gacha · 생태도감 · 바이옴 여정 · 직업트리 · promotion_lab)
```

`pages/snapshots.js`·`snapshots.json` 은 **생성물**이라 커밋하지 않는다(gitignore).
새 클론에서는 스냅샷 탭이 "아직 스냅샷이 없습니다" 로 뜨고, 위 첫 명령을 돌리면 채워진다.

## 시뮬은 무엇을 읽나

전부 `data/` 의 정본 JSON 만 읽는다. 원본에서는 `원본 데이터 폴더` 를
가리켰으므로 그 부분만 `data/` 로 바꿨다. 경로 규칙은 두 가지다.

- `ROOT` = `sims/` 에서 네 단계 위 = 폰즈 루트
- 데이터 = `os.path.join(ROOT, "data", "<파일>.json")`

**검사는 읽기만 해야 한다.** 스냅샷은 실행 전후의 `data/` mtime 을 비교해서, 데이터를
덮어쓴 시뮬이 있으면 스냅샷 탭에 "데이터 원본을 고친 시뮬" 배너로 띄운다. 지금은 0건이다.
`normalize_biome_order.py` 는 유일하게 쓰기 경로가 있지만, 변경이 없으면 파일을 건드리지
않는다(멱등).

## 커리어 생성기 3종 (37차 이관)

`data/job_tree.json` 은 손으로 고치지 않는다. `sims/` 의 생성기가 만든다.
**`SIMS` 에는 넣지 않는다** — 검사가 아니라 데이터를 쓰는 도구라서, 스냅샷의
"데이터를 고친 시뮬" 판정과 섞이면 안 된다.

| 스크립트 | 하는 일 | 출력 |
|---|---|---|
| `sims/gen_career_34.py` | L2 정의 · LEXICON → 트리 생성, `R1~R10` HARD 검증 | `data/job_tree.json` |
| `sims/sync_career_tables.py` | 그 트리로 영웅생성 문서의 직업 트리 표 재생성 (`AUTO-CAREER-TREE` 블록) | `docs/gdd/GDD_v8.0_05_영웅생성.md` |
| `sims/gen_career_html.py` | 직업트리 도감 | `sim/center/pages/직업트리_전체도.html` |

실행 순서는 표의 위에서 아래. 형제 모듈 `retier.py` · `keyword_scale.json` 이 함께 있어야 한다
(`gen_career_html.py` 는 `gen_career_34.py` 의 `AX_NAME` 을 import 한다).

## 페이지 동기화 (`sync_pages.py`)

`pages/생태도감.html`·`pages/바이옴_여정.html` 은 값을 HTML 안에 박아 둔 정적 생성물이다.
원본 생성기(`gen_ecology_codex.py`·`gen_biome_journey.py`)는 폰즈에 없다. 그래서 원본의 계산
규칙을 [sync_pages.py](sync_pages.py) 로 옮겨 `data/` 위에서 다시 돌린다. **페이지 값을 손으로
고치지 않는다.** 고칠 것은 `data/` 이고, 페이지는 스크립트로 따라오게 한다.

| 명령 | 하는 일 |
|---|---|
| `sync_pages.py` | 검사. 다르면 exit 1 |
| `sync_pages.py --write` | 페이지 갱신 |
| `sync_pages.py --quiet` | 한 줄 요약 (게이트·서버가 이걸 쓴다) |

서버는 시작할 때 `--write` 를 한 번 돌리고, `gate_all.py` 는 `pages` 단계에서 `--check` 로 막는다.

### 다시 계산하는 것

| 페이지 | 값 | 규칙 |
|---|---|---|
| 생태도감 종 | `tier`·`r`·`d`·`stats`·`threat`·`el`·`floors`·`temp`·`bio`·`bids`·`note`·`pred`·`prey`·`rel`·`eco`·`bc` | `monsters.json`·`ambient.json`·`biomes.json` 그대로. 스탯은 0·미기입을 버리고 `spd` 를 `aspd` 로 통일 |
| 생태도감 종 | `level` | 서식지 → 바이옴 슬롯 → `[slot*5-4, slot*5]`. 서식지가 비면 `spawn.floors` 로 대신한다 |
| 생태도감 종 | `bc` | 4류는 동물, 6류는 식물. 악마 계열 12종은 동물로 되돌리고, `undead`·`elemental` 은 `ether` |
| 생태도감 종 | 정렬 | 전투(티어 높은 순) → 야생 → 같은 급은 이름순 |
| 생태도감 바이옴 | `gid`·`gname`·`tempS`·`cl`·`slots`·`floors`·`mult`·`habitat`·`species`·`missing`·`curN`·`complete` | 그룹·기후·난이도에서. `species` 는 서식지가 겹치는 종 |
| 생태도감 집계 | `edges`·`nAmb`·`nMon`·`nSp`·`nPlan` | 두 바이옴을 같이 사는 종이 있으면 `edges` 1 |
| 바이옴 여정 | `step`·`region`·`slot`·`id`·`name`·`kit`·`layer`·`floors`·`category`·`gatekeeper`·`regions` | 슬롯 1..26 오름차순으로 걷는다. `slot = (rx*wx + rz*wz) % 26`, `wx`·`wz` 는 페이지의 `grid` |
| 생태도감 바이옴 | `resName`·`resDesc`·`K`·`r`·`energy` | `data/ecology_energy_channels.json` 의 `roots`(바이옴별 근원자원 표)에서. `energy` 는 그 바이옴 노드의 `id`·`name`·`cat`·`consumerCount` |
| 생태도감 에너지 | `energy` 130노드의 `eaters`·`consumerRoles`·`map` | 근원자원 26(종류별 식성·역할 판정, 없으면 역할 폴백) + 지역 채널 104(카탈로그의 `consumerRoles` ∩ 현지 역할). 현지 서식종 = `bids` 가 그 바이옴을 포함한 종, 순서는 종 정렬 순 |
| 생태도감 에너지 | 종 `resources` | 그 종을 `eaters` 에 넣은 노드들. 옛 prey 문자열(`corpse`·`grass`…)은 `legacyCategories` 로 분류를 정해 같은 분류의 첫 노드, 모르면 그 바이옴 근원자원으로 붙는다 |
| 두 페이지 | 이름 일반 | `id` 가 정본에 있으면 `name`·`n` 을 정본 이름으로 (전 깊이) |

에너지 계산은 `build_energy()` 가 맡는다. 노드가 130개가 아니거나, 소비종이 없는 노드나
비현지·비호환 링크가 나오면 페이지를 쓰지 않고 exit 1 로 멈춘다.

### 계산하지 않는 것

`note`(바이옴 표), `settlements`(종족 카탈로그), 여정의 3D 계측(`profile`·`arc`·`placed`·
`footprint`·`distance`·`masks`·`camera`·`ground`·`party`·`delta`), `hero`·`mission`·`pilot`.
원본 생성기가 읽던 다른 자료(3D 자산·종족 카탈로그)가 폰즈에 없다. 이 자리들은 페이지에 남은
저자 값이고, 스크립트는 건드리지 않는다.

### 멈추는 조건

- `data/` 의 바이옴 `slots[0]` 이 1..26 연속이 아니면 멈춘다 (여정 슬롯 지도를 만들 수 없다).
- 에너지 카탈로그가 근원자원 26 · 바이옴 26 · 채널 4씩이 아니거나, 없는 바이옴을 가리키거나,
  `kind`·`category` 가 plant/animal/abiotic/ether 밖이면 멈춘다 (그래프를 만들 수 없다).
- 여정 스텝 수와 바이옴 수가 다르면 멈춘다 (자산 없이 새 스텝을 만들 수 없다).
- 페이지의 원래 JSON 띄어쓰기(`": "` 또는 빽빽한 `":"`)를 지킨다. 안 지키면 이름 하나 바꿀 때
  파일 전체(60만 자)가 다시 쓰인다.

## 옮기지 않은 시뮬 2종 (이유)

| 시뮬 | 왜 뺐나 |
|---|---|
| `audit_sim` | 시즌 시뮬 법칙을 **생성기 소스**(`gen_ecology_codex.py`)와 1:1 대조한다. 폰즈에는 생성기가 없다(도감 HTML 만 있다). 대조할 짝이 없는데 남은 검사만 돌리면 **약해진 게이트**가 초록이 된다 — 그래서 넣지 않았다. |
| `arc_parity` | `design-docs/설계/아크*.md`(원본 GDD 가안)의 문구를 데이터와 대조한다. 폰즈는 그 문서를 갖고 있지 않다 — `docs/gdd/` 에 있는 것은 GDD 12종뿐이다 (자체 실측). |

둘 다 폰즈 데이터가 아니라 **원본 저장소와의 동기**를 검사하는 도구다. 원본 문서·생성기를
들여오면 그때 `SIMS` 에 다시 넣으면 된다.

## 게이트

앱 안의 게이트 패널은 폰즈 스크립트를 그대로 부른다 — 판정식을 서버에 다시 구현하지 않는다.

| id | 명령 | 성격 |
|---|---|---|
| `docs` | `python3 tools/check_docs.py` | 필수 산출물 52종 · 구조 회귀 · data/ 정본 대조 |
| `pages` | `python3 sim/center/sync_pages.py` | 생태도감·바이옴 여정 내장값 ↔ data/ (`--write` 로 맞춤) |
| `gacha` | `python3 sim/gacha.py` | 확정 #32 확률표 · #11 종족 롤 |
| `review` | `python3 tools/review_docs.py` | advisory — 실패가 곧 빌드 실패는 아니다 |
| `env` | `python3 tools/check_env.py` | 툴체인 doctor |
| `godot` | `bash tools/test_godot.sh` | 임포트 + GUT (수 분) |
| `all` | `python3 tools/gate_all.py` | 커밋 전 전체 = `docs` + `glossary` + `gdd` + `text` + `pages` + `gacha` |

`godot` 은 수 분 걸려서 스냅샷에는 넣지 않았다. 패널에서만 돌린다.

### 런 원장

`tools/gate_all.py` 는 이제 매 런을 `tools/gate_ledger.jsonl`(gitignore)에 한 줄씩 남기고,
첫 실패에서 멈추지 않는다. 그래서 "이 실패가 **계속** 깨지는 것인지 방금 새로 깨진 것인지" 를
[🛡 게이트 상태] 탭에서 볼 수 있다. 터미널에서는 `--history` 로 같은 내용을 본다.

판정 함수(`ledger_read`·`ledger_trend`)는 `tools/gate_all.py` 한 곳에만 있고 서버가 그걸
import 해 쓴다. 두 벌로 쓰면 화면은 초록인데 게이트가 우는 상태가 조용히 생긴다.

## 옮기면서 고친 자리 (기록)

| 파일 | 고친 것 |
|---|---|
| `sims/gacha_test.py` | `skill_catalog_gen.py` 를 파일 경로로 읽는다 — 형제 모듈이라 같이 옮겼다 |
| `sims/playthrough_audit.py` | `sim_economy.py` 를 `design-docs/_tools/` 에서 찾던 것 → `sims/` 옆 파일 |
| `sims/test_gacha_revisions.py` | `gacha.html` 이 `sims/` 가 아니라 `pages/` 에 있다 |
| `sims/audit_sim.py` | (옮기지 않음 — 위 표. 계산 규칙은 `sync_pages.py` 가 대신한다) |
| `server.py` | 원본의 "루트 밖 HTML 허용" 규칙을 지웠다. 모든 탭이 `pages/` 안에 있어 필요 없고, 경로 탈출 구멍도 함께 사라진다 |
| `pages/test_center.html` | iframe `../` 제거 · 클론 재현성 검사 제거(폰즈에 `check_clone_selfconsistent.py` 가 없다) · 게이트/가이드 문구를 폰즈 명령으로 |
