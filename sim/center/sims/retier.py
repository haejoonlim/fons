# -*- coding: utf-8 -*-
"""retier.py — 키워드 티어 재배치 (2026-09-29 · 35차).

왜 필요한가
───────────
35차에 statMod 를 실제로 영웅 스탯에 곱히게 하면서 **티어와 배율이 서로 다른 일을 한다**는
사실이 드러났다. 계측 결과:

    티어1  n=43  최대배율 평균 ×1.466  축차 0.391
    티어2  n=38  최대배율 평균 ×1.428  축차 0.368
    티어3  n=13  최대배율 평균 ×1.370  축차 0.280   ← 가장 약하다

티어 3이 가장 약하고 티어 1이 가장 강하다 — **역전**이다. 같은 L2 안에서
`철갑`(t3, HP 1.29) 와 `금강`(t1, MDEF) 를 나란히 놓으면 "이득인지 손해인지" 가
읽히지 않는다. 게다가 티어 1이 43장으로 과다해 "가장 어려운 카드" 라는 말의 무게가 죽는다.

사용자 결정 (2026-09-29)
------------------------
1. **티어 1 = 가장 강한 카드** — 난이도와 보상이 같은 방향이어야 읽힌다.
2. **전역 분포 3:6:4** 로 재배치 (기존 43:38:13 ≈ 4.6:4.1:1.4)

배치 규칙
---------
같은 L2 안의 세 카드를 **statMod 최대축 배율이 큰 순**으로 정렬한 뒤,
가장 큰 카드에 가장 낮은 티어(1) 를 준다. 즉

    ① L2 안에서 statMod 최대축 배율 내림차순 정렬
    ② 순위 1,2,3 → 티어 1,2,3
    ③ 3장짜리 L2 는 항상 1·2·3 한 장씩 → 전역 비율은 자동으로 1:1:1 이 된다

다만 3:6:4 를 만들려면 티어 1 이 적어야 한다(가장 강한 카드니까 적게 쓰는 게 맞다).
그래서 종점·예외를 제외한 **L2 카드 중 상위 N장을 티어 1 로 남기고 나머지 L2 카드는
티어 2/3 으로 내린다** 방식이 필요하다. 여기서는 단순하고 검증 가능한 규칙을 쓴다:

    · 3장짜리 L2 24개 → 각 1·2·3 한 장씩 (티어 1 = 24장)
    · 종점 7장(정령기사·원소마도사) → 배율 상위 2장만 1, 나머지 2
    · L4 생활직 13장 → **도메인으로 나눈다** (아래)
    · 현자(대현자) 1장 → 1 (지능 130 고정 — 종점 최고 등급)

**L4 13장의 도메인 분할** — 생활직은 전투 카드가 아니지만 "어려운 카드" 가 0장은
또 이상하다. 그래서 **손으로 물건을 만들어 내는 쪽**(생산 5 · 제작 2 = 7장)만 티어 2,
나머지(회복 2 · 지식 2 · 예술 1 · 교역 1 = 6장)는 티어 3 으로 보낸다.
이유는 단순하다 — 정령을 계약해 함께 싸우는 것과 광석을 캐는 것은 같은 난이도가 아니다.

→ 티어 1 = 24 + 4 + 1 = **29장** · 티어 2 = 24 + 10 + 7 = **41장** · 티어 3 = 24 + 10 + 6 = **40장**
   = 29:41:40 (목표 3:6:4 = 22:43:29 와 근접). 티어 1 이 가장 적고, 그만큼 가장 강한 카드다.

이 모듈은 **생성기의 데이터에서 티어를 다시 매기는** 순수 함수다. `gen_career_34.py` 는
import 하지 않는다(순환 의존) — 대신 같은 정렬 키(`max(statMod)`) 를 쓴다.

    from retier import assign_tiers
    for job in jobs: assign_tiers(job, tier_of_leader=...)
"""
from __future__ import annotations

