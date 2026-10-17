#!/usr/bin/env python3
"""run_snapshots.py — 전 시뮬 1회 실행 → 스냅샷 생성 (test_center.html 허브용 · 2026-09-18)

기존 시뮬을 전혀 건드리지 않고 stdout만 캡처. 실행마다 시드·시각·소요시간을 기록해
"언제 찍은 스냅샷인지"가 항상 명시됨.

실행: python3 sim/center/run_snapshots.py [--only 이름,이름]
출력: sim/center/pages/snapshots.json  (서버용 원본)
      sim/center/pages/snapshots.js    (허브 로딩용 — const SNAPSHOTS = {...})
"""
import hashlib
import json
import os
import subprocess
import sys
import time

ROOT = os.path.dirname(os.path.abspath(__file__))       # sim/center — 러너·서버가 사는 곳
PAGES = os.path.join(ROOT, "pages")                     # 서버 루트 · 생성물(snapshots.js)이 놓이는 곳
SIMS_DIR = os.path.join(ROOT, "sims")                   # 시뮬 본체
REPO = os.path.normpath(os.path.join(ROOT, "..", ".."))  # 폰즈 저장소 루트
# 데이터 원본이 놓이는 곳 — 여기가 바뀌면 결과가 바뀌므로 지문을 남겨야 할 곳이다.
# 폰즈는 data/ 하나만 정본이다 (원본 저장소의 unity/…·design-docs/에셋 이중 사본을 없앴다).
DATA_DIRS = [os.path.join(REPO, "data")]

