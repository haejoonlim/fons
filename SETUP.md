# SETUP — 개발 환경 (설치 2026-10-15 · 실측 재검증 2026-10-16)

이 머신(macOS 12.7.6 / Intel x86_64, i5-6500)에 게임 제작 툴체인을 설치했다.
Godot 4.x로 **빌드·실행·익스포트**, Blender로 **에셋 재제작**, ffmpeg로 **오디오/영상 변환**까지 커버한다.

## 설치된 것 (2026-10-16 `--version` 실측)

| 도구 | 버전 | 설치 위치 | 용도 |
|---|---|---|---|
| Godot | `4.7.2.stable.official.ed1daf0bf` | `/Applications/Godot.app` → `~/.local/bin/godot` | 게임 엔진 — 씬/스크립트/익스포트 |
| Blender | `4.5.14 LTS` | `/Applications/Blender.app` → `~/.local/bin/blender` | 3D 모델·리깅·익스포트 (에셋 재제작) |
| ffmpeg | `9.0.2` | `~/.local/bin/ffmpeg` | 오디오/영상 변환 |
| ffprobe | `9.0.2` | `~/.local/bin/ffprobe` | 미디어 정보 조회 |
| git-lfs | `3.8.0` (darwin amd64) | `~/.local/bin/git-lfs` | 대용량 바이너리 에셋 (`git lfs install` 완료) |
| git | `2.37.1 (Apple Git-137.1)` | `/usr/bin/git` | 버전 관리 |
| GUT | 9.6.1 (vendored) | `godot/addons/gut/` | Godot 단위 테스트 — `godot/project.godot`에 에디터 플러그인으로 등록됨 |
| 익스포트 템플릿 | `4.7.2.stable` | `~/Library/Application Support/Godot/export_templates/4.7.2.stable/` | 빌드 산출물 (.app/.exe/.apk/.zip) |
| Python | `3.9.6` | `.venv/` (`python3 -m venv .venv`로 생성) | `tools/`·`sim/` 게이트 실행 |

Godot·Blender는 `.app` 번들이라 CLI에서 쓰도록 `~/.local/bin`에 심볼릭 링크를 걸어 뒀다.
`~/.local/bin`은 `~/.zprofile`과 `~/.zshrc`에 PATH로 등록했다 (두 파일 모두 이번에 새로 만든 파일).

**GUT 버전 주의:** 벤더링된 애드온의 실제 버전은 `godot/addons/gut/plugin.cfg`의 `version="9.6.1"` 기준 **9.6.1**이다(위 표의 값이 맞다). GUT는 실행 끝에 "9.7.1 is now available" 같은 상류 릴리스 공지를 출력하는데, 이는 **상류에 더 새 릴리스가 있다는 안내일 뿐** 벤더링된 사본의 버전이 아니다. 이 값을 9.7.1로 "고치지" 말 것.

**엔진은 준비 끝이다.** Godot 4.7.2가 실제로 실행되고(`godot --version` 응답 확인), 익스포트 템플릿도 같은 버전으로 설치돼 있다. "Godot을 아직 못 켰다"는 상태는 아니며, 남은 것은 이 레포의 씬·스크립트·익스포트 프리셋을 만드는 일뿐이다.

## 렌더러 결정 (확정: `gl_compatibility`)

`godot/project.godot`의 렌더러는 **Compatibility(OpenGL 3.3)** 로 확정한다. 되돌릴 계획이 아니라 의도된 선택이다.

- 근거: macOS는 Vulkan을 네이티브로 제공하지 않아 Forward+/Mobile은 MoltenVK 경로를 탄다. Intel Mac + Monterey 조합에서 Forward+/Mobile의 에디터 검은 화면·Vulkan device loss 보고가 있고, Compatibility는 그 경로를 아예 쓰지 않는다. Godot 문서도 Compatibility를 구형 하드웨어·최대 호환용으로 안내한다.
- 대가(Compatibility에서 **못 쓰는** 기능): SDFGI, VoxelGI, SSIL, SSR, 볼류메트릭 포그, 서브서피스 스캐터링, 데칼, DOF 블러, 컴퓨트 셰이더, TAA/FSR2/FXAA/SMAA.
  - 라이트맵 **베이킹**은 RenderingDevice가 필요해 Compatibility에서는 불가(베이킹된 라이트맵의 **렌더링**은 가능).
- 여전히 쓸 수 있는 것: **SSAO**, **MSAA 3D**, SSAA, 기본 depth/height fog, glow.
- 시작 프로파일: 3D 렌더 스케일 1.0(1920×1080), MSAA 3D 2×, 그림자 캐스팅 라이트 최소화, SSAO·glow는 기본 OFF로 두고 실측 후 켠다. 60fps는 목표이지 보장이 아니다 — 익스포트 빌드로 이 머신에서 직접 측정한다.

