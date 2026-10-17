#!/usr/bin/env python3
"""먹이그물 전투 연동 시뮬 — 08 §4 경로의 전투 영향 정량 검증 (2026-09-16).

질문: 포식·분해 경로가 ① 층 클리어 속도 ② 청소부 부스트 피드백 ③ 전투 난이도에
어떤 영향을 주는가? (Unity 미구현 상태 — 08 §8 "관계 밀도 기반 스폰" 제안의 사전 검증)

모델 (07 §8 법칙 승계 — audit_sim 규격):
  생태   : 로지스틱 dN = rN(1−N/K) + Holling II 포식 (a·Np·Nq/(20+Nq)) — 쌍방 전이 일관
  사체   : 클리어 처치 × 0.5 corpse (픽업 절반 회수 가안) → 분해·청소 섭취 → 10% 전환
  스폰   : S0 고정 가중 / S1+ 관계 가중 w = 1 + α·attr
           attr = 기능반응 — 자기 먹이의 가용률 평균 (종 피식: N_prey/K_prey · corpse: C/(C+5))
  클리어 : 조우 6체 (D-261) 기대치 → Σ(HP)/DPS · GK 보스는 10·15·20층 별도 합산 (06 §3.4)
  담당자 : S3 activity 가중 (nocturnal ×1.5 — 밤 클리어 가정)
  비교   : S1+ 지표를 S0와 **동일 층 매칭 비율**로 비교 — 풀 구성 그래디언트 제거

시나리오: S0 베이스 / S1 관계가중 / S2 관계가중+청소캡 / S3 S2+담당자스위치
           S4 S3+AI전투연동(공포 전파·사체 유인 — 캐릭터AI_생태연동 §3 · 2026-09-21)
           S5 S4+먹이 전환(G-3 Type III — 생태계_이론개선안 · 2026-09-22)
  S5 모델: 포식자가 선호 먹이를 임계 밀도 이하로 몰아먹으면 포식 압력이 급감(Holling III)
           → 피식 종이 멸종 대신 자연 회복. "무한 사냥에 자연적 제동" — 이론개선안 1순위 G-3
  S4 모델: ① 공포 전파 — 조우 패배 시 목격자 무리의 겁이 올라 다음 조우 승산↓ (피격 유입 corpse 감쇠)
           ② 사체 유인 — 전투 사체가 EcoLedger식 corpse로 적립되어 청소 전투몬 스폰 가중 추가 부스트
           ※ AI는 개체수를 직접 바꾸지 않는다 — corpse·겁 계수만 스폰 가중에 반영 (안전장치 §6)
사냥 순서: 청소부 우선 vs 포식자 우선 (월드 처치 3킬 × 개체 제거 2.0)
바이옴 3종 대표: 초원(피식 풍부) · 하수도(청소 전투몬 밀집) · 동굴(사슬 깊이 7)

실행: python3 design-docs/_tools/sim_foodweb_combat.py (결정적 — 시드 고정)
가안 파라미터는 CONST 블록에 명시 — 플탐 튜닝 대상.
"""
import json
import os

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
DATA = os.path.join(ROOT, "data")

