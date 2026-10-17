#!/usr/bin/env python3
"""42차 키워드 재설계 — 이름 톤을 나무 전체에 맞춘 라운드.

왜 스크립트인가:
    이름·축·설명을 손으로 HTML 에 적으면 데이터가 바뀔 때 페이지가 조용히
    거짓말을 한다. 여기서는 **지금 값은 job_tree.json 에서** 읽고, 이 파일에는
    '무엇에서 무엇으로 바뀌었나'와 '왜'만 적는다. old 카드가 데이터에 없으면
    즉시 실패하므로 거짓 표시가 불가능하다.

사용: ./.venv/bin/python sim/center/sims/gen_keyword_42.py
출력: docs/design/키워드_설계안_42차.html
"""
import json
import os

TOOLS = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(TOOLS)))
TREE = os.path.join(ROOT, 'data', 'job_tree.json')
OUT = os.path.join(ROOT, 'docs', 'design', '키워드_설계안_42차.html')

GROUPS = {
    '철벽기사': '수호자', '전위기사': '수호자', '성기사': '수호자',
    '맹독사': '암살자',
    '포화사수': '궁수', '명사수': '궁수', '사역사': '궁수',
    '창술사': '전사',
    '주술사': '마법사',
    '드루이드': '지원가', '땜장이': '지원가',
}

# (지금 직업명, 이전 직업명, 직업 설명, 지적, [(지금 카드, 이전 카드, 왜)])
PROPOSALS = [
    ('철벽기사', None, None, '"중갑이 좋았는데 그걸로 · 맷집은 너무 멋없다"', [
        ('버팀', None, None),
        ('중갑', '맷집',
         '체력 카드는 갑옷 판을 겹겹이 대는 쪽으로 돌아간다. 버팀(방어)은 그대로 — '
         '버팀이 갑옷이 힘을 받는 카드, 중갑이 판을 두껍게 대는 카드다.'),
        ('요새', None, None),
    ]),
    ('전위기사', None, None, '"두들기기·방패치기는 돌파랑 톤이 다르다"', [
        ('연타', '두들기기',
         '돌파와 같은 두 글자 동작 이름으로 맞췄다. 앞에 선 것을 쉬지 않고 연달아 때린다.'),
        ('쇄도', '방패치기',
         '한꺼번에 몰려들어 자리를 밀어내는 쪽. 방패 하나를 강조하던 그림을 지웠다.'),
        ('돌파', None, None),
    ]),
    ('성기사', None, None, '"성역·축성은 확정 · 대신맞기는 이름이 이상하다"', [
        ('성역', None, None),
        ('축성', None, None),
        ('헌신', '대신맞기',
         '성역(땅) · 축성(남의 갑옷)과 같은 두 글자 한자어로 맞췄다. 곁의 몫까지 제 몸으로 받는다.'),
    ]),
    ('맹독사', None, '독을 넣고, 쌓고, 갉아 내는 직업', '"녹이기도 이름이 따로 논다"', [
        ('급독', None, None),
        ('중독', None, None),
        ('부식', '녹이기',
         '급독·중독과 같은 두 글자 한자어로 맞췄다. 독이 갑옷을 갉아 방어를 지나 안쪽까지 든다.'),
    ]),
    ('포화사수', None, None, '"발놀림도 이름이 따로 논다"', [
        ('속사', None, None),
        ('선회', '자리옮김',
         '원래 있던 두 글자 이름으로 되돌렸다. 돌며 쏘아 매번 각도를 바꾼다.'),
        ('제압', None, None),
    ]),
    ('명사수', None, None, '"급소 확정"', [
        ('정밀', None, None),
        ('급소', None, None),
        ('원사', None, None),
    ]),
    ('사역사', None, '짐승에게 일을 맡기고 그 뒤에 붙어 함께 움직이는 직업',
     '"바이옴에서 사역할 만한 것을 찾아 셋으로 나눠서"', [
        ('물기', '물어뜯기',
         '생태도감의 늑대(6~10층 · 숲·평원). 목덜미를 물어 붙잡는 일을 맡긴다.'),
        ('몰이', '끌려가기',
         '생태도감의 들매(1~5층 · 초원). 띄워서 도망갈 길을 미리 막는다.'),
        ('등짐', '매달리기',
         '생태도감의 표류수리(11~15층 · 산호·바다). 건져 올린 것을 지고도 걸음을 놓지 않는다.'),
    ]),
    ('창술사', '작살꾼', '창끝을 먼저 내밀어 거리를 지키는 직업',
     '"작살꾼 대신 전사로 창술 직업"', [
        ('직사', '내리꽂기',
         '창끝을 곧게 내질러 한 사람만 찌른다 — 힘 축.'),
        ('관철', '당겨오기',
         '판을 뚫고 뒤에 선 것까지 꿰뚫는다 — 관통 축.'),
        ('항전', '줄감기',
         '물러서지 않고 창을 세워 버틴다 — 근성 축.'),
    ]),
    ('주술사', None, '적에게 낙인을 남기고, 값을 치러 키운 뒤, 한 번에 터뜨리는 직업',
     '"낙인 확정 · 나머지도 다른 애들이랑 맞게"', [
        ('낙인', None, None),
        ('대가', '몸바치기',
         '제 몸을 값으로 내주고 표식을 키운다 — 두 글자로 줄였다.'),
        ('해봉', '걷어내기',
         '묶어 둔 표식을 풀어 터뜨린다 — 낙인과 짝이 되는 봉인 용어.'),
    ]),
    ('드루이드', None, None, '"새로 만든 이름이 다 이상하다"', [
        ('수맥', '뿌리내림',
         '발밑의 땅을 타고 흐르는 기운을 끌어올린다. 개화(꽃)·산림(숲)·변신(몸)과 겹치지 않는 네 번째 그림.'),
        ('산림', None, None),
        ('변신', None, None),
    ]),
    ('땜장이', '연막수', '아군의 갑옷과 무기를 그 자리에서 고쳐 주는 직업',
     '"연막수는 아예 새 직업으로"', [
        ('때움', '연기막',
         '뚫린 갑옷을 그 자리에서 때워 막는다 — 방어 축.'),
        ('담금', '몸낮춤',
         '달군 쇠를 식혀 주문을 견디게 한다 — 마법방어 축.'),
        ('맞춤', '목졸림',
         '손에 맞게 고쳐 한 번의 무게를 살린다 — 힘 축.'),
    ]),
]

