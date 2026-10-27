#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""블록 16·17·20(76~85·96~100층) 전투 로스터를 채운다 (멱등).

왜 이 스크립트가 있나 (근거: docs/design/로스터_보강_화산_사막_심연.md)
    76~85·96~100 이 벽인 이유는 층 스케일이 아니라 편성이다. 세 블록은 자기 층대
    몬스터가 없어서 이웃 블록의 tier 4 를 5칸에 채워 넣고 있었다. 원인은 두 가지다.

      ① 76~80(화산)·96~100(심연)의 `habitat` 이 101~105 에 저작된 정령 6종과 같다.
         `spawn.floors` 는 06 §3.4 가 후보 게이트에서 뺀 기록용 참조라, 20~25층 먼저
         나와도 게이트가 못 잡는다. → 정령 6종을 `["astral"]` 로 옮긴다 (D1).
      ② 76~80·81~85·96~100 에 그 층대의 전투 개체가 없다. → 이미 도감에 있는
         비전투 5종을 전투로 **승격**한다 (D2). 새 종은 만들지 않는다 (377 = 13×29).

    옮기는 것이므로 합 377 은 그대로이고 전투 138 → 143 · 비전투 239 → 234 다.
    (2026-10-26 — 먹이층 승격 19종이 더해져 전투 162 · 비전투 215 가 되었다.
     이 스크립트의 5종은 변하지 않는다. 상수만 현재 값을 센다.)

값은 손으로 정하지 않는다
    `derive()` 가 **비전투 원본 비율 × 같은 tier 전투 밴드 중앙값**으로 계산하고, 밴드
    밖은 밴드 끝으로 자른다. `EXPECTED` 는 derive() 가 내야 하는 값의 사본이며,
    쓰기 전에 둘이 같은지 확인한다 (다르면 손으로 적은 값이 섞였다는 뜻이다).

    hp   = clamp(원본 hp / 60 × tier 중앙값)      ← 60 = T1 전투 hp 중앙
    atk  = clamp(원본 atk / 8 × tier 중앙값)      ← 8  = T1 전투 atk 중앙
    def  = clamp(원본 def × 3.5)                  ← 9  = T1 전투 def 상한
    mdef = clamp(원본 mdef × 2.8)                 ← 4  = T1 전투 mdef 상한
    aspd = clamp(원본 spd, 밴드)                  ← 원본이 이미 같은 축이다
    threat = 밴드 중앙값                          ← 위협도는 tier 가 정한다

사용: ./.venv/bin/python sim/center/sims/gen_block_roster.py [--check]
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

CODEX_TOTAL = 377          # 13×29 — 새 종을 넣지 않는 이유 (docs/gdd 02 §4)
TOTAL_COMBAT = 162         # 143(이 스크립트 5종 포함) + 먹이층 승격 19
TOTAL_AMBIENT = 215        # 234 - 먹이층 승격 19

# tier 대역 — 현행 전투 몬스터(승격 전 138종) 실측 최소·최대. 밖으로 나가면 밴드 끝으로 자른다.
BANDS = {
    2: {'hp': (478, 803), 'atk': (24, 32), 'def': (7, 24), 'mdef': (4, 22),
        'aspd': (8, 17), 'threat': (36.8, 50.2)},
    3: {'hp': (1962, 3583), 'atk': (52, 111), 'def': (16, 54), 'mdef': (10, 46),
        'aspd': (5, 16), 'threat': (76.7, 95.7)},
    4: {'hp': (8493, 12268), 'atk': (60, 260), 'def': (38, 100), 'mdef': (10, 110),
        'aspd': (4, 14), 'threat': (100.7, 118.8)},
}
# 같은 실측의 중앙값 — 비율을 곱하는 기준값이다 (평균이 아니라 중앙값).
MEDIAN = {
    2: {'hp': 598, 'atk': 27, 'threat': 44.0},
    3: {'hp': 2622.5, 'atk': 86, 'threat': 87.5},
    4: {'hp': 9200, 'atk': 184, 'threat': 105.0},
}
DERIVE = {'hp_div': 60.0, 'atk_div': 8.0, 'def_mul': 3.5, 'mdef_mul': 2.8}
# 전리품은 같은 tier 기존 전투 몬스터의 중앙값.
LOOT = {
    2: {'soul': ['하'], 'gold': 310, 'exp': 162},
    3: {'soul': ['중'], 'gold': 1465, 'exp': 446},
    4: {'soul': ['중'], 'gold': 3010, 'exp': 815},
}

