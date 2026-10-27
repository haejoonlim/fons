"""원본 클론 아카이브에서 필요한 파일만 꺼낸다.

  ./.venv/bin/python tools/archive_clone.py find 설계
  ./.venv/bin/python tools/archive_clone.py get design-docs/_tools/check_cs.py
  ./.venv/bin/python tools/archive_clone.py get check_cs --out /tmp/fons

`~/soul-commander` 는 2026-10-24에 tar 로 묶고 지웠다
(`~/Desktop/soul-commander-archive-2026-10-24/`, 기록은 docs/dev/원본클론_정리_선택지.md §5).
381MB 를 통째로 풀지 않고 한 파일만 보고 싶을 때 쓴다.

한글 파일명 때문에 tar 명령으로는 못 찾는다. macOS 는 이름을 NFD 로 저장하고
tar 도 그 바이트를 그대로 담는데, 셸에서 친 한글은 NFC 라 `tar -x "./설계"` 가 빗나간다.
그래서 이 스크립트는 양쪽을 NFC 로 맞춰 비교한다.

`get` 은 정확한 경로를 먼저 찾고, 없으면 부분 일치로 찾는다. 후보가 여럿이면
무엇이 걸렸는지 보여 주고 exit 1 한다 — 엉뚱한 파일을 조용히 꺼내지 않기 위해서다.
"""
import argparse
import sys
import tarfile
import unicodedata
from pathlib import Path

DEFAULT_TAR = Path.home() / "Desktop/soul-commander-archive-2026-10-24" / "soul-commander-2026-10-24.tar.gz"
DEFAULT_OUT = Path.home() / "Desktop/soul-commander-restore"


def nfc(text: str) -> str:
    return unicodedata.normalize("NFC", text)


def rel_name(member: tarfile.TarInfo) -> str:
    name = member.name[2:] if member.name.startswith("./") else member.name
    return nfc(name.rstrip("/"))


def files(tar: tarfile.TarFile):
    for member in tar:
        if member.isfile():
            yield member, rel_name(member)


def safe_target(root: Path, rel: str) -> Path:
    target = (root / rel).resolve()
    if root.resolve() not in target.parents:
        raise SystemExit("오류: 아카이브 밖으로 나가는 경로입니다: %s" % rel)
    return target


def cmd_find(tar_path: Path, needle: str) -> int:
    hits = 0
    with tarfile.open(tar_path, "r:gz") as tar:
        for member, rel in files(tar):
            if nfc(needle).lower() in rel.lower():
                print("%10d  %s" % (member.size, rel))
                hits += 1
    if not hits:
        print("일치 없음: %s" % needle)
        return 1
    print("\n%d개" % hits)
    return 0


def cmd_get(tar_path: Path, queries, out_dir: Path, take_all: bool) -> int:
    out_dir.mkdir(parents=True, exist_ok=True)
    with tarfile.open(tar_path, "r:gz") as tar:
        members = list(files(tar))
        picked = {}
        for query in queries:
            want = nfc(query).strip().lstrip("./")
            exact = [m for m in members if m[1] == want]
            found = exact or [m for m in members if want.lower() in m[1].lower()]
            if not found:
                print("일치 없음: %s" % query)
                return 1
            if len(found) > 1 and not exact and not take_all:
                print("후보가 %d개입니다 — 경로를 더 적거나 --all:" % len(found))
                for member, rel in found[:20]:
                    print("  %s" % rel)
                return 1
            for member, rel in found:
                picked[rel] = member

        for rel, member in picked.items():
            src = tar.extractfile(member)
            if src is None:
                print("읽기 실패: %s" % rel)
                return 1
            target = safe_target(out_dir, rel)
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(src.read())
            print("%10d  %s" % (member.size, target))

    print("\n%d개 → %s" % (len(picked), out_dir))
    return 0


def main() -> int:
    ap = argparse.ArgumentParser(description="원본 클론 아카이브에서 파일 꺼내기")
    ap.add_argument("--tar", default=str(DEFAULT_TAR), help="아카이브 tar 경로")
    sub = ap.add_subparsers(dest="cmd", required=True)

    find = sub.add_parser("find", help="이름으로 찾기 (NFC/NFD 무관)")
    find.add_argument("needle")

    get = sub.add_parser("get", help="파일 꺼내기 (정확한 경로 우선, 없으면 부분 일치)")
    get.add_argument("queries", nargs="+")
    get.add_argument("--out", default=str(DEFAULT_OUT), help="꺼낼 폴더")
    get.add_argument("--all", action="store_true", help="부분 일치가 여럿이면 전부 꺼낸다")

    args = ap.parse_args()
    tar_path = Path(args.tar).expanduser()
    if not tar_path.is_file():
        print("오류: 아카이브가 없습니다: %s" % tar_path)
        return 2

    if args.cmd == "find":
        return cmd_find(tar_path, args.needle)
    return cmd_get(tar_path, args.queries, Path(args.out).expanduser(), args.all)


if __name__ == "__main__":
    raise SystemExit(main())
