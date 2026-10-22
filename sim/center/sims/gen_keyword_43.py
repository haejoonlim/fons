#!/usr/bin/env python3
"""43차 키워드 재설계 — 사용자가 지목한 11곳을 다시 세운 라운드.

왜 스크립트인가:
    이름·축·설명을 손으로 HTML 에 적으면 데이터가 바뀔 때 페이지가 조용히
    거짓말을 한다. 여기서는 **지금 값은 job_tree.json 에서** 읽고, 이 파일에는
    '무엇이 무엇이 됐나'와 '왜'만 적는다. 새 카드가 데이터에 없거나 옛 이름이
    아직 남아 있으면 즉시 실패한다.

사용: ./.venv/bin/python sim/center/sims/gen_keyword_43.py
출력: docs/design/키워드_설계안_43차.html
"""
import json
import os

TOOLS = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(TOOLS)))
TREE = os.path.join(ROOT, 'data', 'job_tree.json')
OUT = os.path.join(ROOT, 'docs', 'design', '키워드_설계안_43차.html')

# (직업명, 바뀐 직업명 or None, 지적, [(지금 카드, 이전 카드 or None, 왜)])
PROPOSALS = [
    ('철벽기사', None, '"버팀을 중갑으로, 방어가 중갑. 체력은 새로"', [
        ('중갑', '버팀', '갑옷이 힘을 받는 방어 카드로 자리를 옮겼다. 축은 방어 그대로다.'),
        ('골격', '중갑', '체력 카드는 새로 만들었다. 판을 겹쳐 대는 대신 뼈대가 굵어져 맞은 만큼을 담는다.'),
        ('요새', None, None),
    ]),
    ('전위기사', None, '"연타 일단 확정 · 쇄도는 돌파랑 겹치니까 다시"', [
        ('연타', None, None),
        ('도발', '쇄도', '쇄도는 돌파와 같은 "밀고 나간다"였다. 새 카드는 밀지 않고 끌어당긴다 — '
                        '적의 시선을 제 쪽에 붙여 뒤에 선 사람이 지나갈 길을 연다.'),
        ('돌파', None, None),
    ]),
    ('성기사', None, '"헌신 확정"', [
        ('성역', None, None),
        ('축성', None, None),
        ('헌신', None, None),
    ]),
    ('맹독사', None, '"부식도 확정"', [
        ('급독', None, None),
        ('중독', None, None),
        ('부식', None, None),
    ]),
    ('명사수', None, '"급소 확정"', [
        ('정밀', None, None),
        ('급소', None, None),
        ('원사', None, None),
    ]),
    ('포화사수', None, '"선회는 아예 컨셉을 새로"', [
        ('속사', None, None),
        ('일제', '선회', '돌며 쏘는 그림을 버렸다. 한 번에 여러 발을 같은 선에 늘어놓아 '
                        '그 선을 지나가는 것을 모두 꿰는 사격형이다.'),
        ('제압', None, None),
    ]),
    ('사역사', None, '"다룰 수 있는 동물 조율가가 키워드의 핵심 · 좀 다양하게"', [
        ('합공', '물기', '늑대 무리(6~10층 숲·평원). 짐승의 동작이 아니라 명령을 카드로 삼았다.'),
        ('추격', '몰이', '들매(1~5층 초원). 도망치는 것을 놓치지 않는 역할을 맡긴다.'),
        ('경호', '등짐', '곰(6~10층 숲). 셋째는 공격이 아니라 지키는 자리다.'),
    ]),
    ('창술사', None, '"관철만 놔두고 나머지는 다 재설계"', [
        ('창벽', '직사', '찌르기만 있는 무기가 아니다. 여럿이 나란히 세우면 벽이 된다 — 방어 축.'),
        ('관철', None, None),
        ('소탕', '항전', '버티는 카드는 전위기사와 겹쳤다. 창을 크게 휘두르는 쪽으로 바꿨다 — 속도 축.'),
    ]),
    ('주술사', None, '"해봉을 컨셉으로 잡으면 낙인 키워드가 같이 다녀야 한다"', [
        ('낙인', None, None),
        ('매듭', '대가', '낙인 다음에 오는 자리를 "값을 치른다"에서 "묶어 둔다"로 바꿨다. '
                        '남긴 표식마다 실을 걸어 두면 해봉이 풀릴 때 더 무겁게 터진다.'),
        ('해봉', None, None),
    ]),
    ('드루이드', None, '"산림과 변신을 둘 다 쓰는 만능인으로"', [
        ('순환', '수맥', '숲을 세우는 쪽(산림)과 몸을 바꾸는 쪽(변신)을 오간다. 한쪽만 고르던 자리를 없앴다.'),
        ('산림', None, None),
        ('변신', None, None),
    ]),
    ('길잡이', '땜장이', '"땜장이 아예 다시 새로운 직업으로"', [
        ('선도', '때움', '앞에 서서 길을 열고 먼저 나간다 — 지원가의 빈 축은 사람이 아니라 "길과 지형"이었다.'),
        ('살핌', '담금', '먼저 둘러보고 약한 곳과 위험한 곳을 알아 둔다.'),
        ('우회', '맞춤', '위험한 길을 돌아가 덜 맞는다.'),
    ]),
]

