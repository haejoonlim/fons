# DOC REVIEW — 폰즈 (FONS) 전체 문서 검수 기록

작성 2026-10-16. 대상: 이 저장소의 문서·설정·코드 **및** 그 근거가 되는 원본 저장소 문서.
관련 문서: [DEV_PLAN.md](DEV_PLAN.md) (작업 순서·게이트), [MIGRATION_PLAN.md](../MIGRATION_PLAN.md) (이관 인벤토리), [HANDOFF.md](../HANDOFF.md) (인수인계).

---

## 1. 검수 범위와 결론 요약

| 검수 대상 | 상태 | 근거 |
|---|---|---|
| 원본 GDD `design-docs/GDD_v8.0_00~09, 99` | **검수 불가** | 원본 레포가 비공개이고 이 머신에 접근 수단이 없다 (§2). 본문은 어떤 대화 기록에도 저장돼 있지 않다 (원본 미검증) |
| 원본 `fons-web-ver/PLAN.md`, `GAME_PLAN_3D.md` | **검수 불가** | 같은 사유. §6-2 검증 테이블 원문 미확보 (원본 미검증) |
| 원본 결정 기록 `D-265`, `D-267` | **검수 불가** | 결정의 **제목조차** 확인되지 않았다. 현재 리포에 있는 값은 전부 2차 인용 (원본 미검증) |
| 원본 설정 데이터 `unity/Assets/Resources/Data/*.json` | **검수 불가** | 파일 내용 미확보. `data/manifest.json`은 원본과 **한 번도 대조된 적 없는 추정 목록** (원본 미검증) |
| 원본 `.ts` 시뮬레이터 소스 (`game/combat/summon/estate/party/tower/economy`) | **검수 불가** | 한 줄도 읽지 못했다. 포팅 매핑표는 파일명 기반 가정 (원본 미검증) |
| 이 저장소의 문서 (`README.md`, `SETUP.md`, `MIGRATION_PLAN.md`, `docs/*.md`, `data/README.md`, `sim/README.md`) | **검수 완료** | 전 문장을 읽고 결함 8건 확인 → §3 |
| 이 저장소의 코드·설정 (`sim/gacha.py`, `godot/**`, `tools/**`, `.gitignore`) | **검수 완료** | 실물 파일 열람 + 실제 실행으로 확인 → §3 |
| 이 저장소와 원본의 **일치 여부** | **검수 불가** | 원본이 없으면 대조 자체가 성립하지 않는다 |

**요약:** 현재 리포 자체의 결함은 찾아 고칠 수 있었고, 그중 게이트가 사실을 증명하지 못하던 결함(§3-1)은 가장 위험한 종류였다. 그러나 **사용자가 요청한 "전체 문서 검수"의 핵심부 — 원본 GDD·PLAN·설정의 모순점 탐색 — 는 아직 시작조차 하지 못했다.** 원본 없이 쓸 수 있는 "모순 보고서"는 추측이며, 그러한 문서는 이 저장소의 원칙(원본이 이긴다, 원본 미검증은 사실로 쓰지 않는다)에 정면으로 어긋난다. 그래서 결함을 지어내는 대신 §5의 실행 절차와 §6의 사람 체크리스트를 미리 갖춰 두었다.

---

## 2. 검수 불가 사유 (증거)

원본 `haejoonlim/soul-commander`(비공개)에 접근할 수 없다. 아래 기록은 전부 **원본 미검증** 상태의 접근 시도 결과다. 2026-10-16에 실제로 실행한 확인은 다음과 같다.

