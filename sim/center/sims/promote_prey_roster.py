#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""먹이층 0인 17바이옴을 도감 야생종 승격으로 채운다 (멱등).

근거: docs/design/피식자_보강_설계.md
     전투먹이 8종이 전부 tier 1~2라 61층 위 65층은 편성 후보에 먹이층이 없다.
     도감에는 그 바이옴에 사는 prey·swarm 이 2~8종씩 있는데, 전투 프로필이 없어
     `FonsEncounter` 후보(`spawn.mode` = encounter·elite)에 안 들어온다.

무엇을 하나
    `ambient.json` 의 개체를 `monsters.json` 으로 **옮긴다** (새 종을 만들지 않는다).
    도감 377 = 13×29 불변식은 그대로다 — 전투 143 → 162 · 비전투 234 → 215.
    성격 레코드(`monster_personality.json`)도 함께 만든다 (전투 개체 수 = 성격 수).

    스탯은 손으로 정하지 않는다 — §3 밴드(tier 전투종 중앙값 HP · 하위 4분위 공격 축)를
    그대로 쓴다. 먹이층 보장이 **가장 약한 자리**를 비우므로 HP 를 중앙값에 맞춰야
    층 HP 합이 안 흔들린다 (생태_출현표 §5-2 의 A/B 가 그 근거다).

    바이옴이 tier 경계에 걸친 둘(침전수로 51~55 · 역류폭포 101~105)은 한 종씩 더 둔다.
    한 종으로 밀면 낮은 쪽 2~4층이 그 tier 최저 HP 종보다 훨씬 센 피식자를 받는다.

사용: ./.venv/bin/python sim/center/sims/promote_prey_roster.py [--check]
      --check 는 쓰지 않고 검사만 한다 (게이트·리뷰용)