# ── 가안 상수 (플탐 튜닝 대상) ─────────────────────────────────
FLOORS = 20                  # 검증 구간 (g1 밴드)
ENCOUNTER_SLOTS = 6         # 층=생태계(D-261) — 생태 조우 1회의 조우 규모 (D-261 이전 명칭: 조우 6체 (D-261))
WORLD_KILLS = 3              # 층당 생물 처치 수 (전리품 사냥 가정)
KILL_REMOVAL = 2.0           # 사냥 1회당 개체 제거량 (N 단위)
CORPSE_PER_KILL = 0.5        # 처치 1당 corpse 잔량 (픽업 50% 가안)
CORPSE_DECAY = 0.7           # 틱당 자연 분해 잔존율
ALPHA = 0.5                  # 관계 가중 스폰 강도 (S1+)
SCAV_CAP = 2.5               # S2 — 청소 전투몬 스폰 가중 상한 배율
R_BASE = 0.35                # 로지스틱 r (audit_sim 승계)
A_HOLLING = 0.10             # Holling II 포식계수 (느린 틱 보정 — 증폭)
CONVERT = 0.10               # 10% 법칙 — 섭취→개체수 전환
NIGHT_MULT = 1.5             # S3 — 밤 클리어 시 nocturnal 스폰 가중
FEAR_WITNESS = 0.06          # S4 — 조우 패배 1건당 목격 무리 겁 +0.06 (CombatPersona 드리프트 0.03×2 동조 가안)
FEAR_DECAY = 0.9             # S4 — 층 진입 시 겁 감쇠 잔존율 (전투 한정·런 미저장 정신 승계)
FEAR_WIN_ODDS = 0.12         # S4 — 겁 최대치에서 승산 하락폭 (교전 회피 확률로 환산)
WITNESS_SHARE = 0.35         # S4 — 패배 조우를 목격한 무리 비율 (전투 중 시야 내 동료)
SWITCH_QUOTA = 0.35          # S5 G-3 — 선호 먹이가 K의 35% 이하로 떨어지면 포식자가 다른 먹이로 전환
SWITCH_RELIEF = 0.75         # S5 — 전환 시 선호 먹이에 대한 포식 압력 완화율 (Type III 백분위 75%)
DPS = 900.0                  # 플레이어 DPS (스케일 캘리브레이션용)
CORPSE_HALF = 5.0            # 기능반응 포화 상수 (corpse)
PRED_ROLES = {"predator", "hunter", "ambusher", "apex"}
SCAV_ROLES = {"decomposer", "scavenger"}
TRACE = os.environ.get("TRACE") == "1"

bi_groups = json.load(open(os.path.join(DATA, "biomes.json")))["groups"]
mon = json.load(open(os.path.join(DATA, "monsters.json")))["monsters"]
amb = json.load(open(os.path.join(DATA, "ambient.json")))["ambient"]
all_sp = {s["id"]: s for s in mon + amb}

_BY_ID = {b["id"]: b for g in bi_groups for b in g["biomes"]}


def _pick(bid):
    """바이옴을 id 로 고르고 **이름과 habitat 을 데이터에서 읽는다**.

    원래 `next(b["habitat"] ... if b["name"] == "초원")` 로 이름을 박아뒀다. D-277 에서
    biome_plains 의 이름이 "초원" → "풀바다" 로 바뀌면서 이 줄이 StopIteration 로 죽었고,
    이 시뮬은 run_snapshots.SIMS 에도 없어 아무도 돌려보지 않았다. 테스트 센터에 없는
    시뮬은 죽어 있어도 조용하다.

    그리고 `next()` 는 habitat 의 **첫 항목만** 읽는다. biome_plains 의 habitat 은
    [grassland, plains, meadow] 세 개인데 첫 항목 grassland 에는 전투몬이 0종이다.
    그래서 combat_pool() 이 매층 빈 풀로 떨어져 floor 루프가 20번 연속 continue 하고
    logs["clear"] 가 빈 채로 남았다 — 그 결과가 max() 의 빈 수열 크래시였다.
    밸런스가 아니라 **데이터 해석**의 문제였고, habitat 을 통째로 읽으면 풀바다 4종으로
    살아난다(지맥굴도 11 → 12종).
    """
    return _BY_ID[bid]["name"], _BY_ID[bid]["habitat"]


_plains, _plains_hab = _pick("biome_plains")
_sewer, _sewer_hab = _pick("biome_sewer")
_cave, _cave_hab = _pick("biome_cave")

BIOMES = {
    _plains: {"K": 140, "habs": _plains_hab},
    _sewer:  {"K": 95,  "habs": _sewer_hab},
    _cave:   {"K": 80,  "habs": _cave_hab},
}
GK = {10: "mon_doppelganger_01", 15: "mon_riftlistener_01", 20: "mon_dreadnought_01"}  # 06 §3.4 배치
# 인과 실험 대상 — 바이옴별 "대형 전투몬이 ambient를 직접 먹는" 간선 (08 §5.2 편입분)
CAUSAL_KILL = {
    _cave: ["먼지벌레", "쥐"],      # 거미 여왕의 ambient prey — 매층 사냥 시 여왕 스폰 가중 하락 기대
}


