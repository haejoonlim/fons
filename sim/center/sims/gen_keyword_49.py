#!/usr/bin/env python3
"""49차 키워드 재설계 — 길잡이 계급을 길 계열 이름(길눈·길꾼·길지기)으로.

왜 스크립트인가:
    이름·축·설명을 손으로 HTML 에 적으면 데이터가 바뀔 때 페이지가 조용히
    거짓말을 한다. 여기서는 **지금 값은 job_tree.json 에서** 읽고, 이 파일에는
    '무엇이 무엇이 됐나'와 '왜'만 적는다. 새 카드가 데이터에 없거나 옛 이름이
    아직 남아 있으면 즉시 실패한다.

사용: ./.venv/bin/python sim/center/sims/gen_keyword_49.py
출력: docs/design/키워드_설계안_49차.html
"""
import json
import os

TOOLS = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(TOOLS)))
TREE = os.path.join(ROOT, 'data', 'job_tree.json')
OUT = os.path.join(ROOT, 'docs', 'design', '키워드_설계안_49차.html')

PROPOSALS = [
    ('사역사', None, [
        ('짐승', None, None),
        ('곤충', None, None),
        ('덩굴', None, None),
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
    ('길잡이', '"견습·숙련·장인은 이미 쓰는 말이다 — 길잡이답게 다시"', [
        ('길눈', '견습', '1단계. 눈으로 먼저 읽는다 — 아직 걸어 보지 못한 길을 알아본다.'),
        ('길꾼', '숙련', '2단계. 읽은 길을 다뤄 남을 데려간다.'),
        ('길지기', '장인', '3단계. 난 길을 지키고, 없는 곳에는 새 길을 낸다.'),
    ]),
]

CONFIRMED = {('창술사', '투창'), ('창술사', '연창'), ('창술사', '관철'),
             ('주술사', '낙인'), ('주술사', '속박'), ('주술사', '역병')}

# 사다리 — 데이터의 이름·설명은 여기서 읽고, '무엇이 커지는가'만 손으로 적는다.
LADDER = [
    ('길눈', '보다', '길이 어디로 뻗었는지 눈으로 먼저 안다.'),
    ('길꾼', '다루다', '걸어 본 길을 표시해 남에게 건넨다.'),
    ('길지기', '맡다', '난 길을 지키고, 없는 길을 새로 낸다.'),
]

# 지금까지 버린 이름들 — 왜 버렸는지 함께 남긴다.
REJECTED = [
    ('답사 · 인도 · 개척', '44차', '뜻은 좋지만 어느 것이 위인지 이름만으로 알 수 없었다.'),
    ('발자국 · 표식 · 이정표', '46차', '표시물이 커지는 그림 — 위계를 읽는 사람이 추론해야 했다.'),
    ('견습 · 숙련 · 장인', '47차', '위계는 보였지만, 이미 다른 계통에서 쓰는 일반 계급어였다.'),
]

NOTES = [
    ('왜 길 하나로 묶었나', [
        '셋 다 <b>길</b>로 시작한다. 어근이 같으면 같은 직업의 세 단계라는 것이 먼저 보인다.',
        '뒤에 붙는 말이 단계를 만든다 — <b>눈 → 꾼 → 지기</b>. '
        '보는 자(감각) → 다루는 자(솜씨) → 맡는 자(책임).',
        '견습·숙련·장인은 누구에게나 붙는 말이라 길잡이를 가리키지 못했다. '
        '이제 카드 셋만 늘어놓아도 어떤 직업의 사다리인지 읽힌다.',
    ]),
    ('셋이 하는 일', [
        '<b>길눈</b>은 눈으로 먼저 읽는다 — 아직 가 보지 않은 길의 위험을 알아본다.',
        '<b>길꾼</b>은 읽은 길을 표시해 뒤따르는 이를 데려간다.',
        '<b>길지기</b>는 난 길을 지키고, 처음 가는 곳에 새 길을 낸다.',
        '축은 그대로 치명 · 민첩 · 마나다. 단계가 높아도 오르는 힘이 달라서 '
        '3단계가 1단계의 상위 호환이 되지 않는다.',
    ]),
    ('바뀌지 않은 것', [
        '확정 여덟 장(중갑·강골·도발·호흡·투창·연창·속박·역병)은 그대로다.',
        '사역사 셋(짐승·곤충·덩굴)과 낙인·관철도 그대로다. 이번 라운드는 길잡이 세 장의 이름만 건드렸다.',
    ]),
    ('아직 정하지 않은 것', [
        '숙련도가 무엇으로 오르고, 몇에서 카드가 바뀌는지는 가안이다. AI 연동 규칙도 아직 없다.',
        '셋이 <b>동시에</b> 오르는지 <b>하나씩</b> 열리는지 미정이다 — 동시에 오르면 '
        '1·2단계는 지나가는 자리가 된다.',
    ]),
]

HEAD = """<!DOCTYPE html>
<html lang="ko">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>직업 키워드 재설계 (49차)</title>
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
  .rj{background:var(--card2);border-radius:10px;padding:10px 12px;margin-bottom:8px}
  .rh{display:flex;align-items:baseline;gap:8px;flex-wrap:wrap}
  .rh b{font-size:15.5px;color:#b9c6d4}
  .rw{font-size:13px;color:var(--dim);border:1px solid var(--line);border-radius:20px;padding:1px 8px}
  .rj p{margin:5px 0 0;font-size:14.5px;line-height:1.6;color:var(--dim)}
  .foot{color:var(--dim);font-size:14px;line-height:1.7;margin-top:28px}
  code{background:#0b0e12;border:1px solid var(--line);border-radius:5px;padding:0 4px;font-size:14px}
</style>
</head>
<body>
<h1>직업 키워드 재설계 — 49차</h1>
<p class="lead">길잡이 세 장의 이름만 다시 지었다. 47차의 계급어(견습·숙련·장인)는 이미 다른 계통에서
쓰는 말이라 버리고, <b>길</b> 하나를 어근으로 세 단계를 만들었다 — 길눈 · 길꾼 · 길지기.
확정 여덟 장과 사역사 셋은 손대지 않았다. 아래 값은 전부 <code>job_tree.json</code> 에서 읽었다.</p>
"""

FOOT = """<p class="foot">
  데이터: <code>data/job_tree.json</code> · 생성기: <code>sim/center/sims/gen_keyword_49.py</code><br>
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
    """길 계열 사다리 — 데이터의 이름·설명을 1·2·3단계 순서로 세운다.

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
               '길잡이 이름만 바꾸고 나머지는 값 그대로 확인했다.</div>')

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

        if job_name == '길잡이':
            out.append('<h3 style="font-size:15px;color:var(--dim);margin:16px 0 4px">'
                       '지금까지 버린 이름</h3>')
            for names, round_no, why in REJECTED:
                out.append('<div class="rj">'
                           f'<div class="rh"><b>{names}</b><span class="rw">{round_no}</span></div>'
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
