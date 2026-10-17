# PROMPT — 폰즈 2D-first 작업 지시문

작업을 시작하는 에이전트에게 그대로 붙여넣는 프롬프트다.
구조의 근거는 [PLAN_2D_FIRST.md](PLAN_2D_FIRST.md), 작업 순서는 [DEV_PLAN.md](../dev/DEV_PLAN.md).

---

```
너는 ~/Desktop/폰즈 에서 FONS(폰즈) Godot 4.7 프로젝트를 작업한다.
Unity 원본은 ~/soul-commander 에 있다(읽기 전용). 렌더링은 2D 먼저, 3D는 나중에 같은 심 위에 갈아 끼운다.

읽어라: docs/design/PLAN_2D_FIRST.md, docs/dev/DEV_PLAN.md, docs/dev/GODOT_PORTING_MAP.md, MIGRATION_PLAN.md.
수치의 정본은 docs/original/ 이다. 거기 없는 값을 만들지 마라.

지켜야 하는 경계 4규칙 (어기면 3D 전환이 재작업이 된다):
R1 godot/core/** 은 Node/Node2D/Node3D/Control 을 절대 참조하지 않는다. RefCounted 만 쓴다.
R2 심의 위치는 전부 Vector3 다(y=높이). 심 안에 Vector2 를 쓰지 않는다.
R3 심은 대상물을 문자열 키로만 가리킨다("hero:knight"). 경로·Texture·Mesh·PackedScene 금지.
R4 2D/3D 선택 지점은 FonsViewFactory 한 곳뿐이다. 다른 코드가 "2d"/"3d" 를 분기하지 않는다.

심은 스냅샷(Dictionary)만 내보내고, 뷰는 스냅샷을 읽고 입력은 intent 시그널로 되돌린다.
스냅샷 스키마는 고정이다:
  { "tick": int, "entities": [ { "id": StringName, "asset": String, "pos": Vector3, "size": Vector2, "kind": String } ] }
"id" 는 안정적이어야 한다(재사용 금지). 뷰는 id 로 노드를 재사용하고 사라진 id 를 지운다.

작업 규칙:
- 새 모듈은 "전역 상수 → 순수 함수 → GUT 테스트" 순서로 만든다.
- 테스트를 먼저 쓰고, 실패를 확인하고, 최소 구현으로 통과시킨다.
- JSON 은 godot/autoload/data_loader.gd 로만 읽는다. 직접 FileAccess 금지.
- 검증은 명령의 종료 코드로만 판정한다:
    ./tools/test_godot.sh                       (전부 통과, 0건 실행이면 실패)
    godot --headless --path godot --quit-after 120
    ./.venv/bin/python tools/gate_all.py
- Godot 출력을 파이프로 거를 때는 set -o pipefail 을 쓴다.
- 3D 뷰는 아직 없다. view_3d/ 를 채우는 순간 FonsViewFactory 가 자동 인식한다. 그 전까지 run.gd 와 sim/ 은 3D를 몰라야 한다.
- 완료 보고에는 실행한 명령과 그 출력을 붙인다. 실행하지 않은 검증을 통과라고 쓰지 않는다.
```

---

## 이 프롬프트를 쓰는 시점

| 상황 | 같이 읽을 것 |
|---|---|
| 시뮬 모듈 포팅 (combat/party/estate/tower) | `docs/dev/GODOT_PORTING_MAP.md` §2 표 |
| 화면 붙이기 | `docs/design/PLAN_2D_FIRST.md` §3 투영 규칙 |
| 3D 착수 | `docs/design/PLAN_2D_FIRST.md` §6 "바뀌는 것 / 안 바뀌는 것" |
| 수치가 의심될 때 | `docs/original/01_확정_규칙.md` — 원본 대조값만 인용 |

## 하지 말아야 하는 것

- `sim/`에서 `get_node`, `@onready`, `Node2D` 사용 — R1 위반.
- 심에 `Vector2` 위치 저장 — R2 위반. 2D 좌표가 필요하면 뷰가 투영한다.
- 뷰가 JSON 파일 경로나 에셋 경로를 직접 들고 다니기 — R3 위반. 키만 주고받는다.
- `run.gd`나 심 안에서 `if mode == "3d"` — R4 위반.
- 숫자를 코드에 박기 전에 `docs/original/` 확인 생략.
