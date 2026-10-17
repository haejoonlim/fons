#!/usr/bin/env python3
"""직업 키워드 검토 페이지 — `data/job_tree.json` 에서 뽑는다.

왜 스크립트인가:
    손으로 옮겨 적으면 축·설명·배율이 데이터와 어긋난다(실제로 한 번 어긋났다).
    이름·축·설명·statMod 는 전부 데이터에서 읽고, 사람이 쓰는 것은
    "이 직업은 무엇을 지적받았나(지적)" 와 "세 장이 어떻게 갈리나(갈림)" 두 문장뿐이다.

사용: ./.venv/bin/python sim/center/sims/gen_career_review.py
출력: docs/design/키워드_설계안_37차.html
"""
import json
import os

TOOLS = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(TOOLS)))
TREE = os.path.join(ROOT, 'data', 'job_tree.json')
OUT = os.path.join(ROOT, 'docs', 'design', '키워드_설계안_38차.html')

# 스탯 코드 → 사람이 읽는 이름 (축 이름과 헷갈리지 않게 다른 낱말을 쓴다:
# 축 '체력' = HP, 축 '방어' = DEF)
STAT = {
    'HP': ('생명력', 0.12), 'ATK': ('공격력', 2.0), 'DEF': ('방어력', 1.5),
    'ASPD': ('공격속도', 3.0), 'MAG': ('마법력', 2.0), 'MDEF': ('마법방어력', 1.5),
    'CRI': ('치명타율', 3.0), 'PEN': ('물리관통', 2.5), 'MPEN': ('마법관통', 2.5),
    'MS': ('이동속도', 1.5), 'CDMG': ('치명타피해', 1.0), 'STA': ('스태미너', 0.03),
    'MANA': ('마나', 0.05),
}
AX = ('HP', 'ATK', 'DEF', 'ASPD', 'MAG', 'MDEF', 'CRI', 'PEN', 'MPEN', 'MS', 'CDMG', 'STA', 'MANA')

# 지적(사용자가 실제로 한 말) + 세 장의 갈림. 나머지는 전부 데이터에서 온다.
NOTE = {
    '철벽기사': ('흘림·감쇄 계보 폐기 — 버팀·겹갑·요새로 확정(39차)',
             '받아 낸다 / 두꺼워진다 / 안 움직인다 — 방어력·생명력·스태미너로 축이 갈린다'),
    '전위기사': ('선두·전진 — 둘 다 앞으로 가서 돌파와 겹침',
             '순서를 뺀다 / 자리를 좁힌다 / 뚫고 나간다 — 공속·공격력·관통으로 갈린다'),
    '성좌기사': ('기사 자리로 돌아와야 함 · 키워드 3장 전부 별로',
             '갑옷에 별을 새긴다 — 방어력 / 마법방어력 / 스태미너, 근거가 셋 다 별'),
    '자객': ('절단 — 이름이 별로',
           '한 방 / 다가감 / 이어서 다음 — 공격력·이동속도·공속'),
    '맹독사': ('심독 — 중독과 겹침',
            '빨리 넣고 빠진다 / 쌓는다 / 자리를 막는다 — 이동속도·치명타피해·마법관통'),
    '도적': ('미끼 — 이름이 별로',
           '훔친다 / 눈을 붙잡는다 / 숨어든다 — 공속·공격력·이동속도'),
    '명사수': ('관통사·비거리 — 둘 다 이름이 별로',
            '한 점을 노린다 / 틈을 벌린다 / 멀리 보낸다 — 치명타율·물리관통·치명타피해'),
    '포화사수': ('포줄 이름 별로 · 차폐는 컨셉 자체를 바꿔야 함',
             '계속 쏜다 / 돌며 쏜다 / 대신 맞힌다 — 공속·이동속도·방어력'),
    '사냥꾼': ('길들임 이름 별로 · 유인은 컨셉 자체 교체',
            '따라붙는다 / 짐승을 세운다 / 몰아넣는다 — 이동속도·공격력·스태미너'),
    '마궁사': ('키워드를 아예 새로 · 5글자라 다른 애들과 달라 보임',
            '새긴다 / 벌어진다 / 터진다 — 마법력·마법관통·치명타피해'),
    '소환술사': ('곤충은 빼고 다른 것',
             '만든 것 / 죽은 것 / 원소 — 생명력·생명력·마법관통'),
    '주술사': ('심연·파멸이 겹침 · 제물은 뭘 하는지 모르겠음',
            '묶는다 / 바친다 / 태운다 — 마법력·치명타피해·마법관통'),
    '드루이드': ('개화·산림이 좁 겹침 — 설계를 다시',
             '되살린다 / 세운다 / 변한다 — 마나·방어력·공격력'),
    '전술가': ('정찰·참모 — 컨셉이 뭔지 모르겠음',
            '화력을 모은다 / 줄을 세운다 / 순서를 잡는다 — 치명타피해·방어력·공속'),
}
GROUP = [
    ('수호자', ['철벽기사', '전위기사', '성좌기사']),
    ('암살자', ['자객', '맹독사', '도적']),
    ('궁수', ['명사수', '포화사수', '사냥꾼', '마궁사']),
    ('마법', ['소환술사', '주술사']),
    ('지원가', ['드루이드', '전술가']),
]