# 스냅샷 대상 — (이름, 명령 인수, 설명) · 시뮬 자체 수정 없이 기본 파라미터만 사용
#
# 폰즈로 옮기면서 **원본 문서·생성기에만 기대는 시뮬 2종을 뺐다**(2026-10-17).
#   · audit_sim   — 시즌 시뮬 법칙을 *생성기 소스*(gen_ecology_codex.py)와 1:1 대조한다.
#                   폰즈에는 그 생성기가 없다(도감 HTML 만 있다). 대조할 짝이 없으면
#                   남은 검사만 돌려 초록을 만드는 것은 "약해진 게이트" 다 — 그래서 안 넣었다.
#   · arc_parity  — design-docs/설계/*.md(원본 GDD 가안)의 특수미션 문구를 데이터와 대조한다.
#                   폰즈는 GDD 원문을 저장소에 두지 않는다(원본 저장소가 정본).
# 둘 다 폰즈 데이터를 검사하는 게 아니라 **원본 저장소와의 동기**를 검사하는 도구다.
# 원본 GDD·생성기를 폰즈로 들여오면 그때 다시 연결하면 된다.
SIMS = [
    ("gacha", ["gacha_test.py", "50", "10"],
     "소환 시뮬 — 50층 기준 10연차 ×40 · 등급/티어/희귀 적성/CP 분포"),
    ("fate", ["fate_test.py"],
     "운명 7단계 — 500k 롤 · 희귀직 확률 배율 검증"),
    ("proficiency", ["proficiency_test.py", "2000", "30"],
     "숙련도 — 영웅 2,000 × 30일 · 은닉→견습 해금 곡선"),
    ("economy", ["sim_economy.py"],
     "영지 경제 — baseline 포함 전 시나리오 · 골드 수지 (baseline은 항상 첫 시나리오)"),
    ("playthrough", ["playthrough_audit.py"],
     "플레이스루 감사 — 100층 런 전체 시뮬 + 정본 교차 검수"),
    ("revisions", ["test_gacha_revisions.py"],
     "5대 개정 자동 검증 — pytest 계약 (FULL 표본)"),
    ("synergy", ["party_synergy_sim.py"],
     "파티 시너지 — 5인 조합 보너스 분포 · 시나리오 3종 계약 (00 #42)"),
    ("ai_stats", ["ai_stats_check.py"],
     "AI 스탯 정합 — monsters.json 전투 몬스터 전체 aiType×스탯×aiDecision×pattern (H9)"),
    ("siren", ["siren_test.py"],
     "사이렌 계약 — T2 스탯·AI·원천연안(슬롯 3)·도감 연결"),
    ("estate_space", ["estate_space_sim.py"],
     "영지 공간 — 발면표·그리드·도로율 · P=1300 식민섬 재사용 공식"),
    ("birth_rhythm", ["run_birth_rhythm.py"],
     "출생 리듬 — 인구 자연증가 상한 60 도달 시점 실측 (S3 리듬)"),
    ("mana_econ", ["run_mana_econ.py"],
     "마나 경제 — §6b 배급 배율 스윕 × 소환 루프 무해 3프로필 (D-267)"),
    ("san_chain", ["run_san_chain.py"],
     "위생 체인 — 역병 연쇄율·격리 방어 관측 · 밴드 유지 (D-256)"),
    ("mission_mix", ["sim_mission_mix.py"],
     "미션 배분 — 주 7종 분포 밴드·특수 19종 발생률·층 총액 불변·게이팅 (#57)"),
    ("risk_curve", ["sim_risk_curve.py"],
     "층 위험도 지수 — D(f)=13^((f-1)/129) 단조성·앵커·등급 밴드·카드 규칙 (#58)"),
    ("estate_pace", ["sim_estate_pace.py"],
     "영지 개발 속도 — 시설 이중 잠금 6/6·밀도 정합안·★6 완성 전 수급 (#63)"),
    ("story_scenes", ["check_story_scenes.py"],
     "스토리 씬 게이트 — 유령 씬 0·선택지 중복 0·강제 1건·minRun·id 규칙 (결선 09-21)"),
    ("telegraph_data", ["check_telegraph_data.py"],
     "텔레그래프 데이터 — G4 무예고 1건·예고율 94%·phase·광폭 창 (D-253)"),
    ("biome_order", ["normalize_biome_order.py"],
     "biomes.json 블록 순서 — 26블록 정본 순서 자기검증 (멱등 · 09-21)"),
    ("ending_ley", ["sim_ending_ley.py"],
     "엔딩 3분기 도달 — 지망 소진 런 반복·바닥 접촉 3런 게이트·흡수 선행 (09-21)"),
    ("g4_ceiling", ["sim_g4_ceiling.py"],
     "G4 천정 101~130층 밸런스 — 체감 마진 1.1~1.6 밴드 진입 + ★7 요건 (#51/#54 후속)"),
    ("foodweb", ["sim_foodweb_combat.py"],
     "먹이그물 × 전투 연동 — 3바이옴 × 6시나리오 · 사체 유인·공포 전파 · 밸런스 게이트 (08 §5.2)"),
]
MAX_STDOUT = 60_000  # 스냅샷당 저장 한도 (초과분은 앞뒤 절단 표기)


def _sha256(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(65536), b""):
            h.update(chunk)
    return h.hexdigest()[:16]


def _mtime_map():
    """데이터 파일 경로 → mtime. 시뮬 실행 전후를 비교해 "무엇을 고쳤나" 를 찾는다."""
    out = {}
    for d in DATA_DIRS:
        if not os.path.isdir(d):
            continue
        for dirpath, _, names in os.walk(d):
            for n in names:
                p = os.path.join(dirpath, n)
                try:
                    out[os.path.relpath(p, REPO)] = os.stat(p).st_mtime
                except OSError:
                    pass
    return out


def _dirty_paths():
    """HEAD 와 다른 파일 집합 — 미커밋 작업. 없는 저장소면 조용히 빈 집합."""
    try:
        r = subprocess.run(["git", "status", "--porcelain", "--untracked-files=all"],
                           cwd=REPO, capture_output=True, text=True, timeout=60)
    except Exception:
        return set()
    if r.returncode != 0:
        return set()
    dirty = set()
    for line in r.stdout.splitlines():
        p = line[3:].strip().strip('"')
        if " -> " in p:
            p = p.split(" -> ")[-1]
        dirty.add(os.path.normpath(p))
    return dirty