1. **레포는 비공개다.** GitHub REST API로 `GET /repos/haejoonlim/soul-commander` → `404 Not Found`. 같은 시각 `GET /users/haejoonlim/repos`는 정상 응답하며 공개 레포 3개(`haejoonlim/-`, `haejoonlim/hive`, `haejoonlim/Limagination`)를 반환했다. **`soul-commander`만 목록에 없다** → 존재하지 않는 것이 아니라 비공개다. (원본 미검증 — 레포 내용은 이 머신에서 읽지 못했다.)
2. **자격증명이 없다.** `gh` CLI 미설치. `git ls-remote https://github.com/haejoonlim/soul-commander.git` → `could not read Username for 'https://github.com': Device not configured` (인증 실패). `~/.netrc` 없음, macOS 키체인에 github.com 인터넷 암호 항목 없음, 전역 git config에 자격증명 헬퍼 없음. (원본 미검증)
3. **로컬 사본이 없다.** Spotlight(`mdfind`)로 `soul-commander`, `GDD_v8`, `fons`를 검색했고, 홈 전체에서 `.git` 디렉터리와 `soul-commander*` / `fons*` / `폰즈` 이름을 훑었다. 발견된 것은 무관한 Godot 사용자 데이터 디렉터리 하나뿐이다. Desktop·Documents·Downloads·iCloud에도 원본 프로젝트나 GDD 문서는 없다. (원본 미검증)
4. **과거 세션도 본문을 저장하지 않았다.** 이 리포를 만든 이전 세션들은 GitHub 연동 도구로 **디렉터리 목록 수준**만 읽었고, GDD·`PLAN.md`·JSON 파일의 본문은 읽지 않았다. Freebuff 메시지 저장소(`desktop-v2.db`)의 모든 메시지를 검색해도 원본 본문은 존재하지 않는다 — 복구된 것은 파일 **경로 목록**과 이 리포가 스스로 쓴 문서뿐이다. (원본 미검증)

**따라서 다음이 확정된다.**

- 이 리포의 "130연 / shaped 5% / legacy 0.95 / D-265 / D-267 / `verify_game.mjs` 22/22" 같은 수치는 **전부 2차 인용**이며, 원본 정의를 본 사람이 아무도 없다. (원본 미검증)
- 현재 리포의 어떤 문서도 원본과의 정합성을 주장할 수 없다.

**해소 방법 (택 1):**

1. Freebuff의 GitHub 연동을 연결하면 에이전트가 원본 파일을 직접 읽고 이관·검수할 수 있다 (권장 — 검수와 이관을 한 번에 처리).
2. 이 머신에 원본을 clone하고 경로를 알려준다.
   ```bash
   git clone https://github.com/haejoonlim/soul-commander.git ~/soul-commander
   ```
3. 원본 문서 파일들만이라도 이 리포 `docs/gdd/`, `docs/web-plan/`에 직접 붙여 넣는다.

세 경우 모두, 접근이 뚫린 **직후 §5의 절차를 순서대로** 실행한다.

---

## 3. 이 저장소 문서 검수 결과 (완료된 부분)

실물 파일을 읽고 실행해서 확인한 결함만 적는다. 추정으로 채운 항목은 없다.

### 3-1. 가장 위험한 결함 — GUT가 테스트를 하나도 실행하지 않고 성공으로 종료했다 (수정 완료)

- **증거:** `.godot` 임포트 캐시가 없는 새 사본에서 `cd godot && godot --headless -s addons/gut/gut_cmdln.gd -gexit`를 실행하면 Godot이
  `ERROR: Some GUT class_names have not been imported. Please restart the Editor or run godot --headless --import`
  를 출력하고 **exit 0으로 종료한다. 테스트는 한 건도 실행되지 않는다.**
