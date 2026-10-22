#!/usr/bin/env python3
"""직업 AI 프로필 26종을 저작한다 — `data/job_ai_profiles.json` + 근거표 (멱등).

무엇을 하나
    L2 26직업에 **행동 도메인 가중 8칸**과 태그 선호를 준다. 도메인은
    `role` 기본값에서 출발해 직업별로 3~5칸만 옮긴다. 옮긴 양의 합은 0 이라
    한 직업만 세지지 않는다 (P0-6).
    근거는 `job_tree.json` 의 `desc` 한 문장이다. desc → 태그 → 도메인 순서로 읽는다.

무엇을 만들지 않나
    · 스킬을 직접 가리키지 않는다. 태그(104 어휘)로만 가리킨다 — 스킬 하나가 여러 직업에서
      다르게 쓰이는 성질(융합·발견)을 보존한다.
    · CP·스탯·등급에 아무 값도 넣지 않는다. J·Kw·X 는 행동 선호만 바꾼다.
      이 파일을 읽는 전투 코드가 아직 없으므로 CP 는 **구조적으로** 움직이지 않는다.

사용: ./.venv/bin/python sim/center/sims/gen_job_ai_profiles.py [--check]
출력: data/job_ai_profiles.json · docs/design/직업_AI_프로필_근거.md
"""
import argparse
import json
import os

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(HERE)))
TREE = os.path.join(ROOT, 'data', 'job_tree.json')
SKILLS = os.path.join(ROOT, 'data', 'skills_catalog.json')
OUT = os.path.join(ROOT, 'data', 'job_ai_profiles.json')
DOC = os.path.join(ROOT, 'docs', 'design', '직업_AI_프로필_근거.md')

DOMAINS = ('공격', '기동', '방어·제어', '지원', '생산', '지식', '사회', '회복')
CLAMP = (0.85, 1.15)
SUM_TARGET, SUM_TOL = 8.0, 0.08
TAG_COUNT = 104

# ── role 기본값 (제안서 02 §2.1 · 합계 7.94~8.08) ───────────────────────────
# 포격 행은 제안서 표에서 생산·지식 자리가 바뀌어 있었다 — 지식 1.04 · 생산 0.94 로 바로잡았다
# (합계는 8.00 그대로, 원거리 직업이 생산을 더 선호할 이유가 없다).
ROLE_BASE = {
    '선봉': (1.12, 1.06, 1.02, 0.96, 0.94, 0.94, 0.94, 0.96),
    '수호': (0.98, 0.96, 1.14, 1.06, 0.94, 0.94, 0.96, 1.00),
    '암살': (1.12, 1.12, 0.94, 0.94, 1.00, 0.96, 0.94, 0.98),
    '포격': (1.12, 1.06, 0.96, 1.00, 0.94, 1.04, 0.94, 0.94),
    '마법': (1.08, 0.98, 1.00, 1.02, 1.06, 0.94, 0.94, 0.96),
    '지원': (0.92, 0.98, 1.02, 1.12, 1.00, 0.94, 0.98, 1.04),
    '무직': (1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00),
}

