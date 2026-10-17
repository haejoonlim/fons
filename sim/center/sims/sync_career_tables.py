#!/usr/bin/env python3
# ─────────────────────────────────────────────────────────────────────
# sync_career_tables.py — GDD 05 §8-1 직업 트리 표를 job_tree.json 에서 재생성
#
# 2026-09-29: 24차에서 "런타임·테스트는 초록, 정본 문서만 옛값"인 조용한
# 드리프트가 났다. 원인은 표를 손으로 유지했다는 것. 이 스크립트는 표를
# **데이터에서 생성**하므로 같은 부류의 드리프트가 구조적으로 불가능하다.
#
# 사용: python3 sync_career_tables.py [--check]
#   --check 는 파일을 고치지 않고 어긋난지만 보고한다 (exit 1)
# ─────────────────────────────────────────────────────────────────────
import ast
import json
import os
import re
import sys

TOOLS = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(TOOLS, '..', '..', '..'))
TREE = os.path.join(ROOT, 'data', 'job_tree.json')
DOC = os.path.join(ROOT, 'docs', 'gdd', 'GDD_v8.0_05_영웅생성.md')
GACHA = os.path.join(TOOLS, 'gacha_test.py')

LAW = {'fire': '화염', 'water': '물', 'earth': '대지', 'wind': '바람',
       'light': '빛', 'dark': '어둠', 'void': '무'}

BEGIN = '<!-- AUTO-CAREER-TREE:BEGIN -->'
END = '<!-- AUTO-CAREER-TREE:END -->'

BEGIN2 = '<!-- AUTO-L2-COEF:BEGIN -->'
END2 = '<!-- AUTO-L2-COEF:END -->'


def _dict_from_module(path, name):
    """gacha_test.py 를 실행하지 않고 dict 리터럴만 뽑는다 (부작용 회피)."""
    with open(path, encoding='utf-8') as fh:
        tree = ast.parse(fh.read())
    for node in tree.body:
        if isinstance(node, ast.Assign) and any(
                isinstance(t, ast.Name) and t.id == name for t in node.targets):
            return ast.literal_eval(node.value)
    raise SystemExit(f'FAIL — {path} 에서 {name} 을 찾지 못했다')


def law_text(tags):
    if not tags:
        return '—'
    return '·'.join(LAW.get(t, t) for t in tags)


def render():
    with open(TREE, encoding='utf-8') as fh:
        root = json.load(fh)
    jobs = root['jobs']
    l1 = [j for j in jobs if j['stage'] == 1]
    l2 = [j for j in jobs if j['stage'] == 2]
    nkw = root.get('keywordCount', sum(len(j.get('keywords') or []) for j in l2))

    out = [BEGIN, '']
    out.append(f"> **이 표는 자동 생성입니다** — `job_tree.json`(v{root['version']})에서 뽑았습니다.")
    out.append('> `design-docs/_tools/sync_career_tables.py`로 다시 만듭니다. **손으로 고치지 마세요.**')
    out.append(f"> 총계: **L1 {root['l1Count']} · L2 {root['l2Count']}(최종 직업) · 키워드 {nkw}**"
               f" — **30차부터 L3 층은 없다**")
    out.append('>')
    out.append('> **33차 — 스탯 축 8종의 뜻**: `공격`(ATK·CRI) · `속도`(공속) · `방어`(HP·DEF) · '
               '`마법`(ATK·MAG) · `회복`(HP·MAG) · `내구`(HP·DEF) · `민첩`(공속·CRI) · `균형`(HP·ATK).')
    out.append('> 괄호는 그 축 벡터의 **최상위 2개 스탯**이다. 축 이름과 설명이 어긋날 수 없도록 '
               '생성기 R9 가 HARD 로 대조한다.')
    out.append('> 30차의 `속성`은 원소가 아니라 MAG 였고 `중화`·`지속`은 무엇을 말하는지 읽히지 않았다. '
               '31차가 **이름이 곧 무엇이 오르는지 말하게** 다시 썼고, 33차는 그 두 축을 확정했다.')
    out.append('')

    out.append('### L1 → L2 → 키워드 전체 구조')
    out.append('')
    out.append('| L1 | L2 (최종 직업) | L2 역할 | 법칙 | 키워드 |')
    out.append('|---|---|---|---|---|')
    for a in l1:
        kids = [j for j in l2 if j['parentId'] == a['id']]
        if not kids:
            out.append(f"| **{a['name']}** ({a['role']}) | — | — | {law_text(a['lawTags'])} | "
                       f"**없음 (리프)** |")
            continue
        for i, b in enumerate(kids):
            kws = b.get('keywords') or []
            if kws:
                # 31차 — 종점 키워드는 이름이 런타임에 정해지므로 표시한다
                names = ' · '.join(
                    f"**{c['name']}**" + (' *(영웅의 첫 원소로 이름 결정)*' if c.get('nameRule') == 'firstElement' else '')
                    for c in kws)
            else:
                names = '**종점 (키워드 없음)**'
            a_cell = f"**{a['name']}** ({a['role']})" if i == 0 else ''
            out.append(f"| {a_cell} | {b['name']} | {b['role']} | {law_text(b['lawTags'])} | {names} |")
    out.append('')

    out.append('### 키워드 상세 — 스탯 방향 · 티어')
    out.append('')
    out.append('> **티어는 1/2/3 이며 1 이 가장 어렵다** (34차). L2 전직 난이도 티어(A=쉬움·B·C=어려움)와는 '
               '**별개**이며 방향도 반대다 — 어휘가 겹치지 않게 하려고 바꾼 것이다.')
    out.append('')
    out.append('> 33차부터 **스킬 상향(skillTags·skillUp)은 없다** — 키워드는 순수 스탯 장비다.')
    out.append('')
    out.append('| L2 | 키워드 | 티어 | 스탯 축 | statMod (HP ATK DEF 공속 MAG MDEF CRI) | 설명 |')
    out.append('|---|---|---|---|---|---|')
    for b in l2:
        kws = b.get('keywords') or []
        if not kws:
            out.append(f"| {b['name']} | **— 종점 —** | — | — | — | {b['desc']} |")
            continue
        for i, c in enumerate(kws):
            mod = ' · '.join(f"{v:g}" for v in c['statMod'])
            b_cell = b['name'] if i == 0 else ''
            # 31차 — 종점 키워드는 축이 없다 (이름이 런타임에 정해지므로 고정하지 않는다)
            shape = c.get('shape') or '**종점** (축 없음)'
            out.append(f"| {b_cell} | **{c['name']}** | {c['tier']} | {shape} | {mod} | {c['desc']} |")
    out.append('')
    out.append(END)
    return '\n'.join(out)


