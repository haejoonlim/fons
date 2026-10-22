#!/usr/bin/env python3
"""외부 에이전트 스킬을 핀 SHA로 받아오고, 받은 것이 그 SHA와 같은지 검사한다.

    python3 tools/fetch_skills.py --list            # 목록
    python3 tools/fetch_skills.py                   # 없는 것만 설치 (기본 목적지 .claude/skills)
    python3 tools/fetch_skills.py --only godot-export
    python3 tools/fetch_skills.py --force           # 있는 것도 다시 받아 덮어쓴다
    python3 tools/fetch_skills.py --check           # 설치본 ↔ 핀 SHA 대조 (exit 1 = 다름)
    python3 tools/fetch_skills.py --dest /tmp/s     # 목적지 바꾸기

왜 스크립트인가: 지금 스킬 12종이 서로 다른 저장소·SHA에 흩어져 있다. 손으로 받으면
"어느 커밋에서 왔는지"가 사라지고, 다음 사람이 최신 upstream 과 비교할 수 없다
(docs/dev/AGENT_SKILLS.md §4-5 "버전은 SHA로 고정한다").

이 스크립트가 하지 않는 것:
  - 스킬 안의 셸 블록을 실행하지 않는다. 받아서 디스크에 놓을 뿐이다.
    `balance-review` 의 preamble 처럼 저장소 밖(`~/.gstack/`)을 쓰는 블록이 있다.
  - 스킬이 제안한 수치를 어디에도 넣지 않는다. 정본은 data/·docs/ 다.

표준 라이브러리만 쓴다 (urllib·tarfile). 로컬 venv 는 3.9 다.
"""
import argparse
import hashlib
import io
import sys
import tarfile
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

# 저장소 → (표기 이름, 핀 SHA). SHA가 바뀌면 여기와 docs/dev/AGENT_SKILLS.md §1을 같은 커밋에서 고친다.
REPOS = {
    "gamedev": ("gamedev-skills/awesome-gamedev-agent-skills",
                "0a70cfc64672d512c5b5b6006b5dcb5cf90dbdbd", "Apache-2.0"),
    "gstack": ("fagemx/gstack-game",
               "7259ab9782fa9c17e45c16f1fb8347823ddb4379", "MIT"),
}

# 설치된 것(installed=True)과 나중에 쓸 것. `--check` 는 설치된 것만 본다.
SKILLS = [
    {"name": "godot-gdscript-headless-testing", "repo": "gamedev",
     "path": "skills/godot/godot-gdscript-headless-testing", "installed": True},
    {"name": "godot-3d-essentials", "repo": "gamedev",
     "path": "skills/godot/godot-3d-essentials", "installed": True},
    {"name": "godot-nodes-scenes", "repo": "gamedev",
     "path": "skills/godot/godot-nodes-scenes", "installed": True},
    {"name": "godot-ui-control", "repo": "gamedev",
     "path": "skills/godot/godot-ui-control", "installed": True},
    {"name": "balance-review", "repo": "gstack",
     "path": "skills/balance-review", "installed": True},
    # --- 나중에 쓸 것 (AGENT_SKILLS.md §6). 지금 설치해도 쓸 자리가 없다 ---
    {"name": "save-systems", "repo": "gamedev",
     "path": "skills/disciplines/save-systems", "installed": False,
     "when": "세이브 규격(확정 #47)을 옮기는 단계"},
    {"name": "dialogue-systems", "repo": "gamedev",
     "path": "skills/disciplines/dialogue-systems", "installed": False,
     "when": "대화·브리핑 화면을 만들 때"},
    {"name": "performance-optimization", "repo": "gamedev",
     "path": "skills/disciplines/performance-optimization", "installed": False,
     "when": "3D 실측에서 프레임이 안 맞을 때 (Phase 3 끝)"},
    {"name": "godot-export", "repo": "gamedev",
     "path": "skills/godot/godot-export", "installed": False,
     "when": "macOS 익스포트 프리셋을 확정할 때"},
    {"name": "godot-resources", "repo": "gamedev",
     "path": "skills/godot/godot-resources", "installed": False,
     "when": "JSON 데이터를 리소스로 바꿀지 정할 때"},
    {"name": "roguelike", "repo": "gamedev",
     "path": "skills/genres/roguelike", "installed": False,
     "when": "영구사망 루프 기준을 문서로 만들 때"},
    {"name": "procedural-gen", "repo": "gamedev",
     "path": "skills/disciplines/procedural-gen", "installed": False,
     "when": "층 생성을 절차 생성으로 바꾸기로 정할 때"},
]


def _sha256(data):
    return hashlib.sha256(data).hexdigest()


