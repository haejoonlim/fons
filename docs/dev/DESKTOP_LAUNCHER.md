# 바탕화면 실행 앱 (폰즈.app)

바탕화면의 `폰즈.app` 은 **내보낸 빌드가 아니라 프로젝트 실행기**다.
프로젝트 폴더(`~/Desktop/폰즈/godot`)를 직접 열기 때문에, 코드를 고치면 다음에 아이콘을 열 때 그대로 반영된다.
익스포트(`export_presets.cfg`)는 아직 설정하지 않았고, 배포용 빌드가 필요해지면 그때 따로 만든다.

## 동작 순서

```
아이콘 더블클릭
  → 변경된 파일이 있으면 godot --headless --path <프로젝트> --import   (새 이미지·오디오 등록)
  → godot --path <프로젝트>                                            (게임 실행)
```

- **임포트를 매번 하지 않는 이유**: 임포트는 이 머신에서 약 6초가 걸리고, 게임 실행은 약 2초면 된다.
  `.gd` 스크립트는 임포트 없이도 항상 최신이 로드되므로, 리소스가 바뀌었을 때만 임포트하면 된다.
- 변경 판정은 `~/Library/Application Support/FONS/import-stamp` 의 mtime과 프로젝트 파일의 mtime을 비교한다.
- 로그: `~/Library/Logs/FONS/launch.log` (1MB 넘으면 `launch.log.old` 로 한 번 비튼다).
  실행할 때마다 `import: 실행` / `import: 건너뜀` / `import: 변경 감지 → <파일>` 이 남는다.

## 구조

```
~/Desktop/폰즈.app/
  Contents/
    Info.plist                     # CFBundleExecutable=launcher, CFBundleIconFile=app
    MacOS/launcher                 # bash 실행기
    Resources/app.icns             # 아이콘 (1024px 소스에서 생성)
```

`CFBundleExecutable` 이 셸 스크립트인 번들은 정상 동작한다. Godot을 내보내지 않으므로 앱 크기가 3MB다
(Godot 바이너리는 `~/.local/bin/godot` 을 그대로 쓴다).

## 다시 만들 때

아이콘을 바꾸거나 앱을 지웠을 때의 절차다. 소스 이미지는 1024 이상 정사각 PNG면 된다.

```bash
IMG="<아이콘>.png"
rm -rf /tmp/FONS.iconset /tmp/app.icns && mkdir -p /tmp/FONS.iconset
sips -s format png -z 1024 1024 "$IMG" --out /tmp/fons_master.png
for spec in "16 icon_16x16" "32 icon_16x16@2x" "32 icon_32x32" "64 icon_32x32@2x" \
            "128 icon_128x128" "256 icon_128x128@2x" "256 icon_256x256" "512 icon_256x256@2x" \
            "512 icon_512x512" "1024 icon_512x512@2x"; do
  size="${spec% *}"; name="${spec#* }"
  sips -z "$size" "$size" /tmp/fons_master.png --out "/tmp/FONS.iconset/${name}.png"
done
iconutil -c icns /tmp/FONS.iconset -o /tmp/app.icns
cp /tmp/app.icns ~/Desktop/폰즈.app/Contents/Resources/app.icns
touch ~/Desktop/폰즈.app    # Finder 아이콘 캐시 갱신
```

아이콘은 모서리가 투명한 정사각 PNG여야 macOS 앱 아이콘처럼 보인다. 모서리가 불투명하면 둥근 사각형으로 깎아야 한다.

## 한계

- **Dock 아이콘은 Godot 것이다.** 실행 중인 프로세스가 Godot 바이너리라서 Dock에는 Godot 아이콘이 뜬다.
  바꾸려면 Godot 바이너리를 번들 안에 넣어야 하는데, 그러면 앱이 100MB를 넘고 Godot 업데이트 때 낡는다.
  지금은 바탕화면 아이콘만 우리 것이다.
- 프로젝트를 옮기면 실행기가 깨진다. 그때는 `Contents/MacOS/launcher` 의 `PROJECT` 경로를 고친다.
- 앱은 서명·공증되지 않았다. 이 머신 안에서만 쓰는 용도다. 배포용은 별도 서명이 필요하다.
