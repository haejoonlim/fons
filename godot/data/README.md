# godot/data/ — 런타임용 설정 사본

`godot/scripts/autoload/data_loader.gd`는 `res://data`(= 이 폴더)를 읽는다.
이 폴더가 없으면 DataLoader는 `push_error`만 하고 빈 Dictionary를 돌려준다.

내용은 손으로 넣지 않는다. 원본 저장소의 JSON을 `data/`로 가져온 뒤
`tools/sync_data.py`로 이 폴더에 복사한다 (수동 복붙 금지).

## 현재 상태 (2026-10-16)

- JSON 파일 **0개**. 원본 저장소 접근이 막혀 있어 아직 채우지 못했다.
- `data/manifest.json`의 파일 목록은 **원본 미검증** 추정 목록이다.
  원본 트리와 대조하기 전에는 이 목록을 믿고 복사하지 말 것.

자세한 규칙은 [../data/README.md](../../data/README.md) 참고.
