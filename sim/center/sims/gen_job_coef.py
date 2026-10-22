#!/usr/bin/env python3
# ─────────────────────────────────────────────────────────────────────
# gen_job_coef.py — 직업계수(L1 7 · L2 26 · 전직 티어)를 data/job_coef.json 으로
#
# 왜 만드나
#   계수 정본은 `gacha_test.py` 의 JOB_COEF / JOB_COEF_L2 / JOB_TIER 다
#   (05 §8-1 표가 이 값에서 자동 생성된다 — 05 §4 의 13직업 표는 개편 대기라 폐기 대상).
#   Godot 쪽이 그 값을 손으로 옮겨 적으면 조용히 갈라진다. 여기서 **데이터로 뽑아**
#   런타임이 JSON 하나를 읽게 한다 (ADR 0002 — 정본은 JSON 하나, 사본은 생성물).
#
# 매핑 규칙 (job_tree.json 이름 → 계수표 키)
#   1. 이름이 같으면 그대로 쓴다 — L1 6종 · L2 26종 전부 1:1.
#   2. `무명자` 는 계수표에 없다. 산하 직업이 없는 자리라 `무직` 의 6축 중립(1.0)을 쓴다.
#   3. L2 티어가 없는 직업(`수도사`·`정신술사`)은 `gacha_test.job_tier_mul` 과 같은 기본값 B.
#   매핑한 예외는 `fallbacks` 에 적어 출력이 스스로 설명하게 한다.
#
# 사용: python3 sim/center/sims/gen_job_coef.py [--write|--check]
#   --check 는 파일을 고치지 않고 어긋난지만 본다 (exit 1)
# ─────────────────────────────────────────────────────────────────────
import ast
import json
import os
import sys

TOOLS = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(TOOLS, '..', '..', '..'))
TREE = os.path.join(ROOT, 'data', 'job_tree.json')
OUT = os.path.join(ROOT, 'data', 'job_coef.json')
GACHA = os.path.join(TOOLS, 'gacha_test.py')

AXES = ['HP', 'ATK', 'DEF', 'ASPD', 'MAG', 'MDEF', 'CRI']
TIER_AXES = ['HP', 'ATK', 'DEF', 'ASPD', 'MAG', 'MDEF']
NEUTRAL_ALIAS = '무명자'
NEUTRAL_KEY = '무직'
DEFAULT_TIER = 'B'


def _dict_from_module(path, name):
    """gacha_test.py 를 실행하지 않고 dict 리터럴만 뽑는다 (부작용 회피)."""
    with open(path, encoding='utf-8') as fh:
        tree = ast.parse(fh.read())
    for node in tree.body:
        if isinstance(node, ast.Assign) and any(
                isinstance(t, ast.Name) and t.id == name for t in node.targets):
            return ast.literal_eval(node.value)
    raise SystemExit(f'FAIL — {path} 에서 {name} 을 찾지 못했다')


def build():
    with open(TREE, encoding='utf-8') as fh:
        root = json.load(fh)
    coef1 = _dict_from_module(GACHA, 'JOB_COEF')
    coef2 = _dict_from_module(GACHA, 'JOB_COEF_L2')
    tier_of = _dict_from_module(GACHA, 'JOB_TIER')
    tier_mul = _dict_from_module(GACHA, 'TIER_MUL')

    jobs = root['jobs']
    by_id = {j['id']: j for j in jobs}
    fallbacks = []

    l1 = {}
    for job in jobs:
        if job.get('stage') != 1:
            continue
        key = job['name'] if job['name'] in coef1 else NEUTRAL_KEY
        if key != job['name']:
            fallbacks.append({
                'job': job['name'], 'id': job['id'], 'used': key,
                'why': '산하 직업이 없는 자리 — 6축 중립(1.0) 계수',
            })
        l1[job['id']] = {'name': job['name'], 'coef': list(coef1[key])}

    l2 = {}
    for job in jobs:
        if job.get('stage') != 2:
            continue
        if job['name'] not in coef2:
            raise SystemExit('FAIL — 계수 없는 L2: %s' % job['name'])
        tier = tier_of.get(job['name'])
        if tier is None:
            tier = DEFAULT_TIER
            fallbacks.append({
                'job': job['name'], 'id': job['id'], 'used': tier,
                'why': '전직 난이도 티어 미지정 — gacha_test.job_tier_mul 기본값과 같다',
            })
        parent = by_id.get(job.get('parentId') or '', {})
        l2[job['id']] = {
            'name': job['name'],
            'parent': parent.get('name', ''),
            'tier': tier,
            'coef': list(coef2[job['name']]),
        }

    return {
        '$schema': 'job_coef/v1',
        'source': 'sim/center/sims/gacha_test.py — JOB_COEF · JOB_COEF_L2 · JOB_TIER · TIER_MUL'
                  ' (05 §8-1 정본 표와 1:1)',
        'note': '05 §4 의 13직업 표는 10차 개편 대기라 쓰지 않는다. 축 7종은 05 §7 '
                '"HP·ATK·DEF·공속·MAG·MDEF·CRI" 이고, 전직 티어는 6축에 제곱근으로 걸린다.',
        'axes': AXES,
        'tierAxes': TIER_AXES,
        'tierMul': {k: tier_mul[k] for k in sorted(tier_mul)},
        'l1': l1,
        'l2': l2,
        'fallbacks': fallbacks,
    }


def dump(data):
    return json.dumps(data, ensure_ascii=False, indent=1, sort_keys=True) + '\n'


def main(argv):
    text = dump(build())
    check = '--check' in argv
    if check:
        if not os.path.exists(OUT):
            print('FAIL — %s 가 없다 (--write 로 만든다)' % OUT)
            return 1
        with open(OUT, encoding='utf-8') as fh:
            if fh.read() != text:
                print('FAIL — job_coef.json 이 gacha_test.py 와 어긋났다 (--write 로 다시 뽑는다)')
                return 1
        print('OK — job_coef.json 이 정본과 같다')
        return 0
    if '--write' not in argv:
        print('사용: gen_job_coef.py --write | --check')
        return 2
    with open(OUT, 'w', encoding='utf-8') as fh:
        fh.write(text)
    data = json.loads(text)
    print('OK — L1 %d · L2 %d · 예외 %d → %s'
          % (len(data['l1']), len(data['l2']), len(data['fallbacks']), OUT))
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
