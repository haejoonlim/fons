#!/usr/bin/env python3
"""마물 사육 규칙 페이지 — data/monster_husbandry.json 을 읽어 검사하고 그린다.

왜 스크립트인가:
    규칙 숫자를 손으로 페이지에 적으면 데이터와 페이지가 갈라진다. 여기서는
    정본 JSON 만 읽고, 로스터의 개체가 생태도감에 실제로 있는지·해금 층이
    도감 층과 맞는지·성격 데이터 유무가 표시와 같은지를 대조한다.
    어긋나면 exit 1.

사용: ./.venv/bin/python sim/center/sims/gen_husbandry.py
출력: docs/design/마물_사육_규칙.html
"""
import json
import os

TOOLS = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(TOOLS)))
HUSB = os.path.join(ROOT, 'data', 'monster_husbandry.json')
CODEX = os.path.join(ROOT, 'data', 'ecology_codex.json')
PERSONA = os.path.join(ROOT, 'data', 'monster_personality.json')
MONSTERS = os.path.join(ROOT, 'data', 'monsters.json')
TREE = os.path.join(ROOT, 'data', 'job_tree.json')
ESTATE = os.path.join(ROOT, 'data', 'estate.json')
OUT = os.path.join(ROOT, 'docs', 'design', '마물_사육_규칙.html')

ROLE_KO = {'decomposer': '분해자', 'scavenger': '청소부'}
HAB_KO = {'swamp': '늪', 'cave': '동굴', 'ocean': '바다', 'mine': '광산', 'sewer': '하수구',
          'forest': '숲', 'grassland': '초원', 'meadow': '풀밭', 'plains': '들',
          'ruins': '폐혀', 'graveyard': '묘지', 'underground': '지하', 'river': '강'}

HEAD = """<!DOCTYPE html>
<html lang="ko">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>마물 사육 규칙</title>
<style>
  :root{--bg:#101317;--card:#191e26;--card2:#202734;--line:#2b3340;
        --fg:#eef2f7;--dim:#96a1b0;--accent:#7cc4ff;--warn:#f2b75e;--green:#9be0b4}
  *{box-sizing:border-box} html,body{overflow-x:hidden}
  body{margin:0 auto;max-width:720px;background:var(--bg);color:var(--fg);
       font:18px/1.7 -apple-system,"Apple SD Gothic Neo","Noto Sans KR",sans-serif;
       padding:20px 16px 64px}
  h1{font-size:23px;line-height:1.35;margin:0 0 8px}
  .lead{color:var(--dim);font-size:15.5px;line-height:1.7;margin:0 0 18px}
  h2.sec{font-size:15px;color:var(--dim);letter-spacing:.06em;margin:30px 0 12px;
         padding-bottom:7px;border-bottom:1px solid var(--line)}
  .box{background:var(--card);border:1px solid var(--line);border-radius:12px;
       padding:15px 16px;margin-bottom:12px;font-size:16px;line-height:1.75}
  .box h3{font-size:17px;margin:0 0 6px}
  .box p{margin:0 0 10px} .box p:last-child{margin:0}
  .num{font-size:30px;font-weight:800;color:var(--accent);line-height:1.2}
  .u{font-size:14px;color:var(--dim);margin-left:5px}
  .grid{display:grid;grid-template-columns:repeat(2,1fr);gap:10px;margin-bottom:12px}
  .cell{background:var(--card);border:1px solid var(--line);border-radius:12px;padding:13px 14px}
  .cell .lab{font-size:13.5px;color:var(--dim);margin-bottom:2px}
  table{width:100%;border-collapse:collapse;font-size:14px;margin:4px 0 8px}
  th,td{text-align:left;padding:7px 5px;border-bottom:1px solid var(--line);vertical-align:top;
        word-break:keep-all}
  th{color:var(--dim);font-weight:600;font-size:12.5px;white-space:nowrap}
  td.n{font-weight:700;white-space:nowrap}
  td.pc{white-space:nowrap}
  .cap{font-size:13.5px;color:var(--dim);margin:2px 0 8px}
  .ok{background:#1d3326;color:var(--green);border:1px solid #2f5a40;border-radius:20px;
      padding:1px 8px;font-size:12px}
  .no{background:#2b1e22;color:#d99a9a;border:1px solid #5a3038;border-radius:20px;
      padding:1px 8px;font-size:12px}
  .foot{color:var(--dim);font-size:14px;line-height:1.7;margin-top:28px}
  code{background:#0b0e12;border:1px solid var(--line);border-radius:5px;padding:0 4px;font-size:14px}
  @media (max-width:430px){.grid{grid-template-columns:1fr}}
</style>
</head>
<body>
<h1>마물 사육 규칙</h1>
<p class="lead">사역사의 마물 카드가 기르는 것들의 규칙이다. 먹이·성장·동반 한도·전투 손실 네 가지와,
기를 수 있는 개체 목록. 값은 전부 <code>data/monster_husbandry.json</code> 이 정본이다.</p>
"""

