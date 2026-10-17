"""원본 저장소의 데이터 JSON을 이 저장소로 복사한다.

  ./.venv/bin/python tools/sync_data.py --src <원본 데이터 폴더> --dst data
  ./.venv/bin/python tools/sync_data.py --src <원본 데이터 폴더> --dst godot/data

원본 유니티 트리는 2026-10-17에 이 머신에서 삭제됐다 (이관 완료 후).
지금은 data/ 와 godot/data/ 가 유일한 정본 사본이므로, 이 스크립트는 원본이 다시 생겼을 때만 쓴다.

manifest.json 에 적힌 파일만 옮긴다. 그 목록은 2026-10-17 원본 트리와 전수 대조한 값이다
(원본 대조). .meta 와 .gitkeep 은 옮기지 않는다 — Unity 전용 부산물이다.

왜 실패하게 만들었나:
  이전 버전은 없는 파일을 건너뛰고도 exit 0 으로 끝났다. 원본에서 파일 이름이 바뀌면
  데이터가 조용히 빠진 채 게이트가 통과한다 — 이 저장소가 겪은 '침묵하는 거짓 통과'와 같은 실패 모드다.
  그래서 지금은 하나라도 없으면 exit 1 이다. 일부만 확인하려면 --allow-missing 을 명시한다.
"""
import argparse
import json
import shutil
from pathlib import Path

HERE = Path(__file__).resolve().parent.parent


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--src", required=True,
                    help="원본 Data 폴더 — 지금은 원본이 없다")
    ap.add_argument("--dst", default="data", help="이 저장소 안의 대상 폴더")
    ap.add_argument("--allow-missing", action="store_true",
                    help="없는 파일이 있어도 실패로 보지 않는다 (부분 확인용)")
    args = ap.parse_args()

    src = Path(args.src).expanduser()
    if not src.is_dir():
        print("오류: 원본 폴더가 아닙니다: %s" % src)
        return 2

    manifest = json.loads((HERE / "data" / "manifest.json").read_text(encoding="utf-8"))
    dst = HERE / args.dst
    dst.mkdir(parents=True, exist_ok=True)

    copied, missing = [], []
    for name in manifest["files"]:
        s = src / name
        if s.exists():
            shutil.copy2(s, dst / name)
            copied.append(name)
        else:
            missing.append(name)

    print("복사 %d / manifest %d → %s" % (len(copied), len(manifest["files"]), args.dst))
    if missing:
        print("원본에 없는 파일 %d개 (manifest 를 고치거나 --allow-missing):" % len(missing))
        for name in missing:
            print("  -", name)
        if not args.allow_missing:
            return 1
    print("SYNC OK: %s" % args.dst)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