- **영향:** 이전 세션이 보고한 "2 scripts / 6 tests / 6 passing / 8 asserts"는 **전달된 파일만으로는 재현되지 않았다.** 종료 코드가 0이므로 CI 게이트도, 사람도 이 상태를 "통과"로 읽는다. 검증이 검증을 가장한 형태다.
- **측정된 정상 동작:** `godot --headless --import`를 먼저 실행한 뒤 같은 GUT 명령을 돌리면 `Scripts 2 / Tests 6 / Passing 6 / Asserts 8`, exit 0으로 테스트가 실제로 실행된다. 즉 문제는 테스트 내용이 아니라 **실행 순서가 명령에 빠져 있었다는 것**이다.
- **상태:** **수정 완료 (2026-10-16).** `tools/test_godot.sh`가 존재하며 실행 권한이 있다. 임포트 → GUT 2단계를 단일 스크립트로 고정하고, 끝나고 junit 결과(`.gut_junit.xml`)를 읽어 **테스트가 0건이면 실패로 종료**하도록 했다 — 같은 침묵 통과가 재발할 수 없다. coordinator가 실측한 정상 동작: 임포트 후 GUT가 `Scripts 2 / Tests 6 / Passing 6 / Asserts 8`, exit 0.
- **금지 규칙 (지금 유효):** 임포트 없이 GUT만 돌리지 않는다. 그 상태의 exit 0은 통과가 아니다. 지원되는 실행 경로는 `./tools/test_godot.sh` 하나다.

### 3-2. `DataLoader`가 읽는 폴더가 존재하지 않았다 (수정됨)

- **증거:** `godot/scripts/autoload/data_loader.gd`는 `const DATA_DIR := "res://data"`에서 JSON을 읽는다. 즉 `godot/data/`가 있어야 하는데, **그 디렉터리 자체가 없었다** (`tools/sync_data.py`를 아직 돌리지 않았기 때문).
- **영향:** 데이터를 읽는 모든 코드 경로가 항상 `push_error("missing data file: ...")`로만 떨어진다. 데이터 로더가 "동작한다"고 주장할 근거가 아예 없었다.
- **상태:** **수정 완료 (2026-10-16, 파일 열람으로 확인).** `godot/data/README.md`가 존재한다. 이 파일이 자리표시자 역할을 하므로 빈 디렉터리가 Git에 안 잡히던 문제도 함께 해소된다. JSON 내용은 Phase 0에서 원본 접근 후 채운다 — 내용이 빈 상태가 정상이다.

### 3-3. 메인 신이 없었다 (수정됨)

- **증거:** `godot/project.godot`의 `run/main_scene="res://scenes/title.tscn"`인데 파일이 없다. `godot --headless --import`가
  `ERROR: Cannot open file 'res://scenes/title.tscn'.` / `ERROR: Failed loading resource: res://scenes/title.tscn.`를 출력했다.
- **상태:** **수정 완료 (2026-10-16, 파일 열람으로 확인).** `godot/scenes/title.tscn`이 존재한다(Control + Label 최소 자리표시자). 정식 타이틀 화면은 Phase 3에서 제작한다.

### 3-4. 같은 값이 세 곳에 따로 박혀 있다 — SSOT 위반 (의도적으로 미수정)

- **증거:** `sim/gacha.py`(130 / 0.05 / 0.95), `godot/scripts/sim/gacha.gd`(`PULLS` / `SHAPED_BONUS` / `LEGACY_COVERAGE`), `godot/tests/test_gacha.gd`(130 / 6.5 / 0.05 / 0.95)가 각자 독립적으로 상수를 정의한다.
- **영향:** 한 곳만 고치면 게임과 테스트가 서로 다른 값을 신뢰한다. 더 나쁜 것은 `test_gacha.gd`가 **자기 사본을 스스로 검증**하므로, 이 테스트는 드리프트를 **원리적으로 잡을 수 없다.**
- **상태:** **미수정 — 의도적.** 지금 통합하면 원본과 대조된 적 없는 숫자(§3-8)를 "확정 상수"로 굳혀 버린다. 순서를 강제한다: **① 원본 대조 → ② 값 확정 → ③ 단일 출처화(`tools/tracked_numbers.json`을 추적 상수의 단일 출처로 삼는다) + 드리프트를 잡는 테스트.** 관련 기록은 [sim/README.md](../sim/README.md)에 있다.

### 3-5. 검사 도구가 아니라 문서가 틀렸던 것 (조치 완료 — 최종 재측정 대기)

기계 검수기(`tools/review_docs.py`, §4)를 처음 돌린 결과: **`DANGLING_SSOT` 6건, `UNVERIFIED_CLAIM` 32건**, 나머지 5종 검사는 0건.