HEAD = """<!DOCTYPE html>
<html lang="ko">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>직업 키워드 설계안 (38차)</title>
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
  .box{background:var(--card);border:1px solid var(--line);border-radius:12px;
       padding:15px 16px;margin-bottom:12px;font-size:16px;line-height:1.75}
  .box b{color:#fff}
  .box .k{color:var(--accent);font-weight:700}
  ol.flow{margin:8px 0 0;padding-left:22px}
  ol.flow li{margin:7px 0}
  .job{background:var(--card);border:1px solid var(--line);border-radius:14px;
       padding:17px 15px 15px;margin-bottom:15px}
  .jh{display:flex;align-items:baseline;gap:9px;flex-wrap:wrap;margin-bottom:3px}
  .l1{font-size:12.5px;color:var(--dim);border:1px solid var(--line);border-radius:20px;
      padding:2px 9px;white-space:nowrap}
  .jh h3{font-size:23px;margin:0;line-height:1.25}
  .jdesc{font-size:15px;color:var(--dim);margin:0 0 9px}
  .note{font-size:15.5px;color:var(--warn);margin:5px 0 13px;line-height:1.6}
  .note::before{content:"지적  ";font-weight:700}
  ul.kw{list-style:none;margin:0 0 13px;padding:0}
  ul.kw li{background:var(--card2);border-radius:11px;padding:12px 14px;margin-bottom:8px}
  .kwhead{display:flex;align-items:baseline;gap:8px;flex-wrap:wrap}
  .name{font-size:23px;font-weight:800;color:var(--accent)}
  .ax{font-size:13.5px;color:var(--dim);border:1px solid var(--line);border-radius:20px;padding:1px 8px}
  .tier{font-size:12.5px;color:#c39cf0}
  .stat{font-size:15px;color:#cfe3f5;margin:6px 0 0}
  .stat b{color:#fff;font-size:16.5px}
  .stat .sub{color:var(--dim);font-size:13.5px}
  .do{font-size:16px;color:#d3dbe6;margin:5px 0 0;line-height:1.6}
  .split{font-size:15.5px;color:var(--green);line-height:1.65;margin:0;
         border-top:1px dashed var(--line);padding-top:10px}
  .split::before{content:"→  ";color:#5f8f72}
  table{width:100%;border-collapse:collapse;font-size:14.5px;margin-top:4px}
  th,td{text-align:left;padding:7px 8px;border-bottom:1px solid var(--line);vertical-align:top}
  th{color:var(--dim);font-size:13px;font-weight:600}
  td.c{color:var(--accent);font-weight:700;white-space:nowrap}
  .sta{background:#161f29;border:1px solid #2a4256}
  .sta h3{font-size:19px;margin:0 0 8px}
  .sta b{color:#bfe0f7}
  .foot{color:var(--dim);font-size:14px;line-height:1.7;margin-top:28px}
</style>
</head>
<body>
<h1>직업 키워드 설계안 — 대표 스탯 · 전직까지 붙여서</h1>
<p class="lead">이름만 보면 역할이 안 읽힌다는 지적을 반영해, 카드마다 <b>그 키워드가 올려 주는 스탯과 배율</b>을 같이 적었다.</p>
"""

