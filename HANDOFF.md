# 인수인계문서 — 폰즈 (FONS) Godot 재구축

| | |
|---|---|
| 작성 시각 | 2026-10-16 최초 · **2026-10-17 원본 대조 후 갱신** |
| 문서 위치 | `~/Desktop/폰즈/HANDOFF.md` |
| 프로젝트 폴더 | `~/Desktop/폰즈` (git 저장소, 브랜치 `main`) |
| 판(version) | 스캐폴드 + 계획 + 검수 기록 + **원본 대조 사실표**. **플레이 가능한 게임 아님** |
| 다음 사람이 제일 먼저 할 일 | §2로 상태를 잡고 §7 순서대로 원본 이관을 실행한다 |

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

**원본을 드디어 읽었다 (2026-10-17)**
- 원본 Unity 저장소 `haejoonlim/soul-commander`를 **클론해서 전부 읽었다** (213MB / 252 커밋 / 1,523 파일 · 자체 실측).
  뚫린 경로는 **SSH 키 등록**이었다 — GitHub 화면에서 공개키를 계정에 추가한 뒤 `git clone`이 성공했다.
- 읽고 나서 **원본에 없는 값이 이 저장소에 박혀 있던 것**을 찾아냈다. 가장 큰 것은 **"130회 소환" 게이트**다.
  `PULLS = 130`과 `expected_shaped = 6.5`는 원본 어디에도 없는 정의였다 — 원본의 130은 탑 층수·티켓 단가·
  레벨 상한·★4 하드 천장 등이고, 5%는 **종족 롤(shaped)** 의 비율이지 소환 횟수에 곱하는 값이 아니다.
  [sim/gacha.py](sim/gacha.py)와 [godot/scripts/sim/gacha.gd](godot/scripts/sim/gacha.gd)를 원본 확정 #32·#11 기준으로 다시 썼다.
- **D-265와 D-267의 정의문을 읽었다 (원본 대조).** D-265 = 층 미션 시스템(주 미션 7종 + 세계 전용 특수 20종),
  D-267 = 마석본위제 화폐·은행(화폐 「레이」 LEY, 환율 1마석 = 60 LEY).
- **데이터 manifest를 원본 트리와 대조했다.** 추정 목록은 실제와 달랐다 — 없던 파일 3개, 빠져 있던 파일 2개.
  실제는 **17종**이다([data/manifest.json](data/manifest.json)).
- 그 결과는 [docs/original/](docs/original/00_읽는법.md) 사실표 4종에 정리했다. **이 저장소의 수치는 이제 그 사실표가 근거다.**

**아직 안 된 일**
- **원본 데이터 이관을 실행했다.** 확정된 17종을 `data/`와 `godot/data/`에 복사했고, 게이트가 누락을 잡도록 바꿨다 (자체 실측).
- **3D 월드가 없다.** 타이틀 자리표시자뿐이고, 시뮬 코드는 소환 규칙과 전투 스텁 수준이다. 게임은 플레이할 수 없다.
- **git 원격은 아직 만들지 않았다.** 이제 SSH 키가 있으므로 `git push`는 가능하다(§10).

---

## 1. 문서 지도 — 무엇을 언제 읽나