def eco_members(habs):
    return [s for s in amb if set(s["ecology"]["habitat"] or []) & set(habs)]


def combat_pool(habs, floor):
    """해당 바이옴·층의 전투 조우 풀 (D-261). 층 창 공백 시 habitat 풀로 폴백 (스포너 현실 가정)."""
    def window(m):
        fl = m["spawn"]["floors"] or [0]
        return min(fl) <= floor <= max(fl)
    pool = [m for m in mon
            if set(m["ecology"]["habitat"] or []) & set(habs)
            and m["spawn"].get("mode") != "world"
            and m["spawn"].get("mode") != "boss"]
    hit = [m for m in pool if window(m)]
    return hit or pool          # 폴백: 층 창 밖이면 habitat 전체


def attr_of(m, N, Kmap):
    """기능반응 — 자기 먹이 가용률 평균 (0~1). 종 피식: N_prey/K_prey · corpse: C/(C+5)."""
    vals = []
    for p in m["ecology"]["prey"] or []:
        if p.startswith("mon_"):
            if p in Kmap and Kmap[p] > 0:
                vals.append(min(1.0, N["amb"].get(p, 0.0) / Kmap[p]))
        elif p == "corpse":
            vals.append(N["corpse"] / (N["corpse"] + CORPSE_HALF))
    return sum(vals) / len(vals) if vals else 0.0


