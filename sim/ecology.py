"""생태 시뮬 — 원본 `audit_sim.py` 의 1:1 포팅 (07 §8 · 08 §2).

이 파일이 존재하는 이유
----------------------
07 §8 의 로지스틱·로트카-볼테라·마르코프 12시즌은 원본 저장소의
`design-docs/_tools/audit_sim.py` 가 정본이다. 이 저장소에는 포팅이 없어서
"그런 규칙이 있다"만 문서에 남아 있었다. 여기서 그 모델을 그대로 옮겨
**지금 데이터에서도 같은 법칙이 도는지** 검사한다.

상수는 `data/ecology_model.json` 하나에 있다. Godot 런타임(`godot/core/ecology.gd`)이
같은 파일을 읽으므로 두 언어에 같은 숫자를 두 번 적지 않는다.

정본에서 옮긴 것 (값을 바꾸지 않았다 · 원본 대조)
------------------------------------------------
  마르코프 P 3×3 · 이상기후 진폭 0.4×밴드
  φ = exp(−((T−tl)/tw)²) · tl = 온도 밴드 중심 · tw = max(2, 폭/2)
  r = max(0.05, reproduction×φ) · K = max(2, Kb×(0.25+0.75φ))
  d = min(0.9, 0.05 + food_need×0.8×(1+0.4(1−φ)))
  포식 손실 = Σ aff×N_prey/(20+N_prey) · aff = 0.004 + 0.012×aggression   (Holling II)
  dN = rN(1−N/K) − 손실×N − d×N×0.2 · dt 0.05 · 400스텝/계절
  Kb = max(5, round(K×0.55/하위 종수)) · max(2, round(K×0.10/포식 종수))
  절멸 N<0.05 → 0 · 시즌 경계 25% 이주 재유입 · N ≤ 1.02K · LCG 시드
  포식 역할 = predator·hunter·ambusher·apex (guardian 은 하위층이다)

바이옴 K 는 `data/ecology_energy_channels.json` 의 근원자원 K 다 — 원본 RESOURCES
테이블과 26/26 같은 값임을 대조했다 (서고 `biome_archive` ↔ `biome_library` 별칭만 다르다).

검사 (원본 audit_sim 의 항목 중 이 저장소 데이터로 돌 수 있는 것)
---------------------------------------------------------------
  S-1 마르코프 행 합 = 1 · 대각 우세
  S-2 10% 법칙 — 포식/먹이 K 총합 비율 0.03~0.55 (26바이옴)
  S-3 LV 진폭 — 풀바다 전문 포식자(먹이 <3)의 60% 이상이 진폭 ≥15%
  S-4 열성능 φ — 60% 이상 종이 계절에 5% 이상 반응 (원본과 같이 K=80 고정)
  S-5 수치 위생 — NaN·음수·절멸 임계 흡수 누락 0건 (26바이옴 × 12계절)
  S-6 결정론 — 같은 시드 → 같은 궤적
  S-7 에너지 피라미드 — 풀바다 포식자 평균 < 피식자 평균
  P-1 패리티 픽스처 — `godot/tests/fixtures/ecology_parity.json` 이 지금 계산과 같은가
      (Godot GUT 이 이 파일을 읽어 같은 궤적인지 본다 — 모델을 고치면 다시 뽑는다)

실행
----
    ./.venv/bin/python sim/ecology.py
    ./.venv/bin/python sim/ecology.py --json
    ./.venv/bin/python sim/ecology.py --seasons 24
    ./.venv/bin/python sim/ecology.py --write-fixture
"""
import argparse
import json
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, HERE)

from foodweb import ecosystem  # noqa: E402

MODEL_NAME = "ecology_model.json"
FIXTURE = os.path.join(ROOT, "godot", "tests", "fixtures", "ecology_parity.json")
FIXTURE_SEASONS = 6
FIXTURE_SEED = 21
PRED_ROLES = {"predator", "hunter", "ambusher", "apex"}


class LCG:
    """원본과 같은 선형 합동 난수 — 시드를 고정하면 궤적이 재현된다."""

    def __init__(self, seed=1):
        self.s = seed

    def rand(self):
        self.s = (self.s * 1103515245 + 12345) & 0x7FFFFFFF
        return self.s / 0x7FFFFFFF


def load_model(data_dir):
    with open(os.path.join(data_dir, MODEL_NAME), encoding="utf-8") as f:
        return json.load(f)


