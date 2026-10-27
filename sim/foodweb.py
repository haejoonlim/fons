"""먹이그물 정적 감사 — 377종 관계의 구조를 데이터에서 계산한다.

왜 있나
-------
생태계 시스템(출현·사체·분해)을 붙이기 전에, 그 밑에 깔린 **관계 데이터**가
스스로 모순되지 않는지 잠그는 게이트다. 08 §3 원칙 6(쌍방 정합)과 07 §8(고아 0)은
문서에만 있고 검사는 없었다 — 종을 하나 추가하고 predators 목록을 반만 고치면
게이트는 전부 통과하는데 그물만 조용히 끊긴다.

무엇을 읽나
-----------
  data/monsters.json              전투 162종 (ecology.prey·predators)
  data/ambient.json               비전투 215종 (같은 필드)
  data/ecology_codex.json         도감 377종 (총계 대조)
  data/biomes.json                26바이옴 habitat 태그 (바이옴별 간선)
  data/ecology_energy_channels.json  근원자원 K·r · 채널 이름 · 옛 자원 분류

검사 (E-1~E-6)
--------------
  E-1  종 377 = 전투 162 + 비전투 215, id 중복 0, 도감 총계와 일치
  E-2  predators 가 실존 종만 가리킨다 — prey 의 모르는 이름은 자원 표기(08)라 실패가 아니다
  E-3  쌍방 정합 — A.prey 에 B 가 있으면 B.predators 에 A 가 있어야 한다 (08 §3-6)
  E-4  고아 0 — prey·predators 가 둘 다 빈 종 (elemental·mimic 은 제외, 08 §2)
  E-5  순환 0 — A 가 B 를 먹고 B 가 A 를 먹는 고리
  E-6  0간선 바이옴 0 — 그 바이옴 안에서 성립하는 종간 간선이 하나도 없는 경우
  E-7  근원자원·채널의 biomeId 가 biomes.json 의 id 와 일치 (26/26 · 서고 별칭 허용)

판정에 쓰지 않는 것 (보고만 한다)
--------------------------------
  · 사슬 깊이 — GDD 는 "깊이 7이면 좋다"고 적었지 하한을 정하지 않았다. 수치를 지어내지 않는다.
  · 미등재 자원 이름 — 08 은 "미등재 ID 는 자원으로 표기"라 했다. 실패가 아니라 목록만 낸다.
  · 조우 편성·출현표 — 런타임 규칙(`FonsEncounter`)을 그대로 돌리는 몫은 게임 쪽 도구가 맡는다.
    여기서 파이썬으로 다시 계산하면 규칙이 둘로 갈라진다.

실행
----
    ./.venv/bin/python sim/foodweb.py
    ./.venv/bin/python sim/foodweb.py --json
    ./.venv/bin/python sim/foodweb.py --data-dir /tmp/eco   (검사기 자체 시험용)
"""
import argparse
import collections
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, os.path.join(ROOT, "tools"))

EXEMPT_ROLES = ("elemental", "mimic")   # 08 §2 — 비생물·모방종은 그물 밖이 정상
# 서고는 원본 생성기가 `biome_archive` 로 부른다 — sync_pages.py 61-64 가 같은 별칭을 쓴다.
# 데이터(biomes.json)의 id 는 `biome_library` (06 §G2 — 데이터 코드 유지)이므로 여기서 맞춘다.
ALIASES = {"biome_archive": "biome_library"}
PREDATOR_ROLES = ("predator", "apex", "hunter", "ambusher")
PREY_ROLES = ("prey", "swarm")
DECOMPOSER_ROLES = ("decomposer", "scavenger")


def canonical(biome_id):
    return ALIASES.get(biome_id, biome_id)


def load(path):
    with open(path, encoding="utf-8") as fh:
        return json.load(fh)


