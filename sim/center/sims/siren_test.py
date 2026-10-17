#!/usr/bin/env python3
"""사이렌 데이터 계약 검사 — 테스트 센터 스냅샷용 읽기 전용 검사."""
import json
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
DATA = os.path.join(ROOT, "data")


def main():
    with open(os.path.join(DATA, "monsters.json"), encoding="utf-8") as f:
        monsters = json.load(f)["monsters"]
    with open(os.path.join(DATA, "ecology_codex.json"), encoding="utf-8") as f:
        codex = json.load(f)["entries"]
    with open(os.path.join(DATA, "biomes.json"), encoding="utf-8") as f:
        biome_groups = json.load(f)["groups"]

    biomes = [b for group in biome_groups for b in group.get("biomes", [])]
    coastal = [b for b in biomes if b.get("name") == "원천연안"]
    # D-277 온도 재조정에서 바이옴 climate.band 가 정본이 되었다. 여기서 절대값(0~30°C 등)을
    # 테스트에 박아두면, 데이터가 고쳐질 때마다 "계약"이 아니라 "숫자"가 낡아져 FAIL 이 된다.
    # → 사이렌 기온 내성은 원천연안 climate.band 와 동일해야 한다는 상대 계약으로 검사한다.
    COASTAL_BAND = coastal[0].get("climate", {}).get("band") if len(coastal) == 1 else None

    failures = []
    matches = [m for m in monsters if m.get("id") == "mon_siren_01"]
    if len(matches) != 1:
        failures.append(f"mon_siren_01은 1개여야 함 (실제 {len(matches)})")
        siren = matches[0] if matches else None
    else:
        siren = matches[0]

    if siren:
        expected = {
            "name": "사이렌",
            "category": 5,
            "aiType": "magic",
            "tier": 2,
            "threatBase": 46.0,
            "element": "water",
        }
        for key, value in expected.items():
            if siren.get(key) != value:
                failures.append(f"{key}={siren.get(key)!r} (기대 {value!r})")
        stats = siren.get("stats", {})
        for key in ("hp", "atk", "def", "aspd", "mdef", "mag", "mana", "spd_cast", "cri", "cdmg", "eva", "sta"):
            if not isinstance(stats.get(key), (int, float)) or stats[key] <= 0:
                failures.append(f"stats.{key} 누락 또는 0 이하")
        if stats.get("mana") != stats.get("mag", 0) * 15:
            failures.append("mana는 mag×15여야 함")
        if siren.get("aiDecision", {}).get("specialSkill") != "siren_song":
            failures.append("aiDecision.specialSkill은 siren_song이어야 함")
        patterns = siren.get("pattern", [])
        if len(patterns) != 3:
            failures.append(f"패턴 3개 필요 (실제 {len(patterns)})")
        for i, pattern in enumerate(patterns, 1):
            for key in ("name", "effect", "telegraph", "counter"):
                if not pattern.get(key):
                    failures.append(f"패턴 {i} {key} 누락")
        ecology = siren.get("ecology", {})
        if ecology.get("role") != "predator" or ecology.get("diet") != "carnivore":
            failures.append("사이렌 생태 역할/먹이는 육식 포식자여야 함")
        if not {"ocean", "coral"}.issubset(set(ecology.get("habitat", []))):
            failures.append("habitat은 ocean·coral을 모두 포함해야 함")
        temperature = ecology.get("temperature", {})
        if [temperature.get("min"), temperature.get("max")] != COASTAL_BAND:
            failures.append(
                f"temperature {[temperature.get('min'), temperature.get('max')]}는 "
                f"원천연안 climate.band {COASTAL_BAND}와 일치해야 함")
        if siren.get("spawn", {}).get("floors") != [11, 15]:
            failures.append("spawn.floors는 원천연안 슬롯 3의 11~15층이어야 함")
        if "lightning" not in siren.get("weakness", {}).get("element", []):
            failures.append("lightning 약점 누락")

    codex_matches = [entry for entry in codex if entry.get("id") == "mon_siren_01"]
    if len(codex_matches) != 1:
        failures.append(f"도감 항목 mon_siren_01은 1개여야 함 (실제 {len(codex_matches)})")
    elif coastal:
        # habitat 을 **집합으로** 비교한다. 2026-09-30 실측: 도감 364개 항목은
        # 전부 `sorted(habitat)` 로 생성되어 있어 ["coral", "ocean"] 이고, 이 검사는
        # ["ocean", "coral"] 을 리터럴로 요구했다. 서식지 *집합*은 맞는데 순서만
        # 달라서 FAIL 이었다 — 계약이 아니라 표기 순서를 재는 검사였다(§온도 상대 계약
        # 전환과 같은 이유). 기준은 여전히 원천연안 바이옴이 하므로 리터럴은 남는다.
        if set(codex_matches[0].get("habitat") or []) != set(coastal[0].get("habitat") or []):
            failures.append(
                f"도감의 habitat {codex_matches[0].get('habitat')}이 "
                f"원천연안 {coastal[0].get('habitat')}와 불일치")
        elif codex_matches[0].get("spawnBlock") != coastal[0].get("slots", [None])[0]:
            failures.append(
                f"도감의 spawnBlock {codex_matches[0].get('spawnBlock')}이 "
                f"원천연안 슬롯 {coastal[0].get('slots')}와 불일치")

    if len(coastal) != 1:
        failures.append(f"원천연안 바이옴은 1개여야 함 (실제 {len(coastal)})")
    elif not (isinstance(COASTAL_BAND, list) and len(COASTAL_BAND) == 2
              and all(isinstance(v, (int, float)) for v in COASTAL_BAND)
              and COASTAL_BAND[0] < COASTAL_BAND[1]):
        failures.append(f"원천연안 climate.band 는 상승하는 2구간이어야 함 (실제 {COASTAL_BAND})")
    elif coastal[0].get("slots", [None])[0] != 3 or not {"ocean", "coral"}.issubset(set(coastal[0].get("habitat", []))):
        failures.append("원천연안 슬롯·habitat이 사이렌 배치와 불일치")
    elif siren:
        band = COASTAL_BAND
        temp = siren.get("ecology", {}).get("temperature", {})
        if len(band) != 2 or temp.get("min", 999) > band[1] or temp.get("max", -999) < band[0]:
            failures.append("사이렌 기온 내성과 원천연안 기후가 겹치지 않음")

    if failures:
        print("FAIL — 사이렌 데이터 계약")
        for failure in failures:
            print(f"  - {failure}")
        return 1

    print("OK — 사이렌 T2·전투 스탯·노래 패턴 3개·원천연안 슬롯 3·기후·도감 연동")
    return 0


if __name__ == "__main__":
    sys.exit(main())
