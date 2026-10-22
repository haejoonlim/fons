#!/usr/bin/env python3
"""46차 키워드 재설계 — 사역사 짐승 통합 · 길잡이 위계 · 확정 네 장.

왜 스크립트인가:
    이름·축·설명을 손으로 HTML 에 적으면 데이터가 바뀔 때 페이지가 조용히
    거짓말을 한다. 여기서는 **지금 값은 job_tree.json 에서** 읽고, 이 파일에는
    '무엇이 무엇이 됐나'와 '왜'만 적는다. 새 카드가 데이터에 없거나 옛 이름이
    아직 남아 있으면 즉시 실패한다.

사용: ./.venv/bin/python sim/center/sims/gen_keyword_46.py
출력: docs/design/키워드_설계안_46차.html
"""
import json
import os

TOOLS = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(TOOLS)))
TREE = os.path.join(ROOT, 'data', 'job_tree.json')
OUT = os.path.join(ROOT, 'docs', 'design', '키워드_설계안_46차.html')

PROPOSALS = [
    ('사역사', '"조류·포유를 짐승으로 합치고, 생태사전에서 한 무리 더"', [
        ('짐승', '조류+포유', '날짐승(매·들매)과 길짐승(늑대·곰·멧돼지)을 한 카드로 묶었다. '
                             '나눠 두면 같은 몸을 두 번 세게 되고, 한 마리만 부르는 카드처럼 읽혔다.'),
        ('곤충', None, '그대로 둔다. 떼로 덮치는 쪽은 다른 무리와 겹치지 않는다.'),
        ('뱀', '포유 자리', '생태사전에서 골랐다 — 들뱀(1~5층 초원)·독사(6~10층 사막·숲·늪). '
                           '낮은 자세로 기어들어 급소를 물어, 밀어붙이는 짐승·덮치는 곤충과 결이 다르다.'),
    ]),
    ('창술사', '"투창 확정 · 연창 확정"', [
        ('투창', None, None),
        ('관철', None, None),
        ('연창', None, None),
    ]),
    ('주술사', '"역병 확정(저주가 퍼지는 느낌) · 속박 확정"', [
        ('낙인', None, None),
        ('속박', None, None),
        ('역병', None, None),
    ]),
    ('길잡이', '"위계가 이름에서 안 보인다 — 다시 설계"', [
        ('발자국', '답사', '1단계. 지나간 흔적을 읽는다 — 남이 남긴 것.'),
        ('표식', '인도', '2단계. 읽은 길에 내 표를 세운다 — 내가 남긴 것.'),
        ('이정표', '개척', '3단계. 표가 길의 기준이 된다 — 모두가 따르는 것.'),
    ]),
]

CONFIRMED = {('창술사', '투창'), ('창술사', '연창'), ('주술사', '속박'), ('주술사', '역병'),
             ('주술사', '낙인'), ('창술사', '관철')}

# 길잡이 3단계 — 데이터의 이름·설명은 여기서 읽고, '무엇이 자라나는가'만 손으로 적는다.
LADDER = [
    ('발자국', '읽는다', '흔적이 어디로 이어졌는지 알아낸다.'),
    ('표식', '남긴다', '읽은 길에 표를 세워 뒤따르는 이가 헷갈리지 않는다.'),
    ('이정표', '정한다', '표가 길의 기준이 되어 다음 이동이 처음부터 짧아진다.'),
]