- `DANGLING_SSOT` 6건 — `data/README.md`(1건), `docs/DEV_PLAN.md`(4건), `sim/README.md`(1건)가 "SSOT"라고 주장하면서 **존재하는 파일을 지목하지 않거나 존재하지 않는 파일을 지목**했다. 대표적으로 `data/game_const.json`을 SSOT로 지목했지만 그 파일은 없다(§3-4의 P1-4 산출물 **예정** 파일이다). (검사 정의: `tools/review_docs.py`)
- `UNVERIFIED_CLAIM` 32건 — 원본 저장소에 대한 숫자 주장을 하면서 그 줄에 `원본 미검증` 표시가 없는 문장들이다. 표에 "검증 상태" 열이 있어도 **행 단위 표기**가 없으면 지적된다. (검사 정의: `tools/review_docs.py`)

**처리 원칙:** 검사기를 느슨하게 만들어 통과시키지 않는다. **문서를 고친다.** 지적된 줄에 표시를 붙이거나 원본 저장소를 가리키는 문장으로 바로잡는다. 검사기의 정밀도 규칙(원본 경로 면제, 미래 산출물 면제)은 그대로 유지한다.
**현재 상태 (2026-10-16):** 1차 측정 38건에서 문서 표기 수정 후 **24건**으로 줄었다(coordinator 실측). 이번 라운드에서 남아 있던 `DANGLING_SSOT` 3건(모두 이 문서의 검사 설명 줄이다 — 검사 정의 파일 `tools/review_docs.py`를 지목하도록 고쳤다)과 이 문서의 `UNVERIFIED_CLAIM` 지적을 조치했다. **조치 후 최종 수치는 coordinator가 재측정하며, 이 문서에 확정치로 적지 않는다.**

### 3-6. 게이트가 실제로 지키지 않던 것 (수정 완료)

- **증거:** `tools/check_docs.py`의 `REQUIRED`가 9개 파일만 검사했다. `SETUP.md`, `docs/DEV_PLAN.md`, `HANDOFF.md`, `tools/review_docs.py`, `godot/scenes/title.tscn`, `godot/data/`가 **목록에 없어서**, 그것들이 사라져도 게이트는 통과했다.
- **상태:** **수정 완료 (2026-10-16, 파일 열람으로 확인).** `tools/check_docs.py`의 `REQUIRED`는 **25개 항목**으로 확장됐고, 위에 나열한 누락 항목이 전부 들어갔다 — 최상위 4개(README·SETUP·HANDOFF·MIGRATION_PLAN), `docs/*` 3개, `data/*` 2개, `sim/*` 2개, `tools/*` 5개, Godot 관련 9개.

### 3-7. 이름 표류 (결정·정리 완료)

- **증거:** 이 프로젝트는 짧은 기간에 `fons-godot` → `fons` → `폰즈`로 이름이 바뀌었고, 문서·구조도·제목에 옛 이름이 남아 있었다.
- **상태:** **결정·정리 완료.** 이름과 저장소명은 **폰즈(FONS)** 로 확정했다([MIGRATION_PLAN.md](../MIGRATION_PLAN.md)의 레포 생성 절). 원본 레포 이름(`haejoonlim/soul-commander`)은 역사적 사실이므로 그대로 둔다. 아래 잔재는 전부 정리했다.
- **잔재 정리 (2026-10-16):**
  - `docs/GODOT_PORTING_MAP.md` H1 — `폰즈`로 수정 완료.
  - `README.md`의 "새 레포 구조" 코드블록 루트 — coordinator가 같은 라운드에서 실제 경로 기준으로 갱신했다. **단, 이 문서 작성자는 그 파일을 소유하지 않아 직접 확인하지 못했다 — 재확인 대상(미검증)이다.**
  - [DEV_PLAN.md](DEV_PLAN.md) 부록 A #4·#5의 해당 항목도 이에 맞춰 정리했다.

### 3-8. 원본 미검증 수치가 확정 수치처럼 서술돼 있었다 (표시 완료, 대조는 미완)

