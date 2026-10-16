# 인수인계문서 — 폰즈 (FONS) Godot 재구축

| | |
|---|---|
| 작성 시각 | 2026-10-16 (아침 작업 시한 08:50 기준) |
| 문서 위치 | `~/Desktop/폰즈/HANDOFF.md` |
| 프로젝트 폴더 | `~/Desktop/폰즈` (git 저장소, 브랜치 `main`) |
| 판(version) | 스캐폴드 + 계획 + 검수 기록. **플레이 가능한 게임 아님** |
| 다음 사람이 제일 먼저 할 일 | §3을 읽고 원본 저장소 접근을 뚫는다 |

---

## 0. 30초 요약

**한 일**
- Unity로 만들던 게임(FONS/폰즈)을 **Godot 4.7.2로 다시 만드는 새 저장소**를 바탕화면 `폰즈/`에 세웠다.
  에셋과 Unity C#은 가져오지 않고, 문서·설정·시뮬레이터 숫자만 이관하는 원칙으로 짰다.
- 개발 환경(Godot/Blender/ffmpeg/GUT/venv)을 **실제로 설치하고 실측 검증**했다.
- 게임 개발 플랜([docs/DEV_PLAN.md](docs/DEV_PLAN.md)), 문서 검수 기록([docs/DOC_REVIEW.md](docs/DOC_REVIEW.md)),
  이관 계획([MIGRATION_PLAN.md](MIGRATION_PLAN.md)), 포팅 매핑([docs/GODOT_PORTING_MAP.md](docs/GODOT_PORTING_MAP.md))을 썼다.
- **문서 검수 자동화 도구**([tools/review_docs.py](tools/review_docs.py), 검사 7종)를 만들어
  이 저장소 문서의 결함을 실제로 잡아 고쳤다.
- 검증 중 **침묵하는 거짓 통과**를 발견해 막았다(§4-1). 이게 이번 작업에서 제일 중요한 발견이다.

**막힌 일 (중요)**
- **원본 문서 검수를 하지 못했다.** 원본 저장소 `haejoonlim/soul-commander`가 **비공개**이고
  이 머신에 GitHub 자격증명이 없어서, 원본 GDD·PLAN·JSON을 한 줄도 읽지 못했다.
- 그래서 "전체 문서 검수"는 **이 새 저장소의 문서에 대해서만** 끝났다.
  원본 문서에 대한 검수는 §3을 해소한 뒤 [docs/DOC_REVIEW.md](docs/DOC_REVIEW.md) §5 절차로 이어서 하면 된다.

**지금 이 저장소가 말하는 숫자는 전부 2차 인용(원본 미검증)이다.** `130`, `0.05`, `0.95`, `D-265`, `D-267`을
확정 수치로 쓰지 말 것 (§4-2).

---

## 1. 문서 지도 — 무엇을 언제 읽나

| 문서 | 언제 읽나 |
|---|---|
| **HANDOFF.md** (이 문서) | 제일 먼저. 현재 상태·차단·다음 할 일 |
| [README.md](README.md) | 프로젝트 개요, 폴더 구조, 실행 명령 |
| [SETUP.md](SETUP.md) | 환경 재현, 렌더러 결정, GUT 실행법 |
| [docs/DEV_PLAN.md](docs/DEV_PLAN.md) | 게임 개발 플랜. Phase 0~5, WBS, 게이트, 리스크 |
| [docs/DOC_REVIEW.md](docs/DOC_REVIEW.md) | 무엇을 검수했고 무엇이 불가한지, 검수 절차 |
| [MIGRATION_PLAN.md](MIGRATION_PLAN.md) | 원본에서 무엇을 가져오고 무엇을 버리는지 |
| [docs/GODOT_PORTING_MAP.md](docs/GODOT_PORTING_MAP.md) | 원본 코드 → GDScript 매핑표 |
| [data/README.md](data/README.md) | JSON 이관 규칙, manifest가 아직 추정이라는 경고 |

---

## 2. 지금 상태 (전부 이 머신에서 실측)