NOTES = [
    ('이번 라운드에 확정된 것', [
        '중갑 · 강골 · 도발 · 호흡 · <b>투창</b> · <b>연창</b> · <b>속박</b> · <b>역병</b>.',
        '역병은 이름을 그대로 두고 설명만 "저주가 퍼지는" 그림으로 남겼다 — 옮은 병이 곁으로 번져 '
        '방어를 지나 안에서 썩는다.',
    ]),
    ('사역사 — 짐승 하나로 합쳤다', [
        '조류(매·들매)와 포유(늑대·곰·멧돼지)는 한 카드로 묶으면 "날짐승과 길짐승"이 된다. '
        '두 장으로 나눠 두면 사역사가 부리는 것이 여섯 장 중 두 장에 걸쳐 있어, '
        '한 번에 한 무리만 부르는 카드처럼 읽혔다.',
        '셋의 축은 <b>힘(짐승) · 속도(곤충) · 치명(뱀)</b> 로 갈린다. 겹치는 축이 없다.',
    ]),
    ('사역사 — 뱀은 어디서 왔나', [
        '생태사전(<code>ecology_codex.json</code>)의 1~10층 개체 중 아직 사역사 손에 없던 무리를 골랐다. '
        '뱀은 들뱀(1~5층 초원)과 독사(6~10층 사막·숲·늪) 두 개체가 있다.',
        '물가(개구리·두꺼비)와 물속(거대 게·산호상어)도 후보였지만, 물가는 6~10층 한 층에만 걸치고 '
        '물속은 11층부터라 1~10층 사역사 손에 닿지 않는다. 뱀은 두 층 모두에서 만난다.',
    ]),
    ('길잡이 — 이름에서 위계가 보이게', [
        '앞의 셋(답사·인도·개척)은 뜻이 좋아도 <b>어느 것이 위인지 이름만으로 알 수 없었다</b>. '
        '그래서 길 위에 남는 표시 셋으로 바꾸고, 남는 시간이 길어지는 순서로 놓았다: '
        '발자국 → 표식 → 이정표.',
        '<b>흔적(남이 남긴 것) → 표시(내가 남긴 것) → 기준(모두가 따르는 것).</b> '
        '뒤로 갈수록 오래 남고, 더 많은 사람이 그것을 따른다.',
        '세 장의 축은 치명 · 민첩 · 마나 그대로다. 이름과 설명만 위계에 맞췄다 — '
        '숙련도로 3단계가 열리면 같은 능력이 읽기 → 남기기 → 정하기로 자란다.',
    ]),
    ('아직 정하지 않은 것', [
        '숙련도가 무엇으로 오르고, 몇에서 카드가 바뀌는지는 가안이다. AI 연동 규칙도 아직 없다.',
        '카드가 바뀔 때 세 장이 <b>동시에</b> 오르는지, <b>하나씩</b> 열리는지도 미정이다 — '
        '동시에 오르면 3단계가 곧 상위 호환이 되어 1·2단계를 다시 볼 이유가 사라진다.',
    ]),
]

HEAD = """<!DOCTYPE html>
<html lang="ko">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>직업 키워드 재설계 (46차)</title>
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
  .sname{font-size:21px;font-weight:800}
  .sax{font-size:13px;color:var(--dim);border:1px solid var(--line);border-radius:20px;padding:1px 8px}
  .sgrow{font-size:14.5px;color:var(--dim);line-height:1.6;margin-top:4px}
  .sgrow b{color:#cfe4f7;font-weight:700}
  .foot{color:var(--dim);font-size:14px;line-height:1.7;margin-top:28px}
  code{background:#0b0e12;border:1px solid var(--line);border-radius:5px;padding:0 4px;font-size:14px}
</style>
</head>
<body>
<h1>직업 키워드 재설계 — 46차</h1>
<p class="lead">확정한 여덟 이름은 손대지 않았다. 사역사는 조류·포유를 <b>짐승</b>으로 합치고 생태사전에서
<b>뱀</b>을 들였고, 길잡이는 이름만으로 위계가 읽히도록 다시 지었다. 아래 값은 전부
<code>job_tree.json</code> 에서 읽었다.</p>
"""

FOOT = """<p class="foot">
  데이터: <code>data/job_tree.json</code> · 생성기: <code>sim/center/sims/gen_keyword_46.py</code><br>
  직업 id 는 그대로다(<code>l2_hunter</code> · <code>l2_magearrow</code> · <code>l2_hexcaller</code> · <code>l2_strategist</code>).
  카드 id 도 그대로 두었다 — 이름만 바뀐 카드가 둘 이상이라 id 까지 바꾸면 저장된 참조가 끊긴다.<br>
  길잡이의 숙련도·AI 연동 규칙과 <code>docs/gdd/</code> 쪽 직업 표는 아직 이번 값이 아니다.
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
    """길잡이 3단계 — 데이터의 이름·설명을 단계 순서대로 세운다.

    검사: LADDER 순서와 데이터의 설명 앞머리(1단계·2단계·3단계)가 어긋나면 실패.
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
               f'<b>카드 {n_changed}장 재설계 · 확정 8장 · 직업 {len(PROPOSALS)}개</b><br>'
               '확정한 이름은 그대로 두고, 지적이 들어온 두 직업만 다시 세웠다.</div>')

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
                for o in old.split('+'):
                    o = o.strip()
                    if o in [k['name'] for k in job.get('keywords') or []] and o not in now_names:
                        raise SystemExit(f'FAIL — {job_name} 에 옛 카드가 아직 있다: {o}')
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
