#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""몸집 대역 3종 → `godot/assets/art/models/creature_<band>.glb`.

무엇을 만드나
-------------
S5 키 매핑(`data/monster_assets.json`)은 78칸에 **어느 종**이 사는지만 정한다.
메시는 대역 셋이면 된다 — 종마다 몸통을 새로 만들면 5종 이상은 같은 실루엣을
색만 바꿔 늘어놓은 것으로 읽힌다. 대역이 실루엣을 정하고, 종은 **색과 크기**가 가른다.

| band | 실루엣 | 쓰는 역할 (`monster_assets.json` bands) |
|---|---|---|
| `heavy` | 네발 · 낮고 넓은 몸통 · 뿔 · 두꺼운 다리 | apex · predator · hunter · guardian · elemental |
| `small` | 두발 · 둥근 몸통 · 큰 귀 · 짧은 팔 | prey · swarm · scavenger · decomposer |
| `odd` | 세발 · 길쭉한 몸통 · 외눈 · 등 가시 | ambusher · undead · corruptor · mimic |

부품 이름 계약 (`FonsMonsterBody` 가 읽는다)
--------------------------------------------
색을 런타임에 바꾸는 부품은 `body_`·`skin_`·`head_`·`tail_` 로 시작한다 — 종의 원소
색으로 곱한다. 뿔·가시·귀는 `horn_`·`spike_`·`ear_`, 눈은 `eye_` 로 두고 색을 굽는다
(원소색이 눈까지 물들면 표정이 사라진다).

높이는 대역이 정한다 — heavy ≈ 1.3 · small ≈ 1.6(귀 포함) · odd ≈ 1.9 유닛.
런타임 배율(`FonsMonsterBody` tier 배율)이 그 위에 곱해진다.

왜 여기서 GLB 를 직접 쓰나
--------------------------
`tools/gen_kit_glb.py` 와 같은 이유다 — 이 머신에서 Blender 4.5 의 glTF 익스포터가
numpy/Accelerate 심볼 문제로 죽는다. 기하 헬퍼를 그 파일에서 그대로 가져다 쓴다.

실행
----
    ./.venv/bin/python tools/gen_monster_glb.py           # 생성
    ./.venv/bin/python tools/gen_monster_glb.py --check   # 결과물과 다르면 exit 1

