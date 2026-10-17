# 문서 지도 — 폰즈 (FONS)

읽는 순서만 정해 두면 나머지는 필요할 때 찾으면 된다.

## 처음 오는 사람

| 순서 | 문서 | 왜 |
|---|---|---|
| 1 | [HANDOFF.md](../HANDOFF.md) | 현재 상태·함정·다음 할 일 |
| 2 | [README.md](../README.md) | 개요, 폴더 구조, 실행 명령 |
| 3 | [SETUP.md](../SETUP.md) | 환경 재현, 렌더러 결정, GUT 실행법 |
| 4 | [docs/original/00_읽는법.md](original/00_읽는법.md) | **수치의 근거가 되는 사실표** — 값을 확인할 때 여기서 시작 |

## 문서 종류

```
docs/
  original/     원본 저장소를 읽고 대조한 사실표 — 여기가 값의 근거다 (수정 금지, 갱신만)
  gdd/          원본 기획서 복사본 — 문면 그대로 (수정 금지)
  dev/          개발 계획·포팅 매핑·문서 검수 기록
  l10n/         용어집·표기 스타일가이드 — 이름과 문장의 규칙
  design/       2D 우선 설계와 그 작업 프롬프트
  adr/          결정 기록 — 왜 이 구조인가
  art/          아트 바이블 (시각 규칙의 정본)
  audio/        오디오 가이드 (믹싱·포맷 규칙의 정본)
```

### dev/

| 문서 | 내용 |
|---|---|
| [DEV_PLAN.md](dev/DEV_PLAN.md) | Phase 0~5, WBS, 게이트, 리스크 |
| [GODOT_PORTING_MAP.md](dev/GODOT_PORTING_MAP.md) | 원본 TS/C# → GDScript 매핑표 |
| [DOC_REVIEW.md](dev/DOC_REVIEW.md) | 무엇을 검수했고 무엇이 남았는지 |
| [STRUCTURE_RESEARCH.md](dev/STRUCTURE_RESEARCH.md) | 폴더 구조를 이렇게 짠 근거 (공식 문서·실제 프로젝트 사례) |
| [DESKTOP_LAUNCHER.md](dev/DESKTOP_LAUNCHER.md) | 바탕화면 `폰즈.app` 실행기의 동작·재생성 절차 |
| [KOREAN_TEXT.md](dev/KOREAN_TEXT.md) | 한국어 문장 검사 스킬 3종 — 설치 위치·적용 순서·적용 범위 |

### l10n/

| 문서 | 내용 |
|---|---|
| [용어집.md](l10n/용어집.md) | 정본 표기 목록 — 시스템 용어·재화·영지·미션·종족·바이옴·직업·폐기 표기 |
| [표기_스타일가이드.md](l10n/표기_스타일가이드.md) | 띄어쓰기·수치·외래어·어조·직업 설명문 규칙 |
| [번역투_교정_예시.md](l10n/번역투_교정_예시.md) | GDD 산문 교정 기록 — 측정·패턴·전후 문장·변경률 |
| [UI_문구_규칙.md](l10n/UI_문구_규칙.md) | 버튼·에러·툴팁·토스트 문구 규칙과 예시 |

### design/

| 문서 | 내용 |
|---|---|
| [PLAN_2D_FIRST.md](design/PLAN_2D_FIRST.md) | 2D 먼저 → 3D 전환 비용을 낮추는 설계 |
| [PROMPT_2D_FIRST.md](design/PROMPT_2D_FIRST.md) | 그 설계를 실행하는 작업 프롬프트 |
| [키워드_설계안_38차.html](design/키워드_설계안_38차.html) | 직업 키워드 최종안 — 회피율 폐지 → 민첩=이동속도 · 철벽기사 확정 (생성물) |
| [키워드_설계안_42차.html](design/키워드_설계안_42차.html) | 이름 톤 정리 — 중갑·연타·쇄도·헌신·부식·사역사·창술사·주술사·땜장이 (생성물) |

### adr/ — 결정 기록

| 번호 | 결정 |
|---|---|
| [0001](adr/0001-repo-layout.md) | 레포 구조: 엔진 프로젝트를 `godot/` 로 격리, 내부는 기능별 |
| [0002](adr/0002-data-ssot.md) | 데이터 정본은 JSON 하나, 사본은 생성물 |
| [0003](adr/0003-2d-first-vector3-sim.md) | 심은 `Vector3` 로만 말하고 뷰가 축을 접는다 |
| [0004](adr/0004-renderer-gl-compatibility.md) | 렌더러는 `gl_compatibility` 고정 |

## 규칙

1. **같은 사실을 두 곳에 적지 않는다.** 수치는 `docs/original/`, 시각 규칙은 `adr`·`art`, 구조는 `adr` 이 정본이다.
   다른 문서는 링크로 가리킨다.
2. **`docs/gdd/` 와 `docs/original/` 은 원본 문면이다.** 고치지 않는다. 원본이 바뀌면 다시 옮긴다.
3. **결정을 뒤집을 때는 ADR 을 새로 쓴다.** 기존 ADR 을 고쳐 쓰면 왜 바뀌었는지가 사라진다.
4. 문서 검사는 `./.venv/bin/python tools/review_docs.py` 로 돌린다 (advisory — 발견이 0이 아니어도 빌드 실패는 아니다).
