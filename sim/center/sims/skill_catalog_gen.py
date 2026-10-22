#!/usr/bin/env python3
# skill_catalog_gen.py — P1-v3 스킬 카탈로그 1,300종 생성기 (결정론 · D-269 재편 2026-09-19)
# 배분(13블록): 전투780=4도메인×15블록 · 생활390=3×10 · 사회130=10
# 레어도: D 443 / C 332 / B 278 / A 130 / S 78 / L 39 — A→S→L ×2 희소 그라디언트
# S 진입 530 (×2.2 점프) · L 3태그 전용(자기 도메인 2 + 타 도메인 1) · 문맥 13×3포즈
# 이름 3층: D·C 수식+어근 / B·A +장식 / S·L 유산 시딩 (등급별 톤 그라디언트)
import sys, json, random, os as _os
# 저장소 경로는 스크립트 위치에서 계산한다 — 폴더 개명(2026-09-27 soul-commander → fons)에 안전
_HERE = _os.path.dirname(_os.path.abspath(__file__))
sys.path.insert(0, _HERE)
import gacha_test as g

SEED = 20260919
CTX26 = 26

DOMAINS = {
    '공격': ['근접타격','베기','찌르기','둔기타격','연속타격','원거리사격','투척','저격','마법시전','광역살포','관통공격','약점타격','흡수공격'],
    '기동': ['돌진','추격','후퇴','측면기동','매복','잠행','은신','정찰','거리유지','도약','등반','신속기동','영역이동'],
    '방어·제어': ['방어태세','방벽전개','회피','반격자세','도발','아군보호','경계','속박','침묵','실명','넉백','끌어당김','저지'],
    '지원': ['치유','보호막','정화','강화버프','약화디버프','소환','함정설치','지형활용','사기부여','오라전개','마나공급','전술신호','부활시도'],
    '생산': ['채집','벌목','농사','채광','제련','건축가','대장장이','세공','조약사','요리','양조','건설','운반'],
    '지식': ['연구','실험','해독','감정','관찰','의사','약초학','측량','지도제작','기록','별관측','곤충','마석학'],
    '사회': ['순찰','경계근무','자체훈련','훈련지도','재고관리','교섭','탐색','위문','축연','장사','분쟁중재','청소','정산'],
    '회복': ['휴식','수면','식사','목욕','요양','장비정비','명상','기도','독서','산책','정신수련','놀이','자연접촉'],
}
CTX_TAGS = ['야간','다수적','장애물','아군부상','적저체력','자기저체력','공중','수중','협소','장거리','밀착','무리생물','보스급']
CATEGORY = {'공격':'전투','기동':'전투','방어·제어':'전투','지원':'전투','생산':'생활','지식':'생활','회복':'생활','사회':'사회'}
# D-269 재편 — 카테고리×레어도 종수 (도메인 분배 → 태그 블록 분배 · 780/390/130 = 6:3:1)
BLOCKS_TOTAL = {'전투': {1:267, 2:200, 3:168, 4:65, 5:39, 6:24},
                '생활': {1:132, 2:100, 3:83, 4:52, 5:30, 6:12},
                '사회': {1:44, 2:32, 3:27, 4:13, 5:9, 6:3}}
BAND = {1:(13,64), 2:(65,129), 3:(130,239), 4:(240,415), 5:(530,714), 6:(715,10**9)}  # S 진입 530 (D-269 — ×2.2 점프)
RNAME = {1:'D',2:'C',3:'B',4:'A',5:'S',6:'L'}  # D-269 알파벳 전환
STAGE_CAP = {1:'중급',2:'상급',3:'특급',4:'극급',5:'신급',6:'초월급'}

# --- P1-v2 수치 체계 (미정K 가안 · 09 §5-2) ---
# 효과 종류 — 태그 → 종류 (전투: 피해/속도/방어/지속/회복/효과 · 생활: 효율/피로회복)
TAG_KIND = {}
for t in DOMAINS['공격']: TAG_KIND[t] = '피해'
for t in DOMAINS['기동']: TAG_KIND[t] = '속도'
for t in ('방어태세','방벽전개','회피','반격자세','아군보호','저지','경계'): TAG_KIND[t] = '방어'
for t in ('도발','속박','침묵','실명','넉백','끌어당김'): TAG_KIND[t] = '지속'
for t in ('치유','보호막'): TAG_KIND[t] = '회복'
for t in DOMAINS['지원']:
    if t not in TAG_KIND: TAG_KIND[t] = '효과'