`--check` 는 게이트 단계 `creatureart` 로 돈다. `.glb` 를 손으로 바꾸면 exit 1 —
정본은 이 스크립트다.
"""
import argparse
import sys
from pathlib import Path

from gate_contract import run
from gen_kit_glb import Gltf, ball, box, cone, cylinder, foot, move

HERE = Path(__file__).resolve().parent.parent
MODELS = HERE / "godot" / "assets" / "art" / "models"

# 바탕색 — 원소 색이 곱해지는 중간 회색. 채도를 넣으면 곱한 색이 탁해진다.
BODY = "#9aa0a8"
BELLY = "#b6bbc2"
LIMB = "#7c828a"
HORN = "#d8d2c4"
EYE = "#14161a"


# --- heavy: 네발 · 뿔 -----------------------------------------------------

def heavy():
    # 낮고 넓은 몸통 · 짧은 다리 넷 · 앞으로 내민 뿔 머리. 실루엣의 가로:세로가 1.3:1.
    pieces = [
        (BODY, ball(0.72, segments=12, rings=6, squash=0.56, lift=0.80)),
        (BELLY, move(ball(0.54, segments=8, rings=4, squash=0.46, lift=0.66), 0.0, 0.0, 0.10)),
        # 머리 — 몸통 앞(+Z)에 낮게 붙는다
        (BODY, move(ball(0.30, segments=8, rings=5, squash=0.86, lift=0.84), 0.0, 0.0, 0.70)),
        (BODY, move(ball(0.15, segments=6, rings=4, squash=0.78, lift=0.76), 0.0, 0.0, 0.96)),
        # 뿔 두 개 — 앞으로 뻗은 인상
        (HORN, move(cone(0.08, 0.32, 6), 0.19, 0.98, 0.68)),
        (HORN, move(cone(0.08, 0.32, 6), -0.19, 0.98, 0.68)),
        # 등 가시 — 무게중심을 낮게 눌러 준다
        (HORN, move(cone(0.07, 0.16, 5), 0.0, 1.18, 0.10)),
        (HORN, move(cone(0.06, 0.12, 5), 0.0, 1.16, -0.28)),
        # 눈
        (EYE, move(box(0.07, 0.06, 0.05), 0.14, 0.88, 0.99)),
        (EYE, move(box(0.07, 0.06, 0.05), -0.14, 0.88, 0.99)),
        # 다리 네 개 — 몸통 밖으로 보이게 길게
        (LIMB, move(cylinder(0.14, 0.48, 6), 0.40, 0.0, 0.36)),
        (LIMB, move(cylinder(0.14, 0.48, 6), -0.40, 0.0, 0.36)),
        (LIMB, move(cylinder(0.16, 0.48, 6), 0.40, 0.0, -0.36)),
        (LIMB, move(cylinder(0.16, 0.48, 6), -0.40, 0.0, -0.36)),
        # 꼬리 — 뒤로 처지는 두 덩이
        (LIMB, move(ball(0.13, segments=6, rings=4), 0.0, 0.80, -0.76)),
        (LIMB, move(ball(0.10, segments=6, rings=4), 0.0, 0.66, -0.92)),
    ]
    return foot(pieces)


# --- small: 두발 · 큰 귀 --------------------------------------------------

def small():
    # 머리가 몸통만 한 두발 — 큰 귀와 짧은 팔이 small 을 만든다.
    pieces = [
        (BODY, ball(0.30, segments=8, rings=6, squash=1.00, lift=0.66)),
        (BELLY, move(ball(0.21, segments=6, rings=4, squash=0.80, lift=0.60), 0.0, 0.0, 0.08)),
        # 머리 — 몸통보다 크게, 위로 얹는다
        (BODY, move(ball(0.33, segments=8, rings=5, squash=1.00, lift=1.14), 0.0, 0.0, 0.02)),
        (BODY, move(ball(0.14, segments=6, rings=4, squash=0.80, lift=1.02), 0.0, 0.0, 0.28)),
        (EYE, move(box(0.07, 0.08, 0.05), 0.13, 1.18, 0.30)),
        (EYE, move(box(0.07, 0.08, 0.05), -0.13, 1.18, 0.30)),
        # 귀 — 머리보다 위로 솟는다
        (HORN, move(cone(0.10, 0.34, 5), 0.18, 1.28, 0.0)),
        (HORN, move(cone(0.10, 0.34, 5), -0.18, 1.28, 0.0)),
        # 다리 두 개 · 팔 두 개 · 짧은 꼬리
        (LIMB, move(cylinder(0.10, 0.36, 5), 0.15, 0.0, 0.0)),
        (LIMB, move(cylinder(0.10, 0.36, 5), -0.15, 0.0, 0.0)),
        (LIMB, move(cylinder(0.06, 0.24, 5), 0.28, 0.54, 0.02)),
        (LIMB, move(cylinder(0.06, 0.24, 5), -0.28, 0.54, 0.02)),
        (LIMB, move(ball(0.10, segments=6, rings=4), 0.0, 0.50, -0.34)),
    ]
    return foot(pieces)


# --- odd: 세발 · 외눈 · 등 가시 -------------------------------------------

def odd():
    # 홀쭉하고 긴 몸통 · 세발 · 외눈 · 등 가시. 가로:세로가 1:2.6.
    pieces = [
        # 세발 — 바닥에 삼각으로 선다
        (LIMB, move(cylinder(0.07, 0.58, 5), 0.0, 0.0, 0.26)),
        (LIMB, move(cylinder(0.07, 0.58, 5), 0.22, 0.0, -0.13)),
        (LIMB, move(cylinder(0.07, 0.58, 5), -0.22, 0.0, -0.13)),
        # 길쭉한 몸통
        (BODY, ball(0.24, segments=8, rings=6, squash=2.20, lift=1.06)),
        (BELLY, move(ball(0.15, segments=6, rings=4, squash=1.80, lift=1.02), 0.0, 0.0, 0.09)),
        # 등 가시
        (HORN, move(cone(0.05, 0.30, 5), 0.0, 1.34, 0.08)),
        (HORN, move(cone(0.04, 0.24, 5), 0.0, 1.18, -0.10)),
        (HORN, move(cone(0.04, 0.20, 5), 0.0, 0.98, -0.16)),
        # 머리 · 외눈
        (BODY, move(ball(0.23, segments=7, rings=5, squash=1.10, lift=1.62), 0.0, 0.0, 0.03)),
        (EYE, move(box(0.18, 0.12, 0.06), 0.0, 1.62, 0.24)),
        # 팔 하나 — 비대칭이 odd 로 읽히게
        (LIMB, move(cylinder(0.05, 0.38, 5), 0.24, 0.86, 0.0)),
    ]
    return foot(pieces)


PLANS = {
    "heavy": heavy,
    "small": small,
    "odd": odd,
}


# 색 → 부품 이름. 런타임 틴트가 `body_`·`skin_` 부품만 원소색으로 곱한다.
GROUPS = [
    (BODY, "body_hide"),
    (BELLY, "body_belly"),
    (LIMB, "skin_limb"),
    (HORN, "horn_spike"),
    (EYE, "eye_dark"),
]


def build(pieces):
    grouped = {name: [] for _, name in GROUPS}
    by_color = {color: name for color, name in GROUPS}
    for color, geo in pieces:
        grouped[by_color[color]].append((color, geo))
    gltf = Gltf("tools/gen_monster_glb.py")
    for _, name in GROUPS:
        if grouped[name]:
            gltf.part(name, grouped[name])
    return gltf.pack()


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--check", action="store_true", help="결과물이 생성물과 같은지만 본다")
    args = ap.parse_args()

    bad = 0
    for band in sorted(PLANS):
        parts = PLANS[band]()
        data = build(parts)
        out = MODELS / ("creature_%s.glb" % band)
        print("%-12s 조각 %d · %d bytes" % (band, len(parts), len(data)))
        if args.check:
            if not out.exists():
                print("[ FAIL ] 없음 — %s (생성기로 뽑는다)" % out.relative_to(HERE))
                bad += 1
            elif out.read_bytes() != data:
                print("[ FAIL ] 다름 — %s (정본은 이 스크립트다)" % out.relative_to(HERE))
                bad += 1
            continue
        out.parent.mkdir(parents=True, exist_ok=True)
        out.write_bytes(data)
    if args.check:
        if bad:
            return 1
        print("결과물 %d = 생성물" % len(PLANS))
        return 0
    print("씀 — %s (%d몸통)" % (MODELS.relative_to(HERE), len(PLANS)))
    return 0


if __name__ == "__main__":
    sys.exit(run("creatureart", main))
