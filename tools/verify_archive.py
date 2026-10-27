"""아카이브 복원 체크리스트를 한 명령으로 검증한다.

  ./.venv/bin/python tools/verify_archive.py
  ./.venv/bin/python tools/verify_archive.py --skip-regen --keep

docs/dev/아카이브_복원_체크리스트.md 의 단계를 그대로 실행해 기대값과 맞댄다.
마지막 묶음(9단계)은 tar 를 잃고 .git 객체와 patch 만 남았을 때의 복원을 시험한다.
아카이브는 읽기만 한다. 작업 폴더는 시스템 temp 에 만들고, 끝나면 지운다(--keep 이면 남긴다).
exit 0 = 전부 통과 · 1 = 하나 이상 불일치 · 2 = 아카이브가 없음.
"""
import argparse
import gzip
import hashlib
import io
import os
import shutil
import subprocess
import sys
import tarfile
import tempfile
import unicodedata
from pathlib import Path

# 아카이브 이름 자체가 검증 대상이다 (tools/archive_clone.py 와 같은 이유).
ARCHIVE = Path.home() / "Desktop/soul-commander-archive-2026-10-24"  # path-ok
TAR = ARCHIVE / "soul-commander-2026-10-24.tar.gz"  # path-ok
PATCH = ARCHIVE / "uncommitted-restore.patch"

HEAD = "669f0be936cec1e4ac3fc84f3af6a0fa7f60fe9f"
COMMITS = 252
TAR_FILES = 1652
TEACHER_REL = "design-docs/_tools/teacher_data/teacher_v1_10k.jsonl"
TEACHER_SHA = "47ea28969c2cf5f382068a823dc9ff38fc6f8bc1db84b6a8d2769096ac39a6ce"
TEACHER_RUNS = 76

# unity/.gitattributes 가 LFS 로 잡았지만 실제로는 원본 바이너리로 커밋된 7개.
# 손대지 않으면 git status 가 늘 수정으로 센다.
LFS_PATHS = [
    "unity/Assets/Icon.png",
    "unity/Assets/Resources/Art/Logo.png",
    "unity/Assets/Resources/Art/Skin/Sheet1_Frames.png",
    "unity/Assets/Resources/Art/Skin/Sheet2_BarsIcons.png",
    "unity/Assets/Resources/Art/Skin/Sheet3_TitleIcons.png",
    "unity/Assets/Resources/Fonts/NanumGothic.ttf",
    "unity/Assets/TextMesh Pro/Fonts/LiberationSans.ttf",
]


def sh(*args, cwd=None):
    r = subprocess.run(args, cwd=cwd, capture_output=True, text=True)
    return r.returncode, r.stdout, r.stderr