# ── 직업별 조정 (100분율 정수 · 합 0) ────────────────────────────────────
# why     = desc 를 태그로 옮긴 한 줄. 근거표의 "왜" 칸에 그대로 들어간다.
# favored = 그 직업이 먼저 배우는 태그 (2~6개)
# banned  = 그 직업이 배우지 않는 태그 (0~3개)
# cards   = 키워드 카드 3장 → 끌어오는 태그 (카드가 확정된 4직업만 · 52차)
JOBS = {
    'l2_breaker': {
        'add': {'공격': 3, '기동': 2, '방어·제어': -2, '지식': -3},
        'favored': ['돌진', '관통공격', '둔기타격', '방벽전개'],
        'banned': ['마법시전'],
        'why': '방어선을 부수러 앞으로 나간다 — 돌진·관통으로 벽을 먼저 때린다',
    },
    'l2_vengeance_knight': {
        'add': {'공격': 3, '방어·제어': 2, '사회': -3, '지식': -2},
        'favored': ['반격자세', '흡수공격', '근접타격', '도발'],
        'banned': ['마법시전'],
        'why': '받은 만큼 돌려준다 — 반격·흡수로 맞으면서 채운다',
    },
    'l2_fighter': {
        'add': {'기동': 6, '공격': 1, '지식': -3, '생산': -4},
        'favored': ['근접타격', '연속타격', '도약', '신속기동'],
        'banned': ['원거리사격'],
        'why': '거리를 지워서 붙는다 — 도약·신속기동으로 틈을 없앤다',
    },
    'l2_swordsman': {
        'add': {'공격': 3, '기동': 3, '사회': -3, '생산': -3},
        'favored': ['베기', '연속타격', '거리유지'],
        'banned': ['마법시전'],
        'why': '칼이 손보다 먼저 닿는다 — 베기와 연속타격이 먼저 나간다',
    },
    'l2_spirit_knight': {
        'add': {'지원': 6, '지식': 4, '사회': -4, '생산': -6},
        'favored': ['소환', '마나공급', '강화버프', '방벽전개'],
        'banned': ['은신'],
        'why': '정령 하나와 계약해 함께 싸운다 — 소환·마나공급이 몸의 절반이다',
        'companion': {'kind': '정령', 'source': '정령 계약 (job_tree.spiritRoll)'},
    },
    'l2_magearrow': {
        'add': {'공격': 3, '방어·제어': 3, '회복': -3, '사회': -3},
        'favored': ['찌르기', '거리유지', '저지', '투척'],
        'banned': ['마법시전'],
        'why': '창끝을 먼저 내밀어 거리를 지킨다 — 찌르기 전에 거리유지·저지',
        'cards': {
            '투창': ['투척', '관통공격'],
            '관철': ['관통공격', '찌르기'],
            '연창': ['연속타격', '찌르기'],
        },
    },
    'l2_ironwall': {
        'add': {'지원': 4, '회복': 2, '공격': -3, '사회': -3},
        'favored': ['방어태세', '방벽전개', '아군보호', '도발'],
        'banned': ['은신'],
        'why': '갑옷을 입고 제자리를 지킨다 — 방어태세·아군보호가 먼저다',
    },
    'l2_vanguard': {
        'add': {'공격': 6, '기동': 4, '방어·제어': -4, '지식': -6},
        'favored': ['돌진', '넉백', '방벽전개', '관통공격'],
        'banned': ['은신'],
        'why': '서 있는 대신 앞으로 밀고 나간다 — 돌진·넉백으로 자리를 민다',
    },
    'l2_paladin': {
        'add': {'방어·제어': 1, '지원': 3, '회복': 2, '생산': -6},
        'favored': ['기도', '방벽전개', '아군보호', '정화'],
        'banned': ['은신'],
        'why': '성스러운 힘을 갑옷에 새겨 지킨다 — 기도·정화가 방어에 붙는다',
    },
    'l2_cutthroat': {
        'add': {'기동': 3, '공격': 2, '방어·제어': -2, '사회': -3},
        'favored': ['은신', '잠행', '약점타격', '매복'],
        'banned': ['마법시전'],
        'why': '보이지 않는 쪽에서 먼저 끝낸다 — 은신·매복 다음에 약점타격',
    },
    'l2_poisoner': {
        # 지식은 해독·조제가 사는 자리다 — favored 에 해독을 두었으니 지식은 최소 1.00 이다.
        'add': {'지원': 6, '지식': 5, '공격': 2, '기동': -7, '사회': -6},
        'favored': ['약화디버프', '약점타격', '해독', '조약사'],
        'banned': ['마법시전'],
        'why': '독을 넣고 쌓고 갉아 낸다 — 약화디버프·조약사·해독이 한 묶음이다',
    },
    'l2_thief': {
        'add': {'기동': 3, '사회': 4, '공격': -4, '회복': -3},
        'favored': ['은신', '잠행', '교섭', '운반'],
        'banned': ['마법시전'],
        'why': '죽이러 오는 게 아니라 뺏으러 온다 — 은신으로 붙고 교섭·운반으로 가져간다',
    },
    'l2_marksman': {
        'add': {'공격': 3, '지식': 2, '기동': -2, '사회': -3},
        'favored': ['저격', '원거리사격', '관찰', '약점타격'],
        'banned': ['마법시전'],
        'why': '멀리서 한 점만 겨눈다 — 관찰로 찾고 저격으로 끝낸다',
    },
    'l2_volley': {
        'add': {'공격': 3, '지원': 4, '지식': -4, '회복': -3},
        'favored': ['광역살포', '원거리사격', '전술신호', '투척'],
        'banned': ['은신'],
        'why': '한 번의 사격으로 싸운다 — 광역살포와 전술신호가 짝을 이룬다',
    },
    'l2_hunter': {
        'add': {'지원': 8, '지식': 5, '공격': -7, '사회': -6},
        'favored': ['소환', '함정설치', '곤충', '관찰', '정찰'],
        'banned': ['마법시전'],
        'why': '분류군을 통째로 부려 싸움을 짠다 — 곤충·소환 다음에 함정과 관찰',
        'cards': {
            '짐승': ['돌진', '광역살포', '저지'],
            '곤충': ['신속기동', '속박', '연속타격'],
            '마물': ['함정설치', '약점타격', '소환'],
        },
        'companion': {
            'kind': '마물',
            'source': 'data/monster_husbandry.json',
            'limit': '2 + 훈련장 레벨 (최대 5)',
            'brain': {'from': 'data/monster_personality.json',
                      'inputs': ['aggression', 'sociality', 'fear', 'intelligence', 'activity'],
                      'actions': ['공격', '무리', '후퇴', '대기']},
        },
    },
    'l2_hierophant': {
        'add': {'방어·제어': 6, '지원': 4, '생산': -6, '사회': -4},
        'favored': ['마법시전', '방벽전개', '보호막', '정화'],
        'banned': ['은신'],
        'why': '빛으로 밀어내고 지켜낸다 — 방벽전개·보호막이 공격보다 앞선다',
    },
    'l2_summoner': {
        'add': {'지원': 8, '지식': 2, '공격': -6, '사회': -4},
        'favored': ['소환', '마나공급', '전술신호'],
        'banned': ['근접타격'],
        'why': '혼자 싸우지 않고 부른다 — 소환과 마나공급이 본체다',
        'companion': {'kind': '망령', 'source': '소환 카드 (곤충·망령·정령)'},
    },
    'l2_elementalist': {
        'add': {'공격': 7, '지식': 4, '방어·제어': -6, '사회': -5},
        'favored': ['마법시전', '광역살포', '약점타격', '관찰'],
        'banned': ['근접타격'],
        'why': '원소 여섯을 손에 넣고 쓴다 — 마법시전·광역살포가 기본형이다',
    },
    'l2_hexcaller': {
        'add': {'지원': 6, '지식': 3, '회복': -4, '사회': -5},
        'favored': ['약화디버프', '속박', '침묵', '마법시전'],
        'banned': ['치유'],
        'why': '저주를 걸어 상대의 몫을 깎는다 — 약화디버프·속박·침묵, 치유는 배우지 않는다',
        'cards': {
            '낙인': ['약화디버프', '마법시전'],
            '속박': ['속박', '저지'],
            '역병': ['약화디버프', '광역살포'],
        },
    },
    'l2_druid': {
        'add': {'회복': 4, '지식': 6, '지원': 2, '생산': -6, '사회': -6},
        'favored': ['자연접촉', '치유', '곤충', '약초학'],
        'banned': ['제련'],
        'why': '숲과 짐승의 몸을 함께 쓴다 — 자연접촉·치유·곤충, 금속을 다루지 않는다',
    },
    'l2_priest': {
        'add': {'회복': 9, '지원': 3, '공격': -6, '생산': -6},
        'favored': ['기도', '치유', '부활시도', '보호막'],
        'banned': ['은신'],
        'why': '기도로 답을 끌어온다 — 치유·부활시도가 직업의 몸통이다',
    },
    'l2_monk': {
        'add': {'회복': 6, '방어·제어': 3, '생산': -4, '사회': -5},
        'favored': ['명상', '근접타격', '반격자세', '휴식'],
        'banned': ['마법시전'],
        'why': '갑옷 없이 몸만 단련하고 갱한 것을 다시 세운다 — 명상·반격·휴식',
    },
    'l2_mentalist': {
        'add': {'지원': 3, '지식': 6, '생산': -5, '회복': -4},
        'favored': ['강화버프', '약화디버프', '침묵', '감정'],
        'banned': ['대장장이'],
        'why': '상대와 아군의 상태를 바꾼다 — 강화·약화·감정이 한 쌍이다',
    },
    'l2_strategist': {
        'add': {'기동': 6, '지원': 3, '사회': 2, '공격': -7, '회복': -4},
        'favored': ['정찰', '탐색', '전술신호', '지형활용', '추격'],
        'banned': ['마법시전'],
        'why': '길을 살피고 대열을 이끈다 — 정찰·탐색·지형활용이 앞에 온다',
        'cards': {
            '탐색': ['정찰', '관찰'],
            '추적': ['추격', '지도제작'],
            '개척': ['지형활용', '건설'],
        },
    },
    'l2_jobless': {
        'add': {},
        'favored': ['근접타격', '회피', '관찰'],
        'banned': [],
        'why': '아직 이름이 없다 — 도메인 조정 0, 기본 동작 셋만 준다',
    },
    'l2_sage': {
        'add': {'지식': 8, '지원': 3, '생산': -5, '사회': -6},
        'favored': ['마나공급', '관찰', '기록', '명상'],
        'banned': ['은신'],
        'why': '원소보다 마나를 먼저 본다 — 관찰·기록·마나공급',
    },
}


