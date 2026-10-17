# GDD 정본 사본 — 출처와 지위

이 폴더는 **원본 저장소의 GDD 정본을 그대로 복사한 것**이다. 수정하지 않는다.

| 항목 | 내용 |
|---|---|
| 원본 경로 | `soul-commander/design-docs/GDD_v8.0_00_확정사항.md` ~ `09`, `99` (11종) |
| 복사 시점 | 2026-10-17 |
| 무결성 | 11종 전부 sha256 이 원본과 일치 (자체 실측) |
| 함께 온 것 | `AGENTS_원본.md` = 원본 `design-docs/AGENTS.md` · `README_원본.md` = 원본 `design-docs/README.md` |

## 왜 여기로 옮겼나

앞선 결정([../DEV_PLAN.md](../DEV_PLAN.md) P0-2)은 GDD를 복사하지 않고 `~/soul-commander` 클론 + [../original/](../original/) 사실표로 갈음하는 것이었다.
이유는 "정본이 둘로 갈라진다"였다.

그 전제가 바뀌었다 — **원본 GitHub 저장소(`haejoonlim/soul-commander`)를 삭제하기로 했다.**
원격이 사라지면 로컬 클론 한 벌만 남으므로, 그 한 벌에 의존하지 않도록 정본을 이 리포에 넣는다.

## 지위 (우선순위)

1. 이 폴더의 GDD — 원본 문면 그대로. **수정 금지.** 개정이 필요하면 사용자 확인을 받고 별도 커밋으로만.
2. `data/*.json` — 런타임 정본 데이터 17종.
3. [../original/](../original/) — 위 둘에서 뽑은 대조 사실표. 값의 출처 표시가 여기 있다.
4. [../DEV_PLAN.md](../DEV_PLAN.md) · [../PLAN_2D_FIRST.md](../PLAN_2D_FIRST.md) — 작업 순서와 렌더링 결정.

값이 갈리면 위 번호가 작은 쪽이 이긴다. 그래도 갈리면 한쪽을 고르지 말고 양쪽을 적고 사용자에게 확인한다.
