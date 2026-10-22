#!/usr/bin/env python3
"""50차 키워드 재설계 — 사역사 세 번째를 '생각하는 무리'(마귀)로.

왜 스크립트인가:
    이름·축·설명을 손으로 HTML 에 적으면 데이터가 바뀌면 페이지가 조용히
    거짓말을 한다. 여기서는 **지금 값은 job_tree.json 에서** 읽고, 이 파일에는
    '무엇이 무엇이 됐나'와 '왜'만 적는다. 새 카드가 데이터에 없거나 옛 이름이
    아직 남아 있으면 실패한다. 근거로 인용한 생태도감 개체도 없으면 실패한다.

사용: ./.venv/bin/python sim/center/sims/gen_keyword_50.py
출력: docs/design/키워드_설계안_50차.html
"""
import json
import os

TOOLS = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(TOOLS)))
TREE = os.path.join(ROOT, 'data', 'job_tree.json')
CODEX = os.path.join(ROOT, 'data', 'ecology_codex.json')
OUT = os.path.join(ROOT, 'docs', 'design', '키워드_설계안_50차.html')

PROPOSALS = [
    ('사역사', '"덩굴은 식물이라 못 부린다 — 사고가 되는 개체여야"', [
        ('짐승', None, None),
        ('곤충', None, None),
        ('마귀', '덩굴', '식물은 시킬 일이 없다. 생각으로 움직이는 무리를 세운다 — '
                       '흉고블린·코볼드·임프는 도구를 들고 덫을 놓는다.'),
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
        ('길눈', None, None),
        ('길꾼', None, None),
        ('길지기', None, None),
    ]),
]

CONFIRMED = {('창술사', '투창'), ('창술사', '연창'), ('창술사', '관철'),
             ('주술사', '낙인'), ('주술사', '속박'), ('주술사', '역병')}

# 생태도감에서 확인한 마귀 무리 — (개체명, 층, 서식지, 역할) · 데이터에 없으면 실패
CREW = [
    ('흉고블린', '[6, 10]', '폐허·숲', 'predator'),
    ('고블린', '[16, 20]', '동굴·폐허', 'scavenger'),
    ('코볼드', '[16, 20]', '동굴·광산', 'scavenger'),
    ('임프', '[21, 25]', '지옥불·폐허', 'scavenger'),
]

ROLE_KO = {'predator': '포식자', 'scavenger': '청소부', 'apex': '상위 포식자'}

# 버린 후보 — (이름, 층, 왜 버렸나)
REJECTED = [
    ('덩굴 (48차)', '6~130', '식물은 사고하지 못한다. 使役은 시킬 것이 있어야 성립한다.'),
    ('뱀 (46차)', '1~10', '동물 셋이 되면 짐승·곤충과 결이 겹친다.'),
    ('포자 버섯', '16~20', '균류도 사고하지 못한다.'),
    ('산호초', '11~15', '바다에 갇혀 육상 층에서 부릴 수 없다.'),
    ('고블린', '6~25', '이름으로 쓰기엔 무리의 절반만 덮는다 — 코볼드·임프가 빠진다.'),
]

NOTES = [
    ('무엇이 부릴 수 있는 것인가', [
        '使役은 시키는 일이다. 시키려면 <b>알아듣는 것</b>이어야 한다. '
        '식물은 알아듣지 못하고, 버섯은 더더욱 아니다.',
        '그래서 생태도감에서 <b>스스로 움직이고 도구를 다루는 무리</b>를 골랐다. '
        '흉고블린은 매복하고, 코볼드는 광산에서 손을 쓰고, 임프는 불을 옮긴다.',
    ]),
    ('왜 마귀인가', [
        '이 넷을 한 이름으로 묶으면 마귀다 — <b>약고, 무리를 짓고, 도구를 든다</b>.',
        '짐승·곤충과 결이 다르다. 짐승은 몸으로 밀어내고(힘), 곤충은 수로 덮고(속도), '
        '마귀는 급소를 노린다(치명).',
        '1~10층에서 바로 만나는 것은 흉고블린 하나다. 고블린·코볼드는 16~20층, '
        '임프는 21~25층에서 같은 무리로 이어진다.',
    ]),
    ('바뀌지 않은 것', [
        '확정 여덟 장(중갑·강골·도발·호흡·투창·연창·속박·역병)은 그대로다.',
        '길잡이 셋(길눈·길꾼·길지기)과 짐승·곤충도 그대로다. 이번 라운드는 사역사 한 장만 건드렸다.',
    ]),
    ('아직 정하지 않은 것', [
        '마귀를 부른 뒤 무엇을 시키는지(덫을 놓는지, 몽둥이로 때리는지)는 전투 규칙이 정해져야 한다.',
        '길잡이 숙련도 해금 규칙도 아직 가안이다.',
    ]),
]

HEAD = """<!DOCTYPE html>
<html lang="ko">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>직업 키워드 재설계 (50차)</title>
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
  .rj{background:var(--card2);border-radius:10px;padding:10px 12px;margin-bottom:8px}
  .rh{display:flex;align-items:baseline;gap:8px;flex-wrap:wrap}
  .rh b{font-size:15.5px;color:#b9c6d4}
  .rw{font-size:13px;color:var(--dim);border:1px solid var(--line);border-radius:20px;padding:1px 8px}
  .rj p{margin:5px 0 0;font-size:14.5px;line-height:1.6;color:var(--dim)}
  .rj.no .rh b{color:#d99a9a}
  .foot{color:var(--dim);font-size:14px;line-height:1.7;margin-top:28px}
  code{background:#0b0e12;border:1px solid var(--line);border-radius:5px;padding:0 4px;font-size:14px}
</style>
</head>
<body>
<h1>직업 키워드 재설계 — 50차</h1>
<p class="lead">사역사 세 번째를 <b>덩굴</b>에서 <b>마귀</b>로 바꿨다. 식물은 사고하지 못하니
시킬 일이 없고, 使役은 알아듣는 것에만 성립한다. 확정 여덟 장과 길잡이 셋은 손대지 않았다.
아래 값은 전부 <code>job_tree.json</code> 에서 읽었다.</p>
"""

FOOT = """<p class="foot">
  데이터: <code>data/job_tree.json</code> · 생태도감: <code>data/ecology_codex.json</code> ·
  생성기: <code>sim/center/sims/gen_keyword_50.py</code><br>
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
                       '생태도감에서 확인한 마귀 무리</h3>')
            out.append('<table><tr><th>개체</th><th>층</th><th>서식지</th><th>역할</th></tr>')
            for name, floors, hab, role in CREW:
                e = codex.get(name)
                if e is None:
                    raise SystemExit(f'FAIL — 생태도감에 없는 개체: {name}')
                if str(e['floors']) != floors or e['role'] != role:
                    raise SystemExit(f'FAIL — 도감 값이 다르다: {name} {e["floors"]} {e["role"]}')
                out.append(f'<tr><td class="n">{name}</td><td>{floors}</td>'
                           f'<td>{hab}</td><td>{ROLE_KO.get(role, role)}</td></tr>')
            out.append('</table>')

            out.append('<h3 style="font-size:15px;color:var(--dim);margin:16px 0 4px">'
                       '버린 후보</h3>')
            for name, floors, why in REJECTED:
                cls = 'rj no' if not name.startswith('마귀') else 'rj'
                out.append(f'<div class="{cls}">'
                           f'<div class="rh"><b>{name}</b><span class="rw">{floors}층</span></div>'
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