def ecosystem(data_dir):
    """데이터를 읽어 종·자원·간선·바이옴 표를 만든다 (판정 없음)."""
    monsters = load(os.path.join(data_dir, "monsters.json"))["monsters"]
    ambient = load(os.path.join(data_dir, "ambient.json"))["ambient"]
    codex = load(os.path.join(data_dir, "ecology_codex.json"))["entries"]
    biomes = load(os.path.join(data_dir, "biomes.json"))["groups"]
    channels = load(os.path.join(data_dir, "ecology_energy_channels.json"))

    species = list(monsters) + list(ambient)
    by_id = {}
    duplicates = []
    for s in species:
        sid = s.get("id")
        if sid in by_id:
            duplicates.append(sid)
        by_id[sid] = s

    # 자원 이름 — 등재된 옛 분류 + 근원자원 이름 + 26바이옴 채널 이름.
    legacy = set(channels.get("legacyCategories", {}))
    roots = {r.get("name") for r in channels.get("roots", [])}
    channel_names = {c.get("name") for b in channels.get("biomes", []) for c in b.get("channels", [])}
    resources = legacy | roots | channel_names

    edges = set()
    dangling_species = set()
    unlisted_resources = collections.Counter()
    resource_refs = collections.Counter()
    for s in species:
        eco = s.get("ecology") or {}
        for prey in eco.get("prey") or []:
            if prey in by_id:
                edges.add((s["id"], prey))
            elif prey in resources:
                resource_refs[prey] += 1
            elif prey.startswith("mon_"):
                # 종 id 모양인데 실존하지 않는다 — 오타·삭제된 개체. 자원이 아니다.
                dangling_species.add(prey)
            else:
                unlisted_resources[prey] += 1
        for pred in eco.get("predators") or []:
            if pred not in by_id and pred not in resources:
                dangling_species.add(pred)

    biome_rows = []
    for group in biomes:
        for biome in group.get("biomes", []):
            tags = set(biome.get("habitat") or [])
            members = [s for s in species if set((s.get("ecology") or {}).get("habitat") or []) & tags]
            member_ids = {s["id"] for s in members}
            internal = [(a, b) for a, b in edges if a in member_ids and b in member_ids]
            roles = collections.Counter((s.get("ecology") or {}).get("role") for s in members)
            root = next((r for r in channels.get("roots", [])
                         if canonical(r.get("biomeId")) == biome.get("id")), None)
            biome_rows.append({
                "id": biome.get("id"), "slot": (biome.get("slots") or [None])[0],
                "species": len(members), "members": [s["id"] for s in members],
                "edges": len(internal),
                "roles": dict(roles),
                "climate": biome.get("climate") or {},   # 계절 모델이 쓴다 (sim/ecology.py)
                "root": root.get("name") if root else None,
                "K": root.get("K") if root else None, "r": root.get("r") if root else None,
            })

    biome_ids = [b.get("id") for g in biomes for b in g.get("biomes", [])]
    root_ids = [r.get("biomeId") for r in channels.get("roots", [])]
    channel_ids = [b.get("id") for b in channels.get("biomes", [])]

    return {
        "biome_ids": biome_ids, "root_ids": root_ids, "channel_ids": channel_ids,
        "species": species, "by_id": by_id, "duplicates": duplicates,
        "codex": len(codex), "monsters": len(monsters), "ambient": len(ambient),
        "edges": edges, "resources": resources,
        "resource_refs": resource_refs, "unlisted_resources": unlisted_resources,
        "dangling_species": dangling_species, "biomes": biome_rows,
        "roots": channels.get("roots", []),
    }


def structure(eco):
    """간선 그래프의 구조 지표 — 쌍방 위반·고아·순환·깊이."""
    by_id, edges = eco["by_id"], eco["edges"]
    adjacency = collections.defaultdict(list)
    for predator, prey in edges:
        adjacency[predator].append(prey)

    asymmetric = []
    for predator, prey in edges:
        eco_of_prey = by_id[prey].get("ecology") or {}
        eco_of_predator = by_id[predator].get("ecology") or {}
        if predator not in (eco_of_prey.get("predators") or []):
            asymmetric.append((predator, prey, "predators"))
        if prey not in (eco_of_predator.get("prey") or []):
            asymmetric.append((predator, prey, "prey"))

    orphans = []
    for s in eco["species"]:
        e = s.get("ecology") or {}
        if e.get("role") in EXEMPT_ROLES:
            continue
        if not (e.get("prey") or []) and not (e.get("predators") or []):
            orphans.append(s["id"])

    colour = {}
    cycles = []

    def visit(node, stack):
        colour[node] = 1
        stack.append(node)
        for nxt in adjacency.get(node, ()):
            if colour.get(nxt, 0) == 1:
                cycles.append(stack[stack.index(nxt):] + [nxt])
            elif colour.get(nxt, 0) == 0:
                visit(nxt, stack)
        stack.pop()
        colour[node] = 2

    for sid in by_id:
        if colour.get(sid, 0) == 0:
            visit(sid, [])

    depth_memo = {}

    def depth(node, seen):
        key = (node, seen)
        if key in depth_memo:
            return depth_memo[key]
        best = 1
        for nxt in adjacency.get(node, ()):
            if nxt in seen:
                continue
            best = max(best, 1 + depth(nxt, seen + (nxt,)))
        depth_memo[key] = best
        return best

    max_depth = max((depth(sid, (sid,)) for sid in by_id), default=0)
    return {"asymmetric": asymmetric, "orphans": orphans, "cycles": cycles,
            "max_depth": max_depth}