# ── 승격 5종 ────────────────────────────────────────────────────────────
# cri·cdmg·eva·sta 는 유도식 밖(원본에 없는 축)이라 개체 성격으로 적는다.
SPECS = [
    {
        'id': 'mon_ashfly_01', 'name': '재 파리떼', 'tier': 2, 'block': 16,
        'floors': [76, 80], 'level': [99, 104],
        'extra': {'cri': 5, 'cdmg': 150, 'eva': 12, 'sta': 60},
        'persona': {'fear': 0.4, 'vengeance': 0.5, 'allyPriority': 0.7,
                    'intelligence': 0.14, 'band': 'N'},
        'why': '화산재를 먹고 번지는 군체 — 76~80층 화산의 유일한 tier 2',
    },
    {
        'id': 'mon_sulfurmite_01', 'name': '유황 진드기', 'tier': 3, 'block': 16,
        'floors': [76, 80], 'level': [99, 104],
        'extra': {'cri': 5, 'cdmg': 150, 'eva': 4, 'sta': 70},
        'persona': {'fear': 0.45, 'vengeance': 0.2, 'allyPriority': 0.5,
                    'intelligence': 0.10, 'band': 'N'},
        'why': '유황 결정을 핥는 껍질 — 원본 def 12 로 가장 단단한 화산 청소부',
    },
    {
        'id': 'mon_slime_red_01', 'name': '붉은슬라임', 'tier': 3, 'block': 16,
        'floors': [76, 80], 'level': [99, 104],
        'extra': {'cri': 4, 'cdmg': 150, 'eva': 6, 'sta': 60},
        'persona': {'fear': 0.55, 'vengeance': 0.1, 'allyPriority': 0.8,
                    'intelligence': 0.06, 'band': 'N'},
        'why': '용암 분해자 — 분열 패턴이 이미 붙어 있어 전투 개체로 그대로 읽힌다',
    },
    {
        'id': 'mon_rustkite_01', 'name': '적갈매', 'tier': 4, 'block': 17,
        'floors': [81, 85], 'level': [105, 111],
        'extra': {'cri': 8, 'cdmg': 160, 'eva': 18, 'sta': 60},
        'persona': {'fear': 0.25, 'vengeance': 0.4, 'allyPriority': 0.4,
                    'intelligence': 0.62, 'band': 'S1'},
        'why': '사막 유일의 상위 포식자 — 81~85층에서 자체 tier 4 를 만드는 유일한 종',
    },
    {
        'id': 'mon_voidjelly_01', 'name': '보이드 젤리', 'tier': 4, 'block': 20,
        'floors': [96, 100], 'level': [125, 130],
        'extra': {'cri': 5, 'cdmg': 150, 'eva': 8, 'sta': 80},
        'persona': {'fear': 0.5, 'vengeance': 0.05, 'allyPriority': 0.9,
                    'intelligence': 0.08, 'band': 'S1'},
        'why': '어둠을 먹는 심연 해파리 — 밴드 상한 HP 로 심연 정점의 압력을 남긴다',
    },
]

# derive() 가 내야 하는 값 (근거 문서 §5 표 · 실측 중앙값으로 계산한 값).
EXPECTED = {
    'mon_ashfly_01': {'hp': 478, 'atk': 24, 'def': 7, 'mdef': 4, 'aspd': 17,
                      'threatBase': 44.0},
    'mon_sulfurmite_01': {'hp': 2622, 'atk': 86, 'def': 42, 'mdef': 14, 'aspd': 6,
                          'threatBase': 87.5},
    'mon_slime_red_01': {'hp': 3583, 'atk': 111, 'def': 16, 'mdef': 11, 'aspd': 6,
                         'threatBase': 87.5},
    'mon_rustkite_01': {'hp': 8493, 'atk': 230, 'def': 38, 'mdef': 10, 'aspd': 14,
                        'threatBase': 105.0},
    'mon_voidjelly_01': {'hp': 12268, 'atk': 253, 'def': 38, 'mdef': 11, 'aspd': 6,
                         'threatBase': 105.0},
}

