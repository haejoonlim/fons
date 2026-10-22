#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""sync_pages.py — 테스트 센터 페이지의 내장값을 data/ 정본에서 다시 계산해 채운다.

왜 있나:
  `sim/center/pages/생태도감.html`·`바이옴_여정.html` 은 데이터를 실행 시 읽지 않고
  JSON 을 HTML 안에 박아 둔 정적 생성물이다. 원본 생성기는 다른 저장소에 있다
  (`design-docs/_tools/gen_ecology_codex.py` · `gen_biome_journey.py`). 폰즈에는
  생성기도, 그 생성기가 읽던 3D 자산도 없다. 그래서 `data/` 를 고쳐도 페이지는
  옛 값(심지어 옛 이름)을 계속 들고 있었다.

  이 스크립트는 그 생성기가 하던 **계산**을 폰즈 `data/` 위에서 다시 돌린다.
  페이지는 출력물이지 정본이 아니다 — 값을 손으로 맞추지 말고 이 스크립트를 돌린다.

다시 계산하는 것 (원본 규칙을 그대로 옮김):
  · 생태도감 종 — `tier`·`r`·`d`·`bio`·`bids`·`floors`·`level`·`temp`·`stats`·`threat`·`el`·
    `note`·`pred`·`prey`·`rel`·`eco`·`bc`·`resources`, 그리고 정렬(전투 > 야생 > 예정, 같은 급은 이름순)
  · 생태도감 바이옴 — `gid`·`gname`·`tempS`·`cl`·`name`·`slots`·`floors`·`mult`·`habitat`·
    `species`·`ecologyStatus`·`complete`·`missing`·`curN`·`planN`·`resName`·`resDesc`·`K`·`r`·`energy`,
    그리고 `edges`·`n*`·`nTotal` 집계
  · 생태도감 에너지 그래프 — 근원자원 26 + 지역 채널 104 = 130 노드의 `eaters`·`consumerRoles`·
    `map` 과, 그 노드를 먹는 종의 `resources` (`data/ecology_energy_channels.json` 의 근원자원·
    채널·`legacyCategories` 가 입력. 판정식은 아래 `build_energy`)
  · 생태도감 스킬 융합 — `FUSION` 의 `pairs`·`meta` 를 `data/fusion_pairs.json` 에서 다시 만든다.
    `구조` 는 카탈로그 태그로 판정한다 (같은 태그 = 동일태그 · R5 = 이어받는 태그와 임계).
    부모 카드가 카탈로그에 없으면 지어내지 않고 `미등재` 로 둔다. `규칙`·`이름규칙` 문면만
    설계 문장이라 `FUSION_RULES` 에 남긴다.
  · 바이옴 여정 — `step`·`region`·`slot`·`id`·`name`·`kit`·`layer`·`floors`·`category`·
    `gatekeeper`·`regions` (격자식 `slot = (rx*wx + rz*wz) % 26`, `wx`·`wz` 는 페이지의 `grid`)
  · 두 페이지 모든 이름 — `id` 로 짝을 찾아 정본 이름으로 (에너지 노드 이름 포함)

계산하지 않는 것 (저자 값 — 페이지에 남는다):
  · 바이옴 `note` — 원본 `NOTES` 표. 데이터에 없음
  · 바이옴 `settlements` — 종족 거주 집계. 원본 저장소의 종족 카탈로그 규칙이 필요하다
  · 바이옴 여정의 3D 계측(`profile`·`arc`·`placed`·`footprint`·`distance`·`masks`·`camera`·
    `ground`·`party`·`delta`) — 블록아웃 GLB 실측값. 자산 없이는 재현 불가
  · 여정의 `hero`·`mission`·`pilot`

사용법:
  ./.venv/bin/python sim/center/sync_pages.py            # 검사만 (다르면 exit 1)
  ./.venv/bin/python sim/center/sync_pages.py --write    # 페이지 갱신
  ./.venv/bin/python sim/center/sync_pages.py --quiet    # 한 줄 요약

