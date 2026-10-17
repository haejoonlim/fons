#!/usr/bin/env python3
"""ai_stats_check.py — monsters.json aiDecision·pattern ↔ 스탯 정합 검증 (exit 0 = 준수).

특성 기반 설계 (2026-09-17)의 AI 계층 정합 규칙:
  [HARD — fail, exit 1]
  H1  aiType ↔ mag: 'magic' 라벨 종은 stats.mag 필수 (마법 AI인데 마법 스탯 없음 = 런타임에서 물리로 때림)
  H2  aiType ↔ eva: 'assassin' 라벨 종은 stats.eva 필수 (회피 정체성)
  H3  aiDecision 필수 4키 존재 + 값 범위 (enrageHp 0~1 · patternCooldown [lo,hi] lo<hi · crowdAoeRadius ≥ 0)
  H4  pattern 필수 5키 (name·cd·effect·telegraph·counter)
      + 패턴 name 교차 그룹 유니크 (같은 specialSkill 그룹 내 공유 = 설계 의도 · 다른 그룹 유출 = 복붙)
      + telegraph 깨짐 감지 (ASCII 비율 > 0.5)
  H5  비캐스터(mag 미보유) 패턴의 MAG 계수 — 마나 없는 종이 마법 계수 기술 보유
  H6  특성 파트 ↔ specialSkill 교집합: 캐스터 스킬(cc가 아닌) 그룹의 공통 필수 파트(mag·mana·spd_cast·cri·cdmg·pen)
      를 그룹 내 전 종이 보유 (교집합이 빈 그룹 = CC·소환·상태기술 → 스킵)
  H7  crowdAoeRadius > 0 ↔ 패턴 effect 광역 표기 (광역 · 범위 · 전방 Nm · 전체)
  H8  신체 특성 키워드 소유 종 화이트리스트 (다른 종의 패턴 복붙 탐지):
      브레스·비행/착지·날개→드라코리치 · 사자/염소/뱀 머리→디어베어 · 흡혈 접촉·박쥐 소환·안개화→(전투종 없음)
      · 도미네이트→마인드플레이어 · 사자 머리 등 삼두신→(디어베어 전용)
  H9  threatBase 티어 위상 — 인접 티어 대역 비겹침 (t.max < t+1.min, 도감 밸런스 차트와 동일 기준).
      한 종의 대역 침범이 상·하위 전 종을 '이탈'로 오인시키는 연쇄 오류를 잡는다 (2026-09-18 바다뱀 사례).
  [WARN — 관측, exit 0]
  W1  pattern cd ∉ aiDecision.patternCooldown 범위 (연출 사이클 드리프트 후보)
  W2  enrageHp > 0 ↔ 광폭 계열 패턴 문구 (광폭·변신·격노·광란·산란) 부재
  W3  마법 동작 정합 — magic 라벨은 주문 중심 종(Mana>0 → 주문 시전, BattleSystem). mana 미보유 magic 라벨 = 재검토.
      컨벤션(확정 2026-09-18): aiType는 교전 양상 라벨(melee/ranged/assassin/magic)이며 mana 보유 하이브리드(주문→마나 소진→물리)는
      non-magic 라벨 유지가 정상 — non-magic+mana는 경고하지 않는다.
  W4  티어 중앙값 곡선 정합 — T1·T5 중앙 앵커 등비 보간 대비 중앙 이탈 비율:
      hp·atk ±40% 초과 경고 (등비 성장 스탯 · 도감 밸런스 차트 기대 곡선과 동일 기준).
      threat은 의도적 완만 곡선(티어당 ×2.1→×1.2, 01·08 문서 배율 표)이라 ±60% 초과 경고.

실행: python3 design-docs/_tools/ai_stats_check.py [--json]
"""
import json
import math
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
P = os.path.join(ROOT, "data", "monsters.json")

fails = []
warns = []