def species_table(eco):
    """종 파라미터 — 원본의 기본값까지 같게."""
    out = {}
    for s in eco["species"]:
        e = s.get("ecology") or {}
        temp = e.get("temperature") or {}
        lo, hi = temp.get("min"), temp.get("max")
        if lo is None or hi is None:
            lo, hi = 0, 30
        out[s["id"]] = {
            "id": s["id"], "name": s.get("name", s["id"]),
            "role": e.get("role"), "pred": e.get("role") in PRED_ROLES,
            "rep": e.get("reproduction", 0.5),
            "food": e.get("food_need", 0.4), "agg": e.get("aggression", 0.3),
            "prey": list(e.get("prey") or []),
            "tl": lo + (hi - lo) * 0.5, "tw": max(2.0, (hi - lo) / 2.0),
        }
    return out


def k_alloc(k_total, members, model):
    """Kb — 하위 55% · 포식 10%, 종수로 나누고 floor(5·2)."""
    low = [s for s in members if not s["pred"]]
    high = [s for s in members if s["pred"]]
    kb = {}
    for s in low:
        kb[s["id"]] = max(model["k_low_floor"],
                          round(k_total * model["k_low_share"] / max(1, len(low))))
    for s in high:
        kb[s["id"]] = max(model["k_high_floor"],
                          round(k_total * model["k_high_share"] / max(1, len(high))))
    return kb


def simulate(members, k_total, climate, seasons, seed, model):
    """원본 run() — 계절마다 마르코프 → φ → K·r·d → 400스텝."""
    rng = LCG(seed) if isinstance(seed, int) else seed
    kb = k_alloc(k_total, members, model)
    st = [{"s": s, "N": kb[s["id"]] * model["initial_fraction"], "ext": False} for s in members]
    index = {o["s"]["id"]: i for i, o in enumerate(st)}
    prey_of = [[index[p] for p in o["s"]["prey"] if p in index] for o in st]
    t0 = float(climate.get("ambient", 15.0))
    band = climate.get("band") or [0, 30]
    bw = float(band[1]) - float(band[0])
    names = model["season_names"]
    matrix = model["markov"]
    dt, steps = model["dt"], model["steps"]

    anom = 1
    hist = [{"nm": names[1], "pop": {o["s"]["id"]: o["N"] for o in st}}]
    for season in range(seasons):
        row = matrix[anom]
        u = rng.rand()
        anom = 0 if u < row[0] else (1 if u < row[0] + row[1] else 2)
        temp = t0 + (-model["anomaly_offset"] * bw if anom == 0
                     else (model["anomaly_offset"] * bw if anom == 2 else 0.0))
        for o in st:
            if o["ext"]:
                continue
            s = o["s"]
            phi = math.exp(-(((temp - s["tl"]) / s["tw"]) ** 2))
            o["r"] = max(model["r_floor"], s["rep"] * phi)
            o["K"] = max(2.0, kb[s["id"]] * (model["k_phi_floor"] + model["k_phi_span"] * phi))
            o["d"] = min(model["d_max"], model["d_base"] + s["food"] * model["d_food"]
                         * (1 + model["d_phi"] * (1 - phi)))
        for _ in range(steps):
            for i, o in enumerate(st):
                if o["ext"]:
                    continue
                s = o["s"]
                loss = 0.0
                for j in prey_of[i]:
                    q = st[j]
                    if q["ext"]:
                        continue
                    loss += ((model["loss_base"] + model["loss_agg"] * (s["agg"] or 0.3))
                             * q["N"] / (model["loss_half"] + q["N"]))
                dN = (o["r"] * o["N"] * (1.0 - o["N"] / o["K"]) - loss * o["N"]
                      - o["d"] * o["N"] * model["d_weight"])
                o["N"] = max(0.0, o["N"] + dN * dt)
        for o in st:
            if o["N"] < model["extinction"]:
                o["ext"] = True
                o["N"] = 0.0
            elif not o["ext"] and o["N"] > o["K"] * model["cap"]:
                o["N"] = o["K"] * model["cap"]
        if season < seasons - 1:
            for o in st:
                if o["ext"] and rng.rand() < model["migration_chance"]:
                    o["ext"] = False
                    o["N"] = kb[o["s"]["id"]] * model["migration_base"] + model["migration_floor"]
        hist.append({"nm": names[anom], "pop": {o["s"]["id"]: o["N"] for o in st}})
    return hist, st


def season_mean(hist, name):
    rows = [h["pop"] for h in hist if h["nm"] == name]
    if not rows:
        return {}
    return {sid: sum(r[sid] for r in rows) / len(rows) for sid in rows[0]}


