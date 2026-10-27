# godot/assets — 런타임 에셋

게임이 **직접 로드하는** 파일만 여기에 둔다. 편집 원본(PSD·Aseprite·Blender·DAW 세션)은
레포 루트의 [art-source/](../../art-source/README.md) · [audio-source/](../../audio-source/README.md) 에 둔다.

이 분리가 중요한 이유: Godot은 프로젝트 폴더 안의 모든 파일을 임포트 대상으로 훑는다.
원본 소스를 `godot/` 안에 넣으면 임포트 캐시가 부풀고, `.gdignore` 로 숨기면 이번엔
`load()` 가 불가능해진다. 원본은 **엔진 밖**에 두는 것이 가장 단순하다.

## 폴더

에셋이 실제로 생길 때 만든다. 빈 폴더를 미리 깔지 않는다.

```
assets/
  art/
    sprites/      # 캐릭터·몬스터 낱장 (PNG)
    tilesets/     # 타일셋 + .tres (TileSet)
    ui/           # 9-slice 패널, 아이콘
    vfx/          # 파티클 텍스처
    models/       # 3D 지형 키트 · 생물 몸통 (.glb) — tools/gen_kit_glb.py · tools/gen_monster_glb.py
  audio/
    music/        # OGG Vorbis, 루프 지점 포함
    sfx/          # OGG Vorbis
  fonts/          # .ttf + 라이선스 파일 (OFL 등)
  data/           # 여기 아님 — 정본 JSON 은 godot/data/ 에 있다
```

- `godot/data/` 는 `tools/sync_data.py` 가 채우는 **정본 JSON** 자리다. 에셋과 섞지 않는다.
- 씬 하나에서만 쓰는 에셋은 그 씬 폴더에 같이 두는 편이 낫다
  (예: `game/ui/title/` 전용 배경). `assets/` 는 **여러 씬이 공유하는 것**만 둔다.

## 규칙

1. **이름은 snake_case, 확장자 소문자.** Windows·Linux 대소문자 차이로 깨지는 것을 막는다.
2. **`.import` 파일은 커밋한다.** 임포트 설정(필터·압축·루프)이 거기 들어 있다.
   `.godot/` 은 캐시이므로 커밋하지 않는다.
3. **파일 경로를 코드에 박지 않는다.** 2D 뷰는 스냅샷의 `asset` 문자열 키(`"hero:knight"`)를
   받아 그리는 구조다([game/view/view_2d/view_2d.gd](../game/view/view_2d/view_2d.gd)).
   키 → 파일 매핑표를 한 곳에 두고, 에셋이 바뀌어도 로직을 고치지 않는다.
4. **포맷은 임포트 비용이 낮은 쪽으로.** 이미지는 PNG, 오디오는 OGG Vorbis
   (`ffmpeg -c:a libvorbis -q:a 5`) — 도구 버전은 [SETUP.md](../../SETUP.md).
5. **라이선스를 남긴다.** 외부 폰트·사운드·스프라이트는 출처와 라이선스를
   `godot/assets/CREDITS.md` 에 적는다. 파일만 받아 두면 배포 전에 권리 확인이 불가능해진다.

## 아직 없는 것

스프라이트·오디오·폰트는 **아직 없다.** 지금 2D 뷰는 `kind` 별 색 사각형으로 그린다.
첫 스프라이트가 들어오는 시점에 `sprites/` 와 매핑표를 함께 만든다.

3D 는 지형 키트 **9벌**이 있다 — `data/biome_assets.json` 의 `topologyKit` 9종이 그대로 파일 이름이고
(`art/models/<kit>.glb`, 26바이옴이 나눠 쓴다), 부품 이름 접두사가 계약이다
(`ground_`·`height_`·`landmark_`·`prop_`). 배치는 `game/view/view_3d/biome_kit.gd` 가 진다.
결과물은 [`tools/gen_kit_glb.py`](../../tools/gen_kit_glb.py) 가 쓰고 `--check` 로 드리프트를 막는다.
전투몬 몸통은 **3벌**이 있다 — `creature_heavy` · `creature_small` · `creature_odd`
(`art/models/creature_<band>.glb`). `data/monster_assets.json` 의 `band` 가 어느 벌을 쓸지 정하고,
`monsters.json` 의 `element` · `tier` 가 색과 크기를 만든다
([monster_body.gd](../game/view/view_3d/monster_body.gd)). 생성기는
[`tools/gen_monster_glb.py`](../../tools/gen_monster_glb.py) 이고, 드리프트는 게이트 `creatureart` 가 막는다.
부품 이름 다섯(`body_hide` · `body_belly` · `skin_limb` · `horn_spike` · `eye_dark`)이 계약이다 —
틴트는 몸통·다리 부품만 바꾸므로 뿔과 눈은 구운 색을 지킨다.

영웅 몸통도 **3벌**이다 — `hero_guard` · `hero_scout` · `hero_mystic`
(`art/models/hero_<band>.glb`). 생성기는 [`tools/gen_hero_glb.py`](../../tools/gen_hero_glb.py),
드리프트는 게이트 `heroart` 가 막고, 런타임 해석은
[hero_body.gd](../game/view/view_3d/hero_body.gd) 이 진다. 어느 직업이 어느 벌을 입는지는
`data/hero_assets.json` 이 정한다 — 생성기 [`tools/gen_hero_assets.py`](../../tools/gen_hero_assets.py),
드리프트는 게이트 `heroassets` 가 막는다. 부품 다섯(`body_hide` · `skin_limb` ·
`gear_metal` · `gear_shine` · `eye_dark`)이 계약이고 틴트는 `body_`·`skin_`·`head_` 만 바꾼다.