def check(data_dir=os.path.join(ROOT, "data")):
    eco = ecosystem(data_dir)
    st = structure(eco)
    fails = []

    # E-1 — 총계·중복. 도감은 몬스터 + ambient 를 미러한다 (check_monsters M-9 와 같은 계약).
    total = len(eco["by_id"])
    if eco["duplicates"]:
        fails.append("E-1 id 중복 %d: %s" % (len(eco["duplicates"]), ", ".join(eco["duplicates"][:5])))
    if total != eco["codex"]:
        fails.append("E-1 종 %d ≠ 도감 %d" % (total, eco["codex"]))
    if total != eco["monsters"] + eco["ambient"]:
        fails.append("E-1 종 %d ≠ 전투 %d + 비전투 %d" % (total, eco["monsters"], eco["ambient"]))

    # E-2 — 종 참조. 자원으로 해석되는 이름은 실패가 아니다 (08 — 미등재는 자원 표기).
    if eco["dangling_species"]:
        fails.append("E-2 없는 종 참조 %d: %s"
                     % (len(eco["dangling_species"]), ", ".join(sorted(eco["dangling_species"])[:5])))

    # E-3 — 쌍방 정합.
    if st["asymmetric"]:
        sample = ", ".join("%s→%s(%s)" % row for row in st["asymmetric"][:3])
        fails.append("E-3 쌍방 위반 %d: %s" % (len(st["asymmetric"]), sample))

    # E-4 — 고아.
    if st["orphans"]:
        fails.append("E-4 고아 %d: %s" % (len(st["orphans"]), ", ".join(st["orphans"][:5])))

    # E-5 — 순환.
    if st["cycles"]:
        fails.append("E-5 순환 %d: %s" % (len(st["cycles"]), " / ".join("→".join(c) for c in st["cycles"][:2])))

    # E-6 — 0간선 바이옴.
    empty = [b["id"] for b in eco["biomes"] if b["edges"] == 0]
    if empty:
        fails.append("E-6 0간선 바이옴 %d: %s" % (len(empty), ", ".join(empty)))

    # E-7 — 근원자원·채널의 biomeId. 07 §5.1 이 서고 코드를 `biome_library` 로 유지하라고
    # 못 박았는데 채널 쪽만 옛 이름(`biome_archive`)을 쓰면 그 바이옴의 근원자원이 사라진다.
    biome_ids = eco["biome_ids"]
    for label, ids in (("근원자원", eco["root_ids"]), ("채널", eco["channel_ids"])):
        canon_ids = {canonical(i) for i in ids}
        unknown = sorted(i for i in ids if canonical(i) not in set(biome_ids))
        missing = sorted(set(biome_ids) - canon_ids)
        if unknown:
            fails.append("E-7 %s biomeId 가 biomes.json 에 없다: %s" % (label, ", ".join(unknown)))
        if missing:
            fails.append("E-7 %s 가 없는 바이옴: %s" % (label, ", ".join(missing)))

    return {"eco": eco, "structure": st, "fails": fails}


def report(out):
    eco, st = out["eco"], out["structure"]
    print("먹이그물 — E-1~E-6")
    print("  종 %d (전투 %d + 비전투 %d) · 도감 %d · 종간 간선 %d · 자원 참조 %d종"
          % (len(eco["by_id"]), eco["monsters"], eco["ambient"], eco["codex"],
             len(eco["edges"]), len(eco["resource_refs"])))
    print("  고아 %d · 쌍방 위반 %d · 순환 %d · 최대 사슬 깊이 %d"
          % (len(st["orphans"]), len(st["asymmetric"]), len(st["cycles"]), st["max_depth"]))
    if eco["unlisted_resources"]:
        names = ", ".join("%s×%d" % (k, v) for k, v in eco["unlisted_resources"].most_common(8))
        print("  미등재 자원 %d종 (실패 아님): %s"
              % (len(eco["unlisted_resources"]), names))
    print("  바이옴 — 종·간선·길드·근원자원:")
    for b in eco["biomes"]:
        roles = b["roles"]
        predator = sum(roles.get(r, 0) for r in PREDATOR_ROLES)
        prey = sum(roles.get(r, 0) for r in PREY_ROLES)
        decomposer = sum(roles.get(r, 0) for r in DECOMPOSER_ROLES)
        print("    %-26s 종 %2d · 간선 %3d · 포식 %2d · 피식 %2d · 분해 %2d · 근원 %s(K=%s r=%s)"
              % (b["id"], b["species"], b["edges"], predator, prey, decomposer,
                 b["root"], b["K"], b["r"]))
    for f in out["fails"]:
        print("  [FAIL] " + f)
    print("  → %s" % ("통과" if not out["fails"] else "실패 %d건" % len(out["fails"])))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--json", action="store_true", help="결과를 JSON 하나로 낸다")
    ap.add_argument("--data-dir", default=os.path.join(ROOT, "data"),
                    help="검사할 데이터 폴더 (기본 data/)")
    args = ap.parse_args()

    out = check(args.data_dir)
    if args.json:
        payload = {
            "species": len(out["eco"]["by_id"]), "monsters": out["eco"]["monsters"],
            "ambient": out["eco"]["ambient"], "codex": out["eco"]["codex"],
            "edges": len(out["eco"]["edges"]), "orphans": len(out["structure"]["orphans"]),
            "asymmetric": len(out["structure"]["asymmetric"]),
            "cycles": len(out["structure"]["cycles"]), "max_depth": out["structure"]["max_depth"],
            "unlisted_resources": dict(out["eco"]["unlisted_resources"]),
            "fails": out["fails"],
        }
        print(json.dumps(payload, ensure_ascii=False, indent=1))
    else:
        report(out)

    if out["fails"]:
        return 1
    return 0


if __name__ == "__main__":
    from gate_contract import run  # noqa: E402
    sys.exit(run("foodweb", main))
