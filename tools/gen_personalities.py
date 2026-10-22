#!/usr/bin/env python3
"""성격 데이터 → `data/personalities.json` (+ `godot/data/` 사본).

무엇을 만드나
-------------
영웅 AI(`godot/core/brain.gd`)가 쓰는 성격표다. **새 수치를 여기서 결정하지 않는다** —
정본에 있는 값만 옮기고, 정본에 없는 기질 수치(5축 다이얼)는 이 파일에만 두되 `basis` 로 근거를 적는다.

| 항목 | 출처 |
|---|---|
| 메인 13 × role 적합도 | `docs/gdd/GDD_v8.0_05_영웅생성.md` §5-1 표 (파싱 — 손으로 옮기지 않는다) |
| 메인 13 → 도메인 편차 | 위 적합도 × `data/job_ai_profiles.json` `meta.role_base` (파생 — 아래 식) |
| 부가 52 도메인 선호/반대 | `gacha_test.SUB_DOM_W` (09 §4-4 스펙표와 같은 값 · CP 계산이 쓰는 그 상수) |
| 부가 52 대척쌍 | `gacha_test.OPPOSITE_PAIRS` |
| 메인 롤 가중치 | `gacha_test.P_WEIGHT` |
| 적성 13 → 도메인 · 7티어 | `gacha_test.APT_DOMAIN` · `APT_TIER` |
| 기질 다이얼 5종 | **이 파일이 정한다** (가안) — 05 §5 의 보정 문장을 행동으로 번역 |

도메인 편차 식
-------------
    domain_dev(P, d) = Σ_r (fit(P, r) − 0.5) × (role_base[r][d] − 1)

`fit − 0.5` 는 GDD 05 §5-1 이 전직 축에서 쓰는 "편차만 잰다" 규칙과 같다. 중립(0.5)이면 0 이다.
`role_base` 에 `생활` 행이 없어 `무직` 을 대리로 쓴다 (07 §무직 = 생활직과 같은 role 표).
결과 범위는 실측 −0.09 ~ +0.12 라 `M = 1 + dev` 가 09 §4-1 의 0.7~1.3 밴드 안에 들어온다.

실행
----
    ./.venv/bin/python tools/gen_personalities.py          # 생성 + 사본
    ./.venv/bin/python tools/gen_personalities.py --check   # 정본과 다르면 exit 1
"""
import argparse
import json
import re
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent.parent
GDD05 = HERE / "docs" / "gdd" / "GDD_v8.0_05_영웅생성.md"
JOB_PROFILES = HERE / "data" / "job_ai_profiles.json"
OUT = HERE / "data" / "personalities.json"
MIRROR = HERE / "godot" / "data" / "personalities.json"

MAIN = ["용감", "신중", "냉정", "난폭", "헌신", "교활", "무자비",
        "불굴", "낭만", "고집", "성실", "몰입", "노련"]
ROLES = ["선봉", "수호", "암살", "포격", "마법", "지원", "무직", "생활"]
DOMAINS = ["공격", "기동", "방어·제어", "지원", "생산", "지식", "사회", "회복"]