| 항목 | 상태 | 근거 |
|---|---|---|
| 개발 환경 | 완료 | `./.venv/bin/python tools/check_env.py --strict` → **exit 0** |
| Godot 프로젝트 | 열림·임포트됨 | `godot --headless --import` → exit 0 |
| GUT 테스트 | **2 스크립트 / 6 테스트 / 6 통과 / 8 단언** | `./tools/test_godot.sh` → **exit 0** |
| Python 게이트 | 통과 | `./.venv/bin/python tools/gate_all.py` → exit 0 |
| 필수 산출물 | 25종 존재 검사 | `tools/check_docs.py` |
| 문서 검수 도구 | 7종 검사 동작 | `tools/review_docs.py` |
| Godot 시뮬 코드 | `gacha.gd`, `combat.gd` 스텁만 | 수치 미검증 |
| 3D 월드 | **없음** | `scene/` 이 타이틀 자리표시자뿐 |
| 원본 이관(데이터) | **0건** | `data/*.json` 없음, `godot/data/` 비어 있음 |
| 원본 문서 검수 | **불가** | 원본 저장소 접근 차단 |

**되는 것**: Godot 프로젝트가 열리고, GUT 6개가 통과하고, 숫자 게이트가 돈다.
**안 되는 것**: 게임을 플레이할 수 없다. 원본 데이터·문서가 없어서 게임 내용은 아직 없다.

---

## 3. 차단 사항 — 원본 저장소 접근 (제일 먼저 뚫을 것)

**무엇이 막혔나**
원본 게임의 단일 진실 공급원(SSOT)인 문서와 설정이 `haejoonlim/soul-commander`(**비공개**)에 있는데,
이 머신에서 그 저장소를 읽을 방법이 없다 (원본 미검증).

**어떻게 확인했나 (추측 아님, 실제로 돌린 결과)**

| 확인 | 결과 |
|---|---|
| GitHub REST API `/repos/haejoonlim/soul-commander` | **404 Not Found** |
| GitHub REST API `/users/haejoonlim/repos` | 같은 계정의 다른 저장소(`haejoonlim/hive`, `haejoonlim/Limagination`)는 정상 반환 → **저장소는 있으나 비공개** |
| `gh` CLI | **설치돼 있지 않음** |
| git 자격증명 | `~/.netrc` 없음, macOS 키체인에 github.com 항목 없음. `credential.helper` 미설정, `~/.config/gh` 없음 |
| Freebuff GitHub 연동 상태 | **`connected: false`** — 계정에 아직 붙어 있지 않음 (이번 세션에서 조회) |
| `SSH_AUTH_SOCK` / `ssh-add -l` | 소켓은 있으나 `The agent has no identities` → **SSH 키 없음** |
| `git ls-remote git@github.com:haejoonlim/soul-commander.git` | `Permission denied (publickey)` |
| `FREEBUFF_GIT_DIR` | 앱에 번들된 `git` 실행 경로 — 자격증명이 아님 |
| Freebuff GitHub 연동을 켠 뒤 재확인 | 로컬 셸은 변화 없음: `gh` 없음 · 자격증명 파일 없음 · SSH 키 없음 · API 응답도 비인증과 같음 → **연동은 계정 쪽에만 있고 셸로 자격증명이 내려오지 않는다** |
| 로컬 클론 | 없음. Spotlight와 전체 트리 검색에서 `soul-commander`, `GDD_v8` 결과 없음 |
| 이전 세션 대화 기록 | 원본 문서 **본문이 남아 있지 않음**. 파일 경로 참조와 새로 쓴 스캐폴드만 복구됨 |

**해소 방법 (아무거나 하나, 위에서부터 권장)**

1. **로컬 클론 후 경로를 알려주기** — 제일 확실하다. 셸에 자격증명이 필요 없다.
   ```bash
   git clone git@github.com:haejoonlim/soul-commander.git ~/soul-commander
   ```
   그러면 `~/Desktop/폰즈`에서 바로 이관할 수 있다 (명령은 §7).
