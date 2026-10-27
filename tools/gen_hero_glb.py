#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""영웅 몸통 3종 → `godot/assets/art/models/hero_<band>.glb`.

무엇을 만드나
-------------
지금 3D 필드의 영웅은 **색 상자와 캡슐**이다 (동료 = `BoxMesh`, 조종 영웅 = `CapsuleMesh`).
생물 몸통을 붙인 뒤로는 그 상자가 몸통 옆에서 "미완성 표시"처럼 읽힌다.
영웅도 몸통 대역 셋이 실루엣을 정하고, 정체성은 **색**이 가른다 — 생물과 같은 규칙이다.

| band | 실루엣 | 인상 |
|---|---|---|
| `guard` | 넓은 어깨 · 짧은 다리 · 왼팔 방패 | 무게 · 방어 |
| `scout` | 가는 몸 · 긴 다리 · 뾰족 두건 | 빠름 · 경계 |
| `mystic` | 긴 로브 · 지팡이 · 후드 | 주문 · 거리 |

부품 이름 계약 (`FonsHeroBody` 가 읽는다)
----------------------------------------
색을 런타임에 바꾸는 부품은 `body_`·`skin_`·`head_` 로 시작한다 — 영웅 색으로 곱한다.
장비(방패·지팡이·금속 띠)는 `gear_`, 눈은 `eye_` 로 두고 색을 굽는다
(영웅 색이 눈까지 물들면 표정이 사라진다).

높이는 1.5~1.65 유닛 — 생물 `small`(≈1.6)과 같은 키대라 조우 화면에서 눈높이가 맞는다.

실행
----
    ./.venv/bin/python tools/gen_hero_glb.py           # 생성
    ./.venv/bin/python tools/gen_hero_glb.py --check   # 결과물과 다르면 exit 1

