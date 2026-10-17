#!/usr/bin/env python3
"""직업 트리 검토용 HTML — `job_tree.json` 에서 생성한다.

왜 스크립트인가:
    29~32차 동안 마크다운 표를 손으로 고쳐서 문서와 런타임이 매번 어긋났다.
    지금은 05 §8-1 을 `sync_career_tables.py` 가, 이 도감은 이 스크립트가 만든다.
    트리가 바뀌면 두 스크립트만 다시 돌리면 된다.

사용:  python3 design-docs/_tools/gen_career_html.py
"""
import json
import os
import sys

TOOLS = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(TOOLS)))
sys.path.insert(0, TOOLS)
# ★ 2026-10-17 — 축 이름·순서는 생성기 `gen_career_34.py` 의 AX_NAME 하나가 정본이다.
#   여기서 손으로 14축을 적어 두었던 탓에 35차 후속5(시전속도→공속 통합 · 마나 정식 축)를
#   따라오지 못해 `AXIS['마나']` KeyError 로 이 스크립트가 죽었고, 그동안 HTML 은 v3.3.0 에
#   멈춰 있었다. 이제 같은 목록을 import 해서 순서까지 한 곳에서 온다.
from gen_career_34 import AX_NAME
TREE = os.path.join(ROOT, 'data/job_tree.json')
OUT = os.path.join(ROOT, 'sim/center/pages/직업트리_전체도.html')

# 34차 — 스탯 축 13종. 각 축이 **스탯 하나를 전담**한다.
#   괄호는 대표 스탯(1위) — gen_career_34.py SHAPE 벡터에서 뽑은 값이라 반드시 일치해야 한다.
#   ★ 장벽 2종은 자기 관통 스탯을 깎는다 (PEN 0.40 / MPEN 0.40)
AXIS = {
    '힘':      ('#e07b5f', 'ATK'),
    '속도':    ('#8dd4e7', '공속'),
    '치명':    ('#f0a868', 'CRI'),
    '주문':    ('#b48dd4', 'MAG'),
    '체력':    ('#81c995', 'HP'),
    '관통': ('#d9724f', 'PEN'),
    '마법관통': ('#9b6fd4', 'MPEN'),
    '방어': ('#5fa87f', 'DEF · PEN↓'),
    '마법방어': ('#7f9ed4', 'MDEF · MPEN↓'),
    '민첩':    ('#c9c05f', 'MS'),
    '치명위력':    ('#e3bb75', 'CDMG'),
    '근성':    ('#8fa3b8', 'STA'),
    # 35차 후속5 — 시전속도(SPD_CAST)가 공속에 통합되고 마나가 정식 축이 됐다.
    '마나':    ('#6fc9b0', 'MANA'),
}
# 표시 이름만 한국어로 바꾼다(정본 순서·개수는 AX_NAME).
STAT_KO = {'ASPD': '공속'}
STATS = [STAT_KO.get(a, a) for a in AX_NAME]
LAW = {'fire': '화염', 'earth': '대지', 'water': '물', 'wind': '바람',
       'light': '빛', 'dark': '어둠', 'void': '무'}