2. **zip 우회** — GitHub 웹에서 `Code → Download ZIP`을 받아 바탕화면에 풀고 경로를 알려준다. 역시 자격증명이 필요 없다.
3. **PAT 파일 우회** — Personal Access Token을 **채팅에 붙이지 말고 파일로 저장**한 뒤 경로만 알려준다. 그 파일로 클론한다(값은 출력하지 않는다).
4. **Freebuff GitHub 연동** — 이전 세션은 이 방법으로 읽었다고 기록했다. 다만 이번에 측정한 사실은 표 마지막 줄과 같다: 연동을 켠 뒤에도 셸에는 자격증명이 내려오지 않았고, 이 빌드에는 저장소를 읽는 GitHub 도구도 노출되지 않았다.
5. **문서만 붙여주기** — GDD 00~09/99, `fons-web-ver/PLAN.md`를 채팅에 붙여도 된다 (경로·번호는 원본 미검증).

**해소되면**: §7 순서를 그대로 따른다. §7의 1번(manifest 대조)을 건너뛰면 안 된다.

---

## 4. 함정 — 절대 잊으면 안 되는 것

### 4-1. 침묵하는 거짓 통과 (이번에 발견한 최악의 함정)

새로 클론한 상태(임포트 캐시 `.godot` 없음)에서 GUT를 그냥 돌리면:

```
ERROR: Some GUT class_names have not been imported. Please restart the Editor or run godot --headless --import
```

를 찍고 **테스트를 하나도 실행하지 않은 채 `exit 0`** 으로 끝난다.

이전 세션이 기록한 "2 scripts / 6 tests / 6 passing"은 **그 상태에서는 재현되지 않았다**.
지금은 [tools/test_godot.sh](tools/test_godot.sh)가 임포트를 먼저 하고, 끝나고 junit 결과를 읽어
**테스트가 0건이면 실패로 처리**한다. GUT를 직접 돌리지 말고 이 스크립트를 쓴다.

### 4-2. 숫자는 전부 2차 인용

`130`, `0.05`, `0.95`, `D-265`, `D-267`은 이전 세션이 원본 일부를 보고 옮겨 적은 값이다 (원본 미검증).
**D-265/D-267이 무엇을 결정한 것인지 그 정의문은 아무도 읽지 않았다.**
원본 대조 전까지 밸런스 근거로 쓰거나 문서에 확정 수치로 적지 말 것.
자세한 목록은 [docs/DOC_REVIEW.md](docs/DOC_REVIEW.md) §3.

### 4-3. 같은 값이 세 곳에 따로 박혀 있다

`130`/`0.05`/`0.95`가 `sim/gacha.py`, `godot/scripts/sim/gacha.gd`, `godot/tests/test_gacha.gd`에
각각 하드코딩돼 있고, **테스트가 자기 복사본을 검사**하므로 드리프트를 절대 못 잡는다.
**지금 통합하면 안 된다** — 아직 대조하지 않은 숫자를 단일 소스로 굳혀버린다.
순서는 고정: ①원본 대조 → ②값 확정 → ③단일 소스화 + 테스트.

### 4-4. 렌더러를 바꾸지 말 것

`gl_compatibility`로 고정했다. Intel macOS에서 Forward+/Mobile은 MoltenVK를 거치고
Godot 4.7에서 검은 화면·Vulkan device loss 보고가 있다. 바꾸면 화면이 안 나올 수 있다.
바꿀 거면 [docs/DEV_PLAN.md](docs/DEV_PLAN.md) §4와 [SETUP.md](SETUP.md)의 손실 목록을 먼저 읽을 것.

### 4-5. `data/manifest.json`은 추정 목록이다

원본 트리와 **한 번도 대조한 적이 없다**. 이 목록을 믿고 복사하면 파일이 조용히 빠진다.
`tools/sync_data.py`는 없는 파일을 건너뛰고도 `exit 0`으로 끝난다. 대조가 먼저다.

### 4-6. 문서 검수기는 advisory(권고)이지 게이트가 아니다

`tools/review_docs.py`를 `tools/gate_all.py`에 하드 게이트로 넣지 말 것.
원본 미검증 주장이 남아 있는 동안은 지적이 0이 아닌 게 정상이다.
목표는 0건이지만, 강제는 원본 대조가 끝난 뒤에 한다.

### 4-7. 버전 관리 규칙

