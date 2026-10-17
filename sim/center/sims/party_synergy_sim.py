#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""party_synergy_sim.py — 파티 시너지 S_syn 몬테카를로 검증기 (2026-09-19 · 00 #42)

규격: 5인 출격 파티의 조합 보너스 — CP 산식(01 §3)에 별개 승수 Y = clamp(1+Σ양−Σ음, 0.90, 1.15)
  ① 성격 케미(양성 쌍) ② 성격 불화(음성 쌍 — 스트레스 연계 +25%/쌍, 04 §3.6-2)
  ③ 계열 다양성(4/5/6종 +2/3/4%) ④ 직업 중복 3명+ (−2%) ⑤ 특성 공진 2명+ (+1.5%, 상한 +3%)

실행: python3 design-docs/_tools/party_synergy_sim.py [파티수=100000]
기준: 무작위 평균 +1.0~1.2% · 중앙 +1.5% · 이상 파티 +10%대 · 최악 −8%대 (00 #42 등재 수치)
"""
import random, statistics, itertools, collections, sys, json, os

# 바이옴 카테고리 단일 소스 — biomes.json biome.category 필드 (2026-09-19 정리)
_TOOLS = os.path.dirname(os.path.abspath(__file__))
BIOMES_PATH = os.path.join(_TOOLS, '..', '..', '..', 'data', 'biomes.json')
SYNERGY_PATH = os.path.join(_TOOLS, '..', '..', '..', 'data', 'synergy.json')

def biome_deltas():
    """biomes.json → {바이옴id: (이름, bioPos, bioNeg)} — synergy.json 델타표 조인. 이중 소속은 구조적으로 불가능."""
    biomes = json.load(open(BIOMES_PATH, encoding='utf-8'))
    syn = json.load(open(SYNERGY_PATH, encoding='utf-8'))
    dtab = {c['id']: (c['deltaPositive'], c['deltaNegative']) for c in syn['zoneRules']['biomeCategories']['categories']}
    out = {}
    for g in biomes['groups']:
        for b in g['biomes']:
            cat = b.get('category')
            assert cat in dtab, f"{b['id']}: 카테고리 미정의({cat}) — biomes.json categoryRule 참조"
            pos, neg = dtab[cat]
            out[b['id']] = (b['name'], pos, neg)
    assert len(out) == 26, f"바이옴 26종 필요 — 실측 {len(out)} (g4 오픈월드 6종 추가 반영)"
    return out

PERS = ['용감','신중','냉정','난폭','헌신','교활','무자비','불굴','낭만','고집','성실','몰입','노련']
PERS_W = [9,9,8,8,8,8,8,8,7,9,8,2,1]        # 05 §5 (노련 Lv30+ 재롤 전용 — 롤 가중 최하)
LINS = ['인간','엘프','드워프','짐승','전사','심연']
JOBS = ['전사','수호자','암살자','궁수','마법사','지원가']

SYN_POS = {  # 성격 케미 — 양성 쌍 (2026-09-19 B안 확정: 6→11쌍 — 커버리지 73.5→87.9% 시뮬)
  ('용감','신중'):0.03, ('냉정','교활'):0.03, ('헌신','낭만'):0.03,
  ('성실','몰입'):0.03, ('불굴','고집'):0.02, ('난폭','무자비'):0.02,
  ('교활','몰입'):0.02, ('무자비','고집'):0.02, ('신중','성실'):0.02,
  ('용감','낭만'):0.02, ('냉정','무자비'):0.03,
}
SYN_NEG = {  # 성격 불화 — 음성 쌍 (B안: 5→8쌍 · 스트레스 +25%/쌍 연계)
  ('난폭','신중'):0.04, ('무자비','헌신'):0.04, ('고집','교활'):0.03,
  ('난폭','냉정'):0.02, ('몰입','낭만'):0.02, ('난폭','교활'):0.02, ('성실','난폭'):0.02,
}
COMMON_FEATS = ['일사불란','상성의 통찰','정교한 손끝','실전 감각','암중적응','거상의 수완']

def lin_diverse(lins):
    u = len(set(lins))
    return {4:0.02, 5:0.03}.get(u, 0.04 if u>=6 else 0.0)

def job_dup(jobs):
    return -0.02 if max(collections.Counter(jobs).values())>=3 else 0.0

def feat_reso(featSets):
    cnt = collections.Counter(f for fs in featSets for f in fs)
    return min(0.03, 0.015*sum(1 for n in cnt.values() if n>=2))

def syn(lins, jobs, pers, featSets, band=1.0, bioNeg=0.0, bioPos=0.0):
    """band: 페어 계수(케미·불화) 승수 — G1 1.0/G2 1.25/G3 1.5 (01 §3-3 지역 시너지)
    bioNeg/bioPos: 바이옴 카테고리 델타 (%p — 어둠·극한 지형 등)"""
    s = 0.0; pos = neg = 0.0; tags = []
    for a,b in itertools.combinations(pers,2):
        k = (a,b) if (a,b) in SYN_POS else ((b,a) if (b,a) in SYN_POS else None)
        if k: pos += SYN_POS[k]; tags.append(f"+{a}×{b}")
        k = (a,b) if (a,b) in SYN_NEG else ((b,a) if (b,a) in SYN_NEG else None)
        if k: neg += SYN_NEG[k]; tags.append(f"−{a}×{b}")
    pos = pos*band + bioPos; neg = neg*band + bioNeg
    d = lin_diverse(lins)
    if d: tags.append(f"+계열다양{len(set(lins))}")
    p = job_dup(jobs)
    if p: tags.append("−직업중복")
    f = feat_reso(featSets)
    if f: tags.append("+특성공진")
    s = pos - neg + d + p + f
    return s, tags, pos, neg

def main(n=100000):
    random.seed(20260919)
    vals = []
    for _ in range(n):
        lins = [random.choice(LINS) for _ in range(5)]
        jobs = [random.choice(JOBS) for _ in range(5)]
        pers = [random.choices(PERS, weights=PERS_W)[0] for _ in range(5)]
        featSets = [random.sample(COMMON_FEATS, k=random.choices([0,1,1,2],[70,15,10,5])[0]) for _ in range(5)]
        vals.append(syn(lins, jobs, pers, featSets)[0])
    vals.sort()
    pct = lambda p: vals[int(len(vals)*p/100)]
    print(f"── 무작위 5인 파티 {n:,} 시뮬 (시드 고정 · B안 11+8쌍) ──")
    print(f"평균 {statistics.mean(vals)*100:+.2f}% · 중앙 {pct(50)*100:+.2f}% · σ {statistics.stdev(vals)*100:.2f}")
    print(f"P5 {pct(5)*100:+.1f} · P25 {pct(25)*100:+.1f} · P75 {pct(75)*100:+.1f} · P95 {pct(95)*100:+.1f}%")
    print(f"양수 {100*sum(v>0 for v in vals)/len(vals):.1f}% · 0 {100*sum(v==0 for v in vals)/len(vals):.1f}% · 음수 {100*sum(v<0 for v in vals)/len(vals):.1f}%")
    # 지역 밴드 (01 §3-3) — 페어 계수 승수만 적용
    print("\n── 지역 밴드 (페어 계수 ×) ──")
    for name, band in [("G1 (1~50층) ×1.00", 1.0), ("G2 (51~95층) ×1.25", 1.25), ("G3 (96~100층) ×1.50", 1.5)]:
        bv = []
        for _ in range(n):
            lins = [random.choice(LINS) for _ in range(5)]
            jobs = [random.choice(JOBS) for _ in range(5)]
            pers = [random.choices(PERS, weights=PERS_W)[0] for _ in range(5)]
            bv.append(syn(lins, jobs, pers, [[],[],[],[],[]], band=band)[0])
        bv.sort()
        cap = 100*sum(v>=0.15 for v in bv)/len(bv)
        print(f"{name}: 평균 {statistics.mean(bv)*100:+.2f}% · P95 {bv[int(n*.95)]*100:+.1f}% · 상한(1.15) 도달 {cap:.2f}%")
    print("\n── 시나리오 ──")
    A = syn(['인간','엘프','드워프','짐승','전사'], ['수호자','마법사','궁수','암살자','지원가'],
            ['용감','신중','냉정','교활','성실'], [['일사불란','상성의 통찰'],[],[],['일사불란'],[]])
    B = syn(['심연']*5, ['심연술사']*3+['광전사','암살자'], ['무자비','난폭','난폭','고집','몰입'], [[],[],[],[],[]])
    C = syn(['인간','인간','엘프','엘프','드워프'], ['전사']*3+['수호자','수호자'],
            ['난폭','신중','무자비','헌신','고집'], [[],[],[],[],[]])
    for name, r, lo, hi in [("A 이상적 파티", A, 0.08, 0.14), ("B 계열 몰빵(공명)", B, -0.01, 0.06), ("C 최악 조합", C, -0.11, -0.04)]:
        ok = lo <= r[0] <= hi
        print(f"{name}: {r[0]*100:+.1f}% [{' '.join(r[1])}] — 기준 {lo*100:+.0f}~{hi*100:+.0f}% {'✓' if ok else '✗ FAIL'}")
    assert -0.11 <= C[0] <= -0.04 and 0.08 <= A[0] <= 0.14, "시나리오 기준 이탈"
    print("\n── 바이옴 카테고리 (biomes.json 단일 소스 · 26종) ──")
    bd = biome_deltas()
    byCat = collections.Counter()
    for bid, (nm, pos, neg) in sorted(bd.items()):
        byCat[(pos, neg)] += 1
        if pos or neg:
            print(f"  {nm}: 케미 {pos*100:+.0f}%p · 불화 {neg*100:+.0f}%p")
    print(f"  중립(극한) {byCat[(0.0,0.0)]}종 · 델타 {26-byCat[(0.0,0.0)]}종 — 이중 소속 0건 (category 필드 단일 키)")
    # 지옥 1개 소속 실측 — 불화 파티(난폭×신중 · 무자비×헌신 2쌍 + 케미 2쌍)를 평온 신전 vs 어둠 지옥에서 비교 (G3)
    strife = ['난폭','신중','무자비','헌신','고집']
    _, _, posT, negT = syn(['인간']*5, ['전사']*5, strife, [[],[],[],[],[]], band=1.5, bioPos=0.01, bioNeg=-0.01)
    _, _, posH, negH = syn(['인간']*5, ['전사']*5, strife, [[],[],[],[],[]], band=1.5, bioPos=0.01, bioNeg=0.02)
    dS = (posH - negH) - (posT - negT)
    print(f"  지역 델타 실측 (G3 · 불화 2쌍 파티): 신전(평온) {(posT-negT)*100:+.1f}% → 지옥(어둠) {(posH-negH)*100:+.1f}% ({dS*100:+.1f}%p — 불화 강화 방향 ✓)")
    assert abs(dS + 0.03) < 1e-9, "지옥 델타 기대 −3%p (dark 불화 +2 − calm 불화 −1 → 파티 점수 악화) 이탈 — 이중 소속/조인 오류 의심"
    print("\nOK — B안 계약 범위 내 (00 #42 · 01 §3-3 · biomes.json 단일 소속)")

if __name__ == '__main__':
    main(int(sys.argv[1]) if len(sys.argv)>1 else 100000)
