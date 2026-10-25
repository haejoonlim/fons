#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""풀바다(슬롯 1) 파일럿 지형 키트 → `godot/assets/art/models/topo_natural_surface.glb`.

무엇을 만드나
-------------
`topo_natural_surface` 키트(바이옴 3곳: 풀바다·뿌리숲·포식밀림)의 첫 실제 메시.
부품 이름 prefix 가 Godot 쪽 계약이다(`FonsBiomeKit`):

| prefix | 부품 | 수 |
|---|---|---|
| `ground_` | 5×5 바닥 타일 4색 | 4 |
| `height_` | 둔덕·바위 노두 | 2 |
| `landmark_` | 외로운 나무 | 1 |
| `prop_` | 덤불·돌·꽃·그루터기 | 4 |

스타일은 아직 미정이다([docs/art/ART_BIBLE.md] §미정). 그래서 텍스처 없이 색만 다른
로우폴리다 — 스타일이 정해지면 재질만 갈아 끼운다.

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
OUT = HERE / "godot" / "assets" / "art" / "models" / "topo_natural_surface.glb"

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


# 이름 prefix 가 계약이다 (`FonsBiomeKit`).
PARTS = [
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


# --- glTF 쓰기 ------------------------------------------------------------

class Gltf:
    """필요한 만큼만 쓰는 glTF 2.0 / GLB 기록기 — 노드 = 부품, 메시 = 재질별 primitive."""

    def __init__(self):
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
            "asset": {"version": "2.0", "generator": "tools/gen_kit_glb.py"},
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


def build():
    gltf = Gltf()
    for name, pieces in PARTS:
        gltf.part(name, pieces)
    return gltf.pack()


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--check", action="store_true", help="결과물이 생성물과 같은지만 본다")
    args = ap.parse_args()

    data = build()
    print("kit topo_natural_surface — 부품 %d (ground 4 · height 2 · landmark 1 · prop 4) · %d bytes"
          % (len(PARTS), len(data)))

    if args.check:
        if not OUT.exists():
            print("[ FAIL ] 없음 — %s (생성기로 뽑는다)" % OUT.relative_to(HERE))
            return 1
        if OUT.read_bytes() != data:
            print("[ FAIL ] 다름 — %s (정본은 이 스크립트다)" % OUT.relative_to(HERE))
            return 1
        print("결과물 = 생성물")
        return 0

    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_bytes(data)
    print("씀 — %s" % OUT.relative_to(HERE))
    return 0


if __name__ == "__main__":
    sys.exit(run("kitart", main))