- **커밋한다**: `.uid` 파일(Godot 4.4+ 스크립트 UID), `godot/project.godot`, 테스트.
- **커밋하지 않는다**: `.godot/`(임포트 캐시), `.gut_junit.xml`, `.venv/`, `build/`, `*.app`, `*.dmg`.
- Unity 잔재(`*.meta`, `ProjectSettings/`)는 절대 이 저장소에 들어오면 안 된다.

---

## 5. 작업 환경 (실측값)

| 도구 | 버전 | 비고 |
|---|---|---|
| Godot | `4.7.2.stable.official.ed1daf0bf` | `/Applications/Godot.app` → `~/.local/bin/godot` |
| Blender | `4.5.14 LTS` | 에셋 재제작용 |
| ffmpeg / ffprobe | `9.0.2` | `~/.local/bin` |
| git-lfs | `3.8.0` | 대용량 바이너리 |
| git | `2.37.1` (Apple Git-137.1) | |
| Python | `3.9.6` | 프로젝트 venv `./.venv` |
| GUT | `9.6.1` (벤더링) | 실행 끝에 뜨는 9.7.1은 **상류 공지**지 설치본 버전이 아니다 |
| 익스포트 템플릿 | `4.7.2.stable` (35파일) | `~/Library/Application Support/Godot/export_templates/` |

머신: macOS 12.7.6, Intel x86_64 (i5-6500).
재현 명령과 재설치 절차는 [SETUP.md](SETUP.md).

---

## 6. 지금 당장 할 일 (원본 없이 가능)

우선순위 순. 원본이 없어도 진행 가능한 것들이다.

1. **git 원격 만들기** — §10. (git 저장소는 이미 `main` 브랜치로 초기화돼 있다)
2. **3D 최소 신 만들기** (Phase 3) — 타이틀 → 영지 → 탐험 순.
   3D 성능을 **지금 측정**해야 한다. 60fps 목표는 목표일 뿐 검증된 값이 아니다.
   렌더 스케일 1.0 / MSAA 2x로 시작해서 실측할 것.
3. **측정 자동화** — 스크립트화한 검증(`tools/test_godot.sh`, `tools/gate_all.py`)을
   CI(GitHub Actions)에 올려서 사람이 잊어도 돌게 만들기.
4. **에셋 파이프라인 확정** — Blender 4.5 → **glTF/`.glb`** 내보내기로 통일.
   `.blend` 직접 임포트는 Blender 설치를 전제하므로 CI/인수인계에 불리하다.
5. **익스포트 프리셋** — `macOS` 프리셋 + 애드혹 서명으로 로컬 `.app` 빌드까지 뚫기.
   (명령은 [SETUP.md](SETUP.md)에 있다. `build/` 디렉터리를 먼저 만들어야 한다)

---

## 7. 원본 확보 직후 할 일 (순서 고정, 건너뛰지 말 것)

1. **manifest 대조** — `data/manifest.json`의 파일 목록을 원본 트리와 먼저 대조한다.
   복사보다 대조가 먼저다. 없는 파일을 조용히 건너뛰는 사고를 막는다.
   ```bash
   # 원본을 ~/soul-commander에 클론했다고 가정
   ls ~/soul-commander/unity/Assets/Resources/Data/ > /tmp/original_data.txt
   # manifest와 diff → 목록을 확정한 뒤에만 아래를 실행
   ./.venv/bin/python tools/sync_data.py --src ~/soul-commander/unity/Assets/Resources/Data --dst data
   ./.venv/bin/python tools/sync_data.py --src ~/soul-commander/unity/Assets/Resources/Data --dst godot/data
   ```
2. **원본 문서 이관** — GDD 00~09/99, `fons-web-ver/PLAN.md`, `GAME_PLAN_3D.md` (경로는 원본 미검증),
   `unity/PORTING_MAP.md`, `loop/` 인수인계 문서를 `docs/` 아래로 복사한다.
3. **D-265 / D-267 정의문 확인** — 그리고 이 저장소의 모든 전사(轉寫)를 고치거나 지운다.
   `130`/`0.05`/`0.95`가 원본과 같은지 한 줄씩 대조한다.
