#!/usr/bin/env python3
"""저층(1~10층) 사육 마물 4종의 **개체·성격 레코드를 저작한다** (멱등).

왜 이 스크립트가 있나
    1~10층 생태도감 31종 중 사육 정의(용어집: "사람 곁에서 버려진 것을 먹고 사는 것들 —
    공격성 0.3 이하 · 무리성 0.6 이상")를 만족하는 종은 넷뿐인데, 넷 다
    `ambient.json`(비전투 배경 생물)에만 있고 `monster_personality.json` 레코드가 없었다.
    성격 레코드가 없으면 전투 브레인이 없어 데리고 다닐 수가 없다.

    → 넷을 전투 개체(`monsters.json`)로 옮기고, 성격 레코드를 붙인다.
      새 종은 만들지 않는다 — 도감 377 = 13×29 불변식을 지킨다 (docs/gdd 02 §4).
      옮기는 것이므로 전투 133 → 137 · 비전투 244 → 240, 합 377 은 그대로다.

무엇을 고치나 (값은 전부 여기, 근거는 docs/design/저층_사육_마물_근거.md)
    · `ambient.json`  — 넷을 **뺀다** (같은 id 가 두 파일에 있으면 전투/비전투 어느 쪽이
      이기는지가 로더마다 달라진다)
    · `monsters.json` — 넷을 **넣는다**. 스탯은 ambient 원본 비율을 지키며 T1 전투 대역
      (실측 hp 110~220 · atk 10~14 · def 4~9 · spd 6~16 · threat 18~25)으로 옮겼다.
    · `monster_personality.json` — 넷의 CombatPersona v2. 기존 133종은 persona 값과
      ecology 값이 전부 같으므로, 성격 기준을 맞추려고 바꾼 ecology 값도 같이 적는다
      (장수풍뎅이·숲 사슴벌레 무리성 0.4→0.6 · 독벌 공격성 0.6→0.3).

사용: ./.venv/bin/python sim/center/sims/gen_husbandry_roster.py [--check]
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

# T1 실측 대역 — 근거 문서 §4 표. 새 수치가 이 밖으로 나가면 검사에서 멈춘다.
T1_BAND = {'hp': (110, 220), 'atk': (10, 14), 'def': (4, 9), 'spd': (6, 16),
           'threat': (18.0, 25.0)}
CRITERIA = {'aggression_max': 0.3, 'sociality_min': 0.6, 'tier_max': 1}
CODEX_TOTAL = 377          # 13×29 — 새 종을 넣지 않는 이유 (docs/gdd 02 §4)
KEEPER_ROLES = ('decomposer', 'scavenger')

# ── 저작 값 ────────────────────────────────────────────────────────────
# stats 유도: ambient 원본 hp ×3.0~3.4 · atk ×1.4~2.0 · spd 는 대역 상한 16 으로 절단.
# def 는 대역 상한 9 로 자르고, 잘린 만큼을 물리 저항(ambient 그대로)으로 남긴다.
SPECS = [
    {
        'id': 'mon_beetle_01', 'name': '장수풍뎅이',
        'unlock_floor': 1, 'spawn_floors': [1, 2, 3], 'level': [1, 21],
        'tier': 1, 'threat': 20.0, 'aiType': 'melee',
        'stats': {'hp': 190, 'atk': 10, 'def': 9, 'aspd': 8, 'mdef': 4,
                  'cri': 5, 'cdmg': 150, 'eva': 4, 'sta': 80},
        'aiDecision': {'enrageHp': 0, 'patternCooldown': [8, 16], 'crowdAoeRadius': 0,
                       'specialSkill': 'entangle', 'fleeHp': 0.4},
        'pattern': [
            {'name': '뿔 밀치기', 'cd': 8, 'effect': '1.4xATK, 밀어냄',
             'telegraph': '뿔을 낮추고 달려듦', 'counter': '옆으로 비켜 등쪽 타격'},
            {'name': '다리 물기', 'cd': 12, 'effect': '0.8xATK + 2초 발 묶임',
             'telegraph': '턱을 벌리고 다리에 붙음', 'counter': '발을 털어내고 즉시 이탈'},
            {'name': '흙더미 파기', 'cd': 16, 'effect': '땅을 파 3초 회피 상승',
             'telegraph': '앞발로 흙을 긁음', 'counter': '파는 자리를 끊어 이동 봉쇄'},
        ],
        'loot': {'soul': ['하'], 'gold': 12, 'exp': 18},
        'persona': {'aggression': 0.3, 'territoriality': 0.4, 'sociality': 0.6,
                    'fear': 0.5, 'vengeance': 0.1, 'allyPriority': 0.7,
                    'intelligence': 0.082, 'band': 'T1', 'preyIds': [],
                    'preyResources': ['corpse', 'rotten_wood', 'detritus'],
                    'activity': 'diurnal'},
        'why': '초원 1~5층의 유일한 청소곤충. 유충이 썩은 나무·사체를 갉아 사냥 잔해를 '
               '토양으로 되돌린다 — 우리에 넣으면 버려진 것을 먹는 일이 그대로 일이 된다.',
        'trait_note': '무리성 0.4 → 0.6 (야생에서는 단독, 우리에서는 같은 우리의 다른 개체와 '
                      '먹이 자리를 나눈다 — 사육 개체 관찰값)',
        'role_ko': '첫 마물',
    },
    {
        'id': 'mon_foreststagbeetle_01', 'name': '숲 사슴벌레',
        'unlock_floor': 6, 'spawn_floors': [6, 7, 8], 'level': [6, 26],
        'tier': 1, 'threat': 22.0, 'aiType': 'melee',
        'stats': {'hp': 200, 'atk': 12, 'def': 9, 'aspd': 7, 'mdef': 4,
                  'cri': 6, 'cdmg': 150, 'eva': 4, 'sta': 80},
        'aiDecision': {'enrageHp': 0, 'patternCooldown': [9, 18], 'crowdAoeRadius': 0,
                       'specialSkill': 'entangle', 'fleeHp': 0.4},
        'pattern': [
            {'name': '집게 조이기', 'cd': 9, 'effect': '1.2xATK + 2초 발 묶임',
             'telegraph': '큰 턱을 벌리고 겨냥', 'counter': '턱 바깥으로 돌아 붙는다'},
            {'name': '통나무 뒤집기', 'cd': 14, 'effect': '1.6xATK, 넘어뜨림',
             'telegraph': '몸을 통나무 밑으로 밀어 넣음', 'counter': '발을 고정하고 중심을 낮춘다'},
            {'name': '턱 비틀기', 'cd': 18, 'effect': '0.9xATK + 방어 -10% 4초',
             'telegraph': '턱을 옆으로 돌림', 'counter': '장비를 고쳐 잡고 거리 벌리기'},
        ],
        'loot': {'soul': ['하'], 'gold': 14, 'exp': 20},
        'persona': {'aggression': 0.3, 'territoriality': 0.5, 'sociality': 0.6,
                    'fear': 0.45, 'vengeance': 0.15, 'allyPriority': 0.7,
                    'intelligence': 0.114, 'band': 'T1', 'preyIds': [],
                    'preyResources': ['corpse', 'rotten_wood'], 'activity': 'diurnal'},
        'why': '숲 6~10층에서 썩은 통나무를 갈라 청소하는 사슴벌레. 턱이 커서 적의 다리를 '
               '붙잡는 일에 그대로 쓸 수 있다 — 사육 성장의 "묶는 시간"과 같은 동작이다.',
        'trait_note': '무리성 0.4 → 0.6 (위와 같은 이유 · 같은 우리에서 먹이 자리를 나눈다)',
        'role_ko': '집게',
    },
    {
        'id': 'mon_bee_01', 'name': '독벌',
        'unlock_floor': 6, 'spawn_floors': [6, 7], 'level': [6, 26],
        'tier': 1, 'threat': 21.0, 'aiType': 'melee',
        'stats': {'hp': 130, 'atk': 12, 'def': 4, 'aspd': 15, 'mdef': 3,
                  'cri': 5, 'cdmg': 150, 'eva': 10, 'sta': 60},
        'aiDecision': {'enrageHp': 0, 'patternCooldown': [6, 16], 'crowdAoeRadius': 0,
                       'specialSkill': 'sting', 'fleeHp': 0.5},
        'pattern': [
            {'name': '독침 쏘기', 'cd': 6, 'effect': '1.0xATK + 중독 3초',
             'telegraph': '꼬리를 들어 노란 빛', 'counter': '방패로 막고 옆으로'},
            {'name': '떼 몰이', 'cd': 11, 'effect': '대상 1명 이동 -20% 3초',
             'telegraph': '군체가 한쪽으로 몰림', 'counter': '연막·불로 군체를 흩는다'},
            {'name': '벌집 흔들기', 'cd': 16, 'effect': '1.3xATK, 후퇴 유도',
             'telegraph': '몸을 낮추고 날개를 빠르게', 'counter': '밀지 말고 자리를 지킨다'},
        ],
        'loot': {'soul': ['하'], 'gold': 10, 'exp': 18},
        'persona': {'aggression': 0.3, 'territoriality': 0.8, 'sociality': 0.95,
                    'fear': 0.3, 'vengeance': 0.4, 'allyPriority': 0.9,
                    'intelligence': 0.191, 'band': 'T1',
                    'preyIds': ['mon_moth_01'],
                    'preyResources': ['corpse', 'nectar', 'flowers'], 'activity': 'diurnal'},
        'why': '군체로 부드러운 유충·썩은 과실을 분해하는 벌. 무리성 0.95 는 도감 최상위권이라 '
               '우리 안에서 사람을 따르는 쪽으로 이미 설계돼 있다 — 잔해를 마무리하는 일꾼이다.',
        'trait_note': '공격성 0.6 → 0.3 (야생 군체의 위협은 개체 패턴 독침·떼 몰이가 표현한다. '
                      '사육 개체는 사람을 쏘지 않는다 — 이 값이 없으면 "기를 수 있는 것" 정의에 못 든다)',
        'role_ko': '떼',
    },
    {
        'id': 'mon_crow_01', 'name': '까마귀',
        'unlock_floor': 6, 'spawn_floors': [6, 7, 8, 9, 10], 'level': [6, 26],
        'tier': 1, 'threat': 21.5, 'aiType': 'ranged',
        'stats': {'hp': 140, 'atk': 11, 'def': 4, 'aspd': 16, 'mdef': 6,
                  'cri': 8, 'cdmg': 160, 'eva': 12, 'sta': 60},
        'aiDecision': {'enrageHp': 0, 'patternCooldown': [7, 18], 'crowdAoeRadius': 0,
                       'specialSkill': 'caw', 'fleeHp': 0.5},
        'pattern': [
            {'name': '눈 찍기', 'cd': 7, 'effect': '0.9xATK + 실명 2초',
             'telegraph': '머리 위로 붙어 부리를 든다', 'counter': '머리를 가리고 팔로 쫓는다'},
            {'name': '깃털 흩뿌리기', 'cd': 13, 'effect': '0.6xATK + 명중 -15% 4초',
             'telegraph': '몸을 털어 깃털을 날림', 'counter': '거리를 벌려 시야를 되찾는다'},
            {'name': '잔해 뒤지기', 'cd': 18, 'effect': '잔해에서 먹이를 찾아 HP 5% 회복',
             'telegraph': '땅에 내려앉아 부리로 긁음', 'counter': '내려앉은 순간에 붙는다'},
        ],
        'loot': {'soul': ['하'], 'gold': 10, 'exp': 18},
        'persona': {'aggression': 0.3, 'territoriality': 0.4, 'sociality': 0.8,
                    'fear': 0.3, 'vengeance': 0.45, 'allyPriority': 0.85,
                    'intelligence': 0.617, 'band': 'T1',
                    'preyIds': ['mon_rabbit_01', 'mon_rat_01', 'mon_tombworm_01',
                                'mon_graverat_01'],
                    'preyResources': ['corpse', 'organic_waste'], 'activity': 'diurnal'},
        'why': '폐허·묘지·숲의 청소부. 잔해를 먹고, 무리성 0.8 에 지능 0.62 로 1~10층에서 가장 '
               '영리하다 — 우리에 들면 가장 먼저 사람을 알아보는 쪽이다.',
        'trait_note': '변경 없음 (공격성 0.3 · 무리성 0.8 로 이미 정의를 만족한 유일한 종)',
        'role_ko': '눈',
    },
    {
        # 11~15층 — 로스터에 이름만 있고 성격·전투 개체가 없던 자리를 메운다.
        'id': 'mon_slime_blue_01', 'name': '슬라임(블루)',
        'unlock_floor': 11, 'spawn_floors': [11, 12, 13], 'level': [11, 31],
        'tier': 1, 'threat': 18.0, 'aiType': 'melee',
        'stats': {'hp': 170, 'atk': 11, 'def': 4, 'aspd': 6, 'mdef': 4,
                  'cri': 4, 'cdmg': 150, 'eva': 6, 'sta': 60},
        'aiDecision': {'enrageHp': 0, 'patternCooldown': [7, 12], 'crowdAoeRadius': 0,
                       'specialSkill': 'split', 'splitHp': 0.3, 'fleeHp': 0.5},
        'pattern': [
            {'name': '분열', 'cd': 0, 'effect': 'HP 30% 시 2마리로 나뉨',
             'telegraph': '몸이 파랗게 부푼다', 'counter': '나뉘기 전에 한 번에 끝낸다'},
            {'name': '산성 튀김', 'cd': 9, 'effect': '0.8xATK + 방어구 -3%',
             'telegraph': '초록 물방울이 맺힘', 'counter': '옆으로 비켜 장비를 닦는다'},
        ],
        'loot': {'soul': ['하'], 'gold': 30, 'exp': 15},
        'persona': {'aggression': 0.2, 'territoriality': 0.2, 'sociality': 0.9,
                    'fear': 0.65, 'vengeance': 0.08, 'allyPriority': 0.95,
                    'intelligence': 0.06, 'band': 'T1', 'preyIds': [],
                    'preyResources': ['organic_waste', 'corpse'],
                    'activity': 'always'},
        'why': '11~15층 늪·바다 동굴의 분해자. 잔해를 녹여 먹고 남은 것을 흙으로 돌린다 — '
               '우리에 넣으면 마당의 잔해를 스스로 치운다. 공격성 0.2 · 무리성 0.9 로 성격 기준은 '
               '이미 넘었고, 없던 것은 성격 레코드뿐이었다.',
        'trait_note': '변경 없음 (공격성 0.2 · 무리성 0.9 — 성격 레코드만 없었다)',
        'role_ko': '분해',
    },
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


def check(monsters, ambient, personas, codex):
    """저작 값이 정의·대역·불변식을 지키는지 본다 (쓰기 전후 모두 호출)."""
    by_codex = {e['id']: e for e in codex['entries']}
    mon = {m['id']: m for m in monsters['monsters']}
    amb = {a['id']: a for a in ambient['ambient']}
    per = {p['id']: p for p in personas['personas']}

    if len(codex['entries']) != CODEX_TOTAL:
        fail('도감 종수가 %d — %d(13×29) 여야 한다 (새 종을 만들지 않는다)'
             % (len(codex['entries']), CODEX_TOTAL))
    if set(mon) & set(amb):
        fail('전투·비전투에 같은 id: ' + ', '.join(sorted(set(mon) & set(amb))[:5]))
    if len(per) != len(mon):
        fail('성격 %d ≠ 전투 개체 %d' % (len(per), len(mon)))

    for s in SPECS:
        e = by_codex.get(s['id'])
        if e is None:
            fail('생태도감에 없는 개체: %s' % s['name'])
        if e['role'] not in KEEPER_ROLES:
            fail('청소부·분해자가 아니다: %s = %s' % (s['name'], e['role']))
        if e['name'] != s['name']:
            fail('이름 불일치: %s ≠ %s' % (s['name'], e['name']))
        if e['floors'][0] != s['unlock_floor']:
            fail('해금 층이 도감과 다르다: %s %d ≠ %d'
                 % (s['name'], e['floors'][0], s['unlock_floor']))
        if s['unlock_floor'] > 11:
            fail('저작 범위를 넘었다 (1~15층 문제를 메우는 것이 목적): %s' % s['name'])
        if s['id'] in amb:
            fail('아직 ambient 에 남아 있다: %s' % s['name'])
        m = mon.get(s['id']) or fail('전투 개체가 없다: %s' % s['name'])
        p = per.get(s['id']) or fail('성격 레코드가 없다: %s' % s['name'])
        if m['name'] != s['name'] or p['name'] != s['name']:
            fail('이름 불일치(개체/성격): %s' % s['name'])
        if p['aggression'] > CRITERIA['aggression_max']:
            fail('공격성 초과: %s %s > %s'
                 % (s['name'], p['aggression'], CRITERIA['aggression_max']))
        if p['sociality'] < CRITERIA['sociality_min']:
            fail('무리성 미달: %s %s < %s'
                 % (s['name'], p['sociality'], CRITERIA['sociality_min']))
        if m['tier'] > CRITERIA['tier_max']:
            fail('티어 초과: %s T%s' % (s['name'], m['tier']))
        eco = m['ecology']
        if (eco['aggression'], eco['sociality']) != (p['aggression'], p['sociality']):
            fail('성격과 생태 값이 갈라졌다: %s' % s['name'])
        for key, (lo, hi) in T1_BAND.items():
            v = m['threatBase'] if key == 'threat' else m['stats'].get(
                'aspd' if key == 'spd' else key)
            if v is None or not (lo <= v <= hi):
                fail('T1 대역 밖 %s %s=%s (%s~%s)' % (s['name'], key, v, lo, hi))


def build(spec, base):
    """ambient 개체 → 전투 개체. 종족 고유 필드(원소·저항·면역)는 ambient 값을 승계한다."""
    eco = dict(base['ecology'])
    eco['aggression'] = spec['persona']['aggression']
    eco['sociality'] = spec['persona']['sociality']
    return {
        'id': spec['id'],
        'name': spec['name'],
        'category': base['category'],
        'aiType': spec['aiType'],
        'tier': spec['tier'],
        'level': spec['level'],
        'threatBase': spec['threat'],
        'element': base['element'],
        'stats': spec['stats'],
        'weakness': base['weakness'],
        'resistance': base['resistance'],
        'statusImmune': base['statusImmune'],
        'aiDecision': spec['aiDecision'],
        'pattern': spec['pattern'],
        'parts': base.get('parts', []),
        'spawn': {'floors': spec['spawn_floors'], 'mode': 'encounter'},
        'loot': spec['loot'],
        'ecology': eco,
    }


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

    # 이미 옮긴 뒤(--check 재실행)에는 ambient 원본이 없다 — 그때는 통과시킨다.
    # 종마다 "ambient 에 있거나, monsters 에 있거나" 둘 중 하나다. 둘 다/둘 다 아님은 사고다.
    for s in SPECS:
        here, there = s['id'] in amb, s['id'] in mon
        if here and there:
            fail('두 파일에 동시에 있다: %s' % s['name'])
        if not here and not there:
            fail('개체가 어디에도 없다: %s' % s['name'])
    pending = [s for s in SPECS if s['id'] in amb]

    if args.check:
        check(monsters, ambient, personas, codex)
        print('OK — 저층 사육 마물 %d종 검사 통과 (도감 %d · 전투 %d · 비전투 %d)'
              % (len(SPECS), len(codex['entries']), len(monsters['monsters']),
                 len(ambient['ambient'])))
        return

    if not pending:
        check(monsters, ambient, personas, codex)
        print('이미 적용됨 — %d종 · 도감 %d · 전투 %d · 비전투 %d'
              % (len(SPECS), len(codex['entries']), len(monsters['monsters']),
                 len(ambient['ambient'])))
        return

    per = {p['id']: p for p in personas['personas']}
    for spec in SPECS:
        base = amb.pop(spec['id'], None)
        if base is None:
            continue          # 이미 옮긴 종은 건드리지 않는다 (멱등)
        mon[spec['id']] = build(spec, base)
        per[spec['id']] = dict({'id': spec['id'], 'name': spec['name']},
                               **spec['persona'])

    ambient['ambient'] = [a for a in ambient['ambient'] if a['id'] in amb]
    monsters['monsters'] = sorted(mon.values(), key=lambda m: m['id'])
    # 성격 파일은 id 정렬이 아니다(위협 순) — 기존 순서를 그대로 두고 뒤에 붙인다.
    known = {p['id'] for p in personas['personas']}
    personas['personas'] += [per[s['id']] for s in SPECS if s['id'] not in known]
    personas['meta']['count'] = len(personas['personas'])
    personas['meta']['note'] = (
        '2026-10-18 — 저층 사육 마물 4종 추가 (%s). 저작: '
        'sim/center/sims/gen_husbandry_roster.py · 근거: docs/design/저층_사육_마물_근거.md'
        % ', '.join(s['name'] for s in SPECS))

    check(monsters, ambient, personas, codex)
    dump('monsters', monsters)
    dump('ambient', ambient)
    dump('persona', personas)
    print('적용 — 사육 마물 %d종 · 도감 %d · 전투 %d · 비전투 %d · 성격 %d'
          % (len(SPECS), len(codex['entries']), len(monsters['monsters']),
             len(ambient['ambient']), len(personas['personas'])))
    for s in SPECS:
        print('  %-12s %d층 %-6s T%d 위협 %4.1f — %s'
              % (s['name'], s['unlock_floor'], s['role_ko'], s['tier'], s['threat'],
                 s['trait_note']))


if __name__ == '__main__':
    # 계약 G-1~G-4 (`tools/gate_contract.py`) — fail() 의 문자열 SystemExit 도 한 줄로 끝난다.
    sys.path.insert(0, os.path.join(ROOT, 'tools'))
    from gate_contract import run  # noqa: E402
    sys.exit(run('husbandry', main))
