# 99 — 운영 가이드: 게이트·러너·검사 (Godot)

> 이 저장소(Godot 4.7.2 재구축)에서 커밋 전에 무엇을 돌리는지 정리한 문서.
> 원본(Unity) 시절의 게이트·러너 기록은 Unity 전용이라 삭제했다 — 현행 도구는 아래 셋으로 대체됐다.

## 0. 언제 무엇을 돌리는가

| 상황 | 명령 | 시간 | 판정 |
|---|---|---|---|
| 커밋 전 전부 | `./.venv/bin/python tools/gate_all.py` | 수십 초 | exit 0 필수 |
| 문서·용어만 | `check_docs.py` → `check_glossary.py` → `review_docs.py` | 수 초 | 앞 둘은 차단, review 는 advisory |
| Godot 코드 | `./tools/test_godot.sh` | 임포트 포함 수십 초 | GUT 통과 |
| 환경 점검 | `./.venv/bin/python tools/check_env.py --strict` | 수 초 | exit 0 |
| 데이터 이관 | `tools/sync_data.py --src <원본 데이터 폴더> --dst data` | 수 초 | 17종 |
| 수치 시뮬 | `./.venv/bin/python sim/gacha.py` | 수 초 | 확률표 재현 |
| 시뮬 센터 | `./.venv/bin/python sim/center/server.py 8741` | 상주 | `/api/sims` |

## 1. gate_all.py — 커밋 전 통합 게이트

```bash
./.venv/bin/python tools/gate_all.py
./.venv/bin/python tools/gate_all.py --history     # 최근 런 추이
```

단계는 순서대로 돌고, 하나가 실패해도 나머지를 끝까지 돌린다. 실패한 단계만 요약한다.

1. `docs` — 필수 산출물·구조·데이터 (`check_docs.py`)
2. `glossary` — 용어집 표기 ↔ 정본 대조 (`check_glossary.py`)
3. `gacha` — 확정 #32 확률표 재현 (`sim/gacha.py`)

매 런은 `tools/gate_ledger.jsonl`(gitignore)에 한 줄씩 남는다. 로그 기록이 실패해도 판정에는 영향이 없다. 시뮬 센터의 [🛡 게이트 상태] 탭이 이 파일을 읽는다.

## 2. test_godot.sh — 임포트 → GUT

```bash
./tools/test_godot.sh
```

**왜 두 단계인가.** 새 클론(.godot 캐시 없음)에서 GUT를 바로 돌리면 "Some GUT class_names have not been imported"만 찍고 **테스트 0건으로 exit 0** 이 된다. 침묵하는 거짓 통과다. 그래서 ① `godot --headless --import` ② GUT 실행 ③ junit의 `tests=` 가 1 이상인지 확인, 셋을 한 스크립트에 묶었다.

## 3. review_docs.py — 문서 기계 검수 (advisory)

```bash
./.venv/bin/python tools/review_docs.py
./.venv/bin/python tools/review_docs.py --json tools/review_report.json
```

검사 7종: 깨진 참조 · 깨진 링크 · 중복 H1 · SSOT 미지목 · 수치 충돌 · 상수 드리프트 · 출처 없는 수치 주장.
**발견 0을 목표로 한다.** advisory라 빌드를 막지는 않는다.

## 4. check_glossary.py — 용어 표기 정본 대조

```bash
./.venv/bin/python tools/check_glossary.py
./.venv/bin/python tools/check_glossary.py --list   # 검사 대상 표기
```

[docs/l10n/용어집.md](../l10n/용어집.md) 의 모든 코드 표기가 `data/*.json` · `docs/gdd/*.md` 에 실제로 있는지 본다. 없는 이름을 지어내면 exit 1.

## 5. check_env.py — 툴체인 점검

```bash
./.venv/bin/python tools/check_env.py --strict
```

필수: `godot` · `git`. 선택: `blender` · `ffmpeg` · `ffprobe` · `git-lfs`. `--strict` 는 선택 도구 누락도 실패로 본다.

## 6. sync_data.py — 데이터 이관

```bash
./.venv/bin/python tools/sync_data.py --src <원본 데이터 폴더> --dst data
./.venv/bin/python tools/sync_data.py --src <원본 데이터 폴더> --dst godot/data
```

`data/` 와 `godot/data/` 는 **같은 17종의 사본**이다. 이관 뒤 `check_docs.py` 의 `MIRROR OK` 가 두 폴더가 동일한지 확인한다.

## 7. 시뮬 센터

```bash
./.venv/bin/python sim/center/server.py 8741
```

페이지는 `sim/center/pages/`, 시뮬은 `sim/center/sims/`. API 목록은 `/api/sims`. 페이지는 정적 HTML이라 서버 없이도 열린다.

## 8. 트러블슈팅

| 증상 | 원인 | 조치 |
|---|---|---|
| GUT가 0건인데 성공 | 임포트 캐시 없음 | `tools/test_godot.sh` 사용 (직접 호출 금지) |
| `GLOSSARY FAIL` | 용어집에 데이터에 없는 표기 | 데이터에 먼저 넣거나 표기를 고친다 |
| `MIRROR` 불일치 | `data/` 만 고침 | `sync_data.py` 로 양쪽 동기화 |
| `review_docs` 수치 발견 | 출처 표시 누락 | `원본 대조` · `자체 실측` 표시 추가 |
| gate 원장이 이상 | 반쯤 쓰인 줄 | 원장은 반쯤 쓴 줄을 건너뛰도록 되어 있다 — 그대로 둔다 |
