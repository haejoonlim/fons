# 외부 에이전트 스킬 도입 판단 — 폰즈 (FONS)

작성 2026-10-22 · 조사 대상: GitHub의 게임 개발용 에이전트 스킬 저장소 3종 + 스프라이트 생성 도구 1종.
저장소 수치(별 수·마지막 push·커밋 SHA)는 **2026-10-22에 GitHub API로 직접 조회한 값**이다 (자체 실측).

## 0. 한 줄 요약

조사한 4개 중 3개는 "게임 개발용 에이전트 스킬 모음"이고 1개는 2D 스프라이트 생성 도구다.
폰즈(Godot 4.7.2 · GDScript · 런타임 데이터 17종 JSON)에 지금 붙여 쓸 수 있는 것은 **`awesome-gamedev-agent-skills`의 Godot 계열 일부**와 **`gstack-game`의 `balance-review` 하나**뿐이다.
나머지 두 개는 설치하지 않고 판단 근거만 여기 남긴다.

---

## 1. 조사한 저장소

| 저장소 | 라이선스 | 규모 | 마지막 push | 고정 SHA | 판정 |
|---|---|---|---|---|---|
| [gamedev-skills/awesome-gamedev-agent-skills](https://github.com/gamedev-skills/awesome-gamedev-agent-skills) | Apache-2.0 | 스킬 74 + 라우터 1 | 2026-10-09 | `0a70cfc64672d512c5b5b6006b5dcb5cf90dbdbd` | **채택(일부)** — Godot 16종 포함 |
| [fagemx/gstack-game](https://github.com/fagemx/gstack-game) | MIT | 명령 29 | 2026-05-31 | `7259ab9782fa9c17e45c16f1fb8347823ddb4379` | **채택(1종)** — 밸런스 검토 기준 |
| [Donchitos/Claude-Code-Game-Studios](https://github.com/Donchitos/Claude-Code-Game-Studios) | MIT | 에이전트 49 · 스킬 74 | 2026-10-19 | `05ad7c8a5b8aa2aa86bbd3439ae7cf7295cac418` | **부분 채택** — 문서 템플릿 3종만 (§2.1) |
| [aldegad/sprite-gen](https://github.com/aldegad/sprite-gen) | Apache-2.0 | Python CLI + 스킬 | 2026-10-21 | — | **지금은 안 붙임** — 2D 전용 |

### "spirite gen"은 무엇인가

GitHub 저장소 이름으로 `spirite`·`spirite-gen`·`spirit-gen`을 검색해도 해당 저장소는 나오지 않는다 (자체 실측 · 2026-10-22 검색 결과).
가장 가까운 실물은 **`aldegad/sprite-gen`**이다 — "2D 게임 스프라이트와 애니메이션 아틀라스를 만드는 컴포넌트 행 파이프라인", Claude/Codex 스킬로 배포 (자체 실측 · README·저장소 설명).
즉 "스프라이트 생성"으로 읽는 게 맞다. 새 고유명사가 아니라 도구 이름이므로 용어집 등록 대상이 아니다.

---

## 2. 채택하지 않거나 범위를 좁힌 것

### 2.1 Claude-Code-Game-Studios — 저장소는 안 받고 문서 템플릿 3종만

- 설치 방식이 저장소 클론(또는 저장소 템플릿)이고, 프로젝트 루트에 `CLAUDE.md`·`project.yaml`·hooks·권한 설치를 깔아야 한다.
- 폰즈는 이미 `AGENTS.md`·`tools/` 게이트 17종·문서 구조를 갖고 있다 (자체 실측 · 저장소 루트 확인). 두 규약 체계가 겹치면 어느 쪽이 이기는지 매번 판단해야 한다.
- 개별 스킬만 떼어 쓰는 것도 단순하지 않다. 스킬이 자체 템플릿 62종·hooks 18종·에이전트 정의에 기대므로, 몇 개만 복사하면 의존 관계를 함께 고쳐야 한다.
- README 기준으로 Godot 4·Unity·Unreal을 모두 지원하지만 (자체 실측 · README), 명령 체계는 Claude Code 전용이다. 폰즈 작업은 Freebuff/Codebuff 세션에서 한다.
- **판정: 템플릿 3종만 옮긴다.** 문서 서식은 규약 충돌이 없다 — 가져온 것은 [docs/templates/](../templates/README.md) 의 밸런스 조정 기록·난이도 곡선표·버그 기록 셋이다 (MIT · 원문 `05ad7c8`). 검토 커맨드는 옮기지 않았다 — 그 자리는 이미 있는 게이트(`tools/gate_all.py` · `tools/review_docs.py`)가 맡는다.

### 2.2 sprite-gen — 지금 프로젝트 단계와 맞지 않는다

- 2D 스프라이트 시트·애틀라스 생성 파이프라인이다. 폰즈는 3D로 간다 ([docs/dev/DEV_PLAN.md](DEV_PLAN.md) Phase 3).
- 도감 377종의 2D 초상화가 필요해질 수는 있지만, 그건 3D 화면이 나온 뒤다.
- **판정: 나중에 필요할 때 그때 설치.** 지금 설치하면 쓸 곳이 없다.

---

## 3. 채택한 것 — 설치 위치와 쓰임

설치 위치는 **저장소 안** `.claude/skills/<스킬>/SKILL.md`다. 커밋 대상이라 규칙이 바뀌면 함께 바뀌고, 검토할 수 있다.

| 스킬 | 출처 | 언제 읽나 | 이 저장소에서의 사용법 |
|---|---|---|---|
| `godot-gdscript-headless-testing` | awesome-gamedev-agent-skills | GitHub Actions 워크플로를 짤 때 ([DEV_PLAN.md](DEV_PLAN.md) Phase 4-3) | `--headless --import` 선행 순서와 `assert()` 함정만 참조한다 |
| `godot-3d-essentials` | awesome-gamedev-agent-skills | 3D 씬을 처음 만들 때 (Phase 3) | 엔진 API 감각 상기기용. 씬 구조는 우리 설계 문서가 정한다 |
| `godot-nodes-scenes` | awesome-gamedev-agent-skills | 노드 구성·인스턴싱을 정리할 때 (Phase 3) | 같은 성격 — 참고용 |
| `godot-ui-control` | awesome-gamedev-agent-skills | 타이틀·영지·HUD 화면을 짤 때 | 레이아웃·테마 참고. 문구는 [docs/l10n/UI_문구_규칙.md](../l10n/UI_문구_규칙.md)가 정한다 |
| `balance-review` | gstack-game | 상층 밸런스 결정을 하기 전에 ([HANDOFF.md](../../HANDOFF.md) §6-2) | **판정 기준(난이도 곡선·진행·캐릭터 밸런스)만** 쓴다 |

### 3.1 `godot-gdscript-headless-testing` — 왜 필요한가

이 스킬이 다루는 함정이 이 저장소에도 그대로 있다. 새 체크아웃에는 Godot 임포트 캐시가 없어서, 테스트를 한 건도 실행하지 않고도 종료 코드가 0으로 떨어진다 (HANDOFF 부록 A #10 · 자체 실측으로 확인된 사실).
스킬은 여기에 더해, 실패한 `assert()`가 `quit()` 호출 전에 실행을 멈춰 CI가 응답 없이 붙는 경우와, 종료 코드와 표준출력을 함께 봐야 한다는 점을 짚는다.
**우리 규칙(`tools/test_godot.sh` 단독 실행 결과는 증거로 치지 않는다)은 유지한다.** 이 스킬은 GUT 없이 순수 러너를 만드는 쪽이라 그대로 쓰지 않고 절차만 가져온다.

### 3.2 `balance-review` — 지금 가장 큰 열린 질문에 붙는다

열린 항목은 "111~130층을 열 것인가"와 턴 상한을 어떻게 잡을가의 결정이다 (HANDOFF §6-2 · 자체 실측으로 확인된 사실).
이 스킬은 그 결정에 필요한 **판정 기준**을 준다 — 스킬 폴더의 `difficulty-curve.md`·`progression.md`·`character-balance.md`·`gotchas.md`.
쓰지 않는 것 두 가지:

- **셸 preamble은 실행하지 않는다.** 이 스킬의 맨 앞 블록은 `~/.gstack/`에 세션·분석 파일을 만들고, 함께 설치된 `gstack-game` 바이너리를 찾는다. 저장소 밖 파일을 쓰는 블록이라 실행 대상이 아니다. 참고 자료로만 읽는다.
- **예시 수치를 옮기지 않는다.** 스킬 안의 숫자 예시는 다른 게임 기준이다. 폰즈의 값은 정본 데이터에서 온다.

---

## 4. 사용 규칙

1. **스킬은 조언이다. 정본은 `data/`와 `docs/`다.** 스킬이 제안한 수치를 코드에 넣지 않는다. 값을 넣는 경로는 항상 등록소(`tools/tracked_numbers.json`) → 파이썬 → GDScript 복사 순서이며, 그 절차는 [DEV_PLAN.md](DEV_PLAN.md) Phase 1-4에 적혀 있다.
2. **문서와 코드의 근거는 대조된 값이다.** 스킬에 예시로 든 수치를 "원본에서 그렇게 한다"로 옮기지 않는다. 근거 표시는 원본 대조·자체 실측으로 갈린다.
3. **검증은 우리 게이트가 한다.** 스킬이 "테스트를 돌렸다"고 적혀 있어도 `./tools/test_godot.sh`와 `tools/gate_all.py` 출력이 붙지 않으면 통과로 치지 않는다.
4. **저장소 밖을 건드리는 블록은 실행하지 않는다.** `~/.gstack/` 세션·분석 파일을 만드는 preamble이 그렇다. 참고 자료로만 읽는다.
5. **버전은 SHA로 고정한다.** §1의 SHA가 바뀌면 파일을 갈아끼우고 이 문서를 같은 커밋에서 갱신한다.

---

## 5. 출처와 라이선스

| 스킬 | 라이선스 | 라이선스 원문 | 출처 파일 |
|---|---|---|---|
| `godot-gdscript-headless-testing` · `godot-3d-essentials` · `godot-nodes-scenes` · `godot-ui-control` | Apache-2.0 | [third_party/awesome-gamedev-agent-skills/LICENSE](../../third_party/awesome-gamedev-agent-skills/LICENSE) · [NOTICE](../../third_party/awesome-gamedev-agent-skills/NOTICE) | <https://github.com/gamedev-skills/awesome-gamedev-agent-skills/tree/0a70cfc64672d512c5b5b6006b5dcb5cf90dbdbd/skills/godot> |
| `balance-review` | MIT | [third_party/gstack-game/LICENSE](../../third_party/gstack-game/LICENSE) | <https://github.com/fagemx/gstack-game/tree/7259ab9782fa9c17e45c16f1fb8347823ddb4379/skills/balance-review> |
| 문서 템플릿 3종 ([docs/templates/](../templates/README.md)) | MIT | [third_party/Claude-Code-Game-Studios/LICENSE](../../third_party/Claude-Code-Game-Studios/LICENSE) | <https://github.com/Donchitos/Claude-Code-Game-Studios/tree/05ad7c8a5b8aa2aa86bbd3439ae7cf7295cac418/.claude/docs/templates> |

Apache-2.0은 재배포 시 라이선스·NOTICE 복기와 변경 사실 고지가 필요하다. 이 스킬들은 원본 그대로 복사했다(변경 없음).

---

## 6. 나중에 붙일 것 — 지금 붙이지 않는 이유

받는 명령은 하나다. 스크립트가 [REPOS 표](../../tools/fetch_skills.py)의 SHA로 받고, 받은 것이 그 SHA와 같은지 파일 해시로 검사한다.

```bash
./.venv/bin/python tools/fetch_skills.py --list     # 무엇이 설치됐고 무엇이 대기인가
./.venv/bin/python tools/fetch_skills.py --only godot-export
./.venv/bin/python tools/fetch_skills.py --check    # 설치본 ↔ 핀 SHA (exit 1 = 손댔거나 낡음)
```

`--check` 가 불일치를 내면 둘 중 하나다 — 파일을 손댔거나, SHA를 올려서 오래된 사본이 남았다.
후자면 `--force` 로 다시 받고 §1 표를 같은 커밋에서 고친다.

| 후보 | 붙이는 시점 | 지금 안 붙이는 이유 |
|---|---|---|
| `save-systems` | 세이브 구조를 세울 때 (확정 #47 세이브 규격을 옮기는 단계) | 세이브 설계가 아직 시작되지 않았다 |
| `dialogue-systems` | 대화·브리핑 화면을 만들 때 | 해당 화면이 아직 없다 |
| `performance-optimization` | 3D 실측에서 프레임이 안 맞을 때 (Phase 3 끝) | 아직 측정 전이다. 가설로 최적화하지 않는다 |
| `godot-export` | macOS 익스포트 프리셋을 확정할 때 ([DEV_PLAN.md](DEV_PLAN.md) §4.6) | 프리셋 확정 전이다 |
| `godot-resources` | JSON 데이터를 리소스로 바꿀지 정할 때 | 변환 여부 자체가 미결이다 |
| `roguelike` | 영구사망 루프 기준을 문서로 만들 때 | 장르 기준표가 필요해지는 시점 |
| `procedural-gen` | 층 생성을 데이터가 아니라 절차로 만들기로 정할 때 | 그 결정이 아직 없다 |

---

## 7. 하지 않은 것

- 위 저장소들의 문서를 통째로 복사하지 않았다. 폰즈 문서 규약에 없는 내용이라 규칙이 아니라 잡음이 된다.
- Claude-Code-Game-Studios 저장소를 설치하지 않았다. 템플릿 3종만 번역해 옮겼다 (2.1).
- `~/.config/freebuff-desktop/account-skills/` 에 넣지 않았다. 그 폴더는 클라우드 동기화 영역이라 저장소 규칙과 어긋나면 두 벌의 규칙이 생긴다. 저장소 안(`.claude/skills/`)에 두는 편이 커밋으로 남는다.
