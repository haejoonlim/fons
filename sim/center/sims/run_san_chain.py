#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
run_san_chain.py — 위생 체인(san_chain 노브) 밴드 영향 검증 (D-256 후속 · 2026-09-18)
04 §3.12 "내부 사건 원인 체인" 가안의 정량 검증 — 발동률 변조(extra_p)가 G-15 밴드에 미치는 영향.

구조: 역병 1회 발동 시 san_chain.extra_p 확률로 연쇄 역병(피해 plague_mul) 추가 — 기하분포.
- 결정론: 기댓값 프레이밍 (extra_p/(1-extra_p) 회 추가 적용 — 스크래치 검증용 근사, 명시 주석)
- MC(seed): 실제 추첨 — 위생도 낮을 때의 분산까지 관측
노브: extra_p 0/0.2/0.3/0.5 × plague_mul 0.95/0.90 × 격리(preserve) 유무 × 3시드
정본: san_chain 미설정 — baseline·stress 궤적 무영향 (먼저 회귀 확인)

판정 기준 (P4·P11 밴드): 아사 1~15 · 파업 5~20 · 골드 최저 ≥ -22,000 · ★5 ≤ 60
"""
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import io, contextlib
import sim_economy as se

STRESS = dict(se._STRESS_BASE)
BAND = {"starve": (1, 15), "strike": (5, 20), "gold": -22_000, "p5": 60}

def run(tag, **over):
    scn = dict(STRESS); scn.update(over)
    buf = io.StringIO()
    with contextlib.redirect_stdout(buf):
        r = se.run_sim(tag, scn)
    return r

def judge(r):
    notes = []
    loss_pct = (1 - r["pop_loss"]) * 100
    if not (BAND["starve"][0] <= r["starve_floors"] <= BAND["starve"][1]):
        notes.append(f"아사 {r['starve_floors']} 밴드 이탈")
    if not (BAND["strike"][0] <= r["strike_floors"] <= BAND["strike"][1]):
        notes.append(f"파업 {r['strike_floors']} 밴드 이탈")
    if r["gold_min"] < BAND["gold"]:
        notes.append(f"골드 {r['gold_min']:,.0f} 한계 초과")
    if r["p5"] and r["p5"] > BAND["p5"]:
        notes.append(f"★5 {r['p5']}층 지연")
    return notes

# ── 0) 정본 회귀: san_chain 미설정 시 stress 무변경 ──
r0 = run("정본 stress")
r0b = run("정본 stress(재실행)")
same = (r0["starve_floors"] == r0b["starve_floors"] and abs(r0["gold_min"] - r0b["gold_min"]) < 1)
print("═══ 0) 정본 회귀 (san_chain 미설정) ═══")
print(f"  stress: 아사 {r0['starve_floors']} · 파업 {r0['strike_floors']} · 골드 {r0['gold_min']:,.0f} · 인구손실 {(1-r0['pop_loss'])*100:.1f}% · 재실행 동일={same}")

# ── 1) 결정론 기댓값 프레이밍 스윕 ──
print("\n═══ 1) 위생 체인 스윕 — 결정론 (기댓값 프레이밍) ═══")
print(f"  {'구성':<28} {'아사':>4} {'파업':>4} {'골드최저':>10} {'인구손실':>8} {'추가역병(기대)':>10}  판정")
rows = []
for extra_p, pmul in [(0.0, 0.95), (0.2, 0.95), (0.3, 0.95), (0.5, 0.95), (0.3, 0.90)]:
    for preserve in (False, True):
        tag = f"extra_p={extra_p} ×{pmul}" + (" +격리" if preserve else "")
        over = {"san_chain": {"extra_p": extra_p, "plague_mul": pmul}}
        if preserve:
            over["san_chain"]["quarantine_cost"] = 500
        r = run(tag, **over)
        n = judge(r)
        rows.append((tag, r, n))
        print(f"  {tag:<28} {r['starve_floors']:>4} {r['strike_floors']:>4} {r['gold_min']:>10,.0f} {(1-r['pop_loss'])*100:>7.1f}% {r['extra_plagues']:>10.2f}  {'⚠ ' + '; '.join(n) if n else '밴드 내'}")

# ── 2) MC 3시드 — 위생도 최악(결핍 고정) 가정에서의 분산 ──
print("\n═══ 2) MC 3시드 — san_chain ON (extra_p=0.3) 최악 케이스 ═══")
worst = {"starve": 0, "strike": 0, "gold": 0.0, "p5": 0}
for seed in (11, 22, 33):
    r = run(f"sanMC{seed}", mc_seed=seed, san_chain={"extra_p": 0.3, "plague_mul": 0.95})
    worst["starve"] = max(worst["starve"], r["starve_floors"])
    worst["strike"] = max(worst["strike"], r["strike_floors"])
    worst["gold"] = min(worst["gold"], r["gold_min"])
    if r["p5"]: worst["p5"] = max(worst["p5"], r["p5"])
    n = judge(r)
    print(f"  seed {seed}: 아사 {r['starve_floors']} · 파업 {r['strike_floors']} · 골드 {r['gold_min']:,.0f} · 추가역병 {r['extra_plagues']:.2f} · {'⚠ ' + '; '.join(n) if n else '밴드 내'}")
print(f"  3시드 최악: 아사 {worst['starve']} · 파업 {worst['strike']} · 골드 {worst['gold']:,.0f} · ★5 {worst['p5']}")
print(f"  밴드 대조: 아사 ≤15 {'✅' if worst['starve'] <= 15 else '❌'} · 파업 ≤20 {'✅' if worst['strike'] <= 20 else '❌'} · 골드 ≥-22,000 {'✅' if worst['gold'] >= -22_000 else '❌'} · ★5 ≤60 {'✅' if worst['p5'] <= 60 else '❌'}")

# ── 3) 격리(방어 투자) 효과 — 시설 연동이 실제로 피해를 줄이는지 ──
print("\n═══ 3) 방어 효과 — 격리 옵션 유무 비교 (extra_p=0.3 고정) ═══")
base = run("격리무", san_chain={"extra_p": 0.3, "plague_mul": 0.95})
prot = run("격리유", san_chain={"extra_p": 0.3, "plague_mul": 0.95, "quarantine_cost": 500})
print(f"  무방어: 인구손실 {(1-base['pop_loss'])*100:.1f}% · 아사 {base['starve_floors']}층")
print(f"  격리  : 인구손실 {(1-prot['pop_loss'])*100:.1f}% · 아사 {prot['starve_floors']}층 — 방어 효과 {'✅ 관측' if (1-prot['pop_loss'])*100 < (1-base['pop_loss'])*100 or prot['starve_floors'] < base['starve_floors'] else '⚠ 없음'}")
print("\n완료 — 판정: 위생 체인은 '방어 투자 시 피해만 감소' 선에서 밴드 유지 확인 목적 (정본 무변경)")
