"""Copy JSON SSOT from soul-commander into data/ and godot/data/.
Usage:
  python3 tools/sync_data.py --src ../soul-commander/unity/Assets/Resources/Data --dst data
Mirrors fons-web-ver/sync_web_data.py concept. Skips .meta/.gitkeep.
"""
import argparse, json, shutil
from pathlib import Path

HERE = Path(__file__).resolve().parent.parent

def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--src", required=True)
    ap.add_argument("--dst", default="data")
    args = ap.parse_args()
    src = Path(args.src)
    dst = HERE / args.dst
    manifest = json.loads((HERE / "data" / "manifest.json").read_text())
    dst.mkdir(parents=True, exist_ok=True)
    copied, missing = [], []
    for name in manifest["files"]:
        s = src / name
        if s.exists():
            shutil.copy2(s, dst / name)
            copied.append(name)
        else:
            missing.append(name)
    print(f"copied {len(copied)}: {copied}")
    if missing:
        print(f"missing {len(missing)} (check original names): {missing}")

if __name__ == "__main__":
    main()
