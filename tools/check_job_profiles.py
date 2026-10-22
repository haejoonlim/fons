#!/usr/bin/env python3
"""job_ai_profiles.json 검사 — P0-1~P0-8 + CP 구조 검사 (exit 0 = 통과).

검사만 한다. 값을 고치지 않는다 (고치는 곳은 sim/center/sims/gen_job_ai_profiles.py).

  P0-1  26직업 프로필 존재 · 키 = job_tree L2 id · name 일치
  P0-2  domains 8키 전부 · 0.85~1.15
  P0-3  favored_tags ⊂ 104태그 · 2~6개
  P0-4  favored ∩ banned = ∅ · banned ≤ 3개
  P0-5  keyword_tags 키 = 그 직업 카드 3장 (meta.card_sets 기준) · 카드 태그 ⊂ 104
  P0-6  도메인 합 = 8.0 ± 0.08 (26/26)
  P0-7  근거표(docs/design/직업_AI_프로필_근거.md)에 26직업 name + desc 가 있다
  P0-8  favored 태그가 사는 도메인 중 하나는 1.00 이상 (선호라고 적어 놓고 그 도메인을
        깎아 둔 모순을 잡는다 — 도메인을 내렸는데 그 도메인 태그를 favored 에 둘 수 없다)
  CP-1  프로필에 스탯·등급·CP 로 읽힐 키가 없다 (J 가 CP 경로에 닿지 못하게 하는 구조 검사)

실행: ./.venv/bin/python tools/check_job_profiles.py [--json]
"""
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
DATA = os.path.join(ROOT, 'data')

sys.path.insert(0, HERE)
from gate_contract import run  # noqa: E402
PATH = os.path.join(DATA, 'job_ai_profiles.json')
DOC = os.path.join(ROOT, 'docs', 'design', '직업_AI_프로필_근거.md')

DOMAINS = ('공격', '기동', '방어·제어', '지원', '생산', '지식', '사회', '회복')
CLAMP = (0.85, 1.15)
SUM_TARGET, SUM_TOL = 8.0, 0.08
TAG_COUNT = 104
# 이 이름이 프로필 안에 있으면 J 가 CP·스탯 경로로 샌 것이다.
FORBIDDEN_KEYS = {'statMod', 'stats', 'cp', 'CP', 'power', 'hp', 'atk', 'def', 'mdef',
                  'cri', 'cdmg', 'eva', 'aspd', 'sta', 'rarity', 'tier'}


def load(path):
    with open(path, encoding='utf-8') as fh:
        return json.load(fh)


def read_json(path, label, fails):
    """필수 정본 읽기 — 없거나 깨졌으면 traceback 이 아니라 실패 항목으로 남는다."""
    try:
        return load(path)
    except OSError as e:
        fails.append('%s 읽기 실패: %s' % (label, e))
    except json.JSONDecodeError as e:
        fails.append('%s JSON 깨짐: %s' % (label, e))
    return None


def text_list(val):
    """태그 배열이면 문자열만 남긴다. 배열이 아니면 (None) — 호출부가 실패로 적는다."""
    if not isinstance(val, list) or not all(isinstance(t, str) for t in val):
        return None
    return val