# ── D1 — 정령 6종 habitat 정합 ──────────────────────────────────────────
# 스탯·tier·이름은 그대로. `spawn.floors`(101~105)와 도감 `group`(중층)이 이미
# summit 을 가리키는데 habitat 만 화산·심연이었다.
SPIRIT_IDS = ('mon_spirit_fire_01', 'mon_spirit_fire_02', 'mon_spirit_fire_03',
              'mon_spirit_dark_01', 'mon_spirit_dark_02', 'mon_spirit_dark_03')
SPIRIT_HABITAT = ['astral']
SPIRIT_BLOCK = 21


def load(path):
    with open(path, encoding='utf-8') as fh:
        return json.load(fh)


# 파일마다 들여쓰기가 다르다 — 손대지 않은 부분이 재포맷되어 diff 를 덮지 않게 맞춘다.
FMT = {'monsters': (2, True), 'ambient': (2, True),
       'persona': (1, False), 'codex': (1, False)}


def dump(kind, obj):
    indent, trailer = FMT[kind]
    with open(PATH[kind], 'w', encoding='utf-8') as fh:
        json.dump(obj, fh, ensure_ascii=False, indent=indent)
        if trailer:
            fh.write('\n')


def fail(msg):
    raise SystemExit('FAIL — ' + msg)


def clamp(v, lo, hi):
    return int(max(lo, min(hi, v)))


def derive(base, tier):
    """ambient 개체 → 같은 tier 전투 스탯. 반올림한 뒤 밴드로 자른다."""
    b = BANDS[tier]
    mid = MEDIAN[tier]
    st = base['stats']
    out = {
        'hp': clamp(round(st['hp'] / DERIVE['hp_div'] * mid['hp']), *b['hp']),
        'atk': clamp(round(st['atk'] / DERIVE['atk_div'] * mid['atk']), *b['atk']),
        'def': clamp(round(st['def'] * DERIVE['def_mul']), *b['def']),
        'mdef': clamp(round(st['mdef'] * DERIVE['mdef_mul']), *b['mdef']),
        'aspd': clamp(int(st['spd']), *b['aspd']),
        'threatBase': mid['threat'],
    }
    return out


def build(spec, base):
    """ambient 개체 → 전투 개체. 원소·저항·면역·패턴은 원본을 승계한다."""
    d = derive(base, spec['tier'])
    stats = {'hp': d['hp'], 'atk': d['atk'], 'def': d['def'], 'aspd': d['aspd'],
             'mdef': d['mdef']}
    stats.update(spec['extra'])
    eco = dict(base['ecology'])
    return {
        'id': spec['id'],
        'name': spec['name'],
        'category': base['category'],
        'aiType': base['aiType'],
        'tier': spec['tier'],
        'level': spec['level'],
        'threatBase': d['threatBase'],
        'element': base['element'],
        'stats': stats,
        'weakness': base['weakness'],
        'resistance': base['resistance'],
        'statusImmune': base['statusImmune'],
        'aiDecision': base['aiDecision'],
        'pattern': base['pattern'],
        'parts': base.get('parts', []),
        'spawn': {'floors': spec['floors'], 'mode': 'encounter'},
        'loot': LOOT[spec['tier']],
        'ecology': eco,
    }