- **증거:** 130 / 5% / 0.95 / `max(1, atk - defense) * crit_mult` / `D-265` / `D-267` / `verify_game.mjs 22/22` / `S2 death`, `S3_2 status` 같은 항목들이 문서에 단정형으로 적혀 있었다. 이들은 한 세션이 **원본을 부분적으로만 읽고 손으로 옮긴** 2차 정보이며, `D-265`·`D-267`이 **무엇을 결정한 사안인지조차 확인되지 않았다.** (원본 미검증)
- **상태:** 전부 `원본 미검증`으로 표시했다. 값 자체의 대조는 §5에서 원본 확보 후 수행한다.
- **주의:** `sim/gacha.py`는 `random.Random(265)`로 `random() < 0.05`를 세는 단순 구현이다. 원본 가챠의 천장·계보·다중 뽑기 규칙과 무관하므로, **이 게이트가 통과해도 원본 가챠 규칙에 대해서는 아무것도 증명하지 않는다**(DEV_PLAN 부록 A #8). (원본 미검증)

---

## 4. 자동 검수 도구

`tools/review_docs.py` — 오프라인·표준 라이브러리만 사용, 결정론적, Python 3.9 호환.

```bash
./.venv/bin/python tools/review_docs.py                 # 검수 실행
./.venv/bin/python tools/review_docs.py --list-checks   # 검사 7종 설명
./.venv/bin/python tools/review_docs.py --json tools/review_report.json
```

종료 코드: **0** 발견 없음 / **1** 발견 있음 / **2** 사용법·설정 오류.
`--root`, `--docs-dir`, `--data-dir`로 경로를 바꿀 수 있다. 출력에는 항상 **면제 건수**가 함께 표시된다(조용히 넘기지 않는다).

| 검사 | 찾는 것 |
|---|---|
| `BROKEN_REFERENCE` | 저장소 경로처럼 보이는 참조가 실제로 없음 (원본 저장소 경로·미래 산출물은 면제) |
| `BROKEN_LINK` | 마크다운 로컬 링크 대상 파일이 없음 |
| `DUPLICATE_H1` | `docs/` 안 두 문서의 H1 제목이 같음 |
| `DANGLING_SSOT` | SSOT라고 주장하면서 존재하는 파일을 지목하지 않음 (검사 정의: `tools/review_docs.py`) |
| `NUMBER_CONFLICT` | 추적 상수가 문서마다 다른 값. registry는 `tools/tracked_numbers.json`이며 현재 등록: `PULLS`=130, `SHAPED_RATE`=0.05, `LEGACY_COVERAGE`=0.95 (전부 원본 미검증). registry가 없으면 SKIP |
| `CONST_DRIFT` | 같은 상수가 코드(`sim/*.py`, `godot/scripts/**/*.gd`)·데이터(`data/*.json`)에서 다른 값으로 선언됨 |
| `UNVERIFIED_CLAIM` | 원본 저장소에 대한 숫자 주장에 `원본 미검증` 표시가 없음 |

### 이 도구가 잡지 **못하는** 것

기계가 못 잡는 모순은 사람이 읽어야 한다. 아래는 도구의 설계 범위 밖이다.

- 서로 어긋나는 **설계 서술**(두 문단이 같은 시스템을 다르게 설명)
- **중복 요구사항**과 문서 간 복사·표류
- 경로가 아닌 **이름으로 된 낡은 상호 참조**("위 §6-2 참조"가 실제로는 다른 절을 가리키는 경우)
- **용어 정의 불일치**(같은 단어를 다른 뜻으로 사용)
- **번역·요약 표류**(원문과 요약본이 다른 결론을 내는 경우)

### 게이트 연결에 대한 결정

**`tools/review_docs.py`는 자문(advisory) 검수기이며, `tools/gate_all.py`의 하드 게이트로 연결하지 않는다.**
이유: 현재 리포는 **정당하게** 2차 정보를 담고 있고, §3-5의 `UNVERIFIED_CLAIM` 지적은 그 사실을 드러내는 **정상 동작**이다. 이 상태에서 하드 게이트로 묶으면 게이트가 항상 빨간불이 되어 아무도 보지 않게 되거나, 반대로 검사기를 약화시켜 통과시키는 유혹이 생긴다. 하드 게이트 승격 조건은 **원본 대조 완료 후 `UNVERIFIED_CLAIM` 0건**이다. 그때까지는 Phase 4에서 사람이 읽는 리포트로만 쓴다.

> **[정합성 — 2026-10-16]** [DEV_PLAN.md](DEV_PLAN.md) §7의 검증 표는 이 검사에 대해 "목표: 지적 0건 + exit 0"을 적으면서, 동시에 이 검사가 **자문(advisory)** 이며 `tools/gate_all.py`의 하드 게이트가 아니라는 이 절의 결정을 명시하도록 정리했다. §10의 "게이트 연결" 항목도 같은 기준으로 수정했다. 두 문서의 서술은 이제 일치한다.

---

## 5. 원본 확보 직후 돌릴 검수 절차

순서를 바꾸지 않는다. 1번을 건너뛰면 이후 결과가 전부 오염된다.

1. **`data/manifest.json`을 먼저 대조한다 — 복사보다 먼저.**
   ```bash
   ls ~/soul-commander/unity/Assets/Resources/Data/*.json | xargs -n1 basename | sort > /tmp/original_data.txt
   python3 -c "import json;print('\n'.join(sorted(json.load(open('data/manifest.json'))['files'])))" > /tmp/manifest_data.txt
   diff /tmp/original_data.txt /tmp/manifest_data.txt
   ```
   차이가 0이 될 때까지 manifest를 고친다. `tools/sync_data.py`는 없는 파일을 **조용히 건너뛰고도 exit 0**으로 끝나므로, 대조 없이 돌리면 누락을 알 수 없다.
2. **`D-265`·`D-267` 원문을 읽고, 이 리포의 모든 전사를 고치거나 삭제한다.** 결정 번호가 무엇을 정한 사안인지 먼저 확인한다. 확인 전까지 §3의 수치는 사실이 아니며, 전부 원본 미검증이다.
3. **포팅된 공식과 원본을 1:1로 대조한다.** `godot/scripts/sim/combat.gd`의 데미지 식, `sim/gacha.py`·`gacha.gd`의 상수·확률 분기, 이후 추가될 `summon.gd`·`estate.gd`가 대상이다. 원본 `.ts`의 해당 줄을 인용해 주석으로 남긴다. (현재 포팅된 식 자체가 원본 미검증이다.)
4. **`tools/review_docs.py`를 다시 돌리고 `UNVERIFIED_CLAIM`을 0건까지 끌어내린다.** 방법은 두 가지뿐이다 — 원본으로 **검증된 주장은 근거와 함께 확정으로 승격**시키거나, 검증 불가능한 주장은 **표시를 붙여 2차 정보로 남긴다.** 검사기 규칙을 느슨하게 만드는 것은 세 번째 방법이 아니다. (대상 주장은 그때까지 원본 미검증으로 남는다.)
5. **원본 인벤토리를 실제 트리와 대조한다.** [MIGRATION_PLAN.md](../MIGRATION_PLAN.md) §1의 체크리스트 6항목(경로 존재 여부, `.ts` 실제 목록, `verify_*.mjs` 개수·이름, Data JSON 전량, `design-docs/` 실제 파일명, 원본 `loop/HANDOFF.md`·`STATUS.md`)을 하나씩 처리하고 표를 실제 값으로 교체한다.
6. **결과를 이 문서에 기록한다.** 위 1~5에서 무엇을 확정하고 무엇을 폐기했는지, 그리고 수정 후 `review_docs.py`의 최종 수치(발견/면제/대조 상수)를 적는다.

---

## 6. 사람이 봐야 하는 검수 체크리스트

원본을 읽을 때 아래 유형을 순서대로 확인한다. 도구가 대신 찾아주지 못하는 항목들이다.

- [ ] **수치 불일치 — 문서 vs JSON vs 코드.** GDD 서술 · `PLAN.md` 검증 테이블 · `unity/.../Data/*.json` 값 · 포팅된 GDScript 상수, 이 네 곳이 같은 값을 말하는가? (§3-4의 상수 중복 하드코딩이 이 문제의 실제 사례다). 이 네 문서는 모두 원본 미검증이므로 대조 전에는 판정할 수 없다. (원본 미검증)
- [ ] **확정 결정과 설계 서술의 충돌.** `GDD_v8.0_00_확정사항.md`가 정한 것과 `01~09`의 서술이 어긋나는 곳이 있는가? (원본 미검증)
- [ ] **폐기된 설계의 잔존.** 이전 버전에서 버린 시스템이 후속 문서·JSON·코드에 살아 있는가? (문서 번호 `99`가 이 성격일 가능성이 있다 — **미검증**)
- [ ] **같은 용어의 다른 정의.** "생태", "에너지 채널", "계보", "shaped", "legacy" 같은 핵심 용어가 문서마다 다른 뜻으로 쓰이는가?
- [ ] **순서·단계 의존 관계의 모순.** 앞 단계의 출력을 뒤 단계가 다르게 가정하는가? (예: 가챠 결과가 영지 자원에 반영되는 규칙이 두 문서에서 다름)
- [ ] **중복 서술과 표류.** 같은 규칙이 여러 문서에 복사돼 한쪽만 갱신된 곳이 있는가?
- [ ] **`GODOT_PORTING_MAP.md`의 1:1 주장 검증.** "TS 1:1", "D-267 1:1" 같은 주장은 **아직 아무것도 대조하지 않은 상태의 가정**이다 (원본 미검증). 한 항목씩 실제로 대조한다.
- [ ] **상태 전이 유추의 검증.** `game_state.gd`의 `TITLE → SUMMON → COMBAT → RESULT → ESTATE → TOWER`는 파일명에서 **유추한 임시안**이다. 원본 `game.ts`의 실제 전이와 비교한다.

---

## 부록 — 이 검수의 한계 (요약)

- **원본 문서 검수: 0%.** §2의 차단이 풀려야 시작된다. 이 문서에 원본의 모순점을 적은 절은 없다 — 알 수 없기 때문이다.
- **이 리포 검수: 발견과 수정 모두 완료.** 실물 파일 열람과 실행으로 결함 8건을 확인했고, 원본 없이 고칠 수 있는 것은 전부 고쳤다. 내역 — **수정 완료 5건**(§3-1 임포트 강제 + 거짓 통과 차단, §3-2 `godot/data/`, §3-3 `title.tscn`, §3-6 `check_docs.py` 25개 확장, §3-5·§3-7 표기·이름 정리) / **의도적 미수정 2건**(§3-4 상수 통합은 원본 대조 후, §3-8 값 대조는 원본 확보 후).
- **수정 적용은 파일 열람으로 재확인했다 (2026-10-16, 이 문서 작성자).** `godot/data/README.md`, `godot/scenes/title.tscn`, `tools/test_godot.sh`(실행 권한 포함), `tools/tracked_numbers.json`이 모두 존재하고, `tools/check_docs.py`는 25개 항목으로, `.gitignore`는 `build/`·`*.app/`·`*.dmg` 규칙을 포함하도록 변경된 것을 확인했다. 다만 **재실행 검증(`review_docs.py`·`check_docs.py`)의 최종 수치는 coordinator가 측정한다** — 이 문서 작성자는 터미널이 없어 실행하지 못했다.
- **§3-5의 최종 재측정 수치는 이 문서에 확정치로 적지 않는다.** 측정은 coordinator가 수행하며, 남은 지적이 0건이 되기 전에는 이 검수를 "통과"로 읽지 않는다.
- **성능·렌더러 관련 항목은 이 검수의 범위가 아니다.** 그쪽은 [DEV_PLAN.md](DEV_PLAN.md) §4·§8과 [SETUP.md](../SETUP.md)를 따른다.
