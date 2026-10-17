# art-source — 아트 편집 원본

**Godot이 읽지 않는** 파일을 둔다. 게임에 들어가는 것은 `godot/assets/art/` 로 내보낸 결과물이다.

```
art-source/
  characters/     # .aseprite, .psd, .blend
  monsters/
  environment/
  ui/
  export/         # 내보내기 스크립트·설정 (사람이 읽는 것)
```

## 왜 나누나

- Godot은 프로젝트 폴더 안의 파일을 전부 임포트한다. 100MB PSD를 `godot/` 안에 두면
  에디터가 느려지고, `.gitignore` 로 숨겨도 임포트 대상 스캔에서는 빠지지 않는다.
- 원본과 결과물의 **책임이 다르다.** 원본은 다시 뽑을 수 있어야 하고, 결과물은 게임이 쓰는 계약이다.
- 원본을 잃으면 결과물만 남아 수정이 불가능해진다. 그래서 원본은 **버전 관리 대상**이다.

## 규칙

1. 원본 → 결과물 경로를 **스크립트로 고정**한다. 손으로 내보내면 다음 사람이 같은 결과를 못 만든다.
   - Blender: `blender --background --python art-source/export/<name>.py`
   - Aseprite: `aseprite -b <file>.aseprite --sheet <out>.png --data <out>.json`
2. 결과물 이름은 **원본과 같게** 유지한다 (`hero_knight.aseprite` → `hero_knight.png`).
   이름이 갈라지면 어느 원본에서 나왔는지 추적이 끊긴다.
3. 큰 바이너리(수십 MB 이상)는 Git LFS 로 추적한다. `git lfs install` 은 이 머신에 이미 되어 있다
   ([SETUP.md](../SETUP.md)). LFS 는 첫 커밋 전에 걸어야 하고, 나중에 옮기면 히스토리 재작성이 필요하다.
4. 팔레트·해상도·픽셀 밀도 같은 시각 규칙은 [docs/art/ART_BIBLE.md](../docs/art/ART_BIBLE.md) 가 정본이다.
   여기에 규칙을 복제하지 않는다.

## 아직 없는 것

원본 파일은 **하나도 없다.** 이 폴더는 규칙과 자리만 잡아 둔 상태다.
첫 캐릭터 원본이 들어올 때 `characters/` 와 `export/` 를 만든다.
