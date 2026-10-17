# 한국어 문장 검사 — 스킬 3종 사용법

`daleseo/korean-skills`(MIT)를 전역 설치했다. 위치는 `~/.agents/skills/`.

| 스킬 | 하는 일 |
|---|---|
| `humanizer` | AI 티 제거. 번역투(`~에 대해`·`~를 통해`), 피동 남용, `~적 N` 추상어, 과장 어휘, 결말 상투구, 문장부호 습관 |
| `grammar-checker` | 맞춤법·띄어쓰기·문법. 확신도와 근거를 함께 제시 |
| `style-guide` | 용어·어조·숫자·날짜 표기 **일관성**. 맞춤법은 다루지 않음 |

## 순서

1. `humanizer` — 문장을 가장 크게 바꾸므로 먼저
2. `grammar-checker` — 안정된 문장에 대해 검사
3. `style-guide` — 마지막에 일관성만 확인

거꾸로 돌리면 humanizer가 grammar-checker가 잡은 문장을 다시 흔든다.

## 어디에 쓰나

- 새로 쓰는 글: `docs/dev/`, `docs/design/`, `docs/art/`, `docs/audio/`, UI 문구, JSON의 설명 필드
- **`docs/gdd/`·`docs/original/` 은 원본 문면이라 손대지 않는다** — `docs/README.md` 규칙 2
- 게임 용어의 정본은 `docs/gdd/GDD_v8.0_00_확정사항.md` 다. `style-guide`에 이 파일을 기준으로 삼게 하고, 새 용어는 여기 먼저 등록한 뒤 쓴다

## 호출 방법

이 앱(Freebuff)은 `~/.agents/skills`를 자동으로 읽지 않고 `~/.AGENTS.md`만 읽는다.
그래서 세 스킬에는 자동 발동이 없고, 필요할 때 SKILL.md를 직접 지정한다.

```
~/.agents/skills/humanizer/SKILL.md 읽고 이 문서에 적용해줘
~/.agents/skills/grammar-checker/SKILL.md 기준으로 검사해줘
~/.agents/skills/style-guide/SKILL.md 기준으로 용어 일관성만 봐줘
```

Claude Code·Codex·Cursor 등에는 설치 시 심링크가 걸려 있어 자동 활성된다.

## 관리

```bash
npx skills list -g          # 설치 목록
npx skills update -g        # 최신으로 갱신
npx skills remove humanizer -g
```

문서 전체 기계 검수는 기존대로 `./.venv/bin/python tools/review_docs.py`.