for t in ('휴식','수면','요양','목욕'): TAG_KIND[t] = '피로회복'
for dom in ('생산','지식','사회','회복'):
    for t in DOMAINS[dom]:
        if t not in TAG_KIND: TAG_KIND[t] = '효율'
EFFECT_BASE = {1: 5, 2: 8, 3: 12, 4: 18, 5: 25, 6: 35}       # 전투 기본값 % (단계1·레벨1)
EFFECT_BASE_LIFE = {1: 4, 2: 6, 3: 9, 4: 13, 5: 18, 6: 25}   # 생활·사회
COOL_BASE = {'피해': 6, '속도': 10, '방어': 15, '지속': 15, '회복': 20, '효과': 20}  # 초
DUR_BASE = {'지속': 5, '효과': 8, '회복': 4}  # 지속시간(초) 보유 종류
def calc_values(r, dom, tag, cat):
    kind = TAG_KIND[tag]
    base = (EFFECT_BASE_LIFE if cat in ('생활','사회') else EFFECT_BASE)[r]
    vals = {'효과_종류': kind, '효과_기본': base}
    if cat == '전투':
        vals['쿨_기본'] = round(COOL_BASE[kind] * (1 - 0.05*(r-1)), 1)
        vals['소모'] = {'마나': round((8 + 4*r) * (1 + 0.05*(r-1)))}
    else:
        vals['쿨_기본'] = None
        vals['소모'] = {'스태미너': 5 + 3*r}
    if kind in DUR_BASE:
        vals['지속_기본'] = round(DUR_BASE[kind] * (1 + 0.13*(r-1)), 1)
    return vals