FOOT = """<p class="foot">
  데이터: <code>data/job_tree.json</code> · 생성기: <code>sim/center/sims/gen_career_review.py</code> —
  이름·축·설명·배율은 전부 데이터에서 읽어 채운다(손으로 옮겨 적지 않는다).
</p>
</body>
</html>
"""


def main():
    with open(TREE, encoding='utf-8') as fh:
        root = json.load(fh)
    jobs = {j['name']: j for j in root['jobs'] if j['stage'] == 2}

    out = [HEAD]

    # ── 전직 흐름 ──────────────────────────────────────────────
    out.append('<h2 class="sec">전직 흐름 — 키워드가 언제 붙나</h2>')
    out.append('<div class="box">'
               '<ol class="flow">'
               '<li>영웅은 <span class="k">L1 7종</span> 중 하나로 소환된다. 이때는 키워드가 없다.</li>'
               '<li>활동 중 <b>전직이 자동 발동</b>한다(합성소 방문 아님). 스탯 기울기 + 적성 토큰으로 갈래가 확률적으로 정해진다.</li>'
               '<li>L2(최종 직업)에 오르면 <b>키워드 3장 중 1장</b>이 붙는다. 그 한 장의 <code>statMod</code>가 영웅 스탯에 곱해진다.</li>'
               '<li>정령기사·원소마도사처럼 <b>7장짜리 종점</b>도 1장만 고른다 — 7장을 다 곱하면 ×2.7~3.2배가 되어 다른 직업의 두 배가 됐기 때문.</li>'
               '<li>키워드 <b>티어 1·2·3</b>은 그 직업 안에서의 서열이다(1이 가장 강함). '
               '전직 난이도 티어(A/B/C)와는 반대 방향이며 어휘도 따로 쓴다.</li>'
               '</ol></div>')

    # ── 38차 축 개정 ──────────────────────────────────────────
    out.append('<h2 class="sec">38차 — 회피율을 없애고, 민첩 = 이동속도</h2>')
    out.append('<div class="box">'
               '<b>없어진 것: 회피율(EVA).</b> 확률로 피해를 통째로 0으로 만드는 스탯이다. '
               '그래서 맞았는데 안 맞은 것이 되고, 카드로 올려도 체감이 운에 묶인다. '
               '기준값 0% — 원래도 대부분의 빌드에서 비어 있던 칸이다.<br><br>'
               '<b>남은 것: 이동속도(MS).</b> 기준 <b>100%</b>. 민첩 축이 이 스탯을 전담하고, '
               '카드가 민첩을 올리면 이동속도가 그만큼 곱해진다. '
               '회피를 지워도 민첩의 뜻(몸을 빨리 옮긴다)은 그대로 남고, '
               '그 뜻이 숫자 하나로 읽힌다 — <b>붙기까지 걸리는 시간</b>이다.<br><br>'
               '<b>설명을 다시 쓰지 않아도 됐다.</b> 민첩을 쓰는 카드 5장'
               '(' + ' · '.join(na for jj in root['jobs'] for kk in (jj.get('keywords') or [])
                                if kk.get('shape') == '민첩' for na in [kk['name']]) + ')은 '
               '36·37차에 이미 전부 움직임으로 쓰여 있었다 — "다가간다 · 빠져나온다 · 따라붙는다". '
               '축만 바뀌었지 문장은 그대로다.<br><br>'
               '<b>아직 남은 일.</b> 장비·종족 효과의 "회피 +N%" 문구와 전투 코드의 회피 판정은 '
               '별도 작업이다. 이 페이지는 <b>영웅 스탯·키워드 축</b>까지만 반영했다.'
               '</div>')

    # ── 철벽기사 확정 ────────────────────────────────────────
    out.append('<h2 class="sec">철벽기사 — 세 번째를 "받아 내는"으로</h2>')
    out.append('<div class="box">'
               '<b>버팀 · 겹갑 · 요새로 확정(39차).</b> 받아 내는(방어력) · '
               '두꺼워지는(생명력) · 안 움직이는(스태미너).<br><br>'
               '<b>세 번째는 버팀(방어력).</b> 흘림 → 감쇄로 이어지던 계보를 끊었다. '
               '그 셋은 전부 <b>"맞은 충격이 어떻게 사라지는가"</b>를 말한다 — 흘린다 · 나눠 받는다 · '
               '비튼다 · 비스듬히 세운다. 화면에서는 전부 "안 아픈 것" 하나로 보여서 서로 구분되지 않고, '
               '이름도 동작이 아니라 형상이라 읽히지 않았다.<br><br>'
               '<b>버팀</b>은 방향을 바꾼다 — 충격을 없애는 게 아니라 <b>갑옷이 대신 받는다</b>. '
               '세 장이 서로 다른 시스템을 건드린다: '
               '<code>버팀 = 물리 피해 감소</code> · <code>중갑 = 최대 생명력</code> · '
               '<code>요새 = 행동 예산</code>. 그래서 셋 다 올렸을 때 서로 곱해지지 않고 따로 쌓인다.'
               '</div>')

    # 전직 선택 관점 자동 점검 — 세 장이 진짜 "고를 수 있는" 선택인가
    three = [j for j in root['jobs'] if j['stage'] == 2 and len(j.get('keywords') or []) == 3]
    axis_ok = sum(1 for j in three if len({k['shape'] for k in j['keywords']}) == 3)
    tier_ok = sum(1 for j in three if {str(k['tier']) for k in j['keywords']} == {'1', '2', '3'})
    out.append('<div class="box"><b>전직 선택 관점 점검</b><br>'
               f'3장짜리 L2 <b>{len(three)}종</b> 전부에서 '
               f'<span class="k">세 축이 서로 다른 직업 {axis_ok}/{len(three)}</span> · '
               f'<span class="k">티어 1·2·3을 하나씩 갖춘 직업 {tier_ok}/{len(three)}</span>. '
               '즉 전직 때 세 장이 같은 값의 다른 이름이 아니고, 난이도도 한 쪽으로 몰려 있지 않다.'
               '</div>')

    out.append('<div class="box"><b>배율 읽는 법</b><br>'
               '키워드 배율은 <b>총량을 올리는 것이 아니라 방향을 옮기는</b> 값이다. '
               '<code>statMod = POWER × (1 + 0.42 × (방향 − 평균))</code> 이므로 '
               '13종 평균은 그대로고, 표시된 스탯만 오르고 나머지는 그만큼 줄어든다. '
               '그래서 아래 표의 <b>대표 스탯 ×1.43</b>은 "방어력이 43% 오른다"가 아니라 '
               '"총량은 그대로인데 방어력 쪽으로 43%만큼 쏠린다"는 뜻이다.'
               '</div>')

    # ── 스탯 13종 ─────────────────────────────────────────────
    out.append('<h2 class="sec">스탯 13종 — 이름과 하는 일</h2>')
    out.append('<div class="box">'
               '<table><thead><tr><th>축 이름</th><th>스탯</th><th>하는 일</th><th>CP 비중</th></tr></thead><tbody>')
    for code, (ko, w) in STAT.items():
        cell = '식에 없음' if w is None else w
        out.append(f'<tr><td class="c">{code}</td><td>{ko}</td><td>{AXIS_MEANING[code]}</td><td>{cell}</td></tr>')
    out.append('</tbody></table>'
               '<div class="stat sub" style="margin-top:9px">CP 비중 = 전투력 계산에서 그 스탯 1점이 차지하는 값. '
               '공속·치명타율 3.0 이 가장 무겁고 스태미너 0.03 이 가장 가볍다.<br>'
               '38차부터 <b>13축 전부 전투력 식에 항이 있다</b> — MPEN 2.5 · MS 1.5 포함. '
               '회피(EVA)는 식에서 빠졌다. 카드 한 장의 CP 배율은 데이터의 <code>power</code> 와 '
               '같고(비율 오차 0.00004), CP 를 낮추는 카드는 없다.</div>'
               '</div>')

    # ── 근성 ───────────────────────────────────────────────
    out.append('<h2 class="sec">근성(STA)이 정확히 뭔가</h2>')
    out.append('<div class="box sta">'
               '<h3>근성 = 스태미너. <b>행동 예산</b>이다.</h3>'
               '<b>1. 행동마다 깎인다.</b> 스킬·방어태세 같은 행동에는 각각 <code>staminaCost</code>가 있고, '
               '그 값이 모자라면 그 행동은 <b>아예 선택되지 않는다</b>(AI도 실행 전에 예산을 계산한다). '
               '방어태세는 고정 15.<br>'
               '<b>2. 취소하면 돌려받는다.</b> 행동이 무산되면 쓴 값이 환급된다.<br>'
               '<b>3. 전투 중 저절로 차지 않는다.</b> 회복 행동이나 장비로만 채워진다 — 코드에 틱 재생이 없다. '
               '그래서 근성은 <b>"한 전투에서 몇 번까지 움직일 수 있나"</b>다.<br>'
               '<b>4. 그래서 근성이 높은 직업</b>은 한 번의 교전에서 행동을 더 오래 굴린다 — '
               '요새·북극성·몰이처럼 "버틴다"가 컨셉인 자리에 붙는다.<br>'
               '<b>5. 전투력 기여는 작다</b>(×0.03). 세고 약함이 아니라 <b>지구력</b>이라 CP가 거의 안 오른다. '
               '등급계수도 적용하지 않는다(7종 중 하나).<br>'
               '<b>6. 문서에만 있는 규칙</b> — GDD 05는 "STA가 낮으면 전 스탯 -10%"라고 적고 있으나, '
               '전투 코드에는 그 페널티가 아직 없다. 지금 실제로 작동하는 것은 <b>행동 예산</b> 하나다.'
               '</div>')

    # ── 직업 카드 ────────────────────────────────────────────
    for group, names in GROUP:
        out.append(f'<h2 class="sec">{group}</h2>')
        for jn in names:
            j = jobs[jn]
            note, split = NOTE[jn]
            out.append('<section class="job">')
            out.append(f'<div class="jh"><span class="l1">{group}</span><h3>{jn}</h3></div>')
            out.append(f'<p class="jdesc">{j.get("desc", "")}</p>')
            out.append(f'<p class="note">{note}</p>')
            out.append('<ul class="kw">')
            for k in j.get('keywords') or []:
                v = k.get('statMod')
                if not v:
                    continue
                order = sorted(range(13), key=lambda i: -v[i])
                top, second = order[0], order[1]
                code = AX[top]
                ko, w = STAT[code]
                out.append('<li>')
                out.append(f'<div class="kwhead"><span class="name">{k["name"]}</span>'
                           f'<span class="ax">{k.get("shape", "—")}</span>'
                           f'<span class="tier">티어 {k.get("tier", "?")}</span></div>')
                out.append(f'<p class="stat">대표 <b>{code} {ko}</b> ×{v[top]:.2f} '
                           f'<span class="sub">· 다음 {AX[second]} ×{v[second]:.2f} · CP 기여 {w}</span></p>')
                out.append(f'<p class="do">{k.get("desc", "")}</p>')
                out.append('</li>')
            out.append('</ul>')
            out.append(f'<p class="split">{split}</p>')
            out.append('</section>')

    out.append(FOOT)
    with open(OUT, 'w', encoding='utf-8') as fh:
        fh.write('\n'.join(out))
    print(f'OK — {OUT} ({os.path.getsize(OUT):,} bytes)')


AXIS_MEANING = {
    'HP': '맷집. 0이 되면 쓰러진다',
    'ATK': '물리 피해량',
    'DEF': '물리 피해를 덜 받는다. 관통(PEN)을 깎아 상쇄한다',
    'ASPD': '공격·시전이 나가는 간격',
    'MAG': '마법 피해량',
    'MDEF': '마법 피해를 덜 받는다. 마법관통(MPEN)을 깎는다',
    'CRI': '치명타가 터질 확률',
    'PEN': '상대 방어력을 뚫는다',
    'MPEN': '상대 마법방어를 뚫는다',
    'MS': '이동속도 — 붙기까지 걸리는 시간, 도망·추격의 우열',
    'CDMG': '치명타가 터졌을 때의 배율',
    'STA': '행동 예산(스태미너) — 아래 설명 참고',
    'MANA': '주문을 쓰는 자원',
}

if __name__ == '__main__':
    main()