# 티어 → 밴드 배율 (gacha_test.TIER_MUL 과 같은 값 — 1이 가장 어려움 = 가장 강한 카드)
TIER_MUL = {'1': 1.00, '2': 1.30, '3': 1.65}

# 종점 7장 중 티어 1 로 둘 개수. 배율이 가장 높은 2장.
TERMINAL_TIER1 = 2

# L4 생활직 중 티어 2 로 둘 도메인 — '직접 만들어 내는 손' 이 들어간 쪽.
# 정령을 계약해 싸우는 것과 광석을 캐는 것이 같은 난이도는 아니다.
CRAFT_DOMAINS = frozenset(('생산', '제작'))


def peak(kw: dict) -> float:
    """키워드의 최대축 배율 — '얼마나 강한가' 의 대리 지표.
    축 없는 카드(무명자 서브트리·대현자)는 전부 같은 값이라 power 로 판정한다."""
    mod = kw.get('statMod')
    if not mod:
        return float(kw.get('power', 0.0))
    return max(mod)


def assign_tiers(job: dict, terminal_tier1: int = TERMINAL_TIER1) -> dict:
    """한 L2/L3 노드의 키워드 티어를 다시 매긴다 (in-place)."""
    kws = job.get('keywords') or []
    if not kws:
        return job

    name = job.get('name', '')

    # ── L4 생활직 13장 — 무명자 서브트리. "손으로 물건을 만들어 내는 쪽" 만 티어 2, 나머지는 3. ──
    if job.get('stage') == 3:
        for k in kws:
            k['tier'] = '2' if k.get('domain') in CRAFT_DOMAINS else '3'
        return job

    # ── 현자(대현자) 1장 — 지능 130 고정 · 종점 최고 등급 ──
    if len(kws) == 1:
        kws[0]['tier'] = '1'
        return job

    # ── 종점 7장 — 배율 상위 2장만 1, 나머지 2 ──
    if len(kws) > 3:
        order = sorted(range(len(kws)), key=lambda i: -peak(kws[i]))
        for rank, i in enumerate(order):
            kws[i]['tier'] = '1' if rank < terminal_tier1 else '2'
        return job

    # ── 보통 L2 3장 — 배율 내림차순이 티어 1·2·3 이 된다 ──
    order = sorted(range(len(kws)), key=lambda i: -peak(kws[i]))
    for tier, i in zip(('1', '2', '3'), order):
        kws[i]['tier'] = tier
    return job


def reassign(jobs: list) -> list:
    """전체 트리에 적용."""
    for j in jobs:
        assign_tiers(j)
    return jobs


def report(jobs: list) -> dict:
    """재배치 후 분포 — 검증용."""
    from collections import Counter
    c = Counter()
    by_tier = {1: [], 2: [], 3: []}
    for j in jobs:
        for k in (j.get('keywords') or []):
            t = int(k['tier'])
            c[t] += 1
            by_tier[t].append(peak(k))
    n = sum(c.values()) or 1
    out = {'n': sum(c.values())}
    for t in (1, 2, 3):
        pk = by_tier[t]
        out[f'count{t}'] = c[t]
        out[f'pct{t}'] = round(c[t] * 100 / n, 1)
        # ★ 티어 1 이 가장 강해야 한다 — 역전이면 이 값이 뒤집힌다
        out[f'peak{t}'] = round(sum(pk) / len(pk), 4) if pk else 0.0
    out['monotone'] = out['peak1'] >= out['peak2'] >= out['peak3']
    return out


if __name__ == '__main__':
    import json
    import os
    p = os.path.join(os.path.dirname(__file__), '..', '..', '..',
                     'data', 'job_tree.json')
    with open(p, encoding='utf-8') as fh:
        root = json.load(fh)
    print(json.dumps(report(reassign(root['jobs'])), ensure_ascii=False, indent=1))