def main():
    fails = []
    notes = []

    if not os.path.exists(PATH):
        print('FAIL — 정본이 없다: data/job_ai_profiles.json')
        return 1
    data = read_json(PATH, 'data/job_ai_profiles.json', fails)
    tree = read_json(os.path.join(DATA, 'job_tree.json'), 'data/job_tree.json', fails)
    catalog = read_json(os.path.join(DATA, 'skills_catalog.json'), 'data/skills_catalog.json', fails)
    if fails:
        for f in fails:
            print('  [FAIL] ' + f)
        return 1

    meta = data.get('meta') if isinstance(data.get('meta'), dict) else {}
    profiles = data.get('profiles')
    raw_jobs = tree.get('jobs')
    skills = catalog.get('skills')
    # 자료형이 다르면 .get·반복에서 traceback 이 난다 — 구조 검사 도구니까 구조 오류로 끝낸다.
    for ok, why in ((isinstance(profiles, dict), 'profiles 가 객체가 아니다'),
                    (isinstance(raw_jobs, list) and all(isinstance(j, dict) for j in raw_jobs),
                     'job_tree.jobs 가 객체 배열이 아니다'),
                    (isinstance(skills, list) and all(isinstance(s, dict) for s in skills),
                     'skills_catalog.skills 가 객체 배열이 아니다')):
        if not ok:
            print('FAIL — ' + why)
            return 1

    l2 = [j for j in raw_jobs if j.get('stage') == 2 and 'id' in j]
    jobs = {j['id']: j for j in l2}

    vocab = {t for s in skills for t in text_list(s.get('tags')) or []}
    tag_domains = {}
    for s in skills:
        for t in (s.get('tags') or []):
            tag_domains.setdefault(t, set()).add(s.get('domain'))
    if len(vocab) != TAG_COUNT:
        fails.append('태그 어휘 %d ≠ %d' % (len(vocab), TAG_COUNT))

    # P0-1 — 존재 · 이름
    if len(l2) != 26:
        fails.append('P0-1 job_tree L2 %d ≠ 26' % len(l2))
    missing = sorted(set(jobs) - set(profiles))
    extra = sorted(set(profiles) - set(jobs))
    if missing:
        fails.append('P0-1 프로필 없음: ' + ', '.join(missing))
    if extra:
        fails.append('P0-1 L2 아닌 프로필: ' + ', '.join(extra))
    for jid, p in profiles.items():
        if not isinstance(p, dict):
            fails.append('P0-1 %s 프로필이 객체가 아니다: %r' % (jid, p))
        elif jid in jobs and p.get('name') != jobs[jid]['name']:
            fails.append('P0-1 이름 불일치 %s: %r ≠ %r'
                         % (jid, p.get('name'), jobs[jid]['name']))

    card_sets = meta.get('card_sets') if isinstance(meta.get('card_sets'), dict) else {}
    for jid, p in sorted(profiles.items()):
        if not isinstance(p, dict):
            continue
        name = p.get('name', jid)

        # P0-2 — 도메인
        doms = p.get('domains')
        if not isinstance(doms, dict):
            fails.append('P0-2 %s domains 가 객체가 아니다: %r' % (name, doms))
            doms = {}
        if set(doms) != set(DOMAINS):
            fails.append('P0-2 %s 도메인 키가 다르다: %s'
                         % (name, sorted(set(doms) ^ set(DOMAINS))))
        for d, v in doms.items():
            if not isinstance(v, (int, float)) or not (CLAMP[0] <= v <= CLAMP[1]):
                fails.append('P0-2 %s %s = %r (%.2f~%.2f)'
                             % (name, d, v, CLAMP[0], CLAMP[1]))

        # P0-3 / P0-4 — 태그
        fav = text_list(p.get('favored_tags', []))
        ban = text_list(p.get('banned_tags', []))
        if fav is None:
            fails.append('P0-3 %s favored_tags 가 문자열 배열이 아니다' % name)
            fav = []
        if ban is None:
            fails.append('P0-4 %s banned_tags 가 문자열 배열이 아니다' % name)
            ban = []
        if not 2 <= len(fav) <= 6:
            fails.append('P0-3 %s favored %d개 (2~6)' % (name, len(fav)))
        if len(ban) > 3:
            fails.append('P0-4 %s banned %d개 (0~3)' % (name, len(ban)))
        unknown = [t for t in fav + ban if t not in vocab]
        if unknown:
            fails.append('P0-3 %s 미등록 태그: %s' % (name, ', '.join(unknown)))
        both = sorted(set(fav) & set(ban))
        if both:
            fails.append('P0-4 %s favored ∩ banned: %s' % (name, ', '.join(both)))

        # P0-5 — 카드
        kt = p.get('keyword_tags')
        if kt is None:
            kt = {}
        if not isinstance(kt, dict) or not all(text_list(t) is not None for t in kt.values()):
            fails.append('P0-5 %s keyword_tags 구조가 다르다: %r' % (name, kt))
            kt = {}
        # want 가 비어 있어도 비교한다 — `if want` 는 카드가 통째로 사라진 경우를 건너뛰었다.
        if jid in card_sets:
            want = card_sets[jid]
            if set(kt) != set(want):
                fails.append('P0-5 %s 카드가 다르다: %s ≠ %s'
                             % (name, sorted(kt), sorted(want)))
        elif kt:
            fails.append('P0-5 %s 에 카드 데이터가 없는데 keyword_tags 가 있다' % name)
        for card, tags in kt.items():
            bad = [t for t in tags if t not in vocab]
            if bad:
                fails.append('P0-5 %s 카드 %s 미등록 태그: %s' % (name, card, ', '.join(bad)))
            if not tags:
                fails.append('P0-5 %s 카드 %s 태그 0개' % (name, card))

        # P0-6 — 합
        total = round(sum(v for v in doms.values() if isinstance(v, (int, float))), 2)
        if abs(total - SUM_TARGET) > SUM_TOL:
            fails.append('P0-6 %s 합계 %.2f (8.0 ± %.2f)' % (name, total, SUM_TOL))

        # P0-8 — favored 태그가 사는 도메인 중 하나는 1.00 이상
        for t in fav:
            t_doms = tag_domains.get(t) or set()
            if not t_doms:
                continue
            weight = max(doms.get(d, 0) for d in t_doms)
            if weight < 1.0:
                fails.append('P0-8 %s favored 태그 %r 이 사는 도메인(%s)이 모두 1.00 미만'
                             % (name, t, ', '.join('%s %.2f' % (d, doms.get(d, 0))
                                                   for d in sorted(t_doms))))

        # CP-1 — 스탯 키가 섞이지 않았는가 (깊이 전수)
        stack = [p]
        while stack:
            node = stack.pop()
            if isinstance(node, dict):
                hit = FORBIDDEN_KEYS & set(node)
                if hit:
                    fails.append('CP-1 %s 안에 스탯·등급 키: %s'
                                 % (name, ', '.join(sorted(hit))))
                stack.extend(node.values())
            elif isinstance(node, list):
                stack.extend(node)

    # P0-7 — 근거표
    doc = None
    if not os.path.exists(DOC):
        fails.append('P0-7 근거표가 없다: docs/design/직업_AI_프로필_근거.md')
    else:
        try:
            doc = open(DOC, encoding='utf-8').read()
        except (OSError, UnicodeDecodeError) as e:
            fails.append('P0-7 근거표 읽기 실패: %s' % e)
    if doc is not None:
        for jid, j in jobs.items():
            if j['name'] not in doc:
                fails.append('P0-7 근거표에 직업 없음: %s' % j['name'])
            elif j['desc'] not in doc:
                fails.append('P0-7 근거표에 desc 없음: %s' % j['name'])

    counts = {
        'profiles': len(profiles),
        'carded': sum(1 for p in profiles.values()
                      if isinstance(p, dict) and p.get('keyword_tags')),
        'companion': sum(1 for p in profiles.values()
                         if isinstance(p, dict) and p.get('companion')),
        'tags': len(vocab),
    }
    notes.append('프로필 %d · 카드 %d직업 · 동반 %d직업 · 태그 %d'
                 % (counts['profiles'], counts['carded'], counts['companion'], counts['tags']))

    # --json 은 표준출력을 JSON 하나로 쓴다 (사람용 줄은 stderr) — 섞이면 파서가 못 읽는다.
    out = sys.stderr if '--json' in sys.argv else sys.stdout
    print('check_job_profiles — P0-1~P0-8 + CP-1', file=out)
    for n in notes:
        print('  ' + n, file=out)
    for f in fails:
        print('  [FAIL] ' + f, file=out)
    print('  → %s' % ('통과' if not fails else '실패 %d건' % len(fails)), file=out)
    if '--json' in sys.argv:
        print(json.dumps({'fail': fails, 'counts': counts}, ensure_ascii=False, indent=1))
    return 1 if fails else 0


if __name__ == '__main__':
    sys.exit(run('jobai', main))