def persona_of(spec, base):
    """CombatPersona v2 — 공격성·무리성은 도감 값을 그대로 쓰고 나머지는 개체 성격.

    preyIds·preyResources 는 원본 ecology.prey 를 id/자원으로 갈라 적는다 (새 이름을 만들지 않는다).
    """
    eco = base['ecology']
    p = dict(spec['persona'])
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
    """값·불변식·D1 정합을 본다 (쓰기 전후 모두 호출)."""
    by_codex = {e['id']: e for e in codex['entries']}
    mon = {m['id']: m for m in monsters['monsters']}
    amb = {a['id']: a for a in ambient['ambient']}
    per = {p['id']: p for p in personas['personas']}

    if len(codex['entries']) != CODEX_TOTAL:
        fail('도감 종수가 %d — %d(13×29) 여야 한다 (새 종을 만들지 않는다)'
             % (len(codex['entries']), CODEX_TOTAL))
    if len(monsters['monsters']) != TOTAL_COMBAT:
        fail('전투 개체가 %d — %d 여야 한다 (승격 5종)'
             % (len(monsters['monsters']), TOTAL_COMBAT))
    if len(ambient['ambient']) != TOTAL_AMBIENT:
        fail('비전투 개체가 %d — %d 여야 한다 (승격 5종)'
             % (len(ambient['ambient']), TOTAL_AMBIENT))
    if set(mon) & set(amb):
        fail('전투·비전투에 같은 id: ' + ', '.join(sorted(set(mon) & set(amb))[:5]))
    if len(per) != len(mon):
        fail('성격 %d ≠ 전투 개체 %d' % (len(per), len(mon)))

    for s in SPECS:
        sid, name = s['id'], s['name']
        e = by_codex.get(sid)
        if e is None:
            fail('생태도감에 없는 개체: %s' % name)
        if s['id'] in amb:
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
        want = EXPECTED[sid]
        got = {'hp': m['stats']['hp'], 'atk': m['stats']['atk'], 'def': m['stats']['def'],
               'mdef': m['stats']['mdef'], 'aspd': m['stats']['aspd'],
               'threatBase': float(m['threatBase'])}
        for key, value in want.items():
            if got[key] != value:
                fail('derive() 값과 다르다: %s %s=%s (기대 %s)'
                     % (name, key, got[key], value))
        b = BANDS[s['tier']]
        for key in ('hp', 'atk', 'def', 'mdef', 'aspd'):
            lo, hi = b[key]
            if not lo <= m['stats'][key] <= hi:
                fail('tier 밴드 밖: %s %s=%s (%s~%s)'
                     % (name, key, m['stats'][key], lo, hi))
        if str(m['spawn'].get('mode')) != 'encounter':
            fail('출현 모드가 encounter 가 아니다: %s' % name)
        if m['spawn']['floors'] != s['floors']:
            fail('출현 층이 다르다: %s %r ≠ %r' % (name, m['spawn']['floors'], s['floors']))
        if m['level'] != s['level']:
            fail('레벨 대역이 다르다: %s %r ≠ %r' % (name, m['level'], s['level']))
        if [e['floors'][0], e['floors'][1]] != s['floors']:
            fail('도감 floors 가 개체와 다르다: %s %r' % (name, e['floors']))
        if int(e.get('spawnBlock') or 0) != s['block']:
            fail('도감 spawnBlock 이 다르다: %s %r ≠ %d'
                 % (name, e.get('spawnBlock'), s['block']))
        if p['aggression'] != m['ecology']['aggression'] \
                or p['sociality'] != m['ecology']['sociality']:
            fail('성격과 생태 값이 갈라졌다: %s' % name)

    for sid in SPIRIT_IDS:
        m = mon.get(sid)
        e = by_codex.get(sid)
        if m is None or e is None:
            fail('정령이 데이터에서 사라졌다: %s' % sid)
        if m['ecology']['habitat'] != SPIRIT_HABITAT:
            fail('정령 habitat 이 astral 이 아니다: %s %r'
                 % (m['name'], m['ecology']['habitat']))
        if e['habitat'] != SPIRIT_HABITAT:
            fail('도감 habitat 이 개체와 다르다: %s %r' % (m['name'], e['habitat']))
        if int(e.get('spawnBlock') or 0) != SPIRIT_BLOCK:
            fail('도감 spawnBlock 이 다르다: %s %r ≠ %d'
                 % (m['name'], e.get('spawnBlock'), SPIRIT_BLOCK))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--check', action='store_true', help='쓰지 않고 검사만')
    args = ap.parse_args()

    monsters = load(PATH['monsters'])
    ambient = load(PATH['ambient'])
    personas = load(PATH['persona'])
    codex = load(PATH['codex'])

    amb = {a['id']: a for a in ambient['ambient']}
    mon = {m['id']: m for m in monsters['monsters']}

    # 이미 적용된 뒤(--check 재실행)에는 ambient 원본이 없다.
    for s in SPECS:
        here, there = s['id'] in amb, s['id'] in mon
        if here and there:
            fail('두 파일에 동시에 있다: %s' % s['name'])
        if not here and not there:
            fail('개체가 어디에도 없다: %s' % s['name'])
    pending = [s for s in SPECS if s['id'] in amb]

    if args.check:
        check(monsters, ambient, personas, codex)
        print('OK — 블록 16·17·20 로스터 검사 통과 (도감 %d · 전투 %d · 비전투 %d)'
              % (len(codex['entries']), len(monsters['monsters']), len(ambient['ambient'])))
        return

    if not pending:
        check(monsters, ambient, personas, codex)
        print('이미 적용됨 — 승격 %d종 · 도감 %d · 전투 %d · 비전투 %d'
              % (len(SPECS), len(codex['entries']), len(monsters['monsters']),
                 len(ambient['ambient'])))
        return

    # 쓰기 전 확인 — derive() 출력이 EXPECTED 와 같아야 한다 (손으로 적은 값 금지).
    for spec in SPECS:
        base = amb.get(spec['id'])
        if base is None:
            continue
        d = derive(base, spec['tier'])
        want = EXPECTED[spec['id']]
        for key, value in want.items():
            if d[key] != value:
                fail('derive() 가 표와 다르다: %s %s=%s (표 %s)'
                     % (spec['name'], key, d[key], value))

    per = {p['id']: p for p in personas['personas']}
    for spec in SPECS:
        base = amb.pop(spec['id'], None)
        if base is None:
            continue          # 이미 옮긴 종은 건드리지 않는다 (멱등)
        mon[spec['id']] = build(spec, base)
        per[spec['id']] = persona_of(spec, base)
        e = next(x for x in codex['entries'] if x['id'] == spec['id'])
        e['floors'] = list(spec['floors'])
        e['spawnBlock'] = spec['block']
        e['group'] = 'G2 — 중부 탑'

    # D1 — 정령 6종 habitat 정합 (멱등).
    for sid in SPIRIT_IDS:
        m = mon[sid]
        m['ecology']['habitat'] = list(SPIRIT_HABITAT)
        e = next(x for x in codex['entries'] if x['id'] == sid)
        e['habitat'] = list(SPIRIT_HABITAT)
        e['spawnBlock'] = SPIRIT_BLOCK

    ambient['ambient'] = [a for a in ambient['ambient'] if a['id'] in amb]
    monsters['monsters'] = sorted(mon.values(), key=lambda m: m['id'])
    # 성격 파일은 id 정렬이 아니다(위협 순) — 기존 순서를 그대로 두고 뒤에 붙인다.
    known = {p['id'] for p in personas['personas']}
    personas['personas'] += [per[s['id']] for s in SPECS if s['id'] not in known]
    personas['meta']['count'] = len(personas['personas'])
    personas['meta']['note'] = (
        '2026-10-23 — 블록 16·17·20 승격 5종 추가 (%s). 저작: '
        'sim/center/sims/gen_block_roster.py · 근거: docs/design/로스터_보강_화산_사막_심연.md'
        % ', '.join(s['name'] for s in SPECS))
    check(monsters, ambient, personas, codex)
    dump('monsters', monsters)
    dump('ambient', ambient)
    dump('persona', personas)
    dump('codex', codex)
    print('적용 — 승격 %d종 · 도감 %d · 전투 %d · 비전투 %d · 성격 %d'
          % (len(SPECS), len(codex['entries']), len(monsters['monsters']),
             len(ambient['ambient']), len(personas['personas'])))
    for s in SPECS:
        m = mon[s['id']]
        print('  %-10s %d층대 T%d hp %6d atk %3d def %3d mdef %3d — %s'
              % (s['name'], s['block'], s['tier'], m['stats']['hp'], m['stats']['atk'],
                 m['stats']['def'], m['stats']['mdef'], s['why']))


if __name__ == '__main__':
    # 계약 G-1~G-4 (`tools/gate_contract.py`) — fail() 의 문자열 SystemExit 도 한 줄로 끝난다.
    sys.path.insert(0, os.path.join(ROOT, 'tools'))
    from gate_contract import run  # noqa: E402
    sys.exit(run('blockroster', main))
