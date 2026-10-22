#!/usr/bin/env python3
"""44차 키워드 재설계 — 확정 3장 · 재설계 6직업.

왜 스크립트인가:
    이름·축·설명을 손으로 HTML 에 적으면 데이터가 바뀔 때 페이지가 조용히
    거짓말을 한다. 여기서는 **지금 값은 job_tree.json 에서** 읽고, 이 파일에는
    '무엇이 무엇이 됐나'와 '왜'만 적는다. 새 카드가 데이터에 없거나 옛 이름이
    아직 남아 있으면 즉시 실패한다.

사용: ./.venv/bin/python sim/center/sims/gen_keyword_44.py
출력: docs/design/키워드_설계안_44차.html
"""
import json
import os

TOOLS = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(TOOLS)))
TREE = os.path.join(ROOT, 'data', 'job_tree.json')
OUT = os.path.join(ROOT, 'docs', 'design', '키워드_설계안_44차.html')

PROPOSALS = [
    ('철벽기사', None, '"중갑 확정 · 골격은 강골로"', [
        ('중갑', None, None),
        ('강골', '골격', '뜻은 그대로 두고 이름만 바꿨다. 뼈대가 굵어 맞은 만큼을 담는다.'),
        ('요새', None, None),
    ]),
    ('전위기사', None, '"도발 확정"', [
        ('연타', None, None),
        ('도발', None, None),
        ('돌파', None, None),
    ]),
    ('포화사수', None, '"일제는 명사수랑 차이가 없어 · 곡사는 구현이 어렵지 않을까"', [
        ('속사', None, None),
        ('호흡', '일제', '뚫는 카드는 명사수와 같은 그림이었다. 뚫지도, 지형을 쓰지도 않는 쪽으로 바꿨다 — '
                        '연사 사이에 숨을 골라 팔과 어깨를 더 오래 쓴다. 스태미너 하나로 구현된다.'),
        ('제압', None, None),
    ]),
    ('사역사', None, '"동물 종을 다룰 수 있게 — 조류면 조류, 곤충"', [
        ('조류', '합공', '들매(1~5층 초원)·매(6~10층 산·평원). 날짐승이 위에서 내리꽂는다.'),
        ('곤충', '추격', '거대 개미·독벌(6~10층 숲·초원). 떼가 수로 덮쳐 숨을 틈을 주지 않는다.'),
        ('수생', '경호', '거대 게·산호상어(11~15층 바다·산호). 껍질과 몸으로 물길을 막아 세운다.'),
    ]),
    ('창술사', None, '"창벽이랑 소탕 진짜 아예 다시 설계"', [
        ('투창', '창벽', '찌르기(刺)만 창의 일이 아니다. 창을 던져 꽂는 쪽(抛)으로 바꿨다 — 치명.'),
        ('관철', None, None),
        ('걸기', '소탕', '휘둘러 쓸어내는 대신 창날로 걸어 당긴다(挑·纏). 자리를 뺏는 쪽 — 힘.'),
    ]),
    ('주술사', None, '"그 컨셉이면 파티에 주술사 둘을 무조건 넣어야 한다"', [
        ('낙인', None, None),
        ('액운', '매듭', '카드 한 장이 그 자체로 끝나는 저주다. 상대의 운을 비틀어 결정적인 순간을 어긋나게 한다.'),
        ('역병', '해봉', '이것도 혼자 선다. 병을 옮겨 방어를 지나 안에서 썩힌다.'),
    ]),
    ('길잡이', None, '"미션·이동(자동이동) 쪽으로, 키워드는 3단계로"', [
        ('답사', '선도', '1단계 — 떠나기 전. 길과 위험을 미리 밟아 둔다.'),
        ('인도', '살핌', '2단계 — 가는 길. 대열을 이끌어 더 빨리 덜 지치게 걷는다.'),
        ('야영', '우회', '3단계 — 도착한 뒤. 자리를 잡고 다음 길을 준비한다.'),
    ]),
]

CONFIRMED = {('철벽기사', '중갑'), ('전위기사', '도발'), ('창술사', '관철'),
             ('주술사', '낙인')}