def build_fixture(eco, table, model):
    """Godot 패리티 픽스처 — 풀바다 6계절, 시드 고정."""
    plains = next(r for r in eco["biomes"] if r["id"] == "biome_plains")
    members = [table[i] for i in plains["members"]]
    hist, _ = simulate(members, plains["K"], plains["climate"],
                       FIXTURE_SEASONS, FIXTURE_SEED, model)
    return {
        "note": "sim/ecology.py --write-fixture 가 만든다. 손으로 고치지 않는다 — "
                "Godot FonsEcology 가 같은 궤적을 내는지 비교하는 기준값이다.",
        "scenario": {"biome": plains["id"], "k": plains["K"],
                     "seasons": FIXTURE_SEASONS, "seed": FIXTURE_SEED},
        "climate": {"ambient": plains["climate"]["ambient"],
                    "band": list(plains["climate"]["band"])},
        "species": [{"id": m["id"], "pred": m["pred"], "rep": m["rep"], "food": m["food"],
                     "agg": m["agg"], "prey": m["prey"], "tl": m["tl"], "tw": m["tw"]}
                    for m in members],
        "pop": [[h["pop"][m["id"]] for m in members] for h in hist],
    }


def run_checks(data_dir, seasons=12, fixture_check=True):
    model = load_model(data_dir)
    eco = ecosystem(data_dir)
    table = species_table(eco)
    results = []

    def check(name, ok, detail=""):
        results.append({"name": name, "ok": bool(ok), "detail": detail})

    # S-1 마르코프
    sums = [sum(row) for row in model["markov"]]
    check("S-1 마르코프 행 합=1", all(abs(x - 1.0) < 1e-9 for x in sums),
          " · ".join("%.2f" % x for x in sums))
    check("S-1 마르코프 대각 우세",
          model["markov"][0][0] > 0.5 and model["markov"][2][2] > 0.5,
          "한파 %.2f · 폭엔 %.2f" % (model["markov"][0][0], model["markov"][2][2]))

    # S-2 10% 법칙 — K 총합 비율
    ratios, fails = [], []
    for row in eco["biomes"]:
        members = [table[i] for i in row["members"]]
        if not members:
            continue
        kb = k_alloc(row["K"], members, model)
        low = sum(kb[s["id"]] for s in members if not s["pred"]) or 1
        high = sum(kb[s["id"]] for s in members if s["pred"]) or 0.001
        ratio = high / low
        ratios.append(ratio)
        if not 0.03 <= ratio <= 0.55:
            fails.append("%s:%.2f" % (row["id"], ratio))
    check("S-2 10% 법칙 K 비율 0.03~0.55", not fails,
          "실패 " + ", ".join(fails) if fails else "26바이옴 %.2f~%.2f" % (min(ratios), max(ratios)))

    # S-3 LV 진폭 — 풀바다, 전문 포식자만
    plains = next(r for r in eco["biomes"] if r["id"] == "biome_plains")
    members = [table[i] for i in plains["members"]]
    hist, st = simulate(members, plains["K"], plains["climate"], 9, 3, model)
    ids = set(plains["members"])
    waves, checked = [], 0
    for o in st:
        seq = [h["pop"][o["s"]["id"]] for h in hist]
        if max(seq) <= 0:
            continue
        if len([p for p in o["s"]["prey"] if p in ids]) >= 3:
            continue
        checked += 1
        amp = (max(seq) - min(seq)) / max(max(seq), 1e-9)
        if amp >= 0.15:
            waves.append(amp)
    share = len(waves) / max(1, checked)
    check("S-3 LV 진폭 — 전문 포식자 60% 이상 진폭 15%", share >= 0.6,
          "%d/%d종 통과" % (len(waves), checked))

    # S-4 열성능 φ — 원본과 같이 K=80 고정으로 26바이옴
    ok_count = total = 0
    for row in eco["biomes"]:
        hist, st = simulate([table[i] for i in row["members"]], 80,
                            row["climate"], 9, 11, model)
        heat, cold, norm = (season_mean(hist, model["season_names"][2]),
                            season_mean(hist, model["season_names"][0]),
                            season_mean(hist, model["season_names"][1]))
        for o in st:
            s = o["s"]
            base = norm.get(s["id"], 0.0)
            if base <= 0.2 or s["role"] == "elemental":
                continue
            total += 1
            if abs(heat.get(s["id"], 0.0) - cold.get(s["id"], 0.0)) / max(base, 1e-9) >= 0.05:
                ok_count += 1
    check("S-4 열성능 φ — 60% 이상 종 계절 반응", ok_count / max(1, total) >= 0.6,
          "%d/%d종" % (ok_count, total))

    # S-5 수치 위생 — 26바이옴 × 12계절
    dirty = []
    for row in eco["biomes"]:
        hist, _ = simulate([table[i] for i in row["members"]], row["K"],
                           row["climate"], seasons, 5, model)
        for h in hist:
            for sid, v in h["pop"].items():
                if not math.isfinite(v) or v < 0 or (0 < v < 0.049):
                    dirty.append("%s/%s" % (row["id"], sid))
    check("S-5 수치 위생 — NaN·음수·임계 흡수 누락 0", not dirty,
          "26바이옴 × %d계절" % seasons if not dirty else ", ".join(dirty[:5]))

    # S-6 결정론
    h_a, _ = simulate(members, plains["K"], plains["climate"], 6, 99, model)
    h_b, _ = simulate(members, plains["K"], plains["climate"], 6, 99, model)
    check("S-6 결정론 — 같은 시드 같은 궤적", h_a == h_b)

    # S-7 에너지 피라미드 — 풀바다 8계절
    hist, st = simulate(members, plains["K"], plains["climate"], 8, 21, model)
    pred = [o for o in st if o["s"]["pred"]]
    prey = [o for o in st if not o["s"]["pred"]]
    pred_avg = sum(h["pop"][o["s"]["id"]] for h in hist for o in pred) / max(1, len(hist) * len(pred))
    prey_avg = sum(h["pop"][o["s"]["id"]] for h in hist for o in prey) / max(1, len(hist) * len(prey))
    check("S-7 에너지 피라미드 — 포식 평균 < 피식 평균", pred_avg < prey_avg,
          "pred %.2f < prey %.2f" % (pred_avg, prey_avg) if pred_avg < prey_avg
          else "pred %.2f ≥ prey %.2f" % (pred_avg, prey_avg))

    # P-1 Godot 패리티 픽스처
    if fixture_check:
        fresh = build_fixture(eco, table, model)
        if not os.path.exists(FIXTURE):
            check("P-1 패리티 픽스처 최신", False,
                  "없음 — sim/ecology.py --write-fixture 로 뽑는다")
        else:
            with open(FIXTURE, encoding="utf-8") as f:
                on_disk = json.load(f)
            same = on_disk == fresh
            check("P-1 패리티 픽스처 최신", same,
                  "같음" if same else "다름 — 모델을 고쳤으면 --write-fixture 로 다시 뽑는다")

    return eco, results


