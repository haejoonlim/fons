# 폴더 구조 리서치 — 무엇을 근거로 이렇게 짰나

이 문서는 [ADR 0001](../adr/0001-repo-layout.md) 의 배경 자료다. 구조를 다시 논의할 때 여기서 시작한다.

## 1. Godot 공식 문서가 말하는 것

**Godot에는 표준 폴더 구조가 없다.** 공식 "Project organization" 문서는 프로젝트 구조를 강제하지 않으며,
파일시스템을 그대로 쓴다고 설명한다. 그래서 "정답 구조"를 찾는 대신 **규모가 커져도 유지되는 기준**을 골라야 한다.
([Project organization](https://docs.godotengine.org/en/stable/tutorials/best_practices/project_organization.html))

공식 문서에서 가져온 판단 기준:

| 문서 | 우리가 쓴 결론 |
|---|---|
| Project organization | 공용은 `shared`·`data`, 전용은 해당 기능 폴더. 폴더명은 snake_case |
| Scenes versus scripts | 씬과 스크립트를 붙여야 하는 규칙은 없다 → **전용 스크립트는 씬 옆에** 둔다 |
| Scene organization | 씬은 자기에게 필요한 것을 안에 두고, 부모가 자식·리소스 연결을 관리 |
| Singletons (Autoload) | Autoload 등록은 Project Settings 에서 한다. 폴더 이름은 관례일 뿐 |
| Autoloads versus regular nodes | 전역 접근은 디버깅을 어렵게 한다 → 정말 전역이어야 하는 것만 Autoload |
| Import process | 원본은 프로젝트 안, 임포트 결과는 `.godot/imported/`. **`.import` 는 커밋, `.godot/` 은 제외** |
| Version control | `.godot/`·`*.translation` 제외. 원본 에셋을 통째로 무시하지 말 것 |
| ResourceLoader / FileAccess | JSON·CSV 같은 일반 텍스트는 `FileAccess`, `.tres`·씬은 `ResourceLoader` |

`.gdignore` 는 `.gitignore` 와 다르다. 해당 폴더는 에디터에서 숨고 `load()` 도 안 되며 익스포트에도 빠진다.
그래서 **Godot이 써야 할 에셋을 `.gdignore` 로 숨기면 안 된다** — 원본 소스는 아예 프로젝트 밖에 두는 쪽을 택했다.

## 2. 실제 프로젝트는 어떻게 생겼나

### Godot 공식 TPS 데모

`scenes/`·`scripts/`·`assets/` 로 종류별 분리하지 **않는다**. `main/`(씬+스크립트), `player/`(씬+스크립트+`model/`+`textures/`+`audio/`),
`level/`, `door/` 처럼 **기능 폴더 안에 씬과 전용 리소스를 같이** 둔다. 공용 효과만 `effects_shared/` 로 뺀다.
([저장소](https://github.com/godotengine/tps-demo))

우리 `game/view/view_2d/`(씬+스크립트), `game/main/`(씬+스크립트)가 이 방식이다.

### 공식 데모 저장소

작은 프로젝트는 씬·스크립트를 프로젝트 루트에 두고 `art/`·`fonts/` 만 나눈다.
([저장소](https://github.com/godotengine/godot-demo-projects)) — 규모가 작을 때 폴더를 미리 깔지 않는 근거로 썼다.
그래서 `godot/assets/` 에는 지금 **규칙 문서만** 있고 빈 하위 폴더를 만들지 않았다.

### Mindustry (상용 배포된 오픈소스 게임)

`core/assets/`(런타임)와 `core/assets-raw/`(편집·생성용 원본)를 분리하고, `tools/`·`tests/` 를 별도 모듈로 둔다.
번역은 `core/assets/bundles/` 의 언어별 파일. 빌드 결과물은 `.gitignore`. ([저장소](https://github.com/Anuken/Mindustry))

우리의 `godot/assets/` ↔ `art-source/`·`audio-source/` 분리가 같은 발상이다.

### Shattered Pixel Dungeon

`docs/` 에 플랫폼별 빌드 안내를 두고, 번역 협업은 외부 도구(Transifex)로 넘긴다.
([저장소](https://github.com/00-Evan/shattered-pixel-dungeon)) — 문서는 저장소, 협업 도구는 밖.

## 3. 문서 구조 — ADR을 쓰는 이유

MADR 가이드는 ADR을 **맥락 · 대안 · 결정 · 결과**로 정의하고 `NNNN-제목.md` 번호 체계를 권한다.
([MADR](https://adr.github.io/madr/)) 우리는 이 네 칸을 그대로 쓴다. 기존 ADR은 고치지 않고 새 번호로 대체한다.

GDD는 거대한 단일 문서보다 주제별 묶음이 실용적이다. 형식을 기계적으로 복사하지 말고 필요한 내용만 담으라고 권한다.
([Game Developer — GDD 가이드](https://www.gamedeveloper.com/design/how-to-write-a-game-design-document))
우리 `docs/gdd/` 는 원본 기획서 **복사본**이라 손대지 않고, 새로 쓰는 설계는 `docs/design/` 에 둔다.

## 4. 데이터 — 정본과 사본

- JSON Schema는 구조·타입·범위를 검증하는 표준이지만, **중복 ID·끊어진 참조·확률 합** 같은 게임 규칙은 별도 코드가 필요하다.
  ([JSON Schema](https://json-schema.org/learn/getting-started-step-by-step))
- 생성기가 정본 JSON을 만들 때 **손 편집 필드를 같은 파일에 섞으면 재생성 때 날아간다.**
  오버라이드 파일을 따로 두는 방식이 안전하다. 우리는 아직 생성기를 안 들였고, 그때 이 규칙을 적용해야 한다
  ([ADR 0002](../adr/0002-data-ssot.md) 의 "아직 안 한 것").
- JSON은 런타임 소비 형식으로 안정적이고, CSV는 표 편집에 강하지만 중첩·참조가 불편하다.
  Godot의 `FileAccess.get_csv_line()` 은 따옴표 처리를 지원하므로 `split(",")` 로 직접 쪼개지 않는다
  ([RFC 4180](https://www.rfc-editor.org/info/rfc4180/), [Godot FileAccess](https://docs.godotengine.org/en/stable/classes/class_fileaccess.html)).

## 5. 테스트

GUT는 프레임워크(`addons/gut/`)와 프로젝트 테스트(`tests/`)를 분리하고, 단위/통합을 나누는 전략을 권한다.
([GUT Quick Start](https://gut.readthedocs.io/en/9.3.1/Quick-Start.html))
우리는 `godot/tests/unit/` 하나만 두었다. 통합 테스트가 생기면 같은 층에 `integration/` 을 만든다.

## 6. 버전 관리

GitHub는 50 MiB 초과 파일에 경고, 100 MiB 초과는 차단한다. LFS는 파일당 상한이 요금제에 따라 다르다.
([대용량 파일](https://docs.github.com/en/repositories/working-with-files/managing-large-files/about-large-files-on-github))
그래서 **큰 원본만 선택적으로** LFS에 걸고, 처음부터 설정한다(나중 전환은 히스토리 재작성).

## 7. 채택하지 않은 것

| 대안 | 왜 안 썼나 |
|---|---|
| 레포 루트를 Godot 프로젝트로 | 문서·venv·도구가 에디터 파일시스템에 노출된다 |
| `scenes/` · `scripts/` 종류별 분리 | 씬 하나 고칠 때 폴더를 오가야 한다 (TPS 데모도 안 쓴다) |
| 빈 폴더 미리 깔기 | git은 빈 폴더를 추적하지 않고, 빈 방은 구조를 오해하게 만든다 |
| 모든 매니저를 Autoload로 | 전역 접근은 디버깅을 어렵게 한다 (공식 문서 경고) |
| JSON Schema 도입 | 지금 검증은 파이썬 게이트와 GUT로 충분하다. 데이터가 커지면 재검토 |