## 확인

```bash
cd ~/Desktop/폰즈
./.venv/bin/python tools/check_env.py            # 툴체인 상태 표
./.venv/bin/python tools/check_env.py --strict   # 선택 도구까지 전부 요구
```

새 터미널을 열고 `godot --version` → `4.7.2.stable.official.ed1daf0bf` 이 나오면 정상이다.

## 쓰는 법

```bash
# 엔진에서 프로젝트 열기 (에디터 GUI)
godot --path godot --editor

# 헤드리스: 리소스 임포트만 (CI/검증용)
godot --path godot --headless --import

# GUT 테스트 — 권장: 리포 루트에서 원샷 스크립트 (import 후 GUT, 실패 시 exit 1)
./tools/test_godot.sh

# 직접 돌릴 때는 import가 먼저다 (설정: godot/.gutconfig.json)
#   신규 clone에는 .godot/ 임포트 캐시가 없다. import 없이 GUT만 돌리면
#   "Some GUT class_names have not been imported" 에러를 찍고 **exit 0**으로 끝난다.
#   → 테스트가 한 개도 실행되지 않았는데 통과로 보이는 조용한 거짓 통과다.
cd godot && godot --headless --import && godot --headless -s addons/gut/gut_cmdln.gd -gexit

# 파이썬 게이트 (docs 존재 + 가챠 W0 재현)
cd ~/Desktop/폰즈 && ./.venv/bin/python tools/gate_all.py

# Blender 헤드리스 (배치 변환/익스포트)
blender --background --python script.py

# 오디오 변환 예시 (wav → ogg, Godot 임포트용)
ffmpeg -i in.wav -c:a libvorbis -q:a 5 out.ogg
```

## 다시 설치해야 할 때 (재현 명령)

```bash
mkdir -p ~/.local/bin

# Godot 4.7.2 (universal)
curl -fL -o /tmp/godot.zip \
  https://github.com/godotengine/godot/releases/download/4.7.2-stable/Godot_v4.7.2-stable_macos.universal.zip
unzip -q /tmp/godot.zip -d /tmp/godot && cp -R /tmp/godot/Godot.app /Applications/
xattr -dr com.apple.quarantine /Applications/Godot.app
ln -sf /Applications/Godot.app/Contents/MacOS/Godot ~/.local/bin/godot

# Blender 4.5 LTS (Intel)
curl -fL -o /tmp/blender.dmg \
  https://download.blender.org/release/Blender4.5/blender-4.5.14-macos-x64.dmg
hdiutil attach /tmp/blender.dmg -nobrowse -readonly
ditto /Volumes/Blender/Blender.app /Applications/Blender.app
xattr -dr com.apple.quarantine /Applications/Blender.app
hdiutil detach /Volumes/Blender
ln -sf /Applications/Blender.app/Contents/MacOS/Blender ~/.local/bin/blender

# ffmpeg / ffprobe (macOS amd64 정적 빌드)
for t in ffmpeg ffprobe; do
  curl -fL -o /tmp/$t.zip "https://ffmpeg.martin-riedl.de/redirect/latest/macos/amd64/release/$t.zip"
  unzip -q -o /tmp/$t.zip -d /tmp/$t-out && cp /tmp/$t-out/$t ~/.local/bin/ && chmod +x ~/.local/bin/$t
done

# Git LFS
curl -fL -o /tmp/git-lfs.zip \
  https://github.com/git-lfs/git-lfs/releases/download/v3.8.0/git-lfs-darwin-amd64-v3.8.0.zip
unzip -q -o /tmp/git-lfs.zip -d /tmp/git-lfs-out
cp /tmp/git-lfs-out/git-lfs-3.8.0/git-lfs ~/.local/bin/ && chmod +x ~/.local/bin/git-lfs
git lfs install

# GUT 애드온
git clone --depth 1 --branch v9.6.1 https://github.com/bitwes/Gut.git /tmp/Gut
cp -R /tmp/Gut/addons/gut godot/addons/gut

# Python venv
python3 -m venv .venv
./.venv/bin/pip install --upgrade pip && ./.venv/bin/pip install pytest jsonschema
```

## PATH (이미 등록됨)

`~/.zprofile`, `~/.zshrc`:

```sh
export PATH="$HOME/.local/bin:$PATH"
```

## 빌드 (익스포트)