# 확정 — 데이터에 들어간 채로 사용자가 "확정"이라고 말한 카드
CONFIRMED = {('성기사', '성역'), ('성기사', '축성'), ('명사수', '급소'), ('주술사', '낙인')}

NOTES = [
    ('이번 라운드의 이름 규칙', [
        '41차는 뜻을 살리려고 긴 서술형 이름을 썼는데, 나무 전체의 톤(버팀·요새·돌파·급독·중독·낙인)과 '
        '따로 놀았다. 이번에는 <b>두 글자 동작·명사</b>로 맞췄다.',
        '되살린 이름 셋 — <b>중갑</b>(체력) · <b>몰이</b>(민첩) · <b>선회</b>(민첩). '
        '죽은 이름 목록에서 빼서 다시 쓸 수 있게 했고, 41차에 만든 긴 이름들은 목록에 넣어 되살아나지 않게 했다.',
    ]),
    ('사역사 — 생태도감 근거', [
        '세 장을 각각 실제 서식종에 붙였다. <b>늑대</b>(6~10층 · 숲·평원) = 물기 · '
        '<b>들매</b>(1~5층 · 초원) = 몰이 · <b>표류수리</b>(11~15층 · 산호·바다) = 등짐.',
        "'사역사'는 사전에 없는 조어다. 이름은 지정대로 두고, 직업 설명이 뜻을 바로 풀게 썼다. "
        "자연스러운 대안은 <b>야수 조련사</b>.",
    ]),
    ('창술사 — 자리를 옮겼다', [
        '작살꾼(원래 마궁사 자리)을 지우고 <b>전사 » 창술사</b>로 옮겼다. 궁수는 다시 세 갈래'
        '(명사수·포화사수·사역사), 전사는 여섯 갈래가 된다.',
        '직업 id 는 <code>l2_magearrow</code> 그대로다 — 키워드 배율표가 id 를 키로 쓰기 때문에 '
        'id 를 바꾸면 세 카드의 power 가 초기값으로 떨어진다. 주석으로만 남겼다.',
    ]),
    ('땜장이 — 왜 새 직업인가', [
        '전투 중에 <b>아군의 갑옷과 무기를 고친다</b>. 사람을 낫게 하는 치유(성술사·신관)도, '
        '명령을 내리는 지휘(전술가)도, 적의 상태를 바꾸는 정신술사도 아니다.',
        'L4 적성 <b>대장장이</b>와 구분된다 — 대장장이는 영지에서 만들고, 땜장이는 전장에서 때운다.',
    ]),
]

