#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""지형 키트 9종 → `godot/assets/art/models/<kit>.glb`.

무엇을 만드나
-------------
`data/biomes.json` 의 `topologyKit` 9종 전부. 26바이옴이 이 9벌을 나눠 쓴다:

| kit | 바이옴 | 실루엣 |
|---|---|---|
| `topo_natural_surface` | 풀바다·뿌리숲·포식밀림 | 풀 타일 · 둔덕 · 외로운 나무 |
| `topo_wetland_water` | 원천연안·부유 이끼늪·정점 | 물·진흙 타일 · 둑 · 물에 잠긴 나무 |
| `topo_rock_cavern_mountain` | 지맥굴·지맥능선·무광심연·형상군락·마른 지맥 | 돌 타일 · 뾰족 바위 · 봉우리 |
| `topo_urban_ruins` | 서고·미궁도시·폐허·침전수로 | 포장 타일 · 부서진 벽 · 무너진 아치 |
| `topo_sacred_sanctuary` | 신전·기억묘역 | 대리석 타일 · 단 · 기둥 |
| `topo_sky_interior` | 광로들판·얼음 바다·찢긴 천창 | 구름 타일 · 떠 있는 바위 · 하늘 아치 |
| `topo_underwater_specialist` | 먹빛 해구 | 모래 타일 · 산호 · 분출구 탑 |
| `topo_dry_fire` | 압력화구·먼지벌판·맥의 상흔 | 잿빛 타일 · 흑요석 · 화구 |
| `topo_frozen_crystal` | 무풍고원·이데아 문턱 | 눈 타일 · 얼음 조각 · 수정 군락 |

부품 이름 prefix 가 Godot 쪽 계약이다(`FonsBiomeKit`): `ground_` 4 · `height_` 2 ·
`landmark_` 1 · `prop_` 4 — 키트마다 11개, 총 99개.

색은 **역할별 틴트가 곱해지는 바탕색**이다. 8종 신규 키트는 채도를 낮춘 회색 계열을 써서
바이옴 팔레트(식생·암석 틴트)가 색을 정하게 둔다 — S3 의 판정 대상은 색이 아니라 **구조**다.
파일럿(`topo_natural_surface`)은 S2 색을 그대로 둔다(재생성해도 바이트가 같다).

왜 Blender 가 아니라 여기서 GLB 를 직접 쓰나
-------------------------------------------
계획 §6 은 Blender 4.5 스크립트 내보내기를 전제했지만, 이 머신(macOS 12.7.6)에서는
Blender 4.5 의 번들 numpy 1.26.4 가 최신 Accelerate 심볼을 요구해 로드에 실패한다:

    Symbol not found: (_cblas_caxpy$NEWLAPACK) — Accelerate.framework

glTF 익스포터가 numpy 를 쓰므로 `bpy.ops.export_scene.gltf` 가 죽는다. 그래서 메시를
**여기서 직접 만들고 glTF 2.0(GL B)로 쓴다.** 의존성 0(표준 라이브러리) · 결과 고정 ·
Blender 없이 재생성 가능. Blender 가 이 머신에서 되살아나면 이 스크립트가 정본이고
`.blend` 는 편집용 사본으로 두면 된다 — 계약(부품 이름·피벗·스케일)은 안 바뀐다.

좌표 규칙
---------
Y-up(glTF 규약), 1 unit = Godot 3D 월드 1유닛, 피벗은 **바닥 중앙**(y=0).
모든 부품의 최저점을 0 으로 맞춘다 — Godot 에서 `position.y = 0` 이 곧 땅에 서는 것이다.
색은 sRGB 표기를 선형으로 바꿔 넣는다(glTF `baseColorFactor` 는 선형값이다).

실행
----
    ./.venv/bin/python tools/gen_kit_glb.py           # 생성
    ./.venv/bin/python tools/gen_kit_glb.py --check   # 결과물과 다르면 exit 1

