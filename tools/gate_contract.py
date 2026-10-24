#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""게이트 출력·종료코드 계약 — `tools/check_*.py` 는 전부 이걸 거쳐 끝난다.

왜 있나:
  게이트마다 실패를 알리는 방법이 달랐다. 어떤 도구는 `[FAIL]`, 어떤 도구는 `MISSING:`,
  어떤 도구는 exit 2, 어떤 도구는 traceback. 자동화가 "이 단계가 실패했나"를 알아내려면
  도구마다 다른 문자열을 알아야 했다. 계약은 그걸 한 줄로 고정한다.

계약 (G-1~G-4):
  G-1  종료코드는 0·1·2 셋뿐이다.
         0 통과 · 1 검사 실패 · 2 설정/사용 오류 (정본 없음·인자 오류)
       그 밖의 코드와 None 은 계약 위반이라 1 로 정규화하고 그 사실을 줄에 적는다.
  G-2  마지막 줄은 `[PASS] <id>` 또는 `[FAIL] <id>` — 기계가 읽는 한 줄.
       그 위의 사람용 출력(`DOCS OK …` `→ 통과` 등)은 도구마다 달라도 된다.
       실패면 이유를 `[FAIL] <id> — <이유>` 로 덧붙인다.
  G-3  잡히지 않은 예외도 traceback 으로 끝나지 않는다.
       `[FAIL] <id> — 내부 오류: <형식>: <메시지>` 로 끝내고, 디버깅용 마지막 프레임 한 줄만
       stderr 에 남긴다.
  G-4  `--json` 이면 stdout 은 JSON 하나다. 사람용 줄과 `[PASS]`/`[FAIL]` 줄은 stderr 로 간다.
       (도구가 stdout 에 사람용 줄을 직접 찍으면 그건 그 도구가 지켜야 한다 — 아래 emit 참고)

<id> 는 `tools/gate_all.py` 의 단계 id 를 쓴다
(docs·glossary·gdd·gddjob·gddrev·text·cjk·paths·manfields·manvalues·pages·fusion·gacha·numbers·monsters·husbandry·blockroster·jobai·personality·biomeassets·kitart·contract).
그래야 `gate_all` 로그에서 어느 줄이 어느 단계인지 바로 맞는다.

쓰는 법:
    from gate_contract import run
    if __name__ == '__main__':
        sys.exit(run('text', main))

검사: ./.venv/bin/python tools/test_gate_contract.py
"""
import sys
import traceback

PASS, FAIL, USAGE = 0, 1, 2
CODES = (PASS, FAIL, USAGE)


def stream(json_mode=False):
    """사람용 줄을 찍을 곳 — `--json` 이면 stderr, 아니면 stdout."""
    return sys.stderr if json_mode else sys.stdout


def verdict(gate, code, note='', json_mode=False):
    """G-1·G-2 — 종료코드를 정규화하고 마지막 줄을 찍은 뒤 그 코드를 돌려준다."""
    if code is None:
        code = PASS
    if code not in CODES:
        note = ((note + ' · ') if note else '') + '계약 밖 종료코드 %r → 1' % (code,)
        code = FAIL
    if code == PASS:
        print('[PASS] %s' % gate, file=stream(json_mode), flush=True)
    else:
        print('[FAIL] %s%s' % (gate, (' — ' + note) if note else ''),
              file=stream(json_mode), flush=True)
    return code


def run(gate, fn, json_mode=None):
    """게이트 main 을 계약에 맞춰 실행한다.

    fn 은 종료코드를 돌려주는 함수여야 한다 (None 은 0). `--json` 은 인자에서 읽는다.
    """
    if json_mode is None:
        json_mode = '--json' in sys.argv[1:]
    note = ''
    try:
        code = fn()
    except SystemExit as exc:                       # 게이트가 직접 sys.exit 한 경우
        if isinstance(exc.code, int) or exc.code is None:
            code, note = exc.code, 'sys.exit(%r)' % (exc.code,)
        else:
            # `raise SystemExit('FAIL — 이유')` 는 문자열이 종료코드 자리에 온다.
            # 그냥 받으면 파이썬이 이유를 찍어 주지 않으므로(인터프리터가 찍는 자리다) 여기서 살린다.
            code, note = FAIL, str(exc.code)
    except Exception as exc:                        # G-3 — traceback 금지
        code = FAIL
        note = '내부 오류: %s: %s' % (type(exc).__name__, exc)
        frames = traceback.format_exc().strip().splitlines()
        print(frames[-1].strip() if frames else note, file=sys.stderr, flush=True)
    return verdict(gate, code, note, json_mode)


def fail(gate, reason):
    """스크립트형 게이트(선형 실행)용 — 마지막 줄을 찍고 종료코드 1 을 돌려준다."""
    print('[FAIL] %s — %s' % (gate, reason), flush=True)
    return FAIL
