"""Phase gates: docs + sim/gacha.py. Godot GUT tests run inside Godot (Phase 2+)."""
import subprocess, sys
from pathlib import Path
HERE = Path(__file__).resolve().parent.parent
def run(cmd):
    print("+", " ".join(cmd))
    r = subprocess.run(cmd, cwd=HERE)
    if r.returncode != 0: sys.exit(r.returncode)
run([sys.executable, "tools/check_docs.py"])
run([sys.executable, "sim/gacha.py"])
print("GATE ALL OK")