T13,T39,T65,T130,T195,T325,T390,T650 = 13,39,65,130,195,325,390,650
# S — 2태그 530~714 (650+39 · 650+13 · 390+195 · 325+325 …)
TPL = {
    1: [ ((T13,), False), ((T13,), 'A'), ((T13,T13), False), ((T13,), 'B'), ((T13,T13), 'C') ],
    2: [ ((T65,), False), ((T39,T39), False), ((T65,), 'A'), ((T65,T13), False) ],
    3: [ ((T130,), False), ((T65,T65), False), ((T130,), 'A') ],
    4: [ ((T390,), False), ((T195,T130), False), ((T130,T130), 'A') ],
    5: [ ((T650,T39), False), ((T390,T195), False), ((T650,T13), False), ((T325,T195), 'CTX') ],  # 마지막 TPL: 520+26=546 — S+S→L 페어용 (L 태그 1 보유 + 동반)
    6: 'L3',  # L 3태그 전용 — build()에서 별도 경로 (자기 도메인 2 + 타 도메인 1 · 문맥 필수)
}
MODS = ['화염','빙결','뇌전','심연','성광','질풍','대지','월영','강철','신속','연쇄','침묵','맹독','파멸','은폐','중첩']
ROOTS = {
 '근접타격':['강타','타격','충타'], '베기':['참격','일섬','절취'], '찌르기':['침격','천철','철참'],
 '둔기타격':['격축','중타','파격'],
 '연속타격':['연타','난타','연격'], '원거리사격':['사격','격발','연발'], '투척':['투창','투석','천투'],
 '저격':['저격','명살','조준'], '마법시전':['주문','영창','마격'], '광역살포':['난사','살포','폭사'],
 '관통공격':['관통','천공','관철'], '약점타격':['정타','급소','치명'], '흡수공격':['흡수','흡혈','포식'],
 '돌진':['돌진','돌파','추진'], '추격':['추격','추적','맹추'], '후퇴':['퇴각','철수','후퇴'],
 '측면기동':['우회','측면','선회'], '매복':['매복','복격','잠복'], '잠행':['잠행','무음','은밀'],
 '은신':['은신','은폐','차폐'], '정찰':['정찰','탐지','주시'], '거리유지':['이격','간격','격리'],
 '도약':['도약','비약','약진'], '등반':['등반','등정','암벽'], '신속기동':['질주','속행','신속'],
 '영역이동':['전이','유영','이동'],
 '방어태세':['방어','태세','수비'], '방벽전개':['방벽','장벽','벽호'], '회피':['회피','피신'],
 '반격자세':['반격','역습'], '도발':['도발','조롱'], '아군보호':['호위','수호','보호'],
 '경계':['경계','감시'], '속박':['속박','구속','포박'], '침묵':['침묵','봉인'],
 '실명':['실명','암전'], '넉백':['격퇴','넉백'], '끌어당김':['포획','당김'], '저지':['저지','차단','방해'],
 '치유':['치유','치료'], '보호막':['가호','보호'], '정화':['정화','세정','정결'],
 '강화버프':['강화','증강','부여'], '약화디버프':['약화','쇠약','저하'], '소환':['소환','환영'],
 '함정설치':['함정','설치'], '지형활용':['지형','지세'], '사기부여':['사기','고취'],
 '오라전개':['오라','발산'], '마나공급':['공급','주입'], '전술신호':['신호','전언','지시'],
 '부활시도':['부활','환생','소생'],
 '채집':['채집','채취'], '벌목':['벌목','벌채'], '농사':['경작','파종','수확'],
 '채광':['채굴','발굴','굴착'], '제련':['제련','용해'], '건축가':['목공','목조'],
 '대장장이':['단조','가공','주조'], '세공':['세공','조각'], '조약사':['처방','배합','정제'],
 '요리':['요리','조리'], '양조':['양조','발효'], '건설':['건설','축조','시공'], '운반':['운반','운송','하역'],
 '연구':['연구','탐구','고찰'], '실험':['실험','시험','검증'], '해독':['해독','해석'],
 '감정':['감정','감별','감식'], '관찰':['관찰','관측'], '의사':['진료','응급'],
 '약초학':['약초','채약'], '측량':['측량','계측','측정'], '지도제작':['제도','제작'],
 '기록':['기록','필사'], '별관측':['천문','별관'], '곤충':['사육','부림'], '마석학':['마석','정석'],
 '순찰':['순찰','순회','순행'], '경계근무':['근무','당직','경비'], '자체훈련':['단련','수련'],
 '훈련지도':['훈련','교육'], '재고관리':['재고','관리','정리'], '교섭':['교섭','협상','담판'],
 '탐색':['수색','통솔','호령'], '위문':['위문','위로','격려'], '축연':['축연','연회','잔치'],
 '장사':['상술','매매'], '분쟁중재':['중재','조정','화해'], '청소':['청소','소독','정돈'],
 '정산':['정산','결산','회계'],
 '휴식':['휴식','안식'], '수면':['수면','숙면'], '식사':['식사','섭취'],
 '목욕':['목욕','탕욕'], '요양':['요양','재활'], '장비정비':['정비','수리','손질'],
 '명상':['명상','좌선'], '기도':['기도','축원'], '독서':['독서','열독'],
 '산책':['산책','산보'], '정신수련':['수련','심련'], '놀이':['유희','놀이'], '자연접촉':['귀의','산림'],
}

def reserved_words():
    rw = set(g.JOB_COEF) | set(g.JOB_COEF_L2) | set(g.P_WEIGHT) | set(g.SUB_TRAITS) | set(g.COMMON_RARE_APT)
    for attr in ('RARE_APT_BY_LIN','LIN_RARE_APT','RARE_APT_ALL'):
        v = getattr(g, attr, None)
        if isinstance(v, dict): rw |= {x for xs in v.values() for x in (xs if isinstance(xs,(list,tuple)) else [xs])}
        elif isinstance(v,(list,tuple)): rw |= set(v)
    for attr in ('SUBRACES','SUB_RACES'):
        v = getattr(g, attr, None)
        if isinstance(v,(list,tuple)): rw |= set(v)
    return rw