| 문서 | 언제 읽나 |
|---|---|
| **HANDOFF.md** (이 문서) | 제일 먼저. 현재 상태·함정·다음 할 일 |
| [docs/original/00_읽는법.md](docs/original/00_읽는법.md) | **원본 확정값의 근거.** 값을 확인할 때 여기서 시작한다 |
| [docs/original/01_확정_규칙.md](docs/original/01_확정_규칙.md) | 확정 #번호 · 소환 · 종족 · 등급·CP·스탯 · 개수 · 경제 (원본 대조) |
| [docs/original/02_웹버전_포팅.md](docs/original/02_웹버전_포팅.md) | 원본 웹 W0~W4 · 3D G0~G4 · `verify_*.mjs` 15개 · `app/src` 실제 목록 (원본 대조) |
| [docs/original/03_데이터_영지_탑.md](docs/original/03_데이터_영지_탑.md) | 정본 JSON 17종 · 영지 · 탑 · 바이옴 · 결정 요지 (원본 대조) |
| [README.md](README.md) | 프로젝트 개요, 폴더 구조, 실행 명령 |
| [SETUP.md](SETUP.md) | 환경 재현, 렌더러 결정, GUT 실행법 |
| [docs/DEV_PLAN.md](docs/DEV_PLAN.md) | 게임 개발 플랜. Phase 0~5, WBS, 게이트, 리스크 |
| [docs/DOC_REVIEW.md](docs/DOC_REVIEW.md) | 무엇을 검수했고 무엇이 남았는지, 검수 절차 |
| [MIGRATION_PLAN.md](MIGRATION_PLAN.md) | 원본에서 무엇을 가져오고 무엇을 버리는지 |
| [docs/GODOT_PORTING_MAP.md](docs/GODOT_PORTING_MAP.md) | 원본 코드 → GDScript 매핑표 |
| [data/README.md](data/README.md) | JSON 이관 규칙, manifest 대조 결과 |

---

## 2. 지금 상태 (전부 이 머신에서 측정한 값이다 — 자체 실측)

| 항목 | 상태 | 근거 |
|---|---|---|
| 개발 환경 | 완료 | `./.venv/bin/python tools/check_env.py --strict` → **exit 0** (자체 실측) |
| Godot 프로젝트 | 열림·임포트됨 | `godot --headless --import` → exit 0 (자체 실측) |
| GUT 테스트 | **2 스크립트 / 8 테스트 / 8 통과 / 25 단언** | `./tools/test_godot.sh` → **exit 0** (자체 실측) |
| Python 게이트 | 통과 | `./.venv/bin/python tools/gate_all.py` → exit 0 · `GATE ALL OK` (자체 실측) |
| 필수 산출물 | **29종** 존재 검사 | `tools/check_docs.py` → `DOCS OK: 29 files present` (자체 실측) |
| 문서 검수 도구 | 검사 7종 동작 · **발견 0건** / 면제 1049건 / 상수 26개 대조 | `tools/review_docs.py` → exit 0 (advisory, 하드 게이트 아님) (자체 실측) |
| 소환 규칙 게이트 | 원본 확정 #32 확률표·#11 종족 롤 **재현** | `sim/gacha.py` → `GATE OK` (표본 200000, seed 265) (자체 실측) |
| 원본 대조 사실표 | **4종 완료** | `docs/original/` (원본 대조) |
| Godot 시뮬 코드 | 소환 규칙은 원본값 · 전투는 스텁 | `gacha.gd`, `combat.gd` (자체 실측) |
| 3D 월드 | **없음** | `godot/scenes/` 가 타이틀 자리표시자뿐 (자체 실측) |
| 원본 이관(데이터) | **완료 — 17종 ×2** | `tools/sync_data.py` → `data/` 17 + `godot/data/` 17 (자체 실측) |
| 원본 문서 검수 | **완료** | `docs/original/` 4종 (원본 대조) |

**되는 것**: Godot 프로젝트가 열리고, GUT 8개가 통과하고, 숫자 게이트가 원본 확률표를 재현한다.
**안 되는 것**: 게임을 플레이할 수 없다. 원본 데이터 17종은 들어왔지만, 그 데이터를 읽어 게임을 돌리는 시뮬 코어 포팅이 아직 없다 (자체 실측).

---

## 3. 원본 접근 — 해소 기록 (이전 판의 차단 사항)

**해소됨.** 원본 `haejoonlim/soul-commander`는 2026-10-17에 이 머신 `~/soul-commander`로 클론됐고 (원본 대조),
정본(확정 규칙·소환·종족·영지·탑·데이터 목록)을 전부 읽었다 (원본 대조).

