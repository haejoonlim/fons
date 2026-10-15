"""Toolchain doctor — verifies the tools needed to build FONS.

Usage:
  python3 tools/check_env.py            # required + optional report
  python3 tools/check_env.py --strict   # fail if any optional tool is missing

Required tools gate the build. Optional tools (art/audio/asset pipeline) only warn.
Exit 0 when every required tool is present.
"""
import argparse
import shutil
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent.parent

REQUIRED = [
    ("godot", ["--version"], "Godot 4.x engine — build/run/export the game"),
    ("git", ["--version"], "version control"),
]
OPTIONAL = [
    ("blender", ["--version"], "3D modelling — remade assets"),
    ("ffmpeg", ["-version"], "audio/video conversion"),
    ("ffprobe", ["-version"], "audio/video inspection"),
    ("git-lfs", ["version"], "large binary assets"),
]

VENV_PYTHON = HERE / ".venv" / "bin" / "python"
TEMPLATES_DIR = Path.home() / "Library" / "Application Support" / "Godot" / "export_templates"


def first_line(name: str, args: list) -> str:
    try:
        r = subprocess.run([name] + args, capture_output=True, text=True, timeout=30)
    except (OSError, subprocess.SubprocessError) as exc:
        return f"error: {exc}"
    out = (r.stdout or r.stderr).strip().splitlines()
    return out[0].strip() if out else "?"


def report(group: list, required: bool) -> int:
    missing = 0
    for name, args, why in group:
        path = shutil.which(name)
        if path:
            print(f"  [ OK ] {name:<8} {first_line(name, args):<46} {why}")
        else:
            missing += 1
            print(f"  [MISS] {name:<8} {'-':<46} {why}")
    return missing


def godot_templates() -> tuple:
    """Return (ok, description) for the installed Godot export templates."""
    if not TEMPLATES_DIR.is_dir():
        return False, f"{TEMPLATES_DIR} not found"
    versions = sorted(p.name for p in TEMPLATES_DIR.iterdir()
                      if p.is_dir() and (p / "version.txt").exists())
    if not versions:
        return False, "no version.txt — Editor > Manage Export Templates"
    newest = versions[-1]
    stamp = (TEMPLATES_DIR / newest / "version.txt").read_text().strip()
    count = sum(1 for _ in (TEMPLATES_DIR / newest).iterdir())
    return True, f"{stamp} ({count} files) — {newest}"


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--strict", action="store_true", help="treat optional tools as required")
    args = ap.parse_args()

    print("FONS toolchain check\n")
    print("required:")
    missing_required = report(REQUIRED, True)
    print("\noptional (art / audio / assets):")
    missing_optional = report(OPTIONAL, False)

    print("\nexport templates (build .app/.exe/.apk):")
    tpl_ok, tpl_desc = godot_templates()
    if tpl_ok:
        print(f"  [ OK ] templates {tpl_desc}")
    else:
        missing_optional += 1
        print(f"  [MISS] templates {tpl_desc}")

    print("\nproject venv:")
    if VENV_PYTHON.exists():
        print(f"  [ OK ] {VENV_PYTHON} -> {first_line(str(VENV_PYTHON), ['--version'])}")
    else:
        missing_required += 1
        print(f"  [MISS] {VENV_PYTHON} — run: python3 -m venv .venv && ./.venv/bin/pip install pytest jsonschema")

    if missing_required or (args.strict and missing_optional):
        print(f"\nFAIL: {missing_required} required, {missing_optional} optional missing")
        return 1
    print(f"\nOK: all required tools present ({missing_optional} optional missing)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
