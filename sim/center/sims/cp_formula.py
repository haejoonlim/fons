#!/usr/bin/env python3
"""전투력(CP) 계산식 검증 — 카드 한 장의 CP 배율이 그 카드의 power 와 같은가.

왜 필요한가
-----------
37차에 대표 스탯이 마법관통(MPEN)인 카드 5장이 **CP 를 한 점도 못 올렸다** —
전투력 식에 MPEN 항이 아예 없었기 때문. 스탯이 식에서 빠지면 카드 선택이
"세지는 대신 다른 걸 잃는다"가 아니라 "잃기만 한다"가 된다.

38차 — 회피율(EVA) 폐지 · 민첩 = 이동속도(MS). MS 는 이제 `races.json`
`heroBaseStats.ms`(기준 100%) 실스탯이므로, 이 검사도 기준 빌드를 데이터에서
그대로 읽는다 (예전처럼 GEAR_REF 로 0 을 메우지 않는다).

무엇을 보는가
-------------
1. CP 식에 **13개 축 전부** 항이 있는가 (누락 0).
2. 카드 한 장의 CP 배율 == `power` 인가 (기준 빌드 · 밴드 ≈ 0).
3. CP 를 낮추는 카드가 하나도 없는가 (모두 ×1.0 이상).
4. 티어 1 ≥ 2 ≥ 3 인가 (강한 카드가 어려운 카드).
5. **빌드가 달라져도** 배율이 power 근처인가 — 기준 빌드에서만 성립하는
   착시를 걸러낸다. statMod 는 축 벡터라, 기준이 그 축에 쏠린 빌드에서는
   같은 카드가 더 세게 곱해진다. 허용 폭 6%p.

기준 빌드
--------
`races.json` 기준스탯은 PEN·MPEN·CRI·CDMG·MDEF 가 0 이라, 그 축 카드는 곱해도
0 이 되어 CP 를 못 올린다. 그래서 **기준 장비 세트**를 더해 0 인 칸을 채운
기준 빌드에서 잰다. 이 값은 생성기 `gen_career_34.py` 의 `GEAR_REF` 와 같은 것을 쓴다.

사용: ./.venv/bin/python sim/center/sims/cp_formula.py
"""
import json
import os
import sys

TOOLS = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(TOOLS)))
sys.path.insert(0, TOOLS)

from gen_career_34 import AX_NAME as AX, CP_W as WEIGHTS, GEAR_REF, _BASE_KEY  # noqa: E402

TREE = os.path.join(ROOT, 'data', 'job_tree.json')
RACES = os.path.join(ROOT, 'data', 'races.json')

BUILD_TOL = 0.06   # 빌드가 달라져도 power 에서 이만큼 넘게 벗어나면 안 된다


def load():
    with open(TREE, encoding='utf-8') as fh:
        tree = json.load(fh)
    with open(RACES, encoding='utf-8') as fh:
        raw = json.load(fh)['meta']['heroBaseStats']
    base = {c: raw.get(_BASE_KEY[c], 0) for c in AX}
    ref = {c: base[c] + GEAR_REF.get(c, 0) for c in AX}
    return tree, ref


def cp(stat, weights):
    return sum(weights[c] * stat[c] for c in AX)


def builds_for(ref):
    """기준 빌드 + 성격이 다른 세 빌드 — 카드 배율이 빌드에 목매지 않는지 본다."""
    return {
        '기준': dict(ref),
        '탱커': {**ref, 'HP': ref['HP'] * 1.8, 'DEF': ref['DEF'] * 2, 'ATK': ref['ATK'] * 0.6},
        '딜러': {**ref, 'ATK': ref['ATK'] * 1.8, 'CRI': ref['CRI'] * 3, 'HP': ref['HP'] * 0.6},
        '마법': {**ref, 'MAG': ref['MAG'] * 2.5, 'MPEN': ref['MPEN'] * 2, 'ATK': ref['ATK'] * 0.4},
    }


