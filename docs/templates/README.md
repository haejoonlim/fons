# 문서 템플릿 — 폰즈

매번 같은 칸을 새로 만들지 않기 위한 서식이다. **템플릿은 서식이지 근거가 아니다** — 값은
`data/`·`docs/`·측정 출력에서 온다.

| 템플릿 | 언제 쓰나 | 대응 문서 |
|---|---|---|
| [밸런스_조정_기록.md](밸런스_조정_기록.md) | 수치 하나를 바꿀 때 (적 HP·계수·확률·비용) | ADR 앞단의 임시 기록. 결정이 굳으면 ADR 로 승격 |
| [난이도_곡선표.md](난이도_곡선표.md) | 층 난이도를 재고 판정할 때 | [상층_개방_결정.md](../design/상층_개방_결정.md) 같은 결정 문서의 입력 |
| [버그_기록.md](버그_기록.md) | 증상이 보고됐는데 원인을 아직 모를 때 | 고친 뒤 [DEV_PLAN.md](../dev/DEV_PLAN.md) Phase 로그에 한 줄 |

## 출처

세 서식은 [Donchitos/Claude-Code-Game-Studios](https://github.com/Donchitos/Claude-Code-Game-Studios)
(`05ad7c8a5b8aa2aa86bbd3439ae7cf7295cac418`) 의 `.claude/docs/templates/` 중 셋을 골라
폰즈 규약으로 다시 쓴 것이다. MIT 라이선스 — 원문은
[third_party/Claude-Code-Game-Studios/LICENSE](../../third_party/Claude-Code-Game-Studios/LICENSE).

| 템플릿 | 원본 |
|---|---|
| [밸런스_조정_기록.md](밸런스_조정_기록.md) | `quick-design-tuning.md` |
| [난이도_곡선표.md](난이도_곡선표.md) | `difficulty-curve.md` |
| [버그_기록.md](버그_기록.md) | `bug-report.md` |

**바꾼 것**: 영어 → 한국어, 원본의 명령 체계(`/story-done`·`production/qa/...` 경로) 제거,
근거 표시 칸(`자체 실측` / `원본 대조`) 추가, "AI 채점" 금지 조항 추가.
**안 가져온 것**: 원본 82종 중 나머지 — 우리 문서가 이미 같은 자리를 채우고 있다
(기획서는 `docs/gdd/`, 결정은 `docs/adr/`, 계획은 `docs/dev/DEV_PLAN.md`, 출시 체크리스트는 아직 없음).
없는 문서는 필요해질 때 만든다.