# ── 기질 다이얼 5종 (가안 — 05 §5 의 「보정(가안)」 문장을 행동으로 번역) ──────────
#   1.0 = 중립. 값은 배율이라 스탯·CP 에는 절대 닿지 않는다 (AI 행동 선호 전용).
#   risk     공격 도메인 가중 · 저체력에서도 밀어붙이는가
#   novelty  ε(개체 노이즈) 폭 · 안 해 본 행동을 고를 확률
#   habit    R(습관) 항 강도 · 같은 행동을 이어서 하는가
#   patience 스킬 아끼기 · 큰 기술을 기다리는가
#   care     지원·회복 도메인 가중 · 남을 먼저 챙기는가
DIALS = {
    "용감":   (1.15, 1.00, 0.95, 1.00, 0.95, "ATK +5% — 먼저 부딪힌다"),
    "신중":   (0.85, 0.90, 1.10, 1.10, 1.00, "DEF +5% — 지고 들어간다"),
    "냉정":   (0.95, 0.95, 1.00, 1.15, 0.85, "CRI +3%p — 급소만 노린다"),
    "난폭":   (1.35, 1.05, 0.85, 0.80, 0.80, "ATK +8% / DEF −3% — 물러서지 않는다"),
    "헌신":   (0.85, 0.95, 1.05, 1.00, 1.35, "치유 +10% — 남을 먼저 챙긴다"),
    "교활":   (0.90, 1.15, 1.00, 1.10, 0.90, "MS +5% — 판을 본 뒤 움직인다"),
    "무자비": (1.10, 1.00, 1.00, 1.20, 0.85, "CDMG +10%p — 끝을 본다"),
    "불굴":   (1.20, 0.95, 1.15, 1.00, 0.95, "HP 30% 이하 방어 +10% — 버틴다"),
    "낭만":   (1.05, 1.20, 0.90, 1.00, 1.10, "사기 +20% — 판을 즐긴다"),
    "고집":   (1.10, 0.85, 1.30, 1.05, 0.95, "스트레스 −20% — 같은 방식을 고수한다"),
    "성실":   (1.00, 0.90, 1.20, 1.10, 1.05, "경험치 +5% — 꾸준히 한다"),
    "몰입":   (1.05, 1.10, 1.25, 1.15, 0.90, "성장 +15% — 한 우물을 판다"),
    "노련":   (1.00, 1.00, 1.15, 1.25, 1.00, "경험치 +10% — 요령이 몸에 붙어 있다"),
}
DIAL_DOC = {
    "risk": "공격 도메인 가중 · 저체력에서도 밀어붙이는가",
    "novelty": "ε(개체 노이즈) 폭 · 안 해 본 행동을 고를 확률",
    "habit": "R(습관) 항 강도 · 같은 행동을 이어서 하는가",
    "patience": "스킬 아끼기 · 큰 기술을 기다리는가",
    "care": "지원·회복 도메인 가중 · 남을 먼저 챙기는가",
}


def parse_role_fit() -> dict:
    """GDD 05 §5-1 의 13×8 표를 읽는다. 행이 13개가 아니면 실패한다 (표가 바뀌면 조용히 넘어가지 않는다)."""
    text = GDD05.read_text(encoding="utf-8")
    out = {}
    for line in text.splitlines():
        if not line.startswith("| "):
            continue
        cells = [c.strip() for c in line.strip().strip("|").split("|")]
        if len(cells) != len(ROLES) + 1 or cells[0] not in MAIN:
            continue
        vals = []
        for c in cells[1:]:
            c = c.replace("*", "")
            try:
                vals.append(float(c))
            except ValueError:
                break
        if len(vals) == len(ROLES):
            out[cells[0]] = vals
    missing = [m for m in MAIN if m not in out]
    if missing:
        raise SystemExit("05 §5-1 표에서 못 읽은 성향: %s" % ", ".join(missing))
    for main, vals in out.items():
        bad = [v for v in vals if v not in (0.3, 0.5, 0.7, 1.0)]
        if bad:
            raise SystemExit("05 §5-1 적합도 값이 0.3/0.5/0.7/1.0 밖: %s %s" % (main, bad))
    return out


def domain_dev(fit: dict, role_base: dict) -> dict:
    """성격 → 8도메인 편차. role_base 에 없는 `생활` 은 `무직` 으로 대리한다."""
    dev = {}
    for d in DOMAINS:
        total = 0.0
        for i, role in enumerate(ROLES):
            base_role = "무직" if role == "생활" else role
            total += (fit[role] - 0.5) * (role_base[base_role][d] - 1.0)
        dev[d] = round(total, 4)
    return dev


