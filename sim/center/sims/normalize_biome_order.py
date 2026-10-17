#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""normalize_biome_order.py — biomes.json 정본 순서 정규화 (확정 #66).

정본: design-docs/설계/아크13_바이옴13_8_5_재배치.md §2 재배치표 (2026-09-28 재설계 확정안)
      — 옛 정본 design-docs/설계/층별세계_26블록_설계.md 는 G2=9종·G3 존재를 전제해 대체됨
문제(실측): ① 그룹 내 biomes 배열이 정본과 다름 (g1 6곳 회전 · g2 9곳 밀림)
           ② slots[0]이 그룹 내 슬롯번호라서 도감 코덱스의 "블록 N" 표기가
              G2(11~19)·G4(21~26)에서 애초에 정본 블록과 불일치
규칙:      ① groups[].biomes 배열 = 정본 블록 순서 (배열 순서 == 블록 순서)
           ② slots[0] = 전역 블록 번호(1~26) — 코덱스 "블록 N" 라벨의 단일 소스
           ③ slots[1]·나머지 모든 필드 불변 (순서·라벨만 정규화)
멱등: 재실행해도 동일 결과. 소비자 영향: 게임 본편은 category 기반(무영향),
      check_docs·시뮬은 habitat/group 기반(무영향), 코덱스는 재생성으로 정합.
실행: python3 design-docs/_tools/normalize_biome_order.py
"""
import json
import os

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
PATH = os.path.join(ROOT, "data", "biomes.json")

# 26블록 정본 순서 (아크13_바이옴13_8_5_재배치.md §2 재배치표)
# 계층 배분 13 : 8 : 5 — G3 층은 흡수되어 더 이상 존재하지 않는다.
#  블록  1~13 = G1 하층 · 14~21 = G2 중층 · 22~26 = G4 상층
CANON = {
    "g1": ["biome_plains", "biome_forest", "biome_coastal_sea", "biome_library", "biome_maze_city",
           "biome_skyreach", "biome_temple", "biome_cave", "biome_ruins", "biome_deep_sea",
           "biome_sewer", "biome_mountain_range", "biome_swamp"],
    "g2": ["biome_jungle", "biome_graveyard", "biome_volcano", "biome_desert",
           "biome_windless_plateau", "biome_hell", "biome_chasm", "biome_summit"],
    "g4": ["biome_frozen_ocean", "biome_crystal_forest", "biome_glass_desert",
           "biome_shattered_skylight", "biome_idea_gate"],
}


def main():
    with open(PATH, encoding="utf-8") as f:
        data = json.load(f)

    block_no = 0
    changed = []
    for g in data["groups"]:
        want = CANON[g["id"]]
        cur_ids = [b["id"] for b in g["biomes"]]
        if set(cur_ids) != set(want):
            raise SystemExit(f"FATAL: {g['id']} 바이옴 집합이 정본과 다름: {set(want) ^ set(cur_ids)}")
        if cur_ids != want:
            changed.append(f"{g['id']}: 배열 재배열 ({len(cur_ids)}종)")
        by_id = {b["id"]: b for b in g["biomes"]}
        ordered = []
        for bid in want:
            block_no += 1
            b = by_id[bid]
            if b.get("slots", [0, 0])[0] != block_no:
                changed.append(f"  {bid}: slots[0] {b.get('slots', [0])[0]} → {block_no}")
                b["slots"] = [block_no, b.get("slots", [0, 9])[1]]
            ordered.append(b)
        g["biomes"] = ordered

    assert block_no == 26, f"블록 총계 {block_no} != 26"
    # 멱등 안전: 변경이 없으면 파일을 건드리지 않는다. 이 스크립트는 테스트 센터 스냅샷에서
    # "검사"로도 도는데, 무조건 덮어쓰면 바이옴 개편이 진행 중인 biomes.json 을 단순
    # 재서식화해 타 세션의 작업을 훼손할 위험이 있다.
    if changed:
        with open(PATH, "w", encoding="utf-8") as f:
            json.dump(data, f, ensure_ascii=False, indent=2)
            f.write("\n")
        print("정본화 완료 (26블록 정본 순서 · slots[0]=전역 블록 번호)")
        print("변경 내역:")
        for c in changed:
            print("  -", c)
    else:
        print("변경 없음 — 이미 13:8:5 정본 정합 (멱등 확인, 파일 미변경)")

    # 자기검증
    with open(PATH, encoding="utf-8") as f:
        chk = json.load(f)
    n = 0
    for g in chk["groups"]:
        for i, b in enumerate(g["biomes"], 1):
            assert b["id"] == CANON[g["id"]][i - 1], f"{g['id']} #{i} 불일치"
            assert b["slots"][0] == n + i, f"{b['id']} slots[0]={b['slots'][0]} != {n + i}"
        n += len(g["biomes"])
    print(f"자기검증 OK — 26바이옴 정본 순서 · 블록 번호 1~26 연속")


if __name__ == "__main__":
    main()