def sha256(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def count_files(root, skip_git=False):
    root = Path(root)
    git_dir = root / ".git"
    n = 0
    for dirpath, dirnames, filenames in os.walk(root):
        here = Path(dirpath)
        if skip_git and (here == git_dir or git_dir in here.parents):
            dirnames[:] = []
            continue
        n += len(filenames)
    return n


def tree_bytes(root):
    total = 0
    for dirpath, _, filenames in os.walk(root):
        for name in filenames:
            total += os.path.getsize(os.path.join(dirpath, name))
    return total


def file_map(root):
    """(.git 제외) 파일 경로 → 실제 경로. 경로는 NFC 로 맞춘다.

    macOS 는 한글 파일명을 NFD 로 저장하고 tar 는 만든 쪽 표기를 그대로 쓴다.
    정규화 없이 맞대면 같은 파일이 '잃음 + 여분' 두 번 세어진다.
    """
    root = Path(root)
    out = {}
    for dirpath, _, filenames in os.walk(root):
        here = Path(dirpath)
        rel_dir = here.relative_to(root)
        if ".git" in rel_dir.parts:
            continue
        for name in filenames:
            path = here / name
            rel = path.relative_to(root).as_posix()
            out[unicodedata.normalize("NFC", rel)] = path
    return out


def status_counts(repo):
    """porcelain 상태 줄을 (총, 수정, 삭제, 미추적) 으로 센다."""
    _, out, _ = sh("git", "-c", "core.quotepath=false", "status", "--porcelain", cwd=str(repo))
    lines = out.splitlines()
    mod = sum(1 for line in lines if line[:2] == " M")
    dele = sum(1 for line in lines if line[:2] == " D")
    unt = sum(1 for line in lines if line[:2] == "??")
    return len(lines), mod, dele, unt


class Report:
    def __init__(self):
        self.total = 0
        self.bad = []

    def eq(self, name, actual, expected):
        self.total += 1
        if str(actual) == str(expected):
            print("[ OK ] %s — %s" % (name, actual))
            return True
        print("[FAIL] %s — %s (기대 %s)" % (name, actual, expected))
        self.bad.append(name)
        return False


def run_checks(base, rep, skip_regen):
    # 1. tar 자체
    expected_sha = None
    for line in (ARCHIVE / "sha256.txt").read_text(encoding="utf-8").splitlines():
        if line.strip().endswith(TAR.name):
            expected_sha = line.split()[0]
            break
    rep.eq("sha256.txt 의 tar 해시", sha256(TAR), expected_sha or "(sha256.txt 에 없음)")
    try:
        with gzip.open(TAR, "rb") as f:
            while f.read(1 << 20):
                pass
        rep.eq("gzip 무결성", "OK", "OK")
    except (OSError, EOFError) as exc:
        rep.eq("gzip 무결성", "실패: %s" % exc, "OK")

    # 2. 풀기
    out = base / "tree"
    out.mkdir()
    with tarfile.open(TAR, "r:gz") as t:
        t.extractall(out)
    rep.eq("풀린 파일 수", count_files(out), TAR_FILES)

    # 3. 이력
    _, head, _ = sh("git", "rev-parse", "HEAD", cwd=str(out))
    rep.eq("HEAD", head.strip(), HEAD)
    _, n, _ = sh("git", "rev-list", "--count", "HEAD", cwd=str(out))
    rep.eq("커밋 수", n.strip(), COMMITS)
    rc, fsck_out, _ = sh("git", "fsck", "--full", cwd=str(out))
    rep.eq("fsck exit", rc, 0)
    rep.eq("fsck 출력 줄", len(fsck_out.strip().splitlines()), 0)

    # 4. 풀린 트리 상태
    total, mod, dele, unt = status_counts(out)
    rep.eq("status 총", total, 103)
    rep.eq("status 수정", mod, 44)
    rep.eq("status 삭제", dele, 22)
    rep.eq("status 미추적", unt, 37)

    # 5. web/hero_viewer
    rc, _, err = sh("git", "--work-tree=%s" % out, "checkout", "HEAD", "--", "web/hero_viewer", cwd=str(out))
    rep.eq("hero checkout exit", rc, 0)
    hero = out / "web" / "hero_viewer"
    rep.eq("hero 파일 수", count_files(hero), 21)
    rep.eq("hero 바이트", tree_bytes(hero), 28978232)
    total, _, dele, _ = status_counts(out)
    rep.eq("status 총(hero 복원 뒤)", total, 82)
    rep.eq("status 삭제(hero 복원 뒤)", dele, 1)
    rep.eq("프로젝트 파일 수", count_files(out, skip_git=True), 1637)

    # 6. teacher_data
    rep.eq("teacher_data 해시", sha256(out / TEACHER_REL), TEACHER_SHA)
    if skip_regen:
        print("[SKIP] teacher_data 재생성 — --skip-regen")
    else:
        regen = base / "teacher_check.jsonl"
        rc, _, err = sh(sys.executable, str(out / "design-docs/_tools/sim_combat_teacher.py"),
                        "--runs", str(TEACHER_RUNS), "--out", str(regen), cwd=str(out))
        rep.eq("재생성 exit", rc, 0)
        if rc != 0:
            print("       stderr: %s" % err.strip().splitlines()[-1:])
        rep.eq("재생성 해시", sha256(regen) if regen.is_file() else "(파일 없음)", TEACHER_SHA)

    # 7. LFS 착시 정리
    rc, _, _ = sh("git", "update-index", "--assume-unchanged", *LFS_PATHS, cwd=str(out))
    rep.eq("assume-unchanged exit", rc, 0)
    total, mod, dele, unt = status_counts(out)
    rep.eq("status 총(7 뒤)", total, 75)
    rep.eq("status 수정(7 뒤)", mod, 37)
    rep.eq("status 삭제(7 뒤)", dele, 1)
    rep.eq("status 미추적(7 뒤)", unt, 37)

    # B. HEAD 이력만으로 트리 세우기
    head_tree = base / "head"
    head_tree.mkdir()
    r = subprocess.run(["git", "-C", str(out), "archive", "HEAD"], capture_output=True)
    rep.eq("git archive exit", r.returncode, 0)
    with tarfile.open(fileobj=io.BytesIO(r.stdout), mode="r|") as t:
        t.extractall(head_tree)
    rc, _, err = sh("git", "apply", str(PATCH), cwd=str(head_tree))
    rep.eq("B patch exit", rc, 0)
    if rc != 0:
        print("       stderr: %s" % err.strip().splitlines()[-1:])
    rep.eq("B 파일 수", count_files(head_tree), 1522)

    diff = 0
    for path in head_tree.rglob("*"):
        if not path.is_file():
            continue
        twin = out / path.relative_to(head_tree)
        if not twin.is_file() or sha256(path) != sha256(twin):
            diff += 1
    rep.eq("B ↔ A 내용 불일치", diff, 0)

    # 9. tar 손실 — tar 를 못 열어 .git 객체와 patch 만 남았을 때
    #    이력이 성하면 추적 파일은 전부 되살아난다. 잃는 것은 tar 에만 있던
    #    미추적·gitignore 파일뿐이다.
    loss = base / "loss"
    loss.mkdir()
    with tarfile.open(TAR, "r:gz") as t:
        only_git = [m for m in t if m.name.startswith("./.git/")]
        t.extractall(loss, members=only_git)
    rc, _, _ = sh("git", "reset", "--hard", "HEAD", cwd=str(loss))
    rep.eq("tar 손실: reset --hard exit", rc, 0)
    rep.eq("tar 손실: HEAD 만으로 세운 파일", count_files(loss, skip_git=True), 1523)
    rc, _, err = sh("git", "apply", str(PATCH), cwd=str(loss))
    rep.eq("tar 손실: patch exit", rc, 0)
    if rc != 0:
        print("       stderr: %s" % err.strip().splitlines()[-1:])

    a_map, loss_map = file_map(out), file_map(loss)
    common = set(a_map) & set(loss_map)
    diff = sum(1 for k in common
               if a_map[k].stat().st_size != loss_map[k].stat().st_size
               or sha256(a_map[k]) != sha256(loss_map[k]))
    rep.eq("tar 손실: A 트리와 공통 파일", len(common), 1522)
    rep.eq("tar 손실: A 트리와 내용 불일치", diff, 0)
    rep.eq("tar 손실: 복원 뒤 잃는 파일", len(set(a_map) - set(loss_map)), 115)
    rep.eq("tar 손실: hero 파일 수", count_files(loss / "web" / "hero_viewer"), 21)
    rep.eq("tar 손실: hero 바이트", tree_bytes(loss / "web" / "hero_viewer"), 28978232)
    rep.eq("tar 손실: teacher_data 부재", (loss / TEACHER_REL).exists(), False)


def main() -> int:
    ap = argparse.ArgumentParser(description="아카이브 복원 체크리스트 검증")
    ap.add_argument("--keep", action="store_true", help="작업 폴더를 지우지 않는다")
    ap.add_argument("--skip-regen", action="store_true", help="teacher_data 재생성(약 8초)을 건너뛴다")
    args = ap.parse_args()

    if not TAR.is_file() or not PATCH.is_file():
        print("오류: 아카이브가 없습니다: %s" % ARCHIVE)
        return 2

    base = Path(tempfile.mkdtemp(prefix="fons-archive-verify-"))
    print("검증 폴더: %s" % base)
    rep = Report()
    try:
        run_checks(base, rep, args.skip_regen)
    finally:
        if args.keep:
            print("남긴 폴더: %s" % base)
        else:
            shutil.rmtree(base, ignore_errors=True)

    if rep.bad:
        print("\nARCHIVE VERIFY FAIL — %d/%d 항목 불일치: %s"
              % (len(rep.bad), rep.total, ", ".join(rep.bad)))
        return 1
    print("\nARCHIVE VERIFY OK — %d개 항목" % rep.total)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