`--check` 는 게이트 단계 `heroart` 로 돈다. `.glb` 를 손으로 바꾸면 exit 1 — 정본은 이 스크립트다.
"""
import argparse
import sys
from pathlib import Path

from gate_contract import run
from gen_kit_glb import Gltf, ball, box, cone, cylinder, foot, move

HERE = Path(__file__).resolve().parent.parent
MODELS = HERE / "godot" / "assets" / "art" / "models"

# 바탕색 — 영웅 색이 곱해지는 중간 회색. 채도를 넣으면 곱한 색이 탁해진다.
BODY = "#b4b9c2"
TRIM = "#8b919b"
GEAR = "#565c68"
SHINE = "#c9ced8"
EYE = "#12141a"


# --- guard: 넓은 어깨 · 방패 ------------------------------------------------

def guard():
    pieces = [
        # 다리 둘 · 짧고 두껍다
        (TRIM, move(cylinder(0.11, 0.50, 6), 0.15, 0.0, 0.0)),
        (TRIM, move(cylinder(0.11, 0.50, 6), -0.15, 0.0, 0.0)),
        # 골반 · 넓은 흉갑
        (BODY, move(box(0.34, 0.16, 0.24), 0.0, 0.48, 0.0)),
        (BODY, move(box(0.46, 0.50, 0.30), 0.0, 0.62, 0.0)),
        # 어깨 판 — 실루엣의 가로를 만든다
        (BODY, move(box(0.62, 0.12, 0.32), 0.0, 1.10, 0.0)),
        # 팔 둘
        (TRIM, move(cylinder(0.07, 0.34, 5), 0.33, 0.78, 0.0)),
        (TRIM, move(cylinder(0.07, 0.34, 5), -0.33, 0.78, 0.0)),
        # 머리 · 투구
        (BODY, move(ball(0.17, segments=8, rings=5), 0.0, 1.36, 0.0)),
        (BODY, move(box(0.28, 0.10, 0.26), 0.0, 1.44, 0.0)),
        (GEAR, move(cone(0.05, 0.16, 5), 0.0, 1.54, 0.0)),
        # 방패 — 왼팔 바깥. 판 + 금속 테
        (GEAR, move(box(0.09, 0.50, 0.38), -0.38, 0.52, 0.02)),
        (SHINE, move(box(0.03, 0.34, 0.24), -0.43, 0.58, 0.04)),
        # 눈
        (EYE, move(box(0.06, 0.05, 0.04), 0.07, 1.36, 0.15)),
        (EYE, move(box(0.06, 0.05, 0.04), -0.07, 1.36, 0.15)),
    ]
    return foot(pieces)


# --- scout: 긴 다리 · 뾰족 두건 --------------------------------------------

def scout():
    pieces = [
        (TRIM, move(cylinder(0.07, 0.66, 5), 0.10, 0.0, 0.0)),
        (TRIM, move(cylinder(0.07, 0.66, 5), -0.10, 0.0, 0.0)),
        # 좁은 몸통
        (BODY, move(box(0.26, 0.14, 0.18), 0.0, 0.64, 0.0)),
        (BODY, move(box(0.28, 0.40, 0.20), 0.0, 0.74, 0.0)),
        # 어깨 — 좁게
        (BODY, move(box(0.36, 0.08, 0.20), 0.0, 1.10, 0.0)),
        (TRIM, move(cylinder(0.05, 0.32, 5), 0.19, 0.84, 0.0)),
        (TRIM, move(cylinder(0.05, 0.32, 5), -0.19, 0.84, 0.0)),
        # 머리 · 뾰족 두건
        (BODY, move(ball(0.14, segments=7, rings=5), 0.0, 1.22, 0.0)),
        (BODY, move(cone(0.17, 0.30, 6), 0.0, 1.26, -0.02)),
        # 망토 자락 — 뒤로 흐른다
        (TRIM, move(box(0.24, 0.46, 0.05), 0.0, 0.70, -0.15)),
        (EYE, move(box(0.05, 0.05, 0.04), 0.06, 1.22, 0.12)),
        (EYE, move(box(0.05, 0.05, 0.04), -0.06, 1.22, 0.12)),
    ]
    return foot(pieces)


# --- mystic: 긴 로브 · 지팡이 ----------------------------------------------

def mystic():
    pieces = [
        # 로브 — 밑이 넓은 원뿔. 다리를 감춘다
        (BODY, move(cone(0.30, 1.06, 8), 0.0, 0.0, 0.0)),
        (TRIM, move(cone(0.24, 0.62, 8), 0.0, 0.42, 0.0)),
        # 어깨 · 머리 · 후드
        (BODY, move(ball(0.17, segments=8, rings=5, squash=0.8), 0.0, 1.16, 0.0)),
        (BODY, move(ball(0.14, segments=7, rings=5), 0.0, 1.34, 0.0)),
        (BODY, move(cone(0.18, 0.24, 6), 0.0, 1.36, -0.01)),
        # 지팡이 — 오른쪽. 끝에 보석
        (GEAR, move(cylinder(0.028, 1.50, 5), 0.30, 0.0, 0.02)),
        (SHINE, move(ball(0.07, segments=6, rings=4), 0.30, 1.54, 0.02)),
        # 눈
        (EYE, move(box(0.05, 0.05, 0.04), 0.06, 1.34, 0.13)),
        (EYE, move(box(0.05, 0.05, 0.04), -0.06, 1.34, 0.13)),
    ]
    return foot(pieces)


PLANS = {
    "guard": guard,
    "scout": scout,
    "mystic": mystic,
}

# 색 → 부품 이름. 런타임 틴트가 `body_`·`skin_` 부품만 영웅 색으로 곱한다.
GROUPS = [
    (BODY, "body_hide"),
    (TRIM, "skin_limb"),
    (GEAR, "gear_metal"),
    (SHINE, "gear_shine"),
    (EYE, "eye_dark"),
]


def build(pieces):
    grouped = {name: [] for _, name in GROUPS}
    by_color = {color: name for color, name in GROUPS}
    for color, geo in pieces:
        grouped[by_color[color]].append((color, geo))
    gltf = Gltf("tools/gen_hero_glb.py")
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
        out = MODELS / ("hero_%s.glb" % band)
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
    sys.exit(run("heroart", main))
