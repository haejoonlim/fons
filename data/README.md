# data/ — 설정 SSOT 복사본

원본: `soul-commander/unity/Assets/Resources/Data/*.json` — **원본 미검증** (레포 비공개, 이 머신에서 열람 불가)

## 이 폴더의 현재 상태 (중요)

- **`manifest.json`은 추측 목록이다.** 한 번도 원본 트리와 대조된 적이 없고, 파일 자체의 `notes` 필드가 그렇게 인정하고 있다. 작성 시점의 디렉터리 열람 기억으로 만든 목록이다.
- 그래서 **첫 작업은 복사가 아니라 diff다.** 원본에 접근한 뒤:
  ```bash
  ls ../soul-commander/unity/Assets/Resources/Data/*.json | xargs -n1 basename | sort > /tmp/original_data.txt
  python3 -c "import json;print('\n'.join(sorted(json.load(open('data/manifest.json'))['files'])))" > /tmp/manifest_data.txt
  diff /tmp/original_data.txt /tmp/manifest_data.txt
  ```
  차이가 0이 될 때까지 `manifest.json`을 고친다. 그 전에 `sync_data.py`를 돌리면 **없는 파일은 조용히 건너뛰고 "missing" 한 줄만 찍고 끝난다** (exit 0).
- `data/`에 지금 실제 JSON 파일은 **하나도 없다.** 이 폴더에는 `README.md`와 `manifest.json`만 있다.

## 규칙

- 손으로 편집 금지. 원본에서 `tools/sync_data.py`로만 가져온다.
- `.meta`, `.gitkeep`은 가져오지 않는다.
- 밸런스 변경은 GDD 개정 + 별도 커밋으로만 한다.
- `godot/data/`는 같은 내용의 Godot 런타임용 복사본이다 (`sync_data.py --dst godot/data`).

## 가져올 파일 목록 (전부 원본 미검증)

`manifest.json` 참조. 현재 들어 있는 이름:
`ambient.json`, `biomes.json`, `ecology_codex.json`, `ecology_energy_channels.json`,
`elemental_affinity.json`, `elemental_matrix.json`, `equipment.json`, `estate.json`,
`fusion_pairs.json`, `job_tree.json`, `monster_personality.json`, `monsters.json`,
`races.json`, `skills_catalog.json`, `synergy.json`, `estate_web.json`, `state.json`, `game_const.json`

이 중 실제로 원본에 존재하는 것이 몇 개인지는 **아직 모른다.** 대조 후 확정한다.
(`state.json`, `game_const.json`, `estate_web.json`처럼 이름이 저장/런타임 상태를 연상시키는 항목은 설정 파일이 아닐 가능성이 있어 대조 때 특히 확인한다. 이 세 파일은 실제 존재 여부도 아직 미확인이다.)
