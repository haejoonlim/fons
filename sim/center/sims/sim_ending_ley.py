#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""sim_ending_ley.py — 엔딩 3분기 도달 시뮬 (계정 지표 · 지맥 소진 런 반복 · 09-21).

정본:
  판정식(자유도원칙_Unity구현사양 §4 · StoryDirector.JudgeEnding):
    봉인  = ley ≥ 0.6 && rel ≥ 0
    흡수  = ley < 0.3 || rel ≤ −6
    공존  = 그 외
  지맥 노브(D-268 · estate.json manaCycle.ley_health):
    start 1.0 · penalty_per_kill 0.06 · natural_recovery_per_day 0.10
    · floor_mul_min_hard_limit 0.55 (런 1회 내 하한 — "사망 불가 설계")
  이월 규칙(Permadeath.StartNewRun · 09-21 결함 수복):
    leyHealth는 계정 지표 → 런 간 이월. (수복 전: estate 리셋 → 매 런 1.0 시작 → 흡수 경로 도달 불가)

시나리오:
  S1 학살형(문지기 연패): 런당 15층 클리어 × 층당 처치 8 · 자연회복 1회/층 — 패배마다 ley·leyBottomed 이월
  S2 보존형(관찰·보류):   S1 대비 처치 1/3 — 하한 접촉 없음
  S3 계열 적대(rel) 경로: rel 합계가 −6 이하로 하락하는 선택 반복 — rel 단독 흡수
  서사 페이스(템포): 흡수는 첫 런에 나오면 안 된다 — "문지기 하한 접촉 3런 누적" 템포 게이트(leyBottomTrials)로 유의한 런 수 확보.
판정:
  P1 수복 전 규칙(이월 없음)에서는 흡수(ley 경로) 도달 0 — 결함 재현
  P2 수복 후 규칙(이월 있음)에서 학살형이 유의한 런 수 내 흡수 도달 (leyBottomed — D-268 하한 0.55 접촉 = "바닥을 본 계정")
  P3 보존형은 봉인(ley ≥ 0.6) 유지 — 학살형과 경로 분리 확인
  P4 rel 경로 단독 도달 확인
  P5 C# 판정 미러 정합 (흡수 선행 — 바닥 접촉 계정은 회복돼도 봉인 불가)
  P6 **S-3 현행 판정식**(지맥 × 광로 회복률) 격자 미러 — 위 P1~P5는 **구 3분기의 지맥 수학 기록**으로 보존한다
출력: 시뮬 표 + 판정 PASS/FAIL — run_snapshots 'ending_ley' 등재 대상.

⚠ **S-3 개정 (2026-09-27)** — 판정 축 2번째가 **계열 관계 총합 → 광로 회복률(account.lightwayRecovery)** 로 교체되었다.
   아래 `judge()`·`judge_v10()` 및 P1~P5는 구 3분기의 판정식을 그대로 다루는 **역사 기록**이며, 현행 판정 미러는 `judge_s3()` 다.
