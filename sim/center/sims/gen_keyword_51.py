#!/usr/bin/env python3
"""51차 키워드 재설계 — 사역사는 기를 수 있는 것들(마물), 길잡이는 계급 없이.

왜 스크립트인가:
    이름·축·설명을 손으로 HTML 에 적으면 데이터가 바뀌면 페이지가 조용히
    거짓말을 한다. 여기서는 **지금 값은 job_tree.json 에서** 읽고, 이 파일에는
    '무엇이 무엇이 됐나'와 '왜'만 적는다. 새 카드가 데이터에 없거나 옛 이름이
    아직 남아 있으면 실패한다. 근거로 인용한 생태도감 개체·성격 수치도
    데이터와 다르면 실패한다.

사용: ./.venv/bin/python sim/center/sims/gen_keyword_51.py
출력: docs/design/키워드_설계안_51차.html
"""
import json
import os

TOOLS = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(TOOLS)))
TREE = os.path.join(ROOT, 'data', 'job_tree.json')
CODEX = os.path.join(ROOT, 'data', 'ecology_codex.json')
PERSONA = os.path.join(ROOT, 'data', 'monster_personality.json')
OUT = os.path.join(ROOT, 'docs', 'design', '키워드_설계안_51차.html')

PROPOSALS = [
    ('사역사', '마귀는 공격성 0.6~0.7 이라 사람을 사냥한다 — 기르는 것이라면 손에 들어와야 한다', [
        ('짐승', None, None),
        ('곤충', None, None),
        ('마물', '마귀', '사람이 버린 것을 먹고 사는 것만 골랐다 — 공격성 0.2~0.3, '
                       '무리성 0.6~0.9. 우리 없이도 사람 곁에 붙는다.'),
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
    ('길잡이', '위계를 이름에 담으려던 세 번의 시도(표시물·계급어·길+접미)가 전부 어색했다', [
        ('앞서기', '길눈', '계급어 대신 동작을 이름으로 삼았다. 혼자 먼저 걷는 일이 첫 단계다.'),
        ('길열기', '길꾼', '대열을 세우는 일은 혼자 못 한다. 여기서 책임이 남에게 넘어간다.'),
        ('길남기기', '길지기', '남긴 자국이 다음 무리를 데려온다. 책임이 아직 오지 않은 자에게 닿는다.'),
    ]),
]

CONFIRMED = {('창술사', '투창'), ('창술사', '연창'), ('창술사', '관철'),
             ('주술사', '낙인'), ('주술사', '속박'), ('주술사', '역병')}

# 기를 수 있는 마물 — (개체, 층, 서식지 코드, 서식지 한글, 식성, 역할, 공격성, 무리성, 지능, 활동)
#   세 조건을 데이터로 만족해야 한다: 공격성 ≤0.3 · 무리성 ≥0.6 · 사람이 버린 것을 먹는다.
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

ROLE_KO = {'decomposer': '분해자', 'scavenger': '청소부', 'predator': '포식자'}
DIET_KO = {'omnivore': '잡식', 'herbivore': '초식', 'carnivore': '육식', 'none': '먹지 않음',
           'mana': '마나', 'mineral': '광물', 'soul': '영혼'}
ACT_KO = {'always': '항상', 'diurnal': '낮', 'nocturnal': '밤'}

# 버린 후보 — (이름, 층, 왜 버렸나)
REJECTED = [
    ('흉고블린', '6~10', '공격성 0.7. 무리를 지어 사람을 사냥한다 — 우리에 넣어도 손이 남는다.'),
    ('고블린', '16~20', '공격성 0.6. 코볼드를 잡아먹는 쪽이다(preyIds).'),
    ('임프', '21~25', '공격성 0.6. 영혼을 먹는다(preyResources: soul).'),
    ('마귀 (50차)', '6~25', '이름 자체가 "귀신 같은 것" — 기르는 대상과 결이 어긋난다.'),
    ('덩굴 (48차)', '6~130', '식물은 사고하지 못한다. 기를 수는 있어도 시킬 일이 없다.'),
    ('포자 버섯', '16~20', '균류도 사고하지 못한다.'),
    ('뱀 (46차)', '1~10', '동물 셋이 되면 짐승·곤충과 결이 겹친다.'),
]

# 길잡이 3단계 — (카드, 범위, 티어 난이도). 설명은 카드 데이터에서 그대로 읽어 찍는다.
ARC = [
    ('앞서기', '자기 하나', '3 · 가장 쉽다'),
    ('길열기', '무리 전체', '2'),
    ('길남기기', '뒤에 오는 자', '1 · 가장 어렵다'),
]

NOTES = [
    ('마물이 무엇인가', [
        '몬스터를 통째로 부르는 말이 마물이다. 카드 이름 셋이 <b>짐승 · 곤충 · 마물</b> 이 되어 '
        '분류군 이름의 결이 맞는다 — 사역사는 분류군을 통째로 다루는 직업이다.',
        '기준은 셋이다. 공격성 0.3 이하, 무리성 0.6 이상, 사람이 버린 것을 먹을 것. '
        '셋을 다 만족하면 우리에 가두지 않아도 마을 곁에 남는다.',
    ]),
    ('기르는 것과 부리는 것', [
        '사육은 먹이·자리·번식을 사람이 대야 한다. 셋 다 <b>폐기물</b>을 먹으므로 먹이는 '
        '문제가 되지 않고, 무리를 지어 스스로 늘어난다.',
        '전투에서는 부린다. 슬라임은 좁은 틈으로 스며들어 발을 붙잡고, 코볼드는 덫을 걷는다. '
        '묶인 틈에 사역사가 급소를 연다 — 그래서 축이 치명이다.',
    ]),
    ('길잡이 — 이름에 계급을 담지 않는다', [
        '표시물(발자국·표식·이정표), 계급어(견습·숙련·장인), 길+직업 접미(길눈·길꾼·길지기) — '
        '셋 다 "몇 번째 단계인가"를 이름에 우겨 넣으려다 실패했다.',
        '이번에는 이름이 <b>일의 범위</b>를 말한다. 앞서기 → 길열기 → 길남기기로 책임이 '
        '자기 → 무리 → 아직 오지 않은 자로 넓어진다. 단계는 이름이 아니라 범위가 정한다.',
    ]),
    ('바뀌지 않은 것', [
        '확정 여덟 장(중갑·강골·도발·호흡·투창·연창·속박·역병)과 짐승·곤충은 그대로다.',
        '직업 id·카드 id 도 그대로다(<code>l2_hunter</code> · <code>kw_strategist_command</code>).',
    ]),
    ('아직 정하지 않은 것', [
        '마물 사육 규칙 — 먹이 소모, 성장, 데리고 다닐 수 있는 수. 전투 밖 규칙이 아직 없다.',
        '오우즈는 31~35층 개체다. 후반 카드로 열리는 편이 자연스럽다.',
        '길잡이 숙련도·AI 연동 규칙도 가안이다.',
    ]),
]

HEAD = """<!DOCTYPE html>
<html lang="ko">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>직업 키워드 재설계 (51차)</title>
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
<h1>직업 키워드 재설계 — 51차</h1>
<p class="lead">사역사 세 번째를 <b>마귀</b>에서 <b>마물</b>로 바꿨다. 사람이 기를 수 있는 것만
골랐으니 공격성 0.2~0.3, 무리성 0.6~0.9 다. 길잡이 셋은 계급을 이름에서 빼고
<b>일의 범위</b>로 다시 세웠다. 아래 값은 전부 <code>job_tree.json</code> 과
<code>ecology_codex.json</code> 에서 읽었다.</p>
"""

FOOT = """<p class="foot">
  데이터: <code>data/job_tree.json</code> · 생태도감: <code>data/ecology_codex.json</code> ·
  성격: <code>data/monster_personality.json</code> ·
  생성기: <code>sim/center/sims/gen_keyword_51.py</code><br>
  직업 id·카드 id 는 그대로다(<code>l2_hunter</code> · <code>kw_strategist_command</code>).<br>
  <code>docs/gdd/</code> 쪽 직업 표는 아직 이번 값이 아니다.
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

    # 근거 확인 — 인용한 개체가 데이터에 있고, 적은 수치가 데이터와 같아야 한다
    for name, floors, hab, hab_ko, diet, role, aggr, soc, intel, act in CREW:
        e = codex.get(name)
        if e is None:
            raise SystemExit(f'FAIL — 생태도감에 없는 개체: {name}')
        if str(e['floors']) != floors or e['diet'] != diet or e['role'] != role:
            raise SystemExit(f'FAIL — 도감 값이 다르다: {name} {e["floors"]} {e["diet"]} {e["role"]}')
        if e['habitat'] != hab:
            raise SystemExit(f'FAIL — 서식지가 다르다: {name} {e["habitat"]}')
        p = pers.get(name)
        if p is None:
            raise SystemExit(f'FAIL — 성격 데이터에 없는 개체: {name}')
        for key, want in (('aggression', aggr), ('sociality', soc),
                          ('intelligence', intel), ('activity', act)):
            if p[key] != want:
                raise SystemExit(f'FAIL — 성격 값이 다르다: {name}.{key} {p[key]} ≠ {want}')
        if aggr > 0.3 or soc < 0.6:
            raise SystemExit(f'FAIL — 사육 조건 미달: {name} 공격성 {aggr} · 무리성 {soc}')

    # 버린 후보의 수치도 데이터에서 읽어 대조한다 (이름만 적고 수치를 지어내지 않는다)
    for name, floors, why in REJECTED:
        p = pers.get(name)
        if name in ('흉고블린', '고블린', '임프'):
            if p is None or p['aggression'] < 0.6:
                raise SystemExit(f'FAIL — 공격성 근거가 틀렸다: {name}')

    n_changed = sum(1 for _, _, cs in PROPOSALS for now, old, _ in cs if old)
    out = [HEAD]
    out.append('<div class="box">'
               f'<b>카드 {n_changed}장 교체 · 확정 8장 · 직업 {len(PROPOSALS)}개</b><br>'
               '사역사 한 장과 길잡이 세 장을 바꾸고 나머지는 값 그대로 확인했다.</div>')

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
                cls = 'why2' if job_name == '길잡이' else 'why'
                out.append(f'<p class="{cls}">{why}</p>')
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

            out.append('<h3 style="font-size:15px;color:var(--dim);margin:16px 0 4px">'
                       '버린 후보</h3>')
            for name, floors, why in REJECTED:
                out.append(f'<div class="rj no">'
                           f'<div class="rh"><b>{name}</b><span class="rw">{floors}층</span></div>'
                           f'<p>{why}</p></div>')

        if job_name == '길잡이':
            out.append('<h3 style="font-size:15px;color:var(--dim);margin:16px 0 4px">'
                       '3단계 — 이름이 아니라 일의 범위가 넓어진다</h3>')
            out.append('<table><tr><th>카드</th><th>범위</th><th>하는 일</th>'
                       '<th class="num">티어</th></tr>')
            for name, scope, tier in ARC:
                cur = find_card(job, name)
                if cur is None:
                    raise SystemExit(f'FAIL — 길잡이에 없는 카드: {name}')
                out.append(f'<tr><td class="n">{name}</td><td>{scope}</td>'
                           f'<td>{cur["desc"]}</td><td class="num">{tier}</td></tr>')
            out.append('</table>')
            out.append('<p class="cap" style="margin:6px 0 0">티어는 난이도다 — 1이 가장 어렵고 '
                       '가장 강하다. 세 단계는 티어 3 → 2 → 1 로 올라간다.</p>')
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
