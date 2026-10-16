# godot/data/ — 런타임용 설정 사본

`godot/scripts/autoload/data_loader.gd`는 `res://data`(= 이 폴더)를 읽는다.
이 폴더가 없거나 비어 있으면 DataLoader는 `push_error`만 하고 빈 Dictionary를 돌려준다.

내용은 손으로 넣지 않는다. 원본 저장소의 JSON을 `data/`로 가져온 뒤
`tools/sync_data.py`로 이 폴더에 복사한다 (수동 복붙 금지).

## 현재 상태 (2026-10-17)

- JSON **17종**이 들어와 있다 — 원본 `unity/Assets/Resources/Data/`의 확정 목록 그대로다 (자체 실측).
- 목록 근거는 [manifest.json](../../data/manifest.json)이고, 그 목록은 원본 트리와 전수 대조한 값이다 (원본 대조).
- 이 폴더의 파일을 고치지 않는다. 원본이 바뀌면 `tools/sync_data.py`를 다시 돌린다.
- 누락은 조용히 넘어가지 않는다: `tools/check_docs.py`가 `data/`의 17종을 검사하고,
  `tools/sync_data.py`는 없는 파일이 하나라도 있으면 exit 1로 끝난다 (자체 실측).

자세한 규칙은 [../data/README.md](../data/README.md) 참고.