def build():
    RESERVED = reserved_words()
    skills, used_names, used_cond = [], set(), set()
    sid = 0
    l_seq = [0]  # L 전역 순번 — 문맥 13종 × 3포즈 완전 균등 배정 (D-269)
    # 카테고리 총량을 도메인에 먼저 분배 (전투 4·생활 3·사회 1 — 몫+잔여 결정론) 후 태그 블록 분배
    CAT_DOMS = {c: [d for d in DOMAINS if CATEGORY[d] == c] for c in ('전투', '생활', '사회')}
    DOM_TOTALS = {}
    for c, doms in CAT_DOMS.items():
        for r, total_r in BLOCKS_TOTAL[c].items():
            q, rem = divmod(total_r, len(doms))
            for di, d in enumerate(doms):
                DOM_TOTALS.setdefault(d, {})[r] = q + (1 if di < rem else 0)
    for dom, tags in DOMAINS.items():
        cat = CATEGORY[dom]
        ntags = len(tags)
        for r, total_r in DOM_TOTALS[dom].items():
            # 종수를 태그 블록에 분배 — 몫 + 잔여는 결정론 순서(ti 순)로 1개씩
            base_q, rem = divmod(total_r, ntags)
            for ti, tag in enumerate(tags):
                roots = ROOTS[tag]
                n_per_tag = base_q + (1 if ti < rem else 0)
                for j in range(n_per_tag):
                    if TPL[r] == 'L3':
                        # ── L 3태그 전용 (D-269) ── 문맥 13×3포즈: idx = (j*13 + ti*2) % 13 · 포즈 = j // 3
                        others = [t for t in tags if t != tag]
                        # 자기 도메인 2태그: 자기 + 타 태그 1 · 타 도메인 1: 전역 태그 풀에서 결정론 선택
                        cross_dom = [d for d in DOMAINS if d != dom]
                        cross_tags = DOMAINS[cross_dom[(j + ti) % len(cross_dom)]]
                        # S+S→L 융합 트리 정합: 자기 390 + 타 325 + 인접 도메인 195 = 910 (문맥+26 → 936)
                        p_self, p_second, p_cross = T390, T325, T195
                        thrs = [(tag, p_self), (others[(ti + j) % len(others)], p_second),
                                (cross_tags[(ti + j) % len(cross_tags)], p_cross)]
                        k = l_seq[0]; l_seq[0] += 1
                        ctx = CTX_TAGS[k % 13]                         # 문맥 13종 완전 순환 × 3포즈
                    else:
                        thr_tpl, ctx_mode = TPL[r][(ti + j) % len(TPL[r])]
                        thrs = [(tag if k == 0 else tags[(ti + 1 + j + k) % 13], t) for k, t in enumerate(thr_tpl)]
                        ctx = None
                        if ctx_mode:
                            ctx = CTX_TAGS[(ti * 2 + j + (0 if ctx_mode=='A' else 5) + (r-1)*3) % 13]
                    cond_key = (frozenset(thrs), ctx)
                    if cond_key in used_cond:
                        # 조건 중복 탈출 — 결정론 프로브 (L3: 문맥 회전 → 임계 재배치 → 태그 교체 / 일반: TPL 대안)
                        found = False
                        for shift in range(1, 13):                      # ① 문맥 인덱스 회전 (13방향) — L3·일반 공용
                            k2 = (frozenset(thrs), CTX_TAGS[(ti * 3 + j + shift) % 13] if ctx else None)
                            if k2 not in used_cond:
                                thrs, ctx, cond_key = thrs, k2[1], k2
                                found = True; break
                        if not found and len(thrs) == 3:
                            for p_self2 in (T390, T325, T195):           # ② 임계 재배치 (동일 합계 유지 아님 — 밴드 재검증)
                                for p_second2 in (T325, T195, T130):
                                    for p_cross2 in (T195, T130, T65):
                                        tot2 = p_self2 + p_second2 + p_cross2
                                        if r < 6 and not (BAND[r][0] <= tot2 <= BAND[r][1]):
                                            continue
                                        if r == 6 and tot2 < BAND[6][0]:
                                            continue
                                        thrs2 = [(thrs[0][0], p_self2), (thrs[1][0], p_second2), (thrs[2][0], p_cross2)]
                                        for shift in range(13):
                                            k2 = (frozenset(thrs2), CTX_TAGS[(ti * 3 + j + shift) % 13] if ctx else None)
                                            if k2 not in used_cond:
                                                thrs, ctx, cond_key = thrs2, k2[1], k2
                                                found = True; break
                                        if found: break
                                    if found: break
                                if found: break
                        if not found and TPL[r] != 'L3':
                            # ③ TPL 대안 × 제2태그 회전 × 문맥 회전 (13×13×len(TPL) 후보 — 결정론)
                            for alt_i in range(len(TPL[r])):
                                thr2, cm2 = TPL[r][alt_i]
                                for dt in range(13):
                                    thrs2 = [(tag if k==0 else tags[(ti+1+dt+k)%13], t) for k,t in enumerate(thr2)]
                                    for dc in range(13):
                                        ctx2 = CTX_TAGS[(ti+alt_i*4+r+dc)%13] if cm2 else None
                                        k2 = (frozenset(thrs2), ctx2)
                                        if k2 not in used_cond:
                                            thrs, ctx, cond_key = thrs2, ctx2, k2
                                            found = True
                                            break
                                    if found: break
                                if found: break
                        assert found, f"조건 중복 미해소: {tag} R{r}"
                    used_cond.add(cond_key)
                    total = sum(t for _, t in thrs) + (CTX26 if ctx else 0)
                    lo, hi = BAND[r]
                    assert lo <= total and (total <= hi if r < 6 else True), f"밴드 이탈: {tag} R{r} 합계 {total}"
                    root = roots[(j + ti) % len(roots)]
                    name = None
                    # ── 3층 이름 로직 (D-269 — 등급별 톤 그라디언트) ──
                    # 1층 수식(MODS) · 2층 동작 어근 · 3층 장식/유산 (S·L만 결정론 시딩)
                    LORE_S = ['검은','잿빛','붉은','천둥의','그늘의','이름없는','잊혀진','깊은']
                    LORE_L = ['종언의','여명을 부르는','심연이 꿈꾸는','하늘이 갈라지는','만개하는',
                              '잿불 속의','유성이 지는','겁 없는','왕의','파수꾼의','울부짖는','별이 눈물 짓는','첫 번째']
                    DECOR  = ['의','의','의']  # B·A 접미 조사 후보
                    SUFFIX = {'B': ['술','법'], 'A': ['의 진수','의 극의'], 'S': ['— 검의 노래','— 대지의 유산'], }
                    def _ok(cand):
                        return (cand not in used_names and not any(w in cand for w in RESERVED)
                                and not any(cand[i]==cand[i+1] for i in range(len(cand)-1)))
                    if r >= 5:
                        # S·L — 유산 시딩: [유산] + [어근 또는 수식+어근]
                        lore = (LORE_L if r == 6 else LORE_S)[(ti + j*3 + r) % len(LORE_L if r == 6 else LORE_S)]
                        body = m_ = None
                        for probe in range(24):
                            m_ = MODS[(ti * 5 + j * 7 + r + probe) % 16]
                            cand = f"{lore} {m_}{root}"
                            if m_ not in root and _ok(cand):
                                name = cand; break
                        if name is None:
                            for probe in range(24):
                                root2 = roots[(j + probe) % len(roots)]
                                cand = f"{lore} {root2}"
                                if _ok(cand):
                                    name = cand; break
                    elif r >= 3:
                        # B·A — 2~3층: [수식] + 어근 (+ 접미 장식 결정론)
                        for probe in range(24):
                            m = MODS[(ti * 7 + j * 3 + r + probe * 5) % 16]
                            base = m + root
                            if r == 4 and probe % 2 == 1:
                                base = m + root + SUFFIX['A'][probe % len(SUFFIX['A'])]
                            elif r == 3 and probe % 3 == 2:
                                base = m + root + SUFFIX['B'][probe % len(SUFFIX['B'])]
                            if m in root or root in m: continue
                            if _ok(base):
                                name = base; break
                    if name is None:
                        # D·C — 기존 2단 (수식+어근) + 폴백 공용
                        for probe in range(16):
                            m = MODS[(ti * 7 + j * 3 + r + probe * 5) % 16]
                            cand = m + root
                            if m in root or root in m: continue
                            if _ok(cand):
                                name = cand; break
                    if name is None:
                        # 최종 폴백 — 전체 어근×수식×순번 접미 (결정론 · 3층 유산 조합 포함)
                        ord_sfx = ['검','술','참','격','파','진','각','열','격참','분격']
                        for root2 in roots:
                            for m in MODS:
                                for sfx in [''] + ord_sfx:
                                    cand = (f"{LORE_S[(ti+j)%len(LORE_S)]} " if r >= 5 else '') + m + root2 + sfx
                                    if m in root2 or root2 in m: continue
                                    if _ok(cand):
                                        name = cand; break
                                if name: break
                            if name: break
                        if name is None and r >= 5:
                            for probe in range(64):
                                cand = f"{LORE_L[(ti+probe)%len(LORE_L)]} {roots[(probe)%len(roots)][0]}{root}{ord_sfx[probe%len(ord_sfx)]}"
                                if _ok(cand):
                                    name = cand; break
                    assert name, f"이름 미확보: {tag} R{r} j={j}"
                    used_names.add(name)
                    sid += 1
                    skills.append({'id': sid, '이름': name, '카테고리': cat, '도메인': dom,
                        '태그': [t for t,_ in thrs], '태그_임계': {t: v for t, v in thrs},
                        '문맥': ctx, '각인_임계': total, '레어도': r, '레어도_명칭': RNAME[r],
                        '단계_상한': STAGE_CAP[r], **calc_values(r, dom, tag, cat)})
    return skills