NOTES = [
    ('주술사 — 왜 사슬을 끊었나', [
        '43차는 낙인 → 매듭 → 해봉으로 표식 하나의 일생을 만들었다. 그런데 이 나무의 키워드는 '
        '<b>영웅 한 명이 가진 카드 한 장</b>이다. 앞 카드가 없으면 뒤 카드가 반쪽이 되니, '
        '한 파티에 주술사를 둘 넣어야 사슬이 완성된다.',
        '그래서 세 장을 <b>각각 그 자체로 완결되는 저주</b>로 다시 골랐다 — 남기는 저주(낙인) · '
        '막는 저주(액운) · 삭히는 저주(역병). 혼자서도 셋 다 온전하다.',
    ]),
    ('포화사수 — 구현되는 것만 남겼다', [
        '일제(관통)는 화살로 판을 꿰는 그림이라 명사수의 급소·원사와 같은 계열이었다.',
        '곡사(포물선·엄폐 무시)는 지형과 엄폐 판정이 있어야 성립한다 — 지금 전투에는 그 판정이 없다. '
        '그래서 <b>호흡</b>으로 바꿨다. 연사 사이에 숨을 골라 오래 쏘는 쪽이고, 필요한 것은 스태미너 하나다.',
    ]),
    ('사역사 — 개체에서 분류군으로', [
        '43차는 늑대·들매·곰 세 개체만 다뤘다. 44차는 <b>분류군</b>을 카드로 삼아, 그 서식권의 '
        '여러 종을 한꺼번에 부린다. 생태도감(ecology_codex.json)의 실제 서식종을 그대로 적었다.',
        '<b>조류</b> 들매(1~5층 초원)·매(6~10층 산·평원) · <b>곤충</b> 거대 개미·독벌(6~10층 숲·초원) · '
        '<b>수생</b> 거대 게·산호상어(11~15층 바다·산호).',
    ]),
    ('창술사 — 창법 리서치', [
        '중국 창술의 기본 셋은 攔(막기)·拿(받아 막기)·扎(찌르기)이고, 그 밖에 劈(내리치기)·'
        '掃(쓸기)·挑(걸어 올리기)·纏(감기)·抛(던지기)가 있다.',
        '관철은 刺, 투창은 抛, 걸기는 挑·纏에서 가져왔다. 43차의 막기(창벽)·쓸기(소탕)는 '
        '지적을 받았으므로 다시 쓰지 않았다.',
        '<b>투창은 고전 장창술이 아니라 표창 계열의 그림</b>이다 — 장창을 실제로 던졌다는 기록은 확인하지 못했다.',
    ]),
    ('길잡이 — 이동 3단계 (역할은 가안)', [
        '떠나기 전(답사) → 가는 길(인도) → 도착한 뒤(야영). 한 번의 행군을 셋으로 나눠 '
        '단계마다 다른 일을 맡긴다.',
        '미션·자동이동과 엮는 부분은 아직 <b>가안</b>이다. 지금 카드에 붙은 축(치명·민첩·마나)은 '
        '전투 스탯을 빌려 둔 임시값이고, 실제 역할은 이동·미션 규칙이 정해질 때 다시 맞춘다.',
    ]),
]

HEAD = """<!DOCTYPE html>
<html lang="ko">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>직업 키워드 재설계 (44차)</title>
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
<h1>직업 키워드 재설계 — 44차</h1>
<p class="lead">확정한 이름(중갑·강골·도발)과 관철은 그대로 두고, 나머지를 다시 세운 라운드다.
아래 값은 전부 <code>job_tree.json</code> 에서 읽었고, 생성기 R1~R11 을 통과한 뒤의 값이다.</p>
"""

FOOT = """<p class="foot">
  데이터: <code>data/job_tree.json</code> · 생성기: <code>sim/center/sims/gen_keyword_44.py</code><br>
  직업 id 는 그대로다(<code>l2_hunter</code> · <code>l2_magearrow</code> · <code>l2_strategist</code>).
  바뀐 것은 이름·축·설명이고, 길잡이의 역할(지원)은 아직 가안이다.
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
               '확정이라 답한 중갑·강골·도발·관철은 그대로 두었다.</div>')

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
