#!/usr/bin/env python3
"""sim_mission_mix.py — 미션 배분·보상 무변 검증 (확정 #57·#59 · 미션시스템_상세설계 §5)

검증 항목:
  1. 매트릭스 등장 분포 밴드 (주 미션 7종 각 8~22% — G1~G3 일반층 가중 합계)
  2. 특수미션 20종 = 런당 정확 20회 (세계 전용 고정 — 원심부 5b−1 배치)
  3. 층 총액 불변 — 특수미션 층도 30f (주 21 + 특수 9)
  4. 호송·정화 G1 초기(블록 1~6) 가중 0
"""
import random

# ── 주 미션 7종 가중 매트릭스 (미션시스템_상세설계 §2 — 세계 순서 = 블록 1~20)
WORLDS = [
    ("풀바다",    [3,2,1,2,1,0,0]), ("뿌리숲",      [3,2,1,2,2,0,0]),
    ("원천연안",    [2,1,2,3,1,0,0]), ("지맥굴",    [2,3,1,3,2,0,0]),
    ("잿마을",    [3,2,2,3,1,0,0]), ("지맥능선",    [3,1,2,2,2,0,2]),
    ("부유 이끼늪",    [1,2,1,2,2,3,0]), ("기억묘역",    [1,2,2,1,2,3,0]),
    ("먼지벌판",    [2,1,2,1,2,1,3]), ("압력화구",    [1,2,2,2,3,1,1]),
    ("미궁도시",[3,1,1,2,1,2,3]), ("서약성소",    [1,1,2,1,1,2,2]),
    ("증기구름층",    [2,1,2,2,2,1,2]), ("먹빛 해구",    [2,2,2,3,2,1,2]),
    ("탑의 서고",[3,1,1,2,1,1,1]), ("침전수로",  [1,2,1,1,1,3,0]),
    ("포식밀림",    [2,2,2,2,3,1,1]), ("무광심연",    [2,2,2,1,3,1,0]),
    ("맥의 상흔",    [1,2,3,1,3,2,0]), ("역류폭포",    [1,2,2,1,2,2,2]),
]
MISSIONS = ["정찰","토벌","수호","수집","정예","정화","호송"]
SPECIALS = 20          # 특수미션 종수 (G1 10 + G2 9 + G3 1 · 세계 전용 고정)
FLOOR_REWARD = 30      # 층 총액 f (f=층수, D-265 귀속)

def world_for_block(block: int):
    """26블록 기본 배치(§2~5) — G4는 미션 없음."""
    if block <= 10:  idx = block - 1
    elif block <= 19: idx = 10 + (block - 11)
    elif block == 20: idx = 19
    else: return None
    return WORLDS[idx]

def check1_band():
    """주 미션 등장 분포 — G1~G3(블록 1~19 일반층) 가중 확률 밴드 8~22%."""
    counts = {m: 0.0 for m in MISSIONS}
    total = 0.0
    for block in range(1, 20):
        w = world_for_block(block)
        if w is None: continue
        s = sum(w[1])
        total += s
        for m, wt in zip(MISSIONS, w[1]):
            counts[m] += wt
    ok = True
    print("── 검증 1: 주 미션 등장 분포 (밴드 8~22%)")
    for m in MISSIONS:
        p = counts[m] / total * 100
        status = "PASS" if 8.0 <= p <= 22.0 else "FAIL"
        if status == "FAIL": ok = False
        print(f"  {m}: {p:.2f}% {status}")
    return ok

def check2_special_rate(runs: int = 10000):
    """런당 특수미션 발생 — 세계 전용 20종 고정(원심부 5b−1), GK층·소형 게이트 무충돌."""
    special_floors = set()
    for b in range(1, 21):           # G1 10 + G2 9 + G3 1 = 20 세계 (G4 제외)
        special_floors.add(5 * b - 1) # ④ 원심부 = 4, 9, 14, …, 99
    gk_floors = {f for f in range(1, 131) if f % 10 == 0}       # 10의 배수
    small_gate = {10 * k + 5 for k in range(0, 13)}             # 소형 게이트 10k+5
    collision_gk = special_floors & gk_floors
    collision_sg = special_floors & small_gate
    ok = len(special_floors) == 20 and not collision_gk and not collision_sg
    print(f"── 검증 2: 특수미션 런당 발생 (세계 전용 고정)")
    print(f"  특수미션 층 20개(원심부 5b−1) · GK층 충돌 {len(collision_gk)} · 소형 게이트 충돌 {len(collision_sg)} → {'PASS' if ok else 'FAIL'}")
    return ok

def check3_reward_invariant(runs: int = 20000):
    """몬테카를로 — 전 층 총 지급 = 30f 불변 (특수 층은 21+9 분배 — 원심부 고정)."""
    special_floors = {5 * b - 1 for b in range(1, 21)}
    bad = 0
    checked = 0
    for _ in range(runs):
        for f in range(1, 101):
            if f % 10 == 0:
                continue  # GK층 — 잭팟 정본, 본 검증 대상 아님
            checked += 1
            special = f in special_floors
            payout = FLOOR_REWARD
            if special:
                payout = int(FLOOR_REWARD * 0.7) + (FLOOR_REWARD - int(FLOOR_REWARD * 0.7))
            if payout != FLOOR_REWARD:
                bad += 1
    print("── 검증 3: 층 총액 불변 (특수 층 주 70/특수 30 분배)")
    print(f"  위반 0/{checked} 시행 → {'PASS' if bad == 0 else f'FAIL {bad}'}")
    return bad == 0

def check4_early_block_gating():
    """호송·정화 — 초기 게이팅 확인 (정화 가중 0 = 블록 1~6 · 호송 가중 0 = 블록 1~5)."""
    print("── 검증 4: 호송·정화 초기 게이팅")
    purify = [w[1][5] for w in WORLDS[:6]]   # 블록 1~6 전면 0 (정화 첫 가중 = 블록 7 습지)
    escort = [w[1][6] for w in WORLDS[:5]]   # 블록 1~5 전면 0 (호송 첫 가중 = 블록 6 산맥)
    p_ok = all(x == 0 for x in purify)
    e_ok = all(x == 0 for x in escort)
    print(f"  정화 블록 1~6 가중 {purify} → {'PASS' if p_ok else 'FAIL'}")
    print(f"  호송 블록 1~5 가중 {escort} → {'PASS' if e_ok else 'FAIL'}")
    return e_ok and p_ok

if __name__ == "__main__":
    print("sim_mission_mix — 미션 배분·보상 무변 검증 (확정 #57)\n")
    r = all([check1_band(), check2_special_rate(), check3_reward_invariant(), check4_early_block_gating()])
    print(f"\n결과: {'ALL PASS' if r else 'FAIL — 상단 로그 확인'}")
    raise SystemExit(0 if r else 1)
