#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
run_mana_econ.py — §6b 시설 마나 배급 × 플탐 마석 수급 재검증 (D-267 잔여 · 문서 무변경)
질문: 은행 에너지 계정의 시설별 배급(§6b 표)이 플레이 시나리오의 마석 수급(소환 루프)을 얼마나 침식하는가?

방법:
1) energy_rate_mp(배율) 0.0/0.5/1.0/1.5/2.0 × 3 시나리오 = 15런
   - baseline : 정식 정본 (민심 50 · 계절 표준 — playthrough_audit 감사 프리셋 계승)
   - stress   : G-15 정본 스트레스 (민심 25 · 겨울·흉작·사건)
   - front    : 전선 유지비 B안 20G/층/섬일 (run_mc_probe 비교 프리셋 — 유지비 런기간 의존 최대 부하)
2) 지표 (run_sim 반환값):
   - 소환 횟수(summons) — 소환 버퍼 10,000석 규칙 때문에 잔고는 상시 ~10,000에 붙으므로
     수급 침식은 잔고가 아니라 소환 페이싱에 나타난다 (진짜 지표).
   - 에너지 소모 MP → 130MP 마석 환산 → 정본 잉여(총수급 3,590,250 − 소환소모 = 8,750석) 대비 잠식률
   - ★5 완성층(p5) · 골드 최저(gold_min) — 정본 앵커 보호 판정
3) 판정: 소환 Δ ≤ 0.1% · ★5·골드최저 무변경이면 "소환 루프 무해"
"""
import sys, os, io, contextlib
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
with contextlib.redirect_stdout(io.StringIO()):   # sim_economy는 import 시 리포트 출력 — 억제
    import sim_economy as se

MP_PER_CRYSTAL = 130          # 1마석 = 130MP (D-267 정본)
SURPLUS_CRYSTALS = 8750       # 정본 잉여 = G+E 총수급 3,590,250 − scale0 소환소모 27,550×130 (04 §3.9 · D-267 §6b)
SCALES = [0.0, 0.5, 1.0, 1.5, 2.0]
SCN = {
    "baseline": se.SCENARIOS["baseline"],                          # 정식 정본 프리셋
    "stress":   se.SCENARIOS["stress"],                            # G-15 정본 스트레스 (민심 25·겨울·흉작·사건)
    "front":    dict(se.SCENARIOS["baseline"], front_maint=20),    # 전선 유지비 B안 20G/층/섬일 (run_mc_probe 프리셋)
}

rows = []
print("═══ §6b 시설 마나 배급 × 플탐 마석 수급 (순환 OFF — 에너지 순수 담보 잠식) ═══")
print(f"{'시나리오':10}{'scale':>6}{'소환':>9}{'에너지MP':>11}{'→마석':>8}{'잉여잠식':>9}{'★5':>5}{'골드최저':>13}")
for scn_name, preset in SCN.items():
    for s in SCALES:
        r = se.run_sim(f"{scn_name}@x{s}", dict(preset, energy_rate_mp=s))
        mp = int(r["energy_spent_mp"])
        row = dict(scn=scn_name, s=s, summons=r["summons"], mp=mp,
                   cry=mp // MP_PER_CRYSTAL,
                   eat=mp / MP_PER_CRYSTAL / SURPLUS_CRYSTALS * 100,
                   p5=r["p5"], gmin=int(r["gold_min"]), gf=r["gold_min_f"])
        rows.append(row)
        print(f"{scn_name:10}{s:>6}{row['summons']:>9,}{mp:>11,}{row['cry']:>7,}석{row['eat']:>8.2f}%"
              f"{str(row['p5']):>5}{row['gmin']:>10,}G@{row['gf']:<2}")

print()
print("═══ scale 0 기준 소환 침식 (수급 잠식의 직접 체감치) ═══")
print(f"정본 잉여 재고: {SURPLUS_CRYSTALS:,}석 — 쿼터 기준선: S2 88% · S3 51% · 100층 106% (04 §3.9 G+E 재계산표)")
ok = True
for scn_name in SCN:
    base = next(r for r in rows if r["scn"] == scn_name and r["s"] == 0.0)
    print(f"── {scn_name} (기준: 소환 {base['summons']:,} · ★5 {base['p5']}층 · 골드최저 {base['gmin']:,}@{base['gf']})")
    for r in rows:
        if r["scn"] == scn_name and r["s"] > 0:
            ds = (r["summons"] - base["summons"]) / base["summons"] * 100
            print(f"   scale {r['s']}: 소환 {r['summons']:,} ({ds:+.3f}%) · 잉여잠식 {r['eat']:.2f}%"
                  f" · ★5 {r['p5']}층 · 골드최저 {r['gmin']:,}@{r['gf']}")
            if ds < -0.1 or r["p5"] != base["p5"] or abs(r["gmin"] - base["gmin"]) > 1:
                ok = False

print()
print("✓ 소환 루프 무해 — 소환 Δ≤0.1% · ★5·골드최저 전 런 정본 유지" if ok
      else "✗ 기준선 이탈 런 존재 — 상단 확인")