def run(biome, mode, order="mix", seed=7, force_kill=None):
    cfg = BIOMES[biome]
    habs, K = set(cfg["habs"]), cfg["K"]
    members = eco_members(habs)
    preds = [s for s in members if s["ecology"]["role"] in PRED_ROLES]
    scav = [s for s in members if s["ecology"]["role"] in SCAV_ROLES]

    def kof(s):
        role = s["ecology"]["role"]
        if role in PRED_ROLES:
            return K * 0.10 / max(len(preds), 1)
        if role in ("prey", "swarm"):
            return K * 0.55 / 2
        return K * 0.35 / 3

    Kmap = {s["id"]: kof(s) for s in members}
    N = {"amb": {s["id"]: kof(s) * 0.6 for s in members}, "corpse": 0.0}
    rng = [seed * 2654435761 % (2**31)]

    def rand():
        rng[0] = (rng[0] * 1103515245 + 12345) & 0x7FFFFFFF
        return rng[0] / 0x7FFFFFFF

    logs = {k: [] for k in ("clear", "threat", "scav_share", "scav_N", "corpse")}
    boss_threat = {}
    # S4 — AI 전투연동 상태 (EcoLedger 동형: 런 단위 · 결정론)
    fear = 0.0                  # 무리 평균 겁 (0~1) — 조우 패배 목격 시 상승, 층 진입 감쇠
    ai_corpse = 0.0             # AI 전투 사체 장부 (전투몬 처치 × CORPSE_PER_KILL — 08 §4 동형)
    rout_streak = 0             # 연속 패배(궤주) — 공포 전파 검증 지표

    for f in range(1, FLOORS + 1):
        pool = combat_pool(habs, f)
        if not pool:
            continue
        # ── 스폰 가중 ──
        w = {}
        for m in pool:
            base = 1.0
            if mode != "S0":
                a = attr_of(m, N, Kmap)
                base = 1.0 + ALPHA * a
                if mode >= "S2" and m["ecology"]["role"] in SCAV_ROLES:
                    base = min(base, SCAV_CAP)
                if mode == "S3" and m["ecology"].get("activity") == "nocturnal":
                    base *= NIGHT_MULT
                if mode == "S4":
                    # ② 사체 유인 — 전투 corpse 장부가 청소 전투몬 가중을 추가 부스트 (캡 위 가안)
                    if m["ecology"]["role"] in SCAV_ROLES:
                        base += ALPHA * ai_corpse / (ai_corpse + CORPSE_HALF) * (1.0 if ai_corpse > 0 else 0.0)
            w[m["id"]] = base
        tot_w = sum(w.values()) or 1.0
        share = {k: v / tot_w for k, v in w.items()}
        # ── 조우 기대치 → 클리어·위협 ──
        hp_sum = sum(share[i] * ENCOUNTER_SLOTS * all_sp[i]["stats"]["hp"] for i in share)
        threat = sum(share[i] * ENCOUNTER_SLOTS * all_sp[i]["threatBase"] for i in share)
        if f in GK and GK[f] in share:
            hp_sum += all_sp[GK[f]]["stats"]["hp"]
            threat += all_sp[GK[f]]["threatBase"]
            boss_threat[f] = threat
        # S4 ① 공포 전파 — 겁이 높은 층은 몬스터 교전 승산이 떨어져 조우 몬스터가 늦게 정리된다.
        #   (AI가 개체수를 직접 건드리지 않는 대신, 겁 계수만 전투 난이도 유입에 반영 — 안전장치 §6)
        if mode == "S4" and fear > 0:
            hp_sum *= 1.0 + FEAR_WIN_ODDS * fear   # 겁 최대치에서 클리어 시간 +12% 가안
        logs["clear"].append(hp_sum / DPS)
        logs["threat"].append(threat)
        logs["scav_share"].append(sum(s for i, s in share.items()
                                      if all_sp[i]["ecology"]["role"] in SCAV_ROLES))
        if TRACE and f in (1, 5, 20) and mode == "S0":
            top = sorted(share.items(), key=lambda kv: -kv[1])[:3]
            print(f"    [{biome} f{f:02d} {mode}] " + ", ".join(f"{all_sp[i]['name']}:{s:.2f}" for i, s in top))
        # ── 사냥 → 개체 제거 + corpse ──
        if force_kill is not None:
            # 고정 킬 실험 — 특정 종을 매층 사냥 (인과 분리용)
            tgt = [s for s in members if s["name"] in force_kill and N["amb"][s["id"]] > 0.0]
            for s in tgt[:WORLD_KILLS]:
                N["amb"][s["id"]] = max(0.0, N["amb"][s["id"]] - KILL_REMOVAL)
            killed_n = min(len(tgt), WORLD_KILLS)
        else:
            alive = [s for s in members if N["amb"][s["id"]] > 1.0]
            if order == "scav":        # 청소·분해 우선 사냥
                cand = sorted(alive, key=lambda s: (0 if s["ecology"]["role"] in SCAV_ROLES else 1, -N["amb"][s["id"]]))
            elif order == "pred":      # 포식자 우선 사냥
                cand = sorted(alive, key=lambda s: (0 if s["ecology"]["role"] in PRED_ROLES else 1, -N["amb"][s["id"]]))
            else:                      # mix — 개체수 많은 순
                cand = sorted(alive, key=lambda s: -N["amb"][s["id"]])
            killed = cand[:WORLD_KILLS]
            for s in killed:
                N["amb"][s["id"]] = max(0.0, N["amb"][s["id"]] - KILL_REMOVAL)
            killed_n = len(killed)
        kills_combat = ENCOUNTER_SLOTS + (1 if f in GK else 0)
        N["corpse"] += (kills_combat + killed_n) * CORPSE_PER_KILL
        if mode == "S4":
            ai_corpse += kills_combat * CORPSE_PER_KILL            # ② 사체 유인 — 전투 처치가 장부에 적립
            # ① 공포 전파 — 플레이어 패배(궤주) 조우를 목격한 무리의 겁 상승. 결정론:
            #   위협 > 플레이어 DPS×교전시간(간접치) 조건을 "GK 층"으로 근사 — 보스전 패배 가정.
            if f in GK:
                witnesses = WITNESS_SHARE * ENCOUNTER_SLOTS
                fear = min(1.0, fear + FEAR_WITNESS * witnesses)
                rout_streak += 1
            else:
                rout_streak = 0
        # ── 생태 틱 ──
        # 1) 청소·분해 corpse 섭취 → 10% 전환
        if scav and N["corpse"] > 0:
            per = N["corpse"] / len(scav)
            for s in scav:
                gain = CONVERT * per * min(1.0, N["amb"][s["id"]] / (kof(s) + 1e-9) + 0.3)
                N["amb"][s["id"]] = min(kof(s) * 1.5, N["amb"][s["id"]] + gain)
            N["corpse"] *= 0.7
        # 2) 로지스틱 + Holling II 포식 (층 정리 사이 3틱 압축 — 사냥 반응을 관측 가능한 속도로)
        for _tick in range(3):
            newN = dict(N["amb"])
            for s in members:
                i = s["id"]
                n = newN[i]
                dn = R_BASE * n * (1 - n / kof(s))
                for p in s["ecology"].get("prey") or []:
                    if p.startswith("mon_") and p in newN:
                        dn -= A_HOLLING * n * newN[p] / (20 + newN[p])
                if s["ecology"]["role"] in SCAV_ROLES:
                    dn += CONVERT * 0.2 * N["corpse"] / max(len(scav), 1)
                newN[i] = max(0.0, n + dn)
            for s in members:      # 포식 성장 = 피식 감소 (10% 전환)
                for p in s["ecology"].get("prey") or []:
                    if p.startswith("mon_") and p in newN and newN[p] > 0:
                        # ── S5 G-3 먹이 전환 (Type III 반응) ──
                        # 피식 밀도가 K의 SWITCH_QUOTA 이하로 떨어지면, 먹이 전환으로
                        # 포식 압력이 SWITCH_RELIEF만큼 완화 — 피식 종이 멸종 대신 회복.
                        # Holling III의 시그모이드(저밀도에서 포식률 급감)를 2-분할 근사.
                        pressure = 1.0
                        if mode == "S5":
                            pk = kof(next(x for x in members if x["id"] == p))
                            if pk > 0 and newN[p] / pk < SWITCH_QUOTA:
                                pressure = 1.0 - SWITCH_RELIEF
                        eat = A_HOLLING * pressure * newN[s["id"]] * newN[p] / (20 + newN[p])
                        newN[p] = max(0.0, newN[p] - eat)
                        newN[s["id"]] += CONVERT * eat
            N["amb"] = newN
        N["amb"] = newN
        N["corpse"] *= CORPSE_DECAY
        if mode == "S4":
            fear *= FEAR_DECAY                                     # 층 진입 겁 감쇠 (런 미저장 정신)
            ai_corpse *= CORPSE_DECAY                              # 전투 사체도 같은 분해 잔존율
        logs["scav_N"].append(sum(N["amb"][s["id"]] for s in scav))
        logs["corpse"].append(N["corpse"])

    n = len(logs["clear"]) or 1
    half = n // 2
    return {
        "clear_mean": sum(logs["clear"]) / n,
        "clear_max": max(logs["clear"]),
        "threat_mean": sum(logs["threat"]) / n,
        "threat_late_ratio": (sum(logs["threat"][half:]) / max(n - half, 1))
                             / (sum(logs["threat"][:half]) / max(half, 1) or 1),
        "scav_share_mean": sum(logs["scav_share"]) / n,
        "scav_share_peak": max(logs["scav_share"]),
        "scav_N_peak": max(logs["scav_N"]) if logs["scav_N"] else 0,
        "scav_N_final": logs["scav_N"][-1] if logs["scav_N"] else 0,
        "corpse_peak": max(logs["corpse"]) if logs["corpse"] else 0,
        "fear_final": fear if mode in ("S4", "S5") else 0.0,
        "min_prey_ratio": (min((N["amb"][s["id"]] / kof(s) for s in members
                                if s["ecology"].get("prey") and kof(s) > 0), default=1.0)
                          if mode == "S5" else None),   # S5 — 최저 피식 밀도/K (전환 임계 근접도)
        "ai_corpse_final": ai_corpse if mode == "S4" else 0.0,
        "rout_streak_max": rout_streak if mode == "S4" else 0,
        "threat_series": logs["threat"],
        "clear_series": logs["clear"],
        "boss_threat": boss_threat,
    }


