# GDD 개정 반영본 — 생성물

> `./.venv/bin/python tools/gen_gdd_revised.py --write` 가 만든다. 손으로 고치지 않는다.

`docs/gdd/` 는 원본 문면이라 고치지 않는다. 이 폴더는 그 원본을 **읽기용으로 복사**한 뒤,
직업 표의 옛 이름과 **데이터와 어긋난 서술**을 바로잡은 사본이다.

- 바뀐 곳 ①: [GDD_직업_개정_대기.md](../l10n/GDD_직업_개정_대기.md) 에 적힌 파일·줄·칸 그대로
- 바뀐 곳 ②: `tools/gen_gdd_revised.py` 의 `REVISIONS` — biomes/monsters 실측과 어긋난 바이옴 계층·종 수·category·문지기 서술
- 바뀐 곳 ③: `docs/l10n/동철_판정.json` 이 `옛 이름` 으로 판정한 자리 (적성·태그·산문 포함)
- 안 바뀐 곳: 그 밖의 산문, 개정 이력 행, 몬스터·용어 이름, `다른 뜻` 으로 판정한 동철 표기
- 정본은 여전히 `data/` 와 `docs/gdd/` 다. 이 폴더는 "새 이름으로 읽으면 어떻게 읽히나"를 보는 사본이다

원본에 개정본이 들어오면 `docs/gdd/` 를 교체하고 `tools/gen_gdd_revised.py --write` 로 다시 만든다.
