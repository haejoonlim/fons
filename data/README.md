# data/ — 원본 데이터 복사본

원본: 원본 저장소의 데이터 폴더 — 비공개 레포였지만 **2026-10-17에 클론해서 읽었다** (원본 대조).
근거 기록은 [docs/original/03_데이터_영지_탑.md](../docs/original/03_데이터_영지_탑.md)에 있다 (원본 대조).

## 현재 상태

- `manifest.json`은 **대조를 마친 확정 목록**이다 — 2026-10-17 원본 트리와 전수 비교했고 **17종**이다 (원본 대조).
- 대조 전의 목록은 추정이었고 실제와 달랐다: 없던 파일 3개(`estate_web.json`·`state.json`·`game_const.json`)가 들어 있고,
  있던 파일 2개(`scenes.json`·`world_laws.json`)가 빠져 있었다 (원본 대조).
- 2026-10-17에 복사를 실행했다: 이 폴더에 데이터 **17종**과 `manifest.json`이 있다 (자체 실측).

## 가져올 파일 — 17종 (원본 대조)

```
ambient.json                  biomes.json                ecology_codex.json
ecology_energy_channels.json  elemental_affinity.json    elemental_matrix.json
equipment.json                estate.json                fusion_pairs.json
job_tree.json                 monster_personality.json   monsters.json
races.json                    scenes.json                skills_catalog.json
synergy.json                  world_laws.json
```

## 정본은 어디인가 (원본 대조)

| 파일 | 성격 |
|---|---|
| `skills_catalog.json` · `fusion_pairs.json` | 원본 스크립트가 **한글 키 정본에서 생성**한다 — 정본은 `design-docs/_tools/`에 있고, 생성기가 런타임 JSON(snake_case)을 만든다 (원본 대조) |
| 나머지 15종 | 원본에서 **직접 저작**한 파일이다 — 생성물이 아니다 (원본 대조) |

- 어느 쪽이든 **이관 원본은 원본 저장소의 데이터 폴더 하나**다. 정본 경로와 재생성 명령은 [03_데이터_영지_탑.md](../docs/original/03_데이터_영지_탑.md) §1에 적어 뒀다 (원본 대조).
- 원본에서 이 폴더의 JSON을 손으로 고치면 다음 동기화에 덮인다 — 수치 변경은 정본 문서·생성기에서 한다 (원본 대조).

## 규칙

- 손으로 편집 금지. `tools/sync_data.py`로만 가져온다.
- `.meta`, `.gitkeep`은 가져오지 않는다 — Unity 전용 부산물이다.
- 밸런스 변경은 정본(GDD) 개정 + 별도 커밋으로만 한다.
- `godot/data/`는 같은 내용의 Godot 런타임용 복사본이다 (`--dst godot/data`).

## 복사 방법

> **상태 (2026-10-17):** 이관 완료 — 17종이 여기와 `godot/data/` 에 있다 (자체 실측).
> 원본 원본 에셋 트리는 그 뒤 로컬에서 삭제됐다. 아래 명령은 원본이 다시 생겼을 때의 절차다.
> 지금 이 폴더가 **유일한 정본 사본**이므로 손으로 지우지 말 것.

```bash
./.venv/bin/python tools/sync_data.py --src <원본 데이터 폴더> --dst data
./.venv/bin/python tools/sync_data.py --src <원본 데이터 폴더> --dst godot/data
```

- `sync_data.py`는 이제 **없는 파일이 하나라도 있으면 exit 1**이다. 성공하면 `SYNC OK: <대상>`을 찍는다 (자체 실측).
- 이전 동작은 없는 파일을 건너뛰고 "missing" 한 줄만 찍은 뒤 **exit 0으로 끝났다** — 원본 이름이 바뀌면 데이터가 조용히 빠진 채 게이트가 통과하는 실패 모드였다 (원본 대조).
- 일부만 확인하려면 `--allow-missing`을 명시한다. 그때는 `missing` 목록을 반드시 읽는다 (자체 실측).

## 다시 대조하고 싶을 때

```bash
# 원본이 있을 때만. 지금은 원본 유니티 트리가 없다 (2026-10-17 로컬 삭제, 자체 실측).
ls <원본 데이터 폴더>/*.json | xargs -n1 basename | sort > /tmp/original_data.txt
python3 -c "import json;print('\n'.join(sorted(json.load(open('data/manifest.json'))['files'])))" > /tmp/manifest_data.txt
diff /tmp/original_data.txt /tmp/manifest_data.txt
```

## 원본이 스스로 어긋나는 곳

원본 저장소 안에서도 런타임 JSON 개수 표기가 갈린다 — `unity/README.md`는 **10종**, `unity/PORTING_MAP.md`는 **13개**로 적었고 (둘 다 원본 대조),
실제 폴더에는 **17종**이 있다 (원본 대조). 어느 문서를 믿을지 고민할 필요는 없다: **폴더 실측이 정본**이고 manifest도 그 값으로 맞췄다 (원본 대조).