CSS = """
:root{color-scheme:dark;--line:#263340;--muted:#9fb0c0;--ice:#8dd4e7;--amber:#e3bb75}
*{box-sizing:border-box}body{margin:0;background:#0b0f14;color:#edf2f7;font:15px/1.6 -apple-system,"Apple SD Gothic Neo","Noto Sans KR",sans-serif}
main{max-width:1240px;margin:auto;padding:36px 20px 80px}
.eyebrow{font-size:11px;letter-spacing:.17em;color:var(--ice)}
.badge{display:inline-block;border:1px solid #415362;border-radius:99px;padding:3px 11px;color:var(--amber);font-size:12px;margin:10px 0}
h1{font-size:clamp(26px,4.2vw,42px);line-height:1.15;margin:6px 0 12px}
.lede,.note{max-width:860px;color:#c3cfdb}.note{color:var(--muted);font-size:13px}
.stats{display:grid;grid-template-columns:repeat(4,1fr);gap:10px;margin:22px 0}
.stat{background:#141d26;border:1px solid var(--line);border-radius:12px;padding:12px}
.stat b{display:block;font-size:20px}.stat span{font-size:12px;color:var(--muted)}
.axiskey{display:flex;flex-wrap:wrap;gap:7px;margin:8px 0 28px}
.l1{margin:0 0 32px}.l1h{display:flex;align-items:baseline;gap:10px;flex-wrap:wrap;padding-bottom:8px;border-bottom:2px solid var(--line)}
.l1h b{font-size:24px}.l1h small{color:var(--muted);font-size:12px;margin-left:auto}
.ldesc{color:#b8c6d3;margin:8px 0 12px}
.role{font-size:11px;padding:2px 9px;border-radius:99px;background:#1d2731;border:1px solid #35424f}
.job{border:1px solid var(--line);border-radius:12px;padding:14px;margin:11px 0;background:#10161d}
.job.term{background:#171522;border-color:#4a3f5c}
.jh{display:flex;align-items:baseline;gap:10px;flex-wrap:wrap}.jh b{font-size:18px}
.jlaw{color:var(--muted);font-size:12px}.jdesc{color:#a9b8c6;margin:6px 0 12px;font-size:14px}
.bt{font-size:11px;padding:2px 8px;border-radius:99px;background:#2a2233;border:1px solid #5b4a70;color:#d7c3ea}
.kws{display:grid;grid-template-columns:repeat(auto-fit,minmax(340px,1fr));gap:10px}
.kw{border:1px solid #223040;border-radius:11px;padding:12px;background:#0e141a}
.kh{display:flex;align-items:center;gap:8px;flex-wrap:wrap;margin-bottom:6px}
.kname{font-size:16px;font-weight:650}
.tier{font-size:11px;font-weight:700;padding:1px 7px;border-radius:5px;margin-left:auto}
.t1{background:#33232a;color:#e8a0ac}.t2{background:#2b2a22;color:#d6c188}.t3{background:#24303c;color:#9fc4de}
.axis{font-size:12px;padding:2px 8px;border-radius:6px;border:1px solid var(--c);color:var(--c)}
.axis em{font-style:normal;font-size:10px;opacity:.72;margin-left:5px}
.axis.term{--c:#b48dd4;border-style:dashed}
.l3wrap{margin:0 0 34px;padding:16px;border:1px solid #3a3348;border-radius:14px;background:#0f0d16}
.l3h{display:flex;align-items:baseline;gap:10px;flex-wrap:wrap;padding-bottom:8px;border-bottom:2px solid #4a3f5c}
.l3h b{font-size:22px}.l3h small{color:var(--muted);font-size:12px;margin-left:auto}
.cond{font-size:10px;padding:1px 6px;border-radius:4px;background:#2a1f33;border:1px solid #5b4a70;color:#d7c3ea}
.kdesc{color:#a5b4c2;margin:0 0 9px;font-size:13.5px}
.mlab{font-size:10px;letter-spacing:.1em;color:#6d7f8f;margin-bottom:3px}
table{width:100%;border-collapse:collapse;font-variant-numeric:tabular-nums;font-size:11.5px}
th{color:#6d7f8f;font-weight:500;padding:2px 3px;text-align:right}
td{padding:2px 3px;text-align:right;border-top:1px solid #1b2530}
/* 35차 — 13축 표.
   ★ 이전 정의가 두 겹으로 깨져 있었다: ① repeat(7,1fr) 인데 셀은 (이름,값) 쌍이므로
     7칸에 3.5쌍만 들어갔다 ② tbody 에 display:contents 가 없어 tbody 가 하나의 블록으로 남아
     카드가 아무리 좁아도 표가 밖으로 넘쳤다(문서 가로 스크롤 발생).
   → 쌍 3개씩(=6칸) 배치하고 tbody 까지 contents 로 펴서 카드가 몇 개든 밖으로 나가지 않게 한다. */
table.vstat{display:grid;grid-template-columns:repeat(3,minmax(0,1fr) minmax(30px,auto));gap:1px 8px;font-size:11px}
table.vstat tbody,table.vstat tr{display:contents}
table.vstat th{text-align:left;padding:1px 0;border-top:1px solid #1b2530;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}
table.vstat td{text-align:right;padding:1px 0;border-top:1px solid #1b2530;font-variant-numeric:tabular-nums}
table.vstat th:first-child{color:#8fa3b8}
td.up{color:#7fd39a}td.dn{color:#dd8b8b}td.fl{color:#5f7183}
footer{border-top:1px solid var(--line);margin-top:30px;padding-top:12px;color:#7e8d9b;font-size:12px}
@media(max-width:860px){.stats{grid-template-columns:repeat(2,1fr)}.l1h small{margin-left:0;width:100%}}
"""