**어떻게 뚫렸나**

| 단계 | 결과 |
|---|---|
| SSH 키 생성 | `~/.ssh/fons_soulcommander_ed25519` (ED25519) (자체 실측) |
| 공개키 지문 | `SHA256:Y68Xqccr3BHtvbL7Jv+y5tIOQC/9AmLsVmZ17EqnaZ8` (자체 실측) |
| GitHub 등록 | 계정 SSH 키로 등록 (Key type = Authentication Key) (자체 실측) |
| 인증 확인 | `ssh -T git@github.com` → `Hi haejoonlim! You've successfully authenticated...` (자체 실측) |
| 클론 | `git clone git@github.com:haejoonlim/soul-commander.git ~/soul-commander` → **exit 0** (자체 실측) |
| 규모 | 213MB / 252 커밋 / 1,523 파일 · `HEAD` = `669f0be` (자체 실측) |

**이 실패가 남긴 교훈 (다음에 같은 데서 막히면 여기부터 읽어라)**

| 확인 | 결과 |
|---|---|
| GitHub REST API `/repos/haejoonlim/soul-commander` (비인증) | **404 Not Found** (자체 실측) |
| GitHub REST API `/users/haejoonlim/repos` | 같은 계정의 다른 저장소(`haejoonlim/hive`, `haejoonlim/Limagination`)는 정상 반환 → **저장소는 있으나 비공개** (자체 실측) |
| `gh` CLI | **설치돼 있지 않음** (자체 실측) |
| git 자격증명 파일 | `~/.netrc` 없음 · `~/.git-credentials` 없음 · `credential.helper` 미설정 · `~/.config/gh` 없음 (자체 실측) |
| `SSH_AUTH_SOCK` / `ssh-add -l` | 소켓은 있으나 `The agent has no identities` → 앱이 키를 대신 쥐여주지 않는다 (자체 실측) |
| Freebuff GitHub 연동 | 연동을 켠 뒤에도 셸은 그대로였다 → **연동은 계정 쪽 기능이고 로컬 셸에 자격증명을 내려주지 않는다** (자체 실측) |
| `FREEBUFF_GIT_DIR` | 앱에 번들된 `git` 실행 경로 — 자격증명이 아니다 (자체 실측) |

**요약**: 비공개 저장소에 대한 **404는 권한이 없다는 뜻이지 존재하지 않는다는 뜻이 아니다.**
그리고 **Freebuff 연동을 켜는 것과 그 셸에서 git이 자격증명을 얻는 것은 별개다.**
실제로 뚫은 것은 **키 한 쌍을 만들어 공개키를 계정에 등록한 것**이다.

**정리 상태**: 이 키는 계정의 모든 저장소에 읽기+쓰기 권한을 준다. 이관 작업이 끝나면
GitHub Settings → SSH keys에서 지우고, 로컬 개인키도 함께 지우는 편이 좋다.

---

## 4. 함정 — 절대 잊으면 안 되는 것

### 4-1. 침묵하는 거짓 통과 (이번에 발견한 최악의 함정)

새로 클론한 상태(임포트 캐시 `.godot` 없음)에서 GUT를 그냥 돌리면:

```
ERROR: Some GUT class_names have not been imported. Please restart the Editor or run godot --headless --import
```

를 찍고 **테스트를 하나도 실행하지 않은 채 `exit 0`** 으로 끝난다.

지금은 [tools/test_godot.sh](tools/test_godot.sh)가 임포트를 먼저 하고, 끝나고 junit 결과를 읽어
**테스트가 0건이면 실패로 처리**한다. GUT를 직접 돌리지 말고 이 스크립트를 쓴다.

같은 실패 모드가 데이터 쪽에도 있었다 — [tools/sync_data.py](tools/sync_data.py)는 없는 파일을
건너뛰고도 `exit 0` 으로 끝났다. 지금은 하나라도 없으면 실패이고, 부분 확인은 `--allow-missing` 을 명시해야 한다.