"""
import json
import os

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
ESTATE = json.load(open(os.path.join(ROOT, "data/estate.json"), encoding="utf-8"))
LH = ESTATE["manaCycle"]["ley_health"]

START = LH["start"]
KILL = LH["penalty_per_kill"]
RECOVER = LH["natural_recovery_per_day"]
HARD_MIN = LH["floor_mul_min_hard_limit"]
BOTTOM_EPS = 1e-4   # C# float 접촉 판정(ManaCycleEngine.OnKill)과 동일 여유

SEAL_LEY, SEAL_REL = 0.6, 0
ABSORB_LEY, ABSORB_REL = 0.3, -6

# 전투 처치 분포(정본 런타임 계약): 유닛끼리 서로 죽이는 생태 전투 — 영웅 처치분만 지맥 페널티(ManaCycleEngine.OnKill 호출처 GameRoot.Battle t.IsHero 공격자 필터는 없으나
#   생태 웹이 "몬스터가 몬스터를 죽인다" 구조이므로 지맥 페널티 대상 = 영웅 관여 처치분만이라는 가정이 D-268 학살 페널티의 의미).
#   시뮬은 관여율 노브를 둔다: 학살형 = 적 8체 중 영웅 관여 4체(나머지는 생태 포식 — 페널티 없음), 보존형 = 관여 1체.
HERO_KILLS_MASSACRE = 4
HERO_KILLS_CONSERVE = 1
FLOORS_PER_RUN = 15
LEYBOTTOM_TRIALS = 3   # 흡수 템포 게이트 — 하한 접촉 런 3회 누적 후 흡수역 진입 (서사: "세 번의 바닥" — 99번째 재림 조응)

# ── S-3 개정 (2026-09-27): 판정 축 2번째가 계열 관계 총합 → 광로 회복률로 교체 (바이블 §4.5 · GDD 00 #72) ──
LEY_SETTLE_MIN = 0.70      # 지맥 정지 구간 하한
LIGHTWAY_CRACK_MIN = 0.25  # 광로 균열 구간 하한 (부분 녹음)
LIGHTWAY_THAW_MIN = 0.60   # 광로 녹음 구간 하한 (원형 복원)


def judge_s3(ley: float, lw: float, bottomed: bool = False, bottomed_runs: int = None) -> str:
    """StoryDirector.JudgeEnding **현행(S-3)** 미러 — 7분가지.
    저하 지맥 구간에서는 회복률이 높을수록 결과가 나쁘다(하늘은 열리고 아래는 무너진다 → 다시 탑)."""
    runs = ns_bottomed_runs if bottomed_runs is None else bottomed_runs
    gated = (bottomed and runs >= LEYBOTTOM_TRIALS) or (bottomed_runs is not None and runs >= LEYBOTTOM_TRIALS)
    if ley < ABSORB_LEY or gated:
        return "내려앉음"
    if ley >= LEY_SETTLE_MIN:
        if lw >= LIGHTWAY_THAW_MIN:
            return "이름"
        if lw >= LIGHTWAY_CRACK_MIN:
            return "131회차"
        return "열린 문"
    if lw >= LIGHTWAY_THAW_MIN:
        return "다시 탑"
    if lw >= LIGHTWAY_CRACK_MIN:
        return "녹음"
    return "지워짐"


def judge_v10(ley: float, rel: int) -> str:
    """수복 전(v1.0 원문식 — ley < 0.3 or rel ≤ −6만, bottomed 개념 없음) — P1 결함 재현 전용."""
    if ley >= SEAL_LEY and rel >= SEAL_REL:
        return "봉인"
    if ley < ABSORB_LEY or rel <= ABSORB_REL:
        return "흡수"
    return "공존"


ns_bottomed_runs = 0   # 하한 접촉 런 누적 — judge의 템포 게이트 입력(모듈 상태, 시뮬 전용)


def judge(ley: float, rel: int, bottomed: bool = False, bottomed_runs: int = None) -> str:
    """StoryDirector.JudgeEnding (09-21 개정 — leyBottomed·흡수 선행·템포 게이트) 미러.
    bottomed_runs: 하한 접촉 런 누적(게이트). None이면 bottomed=True가 곧 게이트 통과로 간주(단발 판정 — C# 계약).
    """
    runs = ns_bottomed_runs if bottomed_runs is None else bottomed_runs
    gated = (bottomed and runs >= LEYBOTTOM_TRIALS) or (bottomed_runs is not None and runs >= LEYBOTTOM_TRIALS)
    ley_path = ley < ABSORB_LEY or gated
    if ley_path or rel <= ABSORB_REL:
        return "흡수"
    if ley >= SEAL_LEY and rel >= SEAL_REL:
        return "봉인"
    return "공존"


def run_round(ley: float, hero_kills: int) -> tuple:
    """한 런(15층) 동안의 지맥 변화 — 층당 영웅 관여 처치(hero_kills)·회복 1회. 런 1회 내 하한 = hard limit.
    반환: (런 후 ley, 바닥 접촉 여부) — C# ManaCycleEngine.OnKill 클램프 로직 미러."""
    bottomed = False
    for _ in range(FLOORS_PER_RUN):
        next_ley = max(HARD_MIN, ley - KILL * hero_kills)         # 영웅 관여 처치만 페널티(생태 포식 제외)
        if next_ley <= HARD_MIN + BOTTOM_EPS:                     # 하한 접촉 기록 (C#과 동일 판정)
            bottomed = True
        ley = next_ley
        ley = min(1.0, ley + RECOVER)                             # 자연 회복(층 클리어 = 1 섬일 가안)
    return ley, bottomed


def simulate(carry: bool) -> dict:
    """carry=True = 수복 후(ley·bottomed 이월), False = 수복 전(런마다 1.0 리셋)."""
    out = {}
    for name, kpf in (("학살형", HERO_KILLS_MASSACRE), ("보존형", HERO_KILLS_CONSERVE)):
        global ns_bottomed_runs
        ley, bottomed, run = START, False, 0
        ns_bottomed_runs = 0
        trace = []
        while run < 200:
            run += 1
            if not carry:
                ley, bottomed = START, False
            ley, hit_bottom = run_round(ley, kpf)
            bottomed = bottomed or hit_bottom
            if hit_bottom:
                ns_bottomed_runs += 1   # 템포 게이트 — 접촉 런 누적
            j = judge_v10(ley, 0) if not carry else judge(ley, 0, bottomed, ns_bottomed_runs)
            trace.append((run, round(ley, 4), j))
            if j == "흡수":
                break
        out[name] = {"runs": run, "final_ley": round(ley, 4), "bottomed": bottomed,
                     "ending": judge_v10(ley, 0) if not carry else judge(ley, 0, bottomed, ns_bottomed_runs),
                     "reached_absorb": (judge_v10(ley, 0) if not carry else judge(ley, 0, bottomed, ns_bottomed_runs)) == "흡수",
                     "trace_tail": trace[-3:]}
    return out


def main():
    print(f"정본 노브 — start {START} · kill {KILL} · recovery {RECOVER} · hard_min {HARD_MIN}")
    print(f"런 정의 — {FLOORS_PER_RUN}층/런 · 영웅 관여 처치: 학살형 {HERO_KILLS_MASSACRE}/층 · 보존형 {HERO_KILLS_CONSERVE}/층 (생태 포식분 페널티 없음)")
    print()

    print("■ P1 — 수복 전(이월 없음 · estate 런 리셋 · v1.0 원문식) 재현")
    before = simulate(carry=False)
    for k, v in before.items():
        print(f"  {k}: {v['runs']}런 → ley {v['final_ley']} · {v['ending']} · 흡수도달 {v['reached_absorb']}")
    p1 = not before["학살형"]["reached_absorb"]
    print(f"  → 결함 재현(흡수 0 도달): {'PASS' if p1 else 'FAIL'}")
    print()

    print("■ P2·P3 — 수복 후(ley 계정 이월)")
    after = simulate(carry=True)
    for k, v in after.items():
        tail = " · ".join(f"{r}런 ley{l}→{j}" for r, l, j in v["trace_tail"])
        print(f"  {k}: {v['runs']}런 → ley {v['final_ley']} · {v['ending']} · [{tail}]")
    p2 = after["학살형"]["reached_absorb"]
    p3 = after["보존형"]["ending"] == "봉인"
    print(f"  → 학살형 흡수 도달: {'PASS' if p2 else 'FAIL'}")
    print(f"  → 보존형 봉인 유지(경로 분리): {'PASS' if p3 else 'FAIL'}")
    print()

    print("■ P4 — rel 경로 단독 (rel 합계 −6)")
    p4 = judge(1.0, -7, bottomed_runs=LEYBOTTOM_TRIALS) == "흡수"
    print(f"  ley 1.0 · rel −7 → {judge(1.0, -7, bottomed_runs=LEYBOTTOM_TRIALS)} : {'PASS' if p4 else 'FAIL'}")
    print()

    print("■ P5 — C# 판정 미러 정합 (JudgeEnding leyBottomed 해석)")
    p5 = (judge(0.65, 0, True, LEYBOTTOM_TRIALS) == "흡수"
          and judge(0.65, 0, True, 1) == "봉인"
          and judge(0.7, 0, False, 0) == "봉인")
    print(f"  접촉 {LEYBOTTOM_TRIALS}런 → {judge(0.65, 0, True, LEYBOTTOM_TRIALS)} / 접촉 1런 → {judge(0.65, 0, True, 1)} / 미접촉 → {judge(0.7, 0, False, 0)} : {'PASS' if p5 else 'FAIL'}")
    print()
    print("■ P6 — S-3 현행 판정식 미러 (지맥 × 광로 회복률 · 계열 관계 미사용)")
    grid_expect = {
        # (ley, lw)                    : 기대 엔딩
        (0.10, 0.00): "내려앉음", (0.20, 0.70): "내려앉음",   # 하한 = 광로 무관
        (0.80, 0.70): "이름", (0.80, 0.30): "131회차", (0.80, 0.00): "열린 문",
        (0.50, 0.70): "다시 탑", (0.50, 0.30): "녹음", (0.50, 0.00): "지워짐",
    }
    p6 = True
    for (ley, lw), want in grid_expect.items():
        got = judge_s3(ley, lw, bottomed_runs=0)
        flag = "PASS" if got == want else "FAIL"
        if got != want:
            p6 = False
        print(f"  ley {ley:.2f} · lw {lw:.2f} → {got:<6} (기대 {want}) : {flag}")
    # 저하 구간의 방향 역전 — 회복률이 높을수록 결과가 나빠진다
    p6b = judge_s3(0.50, 0.70) == "다시 탑" and judge_s3(0.50, 0.00) == "지워짐"
    p6 = p6 and p6b
    print(f"  저하 구간 방향 역전(회복↑ → 결과↓): {'PASS' if p6b else 'FAIL'}")
    # 계정 템포 게이트는 광로와 무관하게 내려앉음을 연다
    p6c = judge_s3(0.80, 0.70, True, LEYBOTTOM_TRIALS) == "내려앉음"
    p6 = p6 and p6c
    print(f"  하한 접촉 {LEYBOTTOM_TRIALS}런 → 광로 무관 내려앉음: {'PASS' if p6c else 'FAIL'}")
    print()

    ok = p1 and p2 and p3 and p4 and p5 and p6
    print(f"결과 — 6판정 {'전부 PASS' if ok else 'FAIL 존재'}")
    return 0 if ok else 1


if __name__ == "__main__":
    raise SystemExit(main())