MODES = (("S0", "S0 고정스폰(현행)"), ("S1", "S1 관계가중(제안)"),
         ("S2", "S2 S1+청소가중캡"), ("S3", "S3 S2+담당자스위치"),
         ("S4", "S4 S3+AI전투연동(공포·사체)"), ("S5", "S5 S4+먹이전환(G-3)"))


def _g3_selftest():
    """G-3 먹이 전환 단위 검증 — 과잉 포식 압력에서 S4(멸종) vs S5(회복) 분기 확인.
    Holling II는 밀도 의존이라 정상 평형에선 개입 불필요(시뮬 S4≈S5 = 안전 확인) —
    개입이 필요한 극단 압력에서만 차이가 나야 '자연적 제동'으로 기능."""
    import importlib.util as _ilu
    spec = _ilu.spec_from_file_location("sfw_g3", __file__)
    sfw = _ilu.module_from_spec(spec)
    spec.loader.exec_module(sfw)
    A, Q, RELIEF, CONVERT = sfw.A_HOLLING, sfw.SWITCH_QUOTA, sfw.SWITCH_RELIEF, sfw.CONVERT

    def _run(prey, pred, s5, t_max=400):
        for _ in range(t_max):
            pressure = 1.0
            if s5 and prey / 100.0 < Q:
                pressure = 1.0 - RELIEF
            eat = A * pressure * pred * prey / (20 + prey)
            prey = max(0.0, prey - eat) + 0.35 * prey * (1 - prey / 100.0)
            pred += CONVERT * eat
            if prey <= 0.001:
                return 0.0
        return prey

    p4 = _run(60, 30, s5=False)
    p5 = _run(60, 30, s5=True)
    assert p4 < 0.01, f"S4(전환 없음) 멸종 기대 — 실측 {p4:.3f}"
    assert p5 > 20.0, f"S5(전환) 회복 기대 20%+ — 실측 {p5:.3f}"
    print(f"G-3 selftest PASS — 과잉 포식 압력: S4 멸종({p4:.3f}) → S5 회복({p5:.1f}/K100)")