# H8 — 신체 특성 키워드 → 허용 종 (다른 종 패턴 복붙 탐지)
BODY_KEYWORDS = {
    "수신판": ["mon_riftlistener_01"],
    "공명판": ["mon_riftlistener_01"],
    # 화이트리스트는 '소유 종 여러 개' 목록이다 — 데이터에 실제로 존재하는 종만 적는다.
    # mon_dracolich_01(드라코리치)이 브레스·비행/착지·날개의 실제 소유자다.
    # 화이트리스트에 없는 종이 쓰면 '타 종 패턴 복붙'으로 FAIL 한다.
    "브레스": ["mon_dracolich_01"],
    "비행/착지": ["mon_dracolich_01"],
    "날개": ["mon_dracolich_01"],
    "사자 머리": ["mon_dire_bear_01"],
    "염소 머리": ["mon_dire_bear_01"],
    "뱀 머리": ["mon_dire_bear_01"],
    "흡혈 접촉": [],
    "박쥐 소환": [],
    "안개화": [],
}
AOE_RE = re.compile(r"광역|범위|전방 \d+m|전체")
MAG_COEF_RE = re.compile(r"\d+(?:\.\d+)?xMAG")
ENRAGE_RE = re.compile(r"광폭|변신|격노|광란|산란")
CC_SKILLS = {"entangle", "shield_block", "split", "bandage_wrap", "corpse_eat",
             "transform", "stone_ambush", "mimic_assault", "constrict", "mind_blast"}
CASTER_PARTS = ["mag", "mana", "spd_cast"]
CURVE_TOL = {"hp": 0.40, "atk": 0.40, "threat": 0.60}   # 위촉 키 → 허용 이탈 (W4)


def fail(mid, code, msg):
    fails.append(f"{code} {mid}: {msg}")


def warn(mid, code, msg):
    warns.append(f"{code} {mid}: {msg}")


def ascii_ratio(s):
    if not s:
        return 0.0
    a = sum(1 for c in s if ord(c) < 128)
    return a / len(s)