익스포트 템플릿이 설치돼 있어 프리셋만 만들면 바로 빌드된다. 아직 없는 것: `godot/export_presets.cfg` 하나뿐이다.
메인 신은 있다 — `res://game/main/main.tscn` ([project.godot](godot/project.godot) 의 `run/main_scene`).

```bash
# 에디터에서 프리셋 만들고: Project > Export > Add > macOS
#   - Application > Bundle Identifier: com.<본인>.pons  (비워두지 말 것)
#   - Custom Template: 비워두면 설치된 기본 템플릿 사용
#   - Codesign: Built-in (ad-hoc only) / Notarization: Disabled  ← 로컬 테스트용
mkdir -p build
godot --headless --path godot --export-release "macOS" ../build/FONS.app
```

- 익스포트 CLI는 **출력 디렉터리가 미리 존재해야** 한다 (`mkdir -p build`).
- 위 Codesign/Notarization 설정은 **로컬 실행 테스트용**이다. 배포용으로는 Apple Developer ID 인증서로 서명·공증(notarize)·staple이 필요하고, 없으면 Gatekeeper가 막을 수 있다.
- `.app` 번들 이름은 `FONS.app`(ASCII)로 뽑고, 표시 이름만 나중에 `폰즈`로 맞춘다.

## 안 깔린 것 (필요해지면)

- **Node.js / npm** — 계획에서 웹 표현층(Vite/TS)을 버렸으므로 불필요. 원본 `verify_*.mjs` 15종(원본 대조)은 `godot/tests/unit/*.gd`와 `tools/` 파이썬 게이트로 승계한다.
- **Homebrew** — 이번엔 안 썼다. `/usr/local`이 root 소유라 sudo가 필요해서, `.app` 직접 설치 + `~/.local/bin` 심볼릭 링크로 처리했다. 패키지 관리가 필요해지면 그때 설치.
- **`gh` (GitHub CLI)** — 없다. 그래서 이 머신에서는 레포 생성·푸시를 CLI로 자동화할 수 없다. 자세한 처리는 [MIGRATION_PLAN.md](MIGRATION_PLAN.md) §2.

## 검증 결과

**2026-10-16 실측 (이 문서의 표·경로는 전부 이 값 기준):**

- `godot --version` → `4.7.2.stable.official.ed1daf0bf`
- `blender --version` → `Blender 4.5.14 LTS`, `ffmpeg`/`ffprobe` → `9.0.2`, `git-lfs` → `3.8.0`, `git` → `2.37.1`
- 익스포트 템플릿 디렉터리 `4.7.2.stable` 존재
- `./.venv/bin/python --version` → `Python 3.9.6`

**2026-10-16 재실측 (이 폴더에서 직접 실행, 종료 코드 포함):**

- `./.venv/bin/python tools/check_env.py --strict` → 모든 도구 OK, exit 0
- `./.venv/bin/python tools/gate_all.py` → `DOCS OK` + `GATE OK: W0 pulls=130 expected_shaped=6.5 legacy=0.95` → `GATE ALL OK`, exit 0
- `godot --headless --import` → exit 0. 단 `res://scenes/title.tscn` 미존재 에러 2건을 찍는다 (메인 신 미생성 상태 — Phase 3-1에서 생성)
- import **후** GUT → `Scripts 2 / Tests 6 / Passing 6 / Asserts 8`, exit 0
- import **없이** GUT만 → class_names 에러를 찍고 **exit 0** (거짓 통과). 위 "쓰는 법"의 두 단계를 반드시 지킬 것

**2026-10-15 이전 세션 기록 (그 시점 값 — 위 재실측이 우선). 아래 게이트 출력의 `pulls=130`은 그때 쓰던 값이고, 2026-10-17 원본 대조에서 **원본에 없는 정의**로 확인됐다:**

- `godot --headless --import` → exit 0 (스크립트 파싱 에러 없음. `res://scenes/title.tscn` 미존재 경고만)
- GUT → `2 scripts / 6 tests / 6 passing / 8 asserts`, exit 0
- `tools/gate_all.py` → `DOCS OK` + `GATE OK: W0 pulls=130 expected_shaped=6.5 legacy=0.95` → `GATE ALL OK`, exit 0

**원본 대조 완료 (2026-10-17):** 이 문서가 참조하는 원본 레포(`haejoonlim/soul-commander`)는 이제 이 머신에 클론돼 있다 (`~/soul-commander` · 워킹트리 213MB · 커밋 252개 · 파일 1,523개 · 자체 실측). 원본 경로·수치의 근거는 [docs/original/](docs/original/00_읽는법.md) 사실표 4종이다. 위 검증값은 **이 머신과 이 레포에 대한 것**이고, 원본 수치·구조는 사실표를 보면 된다.