if __name__ == "__main__":
    import sys
    if "--selftest-g3" in sys.argv:
        _g3_selftest()
        sys.exit(0)
    print("=" * 96)
    print("먹이그물 전투 연동 시뮬 — 포식·분해 경로의 클리어 속도·청소부 부스트·난이도 영향")
    print("=" * 96)
    for biome in (_plains, _sewer, _cave):
        print(f"\n■ {biome} (K={BIOMES[biome]['K']}) — {FLOORS}층 구간")
        res = {m: run(biome, m) for m, _ in MODES}
        base = res["S0"]
        hdr = (f"{'시나리오':22} {'클리어평균':>7} {'위협평균':>7} {'위협/S0':>7} {'후반/S0':>7} "
               f"{'청소몬점유':>8} {'청소몬점유피크':>10} {'corpse피크':>9}")
        print(hdr)
        for mode, label in MODES:
            r = res[mode]
            print(f"{label:22} {r['clear_mean']:7.1f} {r['threat_mean']:7.0f} "
                  f"{r['threat_mean']/base['threat_mean']:7.3f} {r['threat_late_ratio']/base['threat_late_ratio']:7.3f} "
                  f"{r['scav_share_mean']:8.2f} {r['scav_share_peak']:10.2f} {r['corpse_peak']:9.1f}")
        # 청소부 개체수 피드백 (생태층)
        s0, s2 = base["scav_N_peak"], res["S2"]["scav_N_peak"]
        if s0 > 0:
            print(f"  ↳ 청소부 N: S0 피크 {s0:.1f} → S2 피크 {s2:.1f} ({(s2/s0-1)*100:+.1f}% — 사냥 사체 유입분)")
        else:
            print(f"  ↳ 청소부 N: S0 피크 {s0:.1f} → S2 피크 {s2:.1f} (S0 기반 0 — corpse 경로 신설분)")
        # 인과 분리 실험 — 고정 킬: "대형 포식자의 ambient 먹이를 매층 사냥"하면 위협·클리어가 어떻게 변하는가
        # 대상: 동굴 거미 여왕(3200hp)의 ambient prey = 먼지벌레·쥐 (초원·하수도는 전투몬 prey가 ambient가 아님 — 08 데이터 공백)
        a0 = run(biome, "S1", force_kill=[])
        a1 = run(biome, "S1", force_kill=CAUSAL_KILL.get(biome, []))
        def late(r):
            ls = r["threat_series"]
            return sum(ls[9:]) / max(len(ls) - 9, 1)   # f10~20 — 풀 고정 구간
        l0, l1 = late(a0), late(a1)
        c0, c1 = a0["clear_mean"], a1["clear_mean"]
        print(f"  ↳ 대형 포식자 먹이 사냥 실험 ({', '.join(CAUSAL_KILL.get(biome, ['—'])) or '대상 없음'}): "
              f"후반 위협 {l0:.0f}→{l1:.0f} ({(l1/l0-1)*100:+.1f}%) · 클리어 {c0:.2f}→{c1:.2f} ({(c1/c0-1)*100:+.1f}%)")
        # 청소 전투몬 점유 이동 (부스트 실체) — S1이 corpse 가중을 받는다
        g0 = base["scav_share_mean"]
        g1 = res["S1"]["scav_share_mean"]
        g2 = res["S2"]["scav_share_mean"]
        print(f"  ↳ 청소 역할 전투몬 스폰 점유: S0 {g0:.2f} → S1 {g1:.2f} ({(g1/g0-1)*100:+.1f}%) → S2 캡 {g2:.2f}")
        # S4 — AI 전투연동 밸런스 판정 (캐릭터AI_생태연동 §4 검증 질문에 대한 정량 응답)
        r4 = res["S4"]
        share4 = r4["scav_share_mean"]
        print(f"  ↳ S4 공포 전파: 최종 겁 {r4['fear_final']:.2f} · 궤주 연쇄 {r4['rout_streak_max']} · "
              f"클리어 영향 {r4['clear_mean']/base['clear_mean']*100-100:+.1f}% (상한 +12%×겁 — 난이도 무영향 원칙 검증)")
        print(f"  ↳ S4 사체 유인: AI 장부 최종 {r4['ai_corpse_final']:.1f} → 청소몬 점유 S3 {res['S3']['scav_share_mean']:.2f} → "
              f"S4 {share4:.2f} ({(share4/res['S3']['scav_share_mean']-1)*100:+.1f}% — 시체 안 치우면 청소부 몰림)")
        ok = (r4['clear_mean']/base['clear_mean'] < 1.15) and (share4/res['S3']['scav_share_mean'] < 1.30)
        print(f"  ↳ S4 밸런스 게이트: 클리어 <115% · 청소점유 <130% → {'PASS' if ok else 'FAIL — 가안 재조정 필요'}")
        # 청소 전투몬 가중 공식 요약 — corpse 평형에서의 부스트 크기
        c_eq = res["S1"]["corpse_peak"]
        print(f"  ↳ corpse 평형 {c_eq:.1f} → 청소 전투몬 w = 1+α·C/(C+5) = {1 + ALPHA * c_eq/(c_eq + CORPSE_HALF):.2f} "
              f"(+{(ALPHA * c_eq/(c_eq + CORPSE_HALF))*100:.0f}% — 사냥할수록 청소 전투몬이 몰린다)")
    print("\n※ 가안: DPS 900 · 슬롯 6 · 월드 3킬(제거 2.0) · corpse/킬 0.5 · α 0.5 · r 0.35 · Holling 0.10 · 층당 3틱")
