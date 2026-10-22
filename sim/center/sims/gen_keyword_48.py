#!/usr/bin/env python3
"""48차 키워드 재설계 — 사역사 세 번째를 동물이 아닌 무리(덩굴)로.

왜 스크립트인가:
    이름·축·설명을 손으로 HTML 에 적으면 데이터가 바뀔 때 페이지가 조용히
    거짓말을 한다. 여기서는 **지금 값은 job_tree.json 에서** 읽고, 이 파일에는
    '무엇이 무엇이 됐나'와 '왜'만 적는다. 새 카드가 데이터에 없거나 옛 이름이
    아직 남아 있으면 즉시 실패한다. 인용한 생태도감 개체도 데이터에 없으면 실패한다.

사용: ./.venv/bin/python sim/center/sims/gen_keyword_48.py
출력: docs/design/키워드_설계안_48차.html
"""
import json
import os

TOOLS = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(TOOLS)))
TREE = os.path.join(ROOT, 'data', 'job_tree.json')
CODEX = os.path.join(ROOT, 'data', 'ecology_codex.json')
OUT = os.path.join(ROOT, 'docs', 'design', '키워드_설계안_48차.html')

PROPOSALS = [
    ('사역사', '"나머지 한 장은 굳이 동물이 아니어도 된다 — 다시 찾아 봐"', [
        ('짐승', None, None),
        ('곤충', None, None),
        ('덩굴', '뱀', '동물 셋으로 채우면 결이 얇아진다. 생태도감에서 식물 계열을 골랐다 — '
                       '뿌리내려 길목을 막아 붙잡아 두는 쪽이라 축이 방어로 갈린다.'),
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
    ('길잡이', None, [
        ('견습', None, None),
        ('숙련', None, None),
        ('장인', None, None),
    ]),
]

CONFIRMED = {('창술사', '투창'), ('창술사', '연창'), ('창술사', '관철'),
             ('주술사', '낙인'), ('주술사', '속박'), ('주술사', '역병')}

# 생태도감에서 확인한 덩굴 계열 — (개체명, 층, 서식지) · 데이터에 없으면 생성 실패
VINE_SPECIES = [
    ('독덩굴', '[6, 10]', '숲·늪'),
    ('덩굴꽃', '[66, 70]', '밀림'),
    ('월광덩굴', '[96, 100]', '성층'),
    ('중력 매복 덩굴', '[121, 125]', '찢긴 천창'),
]

# 후보와 버린 이유 — (이름, 층, 왜 버렸나)
CANDIDATES = [
    ('뱀 (46차)', '1~10', '동물 셋이 되면 짐승·곤충과 결이 겹친다. 셋 다 몸으로 때리는 쪽이다.'),
    ('포자 버섯', '16~20', '1~10층에 없다. 퍼뜨리는 쪽이라 즉발이 없어 카드 한 장으로 읽히지 않는다.'),
    ('산호초', '11~15', '바다에 갇혀 육상 층에서 부릴 수 없다.'),
    ('덩굴', '6~130', '뿌리내려 길목을 막는다 — 셋 중 유일하게 방어로 갈린다.'),
]

NOTES = [
    ('왜 동물이 아니어도 되는가', [
        '사역사의 직업 설명은 "분류군을 통째로 부려 싸움을 짜는 직업"이다. 부리는 대상이 '
        '짐승일 이유가 없다 — 생태도감의 계열이면 무엇이든 부릴 수 있다.',
        '세 번째를 동물로 채우면 셋이 모두 <b>몸으로 때리는 쪽</b>이 되어 카드가 취향으로만 갈린다. '
        '식물은 싸우는 방식이 다르다 — 스스로 움직이지 않고, 이미 그 자리에 뿌리내려 있다.',
    ]),
    ('덩굴은 한 종이 아니라 계열이다', [
        '생태도감에서 덩굴 계열은 층을 올라가며 계속 나온다. 짐승·곤충과 같은 급의 분류군이다:',
        '독덩굴(6~10층 숲·늪) · 덩굴꽃(66~70층 밀림) · 월광덩굴(96~100층 성층) · '
        '중력 매복 덩굴(121~125층 찢긴 천창).',
        '1~10층에서 지금 바로 만나는 것은 독덩굴 하나다. 나머지는 올라가며 같은 계열로 이어진다.',
    ]),
    ('셋의 결', [
        '<b>짐승(힘)</b>은 몸으로 밀어낸다 · <b>곤충(속도)</b>은 수로 덮친다 · '
        '<b>덩굴(방어)</b>은 길목을 막아 붙잡아 둔다.',
        '셋 다 같은 자리에서 다른 일을 한다 — 공격만 늘리는 대신, 버티는 한 장이 생겨 '
        '사역사로 탱커를 세울 길이 열린다.',
    ]),
    ('바뀌지 않은 것', [
        '확정 여덟 장(중갑·강골·도발·호흡·투창·연창·속박·역병)은 그대로다.',
        '길잡이 견습·숙련·장인도 그대로다 — 47차 이름을 다시 건드리지 않았다.',
    ]),
]

HEAD = """<!DOCTYPE html>
<html lang="ko">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>직업 키워드 재설계 (48차)</title>
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
  .keep{font-size:23px;font-weight:800;color:var(--fg)}
  .ax{font-size:13.5px;color:var(--dim);border:1px solid var(--line);border-radius:20px;padding:1px 8px}
  .tag{font-size:12px;border-radius:20px;padding:1px 8px;margin-left:auto}
  .done{background:#1d3326;color:var(--green);border:1px solid #2f5a40}
  .stay{background:#1c2530;color:var(--dim);border:1px solid var(--line)}
  .do{font-size:16px;color:#d3dbe6;margin:6px 0 0;line-height:1.6}
  .why{font-size:14.5px;color:var(--dim);margin:5px 0 0;line-height:1.6}
  .why::before{content:"왜  ";color:#6f8ba3}
  .box{background:var(--card);border:1px solid var(--line);border-radius:12px;
       padding:15px 16px;margin-bottom:12px;font-size:16px;line-height:1.75}
  .box h3{font-size:17px;margin:0 0 6px}
  .box p{margin:0 0 10px} .box p:last-child{margin:0}
  table{width:100%;border-collapse:collapse;font-size:15px;margin:4px 0 8px}
  th,td{text-align:left;padding:7px 6px;border-bottom:1px solid var(--line);vertical-align:top}
  th{color:var(--dim);font-weight:600;font-size:13.5px}
  td.n{font-weight:700;white-space:nowrap}
  .cand{background:var(--card2);border-radius:10px;padding:10px 12px;margin-bottom:8px}
  .ch{display:flex;align-items:baseline;gap:8px;flex-wrap:wrap}
  .ch b{font-size:16px}
  .cf{font-size:13px;color:var(--dim);border:1px solid var(--line);border-radius:20px;padding:1px 8px}
  .cand p{margin:5px 0 0;font-size:15px;line-height:1.6;color:#c8d2de}
  .cand.no .ch b{color:#d99a9a}
  .foot{color:var(--dim);font-size:14px;line-height:1.7;margin-top:28px}
  code{background:#0b0e12;border:1px solid var(--line);border-radius:5px;padding:0 4px;font-size:14px}
</style>
</head>
<body>
<h1>직업 키워드 재설계 — 48차</h1>
<p class="lead">사역사 세 번째를 동물로 채우지 않아도 된다는 지시를 받아 생태도감을 다시 뒤졌다.
<b>뱀</b>을 빼고 <b>덩굴</b>을 넣었다 — 부리는 것의 결이 셋으로 갈린다. 확정 여덟 장과
길잡이 계급어는 손대지 않았다. 아래 값은 전부 <code>job_tree.json</code> 에서 읽었다.</p>
"""

FOOT = """<p class="foot">
  데이터: <code>data/job_tree.json</code> · 생태도감: <code>data/ecology_codex.json</code> ·
  생성기: <code>sim/center/sims/gen_keyword_48.py</code><br>
  직업 id·카드 id 는 그대로다(<code>l2_hunter</code> · <code>kw_hunter_lure</code>).<br>
  숙련도·AI 연동 규칙과 <code>docs/gdd/</code> 쪽 직업 표는 아직 이번 값이 아니다.
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
    l1name = {j['id']: j['name'] for j in jobs if j['stage'] == 1}

    n_changed = sum(1 for _, _, cs in PROPOSALS for now, old, _ in cs if old)
    out = [HEAD]
    out.append('<div class="box">'
               f'<b>카드 {n_changed}장 교체 · 확정 8장 · 직업 {len(PROPOSALS)}개</b><br>'
               '사역사 한 장만 바꾸고 나머지는 값 그대로 확인했다.</div>')

    group_now = None
    for job_name, note, cards in PROPOSALS:
        job = find_job(jobs, job_name)
        if job is None:
            raise SystemExit(f'FAIL — 데이터에 없는 직업: {job_name}')
        group = l1name.get(job.get('parentId'), '?')
        if group != group_now:
            out.append(f'<h2 class="sec">{group}</h2>')
            group_now = group

        out.append('<section class="job">')
        out.append(f'<div class="jh"><span class="l1">{group}</span><h3>{job_name}</h3></div>')
        out.append(f'<p class="jdesc">{job.get("desc", "")}</p>')
        if note:
            out.append(f'<p class="note">{note}</p>')

        now_names = {n for n, _, _ in cards}
        for now, old, why in cards:
            cur = find_card(job, now)
            if cur is None:
                raise SystemExit(f'FAIL — {job_name} 에 없는 카드: {now}')
            if (job_name, now) in CONFIRMED:
                tag = '<span class="tag done">확정</span>'
                name_html = f'<span class="keep">{now}</span>'
            elif old:
                tag = '<span class="tag done">교체</span>'
                if old in [k['name'] for k in job.get('keywords') or []] and old not in now_names:
                    raise SystemExit(f'FAIL — {job_name} 에 옛 카드가 아직 있다: {old}')
                name_html = (f'<span class="old">{old}</span><span class="arrow">→</span>'
                             f'<span class="new">{now}</span>')
            else:
                tag = '<span class="tag stay">유지</span>'
                name_html = f'<span class="keep">{now}</span>'
            out.append('<div class="card">')
            out.append(f'<div class="chead">{name_html}'
                       f'<span class="ax">{cur["shape"]}</span>{tag}</div>')
            out.append(f'<p class="do">{cur["desc"]}</p>')
            if why:
                out.append(f'<p class="why">{why}</p>')
            out.append('</div>')

        if job_name == '사역사':
            out.append('<h3 style="font-size:15px;color:var(--dim);margin:16px 0 4px">'
                       '생태도감에서 확인한 덩굴 계열</h3>')
            out.append('<table><tr><th>개체</th><th>층</th><th>서식지</th></tr>')
            for name, floors, hab in VINE_SPECIES:
                e = codex.get(name)
                if e is None:
                    raise SystemExit(f'FAIL — 생태도감에 없는 개체: {name}')
                if str(e['floors']) != floors:
                    raise SystemExit(f'FAIL — 층이 다르다: {name} {e["floors"]} != {floors}')
                out.append(f'<tr><td class="n">{name}</td><td>{floors}</td><td>{hab}</td></tr>')
            out.append('</table>')

            out.append('<h3 style="font-size:15px;color:var(--dim);margin:16px 0 4px">'
                       '후보와 버린 이유</h3>')
            for name, floors, why in CANDIDATES:
                cls = 'cand no' if name != '덩굴' else 'cand'
                out.append(f'<div class="{cls}">'
                           f'<div class="ch"><b>{name}</b><span class="cf">{floors}층</span></div>'
                           f'<p>{why}</p></div>')
        out.append('</section>')

    out.append('<h2 class="sec">남은 판단</h2>')
    for title, paras in NOTES:
        out.append('<div class="box">')
        out.append(f'<h3>{title}</h3>')
        for p in paras:
            out.append(f'<p>{p}</p>')
        out.append('</div>')

    out.append(FOOT)
    with open(OUT, 'w', encoding='utf-8') as fh:
        fh.write('\n'.join(out))
    print(f'OK — {OUT} ({os.path.getsize(OUT):,} bytes) · 교체 {n_changed}')


if __name__ == '__main__':
    main()
