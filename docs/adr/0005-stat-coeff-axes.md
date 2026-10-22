# ADR 0005 — 등급계수·레벨계수는 축 집합이 다르다

## 맥락

영웅 필드스탯은 `기준 × (1+statMods%) × 직업계수 × 등급계수 × 레벨계수 × 순수도` 다
(05 §7 · 01 §2). GDD는 **등급계수 미적용 7종**을 못박았지만 — ASPD · CRI · PEN · MS · CDMG · SPD_CAST · STA —
**레벨계수를 어느 축에 거는지는 어디에도 적지 않았다.**

그대로 13축 전부에 레벨계수 ×7.45를 걸면 MS 100% 가 745%, ASPD 10 이 74.5 가 된다.
반대로 크기 스탯에만 걸면 GDD 문면보다 좁아진다. 어느 쪽도 근거가 없으면
6개월 뒤에 이 코드를 읽는 사람이 값을 역추측해야 한다.

## 대안

1. **GDD 문면대로 전 축에 레벨계수를 건다.** 비율·회수 축이 ×7.45 가 된다. MS·ASPD 기준값을 1/7로 다시 잡아야 한다.
2. **등급·레벨 둘 다 크기 스탯 5종에만 건다.** 단순하지만 MANA 가 등급계수를 못 받아 원본과 어긋난다.
3. **원본 구현을 읽고 두 축 집합을 따로 정한다.**

## 결정

3번. 원본 Unity 구현이 이미 두 집합을 다르게 쓰고 있었다 (원본 대조).

| 계수 | 축 | 근거 |
|---|---|---|
| 등급계수 | HP · ATK · MAG · DEF · MDEF · **MANA** | `CombatStats.FromRace` 가 `* rankMul` 을 이 6축에만 건다 |
| 레벨계수 | HP · ATK · MAG · DEF · MDEF | `BattleSystem.AddHero` 가 `lvMul` 을 이 5축에만 건다 (`Mana` 는 가산만) |

원본 코드 경로 (원본 대조):

```
unity/Assets/Scripts/Data/DataModels.cs      CombatStats.FromRace   ← rankMul: Hp·Atk·Mag·Def·MDef·Mana
unity/Assets/Scripts/Battle/BattleSystem.cs  AddHero                ← lvMul: Hp·Atk·Mag·Def·MDef
unity/Assets/Scripts/Core/LevelCurve.cs      1 + (Lv−1)×0.05, 상한 130
```

`CombatStats.FromRace` 의 나머지 축(ASPD·PEN·EVA·CRI·CDMG·SpdCast·Sta)은 어느 계수도 안 받는다 —
05 §7 의 "등급계수 미적용 7종"과 같은 목록이다(38차 EVA→MS 교체 반영). MANA 는 그 7종 목록에 없으므로
등급계수는 받고, 레벨계수는 안 받는다.

이 저장소의 구현은 `godot/core/hero_stats.gd` 의 `GRADE_AXES` · `LEVEL_AXES` 두 상수다.
순수도(05 §7-1)는 이 둘 뒤에 **전 축** 최종 배율로 곱한다 — 이건 GDD가 명시한다.

## 결과

**얻은 것**
- 필드스탯 경로가 원본과 같은 값을 낸다. MANA 가 등급계수를 못 받던 어긋남이 사라졌다.
- GDD에 없던 구분이 ADR로 남아, 다음 사람이 코드를 역추측하지 않아도 된다.

**잃은 것 / 남은 것**
- GDD 05 §7 표는 MANA 행에 "등급계수 미적용"이라고 적혀 있어 같은 문서의 7종 목록과 어긋난다
  (`docs/gdd/` 는 원본 문면이라 고치지 않는다). 코드는 **7종 목록과 원본 구현**을 따른다.
- 레벨계수의 축별 예외는 여전히 원본 저장소 GDD에 없다. 원본에 개정 요청을 올릴 항목이다.
- 원본 웹 버전(`fons-web-ver/app/src/summon.ts`)은 레벨 축 자체가 없고 등급계수만 건다 —
  레벨계수는 Unity 경로에만 있다. 두 구현이 다른 것은 원본의 미구현 차이다.
