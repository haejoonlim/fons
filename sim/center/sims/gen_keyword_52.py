#!/usr/bin/env python3
"""52차 — 길잡이를 추적·탐색·개척으로 확정하고, 네 직업 12장을 전부 확정 처리.

왜 스크립트인가:
    확정된 이름·축·설명을 손으로 HTML 에 적으면 데이터가 바뀌어도 페이지가
    그대로 남아 거짓말을 한다. 여기서는 **값은 전부 job_tree.json 에서** 읽고
    이 파일에는 '무엇이 무엇이 됐나'와 '왜'만 적는다. 카드가 데이터에 없거나,
    확정 전 이름이 아직 남아 있거나, 생태도감 수치가 인용과 다르면 실패한다.

사용: ./.venv/bin/python sim/center/sims/gen_keyword_52.py
출력: docs/design/키워드_설계안_52차.html
"""
import json
import os

TOOLS = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(TOOLS)))
TREE = os.path.join(ROOT, 'data', 'job_tree.json')
CODEX = os.path.join(ROOT, 'data', 'ecology_codex.json')
PERSONA = os.path.join(ROOT, 'data', 'monster_personality.json')
OUT = os.path.join(ROOT, 'docs', 'design', '키워드_설계안_52차.html')

# (직업, 지적, [(지금 카드, 이전 카드, 왜)])
PROPOSALS = [
    ('사역사', '기를 수 있는 것만 — 공격성 0.3 이하 · 무리성 0.6 이상 · 버려진 것을 먹을 것', [
        ('짐승', None, None),
        ('곤충', None, None),
        ('마물', None, '51차에 마귀로 바꾼 자리를 마물로 확정했다. 골라 둔 셋은 바뀌지 않았다.'),
    ]),
    ('창술사', None, [
        ('투창', None, None),
        ('관철', None, None),
        ('연창', None, None),
    ]),
    ('주술사', None, [
        ('낙인', None, None),
        ('속박', None, None),
        ('역병', None, None),
    ]),
    ('길잡이', '세 번 어색했던 이름(표시물·계급어·길 접미)을 버리고 동작 셋으로', [
        ('탐색', '앞서기', None),
        ('추적', '길열기', None),
        ('개척', '길남기기', None),
    ]),
]

# 기를 수 있는 마물 — (개체, 층, 서식지 코드, 서식지 한글, 식성, 역할, 공격성, 무리성, 지능, 활동)
CREW = [
    ('초록슬라임', '[16, 20]', ['swamp', 'cave'], '늪·동굴', 'omnivore', 'decomposer',
     0.2, 0.9, 0.06, 'always'),
    ('코볼드', '[16, 20]', ['cave', 'mine'], '동굴·광산', 'omnivore', 'scavenger',
     0.3, 0.9, 0.233, 'nocturnal'),
    ('오우즈', '[31, 35]', ['swamp', 'sewer'], '늪·하수구', 'omnivore', 'decomposer',
     0.3, 0.6, 0.045, 'always'),
]
DOMESTIC_WHY = {
    '초록슬라임': '배설물과 사체를 먹는다. 겁이 많고(0.65) 먼저 물지 않는다.',
    '코볼드': '무리성이 가장 높다(0.9). 손을 쓰는 청소부라 창고·광산 일이 된다.',
    '오우즈': '지능이 가장 낮다(0.045). 하수구 바닥을 훑고 지나간다.',
}
ROLE_KO = {'decomposer': '분해자', 'scavenger': '청소부'}

# 길잡이 3단계 — (카드, 아는 것, 티어). 설명은 카드 데이터에서 그대로 읽는다.
ARC = [
    ('추적', '지나간 것', '3 · 가장 쉽다'),
    ('탐색', '지금 있는 것', '2'),
    ('개척', '아직 없는 것', '1 · 가장 어렵다'),
]

