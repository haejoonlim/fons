#!/usr/bin/env python3
"""45차 키워드 재설계 — 사역사 분류군 · 창술사 · 주술사 · 길잡이.

왜 스크립트인가:
    이름·축·설명을 손으로 HTML 에 적으면 데이터가 바뀔 때 페이지가 조용히
    거짓말을 한다. 여기서는 **지금 값은 job_tree.json 에서** 읽고, 이 파일에는
    '무엇이 무엇이 됐나'와 '왜'만 적는다. 새 카드가 데이터에 없거나 옛 이름이
    아직 남아 있으면 즉시 실패한다.

사용: ./.venv/bin/python sim/center/sims/gen_keyword_45.py
출력: docs/design/키워드_설계안_45차.html
"""
import json
import os

TOOLS = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(TOOLS)))
TREE = os.path.join(ROOT, 'data', 'job_tree.json')
OUT = os.path.join(ROOT, 'docs', 'design', '키워드_설계안_45차.html')

PROPOSALS = [
    ('사역사', None, '"분류 다시 — 늑대나 곰 같은 건 꼭 포함"', [
        ('조류', None, '들매(1~5층 초원)·매(6~10층 산·평원)가 위에서 내리꽂는다 — 셋 중 가장 날카로운 축.'),
        ('곤충', None, '거대 개미·독벌(6~10층 숲·초원)이 수로 덮친다.'),
        ('포유', '수생', '늑대·곰·멧돼지(6~10층 숲·산)를 앞에 세워 밀어붙인다. 셋 중 가장 무거운 축이다.'),
    ]),
    ('창술사', None, '"투창 확정 · 걸기는 다시 설계"', [
        ('투창', None, None),
        ('관철', None, None),
        ('연창', '걸기', '걸어 당기는 일은 창이 하는 일로 읽히지 않았다. 한 번 깊게 뚫는 관철과 달리 '
                        '쉬지 않고 이어 찌르는 쪽으로 바꿨다 — 속도.'),
    ]),
    ('주술사', None, '"액운 재설계 · 역병 확정, 저주가 퍼지는 느낌으로"', [
        ('낙인', None, None),
        ('속박', '액운', '운을 비트는 일은 이 게임에 운 판정이 없어 읽히지 않는다. 발밑에서 올라온 그림자가 '
                        '다가오는 것을 붙잡는 저주로 바꿨다 — 방어.'),
        ('역병', None, '확정. 설명을 "퍼지는" 쪽으로 고쳐, 병이 곁으로 번져 방어를 지나 안에서 썩는 그림을 남겼다.'),
    ]),
    ('길잡이', None, '"AI·숙련도로 3단계 진화 — 그에 맞게 다시"', [
        ('답사', None, '1단계 — 길을 알아본다. 아직 낯설어 위험을 먼저 밟아 둔다.'),
        ('인도', None, '2단계 — 대열을 이끈다. 길이 익어 더 빨리 덜 지치게 걷는다.'),
        ('개척', '야영', '3단계 — 없는 길을 낸다. 자리를 잡아 두는 대신 새 길을 열어 다음 이동을 앞당긴다.'),
    ]),
]

CONFIRMED = {('창술사', '투창'), ('주술사', '역병'), ('주술사', '낙인'), ('창술사', '관철')}

NOTES = [
    ('이번 라운드에 확정된 것', [
        '중갑 · 강골 · 도발 · 호흡 · 투창 · 역병. 여섯 이름은 데이터에 그대로 두고 손대지 않았다.',
        '역병은 이름은 그대로 두고 <b>설명만</b> "저주가 퍼지는" 그림으로 고쳤다 — 옮은 병이 곁으로 번져 '
        '방어를 지나 안에서 썩는다.',
    ]),
    ('사역사 — 포유를 넣고 수생을 뺐다', [
        '분류군 셋이 서로 다른 축을 갖도록 다시 골랐다: 조류(치명) · 곤충(속도) · <b>포유(힘)</b>.',
        '포유는 생태도감의 늑대·곰·멧돼지(6~10층 숲·산)다. 늑대와 곰을 빼면 사역사가 부리는 짐승 중 '
        '가장 무거운 몸이 사라져서, 수생(거대 게·산호상어)을 빼고 넣었다.',
        '수생을 다시 넣고 싶으면 조류나 곤충과 자리를 바꾸면 된다 — 셋 중 하나만 빠지면 된다.',
    ]),
    ('창술사 — 연창', [
        '관철은 한 번 깊게 뚫고, 연창은 쉬지 않고 이어 찌른다. 같은 찌르기지만 한 방과 연속으로 갈린다.',
        '걸기(挑·纏)는 창날로 걸어 당기는 그림이었는데, 이 게임의 카드는 스탯만 남기 때문에 '
        '"당긴다"가 무엇을 하는지 읽히지 않았다.',
    ]),
    ('주술사 — 속박', [
        '액운은 "운"을 비트는 카드였지만 이 게임에는 운 판정이 없다. 그래서 그림자로 발을 묶는 '
        '<b>속박</b>으로 바꿨다 — 다가오지 못하게 막는 저주, 축은 방어.',
        '낙인(남긴다) · 속박(막는다) · 역병(번진다). 셋 다 혼자 완결되고, 셋 다 저주다.',
    ]),
    ('길잡이 — 숙련도 3단계 (가안)', [
        'AI·숙련도 시스템은 아직 없다. 그래서 카드 이름과 설명만 <b>진화 3단계</b>에 맞춰 두고, '
        '실제 규칙(숙련도가 무엇을 올리고, 몇 단계에서 카드가 바뀌는지)은 다음 라운드로 미뤘다.',
        '1단계 답사(치명) → 2단계 인도(민첩) → 3단계 개척(마나). 단계가 오르면 같은 능력이 '
        '알아보기 → 이끌기 → 열기로 자란다.',
        '여기서 \'단계\'는 숙련도 단계다. 데이터의 tier 값(1·2·3)은 카드 세기 보정이고 숫자가 '
        '진화 순서와 반대로 매겨져 있다 — 둘을 같은 것으로 읽지 않는다.',
    ]),
]

HEAD = """<!DOCTYPE html>
<html lang="ko">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>직업 키워드 재설계 (45차)</title>
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
<h1>직업 키워드 재설계 — 45차</h1>
<p class="lead">확정한 여섯 이름(중갑·강골·도발·호흡·투창·역병)은 그대로 두고, 사역사·창술사·주술사·길잡이를
다시 세운 라운드다. 아래 값은 전부 <code>job_tree.json</code> 에서 읽었다.</p>
"""

FOOT = """<p class="foot">
  데이터: <code>data/job_tree.json</code> · 생성기: <code>sim/center/sims/gen_keyword_45.py</code><br>
  직업 id 는 그대로다(<code>l2_hunter</code> · <code>l2_magearrow</code> · <code>l2_hexcaller</code> · <code>l2_strategist</code>).
  길잡이의 숙련도·AI 연동 규칙은 아직 가안이다.
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
    out = [HEAD]
    out.append('<div class="box">'
               f'<b>카드 {n_changed}장 교체 · 직업 {len(PROPOSALS)}개 확인</b><br>'
               '확정 여섯 이름은 그대로 두었다.</div>')

    group_now = None
    for job_name, _, note, cards in PROPOSALS:
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
                name_html = (f'<span class="old">{old}</span><span class="arrow">→</span>'
                             f'<span class="new">{now}</span>')
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
    print(f'OK — {OUT} ({os.path.getsize(OUT):,} bytes) · 교체 {n_changed}')


if __name__ == '__main__':
    main()