def load(path):
    with open(path, encoding='utf-8') as fh:
        return json.load(fh)


def fail(msg):
    raise SystemExit('FAIL — ' + msg)


def build():
    tree = load(TREE)
    skills = load(SKILLS)['skills']
    vocab = {t for s in skills for t in (s.get('tags') or [])}
    tag_dom = {}
    for s in skills:
        for t in (s.get('tags') or []):
            tag_dom.setdefault(t, set()).add(s.get('domain'))
    if len(vocab) != TAG_COUNT:
        fail('태그 어휘가 %d — %d 이어야 한다' % (len(vocab), TAG_COUNT))

    l2 = [j for j in tree['jobs'] if j['stage'] == 2]
    if len(l2) != 26:
        fail('L2 가 %d — 26 이어야 한다' % len(l2))
    ids = [j['id'] for j in l2]
    if set(ids) != set(JOBS):
        fail('JOBS 표와 job_tree L2 가 다르다: 빠짐 %s / 남음 %s'
             % (sorted(set(ids) - set(JOBS)), sorted(set(JOBS) - set(ids))))

    profiles, rows = {}, []
    for job in l2:
        spec = JOBS[job['id']]
        base = ROLE_BASE[job['role']]
        doms = []
        for i, d in enumerate(DOMAINS):
            v = round(base[i] + spec['add'].get(d, 0) / 100.0, 2)
            if not (CLAMP[0] <= v <= CLAMP[1]):
                fail('%s %s = %.2f (허용 %s~%s)' % (job['name'], d, v, CLAMP[0], CLAMP[1]))
            doms.append(v)
        total = round(sum(doms), 2)
        if abs(total - SUM_TARGET) > SUM_TOL:
            fail('%s 합계 %.2f (허용 8.0 ± %.2f)' % (job['name'], total, SUM_TOL))
        if sum(spec['add'].values()) != 0:
            fail('%s 조정 합이 0 이 아니다: %s' % (job['name'], spec['add']))

        fav, ban = spec['favored'], spec['banned']
        if not 2 <= len(fav) <= 6:
            fail('%s favored %d개 (2~6)' % (job['name'], len(fav)))
        if len(ban) > 3:
            fail('%s banned %d개 (0~3)' % (job['name'], len(ban)))
        for t in fav + ban:
            if t not in vocab:
                fail('%s 미등록 태그: %s' % (job['name'], t))
        if set(fav) & set(ban):
            fail('%s favored ∩ banned: %s' % (job['name'], sorted(set(fav) & set(ban))))
        # 선호 태그가 사는 도메인은 1.00 이상 — 깎아 둔 도메인의 태그를 favored 에 둘 수 없다.
        weights = dict(zip(DOMAINS, doms))
        for t in fav:
            t_doms = tag_dom.get(t) or set()
            if t_doms and max(weights[d] for d in t_doms) < 1.0:
                fail('%s favored 태그 %r 이 사는 도메인(%s)이 모두 1.00 미만'
                     % (job['name'], t, ', '.join('%s %.2f' % (d, weights[d])
                                                 for d in sorted(t_doms))))

        prof = {'name': job['name'], 'domains': dict(zip(DOMAINS, doms)),
                'favored_tags': fav, 'banned_tags': ban}
        cards = spec.get('cards')
        if cards:
            if len(cards) != 3:
                fail('%s 카드가 %d장 (3장)' % (job['name'], len(cards)))
            for card, tags in cards.items():
                if not tags:
                    fail('%s 카드 %s 에 태그가 없다' % (job['name'], card))
                for t in tags:
                    if t not in vocab:
                        fail('%s 카드 %s 미등록 태그: %s' % (job['name'], card, t))
            prof['keyword_tags'] = cards
        if spec.get('companion'):
            prof['companion'] = spec['companion']
        profiles[job['id']] = prof
        rows.append((job, doms, total, spec))

    meta = {
        'schema_version': '1.0',
        'source': 'data/job_tree.json (L2 26) · docs/design/키워드_설계안_52차.html (카드 12)',
        'generator': 'sim/center/sims/gen_job_ai_profiles.py',
        'evidence': 'docs/design/직업_AI_프로필_근거.md',
        'invariant': 'J·Kw·X 는 행동 선호만 바꾼다 — CP·스탯·등급에 절대 넣지 않는다',
        'clamp': list(CLAMP),
        'sum': SUM_TARGET,
        'sum_tolerance': SUM_TOL,
        'tag_vocabulary': TAG_COUNT,
        'role_base': {r: dict(zip(DOMAINS, v)) for r, v in ROLE_BASE.items()},
        'note': ('도메인은 role 기본값에서 출발해 직업별 3~5칸만 옮긴다. 옮긴 양의 합은 0 이라 '
                 '한 직업만 세지지 않는다. role 기본값의 포격 행은 제안서 표에서 생산·지식 '
                 '자리가 바뀌어 있어 지식 1.04 · 생산 0.94 로 바로잡았다(합 8.00 그대로).'),
        'card_sets': {k: list(v['cards']) for k, v in JOBS.items() if v.get('cards')},
    }
    return {'meta': meta, 'profiles': profiles}, rows