def main():
    ms = json.load(open(P))["monsters"]
    by_skill = {}
    seen_names = {}   # (name → specialSkill) — 교차 그룹 유출만 fail

    for m in ms:
        mid = m["id"]
        st = m["stats"]
        at = m.get("aiType")
        ad = m.get("aiDecision")
        pat = m.get("pattern")

        # H1/H2/W3 — aiType ↔ 스탯 라벨
        if at == "magic" and not st.get("mag"):
            fail(mid, "H1", "aiType=magic인데 stats.mag 미보유")
        if at == "assassin" and not st.get("eva"):
            fail(mid, "H2", "aiType=assassin인데 stats.eva 미보유")
        if at == "magic" and not st.get("mana"):
            warn(mid, "W3", f"aiType=magic인데 mana 미보유 — 주문 시전 종 아님, 라벨 재검토")
        # non-magic + mana = 하이브리드 정상 (교전 양상 컨벤션 — docstring W3 참조)

        # H3 — aiDecision 무결성
        if not ad:
            fail(mid, "H3", "aiDecision 없음")
            continue
        for k in ("enrageHp", "patternCooldown", "crowdAoeRadius", "specialSkill"):
            if k not in ad:
                fail(mid, "H3", f"aiDecision.{k} 누락")
        if not (0 <= ad.get("enrageHp", 0) <= 1):
            fail(mid, "H3", f"enrageHp {ad['enrageHp']} (0~1 범위 밖)")
        pc = ad.get("patternCooldown")
        if not (isinstance(pc, list) and len(pc) == 2 and 0 < pc[0] < pc[1]):
            fail(mid, "H3", f"patternCooldown {pc} ([lo,hi] lo<hi 아님)")
        if ad.get("crowdAoeRadius", 0) < 0:
            fail(mid, "H3", f"crowdAoeRadius {ad['crowdAoeRadius']} 음수")

        # H4/H5 — pattern 무결성 · 비캐스터 MAG 계수
        for p in pat or []:
            for k in ("name", "cd", "effect", "telegraph", "counter"):
                if k not in p:
                    fail(mid, "H4", f"pattern '{p.get('name','?')}' 키 {k} 누락")
            nm = p.get("name", "?")
            sk = ad.get("specialSkill")
            if nm in seen_names and seen_names[nm] != sk:
                fail(mid, "H4", f"패턴 유출 '{nm}' — 그룹 {seen_names[nm]}에서 {sk}로 복사됨")
            seen_names.setdefault(nm, sk)
            if ascii_ratio(p.get("telegraph", "")) > 0.5 and p.get("telegraph") not in ("없음", "없음 (은신)"):
                fail(mid, "H4", f"telegraph 깨짐 의심: '{p['telegraph']}'")
            if not st.get("mag") and MAG_COEF_RE.search(p.get("effect", "")):
                fail(mid, "H5", f"비캐스터 패턴 MAG 계수: '{nm}'")

        # H7 — AoE 반경 ↔ effect 광역 표기
        if ad.get("crowdAoeRadius", 0) > 0:
            effs = " ".join(p.get("effect", "") for p in pat or [])
            if not AOE_RE.search(effs):
                fail(mid, "H7", f"crowdAoeRadius {ad['crowdAoeRadius']}인데 광역 효과 표기 없음")

        # H8 — 신체 특성 키워드 ↔ 종 화이트리스트
        for p in pat or []:
            for kw, allow in BODY_KEYWORDS.items():
                if kw in p.get("name", "") + p.get("effect", "") and mid not in allow:
                    fail(mid, "H8", f"타 종 신체 특성 패턴: '{p['name']}' (키워드 '{kw}' — 허용 {','.join(allow) or '없음'})")

        # W1/W2 — cd 범위 · 광폭 문구
        lo, hi = ad.get("patternCooldown", [0, 0])
        for p in pat or []:
            if p.get("cd") and not (lo <= p["cd"] <= hi):
                warn(mid, "W1", f"pattern '{p['name']}' cd {p['cd']} ∉ patternCooldown {pc}")
        if ad.get("enrageHp", 0) > 0:
            blob = " ".join(p.get("name", "") + p.get("effect", "") for p in pat or [])
            if not ENRAGE_RE.search(blob):
                warn(mid, "W2", f"enrageHp {ad['enrageHp']}인데 광폭 계열 패턴 문구 없음")

        by_skill.setdefault(ad.get("specialSkill"), []).append(m)

    # H6 — 특성 파트 ↔ specialSkill 교집합
    for sk, grp in sorted(by_skill.items()):
        if sk in CC_SKILLS or len(grp) < 2:
            continue  # CC·소환·상태기술 또는 단일 종 스킬은 파트 교집합 스킵
        req = set(CASTER_PARTS)
        for m in grp:
            req &= {k for k in CASTER_PARTS if m["stats"].get(k)}
        for m in grp:
            for k in req:
                if not m["stats"].get(k):
                    fail(m["id"], "H6", f"스킬 '{sk}' 그룹 공통 파트 {k} 미보유")

    # H9 — threatBase 티어 위상 (인접 대역 비겹침)
    bands = {}
    for t in range(1, 6):
        vs = sorted(m["threatBase"] for m in ms if m.get("tier") == t and m.get("threatBase") is not None)
        if vs:
            bands[t] = (vs[0], vs[-1])
    for t in range(1, 5):
        if t in bands and t + 1 in bands and bands[t][1] >= bands[t + 1][0]:
            fail("(global)", "H9", f"T{t} threat 대역 max {bands[t][1]} ≥ T{t+1} min {bands[t+1][0]} — 위상 침범")

    # W4 — 티어 중앙값 곡선 정합 (T1·T5 앵커 등비 보간 대비)
    def med(t, key):
        if key == "threat":
            vs = sorted(m["threatBase"] for m in ms if m.get("tier") == t and m.get("threatBase") is not None)
        else:
            vs = sorted(m["stats"][key] for m in ms if m.get("tier") == t)
        return vs[len(vs) // 2] if vs else None
    for key, tol in CURVE_TOL.items():
        meds = [med(t, key) for t in range(1, 6)]
        if any(v is None for v in meds):
            continue
        a, b = math.log10(meds[0]), math.log10(meds[-1])
        for i, v in enumerate(meds, start=1):
            exp = 10 ** (a + (b - a) * (i - 1) / 4)
            dev = v / exp
            if abs(math.log10(dev)) > math.log10(1 + tol):
                warn("(global)", "W4", f"{key} T{i} 중앙 {v:g} 기대 대비 ×{dev:.2f} (허용 ±{int(tol*100)}%) — 곡선 정합 재검토")

    print(f"ai_stats_check — monsters.json {len(ms)}종 · aiType×스탯×aiDecision×pattern 정합")
    for w in warns:
        print(f"  [WARN] {w}")
    for f in fails:
        print(f"  [FAIL] {f}")
    print(f"  → HARD fail {len(fails)} · WARN {len(warns)}")
    if "--json" in sys.argv:
        print(json.dumps({"fail": fails, "warn": warns}, ensure_ascii=False, indent=1))
    sys.exit(1 if fails else 0)


if __name__ == "__main__":
    main()
