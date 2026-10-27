# PLAN — 2D 먼저, 3D는 나중에 (뷰 교체 구조)

작성 2026-10-17. 선행 문서: [DEV_PLAN.md](../dev/DEV_PLAN.md)(작업 순서) · [MIGRATION_PLAN.md](../../MIGRATION_PLAN.md)(이관/폐기 판정) · [GODOT_PORTING_MAP.md](../dev/GODOT_PORTING_MAP.md)(TS→GDScript 매핑).

이 문서는 **렌더링 계층 결정**만 다룬다. 게임 규칙·수치는 정본(원본 GDD·JSON)이 이긴다. 여기 없는 수치를 만들지 않는다.

---

## 1. 결정

**2D로 만든다. 3D는 같은 심 위에 뷰를 갈아 끼우는 방식으로 나중에 붙인다.**

근거 (자체 실측):

- 이 머신은 macOS 12.7.6 · Intel i5-6500 · iMac17,1이다. Godot은 `gl_compatibility` 고정이다 ([DEV_PLAN.md](../dev/DEV_PLAN.md) §4.2).
- 3D 최소 신(Phase 3)은 에셋 파이프라인(Blender → glTF → 임포트)까지 필요하다. 2D는 `_draw()`만으로 화면이 뜬다 — 코어 루프를 먼저 닫을 수 있다.
- 원본 웹판의 3D는 전부 **절차적 지오메트리**이고 `app/src/assets/`에는 이미지 3개뿐이다 (원본 대조). 즉 지금 잃는 3D 자산은 사실상 없다.

바꾸지 않는 것: `sim/`의 규칙·수치·데이터. 2D든 3D든 같은 `sim`을 쓴다.

---

## 2. 교체가 싸게 되는 이유 — 심/뷰 경계 4규칙

이 4개를 어기면 3D 전환이 "다시 만들기"가 된다. 어기면 게이트가 실패한다.

| # | 규칙 | 왜 |
|---|---|---|
| R1 | `scripts/sim/**`는 `Node`·`Node2D`·`Node3D`·`Control`을 **참조하지 않는다.** `RefCounted`만 쓴다 | 심을 씬 트리에서 떼어내야 테스트가 엔진 없이 돌고, 뷰를 통째로 갈 수 있다 |
| R2 | 심의 모든 위치는 **`Vector3`**다. `Vector2` 금지 (y = 높이) | 2D는 축을 골라 투영하고, 3D는 그대로 쓴다. 심이 2D 좌표를 알면 3D에서 전부 다시 계산해야 한다 |
| R3 | 심은 대상물을 **문자열 키**로만 가리킨다 (`"hero:knight"`, `"monster:wolf_t1"`). 경로·`Texture`·`Mesh`·`PackedScene` 금지 | 2D는 스프라이트, 3D는 메시로 같은 키를 각자 해석한다 |
| R4 | 2D/3D 선택 지점은 **`FonsViewFactory` 한 곳**뿐이다. 다른 코드가 `"2d"`/`"3d"`를 분기하지 않는다 | 전환 비용이 한 파일로 고정된다 |

추가로: 심은 **스냅샷(Dictionary)** 만 내보낸다. 뷰는 스냅샷을 읽고, 입력은 `intent` 시그널로 되돌린다. 노드 참조를 서로 넘기지 않는다.

```
sim/ (RefCounted, Vector3, 문자열 키)
   │  snapshot() -> Dictionary            ▲ intent(kind, payload)
   ▼                                      │
run.gd ── FonsViewFactory.create(mode) ──► view/view_2d | view/view_3d
```

---

## 3. 투영 규칙 (`FonsProjection`)

2D는 심의 `Vector3`를 화면 `Vector2`로 접는다. 축 선택은 상수 하나다.

| 평면 | 변환 | 쓰는 곳 |
|---|---|---|
| `Plane.XZ` (기본) | `(x, -z)` | 탑·영지·전장의 탑다운 |
| `Plane.XY` | `(x, -y)` | 횡스크롤 구간이 필요할 때 |