def verify(skills):
    errs = []
    cats = {'전투':0,'생활':0,'사회':0}; rars = {r:0 for r in BAND}
    tag_cnt = {t:0 for xs in DOMAINS.values() for t in xs}
    names = set()
    RESERVED = reserved_words()
    for s in skills:
        cats[s['카테고리']] += 1; rars[s['레어도']] += 1
        for t in s['태그']: tag_cnt[t] += 1
        if s['이름'] in names: errs.append(f"이름 중복 {s['이름']}")
        names.add(s['이름'])
        if any(w in s['이름'] for w in RESERVED): errs.append(f"충돌 어휘 {s['이름']}")
        lo, hi = BAND[s['레어도']]
        if not (lo <= s['각인_임계'] and (s['레어도']==6 or s['각인_임계'] <= hi)):
            errs.append(f"밴드 {s['이름']} {s['각인_임계']}")
    zero = [t for t,c in tag_cnt.items() if c == 0]
    if zero: errs.append(f"고아 태그 {zero}")
    for x in skills:  # 수치 불변식 — 전투만 쿨·마나 / 생활·사회만 스태미너
        if x['카테고리'] == '전투':
            if not (x['쿨_기본'] and x['쿨_기본'] > 0 and x['소모'].get('마나', 0) > 0):
                errs.append(f"전투 수치 누락 {x['이름']}")
        else:
            if x['쿨_기본'] is not None or x['소모'].get('스태미너', 0) <= 0:
                errs.append(f"생활 수치 규칙 위반 {x['이름']}")
    return cats, rars, tag_cnt, errs