"""
import argparse
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(HERE)))
DATA = os.path.join(ROOT, 'data')
PATH = {
    'monsters': os.path.join(DATA, 'monsters.json'),
    'ambient': os.path.join(DATA, 'ambient.json'),
    'persona': os.path.join(DATA, 'monster_personality.json'),
    'codex': os.path.join(DATA, 'ecology_codex.json'),
}

CODEX_TOTAL = 377          # 13×29 — 새 종을 만들지 않는다
TOTAL_COMBAT = 162         # 143 + 승격 19
TOTAL_AMBIENT = 215        # 234 - 승격 19

# §3 밴드 — tier 전투종 HP 중앙값 · ATK·DEF·MDEF 하위 4분위 (승격 전 143종 실측).
STATS = {
    1: {'hp': 190, 'atk': 10, 'def': 5, 'mdef': 3},
    2: {'hp': 581, 'atk': 26, 'def': 8, 'mdef': 6},
    3: {'hp': 2633, 'atk': 70, 'def': 23, 'mdef': 13},
    4: {'hp': 9200, 'atk': 180, 'def': 42, 'mdef': 10},
    5: {'hp': 29500, 'atk': 380, 'def': 62, 'mdef': 16},
}
# 부가 축은 배율을 안 타므로 같은 tier 전투종 중앙값을 쓴다.
EXTRA = {
    1: {'aspd': 9, 'cri': 6, 'cdmg': 140, 'sta': 60, 'eva': 10},
    2: {'aspd': 13, 'cri': 6, 'cdmg': 150, 'sta': 80, 'eva': 8},
    3: {'aspd': 12, 'cri': 6, 'cdmg': 150, 'sta': 80, 'eva': 8},
    4: {'aspd': 11, 'cri': 5, 'cdmg': 150, 'sta': 93, 'eva': 8},
    5: {'aspd': 14, 'cri': 6, 'cdmg': 150, 'sta': 90, 'eva': 8},
}
THREAT = {1: 21.0, 2: 44.0, 3: 87.5, 4: 105.0, 5: 139.0}
LOOT = {
    1: {'soul': ['하'], 'gold': 50, 'exp': 20},
    2: {'soul': ['하'], 'gold': 310, 'exp': 162},
    3: {'soul': ['중'], 'gold': 1465, 'exp': 446},
    4: {'soul': ['중'], 'gold': 3100, 'exp': 820},
    5: {'soul': ['중'], 'gold': 4512, 'exp': 1200},
}

# ── 승격 19종 ────────────────────────────────────────────────────────────
# persona = 성격 축(공격성·무리성·영역성은 도감 값). band 는 기존 먹이층 표기를 따른다.
# why = 이 자리에 이 종인 이유 (설계 §4 근거).
SPECS = [
    {'id': 'mon_sardine_01', 'name': '소어 떼', 'tier': 1, 'floors': [11, 15],
     'persona': {'fear': 0.80, 'vengeance': 0.05, 'allyPriority': 0.60,
                 'intelligence': 0.12, 'band': 'T1'},
     'why': '원천연안 전투 포식자 넷이 이미 prey 로 적어 둔 종 — 간선이 처음으로 전투에 닿는다'},
    {'id': 'mon_papermite_01', 'name': '종이개미', 'tier': 1, 'floors': [16, 20],
     'persona': {'fear': 0.50, 'vengeance': 0.05, 'allyPriority': 0.90,
                 'intelligence': 0.05, 'band': 'T1'},
     'why': '양피지 좀비의 prey — 서고 유일의 먹이 간선'},
    {'id': 'mon_citypigeon_01', 'name': '도시비둘기', 'tier': 1, 'floors': [21, 25],
     'persona': {'fear': 0.85, 'vengeance': 0.02, 'allyPriority': 0.60,
                 'intelligence': 0.20, 'band': 'T1'},
     'why': '미궁도시 사념포식자의 prey — 도감 floors 가 1~130 전 층'},
    {'id': 'mon_templedove_01', 'name': '신전비둘기', 'tier': 2, 'floors': [31, 35],
     'persona': {'fear': 0.85, 'vengeance': 0.02, 'allyPriority': 0.55,
                 'intelligence': 0.18, 'band': 'T2'},
     'why': '서약성소 후보가 정령·수호뿐이라 그물 밖뿐 3층 — 성소에 사는 유일한 prey'},
    {'id': 'mon_ruinpig_01', 'name': '폐허멧돼지', 'tier': 2, 'floors': [41, 45],
     'persona': {'fear': 0.70, 'vengeance': 0.15, 'allyPriority': 0.60,
                 'intelligence': 0.18, 'band': 'T2'},
     'why': '흉고블린·잔해탐지충의 prey — 잿마을 사냥 사슬의 1차 소비자'},
    {'id': 'mon_trenchlanternfish_01', 'name': '해구 등불어', 'tier': 2, 'floors': [46, 50],
     'persona': {'fear': 0.70, 'vengeance': 0.05, 'allyPriority': 0.75,
                 'intelligence': 0.10, 'band': 'T2'},
     'why': '먹빛 해구 후보가 apex·predator 뿐 — 심해 사슬의 먹이 자리'},
    {'id': 'mon_backworm_01', 'name': '배수충', 'tier': 2, 'floors': [51, 52],
     'persona': {'fear': 0.45, 'vengeance': 0.05, 'allyPriority': 0.95,
                 'intelligence': 0.03, 'band': 'T2'},
     'why': '침전수로 51~52 는 tier 2 — 하수 관로의 군집 먹이'},
    {'id': 'mon_sewerslug_01', 'name': '슬러지 벌레', 'tier': 3, 'floors': [53, 55],
     'persona': {'fear': 0.60, 'vengeance': 0.05, 'allyPriority': 0.70,
                 'intelligence': 0.08, 'band': 'T2'},
     'why': '침전수로 53~55 는 tier 3 — 같은 블록에서 승격해야 층 HP 가 안 흔들린다'},
    {'id': 'mon_frog_01', 'name': '개구리', 'tier': 3, 'floors': [61, 65],
     'persona': {'fear': 0.85, 'vengeance': 0.02, 'allyPriority': 0.50,
                 'intelligence': 0.15, 'band': 'T2'},
     'why': '늪도마뱀·늪지기사의 prey — 부유 이끼늪의 사슬이 여기서 시작된다'},
    {'id': 'mon_plumed_deer_01', 'name': '깃털사슴', 'tier': 3, 'floors': [66, 70],
     'persona': {'fear': 0.80, 'vengeance': 0.03, 'allyPriority': 0.70,
                 'intelligence': 0.22, 'band': 'T2'},
     'why': '정글 표범의 prey 이고 도감 블록도 14 로 같다'},
    {'id': 'mon_ashland_01', 'name': '요흔사슴', 'tier': 4, 'floors': [91, 95],
     'persona': {'fear': 0.75, 'vengeance': 0.05, 'allyPriority': 0.65,
                 'intelligence': 0.24, 'band': 'T2'},
     'why': '지옥사냥개의 prey — 맥의 상흔 tier 4 유일한 먹이 자리'},
    {'id': 'mon_creviceech_01', 'name': '틈새우레지', 'tier': 4, 'floors': [96, 100],
     'persona': {'fear': 0.65, 'vengeance': 0.10, 'allyPriority': 0.50,
                 'intelligence': 0.12, 'band': 'T2'},
     'why': '무광심연 후보가 분해자·포식자뿐 — 심연 블록의 먹이 자리'},
    {'id': 'mon_starsandworm_01', 'name': '별모래 벌레', 'tier': 4, 'floors': [101, 104],
     'persona': {'fear': 0.60, 'vengeance': 0.05, 'allyPriority': 0.60,
                 'intelligence': 0.08, 'band': 'T2'},
     'why': '역류폭포 101~104 는 tier 4 — 후보가 정령뿐이라 사슬이 없던 층'},
    {'id': 'mon_stardust_01', 'name': '별가루', 'tier': 5, 'floors': [105, 105],
     'persona': {'fear': 0.40, 'vengeance': 0.05, 'allyPriority': 0.95,
                 'intelligence': 0.05, 'band': 'T2'},
     'why': '역류폭포 105 는 tier 5 — 104/105 경계에서 종을 나눈다'},
    {'id': 'mon_glaciaribou_01', 'name': '얼음사슴', 'tier': 5, 'floors': [106, 110],
     'persona': {'fear': 0.80, 'vengeance': 0.03, 'allyPriority': 0.70,
                 'intelligence': 0.22, 'band': 'T2'},
     'why': '광로들판 후보가 predator 뿐 — 동결 해양 상위 블록의 먹이 자리'},
    {'id': 'mon_crystaldeer_01', 'name': '수정노루', 'tier': 5, 'floors': [111, 115],
     'persona': {'fear': 0.75, 'vengeance': 0.05, 'allyPriority': 0.60,
                 'intelligence': 0.20, 'band': 'T2'},
     'why': '형상군락 후보가 정령·수호·포식자뿐 — 수정 숲의 먹이 자리'},
    {'id': 'mon_glasslizard_01', 'name': '유리 도마뱀', 'tier': 5, 'floors': [116, 120],
     'persona': {'fear': 0.70, 'vengeance': 0.08, 'allyPriority': 0.40,
                 'intelligence': 0.18, 'band': 'T2'},
     'why': '마른 지맥 후보가 수호·포식자뿐 — 그물 밖뿐 5층을 닫는다'},
    {'id': 'mon_weightlessbug_01', 'name': '무게 없는 벌레', 'tier': 5, 'floors': [121, 125],
     'persona': {'fear': 0.65, 'vengeance': 0.05, 'allyPriority': 0.50,
                 'intelligence': 0.06, 'band': 'T2'},
     'why': '찢긴 천창 후보가 정령·포식자뿐 — 중력 dust 를 먹는 벌레'},
    {'id': 'mon_borderfly_01', 'name': '경계눈박이', 'tier': 5, 'floors': [126, 130],
     'persona': {'fear': 0.60, 'vengeance': 0.10, 'allyPriority': 0.55,
                 'intelligence': 0.30, 'band': 'T2'},
     'why': '이데아 문턱 후보가 수호·포식자뿐 — 문턱의 마지막 먹이 자리'},
]


def load(path):
    with open(path, encoding='utf-8') as fh:
        return json.load(fh)


# 파일마다 들여쓰기가 다르다 — 손대지 않은 부분이 재포맷되어 diff 를 덮지 않게 맞춘다.
FMT = {'monsters': (2, True), 'ambient': (2, True), 'persona': (1, False)}


def dump(kind, obj):
    indent, trailer = FMT[kind]
    with open(PATH[kind], 'w', encoding='utf-8') as fh:
        json.dump(obj, fh, ensure_ascii=False, indent=indent)
        if trailer:
            fh.write('\n')


def fail(msg):
    raise SystemExit('FAIL — ' + msg)


def build(spec, base):
    """ambient 개체 → 전투 개체. 원소·저항·면역·패턴·생태는 원본 승계."""
    tier = spec['tier']
    stats = dict(STATS[tier])
    stats.update(EXTRA[tier])
    lo, hi = spec['floors']
    return {
        'id': spec['id'],
        'name': spec['name'],
        'category': base['category'],
        'aiType': base['aiType'],
        'tier': tier,
        'level': [int(round(lo * 1.3)), int(round(hi * 1.3))],
        'threatBase': THREAT[tier],
        'element': base['element'],
        'stats': stats,
        'weakness': base['weakness'],
        'resistance': base['resistance'],
        'statusImmune': base['statusImmune'],
        'aiDecision': base['aiDecision'],
        'pattern': base['pattern'],
        'parts': base.get('parts', []),
        'spawn': {'floors': spec['floors'], 'mode': 'encounter'},
        'loot': LOOT[tier],
        'ecology': dict(base['ecology']),
    }


def persona_of(spec, base):
    """CombatPersona v2 — 공격성·영역성·무리성은 도감 값, 나머지는 개체 성격."""
    eco = base['ecology']
    p = spec['persona']
    return {
        'id': spec['id'], 'name': spec['name'],
        'aggression': eco['aggression'],
        'territoriality': eco['territoriality'],
        'sociality': eco['sociality'],
        'fear': p['fear'],
        'vengeance': p['vengeance'],
        'allyPriority': p['allyPriority'],
        'intelligence': p['intelligence'],
        'band': p['band'],
        'preyIds': [x for x in eco['prey'] if str(x).startswith('mon_')],
        'preyResources': [x for x in eco['prey'] if not str(x).startswith('mon_')],
        'activity': eco['activity'],
    }


def check(monsters, ambient, personas, codex):
    by_codex = {e['id']: e for e in codex['entries']}
    mon = {m['id']: m for m in monsters['monsters']}
    amb = {a['id']: a for a in ambient['ambient']}
    per = {p['id']: p for p in personas['personas']}

    if len(codex['entries']) != CODEX_TOTAL:
        fail('도감 종수가 %d — %d(13×29) 여야 한다 (새 종을 만들지 않는다)'
             % (len(codex['entries']), CODEX_TOTAL))
    if len(monsters['monsters']) != TOTAL_COMBAT:
        fail('전투 개체가 %d — %d 여야 한다 (승격 19종)'
             % (len(monsters['monsters']), TOTAL_COMBAT))
    if len(ambient['ambient']) != TOTAL_AMBIENT:
        fail('비전투 개체가 %d — %d 여야 한다 (승격 19종)'
             % (len(ambient['ambient']), TOTAL_AMBIENT))
    if set(mon) & set(amb):
        fail('전투·비전투에 같은 id: ' + ', '.join(sorted(set(mon) & set(amb))[:5]))
    if len(per) != len(mon):
        fail('성격 %d ≠ 전투 개체 %d' % (len(per), len(mon)))
    if personas.get('meta', {}).get('count') != len(per):
        fail('성격 meta.count %r ≠ 실제 %d' % (personas.get('meta', {}).get('count'), len(per)))

    for s in SPECS:
        sid, name, tier = s['id'], s['name'], s['tier']
        e = by_codex.get(sid)
        if e is None:
            fail('생태도감에 없는 개체: %s' % name)
        if sid in amb:
            fail('아직 ambient 에 남아 있다: %s' % name)
        m = mon.get(sid)
        if m is None:
            fail('전투 개체가 없다: %s' % name)
        p = per.get(sid)
        if p is None:
            fail('성격 레코드가 없다: %s' % name)
        for label, obj in (('개체', m), ('성격', p), ('도감', e)):
            if obj['name'] != name:
                fail('이름 불일치(%s): %s ≠ %s' % (label, name, obj['name']))
        if int(m['tier']) != tier:
            fail('tier 불일치: %s %r ≠ %d' % (name, m['tier'], tier))
        if list(m['spawn']['floors']) != s['floors'] or m['spawn'].get('mode') != 'encounter':
            fail('출현 불일치: %s %r' % (name, m['spawn']))
        want = dict(STATS[tier])
        want.update(EXTRA[tier])
        got = {k: m['stats'].get(k) for k in want}
        for key, value in want.items():
            if int(got[key] or 0) != value:
                fail('스탯이 밴드와 다르다: %s %s=%r (기대 %d)' % (name, key, got[key], value))
        if float(m['threatBase']) != THREAT[tier]:
            fail('위협도가 다르다: %s %r' % (name, m['threatBase']))
        if m['loot'] != LOOT[tier]:
            fail('전리품이 다르다: %s %r' % (name, m['loot']))
        # M-9 미러 — habitat·diet·role 은 도감과 같아야 한다.
        eco = m['ecology']
        if set(eco['habitat']) != set(e['habitat']) or eco['diet'] != e['diet'] \
                or eco['role'] != e['role']:
            fail('도감 미러 불일치: %s' % name)


def apply(monsters, ambient, personas):
    want = {s['id'] for s in SPECS}
    moved = [a for a in ambient['ambient'] if a['id'] in want]
    ambient['ambient'] = [a for a in ambient['ambient'] if a['id'] not in want]

    by_amb = {a['id']: a for a in moved}
    have = {m['id'] for m in monsters['monsters']}
    for spec in SPECS:
        if spec['id'] in have:
            continue
        base = by_amb.get(spec['id'])
        if base is None:
            fail('옮길 원본이 ambient 에도 monsters 에도 없다: %s' % spec['name'])
        monsters['monsters'].append(build(spec, base))
    monsters['monsters'].sort(key=lambda m: m['id'])

    have_per = {p['id'] for p in personas['personas']}
    for spec in SPECS:
        if spec['id'] in have_per:
            continue
        base = by_amb.get(spec['id'])
        if base is None:
            fail('성격을 만들 원본이 없다: %s' % spec['name'])
        personas['personas'].append(persona_of(spec, base))
    personas['personas'].sort(key=lambda p: p['id'])
    personas['meta']['count'] = len(personas['personas'])
    personas['meta']['note'] = (
        '2026-10-26 — 먹이층 0인 17바이옴 승격 19종 추가 '
        '(설계: docs/design 피식자 보강 설계 · 생성기: 승격 로스터)')


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--check', action='store_true', help='쓰지 않고 검사만 한다')
    args = ap.parse_args()

    monsters = load(PATH['monsters'])
    ambient = load(PATH['ambient'])
    personas = load(PATH['persona'])
    codex = load(PATH['codex'])

    if not args.check:
        apply(monsters, ambient, personas)
        dump('monsters', monsters)
        dump('ambient', ambient)
        dump('persona', personas)
        monsters = load(PATH['monsters'])
        ambient = load(PATH['ambient'])
        personas = load(PATH['persona'])

    check(monsters, ambient, personas, codex)
    print('OK — 승격 %d종 · 전투 %d · 비전투 %d · 도감 %d'
          % (len(SPECS), len(monsters['monsters']), len(ambient['ambient']),
             len(codex['entries'])))
    return 0


if __name__ == '__main__':
    # 계약 G-1~G-4 (`tools/gate_contract.py`) — fail() 의 문자열 SystemExit 도 한 줄로 끝난다.
    sys.path.insert(0, os.path.join(ROOT, 'tools'))
    from gate_contract import run  # noqa: E402
    sys.exit(run('preyroster', main))