- `-z`, `-y`인 이유: Godot의 화면 y는 아래로 증가하고, 심의 z/y는 앞·위로 증가한다. 부호를 뒤집지 않으면 화면이 상하 반전된다.
- 스케일·원점은 뷰가 소유한다 (`pixels_per_unit`, `origin`). 심은 화면 단위를 모른다.
- 3D 뷰는 이 함수를 쓰지 않는다. `Vector3`를 그대로 월드 좌표로 쓴다.

---

## 4. 폴더 구조 (목표)

```
godot/
  core/               R1~R3 적용. RefCounted. 게임 규칙 (씬 없음).
  game/
    main/main.gd           조립 루트: 심 생성 → 뷰 생성 → 루프 (모드를 모른다)
    main/main.tscn         실행 진입점
    view/
      view_contract.gd     FonsView — mount/apply/unmount/intent 계약
      projection.gd        FonsProjection — 순수 함수
      view_factory.gd      모드 → PackedScene. 유일한 분기점
      view_2d/view_2d.tscn Node2D. _draw()로 엔티티를 그린다 (기본 모드)
      view_3d/view_3d.tscn Node3D. 같은 계약의 골격 — 기본 도형·지면·격자·카메라
      party_panel.gd       오른쪽 파티 칸 — 2D·3D가 같은 그림을 쓴다
  autoload/           전역 상태·데이터 로더
```

---

## 5. 작업 (태스크)

각 태스크는 파일·인터페이스·검증 명령을 명시한다. 완료 조건은 **명령 실행 결과**다.

### Task 1 — 투영 순수 함수

**Files:** Create `godot/game/view/projection.gd` · Test `godot/tests/unit/test_projection.gd`

**Interfaces:**
- `class_name FonsProjection extends RefCounted`
- `enum Plane { XZ, XY }`
- `static func to_screen(p: Vector3, plane: int = Plane.XZ) -> Vector2`

**Steps:**
1. 실패 테스트를 쓴다: XZ에서 `(1,2,3) → (1,-3)`, XY에서 `(1,2,3) → (1,-2)`.
2. `./tools/test_godot.sh` 실행 → 실패 확인 (`FonsProjection` 미정의).
3. 함수를 최소로 구현한다.
4. 다시 실행 → 통과.

### Task 2 — 뷰 계약

**Files:** Create `godot/game/view/view_contract.gd`

**Interfaces:**
- `class_name FonsView extends Node`
- `signal intent(kind: StringName, payload: Dictionary)`
- `func mount(snapshot: Dictionary) -> void` · `func apply(snapshot: Dictionary) -> void` · `func unmount() -> void`
- `func is_mounted() -> bool`
- 기본 구현은 `push_error("FonsView: <method> not implemented")` — 조용히 통과하지 않는다.

**Steps:** 계약만 만든다. 테스트는 Task 4에서 2D 구현으로 검증한다.

### Task 3 — 팩토리 (유일한 분기점)

**Files:** Create `godot/game/view/view_factory.gd` · Test `godot/tests/unit/test_view_factory.gd`

**Interfaces:**
- `class_name FonsViewFactory extends RefCounted`
- `const SETTING := "fons/view_mode"`
- `const DEFAULT_MODE := "2d"`
- `static func scene_path(mode: String) -> String` — 모르는 모드는 `""`
- `static func create(mode: String = "") -> FonsView` — 빈 인자면 `ProjectSettings` 값, 없으면 `2d`. 씬이 없으면 `null`
- `static func available_modes() -> PackedStringArray`

**Steps:**
1. 테스트: `scene_path("2d")`가 존재하는 경로, `scene_path("9d")`가 `""`, `create("3d")`가 `null`(아직 없음), `create("2d")`가 `FonsView` 인스턴스.
2. 실패 확인 → 구현 → 통과.

### Task 4 — 2D 뷰

**Files:** Create `godot/game/view/view_2d/view_2d.gd`, `.../view_2d.tscn` · Test `godot/tests/unit/test_view_2d.gd`

**Interfaces:**
- `class_name FonsView2D extends FonsView`
- `@export var pixels_per_unit: float = 48.0`
- `@export var plane: FonsProjection.Plane = FonsProjection.Plane.XZ`
- `func entity_count() -> int`
- `mount/apply`는 스냅샷의 `entities` 배열을 받아 `queue_redraw()`

**스냅샷 스키마 (고정):**