4. **수치 게이트 재현** — 원본 `verify_*.mjs`의 기대값과 이 저장소의 `sim`/`tests` 값을 맞춘다.
5. **문서 검수 절차 실행** — [docs/DOC_REVIEW.md](docs/DOC_REVIEW.md) §5에 순서가 있다.
6. **값 단일 소스화** — §4-3의 ①→②→③이 끝난 뒤에만.
7. **`review_docs.py`를 하드 게이트로 승격** — 남은 주장이 전부 확정 또는 `원본 미검증` 표기된 뒤에.

---

## 8. 이 문서 작성 시점 검증 로그 (실제 실행 결과)

```
$ ./.venv/bin/python tools/check_env.py --strict
  [ OK ] godot    4.7.2.stable.official.ed1daf0bf
  [ OK ] git      git version 2.37.1 (Apple Git-137.1)
  [ OK ] blender  Blender 4.5.14 LTS
  [ OK ] ffmpeg   ffmpeg version 9.0.2
  [ OK ] ffprobe  ffprobe version 9.0.2
  [ OK ] git-lfs  git-lfs/3.8.0
  [ OK ] templates 4.7.2.stable (35 files)
  [ OK ] .venv/bin/python -> Python 3.9.6
  OK: all required tools present (0 optional missing)          exit 0

$ ./.venv/bin/python tools/gate_all.py
  DOCS OK: 25 files present
  GATE OK: W0 pulls=130 expected_shaped=6.5 legacy=0.95
  GATE ALL OK                                                   exit 0

$ ./tools/test_godot.sh
  Scripts 2 / Tests 6 / Passing Tests 6 / Asserts 8
  ---- All tests passed! ----
  OK: GUT 6 tests passed (junit: .../godot/.gut_junit.xml)      exit 0

$ ./.venv/bin/python tools/review_docs.py
  문서 11개 / 검사 7개 (실행 7, 건너뜀 0)
  BROKEN_REFERENCE 0 / BROKEN_LINK 0 / DUPLICATE_H1 0 / DANGLING_SSOT 0
  NUMBER_CONFLICT 0 / CONST_DRIFT 0
  UNVERIFIED_CLAIM 1   (아래 참고 — 알려진 오탐)
  요약: 발견 1건 / 면제 432건 / 상수 10개 대조                  exit 1 (advisory)
```

검수 지적은 **38건 → 24건 → 9건 → 1건**으로 줄었다. 줄인 방법은 두 가지뿐이다:
문서를 고쳤거나, 검사기의 **규칙이 실제로 틀렸던 지점**을 바로잡았거나.
후자는 세 곳이었다 — 결정 번호(`D-265`)를 숫자 주장으로 오인하던 것,
`D-267이`처럼 한글이 붙은 결정 번호를 경계 문자(`\b`) 때문에 아예 놓치던 버그,
목록 서수의 숫자와, 우리 계획 문서 이름에 들어 있는 원본 계획 파일 이름을 원본 표지로 오인하던 것.
점수를 만들려고 검사를 약하게 만든 적은 없다.

**남은 1건은 알려진 오탐이고, 일부러 고치지 않았다.**
`HANDOFF.md` §3의 증거 표에서 GitHub API가 `404 Not Found`를 돌려준 줄이다.
이 검사는 "원본 저장소를 언급하는 줄에 숫자가 있으면 숫자 주장으로 본다"는 줄 단위 규칙이라
**내가 직접 측정한 사실**과 **원본에서 옮겨 적은 주장**을 구분하지 못한다.
그 줄에 `원본 미검증`을 붙이면 거짓이 되므로 붙이지 않았고,
검사기를 통과시키려고 문서를 검사기에 맞춰 고치는 것도 하지 않았다.
그 줄을 보게 되면: 그건 원본 내용에 대한 주장이 아니라 이 머신에서 측정한 HTTP 응답이다.

---

## 9. 위험과 미해결