if __name__ == '__main__':
    skills = build()
    cats, rars, tag_cnt, errs = verify(skills)
    print(f"생성: {len(skills):,}종 (목표 1,300)")
    print(f"카테고리: {cats} (D-269 재편 — 전투/생활/사회 6:3:1 그리드 분배)")
    print(f"레어도: {rars} (D-269 목표 443/332/278/130/78/39)")
    print(f"태그 커버: {sum(1 for c in tag_cnt.values() if c>0)}/104 · 최소 {min(tag_cnt.values())} · 최대 {max(tag_cnt.values())}")
    print(f"오류: {len(errs)}건 {errs[:5]}")
    kinds = {}
    for x in skills: kinds[x['효과_종류']] = kinds.get(x['효과_종류'], 0) + 1
    print(f"효과 종류 분포: {kinds}")
    if not errs and len(skills) == 1300:
        with open(_os.path.join(_HERE, 'skills_catalog.json'), 'w', encoding='utf-8') as f:
            json.dump({'meta':{'버전':'P1-v3 (D-269)','수치':'미정K 가안 — 성장식 효과=기본×(1+0.10×(단계-1))×(1+0.015×(레벨-1)) · 쿨=기본×(1-0.05(r-1))×(1-0.03(단계-1)) · 소모 마나=(8+4r)×(1+0.05(r-1)) / 생활 스태미너=5+3r (09 §5-2)','seed':SEED,'생성':'skill_catalog_gen.py','총':'1,300',
                '배분':'전투780·생활390·사회130 — 레어도 D 443/C 332/B 278/A 130/S 78/L 39 · S진입 530 · L 3태그 전용+문맥 13×3포즈'},
                'skills':skills}, f, ensure_ascii=False, indent=1)
        print("저장: design-docs/_tools/skills_catalog.json")
        print("샘플:", [f"{s['이름']}({RNAME[s['레어도']]}/{s['도메인']})" for s in skills[::217]])