CONFIRMED = {('전위기사', '연타'), ('성기사', '성역'), ('성기사', '축성'), ('성기사', '헌신'),
             ('맹독사', '부식'), ('명사수', '급소'), ('주술사', '낙인'), ('주술사', '해봉'),
             ('창술사', '관철')}

GROUPS = ('수호자', '암살자', '궁수', '전사', '마법사', '지원가')

NOTES = [
    ('중갑을 어느 카드로 읽었나', [
        '"버팀을 중갑으로"를 <b>방어 카드의 이름을 중갑으로</b> 바꾸는 것으로 읽었다. '
        '체력 카드는 새 이름 <b>골격</b>을 받았다. 반대 뜻이었으면 두 줄만 바꾸면 된다.',
    ]),
    ('사역사 — 짐승이 아니라 명령이 카드다', [
        '42차는 짐승의 동작(물기·몰이·등짐)을 카드로 썼다. 그러면 짐승이 주인공이고 사역사는 구경꾼이 된다. '
        '세 장을 <b>명령</b>으로 바꿔, 늑대 무리·들매·곰 셋을 부리는 조율을 보이게 했다.',
        "'사역사'는 사전에 없는 조어다. 뜻은 직업 설명이 풀어 준다. 자연스러운 대안은 <b>야수 조련사</b>.",
    ]),
    ('주술사 — 낙인과 해봉은 한 벌', [
        '낙인(남긴다) → 매듭(묶는다) → 해봉(푼다). 해봉만 따로 두면 터뜨릴 것이 없다. '
        '세 장이 <b>표식 하나의 일생</b>이 되어 같이 다닌다.',
    ]),
    ('길잡이 — 왜 새 직업인가', [
        '지원가의 다른 넷은 사람을 고치거나(성술사·신관) 상태를 바꾸거나(정신술사) 자연을 쓴다(드루이드). '
        '비어 있던 축은 <b>길과 지형</b>이다 — 먼저 걷고, 먼저 보고, 돌아간다.',
        '37차에 폐기된 <b>정찰</b>과 다르다. 적을 살펴 보고하는 것이 아니라 지나갈 길을 여는 쪽이다.',
    ]),
]

HEAD = """<!DOCTYPE html>
<html lang="ko">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>직업 키워드 재설계 (43차)</title>
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
<h1>직업 키워드 재설계 — 43차</h1>
<p class="lead">지목한 11곳을 다시 세운 라운드다. 아래 값은 전부 <code>job_tree.json</code> 에서
읽었고, 생성기 R1~R11 을 통과한 뒤의 값이다. 회색 표시는 손대지 않은 카드다.</p>
"""

FOOT = """<p class="foot">
  데이터: <code>data/job_tree.json</code> · 생성기: <code>sim/center/sims/gen_keyword_43.py</code><br>
  직업 id 는 그대로다(<code>l2_hunter</code> · <code>l2_magearrow</code> · <code>l2_strategist</code>).
  땜장이는 폐지하고 <code>l2_strategist</code> 자리에 길잡이를 세웠다.
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
    l1name = {j['id']: j['name'] for j in jobs if j['stage'] == 1}

    n_changed = sum(1 for _, _, _, cs in PROPOSALS for now, old, _ in cs if old)
    n_jobs = sum(1 for _, old, _, _ in PROPOSALS if old)
    out = [HEAD]
    out.append('<div class="box">'
               f'<b>카드 {n_changed}장 교체 · 직업 {n_jobs}개 교체</b><br>'
               '확정이라 답한 카드(연타·헌신·부식·급소·성역·축성·낙인·관철)는 그대로 두었다.</div>')

    group_now = None
    for job_name, job_old, note, cards in PROPOSALS:
        job = find_job(jobs, job_name)
        if job is None:
            raise SystemExit(f'FAIL — 데이터에 없는 직업: {job_name}')
        group = l1name.get(job.get('parentId'), '지원가')
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
        out.append(f'<p class="jdesc">{job.get("desc", "")}</p>')
        if note:
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
                # 舊 이름이 데이터에 남아 있으면 실패한다. 단, 그 이름이 이번에 다른 카드의
                # 새 이름으로 다시 쓰인 경우(중갑)는 제외한다.
                now_names = {n for n, _, _ in cards}
                if old in [k['name'] for k in job.get('keywords') or []] and old not in now_names:
                    raise SystemExit(f'FAIL — {job_name} 에 옛 카드가 아직 있다: {old}')
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
    print(f'OK — {OUT} ({os.path.getsize(OUT):,} bytes) · 교체 {n_changed} · 직업 {n_jobs}')


if __name__ == '__main__':
    main()