| 위험 | 영향 | 완화 |
|---|---|---|
| 원본 문서 접근 차단 | 게임 내용·수치 전부 미확정 | §3 해소. 그 전까지 원본 관련 서술은 전부 `원본 미검증` 표기 |
| Intel macOS 렌더러 불확실성 | 화면이 아예 안 뜰 수 있음 | `gl_compatibility` 고정, 3D 시작 전에 실제 기기에서 먼저 확인 |
| 3D 성능 미검증 | 60fps 목표가 안 나올 수 있음 | Phase 3에서 **측정**. 목표를 보장으로 말하지 말 것 |
| 수치 오전사 | 밸런스가 원본과 달라짐 | 원본 대조 전 확정 수치 사용 금지 (§4-2) |
| 자산 재제작 비용 | 스케줄 폭발 | 문서에 날짜 약속을 쓰지 않았다. 규모(S/M/L)만 적었다 |
| 사람이 검증을 잊음 | §4-1 부류의 거짓 통과 재발 | `tools/test_godot.sh`의 junit 가드 + CI (§6-3) |
| manifest 누락 | 설정 파일이 조용히 빠짐 | §7-1 대조를 복사보다 먼저 |

미해결로 남겨둔 것: **상수 3중 하드코딩**(§4-3)은 의도적으로 안 고쳤다. 원본 대조 후가 맞는 순서다.

---

## 10. 새 GitHub 원격 만들기

로컬 저장소는 이미 `~/Desktop/폰즈`에 `main` 브랜치로 초기화돼 있고 첫 커밋이 있다.
원격은 **자격증명이 없어 이 머신에서 만들지 못했다.** 아래는 원격을 만든 뒤 실행할 명령이다.

```bash
# 원격 저장소 생성 (gh CLI가 있을 때, 이름은 폰즈에 맞춰 정한다)
gh repo create haejoonlim/<레포명> --private -d "폰즈 (FONS) — Godot 재구축"

cd ~/Desktop/폰즈
git remote add origin git@github.com:haejoonlim/<레포명>.git
git push -u origin main
```

주의: 원본 저장소 `haejoonlim/soul-commander`는 **비공개**다. 새 저장소도 기본은 비공개를 권한다 —
원본 미검증 내용과 내부 계획 문서가 들어 있기 때문이다.

---

## 부록 A. 알아둔 원본 구조 (**원본 미검증** — 파일 경로만, 내용은 읽지 못함)

이 표는 `soul-commander` 저장소의 **경로만** 본 기록이다. 내용은 못 읽었다.

| 원본 경로 | 내용 (원본 미검증) | 처분 |
|---|---|---|
| `design-docs/GDD_v8.0_00~09, 99` | GDD 본문 (원본 미검증) | `docs/gdd/`로 복사 |
| `fons-web-ver/PLAN.md`, `GAME_PLAN_3D.md` | W0~W4, G0~G4 플랜과 검증표 | `docs/web-plan/`으로 복사 |
| `unity/Assets/Resources/Data/*.json` | 설정 JSON | `data/`로 복사, Godot은 `godot/data/` |
| `fons-web-ver/app/src/*.ts` | 시뮬 코어 (game/combat/summon/party/estate/tower/economy) | `godot/scripts/sim/*.gd`로 포팅 |
| `fons-web-ver/app/src/game3d/*` | 3D 상태·신 개념 | `godot/scripts/world/*.gd`로 포팅 |
| `fons-web-ver/verify_*.mjs` | 숫자 검증 게이트 (개수 원본 미검증, "20여개"로 기억) | `godot/tests/*.gd` + `tools/gate_all.py` |
| `unity/Assets/Scripts/**` (C#) | 게임 로직 전체 | **버림** — GDScript로 재작성 |
| `unity/Assets/Art`, `Prefabs`, `Scenes` | 에셋 | **버림** — 재제작 |
| `unity/PORTING_MAP.md` | Godot 매핑 초안 | `docs/GODOT_PORTING_MAP.md`로 승계 |
| `loop/HANDOFF.md`, `STATUS.md`, `인수인계_2026-09-27.md` | 인수인계 (원본 미검증) | `docs/handoff/`로 아카이브 |
| `fons-launcher/` | macOS 런처 | 범위 밖 |

**이 표를 근거로 파일을 복사하지 말 것.** §7-1의 대조가 먼저다.
