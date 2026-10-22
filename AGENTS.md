# AGENTS.md — 폰즈 (FONS) 작업 규칙

에이전트가 이 저장소에서 한국어를 쓰기 전에 읽는 파일. 전체 규칙은 아니고, **말과 이름에 관한 것만** 적는다.

## 1. 용어는 등록한 것만 쓴다

정본 순위는 셋이다. 위가 이긴다.

1. `data/*.json` 의 `name` · `name_ko` — 고유명사 철자
2. `docs/gdd/GDD_v8.0_00_확정사항.md` — 시스템 용어의 뜻
3. [docs/l10n/용어집.md](docs/l10n/용어집.md) — 표기 규칙과 등록 목록

**새 고유명사(종족·직업·바이옴·시설·재화·시스템)를 쓰려면 순서를 지킨다.**

1. 데이터에 먼저 넣는다 (`name` / `name_ko`)
2. 같은 이름을 `docs/l10n/용어집.md` 에 등록한다
3. 그 다음에 코드·문서·UI에서 쓴다

등록 없이 새 이름을 만들지 않는다. 이름을 바꿀 때도 같다 — 새 이름을 등록하고, 옛 이름은 용어집의 "폐기 표기" 표로 옮긴다. 폐기 표기는 본문·UI에 다시 쓰지 않는다.

검사:

```bash
./.venv/bin/python tools/check_glossary.py
```

용어집에 적힌 표기가 정본에 실제로 있는지 본다. exit 1 이면 없는 이름을 지어낸 것이다. 통과 전에는 "용어 정리 끝"이라고 하지 않는다.

## 2. 문장 규칙

- 표기(띄어쓰기·수치·어조·직업 설명문): [docs/l10n/표기_스타일가이드.md](docs/l10n/표기_스타일가이드.md)
- 한국어 문장 다듬기: `humanizer` → `grammar-checker` → `style-guide` 순서. 설치 위치와 호출법은 [docs/dev/KOREAN_TEXT.md](docs/dev/KOREAN_TEXT.md)
- 번역투(`~에 대한`·`~를 통해`·`~되어진다`)와 AI 상투구(`결론적으로`·`핵심적으로`)를 쓰지 않는다.

## 3. 손대지 않는 곳

- `docs/gdd/` · `docs/original/` 은 원본 문면이다. 고치지 않는다 ([docs/README.md](docs/README.md) 규칙 2).
- 문서 검수는 `./.venv/bin/python tools/review_docs.py` (advisory, 발견 0을 목표로 한다).

## 4. 외부 에이전트 스킬

- 외부에서 가져온 스킬은 `.claude/skills/`에 있다. 쓰기 전에 해당 `SKILL.md`를 읽는다.
- **스킬은 조언이다.** 정본은 `data/` 와 `docs/`다. 스킬이 제시한 수치를 코드에 넣지 않는다 — 값은 등록소(`tools/tracked_numbers.json`)를 먼저 고친다.
- 스킬이 만들었다고 한 검사 결과도 우리 게이트(`./tools/test_godot.sh` · `./.venv/bin/python tools/gate_all.py`)가 돌린 것만 통과로 친다.
- 채택 판단·라이선스·쓰지 않는 이유: [docs/dev/AGENT_SKILLS.md](docs/dev/AGENT_SKILLS.md)