FOOT = """<p class="foot">
  정본: <code>data/monster_husbandry.json</code> · 근거: <code>ecology_codex.json</code> ·
  <code>monsters.json</code> · <code>monster_personality.json</code> · <code>estate.json</code> ·
  생성기: <code>sim/center/sims/gen_husbandry.py</code><br>
  CP·스탯·등급은 건드리지 않는다 — 전투 밖 상태만 바꾼다.
</p>
</body>
</html>
"""


def fail(msg):
    raise SystemExit(f'FAIL — {msg}')


def main():
    with open(HUSB, encoding='utf-8') as fh:
        h = json.load(fh)
    with open(CODEX, encoding='utf-8') as fh:
        codex = {e['name']: e for e in json.load(fh)['entries']}
    with open(PERSONA, encoding='utf-8') as fh:
        pers = {p['name']: p for p in json.load(fh)['personas']}
    with open(MONSTERS, encoding='utf-8') as fh:
        entities = {m['name'] for m in json.load(fh)['monsters']}
    with open(TREE, encoding='utf-8') as fh:
        jobs = json.load(fh)['jobs']
    with open(ESTATE, encoding='utf-8') as fh:
        est = json.load(fh)

    # ── 검사 ────────────────────────────────────────────────────────────
    if not any(k['name'] == '마물' for j in jobs for k in (j.get('keywords') or [])):
        fail('job_tree.json 에 마물 카드가 없다')

    facility = {f['id']: f for f in est['facilities']}
    keep = h['unlock']['keep_facility']
    if keep not in facility:
        fail(f'estate.json 에 없는 시설: {keep}')
    if facility[keep]['unlock_floor'] != h['unlock']['keep_facility_floor']:
        fail(f'시설 해금 층이 다르다: {keep} {facility[keep]["unlock_floor"]}')

    lim = h['limit']
    reach = lim['base'] + facility[keep]['max_level'] * lim['per_training_ground_level']
    if reach < lim['max']:
        fail(f'한도 상한 {lim["max"]} 에 도달할 수 없다 (최대 {reach})')

    floors = sorted(r['unlock_floor'] for r in h['roster'])
    if floors[0] != h['unlock']['first_floor']:
        fail(f'첫 마물 해금 층 {floors[0]} ≠ unlock.first_floor {h["unlock"]["first_floor"]}')

    crit = h['criteria']
    if crit['feed'] != h['feed']['item']:
        fail(f'판정 먹이({crit["feed"]})와 실제 먹이({h["feed"]["item"]})가 다르다')
    roles = tuple(crit['role'])
    agg_max = crit['persona']['aggression_max']
    soc_min = crit['persona']['sociality_min']

    for r in h['roster']:
        e = codex.get(r['name'])
        if e is None:
            fail(f'생태도감에 없는 개체: {r["name"]}')
        if e['floors'][0] != r['unlock_floor']:
            fail(f'해금 층이 도감과 다르다: {r["name"]} {e["floors"][0]} ≠ {r["unlock_floor"]}')
        if e['role'] not in roles:
            fail(f'청소부·분해자가 아니다: {r["name"]} = {e["role"]}')
        if r['name'] not in entities:
            fail(f'전투 개체가 없다 (ambient 는 데리고 다닐 수 없다): {r["name"]}')
        p = pers.get(r['name'])
        if (p is not None) != r['persona']:
            fail(f'성격 데이터 표시가 틀렸다: {r["name"]} persona={r["persona"]} 실제={p is not None}')
        if p is not None:
            if p['aggression'] > agg_max:
                fail(f'공격성 초과: {r["name"]} {p["aggression"]} > {agg_max}')
            if p['sociality'] < soc_min:
                fail(f'무리성 미달: {r["name"]} {p["sociality"]} < {soc_min}')

    stages = h['growth']['stages']
    if [s['fed_floors'] for s in stages] != sorted(s['fed_floors'] for s in stages):
        fail('성장 단계가 먹인 층 순서가 아니다')
    if h['feed']['leave_at_hunger'] != h['feed']['hunger_steps']:
        fail('굶주림 단계와 이탈 지점이 다르다')

    # ── 그리기 ─────────────────────────────────────────────────────────
    o = [HEAD]
    o.append('<div class="grid">')
    o.append(f'<div class="cell"><div class="lab">동반 한도</div>'
             f'<div class="num">{lim["base"]}<span class="u">+ 훈련장 레벨</span></div>'
             f'<div class="cap">최대 {lim["max"]}</div></div>')
    o.append(f'<div class="cell"><div class="lab">굶으면 우리를 뜬다</div>'
             f'<div class="num">{h["feed"]["leave_at_hunger"]}<span class="u">층</span></div>'
             f'<div class="cap">죽지는 않는다</div></div>')
    o.append('</div>')

    o.append('<h2 class="sec">먹이</h2><div class="box">')
    o.append(f'<h3>{h["feed"]["item"]} {h["feed"]["per_creature_per_floor"]}개 / 마리 / 층</h3>')
    o.append(f'<p>{h["feed"]["note"]}</p>')
    o.append('</div>')

    o.append('<h2 class="sec">성장</h2>')
    o.append('<table><tr><th>단계</th><th>먹인 층</th><th>묶는 시간</th><th>대상</th></tr>')
    for s in stages:
        o.append(f'<tr><td class="n">{s["name_ko"]}</td><td>{s["fed_floors"]}층부터</td>'
                 f'<td>{s["hold_ticks"]}틱</td><td>{s["targets"]}</td></tr>')
    o.append('</table>')
    o.append(f'<p class="cap">{h["growth"]["note"]}</p>')

    o.append('<h2 class="sec">동반 한도</h2><div class="box">')
    o.append(f'<h3>{lim["base"]} + {facility[keep]["name_ko"]} 레벨 (최대 {lim["max"]})</h3>')
    o.append(f'<p>{lim["note"]} 지금 설정으로 도달 가능한 최대는 '
             f'{lim["base"]} + {facility[keep]["max_level"]} = <b>{reach}</b> 이고, '
             f'상한 {lim["max"]} 에서 멈춘다.</p>')
    o.append('</div>')

    o.append('<h2 class="sec">전투 손실</h2><div class="box">')
    o.append(f'<h3>HP 0 = 영구 손실</h3>')
    o.append(f'<p>{h["loss"]["note"]}</p>')
    o.append('</div>')

    o.append('<h2 class="sec">기는 조건</h2><div class="box">')
    o.append(f'<h3>공격성 {agg_max} 이하 · 무리성 {soc_min} 이상</h3>')
    o.append(f'<p>{crit["note"]}</p>')
    o.append(f'<p class="cap">기준 정본: <code>data/monster_husbandry.json</code> '
             f'<code>criteria</code> · 정의: 용어집 “마물”</p>')
    o.append('</div>')

    o.append('<h2 class="sec">기를 수 있는 마물</h2>')
    o.append(f'<p class="cap">첫 해금 {h["unlock"]["first_floor"]}층 — '
             f'{h["unlock"]["reason"]}</p>')
    o.append('<table><tr><th>개체</th><th>해금</th><th>서식지</th><th>역할</th>'
             '<th>성격<br>공격·무리</th></tr>')
    for r in h['roster']:
        e = codex[r['name']]
        hab = '·'.join(HAB_KO.get(x, x) for x in e['habitat'])
        p = pers.get(r['name'])
        mark = (f'{p["aggression"]} · {p["sociality"]}' if p
                else '<span class="no">없음</span>')
        o.append(f'<tr><td class="n">{r["name"]}</td><td>{r["unlock_floor"]}층</td>'
                 f'<td>{hab}</td><td>{ROLE_KO[e["role"]]}</td>'
                 f'<td class="pc">{mark}</td></tr>')
    o.append('</table>')
    for r in h['roster']:
        o.append(f'<p class="cap"><b style="color:#c9d4e2">{r["name"]}</b> — {r["note"]}</p>')

    o.append('<h2 class="sec">받아들일 조건</h2><div class="box"><h3>검사 항목</h3>')
    for a in h['acceptance']:
        o.append(f'<p>· {a}</p>')
    o.append('</div>')
    o.append(FOOT)

    with open(OUT, 'w', encoding='utf-8') as fh:
        fh.write('\n'.join(o))
    print(f'OK — {os.path.relpath(OUT, ROOT)} ({os.path.getsize(OUT):,} bytes) · '
          f'마물 {len(h["roster"])}종 · 한도 {lim["base"]}~{lim["max"]}')


if __name__ == '__main__':
    main()
