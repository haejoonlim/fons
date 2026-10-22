#!/usr/bin/env python3
"""47차 키워드 재설계 — 길잡이를 **계급어**로 다시 세운 라운드.

왜 스크립트인가:
    이름·축·설명을 손으로 HTML 에 적으면 데이터가 바뀔 때 페이지가 조용히
    거짓말을 한다. 여기서는 **지금 값은 job_tree.json 에서** 읽고, 이 파일에는
    '무엇이 무엇이 됐나'와 '왜'만 적는다. 새 카드가 데이터에 없거나 옛 이름이
    아직 남아 있으면 즉시 실패한다.

사용: ./.venv/bin/python sim/center/sims/gen_keyword_47.py
출력: docs/design/키워드_설계안_47차.html
"""
import json
import os

TOOLS = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(TOOLS)))
TREE = os.path.join(ROOT, 'data', 'job_tree.json')
OUT = os.path.join(ROOT, 'docs', 'design', '키워드_설계안_47차.html')

PROPOSALS = [
    ('사역사', None, [
        ('짐승', None, None),
        ('곤충', None, None),
        ('뱀', None, None),
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
    ('길잡이', '"계급어로 위계를 못 박아라"', [
        ('견습', '발자국', '1단계. 계급 이름이 곧 순서다 — 견습은 아직 길을 모른다.'),
        ('숙련', '표식', '2단계. 걸어 본 길을 스스로 표시해 남을 데려간다.'),
        ('장인', '이정표', '3단계. 처음 가는 곳에도 길을 낸다.'),
    ]),
]

CONFIRMED = {('창술사', '투창'), ('창술사', '연창'), ('창술사', '관철'),
             ('주술사', '낙인'), ('주술사', '속박'), ('주술사', '역병')}

# 사다리 — 데이터의 이름·설명은 여기서 읽고, '무엇이 달라지는가'만 손으로 적는다.
LADDER = [
    ('견습', '따라 걷는다', '누가 남긴 길을 밟는다. 아직 스스로 세우지 못한다.'),
    ('숙련', '데려간다', '걸어 본 길을 표시해 남에게 건넨다.'),
    ('장인', '열어 준다', '없던 길을 내어 대열 전체의 다음 이동을 앞당긴다.'),
]

NOTES = [
    ('왜 계급어인가', [
        '46차는 발자국 → 표식 → 이정표로 바꿨다. 길 위에 남는 것이 커지는 그림이었지만, '
        '여전히 <b>어느 것이 위인지</b>는 읽는 사람이 추론해야 했다.',
        '견습 · 숙련 · 장인은 추론이 필요 없다. 셋 다 <b>같은 솜씨의 다른 단계</b>라고 이름이 먼저 말한다. '
        '직업 이름(길잡이)은 머리에 있고, 카드 이름은 그 직업 안의 계급만 말한다.',
    ]),
    ('계급이 오르면 무엇이 열리나', [
        '견습 · 숙련 · 장인 셋은 축이 <b>치명 · 민첩 · 마나</b> 로 갈린다. '
        '같은 솜씨의 세 단계지만 오르는 힘이 달라서, 3단계가 1단계의 상위 호환이 되지 않는다.',
        '숙련도로 3단계가 열리는 규칙 자체는 아직 가안이다. AI 연동 규칙도 아직 없다.',
    ]),
    ('바뀌지 않은 것', [
        '확정 여덟 장(중갑·강골·도발·호흡·투창·연창·속박·역병)은 이름도 설명도 그대로다.',
        '사역사 셋(짐승·곤충·뱀)과 낙인·관철도 그대로다. 이번 라운드는 길잡이 세 장만 건드렸다.',
    ]),
    ('아직 정하지 않은 것', [
        '카드가 바뀔 때 셋이 <b>동시에</b> 오르는지, <b>하나씩</b> 열리는지 미정이다. '
        '동시에 오르면 3단계만 남고 1·2단계는 지나가는 자리가 된다.',
    ]),
]

HEAD = """<!DOCTYPE html>
<html lang="ko">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>직업 키워드 재설계 (47차)</title>
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
  .lad{display:grid;grid-template-columns:1fr;gap:8px;margin:2px 0 14px}
  .step{background:var(--card2);border:1px solid var(--line);border-radius:11px;padding:11px 13px}
  .shead{display:flex;align-items:baseline;gap:9px;flex-wrap:wrap}
  .num{font-size:12.5px;font-weight:800;color:#0f1318;background:var(--accent);
       border-radius:6px;padding:1px 8px;white-space:nowrap}
  .sname{font-size:22px;font-weight:800;letter-spacing:.02em}
  .sax{font-size:13px;color:var(--dim);border:1px solid var(--line);border-radius:20px;padding:1px 8px}
  .sgrow{font-size:14.5px;color:var(--dim);line-height:1.6;margin-top:4px}
  .sgrow b{color:#cfe4f7;font-weight:700}
  .foot{color:var(--dim);font-size:14px;line-height:1.7;margin-top:28px}
  code{background:#0b0e12;border:1px solid var(--line);border-radius:5px;padding:0 4px;font-size:14px}
</style>
</head>
<body>
<h1>직업 키워드 재설계 — 47차</h1>
<p class="lead">길잡이 세 장만 다시 세웠다. 46차의 표시물 이름(발자국·표식·이정표) 대신
<b>계급어</b>(견습·숙련·장인)를 써서, 이름만 읽어도 순서가 보이게 했다. 확정 여덟 장과
사역사 셋은 손대지 않았다. 아래 값은 전부 <code>job_tree.json</code> 에서 읽었다.</p>
"""

FOOT = """<p class="foot">
  데이터: <code>data/job_tree.json</code> · 생성기: <code>sim/center/sims/gen_keyword_47.py</code><br>
  직업 id·카드 id 는 그대로다(<code>l2_strategist</code> · <code>kw_strategist_command</code> 등).<br>
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


def ladder_html(job):
    """길잡이 계급 사다리 — 데이터의 이름·설명을 1·2·3단계 순서로 세운다.

    검사: LADDER 순서와 데이터 설명 앞머리(1단계·2단계·3단계)가 어긋나면 실패.
    """
    out = ['<div class="lad">']
    for i, (name, grows, sentence) in enumerate(LADDER, start=1):
        card = find_card(job, name)
        if card is None:
            raise SystemExit(f'FAIL — 길잡이에 없는 카드: {name}')
        if not card['desc'].startswith(f'{i}단계'):
            raise SystemExit(f'FAIL — {name} 의 설명이 {i}단계로 시작하지 않는다: {card["desc"]}')
        out.append('<div class="step">')
        out.append('<div class="shead">'
                   f'<span class="num">{i}단계</span>'
                   f'<span class="sname">{name}</span>'
                   f'<span class="sax">{card["shape"]}</span></div>')
        out.append(f'<div class="sgrow"><b>{grows}</b> — {sentence}</div>')
        out.append('</div>')
    out.append('</div>')
    return '\n'.join(out)


def main():
    with open(TREE, encoding='utf-8') as fh:
        jobs = json.load(fh)['jobs']
    l1name = {j['id']: j['name'] for j in jobs if j['stage'] == 1}

    n_changed = sum(1 for _, _, cs in PROPOSALS for now, old, _ in cs if old)
    out = [HEAD]
    out.append('<div class="box">'
               f'<b>카드 {n_changed}장 교체 · 확정 8장 · 직업 {len(PROPOSALS)}개</b><br>'
               '지적이 들어온 길잡이만 다시 세우고, 나머지는 값 그대로 확인했다.</div>')

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

        if job_name == '길잡이':
            out.append(ladder_html(job))

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