def data_provenance():
    """이 스냅샷이 기대어 있는 데이터의 지문.

    "왜 이 초록을 믿어도 되는가" 의 답은 대개 시뮬이 아니라 데이터다. 그런데 스냅샷에는
    시뮬의 결과만 남고, 그 계산에 쓰인 biomes.json 이 무엇이었는지는 남지 않았다. 그 빈틈이
    실제로 사고가 났다 — biome_order 는 워킹트리에서만 초록이었다. 결과는 커밋되었는데
    커밋은 자기 완전하지 않았고, 아무도 그 사실을 즉시 볼 수 없었다.

    그래서 데이터 파일의 해시와 "HEAD 와 다른가" 를 스냅샷에 같이 심는다. 나중에 이 초록이
    언제 되돌아가면 무엇이 바뀌어 만들어진 것인지, 특정 파일을 되짚을 수 있다.
    """
    dirty = _dirty_paths()
    files = []
    for d in DATA_DIRS:
        if not os.path.isdir(d):
            continue
        for dirpath, _, names in os.walk(d):
            for n in sorted(names):
                if not n.endswith((".json", ".csv")):
                    continue
                p = os.path.join(dirpath, n)
                rel = os.path.normpath(os.path.relpath(p, REPO))
                try:
                    st = os.stat(p)
                    files.append({"path": rel, "sha256": _sha256(p), "bytes": st.st_size,
                                  "dirtyVsHead": rel in dirty})
                except OSError:
                    continue
    return files