def report(eco, results, seasons):
    print("생태 시뮬 — audit_sim 포팅 (07 §8) · 26바이옴 · %d계절" % seasons)
    for r in results:
        print("  [%s] %s%s" % (" OK " if r["ok"] else "FAIL", r["name"],
                              (" — " + r["detail"]) if r["detail"] else ""))
    fails = [r for r in results if not r["ok"]]
    print("  → 검사 %d · 실패 %d" % (len(results), len(fails)))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--json", action="store_true", help="결과를 JSON 하나로 낸다")
    ap.add_argument("--data-dir", default=os.path.join(ROOT, "data"))
    ap.add_argument("--seasons", type=int, default=12)
    ap.add_argument("--write-fixture", action="store_true",
                    help="Godot 패리티 픽스처를 다시 뽑는다")
    args = ap.parse_args()

    if args.write_fixture:
        model = load_model(args.data_dir)
        eco = ecosystem(args.data_dir)
        data = build_fixture(eco, species_table(eco), model)
        os.makedirs(os.path.dirname(FIXTURE), exist_ok=True)
        with open(FIXTURE, "w", encoding="utf-8") as f:
            json.dump(data, f, ensure_ascii=False, indent=1)
            f.write("\n")
        print("씀 — godot/tests/fixtures/ecology_parity.json (종 %d · %d계절)"
              % (len(data["species"]), data["scenario"]["seasons"]))
        return 0

    eco, results = run_checks(args.data_dir, args.seasons)
    fails = [r for r in results if not r["ok"]]
    if args.json:
        print(json.dumps({"seasons": args.seasons, "checks": results,
                          "fails": [r["name"] for r in fails]},
                         ensure_ascii=False, indent=1))
    else:
        report(eco, results, args.seasons)
    return 1 if fails else 0


if __name__ == "__main__":
    from gate_contract import run  # noqa: E402
    sys.exit(run("ecosim", main))
