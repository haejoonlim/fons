#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""check_manual_values.py — 손 필드의 **값**이 바뀐 것을 잡는다.

왜 존재 검사(manfields)로 부족한가 (원본 이식, 원본 check_manual_values.py):
  키의 존재만 보면 이런 일이 조용히 지나간다.

      "missionWeights": [3, 2, 1]   ← 사람이 조정함
      "missionWeights": [0, 0, 0]   ← 생성기가 덮어씀 → 존재 검사는 통과

  키는 그대로니까. 원본은 생성기 5종을 실제로 돌려 **4/5 가 값을 바꾼다**는 것을 확인하고
  이 검사를 만들었다. 폰즈도 `data/` 가 유일한 정본 사본이라 같은 빈틈이 있다.

무엇을 하나:
  PROTECTED 필드의 값을 sha16 으로 해시해 `tools/manual_values_baseline.json` 에 남기고
  매 실행마다 현재 값과 대조한다. 값이 하나라도 다르면 어긋남이다.
  원값이 아니라 해시를 저장한다 — diff 가 부풀지 않고, 로그에 정본 값이 새지 않는다.

어긋남의 출처를 가른다:
  기준선은 '어떤 정본' 에서 만든다. 그래서 대조를 두 번 한다 — 워킹트리와 HEAD.
    · HEAD 도 어긋난다 → FAIL(1). 기준선이 낡았거나 생성기가 덮고 **커밋됐다**. 진짜 사고.
    · HEAD 는 맞다     → WARN(0). 어긋남이 전부 **미커밋 로컬 작업**이다. 커밋 전까지
                          게이트가 남의 작업을 붙잡으면 게이트가 아니라 소음이다.
  HEAD 를 못 읽으면(얕은 클론·git 없음) 출처를 가르지 못하므로 보수적으로 FAIL 이다.

  워킹트리에서 기준선을 만들면 그 시점에 이미 HEAD 와 다른 자리가 남는다(미커밋 수동 작업이
  큰 경우). 그 자리는 `headDrift` 에 HEAD 쪽 값 해시와 함께 적어 두고 대조에서 면제한다 —
  안 적으면 다음 실행이 남의 미커밋 작업을 '커밋된 정본이 덮였다' 로 오보고한다
  (2026-10-24: 31건이 거짓 FAIL). 면제는 그 HEAD 값이 그대로일 때만 유효하다 — HEAD 가
  또 바뀌면 해시가 어긋나 면제가 풀리고 FAIL 이다. 커밋 뒤 `--update --from-head` 로 비운다.

기준선을 바꾸는 유일한 길:
  `--update --reason "사유"`. 사유 없는 갱신은 검사를 조용히 무효화하므로 거부한다(rc 2).
  `--from-head` 를 주면 워킹트리 대신 커밋된 정본에서 기준선을 만든다(권장).
  `--list` 는 기준선과 현재의 비교표를 낸다.

사용:
  ./.venv/bin/python tools/check_manual_values.py
  ./.venv/bin/python tools/check_manual_values.py --list
  ./.venv/bin/python tools/check_manual_values.py --update --reason "왜 이 값이 맞는지"
  ./.venv/bin/python tools/check_manual_values.py --selftest