def law_text(tags):
    return '·'.join(LAW.get(t, t) for t in (tags or [])) or '—'


def stat_table(mod, shape=None):
    """13축이라 가로 표는 카드를 넘친다 → 축 이름 / 배율 2열로 세운다.
    배율이 가장 높은 축(= shape 의 대표)을 ★ 로 표시해 '무엇이 오르는지' 한눈에 보게 한다.
    ★ 35차 — **shape 가 없으면 ★ 를 아예 찍지 않는다** (무명자 서브트리 L4 13장 · 대현자).
      13축이 전부 같은 값이라 '최댓값' 을 ★ 로 찍으면 'HP 가 대표다' 라는 거짓말이 된다."""
    # ★ 길이가 다르면 zip 이 조용히 잘라서 **다른 축 이름에 다른 배율**이 붙는다
    #   (14축 표 vs 13축 데이터가 정확히 그랬다). 조용한 오표기 대신 즉시 죽는다.
    if len(mod) != len(STATS):
        raise SystemExit(f'statMod 길이 {len(mod)} != STATS {len(STATS)} — '
                         f'AX_NAME(gen_career_34)과 데이터가 어긋났다')
    rows = []
    top = max(range(len(mod)), key=lambda i: mod[i])
    for i, (name, v) in enumerate(zip(STATS, mod)):
        cls = 'up' if v > 1.005 else ('dn' if v < 0.995 else 'fl')
        mark = ' ★' if (shape and i == top) else ''
        rows.append(f'<tr><th>{name}{mark}</th><td class="{cls}">{v:.2f}</td></tr>')
    lab = (f'STATMOD {len(STATS)}축 — ★ 가 shape 대표' if shape
           else f'STATMOD {len(STATS)}축 — <b>축 없음</b> · {len(STATS)}축 균등')
    return (f'<div class="mlab">{lab}</div>'
            '<table class="vstat"><tbody>' + ''.join(rows) + '</tbody></table>')


def axis_chip(shape):
    if not shape:
        return '<span class="axis term">축 없음<em>지능 130 고정</em></span>'
    c, top2 = AXIS[shape]
    return f'<span class="axis" style="--c:{c}">{shape}<em>{top2}</em></span>'


def render_l3_below(l2node, l3):
    """★ 35차 — L2(무직) 카드 **안쪽**에 그 아래 L3 를 그린다.

    왜 함수로 뺐나: 종전에는 L1 루프의 형제 레벨에서 l3 를 그려서, 무직이 키워드 0이라
    job div 가 닫힌 뒤에 생활직이 무직 **옆**에 놓였다. 데이터(`parentId`)는
    `l2_jobless` 로 정상이었는데 화면만 계층을 잃고 있었다 — 명세와 보이는 것이 어긋나는
    최악의 형태라 여기서 계층을 화면에도 그대로 옮긴다."""
    kids = [c for c in l3 if c.get('parentId') == l2node['id']]
    if not kids:
        return []
    o = []
    for c in kids:
        kws = c.get('keywords') or []
        o.append('<div class="l3wrap">')
        o.append(f'<div class="l3h"><b>L3 · {c["name"]}</b>'
                 f'<span class="role">{c.get("role") or "생활"}</span>'
                 f'<small>L4 {len(kws)}장 = 적성 13종 1:1</small></div>')
        o.append(f'<p class="jdesc">{c["desc"]}</p>')
        o.append('<p class="jdesc note">★ 이 갈래에는 <b>축이 없다</b> — 무(空) 는 스탯을 '
                 '재배분하지 않는다. L4 카드는 statMod 13축이 <b>전부 '
                 f'{kws[0]["statMod"][0]:.2f} 로 같다</b>. 티어 2 와 3 이 섞여 있어도 배율은 '
                 '같다 — 다른 것은 축이 아니라 실물(채집·생산·제작) 이다. 그래서 스탯표를 '
                 '붙이지 않는다: 13줄이 전부 같은 숫자일 뿐이다.</p>')
        o.append('<div class="kws l4">')
        for k in kws:
            o.append('<div class="kw">')
            o.append(f'<div class="kh"><span class="kname">{k["name"]}</span>'
                     f'<span class="tier t{k["tier"]}">{k["tier"]}</span>'
                     f'<span class="axis term">축 없음<em>{k.get("domain") or ""}</em></span></div>')
            o.append(f'<p class="kdesc">{k["desc"]}</p>')
            o.append('</div>')            # .kw 닫기
        o.append('</div>')                # .kws 닫기
        o.append('</div>')                # .l3wrap 닫기
    return o