def write_doc(rows):
    out = []
    out.append('# 직업 AI 프로필 근거 — L2 26종')
    out.append('')
    out.append('> 생성물. 손으로 고치지 않는다 — 값은 `sim/center/sims/gen_job_ai_profiles.py`,')
    out.append('> 정본은 [data/job_ai_profiles.json](../../data/job_ai_profiles.json).')
    out.append('> 검사: `./.venv/bin/python tools/check_job_profiles.py`')
    out.append('')
    out.append('## 1. 이 표가 하는 일')
    out.append('')
    out.append('AI 행동 스코어에 **직업 항**을 넣는다. 지금은 직업이 `role` 일치 ×1.2 하나로만')
    out.append('반영돼, 성격이 같으면 창술사와 자객이 같은 후보를 같은 무게로 고른다.')
    out.append('')
    out.append('```')
    out.append('Score(a) = B × S × M × A × K × C × R × J × Kw × X + ε')
    out.append('J  = job.domains[도메인(a)] × (favored_tags 포함 1.10) × (banned_tags 0)')
    out.append('Kw = 보유 카드의 keyword_tags 에 a 의 태그가 있으면 1.0 + 0.05 × 카드 tier')
    out.append('X  = 동반 개체 항 (소환수가 없으면 1.0)')
    out.append('```')
    out.append('')
    out.append('**불변식** — J·Kw·X 는 행동 선호만 바꾼다. CP·스탯·등급 계산에는 들어가지 않는다.')
    out.append('이 파일을 읽는 전투 코드가 아직 없으므로 지금 CP 는 움직일 수 없다.')
    out.append('')
    out.append('## 2. 도메인 기본값 (role)')
    out.append('')
    out.append('| role | ' + ' | '.join(DOMAINS) + ' | 합계 |')
    out.append('|---|' + '---|' * (len(DOMAINS) + 1))
    for role, vals in ROLE_BASE.items():
        out.append('| %s | %s | %.2f |' % (role, ' | '.join('%.2f' % v for v in vals), sum(vals)))
    out.append('')
    out.append('포격 행은 제안서 표에서 생산·지식 자리가 바뀌어 있어 바로잡았다(합은 8.00 그대로).')
    out.append('')
    out.append('## 3. 직업별 조정 — desc 가 근거다')
    out.append('')
    out.append('옮긴 칸은 직업당 3~5개다. 한쪽을 올린 만큼 다른 쪽에서 내려 합이 0 이 된다 —')
    out.append('길잡이는 탐색(사회)을 올리면서 공격·회복에서 같이 내려 5칸이 됐다.')
    out.append('')
    out.append('| 직업 | role | desc | 조정 | favored 태그 | banned | 합계 |')
    out.append('|---|---|---|---|---|---|---|')
    for job, doms, total, spec in rows:
        adj = ', '.join('%s %+.2f' % (d, v / 100.0) for d, v in spec['add'].items()) or '없음'
        ban = ', '.join(spec['banned']) or '—'
        out.append('| %s | %s | %s | %s | %s | %s | %.2f |'
                   % (job['name'], job['role'], job['desc'], adj,
                      ', '.join(spec['favored']), ban, total))
    out.append('')
    out.append('## 4. 왜 이 조정인가')
    out.append('')
    for job, doms, total, spec in rows:
        out.append('- **%s** — %s' % (job['name'], spec['why']))
    out.append('')
    out.append('## 5. 키워드 카드 12장')
    out.append('')
    out.append('카드가 확정된 네 직업만 `keyword_tags` 를 갖는다 (52차 확정). 나머지 22직업은')
    out.append('도메인과 favored 태그로만 움직인다 — 카드 데이터가 아직 정본에 없다.')
    out.append('')
    out.append('| 직업 | 카드 | 끌어오는 태그 |')
    out.append('|---|---|---|')
    for job, doms, total, spec in rows:
        for card, tags in (spec.get('cards') or {}).items():
            out.append('| %s | %s | %s |' % (job['name'], card, ', '.join(tags)))
    out.append('')
    out.append('## 6. 동반 개체')
    out.append('')
    out.append('| 직업 | 종류 | 정본 |')
    out.append('|---|---|---|')
    for job, doms, total, spec in rows:
        c = spec.get('companion')
        if c:
            out.append('| %s | %s | `%s` |' % (job['name'], c['kind'], c['source']))
    out.append('')
    out.append('사역사는 마물 성격 레코드(`monster_personality.json`)를 그대로 브레인 입력으로 쓴다.')
    out.append('')
    out.append('## 7. 검사')
    out.append('')
    out.append('```bash')
    out.append('./.venv/bin/python tools/check_job_profiles.py   # P0-1~P0-7')
    out.append('./.venv/bin/python tools/gate_all.py             # 전체 게이트')
    out.append('```')
    out.append('')
    out.append('| # | 검사 | 임계 |')
    out.append('|---|---|---|')
    out.append('| P0-1 | 26직업 존재 · 이름 일치 | 26/26 |')
    out.append('| P0-2 | 도메인 8키 · 0.85~1.15 | 위반 0 |')
    out.append('| P0-3 | favored ⊂ 104태그 · 2~6개 | 위반 0 |')
    out.append('| P0-4 | favored ∩ banned | 0쌍 |')
    out.append('| P0-5 | keyword_tags 키 = 그 직업 카드 3장 | 누락 0 |')
    out.append('| P0-6 | 도메인 합 = 8.0 ± 0.08 | 26/26 |')
    out.append('| P0-7 | 이 문서에 26직업 desc 대응표 | 26/26 |')
    out.append('| P0-8 | favored 태그의 도메인 중 하나는 1.00 이상 | 위반 0 |')
    out.append('')
    out.append('## 8. 아직 안 한 것')
    out.append('')
    out.append('1. **P3 측정** — 직업만 바꾼 1,000전투로 KL 발산을 재는 도구(`sim/job_ai_sim.py`)가')
    out.append('   없다. J·Kw 를 실제로 곱하는 전투 코드도 아직 없다. 지금 통과하는 것은 데이터 검사다.')
    out.append('2. **나머지 22직업의 카드** — 94장 중 정본에 있는 것은 12장뿐이다.')
    out.append('3. **CP 불변 대조** — 이 파일을 읽는 코드가 생기는 순간 `sim/gacha.py` 고정 시드로')
    out.append('   델타 0 을 다시 재야 한다.')
    with open(DOC, 'w', encoding='utf-8') as fh:
        fh.write('\n'.join(out) + '\n')


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--check', action='store_true', help='쓰지 않고 검사만')
    args = ap.parse_args()
    data, rows = build()

    if args.check:
        if not os.path.exists(OUT):
            fail('정본이 없다: data/job_ai_profiles.json — 생성기를 먼저 돌린다')
        old = load(OUT)
        if old != data:
            fail('정본이 생성기와 다르다 — 생성기를 다시 돌려 맞춘다')
        if not os.path.exists(DOC):
            fail('근거표가 없다: docs/design/직업_AI_프로필_근거.md')
        print('OK — 26직업 프로필 · 정본 = 생성기 출력 · 근거표 있음')
        return

    with open(OUT, 'w', encoding='utf-8') as fh:
        json.dump(data, fh, ensure_ascii=False, indent=1)
        fh.write('\n')
    write_doc(rows)
    carded = sum(1 for v in data['profiles'].values() if 'keyword_tags' in v)
    comp = sum(1 for v in data['profiles'].values() if 'companion' in v)
    print('적용 — 26직업 · 카드 %d직업 · 동반 %d직업 · 태그 %d어휘'
          % (carded, comp, data['meta']['tag_vocabulary']))
    print('  %s / %s' % (os.path.relpath(OUT, ROOT), os.path.relpath(DOC, ROOT)))


if __name__ == '__main__':
    main()