def build() -> dict:
    sys.path.insert(0, str(HERE / "sim" / "center" / "sims"))
    import gacha_test as G  # 정본 상수 — 복사하지 않고 읽는다

    fit = parse_role_fit()
    role_base = json.loads(JOB_PROFILES.read_text(encoding="utf-8"))["meta"]["role_base"]

    main = {}
    for name in MAIN:
        risk, novelty, habit, patience, care, basis = DIALS[name]
        main[name] = {
            "role_fit": dict(zip(ROLES, fit[name])),
            "domain_dev": domain_dev(dict(zip(ROLES, fit[name])), role_base),
            "dial": {"risk": risk, "novelty": novelty, "habit": habit,
                     "patience": patience, "care": care},
            "basis": basis,
            "weight": G.P_WEIGHT.get(name, 0),
        }

    sub = {}
    for name in G.SUB_TRAITS:
        prefer, prefer2, avoid = G.SUB_DOM_W[name]
        sub[name] = {"prefer": [d for d in (prefer, prefer2) if d],
                     "avoid": avoid or ""}

    return {
        "meta": {
            "schema_version": "1.0",
            "generator": "tools/gen_personalities.py",
            "source": "GDD 05 §5-1 (role 적합도) · GDD 09 §4-4 (부가 52) · gacha_test 상수 (SUB_DOM_W·P_WEIGHT) · job_ai_profiles.json meta.role_base",
            "invariant": "성격은 AI 행동 선호만 바꾼다 — 스탯·CP·등급 계산에 절대 들어가지 않는다 (09 §4-1 'CP 무영향')",
            "domain_dev": "Σ_r (fit−0.5) × (role_base[r][d]−1) · 생활 열은 무직 대리 · 실측 −0.092 ~ +0.116",
            "sub_weight": {"prefer": G.SUB_EFF_X, "avoid": G.SUB_EFF_Y,
                           "rule": "도메인당 1회 캡 (09 v0.8)"},
            "dial_doc": DIAL_DOC,
            "dial_note": "가안 — 05 §5 보정 문장의 행동 번역. 플탐 튜닝 대상이며 스탯에는 닿지 않는다.",
        },
        "domains": DOMAINS,
        "roles": ROLES,
        "main": main,
        "sub": sub,
        "opposite_pairs": [list(p) for p in G.OPPOSITE_PAIRS],
        "apt_domain": G.APT_DOMAIN,
        "apt_tier": {str(k): v for k, v in G.APT_TIER.items()},
        "apt_weight": list(G.APT_W),
        "apt_tier_grade_gate": {str(k): v for k, v in G.TIER_GRADE_GATE.items()},
    }


def dump(data: dict) -> str:
    return json.dumps(data, ensure_ascii=False, indent=1) + "\n"


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--check", action="store_true", help="정본과 다르면 exit 1 (생성하지 않는다)")
    args = ap.parse_args()

    text = dump(build())
    if args.check:
        # 게이트 계약 (`tools/gate_contract.py`) — 마지막 줄이 `[PASS] personality` /
        # `[FAIL] personality — 이유` 여야 gate_all 이 이 단계의 결과를 읽는다.
        if not OUT.exists():
            print("[FAIL] personality — %s 없음" % OUT)
            return 1
        if MIRROR.exists() and MIRROR.read_text(encoding="utf-8") != text:
            print("[FAIL] personality — godot/data 사본이 생성기 출력과 다름 (cp %s %s)" % (OUT, MIRROR))
            return 1
        if OUT.read_text(encoding="utf-8") != text:
            print("[FAIL] personality — %s 가 생성기 출력과 다름 (다시 돌리세요)" % OUT)
            return 1
        print("PERSONALITIES OK: %s" % OUT.name)
        print("[PASS] personality")
        return 0

    OUT.write_text(text, encoding="utf-8")
    MIRROR.write_text(text, encoding="utf-8")
    data = json.loads(text)
    print("WROTE %s (%d main · %d sub · %d pairs)" % (
        OUT, len(data["main"]), len(data["sub"]), len(data["opposite_pairs"])))
    print("MIRROR %s" % MIRROR)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