NOTES = [
    ('확정한 것', [
        '네 직업 열두 장이 전부 확정이다 — 사역사(짐승·곤충·마물) · 창술사(투창·관철·연창) · '
        '주술사(낙인·속박·역병) · 길잡이(추적·탐색·개척).',
        '데이터(<code>data/job_tree.json</code>)와 사본(<code>godot/data/job_tree.json</code>)이 같고, '
        '용어집에는 이전 이름이 폐기 표기로 남았다.',
    ]),
    ('길잡이 — 아는 것의 순서', [
        '추적은 <b>지나간 것</b>을 안다. 자국이 남아 있으니 가장 쉽다.',
        '탐색은 <b>지금 있는 것</b>을 안다. 가 봐야 알 수 있다.',
        '개척은 <b>아직 없는 것</b>을 만든다. 없는 길을 내는 일이라 가장 어렵다.',
        '티어도 같은 방향이다 — 3 → 2 → 1. 어려운 카드가 강하다.',
    ]),
    ('마물 — 기른 것만 부린다', [
        '골라 둔 셋은 공격성 0.3 이하, 무리성 0.6 이상, 사람이 버린 것을 먹는다. '
        '셋을 다 넘으면 우리 없이도 마을 곁에 남는다.',
        '위험한 것(흉고블린 0.7 · 고블린 0.6 · 임프 0.6)은 카드에서 뺐다. '
        '기르는 대상이 아니라 사냥감이다.',
    ]),
    ('아직 정하지 않은 것', [
        '마물 사육 규칙 — 먹이 소모, 성장, 데리고 다닐 수 있는 수, 전투에서 잃었을 때.',
        '길잡이 숙련도·AI 연동 규칙. 카드 이름과 난이도만 그 방향에 맞춰 두었다.',
        'GDD 직업 표는 아직 이번 값이 아니다 (<code>docs/gdd/</code> 는 원본 문면이라 고치지 않는다).',
    ]),
]

HEAD = """<!DOCTYPE html>
<html lang="ko">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>직업 키워드 확정 (52차)</title>
<style>
  :root{--bg:#101317;--card:#191e26;--card2:#202734;--line:#2b3340;
        --fg:#eef2f7;--dim:#96a1b0;--accent:#7cc4ff;--warn:#f2b75e;--green:#9be0b4}
  *{box-sizing:border-box} html,body{overflow-x:hidden}
  body{margin:0 auto;max-width:720px;background:var(--bg);color:var(--fg);
       font:18px/1.7 -apple-system,"Apple SD Gothic Neo","Noto Sans KR",sans-serif;
       padding:20px 16px 64px}
  h1{font-size:23px;line-height:1.35;margin:0 0 8px}
  .lead{color:var(--dim);font-size:15.5px;line-height:1.7;margin:0 0 18px}
  h2.sec{font-size:15px;color:var(--dim);letter-spacing:.06em;margin:34px 0 12px;
         padding-bottom:7px;border-bottom:1px solid var(--line)}
  .job{background:var(--card);border:1px solid var(--line);border-radius:14px;
       padding:17px 15px 15px;margin-bottom:15px}
  .jh{display:flex;align-items:baseline;gap:9px;flex-wrap:wrap;margin-bottom:3px}
  .l1{font-size:12.5px;color:var(--dim);border:1px solid var(--line);border-radius:20px;
      padding:2px 9px;white-space:nowrap}
  .jh h3{font-size:23px;margin:0;line-height:1.25}
  .arrow{color:var(--dim);font-size:16px}
  .jdesc{font-size:15px;color:var(--dim);margin:0 0 9px}
  .note{font-size:15.5px;color:var(--warn);margin:5px 0 13px;line-height:1.6}
  .note::before{content:"지적  ";font-weight:700}
  .card{background:var(--card2);border-radius:11px;padding:12px 14px;margin-bottom:9px}
  .chead{display:flex;align-items:baseline;gap:8px;flex-wrap:wrap}
  .old{font-size:17px;color:var(--dim);text-decoration:line-through}
  .new{font-size:23px;font-weight:800;color:var(--accent)}
  .keep{font-size:23px;font-weight:800;color:var(--accent)}
  .ax{font-size:13.5px;color:var(--dim);border:1px solid var(--line);border-radius:20px;padding:1px 8px}
  .tag{font-size:12px;border-radius:20px;padding:1px 8px;margin-left:auto}
  .done{background:#1d3326;color:var(--green);border:1px solid #2f5a40}
  .do{font-size:16px;color:#d3dbe6;margin:6px 0 0;line-height:1.6}
  .why2{font-size:14.5px;color:var(--dim);margin:5px 0 0;line-height:1.6}
  .box{background:var(--card);border:1px solid var(--line);border-radius:12px;
       padding:15px 16px;margin-bottom:12px;font-size:16px;line-height:1.75}
  .box h3{font-size:17px;margin:0 0 6px}
  .box p{margin:0 0 10px} .box p:last-child{margin:0}
  table{width:100%;border-collapse:collapse;font-size:13.5px;margin:4px 0 8px}
  th,td{text-align:left;padding:7px 5px;border-bottom:1px solid var(--line);vertical-align:top;
        word-break:keep-all}
  th{color:var(--dim);font-weight:600;font-size:12.5px;white-space:nowrap}
  td.n{font-weight:700;white-space:nowrap}
  td.num{white-space:nowrap}
  .cap{font-size:13.5px;color:var(--dim);margin:2px 0 8px}
  .dg{background:var(--card2);border-radius:10px;padding:10px 12px;margin-bottom:8px;
      font-size:14.5px;line-height:1.6;color:var(--dim)}
  .dg b{color:#c9d4e2}
  .foot{color:var(--dim);font-size:14px;line-height:1.7;margin-top:28px}
  code{background:#0b0e12;border:1px solid var(--line);border-radius:5px;padding:0 4px;font-size:14px}
</style>
</head>
<body>
<h1>직업 키워드 확정 — 52차</h1>
<p class="lead">길잡이 셋을 <b>추적 · 탐색 · 개척</b> 으로 확정했다. 따라간다 → 찾는다 → 낸다.
사역사는 <b>짐승 · 곤충 · 마물</b> 그대로다. 네 직업 열두 장 모두 확정이고,
아래 값은 전부 <code>job_tree.json</code> 에서 읽었다.</p>
"""