```gdscript
{
  "tick": int,
  "entities": [
    { "id": StringName, "asset": String, "pos": Vector3, "size": Vector2, "kind": String }
  ]
}
```

- `id`는 안정적이어야 한다(재사용 금지). `asset`은 문자열 키(R3).
- 뷰는 `id`로 노드를 재사용하고, 사라진 `id`의 노드를 지운다.

**Steps:**
1. 테스트: 2개 엔티티 `mount` → `entity_count() == 2`, 1개로 `apply` → `1`, `unmount()` → `0`.
2. 실패 확인 → 구현 → 통과.

### Task 5 — 조립 루트 + 실행 씬

**Files:** Create `godot/game/main/main.gd`, `godot/game/main/main.tscn` · Modify `godot/project.godot` (`run/main_scene`, `fons/view_mode`)

**Steps:**
1. `run.gd`: 심 스냅샷 1개를 만들고(데모 3개 엔티티), `FonsViewFactory.create()`로 뷰를 붙이고, 1초에 1틱씩 `apply`한다.
2. `godot --headless --path godot --quit-after 120` → exit 0, 에러 0건.
3. 창 띄워 눈으로 확인: `godot --path godot`.

### Task 6 — 3D 자리 (비워 둔다)

**Files:** Create `godot/game/view/view_3d/.gitkeep`

3D 착수 시 `view_3d.tscn` + `view_3d.gd`만 추가하면 `FonsViewFactory`가 자동으로 인식한다. `run.gd`·`sim/`은 손대지 않는다.

---

## 6. 3D로 넘어갈 때 실제로 바뀌는 것

| 바뀐다 | 안 바뀐다 |
|---|---|
| `view/view_3d/*` 신규 작성 | `sim/` 전체 |
| `ProjectSettings fons/view_mode = "3d"` | `run.gd` 조립 순서 |
| 엔티티 `asset` 키 → 메시 매핑 테이블 | 스냅샷 스키마 |
| 카메라·조명 | GUT 시뮬 테스트 전부 |

`FonsViewFactory`에 3D 경로를 넣는 순간 전환이 끝난다.

> 2026-10-22: 3D 골격을 추가했다 (`view_3d/`). 기본 모드는 여전히 `2d` — 연출·패널이 2D 쪽에 먼저 있다.
> 3D는 `FonsViewFactory.create("3d")` 또는 `fons/view_mode="3d"` 로 켜서 나란히 본다.
>
> 2026-10-22: 3D 에 에셋 키→메시 자리(`register_asset` — 등록이 없으면 종류별 도형)와
> HP 바(`FonsHpBar` — 2D 와 같은 그림)를 붙였다.
>
> 2026-10-22: 필드 스냅샷도 영웅마다 `asset` 키(`hero:<직업 id>`)를 싣는다. 3D 는 그 키들로
> 색을 나눠 주므로 다섯이 같은 모습이 아니다. 남은 차이는 실제 자산과 카메라 추적뿐이다.
>
> 2026-10-25: 기본 뷰를 `3d` 로 올렸다(`project.godot` 의 `fons/view_mode`). "2D 먼저" 는 **착수 순서**였고
> 그 순서는 끝났다 — 2D 뷰는 `FonsViewFactory.create("2d")` 폴백으로 남는다. ADR 0003 에도 같은 날 개정 절을 붙였다.
>
> 2026-10-25: 카메라 추적도 끝났다 — 정사영 탑뷰를 **3인칭 추적**(원근 50°·거리 4.2·기울기 18°)으로 바꿨다.
> 위 "남은 차이는 실제 자산과 카메라 추적" 중 카메라 쪽은 해소됐다. 구도·조작은 [ART_BIBLE](../art/ART_BIBLE.md) 카메라 절.

---

## 7. 검증

| 명령 | 통과 기준 |
|---|---|
| `./tools/test_godot.sh` | 전부 통과 · 0건 실행이면 실패 |
| `godot --headless --path godot --quit-after 120` | exit 0 · 에러 0건 |
| `./.venv/bin/python tools/gate_all.py` | `GATE ALL OK` |

Godot 출력을 파이프로 거를 때는 `set -o pipefail`을 쓴다. 종료 코드가 묻히면 거짓 통과다.