종료: 값 변경·소실 1 · 깨끗/WARN 0 · 사유 없는 갱신 2
"""
import argparse
import hashlib
import json
import os
import shutil
import subprocess
import sys
import tempfile
from datetime import datetime

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, HERE)
from gate_contract import run  # noqa: E402
from check_manual_fields import ALLOWED_MISSING, DATA, PROTECTED, entities  # noqa: E402

BASELINE = os.path.join(HERE, "manual_values_baseline.json")


def sha16(value):
    """값 → 16자리 해시. 키 순서 차이는 무시한다(정렬 JSON)."""
    blob = json.dumps(value, ensure_ascii=False, sort_keys=True,
                      separators=(",", ":")).encode("utf-8")
    return hashlib.sha256(blob).hexdigest()[:16]


def build(data_dir=DATA):
    """현재 정본에서 {파일: {id: {필드: sha16}}} 를 만든다."""
    out = {}
    for fname, keys in PROTECTED.items():
        path = os.path.join(data_dir, fname)
        if not os.path.exists(path):
            continue
        out[fname] = {it.get("id", "?"): {k: sha16(it[k]) for k in keys if k in it}
                      for it in entities(fname, data_dir)}
    return out


def _git(*args, binary=False):
    try:
        p = subprocess.run(["git", *args], cwd=ROOT, capture_output=True, timeout=60)
    except (OSError, subprocess.SubprocessError):
        return None
    if p.returncode != 0:
        return None
    return p.stdout if binary else p.stdout.decode("utf-8", "replace").strip()


def build_from_head(rev="HEAD"):
    """커밋된 정본에서 기준선을 만든다. 하나라도 못 읽으면 None.

    워킹트리를 기준선으로 박으면 다른 세션의 미커밋 작업이 '정상' 이 되고, 커밋되는 순간
    fresh clone 에서 빨개진다. 그래서 --from-head 는 커밋에서 만든다.
    """
    tmp = tempfile.mkdtemp(prefix="manual-values-head-")
    try:
        for fname in PROTECTED:
            raw = _git("show", "%s:data/%s" % (rev, fname), binary=True)
            if raw is None:
                return None
            with open(os.path.join(tmp, fname), "wb") as fh:
                fh.write(raw)
        return build(tmp)
    finally:
        shutil.rmtree(tmp, ignore_errors=True)


class Drift(str):
    """어긋난 항목 하나. str 로 찍으면 사람이 읽는 줄, 속성으로는 출처를 준다."""

    def __new__(cls, text, kind, fname, eid, field=None, want=None, got=None):
        self = super().__new__(cls, text)
        self.kind = kind      # changed | lost | added | removed
        self.fname = fname
        self.eid = eid
        self.field = field
        self.want = want
        self.got = got
        return self


def compare(current, baseline):
    """(값 변경, 필드 소실, 새 항목, 사라진 항목)."""
    changed, lost, added, removed = [], [], [], []
    for fname, ents in baseline.items():
        cur_f = current.get(fname, {})
        for eid, fields in ents.items():
            if eid not in cur_f:
                removed.append(Drift("%s · %s (기준선에만 있음)" % (fname, eid),
                                     "removed", fname, eid))
                continue
            for key, want in fields.items():
                if key not in cur_f[eid]:
                    if ALLOWED_MISSING.get((fname, key), {}).get(eid):
                        continue
                    lost.append(Drift("%s · %s.%s" % (fname, eid, key), "lost", fname, eid, key))
                    continue
                got = cur_f[eid][key]
                if got != want:
                    changed.append(Drift("%s · %s.%s  %s → %s" % (fname, eid, key, want, got),
                                         "changed", fname, eid, key, want, got))
        for eid in cur_f:
            if eid not in ents:
                added.append(Drift("%s · %s (신규)" % (fname, eid), "added", fname, eid))
    return changed, lost, added, removed


def verdict(head_bad, local_bad):
    """출처로 판정을 가른다 → (종류, rc). 커밋된 어긋남이 하나라도 있으면 FAIL."""
    if head_bad:
        return "committed", 1
    if local_bad:
        return "local", 0
    return "clean", 0


def _drift_key(it):
    """기준선에 기록하는 키 — 값 변경은 필드까지, 항목 출현은 개체까지."""
    if it.kind in ("changed", "lost"):
        return "%s|%s|%s" % (it.fname, it.eid, it.field)
    return "%s|%s" % (it.fname, it.eid)


def _drift_mark(it):
    """그 키에서 HEAD 가 갖던 값 — HEAD 가 또 바뀌면 이 표시가 어긋나므로 면제가 풀린다."""
    if it.kind == "changed":
        return str(it.want)
    if it.kind == "lost":
        return "__absent__"
    return "__entity__"


def _by_file(items):
    out = {}
    for it in items:
        out[getattr(it, "fname", "?")] = out.get(getattr(it, "fname", "?"), 0) + 1
    return out


def _short_head():
    return _git("rev-parse", "--short", "HEAD") or "?"


def load(path=BASELINE):
    with open(path, encoding="utf-8") as fh:
        return json.load(fh)


def update(reason, data_dir=DATA, path=BASELINE, from_head=False):
    prev = None
    if os.path.exists(path):
        try:
            prev = load(path)
        except ValueError:
            prev = None
    current = build_from_head("HEAD") if from_head else build(data_dir)
    # 빈 기준선을 쓰면 이후 모든 항목이 '신규' 가 되어 검사가 무력해진다 — 거부한다.
    if not current:
        print("[manvalues] 갱신 중단 — 정본을 읽지 못했다(%s). 빈 기준선은 검사를 무효화한다."
              % ("git HEAD" if from_head else data_dir), file=sys.stderr)
        return 2
    # 기준선을 워킹트리에서 만들면 HEAD 와 이미 다른 자리가 남는다. 그 자리를 **면제 목록**으로
    # 기록해 둔다 — 안 그러면 다음 실행이 그 차이를 "커밋된 정본이 덮였다" 로 오보고한다
    # (2026-10-24 실제로 그랬다: 미커밋 31건이 전부 거짓 FAIL 로 나왔다).
    head_now = build_from_head("HEAD")
    ack = {}
    if head_now and not from_head:
        for it in sum(compare(head_now, current), []):
            ack[_drift_key(it)] = _drift_mark(it)
    doc = {
        "_about": "수동 필드 값 기준선 — tools/check_manual_values.py 가 쓴다. "
                  "직접 손대지 말 것. 바꿔야 하면 --update --reason \"사유\"",
        "updatedAt": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
        "gitHead": _short_head(),
        "dataSource": "git HEAD 커밋" if from_head else "워킹트리",
        "headDrift": ack,
        "reason": reason,
        "fields": PROTECTED,
        "values": current,
    }
    if prev:
        c, l, a, r = compare(current, prev.get("values") or {})
        print("  이전 기준선 %s (HEAD %s) 대비:" % (prev.get("updatedAt", "?"), prev.get("gitHead", "?")))
        for label, items in (("값 변경", c), ("필드 소실", l), ("새 항목", a), ("사라진 항목", r)):
            print("    %s %d건%s" % (label, len(items), ("  — " + items[0]) if items else ""))
    with open(path, "w", encoding="utf-8") as fh:
        json.dump(doc, fh, ensure_ascii=False, sort_keys=True, separators=(",", ":"))
        fh.write("\n")
    n = sum(len(v) for v in current.values())
    m = sum(len(f2) for v in current.values() for f2 in v.values())
    print("  기준선 갱신 — 항목 %d개 · 필드값 %d개 · 사유: %s" % (n, m, reason))
    return 0


def check(data_dir=DATA, path=BASELINE):
    if not os.path.exists(path):
        print("[manvalues] FAIL — 기준선이 없다: %s" % os.path.relpath(path, ROOT))
        print("  자동으로 만들지 않는다. 사유를 적어 만든다:")
        print("  ./.venv/bin/python tools/check_manual_values.py --update --reason \"사유\"")
        return 1
    try:
        doc = load(path)
    except ValueError as exc:
        print("[manvalues] FAIL — 기준선 JSON 이 깨졌다: %s" % exc)
        return 1
    baseline = doc.get("values")
    if not isinstance(baseline, dict) or not baseline:
        print("[manvalues] FAIL — 기준선에 values 가 없다. 손으로 만든 파일 같다.")
        return 1

    changed, lost, added, removed = compare(build(data_dir), baseline)
    bad = []
    if changed:
        bad.append(("수동 필드 값 변경", changed))
    if lost:
        bad.append(("수동 필드 소실", lost))
    if removed:
        bad.append(("기준선에 있던 항목이 사라짐", removed))

    if bad:
        worktree_bad = [it for _label, items in bad for it in items]
        head_now = build_from_head("HEAD") if os.path.normpath(data_dir) == os.path.normpath(DATA) else None
        if head_now is None:
            kind, rc = "unknown", 1
            head_bad = []
        else:
            hc, hl, _ha, hr = compare(head_now, baseline)
            head_bad = list(hc) + list(hl) + list(hr)
            # 기준선을 만들 때 이미 HEAD 와 달랐던 자리는 면제한다(그때 사유에 남았다).
            # HEAD 쪽 값이 그 사이 또 바뀌었으면 면제가 풀린다 — _drift_mark 참고.
            ack = doc.get("headDrift") or {}
            new_head_bad = [it for it in head_bad if ack.get(_drift_key(it)) != _drift_mark(it)]
            suppressed = len(head_bad) - len(new_head_bad)
            head_bad = new_head_bad
            kind, rc = verdict(head_bad, worktree_bad)
            if suppressed and kind != "committed":
                print("  · 기준선을 만들 때부터 HEAD 와 달랐던 %d자리는 면제 목록에 있어 넘긴다"
                      % suppressed)

        if kind == "local":
            by_file = " · ".join("%s %d건" % (f, n) for f, n in sorted(_by_file(worktree_bad).items()))
            print("[manvalues] WARN — 어긋남 %d건이 전부 미커밋 로컬 작업이다 "
                  "(커밋된 HEAD 는 기준선과 일치)" % len(worktree_bad))
            print("  · 기준선 %s (HEAD %s) · 어긋난 파일: %s"
                  % (doc.get("updatedAt", "?"), doc.get("gitHead", "?"), by_file))
            print("  · 커밋하면 같은 상태가 되므로 그때 기준선을 갱신한다:")
            print("      ./.venv/bin/python tools/check_manual_values.py "
                  "--update --from-head --reason \"사유\"")
            print("  ⚠ 이 값이 생성기에 덮인 채 커밋되면 그때는 FAIL 이다.")
            return 0

        print("[manvalues] FAIL — 기준선(%s, HEAD %s) 대비 어긋남"
              % (doc.get("updatedAt", "?"), doc.get("gitHead", "?")))
        if kind == "committed":
            print("  · 커밋된 정본(HEAD)도 어긋난다 %d건 — 기준선이 낡았거나 생성기가 덮고 커밋됐다:"
                  % len(head_bad))
            for it in head_bad[:10]:
                print("      " + it)
            if len(head_bad) > 10:
                print("      … 외 %d건" % (len(head_bad) - 10))
        elif os.path.normpath(data_dir) != os.path.normpath(DATA):
            print("  · 임시 정본(--data-dir)이라 HEAD 대조를 하지 않는다 — 출처 구분 없이 실패로 본다")
        else:
            print("  · HEAD 를 읽지 못해 출처를 가르지 못했다 (얕은 클론·git 없음?)")
        for label, items in bad:
            print("  · 워킹트리 %s %d건" % (label, len(items)))
            for it in items[:20]:
                print("      " + it)
            if len(items) > 20:
                print("      … 외 %d건" % (len(items) - 20))
        if added:
            print("  · (참고) 신규 항목 %d건 — 실패 아님" % len(added))
        print("  해석: 생성기가 수동 편집을 덮었거나, 정본을 고치고 기준선 갱신을 잊었다.")
        print("  의도된 변경이면 사유를 적고 갱신한다:")
        print("      ./.venv/bin/python tools/check_manual_values.py "
              "--update --from-head --reason \"왜 이 값이 맞는지\"")
        return rc

    n = sum(len(v) for v in baseline.values())
    m = sum(len(f2) for v in baseline.values() for f2 in v.values())
    extra = " · 신규 항목 %d건" % len(added) if added else ""
    print("[manvalues] OK — 항목 %d개 · 필드값 %d개가 기준선과 일치 (기준선 %s)%s"
          % (n, m, doc.get("updatedAt", "?"), extra))
    return 0


def _selftest():
    """본검사와 같은 compare/verdict 를 돌린다 — 하네스만 통과하는 상태를 막는다."""
    fails = []
    fixture = {
        "biomes.json": {"biome_a": {"regions": sha16([1, 2]), "missionWeights": sha16([3])},
                        "biome_idea_gate": {"regions": sha16([0])}},
        "monsters.json": {"mon_x": {"level": sha16(7)}},
        "ambient.json": {"amb_y": {"stats": sha16({"hp": 10})}},
    }

    def cmp_with(mut):
        import copy
        cur = copy.deepcopy(fixture)
        mut(cur)
        return compare(cur, fixture)

    cases = [
        ("무변경 → 위반 0", cmp_with(lambda c: None), (0, 0, 0, 0)),
        ("★ 값만 바뀜 → 잡음", cmp_with(
            lambda c: c["biomes.json"]["biome_a"].__setitem__("missionWeights", sha16([0]))),
         (1, 0, 0, 0)),
        ("★ 리스트 내부 값 바뀜 → 잡음", cmp_with(
            lambda c: c["biomes.json"]["biome_a"].__setitem__("regions", sha16([1, 3]))),
         (1, 0, 0, 0)),
        ("★ 7 → 7.0 (같아 보임) → 잡음", cmp_with(
            lambda c: c["monsters.json"]["mon_x"].__setitem__("level", sha16(7.0))),
         (1, 0, 0, 0)),
        ("필드 소실 → 잡음", cmp_with(
            lambda c: c["biomes.json"]["biome_a"].pop("regions")), (0, 1, 0, 0)),
        ("신규 항목 → 실패 아님", cmp_with(
            lambda c: c["ambient.json"].__setitem__("amb_z", {"stats": sha16(1)})),
         (0, 0, 1, 0)),
        ("항목 사라짐 → 잡음", cmp_with(
            lambda c: c["monsters.json"].pop("mon_x")), (0, 0, 0, 1)),
    ]
    for label, got, want in cases:
        nums = (len(got[0]), len(got[1]), len(got[2]), len(got[3]))
        if nums != want:
            fails.append("%s — 실제 %s (기대 %s)" % (label, nums, want))

    d_a = Drift("ambient.json · x.ecology  1 → 2", "changed", "ambient.json", "x", "ecology")
    d_b = Drift("monsters.json · y.ecology  1 → 2", "changed", "monsters.json", "y", "ecology")
    d_c = Drift("ambient.json · z (기준선에만 있음)", "removed", "ambient.json", "z")
    for label, head_bad, local_bad, want in (
            ("커밋된 정본이 어긋나면 FAIL", [d_a], [d_a, d_b], ("committed", 1)),
            ("미커밋 로컬만 어긋나면 WARN", [], [d_a, d_b, d_c], ("local", 0)),
            ("둘 다 깨끗하면 clean", [], [], ("clean", 0)),
            ("HEAD 어긋남이 하나라도 있으면 FAIL", [d_c], [d_a, d_b], ("committed", 1))):
        if verdict(head_bad, local_bad) != want:
            fails.append("%s — %s (기대 %s)" % (label, verdict(head_bad, local_bad), want))

    if _by_file([d_a, d_b, d_c]) != {"ambient.json": 2, "monsters.json": 1}:
        fails.append("Drift 가 파일명을 보존하지 않는다")

    # 사유 없는 --update 거부 — 이 검사의 유일한 실패 모드라 반드시 증명한다.
    import contextlib
    import io
    saved = sys.argv
    sys.argv = ["check_manual_values.py", "--update"]
    try:
        with contextlib.redirect_stdout(io.StringIO()), contextlib.redirect_stderr(io.StringIO()):
            rc = main()
    finally:
        sys.argv = saved
    if rc != 2:
        fails.append("사유 없는 --update 를 거부하지 않는다 (rc=%r)" % rc)

    # 하네스 대조 — 틀린 기대를 실패로 세는가.
    if verdict([], [d_a]) == ("committed", 1):
        fails.append("하네스가 틀린 기대를 통과로 오인한다")

    for f in fails:
        print("[manvalues] 자가진단 실패 — " + f)
    return 1 if fails else 0


def main():
    ap = argparse.ArgumentParser(add_help=True)
    ap.add_argument("--check", action="store_true", help="기준선과 대조 (기본)")
    ap.add_argument("--update", action="store_true", help="기준선 갱신 — --reason 필수")
    ap.add_argument("--from-head", action="store_true", help="--update 시 HEAD 커밋에서 만든다")
    ap.add_argument("--reason", help="갱신 사유")
    ap.add_argument("--list", dest="lst", action="store_true", help="기준선 vs 현재 비교표")
    ap.add_argument("--selftest", action="store_true")
    ap.add_argument("--data-dir", default=DATA)
    ap.add_argument("--baseline", default=BASELINE)
    ns = ap.parse_args()

    if ns.selftest:
        return _selftest()
    if ns.update:
        if not (ns.reason or "").strip():
            print("[manvalues] --update 는 --reason 을 요구한다.", file=sys.stderr)
            print("  사유 없는 갱신은 검사를 조용히 무효화한다. 왜 이 값이 맞는지 한 줄로 남긴다.",
                  file=sys.stderr)
            return 2
        return update(ns.reason.strip(), ns.data_dir, ns.baseline, ns.from_head)
    if ns.lst:
        cur = build(ns.data_dir)
        base = load(ns.baseline).get("values", {}) if os.path.exists(ns.baseline) else {}
        for label, items in zip(("값 변경", "필드 소실", "신규 항목", "사라진 항목"),
                                compare(cur, base)):
            print("%s %d건" % (label, len(items)))
            for it in items[:60]:
                print("  · " + it)
        return 0
    return check(ns.data_dir, ns.baseline)


if __name__ == "__main__":
    sys.exit(run("manvalues", main))