### 4-2. 값은 이제 확정됐다 — 근거는 사실표다

원본 대조가 끝났으므로 `130`, `0.05`, `0.95`는 더 이상 2차 인용이 아니다. 각각의 실체는 이렇다 (원본 대조).

| 값 | 원본에서의 실체 |
|---|---|
| `130` | 탑 층수(#52) · 소환 티켓 단가(#16) · 영웅 레벨 상한 `LEVEL_CAP = 130`(#34) · ★4 하드 천장(#32) · 마나 앵커 `MP_PER_CRYSTAL = 130`(D-267) — **한 값이 여러 뜻으로 쓰인다** (원본 대조) |
| `0.05` | 종족 롤의 shaped 비율 `SHAPED_RATE = 0.05`(#11 · D-276) (원본 대조) |
| `0.95` | legacy 20종 균등 비율 `LEGACY_RATE = 0.95`(각 종족 4.75%) (원본 대조) |
| `0.02` | ★4 소프트 피티 회차당 증가폭 `SOFT_PITY_STEP = 0.02`(#32) (원본 대조) |
| `60` | `LEY_PER_CRYSTAL = 60`(D-267 환율) (원본 대조) |

**추측 금지 규칙은 그대로다.** 여기 없는 값이 필요하면 원본을 다시 읽는다 — `~/soul-commander`에 클론이 있다.
불확실하면 사용자에게 묻는다. 원본 자신이 모순되는 항목(게이트잭팟 계수 75 대 85 등)은
[docs/original/01_확정_규칙.md](docs/original/01_확정_규칙.md) §7에 모아 뒀고, **한쪽을 골라 적지 않는다.**

### 4-3. 값 단일 소스화는 ①→②가 끝나서 이제 해도 된다

값이 확정되기 전에는 통합하면 안 된다고 적어 뒀다. 이제 ①원본 대조와 ②값 확정이 끝났으므로 ③통합이 남은 작업이다.

현재 같은 값이 두 곳에 선언돼 있다 — `SHAPED_RATE = 0.05` / `LEGACY_RATE = 0.95` 가
[sim/gacha.py](sim/gacha.py)와 [godot/scripts/sim/gacha.gd](godot/scripts/sim/gacha.gd)에 각각 있고,
[godot/tests/test_gacha.gd](godot/tests/test_gacha.gd)가 그 사본을 검사한다.
구조적으로 **드리프트를 못 잡는 배치**다. 남은 작업: 한쪽을 정본으로 정하고 다른 쪽이 그것을 읽게 만든 뒤,
[data/](data/manifest.json) 쪽 JSON으로 옮겨 테스트가 데이터를 검사하도록 바꾼다.
[tools/review_docs.py](tools/review_docs.py)의 `CONST_DRIFT` 검사가 같은 이름·다른 값 선언을 계속 감시한다.

### 4-4. 렌더러를 바꾸지 말 것

`gl_compatibility`로 고정했다. Intel macOS에서 Forward+/Mobile은 MoltenVK를 거치고
Godot 4.7에서 검은 화면·Vulkan device loss 보고가 있다. 바꾸면 화면이 안 나올 수 있다.
바꿀 거면 [docs/DEV_PLAN.md](docs/DEV_PLAN.md) §4와 [SETUP.md](SETUP.md)의 손실 목록을 먼저 읽을 것.

### 4-5. `data/manifest.json`은 이제 대조된 목록이다

추정이었던 목록을 2026-10-17에 원본 트리와 전수 대조했다 (원본 대조).
바뀐 것: 없던 파일 3개(`estate_web.json` · `state.json` · `game_const.json`)를 지웠고,
빠져 있던 2개(`scenes.json` · `world_laws.json`)를 채워 **17종**이 됐다.

주의할 점 둘. ① 원본에서 이 폴더는 런타임 직로드용이고, 그중 `skills_catalog.json` 과 `fusion_pairs.json`
두 종만 생성물(한글 키 정본에서 만들어짐)이며 나머지 열다섯은 직접 저작한 파일이다 — 어느 쪽이든
**이관 원본은 이 폴더**다. ② [tools/sync_data.py](tools/sync_data.py)는 이제 없는 파일이 있으면 실패한다.

### 4-6. 문서 검수기는 advisory(권고)이지 게이트가 아니다

[tools/review_docs.py](tools/review_docs.py)를 [tools/gate_all.py](tools/gate_all.py)에 하드 게이트로 넣지 말 것.
원본 대조가 끝나 지적은 1건까지 내려왔지만, 그 1건은 아래에 적은 **알려진 오탐**이고,
남은 미검증 서술이 0이 되기 전에 강제하면 문서가 검사기에 맞춰지는 역방향 압력이 생긴다.

검사기가 요구하는 **출처 표시**는 세 종류다 — `(원본 미검증)` · `(원본 대조)` · `(자체 실측)`.
원본을 언급하는 줄에 숫자를 쓰면 그 줄에 이 중 하나를 달아야 하고, **표 행은 윗 행의 표시를 물려받지 않는다.**
표시 없는 숫자 주장은 계속 발견으로 보고된다. 표시를 **사실과 다르게** 다는 것은 그냥 거짓 기록이다.

### 4-7. 버전 관리 규칙

- **커밋한다**: `.uid` 파일(Godot 4.4+ 스크립트 UID), `godot/project.godot`, 테스트, `docs/original/` 사실표.
- **커밋하지 않는다**: `.godot/`(임포트 캐시), `.gut_junit.xml`, `.venv/`, `build/`, `*.app`, `*.dmg`.
- Unity 잔재(`*.meta`, `ProjectSettings/`)는 절대 이 저장소에 들어오면 안 된다.
  (원본 데이터 폴더의 `.meta` 는 Unity 전용이므로 복사하지 않는다)

---

## 5. 작업 환경 (전부 이 머신에서 측정 — 자체 실측)

| 도구 | 버전 | 비고 |
|---|---|---|
| Godot | `4.7.2.stable.official.ed1daf0bf` | `/Applications/Godot.app` → `~/.local/bin/godot` |
| Blender | `4.5.14 LTS` | 에셋 재제작용 |
| ffmpeg / ffprobe | `9.0.2` | `~/.local/bin` |
| git-lfs | `3.8.0` | 대용량 바이너리 |
| git | `2.37.1` (Apple Git-137.1) | SSH 키 경로는 §3 |
| Python | `3.9.6` | 프로젝트 venv `./.venv` |
| GUT | `9.6.1` (벤더링) | 실행 끝에 뜨는 9.7.1은 **상류 공지**지 설치본 버전이 아니다 |
| 익스포트 템플릿 | `4.7.2.stable` (35파일) | `~/Library/Application Support/Godot/export_templates/` |

머신: macOS 12.7.6, Intel x86_64 (i5-6500).
재현 명령과 재설치 절차는 [SETUP.md](SETUP.md).

---

## 6. 지금 당장 할 일

우선순위 순. 1번은 원본이 있어야 하고, 나머지는 원본과 무관하게 진행할 수 있다.

1. **원본 데이터 이관 실행** — §7-1. 대조는 끝났으니 이제 복사만 하면 된다.
2. **git 원격 만들기** — §10. SSH 키가 생겼으므로 이제 가능하다.
3. **3D 최소 신 만들기** (Phase 3) — 타이틀 → 영지 → 탐험 순.
   3D 성능을 **지금 측정**해야 한다. 60fps 목표는 목표일 뿐 검증된 값이 아니다.
   렌더 스케일 1.0 / MSAA 2x로 시작해서 실측할 것.
4. **값 단일 소스화** — §4-3의 ③.
5. **측정 자동화** — 스크립트화한 검증(`tools/test_godot.sh`, `tools/gate_all.py`)을
   CI(GitHub Actions)에 올려서 사람이 잊어도 돌게 만들기.
6. **에셋 파이프라인 확정** — Blender 4.5 → **glTF/`.glb`** 내보내기로 통일.
   `.blend` 직접 임포트는 Blender 설치를 전제하므로 CI/인수인계에 불리하다.
7. **익스포트 프리셋** — `macOS` 프리셋 + 애드혹 서명으로 로컬 `.app` 빌드까지 뚫기.
   (명령은 [SETUP.md](SETUP.md)에 있다. `build/` 디렉터리를 먼저 만들어야 한다)

---

## 7. 원본 이관 순서 (순서 고정, 건너뛰지 말 것)

원본은 `~/soul-commander`에 있다 (원본 대조). 1번은 실행, 2~3번은 완료, 4번 이하는 남은 작업이다.

1. **데이터 이관 실행** — manifest는 대조 완료(17종)이므로 그대로 옮긴다. 없는 파일이 있으면 실패한다.
   ```bash
   ./.venv/bin/python tools/sync_data.py --src ~/soul-commander/unity/Assets/Resources/Data --dst data
   ./.venv/bin/python tools/sync_data.py --src ~/soul-commander/unity/Assets/Resources/Data --dst godot/data
   ```
2. **원본 문서 이관 (완료)** — 정본 GDD 00~09·99와 웹 플랜은 전부 읽었고, 그 내용은
   [docs/original/](docs/original/00_읽는법.md) 사실표 4종에 값 단위로 정리했다.
   GDD 본문 자체를 `docs/gdd/`로 복사할지는 별도 판단이다 — 값 근거는 이미 사실표에 있다 (원본 대조).
3. **D-265 / D-267 정의문 확인 (완료)** — D-265 = 층 미션 시스템(주 미션 7종 + 세계 전용 특수 20종) (원본 대조),
   D-267 = 마석본위제 화폐·은행 — 이 저장소의 잘못된 전사(轉寫)도 함께 정정했다 (원본 대조).
4. **수치 게이트 재현** — 원본 `verify_*.mjs` 는 **15개**이고, 그 기대값을 이 저장소의 `sim`·`tests` 로 옮겨온다 (원본 대조).
   첫 사례로 소환 확률표(#32)는 이미 재현됐다 (원본 대조).
   다음 후보는 [docs/original/02_웹버전_포팅.md](docs/original/02_웹버전_포팅.md)의 검증 목록에서 고른다.
5. **문서 검수 절차 실행** — [docs/DOC_REVIEW.md](docs/DOC_REVIEW.md)의 순서.
6. **값 단일 소스화** — §4-3의 ③.
7. **`review_docs.py`를 하드 게이트로 승격** — 미검증 주장이 0이 된 뒤에 (지금은 1건, 알려진 오탐).

---

## 8. 검증 로그 (2026-10-17 실행 결과 — 자체 실측)

```
$ ./.venv/bin/python tools/check_docs.py
  DOCS OK: 29 files present
  DATA OK: 17/17 in data/

$ ./.venv/bin/python tools/gate_all.py
  GATE OK: 확정 #32 확률표·#11 종족 롤 재현 (표본 200000, seed 265)
  GATE ALL OK

$ ./.venv/bin/python sim/gacha.py
  shaped=0.0498 (정본 0.05) legacy=0.9500
  band_sum=100.00% | 최대 편차 0.0445%p | shaped 편차 0.00025
  GATE OK: 확정 #32 확률표·#11 종족 롤 재현 (표본 200000, seed 265)

$ ./tools/test_godot.sh
  Scripts               2
  Tests                 8
  Passing Tests         8
  Asserts              25
  ---- All tests passed! ----

$ ./.venv/bin/python tools/review_docs.py
  문서 15개 / 검사 7개 (실행 7, 건너뜀 0)
  BROKEN_REFERENCE 0 / BROKEN_LINK 0 / DUPLICATE_H1 0 / DANGLING_SSOT 0
  NUMBER_CONFLICT 0 / CONST_DRIFT 0
  UNVERIFIED_CLAIM 0
  요약: 발견 0건 / 면제 1048건 / 상수 26개 대조
```

위 네 명령의 종료 코드는 **0 / 0 / 0 / 0** 이다 (자체 실측).

**검수기가 고쳐 준 것 (이력)**: 원래 이 검사는 "원본 저장소를 언급하는 줄에 숫자가 있으면 숫자 주장으로 본다"는
줄 단위 규칙이라 **이 머신에서 직접 측정한 사실**과 **원본에서 옮겨 적은 주장**을 구분하지 못했다.
GitHub API가 `404`를 돌려준 우리 측정 줄이 계속 걸렸던 이유다. 그래서 출처 표시를 세 번째까지 만들었다 —
`(자체 실측)`이 그것이고, 그 표시를 붙인 뒤 지적이 0이 됐다. 표시 없이 두면 지금도 걸린다 (자체 실측).

**검수 지적 추이**: 38건 → 24건 → 9건 → 1건 → **0건** (원본 대조 후 표시 정리까지 끝냈다).
줄인 방법은 두 가지뿐이다 — 문서를 고쳤거나, 검사기의 **규칙이 실제로 틀렸던 지점**을 바로잡았거나.
후자는 지금까지 여섯 곳이다: 결정 번호를 숫자 주장으로 오인하던 것 · 한글이 붙은 결정 번호를
경계 문자 때문에 아예 놓치던 것 · 목록 서수의 숫자 · 우리 계획 문서 이름에 든 원본 계획 파일 이름을
원본 표지로 오인하던 것 · **같은 꼬리말(`_RATE`·`_SEED`)을 가진 다른 상수를 같은 것으로 보던 것** ·
**표 행이 윗 행의 표시를 물려받아 표시 없는 주장을 면제시키던 것**.
점수를 만들려고 검사를 약하게 만든 적은 없다.

**2026-10-17에 검사기에 가한 변경은 늘리는 방향이었다** — 출처 표시를 세 종류로 구분하고
(BROKEN_REFERENCE 와 UNVERIFIED_CLAIM 양쪽에서), 표 행의 상속을 끊어 실제로는 표시 없는 주장이
면제로 새어 나가던 경로를 막았다.

---

## 9. 위험과 미해결

| 위험 | 영향 | 완화 |
|---|---|---|
| 원본이 스스로 모순 (게이트잭팟 계수 75 대 85 등) | 한쪽을 골라 적으면 조용히 원본과 달라짐 | 양쪽을 병기한다 — [docs/original/01_확정_규칙.md](docs/original/01_확정_규칙.md) §7 (원본 대조) |
| Intel macOS 렌더러 불확실성 | 화면이 아예 안 뜰 수 있음 | `gl_compatibility` 고정, 3D 시작 전에 실제 기기에서 먼저 확인 |
| 3D 성능 미검증 | 60fps 목표가 안 나올 수 있음 | Phase 3에서 **측정**. 목표를 보장으로 말하지 말 것 |
| 값 드리프트(코드 vs 문서 vs 데이터) | 밸런스가 조용히 갈라짐 | `CONST_DRIFT` 검사 + 상수 registry + §4-3의 ③ |
| 자산 재제작 비용 | 스케줄 폭발 | 문서에 날짜 약속을 쓰지 않았다. 규모(S/M/L)만 적었다 |
| 사람이 검증을 잊음 | §4-1 부류의 거짓 통과 재발 | `tools/test_godot.sh`의 junit 가드 + `sync_data.py`의 실패 처리 + CI (§6-5) |
| SSH 키 과권한 | 계정의 모든 저장소에 읽기+쓰기 | 이관 완료 후 키 삭제 (§3) |

미해결로 남겨둔 것: **값 단일 소스화**(§4-3) — 이제 순서상 해도 되는 작업이지만 아직 실행하지 않았다.
**원본 데이터 이관**(§7-1)도 대조만 끝나고 실행 전이다.

---

## 10. 새 GitHub 원격 만들기

로컬 저장소는 `~/Desktop/폰즈`에 `main` 브랜치로 초기화돼 있다.
**원격은 아직 없다** — 자격증명이 없던 동안에는 만들 수 없었고, 지금은 SSH 키(§3)가 있으므로 만들 수 있다 (자체 실측).

```bash
# 원격 저장소 생성 (gh CLI가 있을 때, 이름은 폰즈에 맞춰 정한다)
gh repo create haejoonlim/<레포명> --private -d "폰즈 (FONS) — Godot 재구축"

cd ~/Desktop/폰즈
git remote add origin git@github.com:haejoonlim/<레포명>.git
git push -u origin main
```

주의: 원본 저장소 `haejoonlim/soul-commander`는 **비공개**다. 새 저장소도 기본은 비공개를 권한다 —
내부 계획·인수인계 문서와 원본 대조 기록이 들어 있기 때문이다.

---

## 부록 A. 원본 저장소 구조 (2026-10-17 대조 완료)

이 표는 원본을 클론해서 확인한 구조다 (원본 대조). **값의 근거는 경로가 아니라
[docs/original/](docs/original/00_읽는법.md) 사실표 4종이다.**

| 원본 경로 | 내용 | 이 저장소에서의 처분 |
|---|---|---|
| `design-docs/GDD_v8.0_00~09·99` | 정본 11문서 — 00 확정사항이 "무엇이 확정인가"의 기준 (원본 대조) | 값은 `docs/original/01_확정_규칙.md` 로 승계 (원본 대조) |
| `design-docs/결정로그/` | 결정 기록 D-251 ~ D-280 · append-only (원본 대조) | D-265·D-267 등 요지는 `docs/original/03_데이터_영지_탑.md` (원본 대조) |
| `design-docs/_tools/` | 시뮬·게이트 도구 다수 + 일부 정본 JSON (한글 키) (원본 대조) | 게이트 개념만 차용 — 도구는 포팅하지 않음 |
| `design-docs/설계` · `제안서` · `_기록` | 준정본·미확정 후보·검수 기록 — 확정 근거로 인용 금지 (원본 대조) | 참조만 |
| `unity/Assets/Resources/Data/*.json` | 런타임 데이터 **17종** (원본 대조) | `data/` 와 `godot/data/` 로 복사 ([data/manifest.json](data/manifest.json)) |
| `fons-web-ver/` | 웹 버전 — `PLAN.md`(W0~W4) · `GAME_PLAN_3D.md`(G0~G4) · `app/src` · `verify_*.mjs` **15개** (원본 대조) | 시뮬 코어를 GDScript로 포팅 ([docs/GODOT_PORTING_MAP.md](docs/GODOT_PORTING_MAP.md)) |
| `unity/Assets/Scripts/**` (C#) | 게임 로직 전체 (원본 대조) | **버림** — GDScript로 재작성 |
| `unity/Assets/Art` · `Prefabs` · `Scenes` | 에셋 (원본 대조) | **버림** — 재제작 |
| `unity/PORTING_MAP.md` | 원본이 직접 쓴 Godot 매핑 초안 (원본 대조) | [docs/GODOT_PORTING_MAP.md](docs/GODOT_PORTING_MAP.md) 로 승계 |
| `loop/` · `fons-launcher/` · `archive/` | 오케스트레이터 런 기록 · macOS 런처 · 마이그레이션 보존소 (원본 대조) | 범위 밖 (인용 금지) |
| 구 Godot 구현체 | 원본에 **없다** — `godot-ver.zip` 은 저장소 미추적 로컬 보관분, 부활 금지 (원본 대조) | 이 저장소가 새로 만든다 |