def render_l2_coef():
    """L2 계수·티어 표 — gacha_test.JOB_COEF_L2 / JOB_TIER 에서 생성.
    29차 이전에 이 표는 손으로 유지되어 24차 이름(방벽기사·그림자자객·처형자)이 남아 있었다."""
    with open(TREE, encoding='utf-8') as fh:
        root = json.load(fh)
    coef = _dict_from_module(GACHA, 'JOB_COEF_L2')
    tier = _dict_from_module(GACHA, 'JOB_TIER')
    jobs = root['jobs']
    parent = {j['id']: next(k['name'] for k in jobs if k['id'] == j['parentId'])
              for j in jobs if j['stage'] == 2}
    order = [j for j in jobs if j['stage'] == 2]

    out = [BEGIN2, '']
    out.append('> **이 표도 자동 생성입니다** — `gacha_test.py`의 `JOB_COEF_L2`(계수)와 '
               '`JOB_TIER`(전직 난이도 티어)에서 뽑았습니다.')
    out.append('> `design-docs/_tools/sync_career_tables.py`로 다시 만듭니다. **손으로 고치지 마세요.**')
    out.append('')
    out.append('| L2 | 부모 | 티어 | HP | ATK | DEF | 공속 | MAG | MDEF | CRI |')
    out.append('|---|---|---|---|---|---|---|---|---|---|')
    for j in order:
        n = j['name']
        if n not in coef:
            out.append(f"| {n} | {parent[j['id']]} | — | " + ' | '.join(['—'] * 7) + ' |')
            continue
        c = coef[n]
        cells = ' | '.join(f'{v:g}' if isinstance(v, float) else str(v) for v in c)
        out.append(f"| {n} | {parent[j['id']]} | {tier.get(n, '—')} | {cells} |")
    out.append('')
    out.append(END2)
    return '\n'.join(out)


def main():
    block = render()
    block2 = render_l2_coef()
    with open(DOC, encoding='utf-8') as fh:
        doc = fh.read()
    if BEGIN not in doc or END not in doc:
        print(f"FAIL — {DOC} 에 자동 생성 블록 마커가 없다 "
              f"({BEGIN} … {END})")
        return 1
    if BEGIN2 not in doc or END2 not in doc:
        print(f"FAIL — {DOC} 에 L2 계수 자동 생성 블록 마커가 없다 "
              f"({BEGIN2} … {END2})")
        return 1
    new = re.sub(re.escape(BEGIN) + r'.*?' + re.escape(END), block, doc, flags=re.S)
    new = re.sub(re.escape(BEGIN2) + r'.*?' + re.escape(END2), block2, new, flags=re.S)
    if '--check' in sys.argv:
        if new == doc:
            print('OK — 05 §8-1 표가 job_tree.json 과 일치한다')
            return 0
        print('FAIL — 05 §8-1 표가 job_tree.json 과 어긋난다 '
              '(python3 sync_career_tables.py 로 재생성)')
        return 1
    if new == doc:
        print('OK — 이미 일치 (변경 없음)')
        return 0
    with open(DOC, 'w', encoding='utf-8') as fh:
        fh.write(new)
    print('OK — 05 §8-1 표를 job_tree.json 에서 재생성했다')
    return 0


if __name__ == '__main__':
    sys.exit(main())