서버는 시작할 때 `--write` 를 한 번 돌린다 (sim/center/server.py). 그래서 테스트 센터를
띄우면 항상 data/ 기준으로 보인다. 커밋 전에는 gate_all 의 `pages` 단계가 --check 로 막는다.
"""
import argparse
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DATA = ROOT / "data"
PAGES = ROOT / "sim" / "center" / "pages"
ECOLOGY = PAGES / "생태도감.html"
JOURNEY = PAGES / "바이옴_여정.html"

BLOB_RE = re.compile(r"const (?P<var>[A-Z_]+) = (?=\{)")

# 원본 생성기는 서고를 `biome_archive` 로 부르며 데이터 id(`biome_library`)와 다르다.
# 생태도감만 그 이름을 쓰고, 바이옴 여정은 데이터 id 그대로다.
ARCHIVE_ID = "biome_archive"
ARCHIVE_SOURCE_ID = "biome_library"


def load(name):
    path = DATA / name
    if not path.exists():
        raise SystemExit(f"데이터가 없다: {path}")
    return json.loads(path.read_text(encoding="utf-8"))


def name_maps():
    """id → 이름. 몬스터·앰비언트·바이옴을 한 사전으로 합친다 (id 는 서로 겹치지 않는다)."""
    names, biomes = {}, {}
    for fname in ("monsters.json", "ambient.json"):
        obj = load(fname)
        rows = obj if isinstance(obj, list) else next(
            (v for v in obj.values() if isinstance(v, list) and v and isinstance(v[0], dict)
             and "id" in v[0]), [])
        for row in rows:
            if row.get("id") and row.get("name"):
                names[row["id"]] = row["name"]
    b = load("biomes.json")
    groups = b.get("groups") or []
    for group in groups:
        for biome in group.get("biomes", []):
            if not biome.get("id"):
                continue
            biomes[biome["id"]] = biome.get("name", "")
            gk = biome.get("gatekeeper") or {}
            if isinstance(gk, dict) and gk.get("name"):
                names[biome["id"] + ":gk"] = gk["name"]
    return names, biomes


def split_blob(text, var):
    """`const VAR = {...};` 를 (앞, 객체, 뒤) 로 가른다. 문자열 안의 중괄호는 세지 않는다."""
    m = re.search(r"const %s = (?=(\{))" % var, text)
    if not m:
        return None
    start = m.end()
    depth, i, in_str, esc = 0, start, False, False
    while i < len(text):
        ch = text[i]
        if in_str:
            if esc:
                esc = False
            elif ch == "\\":
                esc = True
            elif ch == '"':
                in_str = False
        elif ch == '"':
            in_str = True
        elif ch == "{":
            depth += 1
        elif ch == "}":
            depth -= 1
            if depth == 0:
                end = i + 1
                return text[:start], json.loads(text[start:end]), text[end:]
        i += 1
    raise SystemExit(f"const {var} 의 JSON 이 닫히지 않는다")


# ── 계산 규칙 (원본 생성기 이식) ────────────────────────────────────────────────
# 아래 상수·함수는 원본 생성기의 판정식이다. 값을 바꾸면 페이지 내용이 바뀐다.
PREY_ROLES = {"prey", "swarm", "producer"}
PRED_ROLES = {"predator", "hunter", "ambusher", "apex"}
DECOMP_ROLES = {"decomposer", "scavenger", "corruptor"}

# 에너지 그래프 판정식 (원본 생성기 그대로). 근원자원은 종류별로 '무엇을 먹는가'가 다르고,
# 지역 채널은 카탈로그가 적어 둔 소비 역할을 현지 서식종과 교집합한다.
ROOT_KINDS = ("plant", "animal", "abiotic", "ether")
ROOT_COMPAT = {
    "plant": lambda s: s["d"] in ("herbivore", "omnivore") or s["r"] in PREY_ROLES,
    "animal": lambda s: s["d"] in ("carnivore", "omnivore", "blood") or s["r"] in DECOMP_ROLES,
    "abiotic": lambda s: s["d"] == "mineral" or s["r"] in ("producer", "decomposer"),
    "ether": lambda s: s["d"] in ("mana", "soul") or s["r"] in ("elemental", "undead"),
}
ROOT_FALLBACK_ROLES = {
    "plant": ("prey", "swarm", "producer", "decomposer", "scavenger"),
    "animal": ("scavenger", "decomposer", "prey", "swarm"),
    "abiotic": ("producer", "decomposer", "prey", "swarm", "scavenger"),
    "ether": ("elemental", "undead", "producer", "prey", "swarm"),
}
ENERGY_FALLBACK_ROLES = {
    "plant": ("prey", "swarm", "producer", "decomposer", "scavenger", "elemental"),
    "animal": ("scavenger", "decomposer", "prey", "swarm", "predator", "hunter"),
    "abiotic": ("producer", "decomposer", "scavenger", "prey", "swarm", "elemental"),
    "ether": ("elemental", "undead", "producer", "prey", "apex"),
}

ROLE_KO = {
    "prey": "먹이", "swarm": "군체", "hunter": "사냥꾼", "predator": "포식자",
    "ambusher": "매복자", "apex": "최상위", "scavenger": "청소부",
    "decomposer": "분해자", "corruptor": "오염자", "guardian": "수호자",
    "undead": "언데드", "mimic": "의태자", "elemental": "정령", "warrior": "전사",
    "producer": "생산자",
}
DIET_KO = {
    "herbivore": "초식", "carnivore": "육식", "omnivore": "잡식", "none": "비섭취",
    "mana": "마력", "blood": "흡혈", "mineral": "광물", "soul": "영혼", "brain": "뇌",
}

# `bc`(생물 대분류) 예외 — 원본은 **이름** 목록이었다. 개명 4건(잿빛화관·맥압각·틈새뱀·
# 수정거미)이 목록과 어긋나며 동물이 식물로 뒤집혔다. 이름은 바뀌고 id 는 남으므로
# 판정을 id 로 고정한다. 값은 원본이 동물로 판정하던 12종 그대로다.
DEMON_IDS = {
    "mon_ashbloom_01", "mon_balrog_01", "mon_beholder_01", "mon_crystalsentinel_01",
    "mon_doppelganger_01", "mon_glaciermaw_01", "mon_grieyer_01", "mon_hell_hound_01",
    "mon_imp_01", "mon_lesser_demon_01", "mon_lycanthrope_01", "mon_mindflayer_01",
}
ETHER_IDS = {"mon_jellyfish_01"}  # '마녀 해파리' — 이름 대신 id
PLANT_KEYWORDS = ("덩굴", "버섯", "이끼", "균", "플랑크톤", "산호", "모종", "식물")

DEFAULT_CLIMATE = {"ambient": 15, "base": 18, "band": [0, 35]}


def bio_class(cat, role, ident, name):
    """4=동물형 선언이 추측을 이긴다. 6=식물계는 악마 계열만 동물로 되돌린다."""
    if role in ("undead", "elemental") or ident in ETHER_IDS:
        return "ether"
    if cat == 4:
        return "animal"
    if cat == 6 and ident in DEMON_IDS:
        return "animal"
    if cat == 6 or role == "producer" or any(k in name for k in PLANT_KEYWORDS):
        return "plant"
    return "animal"


def codex_stats(stats):
    """0/미기입 특성은 미보유로 표현하고 ambient 의 spd 를 aspd 명칭으로 정규화."""
    if not isinstance(stats, dict):
        return None
    out = {}
    for key, value in stats.items():
        canonical = "aspd" if key == "spd" else key
        if isinstance(value, (int, float)) and value > 0:
            out[canonical] = value
    return out or None


def level_band(habs, hab2bio, levels, fallback=None):
    """서식지를 5층 블록의 생태 레벨 구간으로 변환 (블록 N → N*5-4 ~ N*5)."""
    bands = [levels[hab2bio[h]] for h in habs if h in hab2bio and hab2bio[h] in levels]
    if bands:
        return [max(1, min(x[0] for x in bands)), min(130, max(x[1] for x in bands))]
    if isinstance(fallback, int):
        return [max(1, min(130, fallback)), max(1, min(130, fallback))]
    if isinstance(fallback, list) and len(fallback) >= 2:
        return [max(1, min(130, int(fallback[0]))), max(1, min(130, int(fallback[1])))]
    return [1, 130]


def codex_context(archive=True):
    """생태도감 계산 입력 — 페이지가 부르는 id 규칙(archive)과 이름·레벨 구간."""
    amb = load("ambient.json")["ambient"]
    mon = load("monsters.json")["monsters"]
    rows, hab2bio, names, levels = [], {}, {}, {}
    for group in load("biomes.json")["groups"]:
        for biome in group.get("biomes", []):
            bid = ARCHIVE_ID if (archive and biome["id"] == ARCHIVE_SOURCE_ID) else biome["id"]
            rows.append((group, biome, bid))
            names[bid] = biome["name"]
            levels[bid] = [biome["slots"][0] * 5 - 4, biome["slots"][0] * 5]
            for hab in biome.get("habitat", []):
                hab2bio[hab] = bid
    return amb, mon, rows, hab2bio, names, levels


def _resolve(refs, known):
    """id 참조만 해석한다. 이름 문자열(에너지원)은 에너지 그래프 몫이라 여기선 빠진다."""
    return [{"n": known[x], "id": x} if x in known else {"n": x, "id": None}
            for x in (refs or [])]


def _resolve_relt(refs, relt, known):
    out = _resolve([x for x in (refs or []) if x in known], known)
    for o in out:
        o["rel"] = relt.get(o["id"] or o["n"], "predation")
    return out


def species_spec(src, kind, hab2bio, bnames, levels, known):
    """종 1건의 기대값. 키 순서는 원본 생성기의 dict 순서 그대로다."""
    ec = src["ecology"]
    temp = ec.get("temperature") or {}
    bids = list(dict.fromkeys(hab2bio[h] for h in ec["habitat"] if h in hab2bio))
    if kind == "amb":
        note = ec.get("note") or (
            f"{ROLE_KO[ec['role']]}형 · 식성 {DIET_KO.get(ec.get('diet'), ec.get('diet', '?'))}.")
        spec = {
            "id": src["id"], "name": src["name"], "k": "amb", "tier": None,
            "r": ec["role"], "d": ec.get("diet", "none"),
            "bio": [bnames[b] for b in bids], "bids": bids,
            "floors": src["spawn"]["floors"],
            "level": level_band(ec["habitat"], hab2bio, levels, src["spawn"].get("floors")),
            "temp": [temp.get("min"), temp.get("max")] if temp else None,
            "stats": codex_stats(src.get("stats")), "el": None, "note": note,
            "pred": _resolve(ec.get("predators"), known),
            "prey": _resolve_relt(ec.get("prey"), ec.get("relationTypes") or {}, known),
            "rel": ec.get("relationTypes") or {},
            "eco": {"rep": ec.get("reproduction", 0.6), "food": ec.get("food_need", 0.4),
                    "agg": ec.get("aggression", 0.3), "soc": ec.get("sociality", 0.5)},
        }
    else:
        note = ec.get("note") or (
            f"{ROLE_KO[ec['role']]}형 전투 몬스터 (T{src.get('tier', '?')}) · "
            f"식성 {DIET_KO.get(ec.get('diet'), ec.get('diet', '?'))}.")
        spec = {
            "id": src["id"], "name": src["name"], "k": "mon", "tier": src.get("tier"),
            "r": ec["role"], "d": ec.get("diet", "none"),
            "bio": [bnames[b] for b in bids], "bids": bids,
            "floors": src["spawn"]["floors"],
            "level": level_band(ec["habitat"], hab2bio, levels, src["spawn"].get("floors")),
            "temp": [temp.get("min"), temp.get("max")] if temp else None,
            "stats": codex_stats(src.get("stats")),
            "threat": src.get("threatBase"), "el": src.get("element"), "note": note,
            "pred": _resolve(ec.get("predators"), known),
            "prey": _resolve_relt(ec.get("prey"), ec.get("relationTypes") or {}, known),
            "rel": ec.get("relationTypes") or {},
            "eco": {"rep": ec.get("reproduction", 0.5), "food": ec.get("food_need", 0.4),
                    "agg": ec.get("aggression", 0.4), "soc": ec.get("sociality", 0.5)},
        }
    spec["bc"] = bio_class(src.get("category"), ec["role"], src["id"], src["name"])
    return spec


_MISSING = object()


def _merge(target, spec, where, changes):
    """기대값을 대상 dict 에 덮어쓴다. 기존 키 순서는 건드리지 않는다."""
    for key, want in spec.items():
        have = target.get(key, _MISSING)
        if have is _MISSING or have != want:
            changes.append((f"{where}.{key}", None if have is _MISSING else have, want))
            target[key] = want


def energy_catalog():
    """에너지 그래프 입력 — 근원자원 26 · 바이옴별 지역 채널 4 · 옛 prey 문자열 분류표.

    카탈로그가 어긋나면 계산을 멈춘다. 근원자원 표가 데이터에 있으므로 페이지는
    이 파일만 보고 다시 만들어지고, 빠진 바이옴이 있으면 조용히 넘어가지 않는다.
    """
    cat = load("ecology_energy_channels.json")
    roots_rows = cat.get("roots") or []
    biome_rows = cat.get("biomes") or []
    legacy = cat.get("legacyCategories") or {}
    problems = []
    if len(roots_rows) != 26:
        problems.append(f"근원자원 {len(roots_rows)}개 ≠ 26")
    if len(biome_rows) != 26:
        problems.append(f"바이옴 {len(biome_rows)}개 ≠ 26")
    roots = {}
    for root in roots_rows:
        bid = root.get("biomeId")
        if root.get("kind") not in ROOT_KINDS:
            problems.append(f"{bid}: 근원자원 종류 {root.get('kind')!r}")
        if not root.get("name") or not root.get("description"):
            problems.append(f"{bid}: 이름·설명 없음")
        if not isinstance(root.get("K"), int) or root["K"] <= 0:
            problems.append(f"{bid}: K {root.get('K')!r}")
        if not isinstance(root.get("r"), (int, float)) or root["r"] <= 0:
            problems.append(f"{bid}: r {root.get('r')!r}")
        if bid in roots:
            problems.append(f"{bid}: 근원자원 중복")
        roots[bid] = root
    channels = {}
    for row in biome_rows:
        bid, chans = row.get("id"), row.get("channels") or []
        if len(chans) != 4:
            problems.append(f"{bid}: 지역 채널 {len(chans)}개 ≠ 4")
        for ch in chans:
            if ch.get("category") not in ROOT_KINDS:
                problems.append(f"{bid}/{ch.get('id')}: 채널 분류 {ch.get('category')!r}")
            if not ch.get("name") or not ch.get("description"):
                problems.append(f"{bid}/{ch.get('id')}: 이름·설명 없음")
            if not ch.get("consumerRoles"):
                problems.append(f"{bid}/{ch.get('id')}: consumerRoles 없음")
        channels[bid] = chans
        if bid not in roots:
            problems.append(f"{bid}: 근원자원 없음")
    for key, value in legacy.items():
        if value not in ROOT_KINDS:
            problems.append(f"legacyCategories[{key!r}] = {value!r}")
    if problems:
        raise SystemExit("에너지 카탈로그가 어긋난다 — " + "; ".join(problems[:6]))
    by_name = {root["name"]: root["kind"] for root in roots_rows}
    by_name.update({ch["name"]: ch["category"] for chans in channels.values() for ch in chans})
    return roots, channels, legacy, by_name


def build_energy(species, rows, bnames, legacy_by_id):
    """근원자원 26 + 지역 채널 104 그래프를 다시 만든다.

    `species` 는 이미 정렬된 종 dict (`r`·`d`·`bids` 사용). `legacy_by_id` 는 종별
    옛 prey 문자열 목록 — 페이지 종 dict 에는 id 있는 참조만 남으므로 원본 데이터에서 받는다.
    반환값은 (에너지 노드 목록, 바이옴별 노드, 종 id → 먹는 자원 링크, 근원자원 표).
    순서는 원본 생성기와 같다 — 근원자원 26개를 먼저, 그다음 바이옴별 채널 4개씩,
    마지막에 옛 prey 문자열을 현지 노드로 정규화한다.
    """
    roots, channels, legacy_cat, node_cat = energy_catalog()
    # 노드 순서 = 카탈로그 순서(슬롯 1..26) — 원본 생성기의 RESOURCES·RESOURCE_CHANNELS 순서다.
    # 페이지의 바이옴·종 목록 순서와는 별개이므로 여기서만 따로 고정한다.
    order = list(roots)
    known = {bid for _, _, bid in rows}
    missing = [bid for bid in order if bid not in known]
    if missing:
        raise SystemExit("페이지에 없는 바이옴을 카탈로그가 가리킨다: " + ", ".join(missing))
    if set(order) != known:
        raise SystemExit("카탈로그 근원자원과 페이지 바이옴이 다르다: "
                         + ", ".join(sorted(known - set(order)) or sorted(set(order) - known)))
    local = {bid: [s for s in species if bid in s.get("bids", [])] for bid in order}
    energy, by_biome = [], {bid: [] for bid in order}
    links = {s["id"]: [] for s in species}

    def add(bid, source_id, name, category, description, mapping, roles):
        residents = local[bid]
        compat = set(roles) & {s["r"] for s in residents}
        if not compat:
            compat = next(({role} for role in ENERGY_FALLBACK_ROLES[category]
                           if any(s["r"] == role for s in residents)), set())
        if not compat:
            raise SystemExit(f"에너지 자원 {bid}/{source_id}: 현지 소비 역할이 없다")
        eaters = [s for s in residents if s["r"] in compat]
        entry = {"id": source_id, "name": name, "cat": category, "d": description,
                 "map": mapping, "biomeId": bid, "bio": [bnames[bid]],
                 "consumerRoles": sorted(compat),
                 "eaters": [{"id": s["id"], "n": s["name"]} for s in eaters]}
        energy.append(entry)
        by_biome[bid].append(entry)
        for eater in eaters:
            links[eater["id"]].append({"id": source_id, "name": name})

    for bid in order:
        root = roots[bid]
        category = root["kind"]
        eaters = [s for s in local[bid] if ROOT_COMPAT[category](s)]
        if not eaters:
            priority = ROOT_FALLBACK_ROLES[category]
            candidates = [s for s in local[bid] if s["r"] in priority]
            if candidates:
                role = next(x for x in priority if any(s["r"] == x for s in candidates))
                eaters = [s for s in candidates if s["r"] == role]
            elif local[bid]:
                eaters = [local[bid][0]]
            else:
                raise SystemExit(f"근원자원 {bid}: 현지 생물이 없다")
        add(bid, f"energy:root:{bid}", root["name"], category, root["description"],
            f"{bnames[bid]} 근원자원 · K≈{root['K']} · r≈{root['r']}",
            {s["r"] for s in eaters})
    for bid in order:
        for ch in channels[bid]:
            add(bid, f"energy:channel:{bid}:{ch['id']}", ch["name"], ch["category"],
                ch["description"], f"{bnames[bid]} 지역 먹이 채널",
                set(ch["consumerRoles"]))

    # 옛 prey 문자열(`corpse`·`grass` 같은 자원 이름)을 현지 노드 하나로 정규화한다.
    # 분류를 알면 같은 분류의 첫 노드, 모르면 그 바이옴의 첫 노드(근원자원)로 붙는다.
    for sp in species:
        local_energy = by_biome.get(
            next((bid for bid in sp.get("bids", []) if bid in by_biome), ""), [])
        if not local_energy:
            continue
        for item in legacy_by_id.get(sp["id"], []):
            name = item
            category = legacy_cat.get(name) or node_cat.get(name)
            candidates = [e for e in local_energy if category and e["cat"] == category]
            target = (candidates or local_energy)[0]
            if sp["id"] not in {e["id"] for e in target["eaters"]}:
                target["eaters"].append({"id": sp["id"], "n": sp["name"]})
                target["consumerRoles"] = sorted(set(target["consumerRoles"]) | {sp["r"]})
            link = {"id": target["id"], "name": target["name"]}
            if link not in links[sp["id"]]:
                links[sp["id"]].append(link)

    if len(energy) != 130 or len({e["id"] for e in energy}) != 130:
        raise SystemExit(f"에너지 그래프는 고유 130노드여야 한다 (실제 {len(energy)})")
    index = {e["id"]: e for e in energy}
    for sid, items in links.items():
        for link in items:
            node = index.get(link["id"])
            if node is None or sid not in {e["id"] for e in node["eaters"]}:
                raise SystemExit(f"에너지 링크가 비현지·비호환: {sid} -> {link['id']}")
    for node in energy:
        if not node["eaters"]:
            raise SystemExit(f"소비종 없는 에너지 노드: {node['id']}")
    return energy, by_biome, links, roots


def _importance(s):
    if s.get("k") == "mon":
        return 200 + (s.get("tier") or 0) * 10
    return 100 if s.get("k") == "amb" else 0


def fix_ecology_names(obj, names, biomes):
    """id 가 정본에 있는 dict 는 `name`·`n` 을 정본 이름으로 덮어쓴다 (전 깊이 순회).

    계산으로 만들지 않는 자리(에너지 채널 이름 등)를 이름만 따라오게 하는 몫이다.
    `energy:*` 처럼 사전에 없는 id 는 손대지 않는다.
    """
    changes = []

    def walk(node, path):
        if isinstance(node, dict):
            ident = node.get("id")
            want = (names.get(ident) or biomes.get(ident)) if isinstance(ident, str) else None
            if want:
                for key in ("name", "n"):
                    cur = node.get(key)
                    if isinstance(cur, str) and cur != want:
                        changes.append((f"{path}.{key}", cur, want))
                        node[key] = want
            for key, val in node.items():
                walk(val, f"{path}.{key}")
        elif isinstance(node, list):
            for i, val in enumerate(node):
                walk(val, f"{path}[{i}]")

    walk(obj, "DATA")
    return changes


def rebuild_ecology(obj):
    """종사전·바이옴 카드·집계를 data/ 에서 다시 계산해 덮어쓴다."""
    amb, mon, rows, hab2bio, bnames, levels = codex_context(archive=True)
    known = {s["id"]: s["name"] for s in amb}
    known.update({m["id"]: m["name"] for m in mon})
    specs = {}
    for src in amb:
        specs[src["id"]] = species_spec(src, "amb", hab2bio, bnames, levels, known)
    for src in mon:
        specs[src["id"]] = species_spec(src, "mon", hab2bio, bnames, levels, known)

    # 역방향(pred) 관계 유형 — 순방향 prey 태그에서 역산한다. 병합 전에 끝낸다.
    for spec in specs.values():
        for prey in spec["prey"]:
            target = specs.get(prey["id"])
            if not target:
                continue
            for pred in target["pred"]:
                if pred["id"] == spec["id"]:
                    pred["rel"] = prey["rel"] or "predation"

    changes = []
    old = {s.get("id"): s for s in obj.get("species", [])}
    species = []
    for sid, spec in specs.items():
        target = old.pop(sid, None)
        if target is None:
            target = {}
            changes.append((f"species[{sid}]", None, "신규"))
        _merge(target, spec, f"species[{sid}]", changes)
        species.append(target)
    for sid in old:
        changes.append((f"species[{sid}]", "데이터에 없음", None))
    species.sort(key=lambda s: (-_importance(s), s.get("name") or ""))

    # 에너지 그래프는 정렬된 종 목록 위에서 만든다 — 원본 생성기도 정렬 뒤에 돌렸다.
    # 옛 prey 문자열(자원 이름)은 페이지 종 dict 에서 빠져 있으니 원본 데이터에서 모은다.
    legacy_by_id = {src["id"]: [p for p in src["ecology"].get("prey") or [] if p not in known]
                    for src in amb + mon}
    energy, nodes_by_biome, links, roots = build_energy(species, rows, bnames, legacy_by_id)
    for entry in species:
        _merge(entry, {"resources": links[entry["id"]]}, f"species[{entry['id']}]", changes)

    page_biomes = {b.get("id"): b for b in obj.get("biomes", [])}
    biomes = []
    for group, biome, bid in rows:
        habitats = set(biome.get("habitat", []))
        found = []
        for src in amb + mon:
            if habitats & set(src["ecology"]["habitat"]):
                found.append({"n": src["name"], "r": src["ecology"]["role"],
                              "p": False, "id": src["id"]})
        roles = {f["r"] for f in found}
        missing = []
        if not roles & PREY_ROLES:
            missing.append("먹이")
        if not roles & PRED_ROLES:
            missing.append("포식")
        if not roles & DECOMP_ROLES:
            missing.append("분해")
        climate = biome.get("climate") or DEFAULT_CLIMATE
        band = climate.get("band") or [0, 35]
        spec = {
            "id": bid, "gid": group["id"],
            "gname": f"{group['name']} ({group['floors'][0]}~{group['floors'][1]}층)",
            "tempS": f"🌡 {climate.get('ambient', 15)}°C (band {band[0]}~{band[1]}°C)",
            "cl": [climate.get("ambient", 15), band[0], band[1], climate.get("seasonSwing", 8)],
            "name": biome["name"], "slots": biome["slots"],
            "floors": [(biome["slots"][0] - 1) * 5 + 1, biome["slots"][0] * 5],
            "mult": (biome.get("difficulty") or {}).get("mult", 1.0),
            "habitat": biome.get("habitat", []), "species": found,
        }
        target = page_biomes.pop(bid, None)
        if target is None:
            target = {}
            changes.append((f"biomes[{bid}]", None, "신규"))
        _merge(target, spec, f"biomes[{bid}]", changes)
        _merge(target, {
            "ecologyStatus": biome.get("ecologyStatus", "existing-species-by-habitat"),
            "complete": not missing, "missing": missing,
            "curN": len(found), "planN": 0,
        }, f"biomes[{bid}]", changes)
        root = roots[bid]
        _merge(target, {
            "resName": root["name"], "resDesc": root["description"],
            "K": root["K"], "r": root["r"],
            "energy": [{"id": e["id"], "name": e["name"], "cat": e["cat"],
                        "consumerCount": len(e["eaters"])} for e in nodes_by_biome[bid]],
        }, f"biomes[{bid}]", changes)
        biomes.append(target)
    for bid in page_biomes:
        changes.append((f"biomes[{bid}]", "데이터에 없음", None))

    edges = 0
    for i, (_, x, _bid) in enumerate(rows):
        for _, y, _bid2 in rows[i + 1:]:
            hx, hy = set(x.get("habitat", [])), set(y.get("habitat", []))
            if any(set(s["ecology"]["habitat"]) & hx and set(s["ecology"]["habitat"]) & hy
                   for s in amb + mon):
                edges += 1
    _merge(obj, {"biomes": biomes, "edges": edges, "nAmb": len(amb), "nMon": len(mon),
                 "nPlan": 0, "nSp": len(species), "energy": energy,
                 "nTotal": len(species) + len(energy)}, "DATA", changes)
    obj["species"] = species
    return changes


def fix_journey_names(obj, names, biomes):
    """바이옴 여정의 바이옴 이름·문지기 이름을 정본으로 맞춘다."""
    changes = []
    for step in obj.get("steps", []):
        bid = step.get("id")
        want = biomes.get(bid)
        if want and step.get("name") != want:
            changes.append((f"steps[{bid}].name", step.get("name"), want))
            step["name"] = want
        want_gk = names.get(str(bid) + ":gk")
        if want_gk and step.get("gatekeeper") != want_gk:
            changes.append((f"steps[{bid}].gatekeeper", step.get("gatekeeper"), want_gk))
            step["gatekeeper"] = want_gk
    return changes


def rebuild_journey(obj):
    """여정의 순서·좌표·바이옴 정보를 data/ 에서 다시 계산한다.

    걷는 경로는 동쪽으로 한 칸씩(region z=0)이고, 블록 번호는 페이지의 grid 상수로
    접는다 — `slot = (rx*wx + rz*wz) % 26`. 3D 계측값은 손대지 않는다.
    """
    groups = load("biomes.json")["groups"]
    info = {}
    for group in groups:
        for biome in group.get("biomes", []):
            info[biome["id"]] = {
                "slot": biome["slots"][0], "name": biome["name"],
                "kit": biome.get("topologyKit"), "layer": group["name"],
                "floors": biome["floors"], "category": biome.get("category"),
                "gatekeeper": (biome.get("gatekeeper") or {}).get("name"),
                "regions": biome.get("regions", []),
            }
    order = sorted(info, key=lambda i: info[i]["slot"])
    if sorted(info[i]["slot"] for i in order) != list(range(1, len(order) + 1)):
        raise SystemExit("바이옴 slots[0] 이 1..26 연속이 아니다 — 슬롯 지도부터 고친다")
    steps = obj.get("steps", [])
    grid = obj.get("grid") or {}
    wx, wz = grid.get("wx"), grid.get("wz")
    if not isinstance(wx, int) or not isinstance(wz, int):
        raise SystemExit("여정 페이지에 grid.wx·wz 가 없다 — 좌표 규칙을 알 수 없다")
    if len(steps) != len(order):
        raise SystemExit(f"여정 스텝 {len(steps)}개 ≠ 바이옴 {len(order)}개 — "
                         "자산이 없어 새 스텝을 만들 수 없다. 데이터와 페이지를 손으로 맞춘다")

    changes = []
    for i, step in enumerate(steps):
        rx, rz = i, 0
        slot = (rx * wx + rz * wz) % len(order)
        bid = order[slot]
        meta = info[bid]
        _merge(step, {
            "step": i + 1, "region": [rx, rz], "slot": slot, "id": bid,
            "name": meta["name"], "kit": meta["kit"], "layer": meta["layer"],
            "floors": meta["floors"], "category": meta["category"],
            "gatekeeper": meta["gatekeeper"], "regions": meta["regions"][:5],
        }, f"steps[{i}]", changes)
    return changes


# ── 실행 ──────────────────────────────────────────────────────────────────────

# 스킬 융합 트리 — `data/fusion_pairs.json` 이 정본이다. 페이지의 FUSION 은 출력물이라
# 부모·자식 이름을 손으로 맞추지 않는다. 규칙 문면(규칙·이름규칙)만 설계 문장이라 여기 남긴다.
FUSION_RULES = {
    "규칙": "자식 레어도 = max(부모)+1 (L 상한) · 연계 3단계(미숙→숙달→완성) 완성 시 자동 융합 · 재화 없음",
    "이름규칙": "R1~R4 부모 수식×어근 재조합 → R5 자식은 카탈로그 L 실명 (부모 유산층 → 자식 유산층 승계) · D-269 카탈로그 충돌 4건 재조합(맹독돌진→맹독돌파 등)",
}


def _fusion_tag(name, cards):
    """카드의 첫 태그와 그 임계 — 툴팁의 `근접타격(390)` 표기."""
    card = cards.get(name)
    tags = (card or {}).get("tags") or []
    if not tags:
        return None
    limit = next((x["v"] for x in card.get("tag_thresholds") or [] if x["tag"] == tags[0]), None)
    return f"{tags[0]}({limit})" if limit is not None else tags[0]


def _fusion_structure(parent1, parent2, child_rarity, cards):
    """쌍의 결 — 같은 태그면 동일태그, 아니면 크로스도메인. R5 는 이어받는 태그를 적는다.

    부모 카드가 카탈로그에 없으면 지어내지 않고 미등재로 둔다 (데이터 구멍을 페이지에 드러낸다).
    """
    a, b = cards.get(parent1), cards.get(parent2)
    if child_rarity == 6:
        ta, tb = _fusion_tag(parent1, cards), _fusion_tag(parent2, cards)
        if ta and tb:
            return f"S+S→L — 태그 이어받기 {ta}·{tb} · 유산층 이름 승계"
        return "S+S→L — 유산층 이름 승계"
    if a is None or b is None or not (a.get("tags") and b.get("tags")):
        return "미등재"
    return "동일태그" if set(a["tags"]) & set(b["tags"]) else "크로스도메인"


def fusion_blob():
    """`data/fusion_pairs.json` → 페이지가 읽는 한글 키 FUSION 객체."""
    data = load("fusion_pairs.json")
    meta = data.get("meta") or {}
    cards = {s["name"]: s for s in load("skills_catalog.json")["skills"]}
    pairs = []
    for p in data.get("pairs") or []:
        p1, p2, rarity = p["parent1"], p["parent2"], p["child_rarity"]
        pairs.append({
            "부모": [p1, p2],
            "부모_레어도": [p["parent_rarity1"], p["parent_rarity2"]],
            "자식_레어도": rarity,
            "자식_이름_시안": p["child_name"],
            "구조": _fusion_structure(p1, p2, rarity, cards),
        })
    return {
        "meta": {
            "버전": meta.get("version"),
            "seed": meta.get("seed"),
            "총쌍": len(pairs),
            "규칙": FUSION_RULES["규칙"],
            "구조": meta.get("note"),
            "이름규칙": FUSION_RULES["이름규칙"],
        },
        "pairs": pairs,
    }


def rebuild_fusion(obj):
    """FUSION 을 데이터에서 다시 만든다. 이미 같으면 아무것도 하지 않는다."""
    want = fusion_blob()
    if obj == want:
        return []
    changes = []
    old_meta = obj.get("meta") or {}
    for key, val in want["meta"].items():
        if old_meta.get(key) != val:
            changes.append((f"FUSION.meta.{key}", old_meta.get(key), val))
    old_pairs = obj.get("pairs") or []
    if len(old_pairs) != len(want["pairs"]):
        changes.append(("FUSION.pairs", f"{len(old_pairs)}쌍", f"{len(want['pairs'])}쌍"))
    else:
        for i, (a, b) in enumerate(zip(old_pairs, want["pairs"])):
            for key, val in b.items():
                if a.get(key) != val:
                    changes.append((f"FUSION.pairs[{i}] {b['자식_이름_시안']}.{key}",
                                    a.get(key), val))
    obj.clear()
    obj.update(want)
    return changes


def _page_jobs():
    names, biomes = name_maps()
    page_biomes = codex_context(archive=True)[4]  # 생태도감은 `biome_archive` 를 쓴다
    return [
        (ECOLOGY, "DATA", [
            rebuild_ecology,
            lambda o: fix_ecology_names(o, names, biomes),
        ]),
        (ECOLOGY, "FUSION", [rebuild_fusion]),
        (JOURNEY, "J", [
            rebuild_journey,
            lambda o: fix_journey_names(o, names, biomes),
        ]),
    ]


def _apply(page_text, var, mutators):
    parts = split_blob(page_text, var)
    if not parts:
        return [], page_text
    head, obj, tail = parts
    changes = []
    for mutate in mutators:
        changes += mutate(obj)
    if not changes:
        return [], page_text
    # 원래 blob 의 띄어쓰기 취향을 지킨다 — 페이지마다 다르다(생태도감은 `": "`, 여정은 빽빽).
    raw = page_text[len(head):len(page_text) - len(tail)]
    compact = '": ' not in raw[:400]
    blob = json.dumps(obj, ensure_ascii=False,
                      separators=(",", ":") if compact else None)
    return changes, head + blob + tail


def _summarize(changes, limit=8):
    """(경로, 옛값, 새값) 목록 → 필드별 건수 + 표본."""
    counts = {}
    for path, _old, _new in changes:
        field = path.rsplit(".", 1)[-1]
        counts[field] = counts.get(field, 0) + 1
    head = " · ".join(f"{k} {v}" for k, v in sorted(counts.items(), key=lambda x: -x[1]))
    return head, changes[:limit]


def process(write, quiet=False):
    total, files = 0, 0
    for path, var, mutators in _page_jobs():
        if not path.exists():
            print(f"  건너뜀 (없음): {path.relative_to(ROOT)}")
            continue
        before = path.read_text(encoding="utf-8")
        changes, after = _apply(before, var, mutators)
        if not changes:
            continue
        files += 1
        total += len(changes)
        if not quiet:
            head, samples = _summarize(changes)
            print(f"  {path.relative_to(ROOT)} — {len(changes)}건 ({head})")
            for where, old, new in samples:
                print(f"    · {where}: {_short(old)} → {_short(new)}")
            if len(changes) > len(samples):
                print(f"    … 외 {len(changes) - len(samples)}건")
        if write:
            path.write_text(after, encoding="utf-8")
    if not total:
        print("PAGES OK — 페이지 내장값이 data/ 와 같다")
        return 0
    if write:
        print(f"PAGES SYNCED — {files}개 파일 · {total}건")
        return 0
    print(f"PAGES DRIFT — {files}개 파일 · {total}건 (--write 로 맞춘다)")
    return 1


def _short(value, limit=48):
    text = json.dumps(value, ensure_ascii=False) if not isinstance(value, str) else value
    return text if len(text) <= limit else text[:limit - 1] + "…"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--write", action="store_true", help="페이지를 실제로 고친다")
    ap.add_argument("--quiet", action="store_true", help="요약만")
    args = ap.parse_args()
    return process(args.write, args.quiet)


if __name__ == "__main__":
    # 계약 G-1~G-4 (`tools/gate_contract.py`)
    sys.path.insert(0, str(ROOT / "tools"))
    from gate_contract import run  # noqa: E402
    sys.exit(run("pages", main))