def _download(repo_key):
    """저장소 tar.gz 하나를 받아 (루트 접두사, {경로: 바이트}) 로 푼다."""
    repo, sha, _ = REPOS[repo_key]
    url = "https://codeload.github.com/%s/tar.gz/%s" % (repo, sha)
    sys.stderr.write("+ %s @ %s\n" % (repo, sha[:12]))
    with urllib.request.urlopen(url, timeout=120) as res:
        blob = res.read()
    root = None
    files = {}
    with tarfile.open(fileobj=io.BytesIO(blob), mode="r:gz") as tar:
        for m in tar.getmembers():
            if not m.isfile():
                continue
            parts = m.name.split("/", 1)
            if len(parts) != 2:
                continue
            if root is None:
                root = parts[0]
            if parts[0] != root:
                continue
            fh = tar.extractfile(m)
            files[parts[1]] = fh.read() if fh else b""
    if root is None:
        raise SystemExit("tar 에서 루트를 찾지 못했습니다: %s" % url)
    return files


def _skill_files(files, skill_path):
    """저장소 파일 중 스킬 폴더 것만 (폴더 기준 상대경로, 바이트) 로 추린다."""
    prefix = skill_path.rstrip("/") + "/"
    out = {}
    for p, data in files.items():
        if p.startswith(prefix):
            out[p[len(prefix):]] = data
    return out


def _write(dest, rel, data):
    target = dest / rel
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_bytes(data)
    if rel.endswith("SKILL.md"):
        target.chmod(0o644)


def cmd_list():
    print("%-34s %-8s %-8s %s" % ("스킬", "저장소", "상태", "쓸 때"))
    for s in SKILLS:
        print("%-34s %-8s %-8s %s" % (
            s["name"], s["repo"], "설치됨" if s["installed"] else "대기",
            s.get("when", "")))
    print("\n저장소 · SHA")
    for key, (repo, sha, lic) in REPOS.items():
        print("  %-8s %s @ %s (%s)" % (key, repo, sha, lic))


def cmd_install(dest, force, only):
    todo = [s for s in SKILLS if not only or s["name"] in only]
    if not todo:
        raise SystemExit("해당 이름이 없습니다: %s" % ", ".join(sorted(only)))
    # 저장소별로 한 번만 받는다.
    cache = {}
    written = skipped = 0
    for s in todo:
        target = dest / s["name"]
        if target.exists() and not force:
            print("- %s (이미 있음 — 다시 받으려면 --force)" % s["name"])
            skipped += 1
            continue
        if s["repo"] not in cache:
            cache[s["repo"]] = _download(s["repo"])
        files = _skill_files(cache[s["repo"]], s["path"])
        if not files:
            raise SystemExit("%s: 핀 SHA에 그 경로가 없습니다 (%s)" % (s["name"], s["path"]))
        for rel, data in files.items():
            _write(target, rel, data)
        print("+ %s (%d files)" % (s["name"], len(files)))
        written += 1
    print("\n설치 %d · 건너뜀 %d → %s" % (written, skipped, dest))
    if written:
        print("다음: docs/dev/AGENT_SKILLS.md §3 표에 언제 쓰는지 한 줄 적는다. "
              "라이선스 원문은 third_party/ 에 있다.")


def cmd_check(dest):
    """설치본이 핀 SHA와 같은지 본다. 파일 단위 sha256 대조 — 다르면 exit 1."""
    cache = {}
    bad = 0
    checked = 0
    for s in SKILLS:
        if not s["installed"]:
            continue
        target = dest / s["name"]
        if not target.exists():
            print("MISSING %s — 설치본이 없습니다 (%s)" % (s["name"], target))
            bad += 1
            continue
        if s["repo"] not in cache:
            cache[s["repo"]] = _download(s["repo"])
        upstream = _skill_files(cache[s["repo"]], s["path"])
        local = {}
        for p in target.rglob("*"):
            if p.is_file():
                local[str(p.relative_to(target))] = p.read_bytes()
        diffs = [p for p in sorted(set(upstream) | set(local))
                 if _sha256(upstream.get(p, b"")) != _sha256(local.get(p, b""))]
        checked += 1
        if diffs:
            bad += 1
            print("DIFF %s — %d files" % (s["name"], len(diffs)))
            for p in diffs[:10]:
                print("   %s" % p)
        else:
            print("OK   %s (%d files)" % (s["name"], len(upstream)))
    print("\n검사 %d · 불일치 %d" % (checked, bad))
    return 1 if bad else 0


def main():
    ap = argparse.ArgumentParser(description="핀 SHA로 외부 스킬 받기/검사")
    ap.add_argument("--list", action="store_true", help="목록만 본다")
    ap.add_argument("--check", action="store_true", help="설치본 ↔ 핀 SHA 대조")
    ap.add_argument("--force", action="store_true", help="있어도 다시 받는다")
    ap.add_argument("--only", action="append", default=[], help="이 이름만 (반복 가능)")
    ap.add_argument("--dest", default=str(ROOT / ".claude" / "skills"), help="설치 폴더")
    a = ap.parse_args()
    if a.list:
        cmd_list()
        return 0
    dest = Path(a.dest)
    if a.check:
        return cmd_check(dest)
    cmd_install(dest, a.force, set(a.only))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