HEAD = """<!DOCTYPE html>
<html lang="ko">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>직업 키워드 재설계 (42차)</title>
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
  .foot{color:var(--dim);font-size:14px;line-height:1.7;margin-top:28px}
</style>
</head>
<body>
<h1>직업 키워드 재설계 — 42차</h1>
<p class="lead">이름 톤을 나무 전체에 맞춘 라운드다. 아래 값은 전부 <code>job_tree.json</code> 에서
읽었고, 생성기 R1~R11 을 통과한 뒤의 값이다. 회색 표시는 손대지 않은 카드다.</p>
"""

FOOT = """<p class="foot">
  데이터: <code>data/job_tree.json</code> · 생성기: <code>sim/center/sims/gen_keyword_42.py</code><br>
  직업 id 는 그대로다(<code>l2_hunter</code> · <code>l2_magearrow</code> · <code>l2_strategist</code>).
  이번에 부모가 바뀐 것은 <code>l2_magearrow</code>(궁수 → 전사) 하나다.
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
        root = json.load(fh)
    jobs = root['jobs']

    n_changed = sum(1 for _, _, _, _, cs in PROPOSALS for now, old, _ in cs if old)
    n_keep = sum(1 for _, _, _, _, cs in PROPOSALS for now, old, _ in cs if not old)
    n_jobs = sum(1 for _, old, _, _, _ in PROPOSALS if old)

    out = [HEAD]
    out.append('<div class="box">'
               f'<b>카드 {n_changed}장 교체 · 직업 {n_jobs}개 교체 · 유지 {n_keep}장</b><br>'
               '확정된 네 장(성역·축성·급소·낙인)은 그대로 두고, 나머지를 기존 나무의 '
               '두 글자 이름으로 맞췄다.</div>')

    group_now = None
    for job_name, job_old, job_desc, note, cards in PROPOSALS:
        job = find_job(jobs, job_name)
        if job is None:
            raise SystemExit(f'FAIL — 데이터에 없는 직업: {job_name}')
        group = GROUPS[job_name]
        if group != group_now:
            out.append(f'<h2 class="sec">{group}</h2>')
            group_now = group

        out.append('<section class="job">')
        head = f'<span class="l1">{group}</span>'
        if job_old:
            head += (f'<h3>{job_old}</h3><span class="arrow">→</span>'
                     f'<h3>{job_name}</h3>')
        else:
            head += f'<h3>{job_name}</h3>'
        out.append(f'<div class="jh">{head}</div>')
        out.append(f'<p class="jdesc">{job_desc or job.get("desc", "")}</p>')
        out.append(f'<p class="note">{note}</p>')

        for now, old, why in cards:
            cur = find_card(job, now)
            if cur is None:
                raise SystemExit(f'FAIL — {job_name} 에 없는 카드: {now}')
            if (job_name, now) in CONFIRMED:
                tag = '<span class="tag done">확정</span>'
                name_html = f'<span class="keep">{now}</span>'
            elif old:
                tag = '<span class="tag done">교체</span>'
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
    print(f'OK — {OUT} ({os.path.getsize(OUT):,} bytes) · 교체 {n_changed} · 직업 {n_jobs} · 유지 {n_keep}')


if __name__ == '__main__':
    main()