def run_one(name, args, desc):
    t0 = time.time()
    # 시뮬은 sims/ 안에 있고, 자기 데이터는 __file__ 기준으로 폰즈 data/ 를 직접 가리킨다.
    # cwd 는 원본과 같은 모양(sims/ = 형제 모듈이 있는 곳)으로 둔다 — 상대 import·형제 실행 유지.
    script = os.path.join(SIMS_DIR, args[0])
    proc = subprocess.run([sys.executable, script] + list(args[1:]), cwd=SIMS_DIR,
                          capture_output=True, text=True, timeout=300)
    dt = time.time() - t0
    out = proc.stdout
    trimmed = False
    if len(out) > MAX_STDOUT:
        out = out[:MAX_STDOUT // 2] + "\n… (중간 절단 — 전체는 단독 실행) …\n" + out[-MAX_STDOUT // 4:]
        trimmed = True
    return {
        "name": name,
        # 저장소 루트에서 그대로 붙여넣어 실행할 수 있는 형태로 남긴다 (허브·가이드가 이 값을 보여준다)
        "cmd": "python3 " + os.path.relpath(script, REPO) + (" " + " ".join(args[1:]) if args[1:] else ""),
        "desc": desc,
        "exit": proc.returncode,
        "seconds": round(dt, 2),
        "stdout": out,
        "stderr": proc.stderr[-2000:] if proc.returncode != 0 else "",
        "trimmed": trimmed,
    }


def execute(only=None, log=print):
    """스냅샷 1회 실행 → (data, fails).

    **CLI 와 서버 워커가 이 함수 하나를 함께 쓴다.** 이전에는 gacha_server._snap_worker 가
    main() 의 본체를 통째로 복사해 놓고 있었고, 그 과정에서 데이터 지문 필드가 빠졌다 —
    서버로 [스냅샷 다시 찍기] 를 누르면 미커밋 데이터 경고 배너가 **사라지는** 상태였다.
    같은 것을 두 벌로 쓰는 한 언제나 이런 일이어난다. 이제 본체는 여기 하나뿐이다.
    """
    scope = "only" if only else "all"
    expected = [n for n, _, _ in SIMS if not only or n in only]

    sims, total0 = [], time.time()
    for name, args, desc in SIMS:
        if only and name not in only:
            continue
        log(f"  ▶ {name}: {' '.join(args)} …")
        m0 = _mtime_map()
        try:
            r = run_one(name, args, desc)
        except subprocess.TimeoutExpired:
            r = {"name": name, "cmd": " ".join(args), "desc": desc, "exit": -1,
                 "seconds": 300, "stdout": "(300초 초과 — 타임아웃)", "stderr": "", "trimmed": False}
        # 검사기가 데이터 원본을 고치는 경우는 조용히 넘어가면 안 된다. 읽기 전용이어야
        # 하는 시뮬이 biomes.json 을 덮어썼던 적이 실제로 있었다(normalize_biome_order).
        wrote = sorted(p for p, t in _mtime_map().items() if m0.get(p) != t)
        r["wroteData"] = wrote
        tag = "OK" if r["exit"] == 0 else f"exit {r['exit']}"
        extra = f" · ⚠ 데이터 {len(wrote)}개 변경" if wrote else ""
        log(f"    {tag} · {r['seconds']}초 · {len(r['stdout'].splitlines())}줄{extra}")
        sims.append(r)
    total = round(time.time() - total0, 2)

    prov = data_provenance()
    uncommitted = [f["path"] for f in prov if f["dirtyVsHead"]]
    writers = [s["name"] for s in sims if s.get("wroteData")]

    data = {
        "generatedAt": time.strftime("%Y-%m-%d %H:%M:%S"),
        "totalSeconds": total,
        # 커버리지 — 실행 대상 전체 목록과 스코프. 테스트 센터가 이것을 보고
        # "N종 중 M종" 을 말하며, 부분 실행을 "전부 통과"로 포장하지 않게 한다.
        "scope": scope,
        "expected": expected,
        "expectedTotal": len([n for n, _, _ in SIMS]),
        # 데이터 지문 — 이 초록이 기대어 있는 데이터의 해시와 미커밋 여부.
        "dataProvenance": prov,
        "uncommittedData": uncommitted,
        "dataWriters": writers,
        "sims": sims,
    }
    return data, [s["name"] for s in sims if s["exit"] != 0]


def write_outputs(data):
    """snapshots.js / snapshots.json 을 쓴다 (허브 로딩 + 서버 원본)."""
    os.makedirs(PAGES, exist_ok=True)
    js_path = os.path.join(PAGES, "snapshots.js")
    json_path = os.path.join(PAGES, "snapshots.json")
    with open(js_path, "w", encoding="utf-8") as f:
        f.write("// 자동 생성 — run_snapshots.py (수정 금지 · 재생성: python3 sim/center/run_snapshots.py)\n")
        f.write("const SNAPSHOTS = ")
        json.dump(data, f, ensure_ascii=False)
        f.write(";\n")
    with open(json_path, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=1)
    return js_path, json_path


def main():
    only = None
    if "--only" in sys.argv:
        only = set(sys.argv[sys.argv.index("--only") + 1].split(","))

    print(f"[run_snapshots] 스냅샷 시작 — {time.strftime('%Y-%m-%d %H:%M:%S')}")
    data, fails = execute(only, log=lambda m: print(m, flush=True))
    js_path, json_path = write_outputs(data)

    prov = data["dataProvenance"]
    uncommitted = data["uncommittedData"]
    writers = data["dataWriters"]
    cov = f"{len(data['sims'])}/{len(data['expected'])}" + ("" if data["scope"] == "all" else " (--only 부분 실행)")
    print(f"[run_snapshots] 완료 — 커버리지 {cov} · {data['totalSeconds']}초 · "
          f"{'전부 OK' if not fails else 'FAIL: ' + ', '.join(fails)}")
    print(f"  데이터 지문 {len(prov)}개 파일 기록")
    if uncommitted:
        print(f"  ⚠ HEAD 와 다른 데이터 {len(uncommitted)}개 — 이 결과는 커밋해도 재현되지 않을 수 있다:")
        for p in uncommitted[:8]:
            print(f"      {p}")
        if len(uncommitted) > 8:
            print(f"      … 외 {len(uncommitted) - 8}개")
    else:
        print("  데이터 전부 커밋됨 (이 결과는 HEAD 로 재현 가능)")
    if writers:
        print(f"  ⚠ 데이터를 고친 시뮬: {', '.join(writers)}")
    print(f"  → {js_path}\n  → {json_path}")
    sys.exit(1 if fails else 0)


if __name__ == "__main__":
    main()