FOOT = """<p class="foot">
  데이터: <code>data/job_tree.json</code> · 생태도감: <code>data/ecology_codex.json</code> ·
  성격: <code>data/monster_personality.json</code> ·
  생성기: <code>sim/center/sims/gen_keyword_52.py</code><br>
  직업 id·카드 id 는 그대로다(<code>l2_strategist</code> · <code>kw_strategist_command</code>).
</p>
</body>
</html>
"""


def find_job(jobs, name):
    for j in jobs:
        if j['name'] == name:
            return j
    return None


def find_card(job, name):
    for k in job.get('keywords') or []:
        if k['name'] == name:
            return k
    return None


def main():
    with open(TREE, encoding='utf-8') as fh:
        jobs = json.load(fh)['jobs']
    with open(CODEX, encoding='utf-8') as fh:
        codex = {e['name']: e for e in json.load(fh)['entries']}
    with open(PERSONA, encoding='utf-8') as fh:
        pers = {p['name']: p for p in json.load(fh)['personas']}
    l1name = {j['id']: j['name'] for j in jobs if j['stage'] == 1}

    # 근거 확인 — 인용한 개체·수치가 데이터와 같아야 한다
    for name, floors, hab, hab_ko, diet, role, aggr, soc, intel, act in CREW:
        e = codex.get(name)
        if e is None:
            raise SystemExit(f'FAIL — 생태도감에 없는 개체: {name}')
        if str(e['floors']) != floors or e['diet'] != diet or e['role'] != role:
            raise SystemExit(f'FAIL — 도감 값이 다르다: {name}')
        if e['habitat'] != hab:
            raise SystemExit(f'FAIL — 서식지가 다르다: {name}')
        p = pers.get(name)
        if p is None:
            raise SystemExit(f'FAIL — 성격 데이터에 없는 개체: {name}')
        for key, want in (('aggression', aggr), ('sociality', soc),
                          ('intelligence', intel), ('activity', act)):
            if p[key] != want:
                raise SystemExit(f'FAIL — 성격 값이 다르다: {name}.{key}')
        if aggr > 0.3 or soc < 0.6:
            raise SystemExit(f'FAIL — 사육 조건 미달: {name}')

    n_cards = 0
    for job_name, _, cards in PROPOSALS:
        job = find_job(jobs, job_name)
        if job is None:
            raise SystemExit(f'FAIL — 데이터에 없는 직업: {job_name}')
        for now, old, _ in cards:
            if find_card(job, now) is None:
                raise SystemExit(f'FAIL — {job_name} 에 없는 카드: {now}')
            if old and old in [k['name'] for k in job.get('keywords') or []]:
                raise SystemExit(f'FAIL — {job_name} 에 옛 카드가 아직 있다: {old}')
            n_cards += 1

    # 길잡이 단계는 티어가 3 → 2 → 1 로 올라가야 한다 (어렵운 쪽이 뒤 단계)
    strat = find_job(jobs, '길잡이')
    for stage, (name, _, _) in enumerate(ARC, start=1):
        cur = find_card(strat, name)
        if cur is None:
            raise SystemExit(f'FAIL — 길잡이에 없는 카드: {name}')
        if int(cur['tier']) != 4 - stage:
            raise SystemExit(f'FAIL — 단계와 티어가 어긋난다: {name} 티어 {cur["tier"]}')

    out = [HEAD]
    out.append('<div class="box">'
               f'<b>네 직업 · {n_cards}장 전부 확정</b><br>'
               '길잡이 세 장만 이름이 새로 붙었고 나머지 아홉 장은 값 그대로다.</div>')

    group_now = None
    for job_name, note, cards in PROPOSALS:
        job = find_job(jobs, job_name)
        group = l1name.get(job.get('parentId'), '?')
        if group != group_now:
            out.append(f'<h2 class="sec">{group}</h2>')
            group_now = group

        out.append('<section class="job">')
        out.append(f'<div class="jh"><span class="l1">{group}</span><h3>{job_name}</h3></div>')
        out.append(f'<p class="jdesc">{job.get("desc", "")}</p>')
        if note:
            out.append(f'<p class="note">{note}</p>')

        for now, old, why in cards:
            cur = find_card(job, now)
            head = (f'<span class="old">{old}</span><span class="arrow">→</span>'
                    f'<span class="new">{now}</span>') if old else f'<span class="keep">{now}</span>'
            out.append('<div class="card">')
            out.append(f'<div class="chead">{head}<span class="ax">{cur["shape"]}</span>'
                       f'<span class="tag done">확정</span></div>')
            out.append(f'<p class="do">{cur["desc"]}</p>')
            if why:
                out.append(f'<p class="why2">{why}</p>')
            out.append('</div>')

        if job_name == '사역사':
            out.append('<h3 style="font-size:15px;color:var(--dim);margin:16px 0 4px">'
                       '기를 수 있는 마물 — 생태도감·성격 데이터에서 확인</h3>')
            out.append('<p class="cap">셋 다 잡식이고, 사체와 배설물을 먹고 산다.</p>')
            out.append('<table><tr><th>개체</th><th>층</th><th>서식지</th><th>역할</th>'
                       '<th>공격성</th><th>무리성</th></tr>')
            for name, floors, hab, hab_ko, diet, role, aggr, soc, intel, act in CREW:
                out.append(f'<tr><td class="n">{name}</td><td class="num">{floors}</td>'
                           f'<td>{hab_ko}</td><td>{ROLE_KO[role]}</td>'
                           f'<td class="num">{aggr}</td><td class="num">{soc}</td></tr>')
            out.append('</table>')
            for name, *_ in CREW:
                out.append(f'<div class="dg"><b>{name}</b> — {DOMESTIC_WHY[name]}</div>')

        if job_name == '길잡이':
            out.append('<h3 style="font-size:15px;color:var(--dim);margin:16px 0 4px">'
                       '3단계 — 아는 것의 범위가 넓어진다</h3>')
            out.append('<table><tr><th>카드</th><th>아는 것</th><th>하는 일</th>'
                       '<th class="num">티어</th></tr>')
            for name, knows, tier in ARC:
                cur = find_card(job, name)
                out.append(f'<tr><td class="n">{name}</td><td>{knows}</td>'
                           f'<td>{cur["desc"]}</td><td class="num">{tier}</td></tr>')
            out.append('</table>')
            out.append('<p class="cap" style="margin:6px 0 0">티어는 난이도다 — 1이 가장 어렵고 '
                       '가장 강하다. 단계도 3 → 2 → 1 로 같이 올라간다.</p>')
        out.append('</section>')

    out.append('<h2 class="sec">적용과 남은 일</h2>')
    for title, paras in NOTES:
        out.append('<div class="box">')
        out.append(f'<h3>{title}</h3>')
        for p in paras:
            out.append(f'<p>{p}</p>')
        out.append('</div>')

    out.append(FOOT)
    with open(OUT, 'w', encoding='utf-8') as fh:
        fh.write('\n'.join(out))
    print(f'OK — {OUT} ({os.path.getsize(OUT):,} bytes) · 카드 {n_cards}장 확정')


if __name__ == '__main__':
    main()