def render():
    with open(TREE, encoding='utf-8') as fh:
        root = json.load(fh)
    jobs = root['jobs']
    l1 = [j for j in jobs if j['stage'] == 1]
    l2 = [j for j in jobs if j['stage'] == 2]
    l3 = [j for j in jobs if j['stage'] == 3]          # 35차 — 생활직 1종
    nkw = sum(len(j.get('keywords') or []) for j in l2 + l3)

    o = [f'<!doctype html><html lang="ko"><head><meta charset="utf-8">',
         '<meta name="viewport" content="width=device-width,initial-scale=1">',
         f'<title>FONS · 직업 트리 {root["version"]}</title>',
         f'<style>{CSS}</style></head><body><main>',
         f'<div class="eyebrow">FONS · career tree</div>'
         f'<span class="badge">v{root["version"]} · job_tree.json 에서 자동 생성</span>',
         '<h1>직업은 L2 까지.<br>그 옆에 키워드 하나.</h1>',
         '<p class="lede">L3 층은 30차에서 없앴고, 그 자리를 키워드 '
         f'{nkw}개가 대신한다. 키워드마다 스탯 13축 배율과 난이도 티어가 붙는다. '
         f'L2 {root["l2Count"]}종이 최종 직업이다. 카드마다 CP 배율 `power` 가 있고 '
         '(×1.00 ~ ×1.22 · 중앙 ×1.16), 키워드가 실제로 올리는 CP 가 그 값과 같다. '
         '같은 직업 안의 차이는 어느 스탯이 오르느냐다.</p>',
         '<div class="stats">'
         f'<div class="stat"><b>{root["l1Count"]}</b><span>L1 계열</span></div>'
         f'<div class="stat"><b>{root["l2Count"]}</b><span>L2 = 최종 직업</span></div>'
         f'<div class="stat"><b>{root.get("l3Count", 0)}</b><span>L3 생활직</span></div>'
         f'<div class="stat"><b>{nkw}</b><span>키워드</span></div>'
         '<div class="stat"><b>×1.16</b><span>키워드 median CP 상승</span></div></div>',
         '<p class="note">statMod <b>13축</b>은 HP · ATK · DEF · 공속 · MAG · MDEF · CRI · '
         'PEN · <b>MPEN</b> · <b>MS</b> · CDMG · STA · MANA. '
         '38차에 회피율(EVA)은 없앴다 — 몸을 빼는 확률 대신 <b>민첩 = 이동속도</b>만 남겼다. '
         '33차까지 7축이었고 eva·cdmg·spd_cast·sta 를 통째로 자르고 있었다. '
         'MPEN(마법 관통)은 34차 신설 — 마법 피해가 관통을 무시하던 것을 '
         '물리 관통과 대칭으로 되돌렸다. 35차 후속5에서 시전속도는 공속에 통합되고 '
         '마나가 정식 축이 됐다. '
         '<b>티어는 1/2/3 이며 1 이 가장 어렵다.</b> '
         'L2 전직 난이도 티어(A=쉬움)와는 별개이고 방향도 반대다. '
         '<b>스킬 상향은 33차에 삭제했다</b> — 키워드는 순수 스탯 장비다. '
         '<b>같은 L2 의 세 키워드는 축이 전부 다르다</b> — 같으면 세 갈래 중 '
         '둘이 구별되지 않는다.</p>',
         '<div class="axiskey">']
    for name, (c, top2) in AXIS.items():
        o.append(f'<span class="axis" style="--c:{c}">{name}<em>{top2}</em></span>')
    o.append('</div>')

    for a in l1:
        o.append('<div class="l1">')
        kids = [b for b in l2 if b['parentId'] == a['id']]
        leaf = '' if kids else ' · 리프 · 키워드 없음'
        o.append(f'<div class="l1h"><b>{a["name"]}</b>'
                 f'<span class="role">{a["role"]}</span>'
                 f'<small>법칙 {law_text(a["lawTags"])}{leaf}</small></div>')
        o.append(f'<p class="ldesc">{a["desc"]}</p>')
        for b in kids:
            kws = b.get('keywords') or []
            is_term = b.get('spiritRoll') or len(kws) != 3
            o.append(f'<div class="job{" term" if is_term else ""}">')
            o.append(f'<div class="jh"><b>{b["name"]}</b>'
                     f'<span class="jlaw">{law_text(b["lawTags"])}</span>'
                     f'<span class="role">{b["role"]}</span>')
            if b.get('spiritRoll'):
                o.append('<span class="bt">★ 종점</span>')
            o.append('</div>')
            o.append(f'<p class="jdesc">{b["desc"]}</p>')
            if b.get('spiritRoll'):
                o.append('<p class="jdesc">전직 때 7정령 중 하나가 확률로 배정되고 '
                         '무(空)만 가중치 0.12다. 무 정령은 마나 그 자체라 나머지보다 '
                         '1.96% 로만 나온다. 이름은 <b>앞에 정령이 붙는다</b> — '
                         '화염정령기사 · 물정령기사 · 무정령기사.</p>')
            if not kws:
                # ★ 35차 — 무직(L2) 은 키워드가 없고 그 아래 L3 생활직이 매달려 있다.
                #   L1 루프의 형제 레벨에서 그렸더니(종전) 생활직이 무직 **옆**에 그려져
                #   "무명자 › 무직 › 생활직" 이라는 계층이 화면에서 사라졌다.
                #   이제 **무직 카드 안쪽**에 그린다.
                o.extend(render_l3_below(b, l3))
                o.append('</div>')
                continue
            o.append('<div class="kws">')
            for c in kws:
                rule = ''
                if c.get('nameRule') in ('firstElement', 'spirit'):
                    rule = '<sup>*</sup>'
                cond = ''
                if c.get('condition') == 'allSixElements':
                    cond = '<span class="cond">6원소 전부</span>'
                o.append('<div class="kw">')
                o.append(f'<div class="kh"><span class="kname">{c["name"]}{rule}</span>'
                         f'<span class="tier t{c["tier"]}">{c["tier"]}</span>'
                         f'{axis_chip(c.get("shape"))}{cond}</div>')
                o.append(f'<p class="kdesc">{c["desc"]}</p>')
                o.append(stat_table(c['statMod'], c.get('shape')))
                o.append('</div>')
            o.append('</div></div>')

        o.append('</div>')

    o.append(f'<footer>v{root["version"]} — 이 문서는 <code>gen_career_html.py</code> 가 '
             '<code>job_tree.json</code> 에서 만든다. 손으로 고치지 마라. '
             '트리가 바뀌면 이 스크립트만 다시 돌리면 따라온다.</footer>')
    o.append('</main></body></html>')
    return '\n'.join(o)


def main():
    html = render()
    with open(OUT, 'w', encoding='utf-8') as fh:
        fh.write(html)
    print(f'OK — {os.path.relpath(OUT, ROOT)} ({len(html):,} bytes)')


if __name__ == '__main__':
    main()