`--check` 는 게이트 단계 `kitart` 로 돈다. `.glb` 를 손으로 바꾸면 exit 1 — 정본은 이 스크립트다.
"""
import argparse
import json
import math
import struct
import sys
from pathlib import Path

from gate_contract import run

HERE = Path(__file__).resolve().parent.parent
MODELS = HERE / "godot" / "assets" / "art" / "models"

TILE = 5.0
TAU = math.tau


# --- 색 -------------------------------------------------------------------

def linear(hex_color):
    """`#rrggbb` sRGB → glTF 선형 색 4성분."""
    def channel(v):
        return v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4

    raw = [int(hex_color[i:i + 2], 16) / 255.0 for i in (1, 3, 5)]
    return [round(channel(v), 6) for v in raw] + [1.0]


# --- 기하 (정점 · 법선 · 삼각형) ------------------------------------------

def quad(size):
    """바닥 타일 — x,z 로 `size` 만 한 정사각형, 법선 +Y."""
    s = size * 0.5
    pos = [(-s, 0.0, s), (s, 0.0, s), (s, 0.0, -s), (-s, 0.0, -s)]
    return pos, [(0.0, 1.0, 0.0)] * 4, [0, 1, 2, 0, 2, 3]


def cylinder(radius, height, segments=6):
    """밑면 y=0 · 윗면 y=height 인 기둥. 옆면은 바깥 법선, 윗면은 +Y."""
    pos, nrm, idx = [], [], []
    for i in range(segments):
        a = TAU * i / segments
        pos.append((radius * math.cos(a), 0.0, radius * math.sin(a)))
        nrm.append((math.cos(a), 0.0, math.sin(a)))
    for i in range(segments):
        a = TAU * i / segments
        pos.append((radius * math.cos(a), height, radius * math.sin(a)))
        nrm.append((math.cos(a), 0.0, math.sin(a)))
    for i in range(segments):
        j = (i + 1) % segments
        # 아래 i → 위 i → 위 j → 아래 j — 바깥을 보는 감기
        idx += [i, segments + i, segments + j, i, segments + j, j]
    top = len(pos)
    pos.append((0.0, height, 0.0))
    nrm.append((0.0, 1.0, 0.0))
    for i in range(segments):
        idx += [top, segments + ((i + 1) % segments), segments + i]
    return pos, nrm, idx


def cone(radius, height, segments=6):
    """밑면 y=0 · 꼭대기 y=height 인 원뿔. 봉우리·수정·흑요석에 쓴다."""
    pos, nrm, idx = [], [], []
    slope = radius / max(height, 1e-6)
    for i in range(segments):
        a = TAU * i / segments
        pos.append((radius * math.cos(a), 0.0, radius * math.sin(a)))
        nrm.append((math.cos(a), slope, math.sin(a)))
    apex = len(pos)
    pos.append((0.0, height, 0.0))
    nrm.append((0.0, 1.0, 0.0))
    base = len(pos)
    pos.append((0.0, 0.0, 0.0))
    nrm.append((0.0, -1.0, 0.0))
    for i in range(segments):
        j = (i + 1) % segments
        idx += [i, apex, j]
        idx += [base, j, i]
    return pos, nrm, idx


def box(width, height, depth):
    """x·y·z 로 `width`·`height`·`depth` 인 상자. 밑면 y=0, 중심 x=z=0."""
    x, y, z = width * 0.5, height * 0.5, depth * 0.5
    faces = [
        ((0.0, 1.0, 0.0), [(-x, height, z), (x, height, z), (x, height, -z), (-x, height, -z)]),
        ((0.0, -1.0, 0.0), [(-x, 0.0, -z), (x, 0.0, -z), (x, 0.0, z), (-x, 0.0, z)]),
        ((0.0, 0.0, 1.0), [(-x, 0.0, z), (x, 0.0, z), (x, height, z), (-x, height, z)]),
        ((0.0, 0.0, -1.0), [(x, 0.0, -z), (-x, 0.0, -z), (-x, height, -z), (x, height, -z)]),
        ((1.0, 0.0, 0.0), [(x, 0.0, z), (x, 0.0, -z), (x, height, -z), (x, height, z)]),
        ((-1.0, 0.0, 0.0), [(-x, 0.0, -z), (-x, 0.0, z), (-x, height, z), (-x, height, -z)]),
    ]
    pos, nrm, idx = [], [], []
    for normal, corners in faces:
        start = len(pos)
        pos += corners
        nrm += [normal] * 4
        idx += [start, start + 1, start + 2, start, start + 2, start + 3]
    return pos, nrm, idx


def ball(radius, segments=8, rings=5, squash=1.0, lift=0.0):
    """저해상 구 — 위아래를 눌러 둔덕·덤불·바위에 같이 쓴다. 중심 높이 `lift`."""
    pos, nrm, idx = [], [], []
    for r in range(rings + 1):
        phi = math.pi * r / rings
        y = math.cos(phi)
        ring = math.sin(phi)
        for i in range(segments):
            a = TAU * i / segments
            pos.append((radius * ring * math.cos(a), radius * y * squash + lift,
                        radius * ring * math.sin(a)))
            nrm.append((ring * math.cos(a), y, ring * math.sin(a)))
    for r in range(rings):
        for i in range(segments):
            j = (i + 1) % segments
            a = r * segments + i
            b = r * segments + j
            c = (r + 1) * segments + j
            d = (r + 1) * segments + i
            idx += [a, b, c, a, c, d]
    return pos, nrm, idx


def move(geo, dx=0.0, dy=0.0, dz=0.0):
    pos, nrm, idx = geo
    return [(x + dx, y + dy, z + dz) for (x, y, z) in pos], nrm, idx


def foot(pieces):
    """조립품의 최저점을 y=0 으로 내린다 — 피벗은 항상 바닥 중앙."""
    low = min(y for _, (pos, _, _) in pieces for (_, y, _) in pos)
    return [(color, ([(x, y - low, z) for (x, y, z) in pos], nrm, idx))
            for color, (pos, nrm, idx) in pieces]


# --- 조립품: [(색, 기하)] -------------------------------------------------

TRUNK = "#4a3a28"
LEAF = "#3d5a30"
STEM = "#4f7a3a"
PETAL = "#d9c95a"


def tree():
    return foot([
        (TRUNK, cylinder(0.22, 3.2, segments=6)),
        (LEAF, ball(1.9, squash=1.0, lift=4.1)),
        (LEAF, ball(1.2, squash=0.9, lift=3.1)),
    ])


def flower():
    pieces = [(STEM, cylinder(0.05, 0.6, segments=5))]
    for i in range(3):
        a = TAU * i / 3.0
        pieces.append((PETAL, move(ball(0.2, segments=5, rings=3), 0.14 * math.cos(a), 0.6,
                                   0.14 * math.sin(a))))
    return foot(pieces)


# --- 1. topo_natural_surface (S2 파일럿 — 색·부품을 바꾸지 않는다) ----------

NATURAL = [
    ("ground_grass_a", [("#5c6b3a", quad(TILE))]),
    ("ground_grass_b", [("#647243", quad(TILE))]),
    ("ground_grass_c", [("#556332", quad(TILE))]),
    ("ground_grass_d", [("#6d7a48", quad(TILE))]),
    ("height_mound_a", [("#4e5c33", ball(2.4, squash=0.45, lift=1.08))]),
    ("height_mound_b", foot([("#6f6f68", cylinder(1.6, 0.9, segments=6)),
                             ("#767669", ball(1.5, squash=0.55, lift=0.9))])),
    ("landmark_lone_tree", tree()),
    ("prop_bush", [("#3f5a2e", ball(0.7, squash=0.80, lift=0.56))]),
    ("prop_rock", [("#77776f", ball(0.55, squash=0.72, lift=0.40))]),
    ("prop_flower", flower()),
    ("prop_stump", [("#6b4f34", cylinder(0.38, 0.45, segments=7))]),
]

# --- 2. topo_wetland_water ------------------------------------------------

WETLAND = [
    ("ground_mud_a", [("#6a6152", quad(TILE))]),
    ("ground_mud_b", [("#5f5749", quad(TILE))]),
    ("ground_water_a", [("#41616a", quad(TILE))]),
    ("ground_water_b", [("#3a565f", quad(TILE))]),
    ("height_bank", foot([("#5a5346", box(3.0, 0.45, 1.8)),
                          ("#4f5c38", box(2.4, 0.12, 1.2))])),
    ("height_reed_bed", foot([
        ("#4e5c3a", cylinder(0.09, 1.9, segments=4)),
        ("#4e5c3a", move(cylinder(0.09, 1.5, segments=4), 0.35, 0.0, 0.28)),
        ("#546440", move(cylinder(0.08, 2.2, segments=4), -0.32, 0.0, 0.34)),
        ("#546440", move(cylinder(0.08, 1.7, segments=4), 0.12, 0.0, -0.42)),
    ])),
    ("landmark_drowned_tree", foot([
        ("#4a3f30", cylinder(0.28, 2.4, segments=6)),
        ("#4a3f30", move(cylinder(0.20, 2.6, segments=6), 0.55, 2.1, 0.18)),
        ("#54683f", ball(1.4, squash=0.7, lift=4.3)),
        ("#54683f", ball(0.9, squash=0.7, lift=5.0)),
    ])),
    ("prop_lily", [("#4f6f45", ball(0.62, squash=0.06, lift=0.06))]),
    ("prop_cattail", foot([("#4f7a3a", cylinder(0.07, 1.2, segments=4)),
                           ("#7a5c34", cylinder(0.11, 0.35, segments=5))])),
    ("prop_driftwood", foot([("#6b5f4a", box(1.5, 0.16, 0.22))])),
    ("prop_shell", [("#9a9484", ball(0.42, squash=0.55, lift=0.2))]),
]

# --- 3. topo_rock_cavern_mountain ----------------------------------------

ROCK = [
    ("ground_stone_a", [("#6e6e68", quad(TILE))]),
    ("ground_stone_b", [("#787870", quad(TILE))]),
    ("ground_stone_c", [("#63635e", quad(TILE))]),
    ("ground_stone_d", [("#575752", quad(TILE))]),
    ("height_boulder", [("#77776f", ball(1.9, squash=0.55, lift=0.8))]),
    ("height_spire", [("#6a6a64", cone(1.15, 2.9, segments=6))]),
    ("landmark_peak", foot([
        ("#66665f", cone(2.2, 5.6, segments=7)),
        ("#70706a", move(cone(1.5, 4.2, segments=6), 1.5, 0.0, 0.9)),
        ("#5e5e58", move(cone(1.1, 3.1, segments=6), -1.6, 0.0, 1.0)),
    ])),
    ("prop_pebble", [("#7c7c74", ball(0.36, squash=0.72, lift=0.26))]),
    ("prop_slab", foot([("#727269", box(1.3, 0.24, 0.85))])),
    ("prop_mushroom", foot([("#8a8478", cylinder(0.12, 0.42, segments=5)),
                            ("#9a9388", ball(0.34, squash=0.5, lift=0.5))])),
    ("prop_crystal", [("#7c8d96", cone(0.34, 1.25, segments=5))]),
]

# --- 4. topo_urban_ruins -------------------------------------------------

URBAN = [
    ("ground_pave_a", [("#77736c", quad(TILE))]),
    ("ground_pave_b", [("#807b73", quad(TILE))]),
    ("ground_dirt", [("#6b6459", quad(TILE))]),
    ("ground_slab", [("#5e5b56", quad(TILE))]),
    ("height_wall", foot([("#7d786f", box(3.2, 2.3, 0.45)),
                          ("#6f6a62", box(1.6, 0.35, 0.5))])),
    ("height_rubble", foot([("#6f6a62", ball(1.1, squash=0.6, lift=0.5)),
                            ("#787169", move(ball(0.75, squash=0.6, lift=0.4), 0.95, 0.0, 0.5)),
                            ("#66605a", move(ball(0.6, squash=0.6, lift=0.35), -0.85, 0.0, 0.55))])),
    # 정면 **+Z** 계약을 몸으로 보이는 유일한 부품이다 — 상인방이 뒤(-Z)로 빠져 있다.
    # 앞좌우로 대칭이면 뷰가 어느 쪽을 정면으로 돌려야 하는지 알 수 없다. 값은 `axis_check()` 가 잠근다.
    ("landmark_broken_arch", foot([
        ("#807b73", cylinder(0.36, 4.5, segments=6)),
        ("#807b73", move(cylinder(0.36, 3.0, segments=6), 2.6, 0.0, 0.0)),
        ("#6e6961", move(box(3.4, 0.5, 0.7), 1.3, 3.0, -1.0)),
    ])),
    ("prop_crate", foot([("#7b6a52", box(0.85, 0.8, 0.85))])),
    ("prop_barrel", [("#6f6450", cylinder(0.34, 0.9, segments=7))]),
    ("prop_post", [("#5f5a52", cylinder(0.12, 1.7, segments=5))]),
    ("prop_shelf", foot([("#6b5f4c", box(1.4, 1.8, 0.3)),
                         ("#7a6d58", box(1.5, 0.12, 0.4))])),
]

# --- 5. topo_sacred_sanctuary --------------------------------------------

SANCTUARY = [
    ("ground_marble_a", [("#9a9a94", quad(TILE))]),
    ("ground_marble_b", [("#a3a39c", quad(TILE))]),
    ("ground_step", [("#8b8b84", quad(TILE))]),
    ("ground_dark", [("#5d5c58", quad(TILE))]),
    ("height_plinth", foot([("#8f8f88", box(1.7, 1.4, 1.7)),
                            ("#9a9a93", box(1.1, 0.5, 1.1))])),
    ("height_steps", foot([("#84847d", box(2.6, 0.5, 1.4)),
                           ("#7c7c76", box(2.0, 0.5, 0.9))])),
    ("landmark_column", foot([
        ("#8f8f88", box(1.4, 0.35, 1.4)),
        ("#9a9a93", cylinder(0.5, 5.0, segments=8)),
        ("#a3a39c", box(1.5, 0.4, 1.5)),
    ])),
    ("prop_candle", foot([("#c9c4b4", cylinder(0.09, 0.5, segments=5)),
                          ("#d8b25a", cone(0.1, 0.28, segments=5))])),
    ("prop_urn", foot([("#8e8a80", ball(0.36, squash=1.1, lift=0.42))])),
    ("prop_grave", foot([("#8a8a83", box(0.75, 1.1, 0.2)),
                         ("#8a8a83", ball(0.37, squash=0.5, lift=1.05))])),
    ("prop_offering", foot([("#a09a8c", box(0.55, 0.22, 0.42))])),
]

# --- 6. topo_sky_interior -------------------------------------------------

SKY = [
    ("ground_cloud_a", [("#b9bcc2", quad(TILE))]),
    ("ground_cloud_b", [("#c3c6cb", quad(TILE))]),
    ("ground_light", [("#a9adb6", quad(TILE))]),
    ("ground_void", [("#8c9099", quad(TILE))]),
    ("height_cloudbank", [("#b5b8bd", ball(2.3, squash=0.4, lift=1.0))]),
    ("height_floating_rock", foot([
        ("#8b8f96", ball(1.5, squash=0.5, lift=1.5)),
        ("#7c8087", move(cone(0.9, 1.5, segments=6), 0.0, 0.0, 0.0)),
    ])),
    ("landmark_sky_arch", foot([
        ("#a9adb6", cylinder(0.26, 4.4, segments=6)),
        ("#a9adb6", move(cylinder(0.26, 4.4, segments=6), 3.0, 0.0, 0.0)),
        ("#b3b6be", move(box(3.8, 0.42, 0.62), 1.5, 4.4, 0.0)),
    ])),
    ("prop_ice_floe", foot([("#a4aeb8", box(1.1, 0.2, 0.9))])),
    ("prop_spire_small", [("#9aa0a8", cone(0.3, 1.05, segments=5))]),
    ("prop_banner", foot([("#8e93a0", cylinder(0.07, 2.0, segments=4)),
                          ("#a8aeb9", box(0.7, 0.9, 0.06))])),
    ("prop_feather", foot([("#b0b6c0", box(0.5, 0.06, 0.18))])),
]

# --- 7. topo_underwater_specialist ---------------------------------------

UNDERWATER = [
    ("ground_sand_a", [("#6d6a5a", quad(TILE))]),
    ("ground_sand_b", [("#767260", quad(TILE))]),
    ("ground_silt", [("#5c5b4f", quad(TILE))]),
    ("ground_vent", [("#4d4b45", quad(TILE))]),
    ("height_coral_bed", foot([
        ("#7d7060", ball(0.55, squash=0.9, lift=0.6)),
        ("#8a7a66", move(ball(0.4, squash=0.9, lift=0.9), 0.6, 0.0, 0.3)),
        ("#6f6455", move(ball(0.35, squash=0.9, lift=0.7), -0.55, 0.0, 0.35)),
    ])),
    ("height_vent", foot([("#5b5a52", cylinder(0.9, 2.2, segments=7)),
                          ("#4e4d47", move(cone(0.68, 0.9, segments=7), 0.0, 2.2, 0.0))])),
    ("landmark_vent_spire", foot([
        ("#55544d", cone(1.35, 5.4, segments=8)),
        ("#61605a", move(cone(0.8, 3.2, segments=6), 1.3, 0.0, 0.7)),
    ])),
    ("prop_kelp", foot([("#4a5f4c", box(0.14, 2.2, 0.05)),
                        ("#557057", move(box(0.12, 1.6, 0.05), 0.3, 0.0, 0.2)),
                        ("#40604a", move(box(0.12, 1.9, 0.05), -0.28, 0.0, 0.3))])),
    ("prop_anemone", foot([("#7d8a8f", ball(0.32, squash=0.8, lift=0.3)),
                           ("#8c9a9e", move(ball(0.22, squash=0.9, lift=0.55), 0.3, 0.0, 0.0))])),
    ("prop_shell", [("#a89d8a", ball(0.44, squash=0.5, lift=0.22))]),
    ("prop_tube", [("#6a6a5e", cylinder(0.13, 1.4, segments=5))]),
]

# --- 8. topo_dry_fire -----------------------------------------------------

FIRE = [
    ("ground_ash_a", [("#5a5049", quad(TILE))]),
    ("ground_ash_b", [("#655a51", quad(TILE))]),
    ("ground_crack", [("#4a4340", quad(TILE))]),
    ("ground_ember", [("#7a4a33", quad(TILE))]),
    ("height_ash_mound", [("#5c544c", ball(2.1, squash=0.4, lift=0.85))]),
    ("height_obsidian", [("#43403f", cone(1.0, 2.2, segments=6))]),
    ("landmark_volcano_vent", foot([
        ("#4a453f", cone(2.5, 2.3, segments=8)),
        ("#57504a", move(cone(1.7, 2.0, segments=7), 0.0, 2.2, 0.0)),
        ("#6b4433", move(cone(1.05, 1.6, segments=6), 0.0, 4.1, 0.0)),
    ])),
    ("prop_charred_stump", foot([("#3f362c", cylinder(0.36, 0.55, segments=6)),
                                 ("#332c25", cylinder(0.2, 0.35, segments=5))])),
    ("prop_ember_rock", [("#6e4230", ball(0.42, squash=0.7, lift=0.3))]),
    ("prop_bone", foot([("#a89f8c", box(1.1, 0.12, 0.16)),
                        ("#a89f8c", move(box(0.16, 0.12, 0.4), 0.45, 0.0, 0.0))])),
    ("prop_dead_shrub", foot([
        ("#4a4038", cylinder(0.06, 1.1, segments=4)),
        ("#544a40", move(cylinder(0.05, 0.8, segments=4), 0.28, 0.55, 0.1)),
        ("#544a40", move(cylinder(0.05, 0.7, segments=4), -0.24, 0.6, 0.18)),
    ])),
]

# --- 9. topo_frozen_crystal ----------------------------------------------

FROZEN = [
    ("ground_snow_a", [("#cfd3d8", quad(TILE))]),
    ("ground_snow_b", [("#d8dce1", quad(TILE))]),
    ("ground_ice", [("#aebfc9", quad(TILE))]),
    ("ground_frost", [("#9aa7b0", quad(TILE))]),
    ("height_snow_drift", [("#d2d6db", ball(2.2, squash=0.35, lift=0.75))]),
    ("height_ice_shard", [("#a9bcc8", cone(0.8, 2.6, segments=6))]),
    ("landmark_crystal_cluster", foot([
        ("#b6c9d4", cone(0.95, 6.4, segments=6)),
        ("#c2d2dc", move(cone(0.7, 4.6, segments=5), 1.4, 0.0, 0.6)),
        ("#a9bcc8", move(cone(0.5, 3.4, segments=5), -1.3, 0.0, 0.8)),
    ])),
    ("prop_icicle", [("#bccbd5", cone(0.16, 0.85, segments=5))]),
    ("prop_frozen_rock", [("#a8b0b5", ball(0.5, squash=0.72, lift=0.36))]),
    ("prop_snow_bush", [("#c8ccd1", ball(0.62, squash=0.7, lift=0.44))]),
    ("prop_crystal", [("#9fb6c2", cone(0.3, 1.15, segments=5))]),
]

# 이름 prefix 가 계약이다 (`FonsBiomeKit`) — 키트마다 11부품.
KITS = {
    "topo_natural_surface": NATURAL,
    "topo_wetland_water": WETLAND,
    "topo_rock_cavern_mountain": ROCK,
    "topo_urban_ruins": URBAN,
    "topo_sacred_sanctuary": SANCTUARY,
    "topo_sky_interior": SKY,
    "topo_underwater_specialist": UNDERWATER,
    "topo_dry_fire": FIRE,
    "topo_frozen_crystal": FROZEN,
}

FAMILIES = ("ground_", "height_", "landmark_", "prop_")


# --- 회전 기준축 계약 (2026-10-26) ----------------------------------------
#
# glTF 2.0 도 Godot 도 **에셋 정면을 +Z** 로 둔다(카메라·기본 노드의 전방만 -Z).
# 그래서 부품은 +Z 를 향해 세우고, 뒤로 밀리는 것(잔해·그림자·계단 뒤)은 모두 -Z 다.
# 대칭 부품만 있으면 이 계약이 코드에서 안 보인다 — 그래서 무너진 아치 하나를 비대칭으로 두고
# 여기서 잠근다. 사라지면 뷰가 정면을 모르는 채 돌리게 되므로 생성 단계에서 막는다.
AXIS_FRONT = 1.0                    # 정면 = +Z
AXIS_PART = "topo_urban_ruins"
AXIS_LANDMARK = "landmark_broken_arch"
AXIS_MIN_BIAS = 0.2                 # 무게중심이 정면 반대쪽으로 밀린 최소 폭 (유닛)


def bounds(pieces):
    """부품의 경계 — (x 최소·최대, y 최소·최대, z 최소·최대)."""
    points = [p for _, (pos, _, _) in pieces for p in pos]
    return (min(p[0] for p in points), max(p[0] for p in points),
            min(p[1] for p in points), max(p[1] for p in points),
            min(p[2] for p in points), max(p[2] for p in points))


def axis_check():
    """정면 +Z 계약 — 비대칭 부품이 그 방향을 보이는지 생성 단계에서 막는다."""
    parts = dict(KITS[AXIS_PART])
    if AXIS_LANDMARK not in parts:
        raise SystemExit("FAIL — 축 계약 부품이 없다: %s.%s" % (AXIS_PART, AXIS_LANDMARK))
    _, _, ymin, _, zmin, zmax = bounds(parts[AXIS_LANDMARK])
    center = (zmin + zmax) / 2.0
    if center * AXIS_FRONT > -AXIS_MIN_BIAS:
        raise SystemExit(
            "FAIL — %s.%s 의 무게중심 z=%.2f 가 정면(+Z) 쪽이다 — 잔해는 뒤(-Z)로 "
            "빠져야 뷰가 정면을 안다" % (AXIS_PART, AXIS_LANDMARK, center))
    if ymin < -0.001:
        raise SystemExit("FAIL — %s 의 바닥이 y=0 보다 낮다 (%.3f)" % (AXIS_LANDMARK, ymin))


# --- glTF 쓰기 ------------------------------------------------------------

class Gltf:
    """필요한 만큼만 쓰는 glTF 2.0 / GLB 기록기 — 노드 = 부품, 메시 = 재질별 primitive."""

    def __init__(self, generator="tools/gen_kit_glb.py"):
        self.generator = generator
        self.blob = bytearray()
        self.views = []
        self.accessors = []
        self.materials = []
        self._material_by_color = {}
        self.meshes = []
        self.nodes = []

    def _align(self):
        while len(self.blob) % 4:
            self.blob.append(0)

    def _view(self, data):
        self._align()
        self.views.append({"buffer": 0, "byteOffset": len(self.blob), "byteLength": len(data)})
        self.blob += data
        return len(self.views) - 1

    def _floats(self, values, kind, bounds=False):
        flat = [v for row in values for v in row]
        accessor = {"bufferView": self._view(struct.pack("<%df" % len(flat), *flat)),
                    "componentType": 5126, "count": len(values), "type": kind}
        if bounds:
            accessor["min"] = [round(min(row[i] for row in values), 6) for i in range(3)]
            accessor["max"] = [round(max(row[i] for row in values), 6) for i in range(3)]
        self.accessors.append(accessor)
        return len(self.accessors) - 1

    def material(self, hex_color):
        key = hex_color.lower()
        if key in self._material_by_color:
            return self._material_by_color[key]
        self.materials.append({
            "name": "mat_" + key.lstrip("#"),
            "doubleSided": False,
            "pbrMetallicRoughness": {"baseColorFactor": linear(key),
                                     "metallicFactor": 0.0, "roughnessFactor": 0.9},
        })
        self._material_by_color[key] = len(self.materials) - 1
        return self._material_by_color[key]

    def _ushorts(self, values):
        self.accessors.append({"bufferView": self._view(struct.pack("<%dH" % len(values), *values)),
                               "componentType": 5123, "count": len(values), "type": "SCALAR"})
        return len(self.accessors) - 1

    def part(self, name, pieces):
        primitives = []
        for hex_color, (pos, nrm, idx) in pieces:
            primitives.append({
                "attributes": {"POSITION": self._floats(pos, "VEC3", bounds=True),
                               "NORMAL": self._floats(nrm, "VEC3")},
                "indices": self._ushorts(idx),
                "material": self.material(hex_color),
                "mode": 4,
            })
        self.meshes.append({"name": name, "primitives": primitives})
        self.nodes.append({"name": name, "mesh": len(self.meshes) - 1})

    def pack(self):
        # BIN 청크 길이는 buffer.byteLength 와 정확히 같아야 한다 — 먼저 4바이트로 맞춘다.
        self._align()
        doc = {
            "asset": {"version": "2.0", "generator": self.generator},
            "scene": 0,
            "scenes": [{"nodes": list(range(len(self.nodes)))}],
            "nodes": self.nodes,
            "meshes": self.meshes,
            "materials": self.materials,
            "accessors": self.accessors,
            "bufferViews": self.views,
            "buffers": [{"byteLength": len(self.blob)}],
        }
        text = json.dumps(doc, ensure_ascii=False, separators=(",", ":")).encode("utf-8")
        text += b" " * (-len(text) % 4)
        total = 12 + 8 + len(text) + 8 + len(self.blob)
        head = struct.pack("<III", 0x46546C67, 2, total)
        chunks = (struct.pack("<II", len(text), 0x4E4F534A) + text
                  + struct.pack("<II", len(self.blob), 0x004E4942) + bytes(self.blob))
        return head + chunks


def families(parts):
    """부품 이름이 계약(4가족)을 지키는지 — 어긋나면 Godot 이 그 부품을 버린다."""
    counts = {prefix: 0 for prefix in FAMILIES}
    for name, _ in parts:
        for prefix in FAMILIES:
            if name.startswith(prefix):
                counts[prefix] += 1
                break
        else:
            raise SystemExit("FAIL — 부품 이름이 가족 prefix 밖: %s" % name)
    if counts["ground_"] != 4 or counts["height_"] != 2 or counts["landmark_"] != 1 \
            or counts["prop_"] != 4:
        raise SystemExit("FAIL — 부품 가족 수가 계약(4/2/1/4)과 다르다: %s" % counts)
    return counts


def build(parts):
    gltf = Gltf()
    for name, pieces in parts:
        gltf.part(name, pieces)
    return gltf.pack()


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--check", action="store_true", help="결과물이 생성물과 같은지만 본다")
    args = ap.parse_args()

    bad = 0
    axis_check()
    for kit in sorted(KITS):
        parts = KITS[kit]
        families(parts)
        data = build(parts)
        out = MODELS / ("%s.glb" % kit)
        print("%-30s 부품 %d (ground 4 · height 2 · landmark 1 · prop 4) · %d bytes"
              % (kit, len(parts), len(data)))
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
        print("결과물 %d = 생성물" % len(KITS))
        return 0
    print("씀 — %s (%d키트)" % (MODELS.relative_to(HERE), len(KITS)))
    return 0


if __name__ == "__main__":
    sys.exit(run("kitart", main))