def rows_for(tree, builds, weights):
    out = []
    for j in tree['jobs']:
        for k in j.get('keywords') or []:
            m = k.get('statMod')
            if not m:
                continue
            ratio = {}
            for label, base in builds.items():
                stat = {c: base[c] * m[i] for i, c in enumerate(AX)}
                ratio[label] = cp(stat, weights) / cp(base, weights)
            out.append({'job': j['name'], 'name': k['name'], 'tier': str(k.get('tier')),
                        'power': k.get('power', 1.0), 'ratio': ratio['기준'], 'by_build': ratio})
    return out


def main():
    tree, ref = load()
    missing = [c for c in AX if c not in WEIGHTS]
    if missing:
        raise SystemExit(f'FAIL — CP 식에 없는 축: {missing}')
    if ref['MS'] <= 0:
        raise SystemExit('FAIL — 기준 빌드의 이동속도(MS)가 0 — races.json heroBaseStats.ms 확인')
    if ref['MPEN'] <= 0:
        raise SystemExit('FAIL — 기준 빌드의 마법관통(MPEN)이 0 — 카드가 CP 를 못 올린다')

    builds = builds_for(ref)
    rows = rows_for(tree, builds, WEIGHTS)
    base_cp = cp(ref, WEIGHTS)
    worst = max(rows, key=lambda r: abs(r['ratio'] - r['power']))
    low = min(rows, key=lambda r: r['ratio'])
    drift = max(rows, key=lambda r: max(abs(v - r['power']) for v in r['by_build'].values()))

    print(f'CP 기준 빌드 = {base_cp:.1f} · 13항 전부 포함 · MS 기준 {ref["MS"]:.0f}')
    print(f'카드 {len(rows)}장 · |CP배율 − power| 최대 {abs(worst["ratio"]-worst["power"]):.5f} '
          f'({worst["name"]})')
    print(f'CP 배율 범위 ×{min(r["ratio"] for r in rows):.4f} ~ ×{max(r["ratio"] for r in rows):.4f}')
    print(f'가장 약한 카드: {low["name"]} ×{low["ratio"]:.4f} (power {low["power"]:.4f})')

    tier = {}
    for r in rows:
        tier.setdefault(r['tier'], []).append(r['ratio'])
    tm = {t: sum(v) / len(v) for t, v in tier.items()}
    print('티어 평균: ' + ' · '.join(f'{t}=×{tm[t]:.4f}' for t in sorted(tm)))

    # 빌드 민감도 — 기준 빌드에서만 power 가 맞고 실제 빌드에서는 어긋나면 착시다.
    print(f'빌드 민감도 최대 {max(abs(v-drift["power"]) for v in drift["by_build"].values())*100:.2f}%p '
          f'({drift["name"]} · ' +
          ' '.join(f'{k}=×{v:.3f}' for k, v in drift['by_build'].items()) + ')')

    problems = []
    if abs(worst['ratio'] - worst['power']) > 0.002:
        problems.append(f'CP배율 ≠ power (최대 {abs(worst["ratio"]-worst["power"]):.5f})')
    if low['ratio'] < 0.999:
        problems.append(f'CP 를 낮추는 카드 존재 ({low["name"]} ×{low["ratio"]:.4f})')
    if not (tm.get('1', 0) >= tm.get('2', 0) >= tm.get('3', 0)):
        problems.append('티어 1 ≥ 2 ≥ 3 불성립')
    dmax = max(abs(v - drift['power']) for v in drift['by_build'].values())
    if dmax > BUILD_TOL:
        problems.append(f'빌드 민감도 {dmax*100:.1f}%p > {BUILD_TOL*100:.0f}%p ({drift["name"]})')
    if problems:
        print('FAIL — ' + ' / '.join(problems))
        raise SystemExit(1)
    print('OK — 13항 전부 · 카드 CP배율 == power · CP 하락 카드 0 · 티어 단조 · '
          f'빌드 민감도 ≤ {BUILD_TOL*100:.0f}%p')


if __name__ == '__main__':
    main()
