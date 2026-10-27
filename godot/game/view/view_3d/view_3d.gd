class_name FonsView3D
extends FonsView
## 3D 뷰 골격 — 같은 심 스냅샷을 3D 월드에 놓는다.
##
## 2D 뷰와 계약이 같다: `mount`/`apply`/`unmount` 로 스냅샷을 받고, 입력은 `intent` 로만 되돌린다.
## 심은 `Vector3`(x, y=높이, z) 로 말하므로 여기서는 **축을 접지 않고 그대로** 쓴다.
## 2D 가 `FonsProjection` 으로 접는 것과 달리 3D 는 y 를 높이로 쓴다 — 필드 스냅샷의 y 는 0 이다.
##
## 에셋은 문자열 키(R3)다 — `hero:knight` 같은 키에 `Mesh` 또는 `PackedScene` 을 걸면 그것을 쓰고,
## 안 걸린 키는 종류별 기본 도형으로 폴백한다. `.glb` 는 `PackedScene` 으로 임포트되므로 씬도 받는다.
## 그래서 자산이 들어오면 `register_asset` 만 호출하면 되고, 심·조립 루트는 안 건드린다.
##
## HP 바는 화면 픽셀에 그린다(`FonsHpBar`) — 머리 위 월드 지점을 카메라로 투영해서, 2D 와 같은 두께·색이 된다.
##
## 화면 구성
##   · 지면(PlaneMesh) + 방향광 + 환경광 — 필드 크기만큼 깔리고, 색은 바이옴 파생값(`palette`)이다
##   · 폴백 도형 — 조우 = 원기둥, 조종 영웅 = 캡슐, 동료 = 상자, 몬스터 = 원뿔
##   · 오른쪽 파티 칸은 `FonsPartyPanel`, HP 바는 `FonsHpBar` — 2D 와 같은 그림

const FIELD_BG := Color(0.04, 0.05, 0.07, 1.0)
const GROUND := Color(0.10, 0.12, 0.15, 1.0)
const HERO_COLOR := Color(0.35, 0.75, 1.0, 1.0)
const AVATAR_COLOR := Color(0.40, 0.90, 0.55, 1.0)
const SITE_COLOR := Color(0.95, 0.72, 0.28, 1.0)
## 2D 의 `KIND_COLORS["monster"]` 와 같은 색 — 두 뷰가 같은 적을 같은 색으로 부른다.
const MONSTER_COLOR := Color(1.0, 0.35, 0.35, 1.0)
const SITE_CLEARED := Color(0.32, 0.34, 0.36, 1.0)
const DEAD_FADE := 0.45

const SITE_HEIGHT := 1.0
const HERO_SIZE := 0.7
const AVATAR_RADIUS := 0.38
const MONSTER_HEIGHT := 0.9
## 조우 종류 이름 — `kind` 가 이것이면 원기둥 기둥으로 그린다.
const KIND_SITE := "site"
const KIND_AVATAR := "avatar"
const KIND_MONSTER := "monster"
const KIND_HERO := "hero"
## 키트 `.glb` 경로 규칙 — 키트 id 가 파일명이다. `art-source/export/<kit>.py` 가 뽑는다.
const KIT_DIR := "res://assets/art/models/%s.glb"
## 지형 알베도 배율 — 식생 틴트를 그대로 쓰면 조명을 얹고 파스텔이 된다.
const TERRAIN_ALBEDO_GAIN := 0.78
## 바이옴을 모르는 화면의 채움광 — 예전 상수 그대로다. 필드는 `palette.fill` 이 덮는다.
const AMBIENT_ENERGY := 0.9

## ── 카메라 구도 — 3인칭 추적 ──────────────────────
## 정본이 된 구도는 "캐릭터 뒤의 낮은 원근 카메라"다 (원신·엔드필드가 쓰는 부류).
## 두 게임 다 FOV·거리·기울기 수치를 공개하지 않는다 — 아래 값은 우리 월드 스케일에서
## [ART_BIBLE](../../docs/art/ART_BIBLE.md) 이 정한 **구도 목표**를 맞추려고 고른 값이다.
## 1 유닛 키의 캐릭터가 화면 세로의 약 1/4 을 차지하고, 시선 높이가 캐릭터 머리보다 살짝 위다.
const CAMERA_FOV := 50.0
## 내려다보는 기본 기울기. 0°(수평)에 가까우면 지면이 안 보이고, 40° 를 넘으면 다시 탑뷰가 된다.
const CAMERA_PITCH_DEFAULT := 18.0
const CAMERA_PITCH_MIN := 6.0
const CAMERA_PITCH_MAX := 42.0
## 캐릭터 1 유닛 키 기준. `2 × d × tan(FOV/2)` 가 세로 화면 높이이므로 4.6 이면 캐릭터가 약 24%.
const CAMERA_DISTANCE := 4.2
## 최소는 캐릭터 어깨 바로 뒤, 최대는 필드 28유닛을 한 화면에 담는 거리.
const CAMERA_DISTANCE_MIN := 2.8
const CAMERA_DISTANCE_MAX := 30.0
const CAMERA_ZOOM_STEP := 1.15
## 카메라가 보는 기준점 — 캐릭터 가슴 높이.
const CAMERA_FOCUS_HEIGHT := 0.62
## 시선을 이만큼 더 올리면 캐릭터가 화면 아래 3분의 1로 내려간다.
const CAMERA_AIM_LIFT := 0.75
## 추적 지연. 0 이면 카메라가 딱 붙어 사람이 아닌 것처럼 보이고, 크면 발밑이 늦게 온다.
const CAMERA_FOLLOW := 9.0
## 이보다 멀리 순간이동하면(조종 전환·층 이동) 미끄러지지 않고 그 자리로 붙는다.
const CAMERA_SNAP_DISTANCE := 12.0
## 카메라가 능선에 파묻히지 않게 두는 지면 여유.
const CAMERA_GROUND_CLEAR := 0.5
## 붐 길이 스무딩 — 나무에 가리면 목표 거리가 프레임마다 튄다. 값을 그대로 쓰면
## 카메라가 툭툭 당겨지고 풀려 "끊긴" 것으로 읽힌다 (2026-10-25 피드백).
## 당길 때는 빠르게(0.04초), 풀릴 때는 느리게(0.30초): 늦게 당기면 나무를 통과하고,
## 늦게 풀면 나무 앞에 붙어 있는 채로 남는다. 지수 스무딩이라 끝에서 떨리지 않는다.
const CAMERA_BOOM_PULL_TIME := 0.04
const CAMERA_BOOM_PUSH_TIME := 0.30
## 나무·큰 바위 원통 앞에서 붐을 끊을 때 남기는 여유 — 표면에 딱 붙으면 화면이 덜컥거린다.
const CAMERA_COLLISION_PAD := 0.35
## 가림 판정의 **가장자리 완중폭**. 광선이 원통을 스치기 시작하는 순간 교점 거리가
## 무한대에서 가까운 값으로 튄다 — 실측 한 프레임 2.34유닛(2026-10-25). 그대로 쓰면
## 카메라가 툭 당겨지고, 시간 스무딩만 걸면 반대로 캐노피를 1.5유닛 파고든다.
## 그래서 축에서 이만큼 비겨 있을 때부터 가중치를 0→1 로 올려 붐을 부드럽게 섞는다.
##
## 값 0.4 는 **실제 필드 blocker 로 잰 창 비율**로 정했다 (2026-10-25 실측, 0.5° 스텝):
## 0.8 이면 줄기(반경 0.22) 하나가 시점 **39.5°** 를 도는 동안 카메라를 당긴다 — 줄기 각폭
## 8.4° 의 4.7배다. 얇은 나무를 스쳐 지나가는데 카메라가 40° 동안 숙였다 피는 것이다.
## 0.4 면 같은 줄기가 **23.5°(2.8배)**, 캐노피(반경 1.81, 42° 시점)가 **32°(51° → 32°)** 로
## 줄고 프레임당 붐 변화는 0.12유닛(0.5° 당) — 튀지 않는다. 캐릭터가 가려진 프레임은 두 값
## 모두 0 이라 더 일찍 당길 이유가 없었다. (원래 0.8 은 캐노피 반경 1.81 을 기준으로 고른 값이다.)
const CAMERA_COLLISION_SOFT := 0.4
## 붐이 이보다 짧아지면 조종 영웅을 흐린다 — 카메라가 등에 붙으면 초록 덩어리가 화면을 덮는다.
## 원신도 벽에 붙으면 같은 방식으로 쓴다. 가까울수록 투명, 멀어지면 원래대로.
## NEAR 아래로는 완전히 가린다 — 카메라가 몸 안에 들어간 상태다.
const CAMERA_AVATAR_FADE_FAR := 2.4
const CAMERA_AVATAR_FADE_NEAR := 1.1
## ── 벽 앞 스윙 (2026-10-28) ──────────────────────────────────────
## 붐이 영웅 몸속까지 접히는 자리(`CAMERA_AVATAR_FADE_NEAR` 아래 — 영웅이 화면에서 완전히
## 사라진다)에서는 접는 대신 **옆으로 돌아** 뚫린 각도를 찾는다. 벽(탑·큰 바위)을 등지고
## 시점을 벽 쪽으로 돌리면 화면이 벽과 파티 몸통으로 꽉 찼다 — 탑 벽 앞 2.6 에서 실측 붐 0.68.
##
## 작은 프롭은 그대로 접는다 — 나무 하나가 붐을 1.9 로 당기는 정도면 영웅이 반투명하게 남아
## 화면이 쓸 만하고(2026-10-25 손맛), 스윙은 돌릴 이유가 없는 자리에서 시점을 흔든다.
## 그래서 문턱을 `CAMERA_AVATAR_FADE_NEAR`(= 영웅이 완전히 사라지는 붐)로 잡았다.
## 돌 자리를 고를 때의 목표는 `CAMERA_AVATAR_FADE_FAR` — 흐려지지 않을 만큼 뚫린 첫 각도다.
##
## 옆으로 돌 때 훑는 각도 간격과 상한(도). 간격을 좁히면 고른 값이 미세하게 흔들리고,
## 넓히면 뚫린 각을 놓친다. 120° 를 넘겨 돌면 시점이 뒤집힌다 — 그 뒤로는 그냥 접는다.
const CAMERA_SWING_STEP := 20.0
const CAMERA_SWING_MAX := 120.0
## 스윙 각도의 지수 스무딩 — 붐(당김 0.04 · 풀림 0.30)과 같은 이유로 시간을 준다.
## 각도가 한 프레임에 꽂히면 시점이 튄다. 들이는 0.20초 · 빼는 0.70초:
## 벽에 붙는 순간은 빨리 피해야 하고, 벽을 벗어날 때 빠르면 그게 다시 끊김으로 읽힌다.
## 들이 0.20 은 **창 모드 실주행**으로 골랐다(2026-10-28): 스윙이 도는 동안 카메라가 벽 쪽으로
## 남아 영웅이 사라진 시간이 0.30초일 때보다 짧다. 60fps 타임스텝 실측(`--fixed-fps 60`):
## 카메라 방향 최대 **7.0°/프레임 ≈ 420°/s**(손목 휙 입력 360°/s) · 영웅이 사라진 시간
## **0.25초**(666프레임 중 15) · 프레임당 붐 변화 최대 0.637유닛. 붐에 하한을 두지 않는 이유는
## 아래 문턱 설명과 같다 — 문턱(1.10)에 맞춰 두면 투명도 4% 라 화면이 그대로고,
## 더 크게 두면 카메라가 벽 안으로 들어간다(2026-10-28 이 고친 결함).
const CAMERA_SWING_TIME_IN := 0.20
const CAMERA_SWING_TIME_OUT := 0.70
## 점프 — 높이 v²/2g = 0.63유닛. 캐릭터(1유닛)의 절반 남짓이라 발이 땅에서 보인다.
## 지금은 **연출**이다. 심은 평면이라 장애물을 넘거나 높이를 타지 않는다.
const JUMP_SPEED := 4.2
const JUMP_GRAVITY := 14.0
## 타격 한 번의 카메라 흔들림 — 짧게(0.18초) 꺾이고 빠르게 잦아든다.
## 진폭은 피해에 안 비례한다. 실제 교전 피해는 1,000 단위(실측 1,200)라
## 60 을 기준으로 나누면 모든 판이 최대치로 붙는다 — 숫자를 쓰지 않고 고정한다.
const CAMERA_SHAKE_TIME := 0.18
## 2026-10-25 상향 — 0.16 은 화면에서 "흔들렸나?" 싶은 정도라 한 방의 무게가 안 실렸다.
## 실측(실제 창 1280×720 첫 프레임): 카메라가 0.178유닛 밀리고 0.72° 기울었다.
## 지금은 0.26유닛 — 가림 여유(0.35)보다 작아 흔들려도 나무를 안 뚫는다(남는 여유 0.09).
const CAMERA_SHAKE_STRENGTH := 0.26
## 회전 흔들림 — 위치만 옴리면 화면이 미끄러지는 것으로 읽히고, 짧은 기울기(롤)가
## 한 방의 무게를 만든다. 2026-10-25: 롤 1.1° → 2.2° · 피치 0.45° → 0.86°.
## 위치와 같은 제곱 감쇠를 쓰므로 둘이 같이 0 으로 돌아온다.
## 5° 를 넘기면 3인칭 멀미가 난다 — 상한으로 쓸 것.
const CAMERA_SHAKE_ROLL := 0.038
const CAMERA_SHAKE_PITCH := 0.015
## 강한 일격(치명타) 배율 — 심이 `strike.heavy` 로 알려 준다. 피해 숫자로 나누지 않는 이유는
## 실측 피해가 1,000 단위라 문턱값을 박으면 모든 판이 한 쪽에 붙기 때문이다(battle.strike).
## 위치는 **가림 여유(0.35유닛)를 넘지 않는 선**에서만 키웠다: 0.26 → 0.338. 더 키우면
## 나무에 붙은 카메라가 흔들리는 동안 줄기를 뚫는다 (`_soft_clamp` 의 pad 와 같은 수치).
const CAMERA_SHAKE_HEAVY_POS := 1.30
## 회전은 따로 더 벌린다 — 2.2° → 3.7°. 위치가 여유에 막혀서 무게 차이는 기울기가 진다.
## 두 배율 모두 5° 상한 안이다 (3인칭 멀미 경계).
const CAMERA_SHAKE_HEAVY_ROT := 1.70
## 탑 높이 — 심은 자리·반경만 준다. 높이는 뷰가 정한다. 캐릭터(1유닛)의 7배 남짓이면
## 걸어가며 지평선 위로 솟아 랜드마크로 읽힌다.
const TOWER_HEIGHT := 7.5
const TOWER_CROWN := 1.8
## 탑 가림 원통의 반경 = 몸통 × 이 값. 덮개가 몸통의 1.3배라 그 위까지 덮는다.
## 카메라 붐은 이 원통의 표면 0.35 앞에서 끊긴다 — 그래서 **플레이어가 서서 카메라를 탑
## 쪽으로 돌릴 자리는 이 반경 + 카메라 기본 거리 밖**이어야 붐이 안 접힌다 (`FonsExplore.SPAWN`).
const TOWER_BLOCKER_SCALE := 1.35
## 마우스 감도 (라디안/픽셀, 약 0.2°/px).
const CAMERA_SENSITIVITY := 0.0035
## 전투·헤드리스처럼 필드가 아닌 화면의 폴백 — 예전 정사영 탑뷰를 그대로 둔다.
const STATIC_PITCH := 60.0
const STATIC_HEIGHT := 34.0

## ── 하늘·원경 ──────────────────────────────────────
## 3인칭 카메라가 지평선을 보여 준다. 배경을 단색으로 두면 땅이 어두운 허공에 뜬
## 초록 판으로 읽힌다 (2026-10-25 렌더) — 하늘은 그라데이, 먼 땅은 같은 색으로 잠긴다.
##
## 새 색을 만들지 않는다. 천정은 심이 준 `sky`, 지평선은 그 sky 의 **색상각을 지킨 채**
## 채도를 낮추고 명도를 올린 헤이즈다 — 공기 원근은 먼 공기가 밝아지며 색이 빠지는 현상이다.
## 태양광 쪽으로 그냥 섞으면 파란 하늘과 회색 태양빛이 만나 회색 안개가 된다(2026-10-25 렌더).
## 두 값 모두 팔레트에서 파생하므로 26바이옴이 같은 규칙으로 갈라진다.
const SKY_HAZE_MIX := 0.62
## 헤이즈가 남기는 채도 — 0 이면 회색 안개, 1 이면 천정색 그대로다.
const SKY_HAZE_SATURATION := 0.55
## 지평선 아래 색은 지평선보다 어둡게 — 밝은 띠가 땅 밑에 남으면 땅이 떠 보인다.
const SKY_GROUND_DARKEN := 0.30
## 안개는 **거리**로만 건다(깊이 안개). 카메라는 지형에 콜라이더가 없어서
## 높이 안개를 걸면 계곡 바닥이 뿌옇게 뜬다.
##
## 무한맵 — 안개의 끝은 **지형 끝보다 가까워야** 한다. 그런데 그 끝은 손으로 고른 수가
## 아니라 반경이 정한다: 지형은 아바타 청크 바깥으로 `VISUAL_RADIUS` 청크를 더 깔고, 아바타가
## 자기 청크 끝에 붙어 서 있어도 청크 폭만큼은 남는다 — 가장 가까운 끝이 **R 청크**다
## (7×7 에서 3 × 28 = 84). T3 의 72 는 이 안에 들어왔지만 손으로 고른 수라서 반경이나
## 청크 크기를 바꾸면 같이 안 움직인다 — 그래서 `fog_span()` 이 뽑는다.
## 남기는 여유(`FOG_EDGE_MARGIN`)는 지평선 쪽 시선 각도와 붐 이동을 먹는 몫이다.
const FOG_EDGE_MARGIN := 12.0
## 안개 시작은 끝의 이 비율 — 어느 바이옴이든 같은 결의 그라데이를 쓴다.
## 0.55 였을 때는 40~70 거리의 프롭이 30~60% 만 젖어, 지평선을 넘어 하늘 위로 솟는
## 것들이 하늘보다 밝은 옅은 판으로 남았다 (2026-10-26 렌더). 0.42(시작 30)로 당긴 뒤에도
## 45~55 거리 프롭이 35~59% 만 젖은 채 지평선 위에 남았다 (2026-10-26 4방향 검수) —
## 그 대역이 62% 이상 젖도록 0.30(시작 21.6)으로 내린다. 0 이 아닌 이유는 가까운 필드가
## 투명해야 프롭의 색과 입체가 읽히기 때문이고, 35 거리에서 27% 로 남겨 둔다.
const FOG_BEGIN_RATIO := 0.30
## 안개가 짙어지는 **곡선**. Godot 깊이 안개는 `smoothstep(시작, 끝, 거리)` 에 이 값을
## 거듭제곱한다 (2026-10-27 흰 판 실측 — curve 2 에서 35 거리 2.6% = 16.4%², 60 거리
## 72.8% = 85.5%²). 1.0 이면 45 거리에서 이미 44% 젖어 중경 채도가 절반 날아간다 —
## 시작을 당긴 대가가 중경에 몰린다. 1.4 는 35 거리 8.0% · 45 거리 31.7% 로 중경을
## 되살리면서, 0.30 을 고른 두 하한(55 거리 62%, 컬링 60 거리 71%)을 64.1% · 80.3% 로
## 지킨다. 1.5 는 55 가 62.1% 로 하한에 붙고 1.8 은 56.5% 로 떨어진다 — 여기가 상한이다.
const FOG_DEPTH_CURVE := 1.4
## 안개 끝의 바닥 — 지형이 아주 좁을 때 0 으로 무너지지 않게.
const FOG_MIN_END := 24.0
## 한 청크짜리 **예전 필드**(스트리밍 없는 폴백·전투 화면)의 값. 그 필드는 여백까지 뜬
## 한 장이라 끝이 원래 화면에 남는다 — 여기서 맞출 수 있는 수가 아니다.
const FOG_SINGLE_BEGIN := 38.0
const FOG_SINGLE_END := 72.0
## 안개가 하늘까지 덮으면 그라데이가 사라지고 하늘이 한 색 판이 된다.
## 땅만 잠기게 두고 하늘은 팔레트가 정한 그라데이를 지킨다.
const FOG_SKY_AFFECT := 0.45
## 프롭을 끄는 자리는 안개 span 의 **비율**이다. 100%(끝)까지 기다리면 지평선 위에 옅은
## 실루엣으로 뜨고(2026-10-26 4방향 검수), 고정 거리(12)로 끊으면 span 이 짧은 짙은 안개
## 바이옴에서 상대적으로 더 이르게 잡혀 60% 만 젖은 자리에서 사라진다 (2026-10-27 측정:
## 배율 1.45 72.5%, 동굴 1.8125 60.2% — 곡선 1.4 에서 63.7% · 49.1%). 0.762 는 기준
## 바이옴에서 예전 12 유닛과 같은 자리(60/72)이고, 배율이 어떻든 같은 만큼(79%) 젖는다.
const KIT_CULL_RATIO := 0.762

## 동료 색은 에셋 키가 정한다 — 키가 다르면 색이 다르다. 다섯이 같은 상자·같은 파랑이면
## 누가 누군지 모른다. 색역은 청록~자홍 사이만 쓴다 (빨강·주황은 몬스터·조우 몫, 초록은 조종 표시 몫).
##
## 색은 **한 판의 영웅들 사이에서 나눈다**. 키 해시로 색을 뽑으면 두 키가 같은 색에 떨어져서
## 실제로 두 쌍이 구분되지 않았다 — 그래서 키를 정렬해 색역을 고르게 쪼갠다.
const HERO_HUE_FROM := 0.45
const HERO_HUE_TO := 0.90
const HERO_SATURATION := 0.55

## HP 바는 2D 와 같은 그림을 쓴다 (엔티티 크기를 픽셀 폭으로 옮기는 배율만 여기서 정한다).
const BAR_PIXELS_PER_UNIT := 42.0
const BAR_MIN_WIDTH := 18.0
const BAR_MAX_WIDTH := 46.0


class PanelCanvas extends Node2D:
	var view_ref: Node = null

	func _draw() -> void:
		if view_ref != null and view_ref.has_method("draw_party_panel"):
			view_ref.draw_party_panel(self)


class BarCanvas extends Node2D:
	var view_ref: Node = null

	func _draw() -> void:
		if view_ref != null and view_ref.has_method("draw_bars"):
			view_ref.draw_bars(self)


var _world: Node3D = null
var _entities_root: Node3D = null
## 타격 연출이 사는 자리 — 엔티티와 분리해 둔다 (교전 때만 잠깐 붙었다 사라진다).
var _strike_root: Node3D = null
## 마지막으로 그린 교전 번호 — 같은 seq 를 다시 받아도 두 번 그리지 않는다.
var _strike_seq := 0
var _camera: Camera3D = null
var _ground: MeshInstance3D = null
var _light: DirectionalLight3D = null
## 후보 C(툰)의 조명 모델 — 견본대가 고른 값을 그대로 쓴다(docs/art/셰이딩_조각수_선택지.md §3.9).
## `unshaded` 라 **그림자를 안 받는다** — 지금 조명은 그림자를 안 켜고 있어 잃는 것이 없다.
var _toon := FonsToonShade.new()
var _environment: Environment = null
## 필드 하늘 — 천정·지평선 색을 팔레트에서 받는다. 필드가 아닌 화면은 단색 배경이다.
var _sky_material: ProceduralSkyMaterial = null
## 지형 — 필드 한 장을 뜬 높이필드. 바이옴·필드가 바뀔 때만 다시 뜬다.
var _terrain: FonsTerrain = null
var _terrain_key := ""
## 활성 청크 — 심이 보낸 남서 모서리들과, 그 청크에 뚫은 메시·키트.
## 청크 스트리밍의 단위다: 목록에 없으면 버리고, 새 좌표면 뜬다.
var _chunks: Array = []
## 스냅샷이 청크 목록을 줬나. 안 줘으면 "한 청크 = 예전 필드"로 보고 여백까지 뜬다 (테스트·전투 화면).
var _chunks_from_snapshot := false
## 심의 조우 반경(`FonsExplore.ACTIVE_RADIUS` = 1)에서 몇 겹 더 깔까. 이 여유가 없으면
## 조우가 지형 밖 허공에 선다. 2 겹이면 7×7 = 49청크, 가장 가까운 끝이 84유닛이다.
const VISUAL_MARGIN_RINGS := 2
## 지형·프롭 반경 — 심의 활성 반경과 **같은 수**에서 출발한다. 심이 반경을 키우면 지형도
## 같이 넓어지고, 안개는 그 반경에서 끝을 뽑으므로(`fog_span_for`) 셋이 따로 놀지 않는다.
## 조우는 여기 안 늘어난다 (심의 목록 그대로 27곳).
const VISUAL_RADIUS := FonsExplore.ACTIVE_RADIUS + VISUAL_MARGIN_RINGS
## 한 apply 에 새로 뜨는 청크 수. 13청크를 한 번에 뜨면 청크를 넘을 때마다 0.5초 멈춘다
## (2026-10-26 실측 514~570ms). 새 청크는 늘 안개 너머 바깥 고리라 한두 프레임 늦게 떠도 안 보인다.
const CHUNK_BUILD_BUDGET := 1
var _chunk_root: Node3D = null
var _chunk_meshes: Dictionary = {}
var _chunk_mesh_key: Dictionary = {}
var _chunk_kits: Dictionary = {}
var _chunk_kit_key: Dictionary = {}
var _chunk_kit_counts: Dictionary = {}
var _chunk_blockers: Dictionary = {}
var _terrain_base := GROUND
var _panel_canvas: PanelCanvas = null
var _bar_canvas: BarCanvas = null
var _nodes: Dictionary = {}
var _positions: Dictionary = {}
var _visuals: Dictionary = {}
var _lifts: Dictionary = {}
var _entities: Dictionary = {}
var _materials: Dictionary = {}
## 이번 스냅샷의 조우 자리 — 지형을 평탄하게 누를 지점이다.
var _flats: Array = []
## 에셋 키(`hero:knight`) → `Mesh` 또는 `PackedScene`. 없으면 종류별 도형으로 폴백한다.
var asset_resources: Dictionary = {}
## 에셋 키 → 이번 스냅샷에서 나눠 준 색. `apply` 마다 다시 계산한다.
var asset_colors: Dictionary = {}
var _party: Array = []
var _field := Vector2.ZERO
var _is_field := false
## 이번 스냅샷이 말한 세계 — 뷰는 판정하지 않고 받아 적기만 한다.
var _biome := ""
var _kit := ""
var _palette: Dictionary = {}
var _floor := 1
var _kit_root: Node3D = null
## 탑·소환진 — 층 중심 랜드마크. 심이 자리·반경만 주고 메시는 여기서 세운다.
var _tower_root: Node3D = null
var _tower_mark: Dictionary = {}
var _tower_key := ""
var _tower_blocker: Dictionary = {}
var _kit_built := ""
var _kit_count := 0
## 지금 깔린 키트에 곱해진 역할별 색 — 바이옴이 바뀌면 키트를 다시 깐다
## (색이 메시에 곱해져 있으므로). `_kit_key` 는 그 값을 비교 가능한 문자열로 줄인 것이다.
var _kit_tints: Dictionary = {}
var _kit_key := ""
## 이번 키트가 놓은 키 큰 프롭 — 카메라 붐이 못 지나가는 원통(자리·반경·높이).
## 물리 콜라이더는 없다. 키트가 배치하면서 같이 알려 준다.
var _blockers: Array = []
## 조종 영웅의 현재 흐림(0 = 불투명). 카메라 붐이 짧아질 때만 오른다.
var _avatar_fade := 0.0
## 남은 흔들림 시간. 교전(`strike.seq`)이 늘어난 순간에만 새로 채운다.
var _shake_left := 0.0
## 지금 흔들림이 강한 일격인가 — 감쇠 시작 시점에 정해지고 끝까지 유지된다.
var _shake_heavy := false
var _shake_rng := RandomNumberGenerator.new()
## 점프 높이·속도 — 심이 아니라 아바타 그림만 움직인다.
var _jump_y := 0.0
var _jump_vy := 0.0
## 마우스 캡처 의도 — 필드에서는 커서를 숨기고 마우스는 시점만 돌린다.
## Esc 로 풀고, 필드에서 클릭하면 다시 잡는다. 헤드리스(테스트·스크린샷)는 안 잡는다.
var _capture_wanted := false
## 이 뷰가 아는 키트 씬 — 테스트가 가짜 씬을 넣는다 (파일이 없는 키트도 배선 확인 가능).
var kit_scenes: Dictionary = {}
var _last_dir := Vector2.ZERO
## 3인칭 카메라 상태 — 수평 회전(yaw), 내려다보는 각(pitch), 거리.
## 값은 여기 있고 위치는 매 프레임 `_place_camera` 가 다시 낸다.
var _yaw := 0.0
var _pitch := deg_to_rad(CAMERA_PITCH_DEFAULT)
var _distance := CAMERA_DISTANCE
var _focus := Vector3.ZERO
var _focus_ready := false
## 마우스 없이도 시점을 돌릴 수 있게 둔 키 회전(Q/E).
const CAMERA_KEY_TURN := 1.8
## 지금 프레임에 쓰는 붐 길이 — 가림 때문에 목표보다 뒤처질 수 있다 (`_smooth_boom`).
var _boom := CAMERA_DISTANCE
var _boom_ready := false
## 지금 프레임에 시점이 벽을 피해 돌아 있는 각(라디안) — 목표는 `_swing_target` 이 고른다.
var _swing := 0.0
var _swing_ready := false
var _last_yaw := 0.0


func _ready() -> void:
	_ensure_world()
	_ensure_panel()


func mount(snapshot: Dictionary) -> void:
	_ensure_world()
	_ensure_panel()
	apply(snapshot)
	_mounted = true
	# 필드에 들어오면 커서를 숨긴다 — 서브컬쳐 3인칭 게임의 기본 조작.
	set_mouse_capture(_is_field)


func apply(snapshot: Dictionary) -> void:
	_party = snapshot.get("party", [])
	_floor = int(snapshot.get("floor", 1))
	_biome = String(snapshot.get("biome", ""))
	_kit = String(snapshot.get("kit", ""))
	_palette = snapshot.get("palette", {})
	_field = snapshot.get("field", Vector2.ZERO)
	_is_field = String(snapshot.get("mode", "")) == "field" and _field.x > 0.0 and _field.y > 0.0
	var chunks: Variant = snapshot.get("chunks", [])
	var streamed := chunks is Array and not (chunks as Array).is_empty()
	_chunks_from_snapshot = streamed and _is_field
	if not _is_field:
		_chunks = []
	elif streamed:
		_chunks = _visual_chunks(chunks)
	else:
		_chunks = [Vector3.ZERO]
	# 필드가 아닐 때는 캐릭터를 흐리거나 흔들 이유가 없다 — 전투 화면에 남지 않게.
	if not _is_field:
		_avatar_fade = 0.0
		_shake_left = 0.0
		_jump_y = 0.0
		_jump_vy = 0.0
		set_mouse_capture(false)
	# 탑은 지형 평탄화보다 먼저 읽어야 한다 — 소환진 자리가 평평해지지 않으면 원판이 띨 수 있다.
	var tower: Variant = snapshot.get("tower", {})
	_tower_mark = tower if tower is Dictionary and _is_field else {}
	var entities: Array = snapshot.get("entities", [])
	_update_colors(entities)
	_update_flats(entities)
	# 지형을 먼저 뜬다 — 유닛·프롭 높이가 그 위에 얹힌다.
	_apply_palette()
	_sync_entities(entities)
	_sync_kit(entities)
	# 키트를 깐 **뒤에** 탑을 세운다 — 키트가 `_blockers` 를 비우므로 순서가 반대면 탑 가림이 산다.
	_sync_tower()
	_play_strike(snapshot.get("strike", {}))
	if _is_field:
		_update_camera(0.0)
	else:
		_set_static_camera()
	if _bar_canvas != null:
		_bar_canvas.queue_redraw()
	if _panel_canvas != null:
		_panel_canvas.queue_redraw()


func unmount() -> void:
	set_mouse_capture(false)
	for id in _nodes:
		_nodes[id].queue_free()
	_nodes.clear()
	asset_colors.clear()
	_positions.clear()
	_visuals.clear()
	_lifts.clear()
	_entities.clear()
	_party = []
	_field = Vector2.ZERO
	_flats = []
	_is_field = false
	_biome = ""
	_kit = ""
	_palette = {}
	_chunks = []
	_floor = 1
	_strike_seq = 0
	_yaw = 0.0
	_pitch = deg_to_rad(CAMERA_PITCH_DEFAULT)
	_distance = CAMERA_DISTANCE
	_focus_ready = false
	_boom = CAMERA_DISTANCE
	_boom_ready = false
	_swing = 0.0
	_swing_ready = false
	_clear_kit()
	_clear_tower()
	_clear_terrain()
	_clear_strikes()
	_mounted = false
	if _bar_canvas != null:
		_bar_canvas.queue_redraw()
	if _panel_canvas != null:
		_panel_canvas.queue_redraw()


func entity_count() -> int:
	return _nodes.size()


func strike_fx_count() -> int:
	## 지금 살아 있는 타격 연출 수 — 보통 0 이고, 교전 직후 0.55초 동안만 1 이상이다.
	return 0 if _strike_root == null else _strike_root.get_child_count()


func has_entity(id: String) -> bool:
	return _nodes.has(id)


func entity_position(id: String) -> Vector3:
	return _positions.get(id, Vector3.ZERO)


func entity_mesh(id: String) -> Mesh:
	var visual: MeshInstance3D = _visuals.get(id, null)
	return null if visual == null else visual.mesh


func entity_color(id: String) -> Color:
	## 지금 화면에 칠해진 색 — 죽은 동료는 어둡게 깎인 값이다.
	var visual: MeshInstance3D = _visuals.get(id, null)
	if visual == null or visual.material_override == null:
		return Color(0.0, 0.0, 0.0, 0.0)
	return (visual.material_override as StandardMaterial3D).albedo_color


func entity_asset_node(id: String) -> Node:
	## `PackedScene` 자산이면 엔티티 아래에 붙은 그 씬을 돌려준다 (메시 자산이면 null).
	var node: Node3D = _nodes.get(id, null)
	return null if node == null else node.get_node_or_null("Asset")


func current_biome() -> String:
	return _biome


func current_kit() -> String:
	return _kit


func ground_color() -> Color:
	## 지형은 정점색으로 칠한다 — 재질 알베도는 흰색이므로 기준색을 따로 들고 있는다.
	if _terrain != null:
		return _terrain_base
	if _ground == null:
		return GROUND
	var material := _ground.material_override as StandardMaterial3D
	return GROUND if material == null else material.albedo_color


func sky_color() -> Color:
	return FIELD_BG if _environment == null else _environment.background_color


func light_color() -> Color:
	return Color.WHITE if _light == null else _light.light_color


func light_energy() -> float:
	return 0.0 if _light == null else _light.light_energy


func is_field() -> bool:
	return _is_field


## HP 바를 그릴 엔티티 id — 조우·조종 영웅은 2D 처럼 필드 위에 바를 달지 않는다.
func bar_entity_ids() -> Array:
	var out: Array = []
	for id in _entities:
		var entity: Dictionary = _entities[id]
		var kind := String(entity.get("kind", ""))
		if kind == KIND_SITE or kind == KIND_AVATAR:
			continue
		if FonsHpBar.has_bar(entity):
			out.append(id)
	return out


func draw_party_panel(canvas: Node2D) -> void:
	FonsPartyPanel.draw(canvas, _party, _viewport_size())


func draw_bars(canvas: Node2D) -> void:
	## 머리 위 지점을 화면 픽셀로 옮겨 `FonsHpBar` 에 넘긴다. 트리 밖(헤드리스 테스트)에서는
	## 카메라 투영을 못 하므로 조용히 건너뛴다.
	if _camera == null or not is_inside_tree():
		return
	for id in bar_entity_ids():
		var entity: Dictionary = _entities[id]
		var node: Node3D = _nodes.get(id, null)
		if node == null:
			continue
		var anchor := node.position + Vector3.UP * float(_lifts.get(id, 1.0))
		if _camera.is_position_behind(anchor):
			continue
		var screen := _camera.unproject_position(anchor)
		var width := clampf(float(entity.get("size", Vector2.ONE).x) * BAR_PIXELS_PER_UNIT,
			BAR_MIN_WIDTH, BAR_MAX_WIDTH)
		FonsHpBar.draw(canvas, FonsHpBar.top_left_above(screen, width), width, entity)


## ── 월드 ────────────────────────────────────────────────────────────────

func _ensure_world() -> void:
	if _world != null:
		return
	# 흔들림은 매 프레임 새 난수를 쓴다 — 시드를 고정해 같은 교전이면 같은 궤적으로 떨리게.
	_shake_rng.seed = 0x5348414B
	_world = Node3D.new()
	_world.name = "World"
	add_child(_world)

	var world_env := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = FIELD_BG
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.55, 0.60, 0.70)
	environment.ambient_light_energy = AMBIENT_ENERGY
	# 하늘·안개는 필드에서만 켠다 (`_apply_palette`). 여기서는 재료만 만들어 둔다.
	_sky_material = ProceduralSkyMaterial.new()
	var sky := Sky.new()
	sky.sky_material = _sky_material
	environment.sky = sky
	environment.fog_enabled = false
	environment.fog_mode = Environment.FOG_MODE_DEPTH
	# 곡선은 상수다 — 시작·끝만 지형에서 뽑는다 (`_apply_atmosphere`).
	environment.fog_depth_curve = FOG_DEPTH_CURVE
	environment.fog_sky_affect = FOG_SKY_AFFECT
	environment.fog_depth_begin = FOG_SINGLE_BEGIN
	environment.fog_depth_end = FOG_SINGLE_END
	world_env.environment = environment
	_world.add_child(world_env)
	_environment = environment

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-52.0, -35.0, 0.0)
	light.light_energy = FonsBiomePalette.DEFAULT_ENERGY
	_world.add_child(light)
	_light = light

	_ground = MeshInstance3D.new()
	_ground.name = "Ground"
	# 지형이 없을 때(전투 화면)의 바닥 — 필드가 오면 높이필드로 갈아 끼운다.
	_ground.mesh = PlaneMesh.new()
	_ground.position = Vector3(20.0, -0.02, 14.0)
	_ground.material_override = _material(GROUND)
	_world.add_child(_ground)

	_camera = Camera3D.new()
	_camera.current = true
	_world.add_child(_camera)
	_set_static_camera()

	_entities_root = Node3D.new()
	_entities_root.name = "Entities"
	_world.add_child(_entities_root)

	_strike_root = Node3D.new()
	_strike_root.name = "Strikes"
	_world.add_child(_strike_root)

	_chunk_root = Node3D.new()
	_chunk_root.name = "Chunks"
	_world.add_child(_chunk_root)


func _ensure_panel() -> void:
	if _panel_canvas != null:
		return
	var layer := CanvasLayer.new()
	layer.name = "Overlay"
	layer.layer = 1
	add_child(layer)
	# 바를 먼저 붙여 파티 칸이 위에 그려지게 한다.
	_bar_canvas = BarCanvas.new()
	_bar_canvas.name = "Bars"
	_bar_canvas.view_ref = self
	layer.add_child(_bar_canvas)
	_panel_canvas = PanelCanvas.new()
	_panel_canvas.view_ref = self
	layer.add_child(_panel_canvas)


func _set_static_camera() -> void:
	## 필드가 아닌 화면(전투·헤드리스)의 폴백 — 예전 정사영 탑뷰. 추적할 캐릭터가 없다.
	if _camera == null:
		return
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.size = 30.0
	_camera.position = Vector3(20.0, STATIC_HEIGHT, 36.0)
	_camera.rotation_degrees = Vector3(-STATIC_PITCH, 0.0, 0.0)


## ── 3인칭 추적 카메라 ──────────────────────────────────────────────

func camera_focus() -> Vector3:
	## 카메라가 보는 기준점 — 조종 영웅의 가슴 높이. 뷰에 아바타가 없으면 필드 가운데.
	var at: Vector3 = _positions.get("avatar", Vector3(_field.x * 0.5, 0.0, _field.y * 0.5))
	return Vector3(at.x, terrain_height(at.x, at.z) + CAMERA_FOCUS_HEIGHT, at.z)


func camera_pitch() -> float:
	return _pitch


func camera_yaw() -> float:
	return _yaw


func camera_distance() -> float:
	return _distance


func orbit(delta_yaw: float, delta_pitch: float) -> void:
	## 시점 회전. 마우스는 픽셀을 라디안으로 바꿔서 부른다 (테스트는 직접 라디안).
	_yaw = wrapf(_yaw + delta_yaw, -PI, PI)
	_pitch = clampf(_pitch + delta_pitch, deg_to_rad(CAMERA_PITCH_MIN), deg_to_rad(CAMERA_PITCH_MAX))


func zoom(steps: float) -> void:
	## 양수 = 가까이, 음수 = 멀리. 휠 한 칸이 1 스텝이다.
	_distance = clampf(_distance * pow(CAMERA_ZOOM_STEP, -steps),
		CAMERA_DISTANCE_MIN, CAMERA_DISTANCE_MAX)
	# 줌은 손맛이다 — 스무딩을 거치면 휠이 늦게 따라온다. 다음 프레임에 목표로 붙인다.
	_boom_ready = false


func camera_relative(dir: Vector2) -> Vector2:
	## 화면 기준 입력을 월드 평면으로 돌린다 — 3인칭 게임의 W 는 화면 위쪽이다.
	if dir == Vector2.ZERO:
		return dir
	var c := cos(_yaw)
	var s := sin(_yaw)
	return Vector2(c * dir.x + s * dir.y, -s * dir.x + c * dir.y)


func _update_camera(delta: float) -> void:
	## 기준점은 부드럽게 따라가고, 순간이동(조종 전환·층 이동)은 그 자리로 붙인다.
	if _camera == null or not _is_field:
		return
	var target := camera_focus()
	if not _focus_ready:
		_focus = target
		_focus_ready = true
	elif delta > 0.0:
		if _focus.distance_to(target) > CAMERA_SNAP_DISTANCE:
			_focus = target
			# 순간이동은 붐도 스윙도 같이 붙인다 — 안 그러면 카메라가 옛 자리(와 옛 벽)에서 미끄러져 온다.
			_boom_ready = false
			_swing_ready = false
		else:
			_focus = _focus.lerp(target, clampf(delta * CAMERA_FOLLOW, 0.0, 1.0))
	_place_camera(delta)


func camera_free_distance(from: Vector3, dir: Vector3, max_distance: float,
		blockers: Array = []) -> float:
	## 기준점에서 `dir` 쪽으로 갈 때 프롭을 뚫지 않을 수 있는 최대 거리.
	## 나무 밑에 서 있으면 그 나무는 무시한다 — 붐을 0으로 만들면 화면이 얼굴로 꽉 찬다.
	var list: Array = _blockers if blockers.is_empty() else blockers
	var limit := max_distance
	for entry in list:
		limit = minf(limit, _soft_clamp(from, dir, limit, entry))
	return maxf(0.0, limit)


static func _soft_clamp(from: Vector3, dir: Vector3, max_distance: float,
		blocker: Dictionary) -> float:
	## 원통 하나가 붐을 얼마나 막는가. **스치는 순간에도 값이 튀지 않는다**:
	## 광선이 축에서 `radius + SOFT` 안으로 들어오면 가중치가 0→1 로 올라가고,
	## 교점 거리는 그 가중치와 섞여 `max_distance` 와 연속으로 이어진다.
	var pos: Vector3 = blocker.get("pos", Vector3.ZERO)
	var radius := float(blocker.get("radius", 0.0))
	var top := float(blocker.get("top", 0.0))
	if radius <= 0.0 or top <= pos.y:
		return max_distance
	var start := Vector2(from.x - pos.x, from.z - pos.z)
	# 캐릭터가 원통 안(잎 밑·줄기 아래)에 있으면 무시한다 — 붐을 0으로 만들면 화면이 얼굴로 꽉 찬다.
	if start.length() <= radius + CAMERA_COLLISION_PAD:
		return max_distance
	var flat := Vector2(dir.x, dir.z)
	var a := flat.length_squared()
	if a <= 0.000001:
		return max_distance
	# 가장 가까운 접근의 3D 거리와 축에서 비켜난 폭.
	var along := -start.dot(flat) / a
	if along <= 0.0:
		return max_distance
	var perp := (start + flat * along).length()
	if perp >= radius + CAMERA_COLLISION_SOFT:
		return max_distance
	var hit := along
	var b := 2.0 * start.dot(flat)
	var c := start.length_squared() - radius * radius
	var disc := b * b - 4.0 * a * c
	if perp < radius and disc >= 0.0:
		var first := (-b - sqrt(disc)) / (2.0 * a)
		if first > 0.0:
			hit = first
	# 높이 밴드와의 교점도 같이 본다 — 원통은 **3D** 다. 수평 교점만 보고 높이를 나중에
	# 한 번 재면, 시점을 올렸을 때 광선이 밑동 **아래**로 수평 원을 먼저 통과하는 경우를
	# "안 막힘"으로 오판해 카메라가 잎 속에 들어간다 (2026-10-25 실측: 42° 시점).
	# 두 구간(수평 원 · 높이 밴드)이 겹치는 곳까지 붐을 늘린다.
	var band_lo := -INF
	var band_hi := INF
	if absf(dir.y) > 0.0001:
		var t0 := (pos.y - from.y) / dir.y
		var t1 := (top - from.y) / dir.y
		band_lo = minf(t0, t1)
		band_hi = maxf(t0, t1)
	elif from.y < pos.y or from.y > top:
		return max_distance
	if hit < band_lo:
		hit = band_lo
	if hit >= band_hi or hit >= max_distance:
		return max_distance
	hit = maxf(0.0, hit)
	var weight := clampf((radius + CAMERA_COLLISION_SOFT - perp) / CAMERA_COLLISION_SOFT, 0.0, 1.0)
	# 여유도 가장자리에서 0 으로 준다 — 교점이 `max_distance` 바로 앞이면 뺄 여유가 없다.
	# 고정 여유를 그대로 빼면 "안 막힘(4.2)" ↔ "막힘(3.85)" 이 프레임 사이에 0.38유닛 튄다 (실측).
	var pad := CAMERA_COLLISION_PAD * clampf((max_distance - hit) / CAMERA_COLLISION_PAD, 0.0, 1.0)
	return lerpf(max_distance, maxf(0.0, hit - pad), weight)


func _camera_dir(yaw: float) -> Vector3:
	## 시점의 단위 방향 — 기준점에서 카메라가 서는 쪽.
	var horizontal := cos(_pitch)
	return Vector3(sin(yaw) * horizontal, sin(_pitch), cos(yaw) * horizontal).normalized()


func _swing_target(free: float) -> float:
	## 붐이 영웅 몸속까지 접히는 자리에서 **옆으로 돌 각**(라디안)을 고른다.
	## 흐려지지 않을 만큼(`CAMERA_AVATAR_FADE_FAR`) 뚫린 첫 각도를 찾고, 없으면 0 — 그냥 접는다.
	if free >= CAMERA_AVATAR_FADE_NEAR:
		return 0.0
	var step := deg_to_rad(CAMERA_SWING_STEP)
	var count := int(round(CAMERA_SWING_MAX / CAMERA_SWING_STEP))
	# 지금 돌아 있는 쪽부터 본다 — 좌우가 비슷할 때 프레임마다 편이 바뀌면 시점이 흔들린다.
	var side := -1.0 if _swing < 0.0 else 1.0
	for i in range(1, count + 1):
		var away := step * float(i)
		if camera_free_distance(_focus, _camera_dir(_yaw + side * away), _distance) >= CAMERA_AVATAR_FADE_FAR:
			return side * away
	# 지금 쪽이 막혔을 때만 반대로 넘어간다 — 넘어가는 동안 카메라는 벽을 가로지르며
	# 그 사이 붐이 급히 접힌다(실측: 프레임당 0.36유닛, 옛 규칙 0.083). 그래서 좌우를
	# 번가라 보지 않고 **한쪽을 끝까지** 본다 — 뒤집힘이 사라지고 안 보는 쪽이 남는다.
	for i in range(1, count + 1):
		var away := step * float(i)
		if camera_free_distance(_focus, _camera_dir(_yaw - side * away), _distance) >= CAMERA_AVATAR_FADE_FAR:
			return -side * away
	return 0.0


func _smooth_swing(target: float, delta: float) -> float:
	## 붐과 같은 지수 스무딩 — 각도가 한 프레임에 꽂히면 시점이 튄다.
	if not _swing_ready:
		_swing = target
		_swing_ready = true
		return _swing
	if delta <= 0.0:
		return _swing
	var time := CAMERA_SWING_TIME_IN if absf(target) > absf(_swing) else CAMERA_SWING_TIME_OUT
	_swing = target if time <= 0.0 else lerpf(_swing, target, 1.0 - exp(-delta / time))
	return _swing


func _place_camera(delta: float = 0.0) -> void:
	var dir := _camera_dir(_yaw)
	var free := camera_free_distance(_focus, dir, _distance)
	# 벽이 붐을 영웅 몸속까지 접으면 접는 대신 옆으로 돈다 — 화면이 벽으로 차는 자리다.
	_swing = _smooth_swing(_swing_target(free), delta)
	if _swing != 0.0:
		dir = _camera_dir(_yaw + _swing)
		free = camera_free_distance(_focus, dir, _distance)
	# 나무·큰 바위에 파고들지 않게 붐을 앞에서 끊고, 끊긴 길이는 시간으로 늘린다.
	var boom := _smooth_boom(free, delta)
	var pos := _focus + dir * boom
	_fade_avatar(boom)
	# 타격 흔들림 — 지면 클리어런스보다 먼저 더한다. 흔들림이 카메라를 땅에 밀어 넣지 않게.
	pos += _shake_offset()
	# 능선에 파묻히지 않게 — 지형에는 콜라이더가 없어서 물리 레이캐스트를 못 쓴다.
	pos.y = maxf(pos.y, terrain_height(pos.x, pos.z) + CAMERA_GROUND_CLEAR)
	_camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	_camera.fov = CAMERA_FOV
	# `look_at` 은 트리 밖(헤드리스 테스트)에서 전역 변환을 못 읽는다 — 기저를 직접 만든다.
	# 나무 앞에서 붐이 접히면 고정 시선 높이는 위로 30° 넘게 꺾여 하늘만 보인다 —
	# 기본 거리에 못 미치는 만큼 시선 높이도 줄여 캐릭터를 프레임에 남긴다.
	var lift := CAMERA_AIM_LIFT * clampf(boom / CAMERA_DISTANCE, 0.0, 1.0)
	var aim := _focus + Vector3.UP * lift
	var basis := Basis.looking_at((aim - pos).normalized(), Vector3.UP)
	# 타격의 회전 성분은 기저 위에 얹는다 — 위치처럼 매 프레임 새로 지으므로
	# 흔들림이 끝나면 회전도 정확한 기본값으로 돌아온다 (누적되지 않는다).
	var turn := _shake_rotation()
	if turn != Vector2.ZERO:
		basis = basis.rotated(basis.x, turn.x).rotated(basis.z, turn.y)
	_camera.transform = Transform3D(basis, pos)


func _smooth_boom(target: float, delta: float) -> float:
	## 목표 붐 길이로 지수 스무딩. **첫 배치·순간이동·줌에서만** 목표로 붙는다(`_boom_ready`).
	## 시간이 안 흐른 호출(`delta <= 0` — 같은 프레임의 `apply`)은 값을 건드리지 않는다.
	## 그걸 목표로 꽂으면 스냅샷을 미는 `apply` 가 걷는 내내 매 프레임 카메라를 스냅시켜
	## 스무딩이 통째로 무너진다 (2026-10-28 실창 실측: 43ms 프레임에서 붐이 1.34 → 2.16 →
	## 3.32 → 4.20 으로 3프레임에 튐 — 스윙도 같은 자리에서 0↔80° 로 꽂혔다).
	if not _boom_ready:
		_boom = target
		_boom_ready = true
		return _boom
	if delta <= 0.0:
		return _boom
	var time := CAMERA_BOOM_PULL_TIME if target < _boom else CAMERA_BOOM_PUSH_TIME
	_boom = target if time <= 0.0 else lerpf(_boom, target, 1.0 - exp(-delta / time))
	return _boom


func camera_boom() -> float:
	## 테스트·디버그용 — 지금 프레임에 쓴 붐 길이(가림으로 접힌 값).
	return _boom


func camera_swing() -> float:
	## 테스트·디버그용 — 지금 프레임에 시점이 벽을 피해 돌아 있는 각(라디안).
	return _swing


func _shake(heavy: bool = false) -> void:
	## 교전 한 번에 붐을 짧게 흔든다. 같은 seq 를 다시 받으면 `_play_strike` 가 먼저 막는다.
	_shake_left = CAMERA_SHAKE_TIME
	_shake_heavy = heavy


func _shake_rotation() -> Vector2:
	## (피치, 롤) 라디안. 위치와 같은 감쇠 곡선을 쓴다.
	## 롤을 굴리는 이유: 화면이 기우는 것이 충격의 방향을 몸으로 느끼게 한다.
	if _shake_left <= 0.0:
		return Vector2.ZERO
	var k := _shake_left / CAMERA_SHAKE_TIME
	var amp := k * k
	var scale := CAMERA_SHAKE_HEAVY_ROT if _shake_heavy else 1.0
	return Vector2(
		_shake_rng.randf_range(-1.0, 1.0) * CAMERA_SHAKE_PITCH,
		_shake_rng.randf_range(-1.0, 1.0) * CAMERA_SHAKE_ROLL) * amp * scale


func _shake_offset() -> Vector3:
	## 잦아드는 제곱 곡선 — 시작이 가장 세고 끝에서 정확히 0 이 된다.
	## 세 축을 따로 흔들되 위아래는 덜 — 화면이 위아래로 튀면 멀미가 난다.
	if _shake_left <= 0.0:
		return Vector3.ZERO
	var k := _shake_left / CAMERA_SHAKE_TIME
	var scale := CAMERA_SHAKE_HEAVY_POS if _shake_heavy else 1.0
	var amp := CAMERA_SHAKE_STRENGTH * scale * k * k
	return Vector3(
		_shake_rng.randf_range(-1.0, 1.0),
		_shake_rng.randf_range(-0.6, 0.6),
		_shake_rng.randf_range(-1.0, 1.0)) * amp


func shake_left() -> float:
	## 테스트·디버그용 — 남은 흔들림 시간(초).
	return _shake_left


func shake_heavy() -> bool:
	## 테스트·디버그용 — 지금 흔들림이 강한 일격인가.
	return _shake_heavy


func jump() -> void:
	## 땅에 있을 때만 선다 — 공중에서 다시 누르면 무시된다.
	if not _is_field or not _nodes.has(KIND_AVATAR):
		return
	if _jump_y > 0.0 or _jump_vy != 0.0:
		return
	_jump_vy = JUMP_SPEED


func jump_height() -> float:
	## 테스트·디버그용 — 발이 땅에서 뜬 높이.
	return _jump_y


func _update_jump(delta: float) -> void:
	## 심은 평면이다 — 아바타 그림만 띄운다. 내려오면 정확히 지면 높이로 돌아간다.
	if _jump_vy == 0.0 and _jump_y <= 0.0:
		return
	_jump_vy -= JUMP_GRAVITY * delta
	_jump_y += _jump_vy * delta
	if _jump_y <= 0.0:
		_jump_y = 0.0
		_jump_vy = 0.0
	var node: Node3D = _nodes.get(KIND_AVATAR, null)
	if node != null:
		node.position.y = terrain_height(node.position.x, node.position.z) + _jump_y


func set_mouse_capture(wanted: bool) -> void:
	## 필드에서만 가둔다. 테스트·헤드리스는 의도만 남기고 실제 마우스는 건드리지 않는다.
	var target := wanted and _is_field
	if target == _capture_wanted:
		return
	_capture_wanted = target
	if DisplayServer.get_name() == "headless":
		return
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if target else Input.MOUSE_MODE_VISIBLE


func mouse_capture_wanted() -> bool:
	return _capture_wanted


func _notification(what: int) -> void:
	# 창을 잃으면 커서를 돌려준다 — 백그라운드에서 마우스가 갇히면 안 된다.
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		set_mouse_capture(false)


func _exit_tree() -> void:
	set_mouse_capture(false)


func _fade_avatar(boom: float) -> void:
	## 붐이 짧을수록 조종 영웅을 흐린다. 카메라가 등에 붙은 채 캐릭터를 그대로 두면
	## 화면이 초록 덩어리로 덮여, 나무를 피한 의미가 없다 (2026-10-25 렌더).
	var span := CAMERA_AVATAR_FADE_FAR - CAMERA_AVATAR_FADE_NEAR
	var alpha := 0.0 if span <= 0.0 else clampf(
		(CAMERA_AVATAR_FADE_FAR - boom) / span, 0.0, 1.0)
	if is_equal_approx(alpha, _avatar_fade):
		return
	_avatar_fade = alpha
	var node: Node3D = _nodes.get(KIND_AVATAR, null)
	if node == null:
		return
	# 몸통 씬이 있으면 부품마다 노드 덮개로 알파를 건다 (표면 덮개는 해제 중 엔진 오류를 낸다).
	var asset_node := node.get_node_or_null("Asset")
	if asset_node != null:
		FonsHeroBody.fade(asset_node, _avatar_fade)
		return
	var mesh := node.get_child(0) as MeshInstance3D
	if mesh != null:
		mesh.material_override = _avatar_material()


func _avatar_material() -> StandardMaterial3D:
	## `GeometryInstance3D.transparency` 는 gl_compatibility 에서 화면을 안 바꿨다 (2026-10-25 렌더).
	## 재질은 색별로 공유되므로, 아바타만 쓰는 복제본을 만들어 알베도 알파를 건다.
	if _avatar_fade <= 0.0:
		return _material(AVATAR_COLOR)
	var faded: StandardMaterial3D = _materials.get("avatar_fade", null)
	if faded == null:
		faded = _material(AVATAR_COLOR).duplicate() as StandardMaterial3D
		faded.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_materials["avatar_fade"] = faded
	var color := _material(AVATAR_COLOR).albedo_color
	color.a = 1.0 - _avatar_fade
	faded.albedo_color = color
	return faded


func avatar_transparency() -> float:
	## 테스트·디버그용 — 조종 영웅에 걸린 흐림(0 = 불투명, 1 = 안 보임).
	return _avatar_fade


func _apply_palette() -> void:
	## 지면·하늘·조명을 바이옴 파생색으로 칠한다. 팔레트가 없는 스냅샷(전투·헤드리스)은 지금 모습 그대로다.
	if _environment == null or _light == null or _ground == null:
		return
	var palette := _palette if not _palette.is_empty() else FonsBiomePalette.defaults()
	var sky := _color(palette, "sky", FonsBiomePalette.DEFAULT_SKY)
	_environment.background_color = sky
	_environment.ambient_light_color = _color(palette, "ambient", FonsBiomePalette.DEFAULT_AMBIENT)
	_environment.ambient_light_energy = float(palette.get("fill", AMBIENT_ENERGY))
	_light.light_color = _color(palette, "light", FonsBiomePalette.DEFAULT_LIGHT)
	_light.light_energy = float(palette.get("energy", FonsBiomePalette.DEFAULT_ENERGY))
	_apply_atmosphere(sky)
	_sync_terrain(_color(palette, "ground", FonsBiomePalette.DEFAULT_GROUND), palette)
	# 조명·환경광이 바뀌었으니 툰 모델도 다시 읽는다 — 안 하면 지형만 이전 바이옴 빛을 받는다.
	_toon.setup(self)


func _apply_atmosphere(sky: Color) -> void:
	## 필드만 하늘 그라데이 + 거리 안개. 전투 화면·헤드리스는 예전 단색 배경 그대로다 —
	## 그 화면들은 지평선이 없고, 하늘을 켜면 HUD 뒤 배경이 바뀐다.
	if _environment == null or _sky_material == null:
		return
	if not _is_field:
		_environment.background_mode = Environment.BG_COLOR
		_environment.fog_enabled = false
		return
	var horizon := horizon_color()
	# 팔레트 색은 sRGB 다. 하늘 재질은 그 값을 **선형광**으로 받으므로 직접 바꿔야 한다 —
	# 그냥 넣으면 화면이 밝고 창백해진다(2026-10-25 렌더: 진한 남색 하늘이 회색 안개로 나왔다).
	# 지형 정점색에서 겪은 감마 결함과 같은 종류다 (terrain.gd 의 vertex_color_is_srgb).
	var sky_linear := sky.srgb_to_linear()
	var horizon_linear := horizon.srgb_to_linear()
	_sky_material.sky_top_color = sky_linear
	_sky_material.sky_horizon_color = horizon_linear
	_sky_material.ground_horizon_color = horizon_linear
	_sky_material.ground_bottom_color = horizon_linear.darkened(SKY_GROUND_DARKEN)
	_sky_material.sky_energy_multiplier = 1.0
	_sky_material.ground_energy_multiplier = 1.0
	# 기본 0.15 는 천정색이 지평선에서 금방 사라진다 — 카메라가 보는 43° 아래 하늘이
	# 전부 헤이즈로 덮여 회색 판이 됐다(2026-10-25 렌더). 전이를 넓혀 천정색을 올려 준다.
	_sky_material.sky_curve = 0.40
	_sky_material.sun_angle_max = 18.0
	_sky_material.sun_curve = 0.12
	_environment.background_mode = Environment.BG_SKY
	_environment.fog_enabled = true
	# 먼 땅이 지평선 색으로 잠겨야 하늘과 이음매가 안 보인다 — 같은 색을 쓴다.
	_environment.fog_light_color = horizon_linear
	_environment.fog_light_energy = 1.0
	# 끝은 지금 깔린 지형에서 뽑는다 — 청크를 넘어 반경이 바뀌면 안개도 같이 따라간다.
	var span := fog_span()
	_environment.fog_depth_begin = span.x
	_environment.fog_depth_end = span.y


func fog_span() -> Vector2:
	## 지금 화면의 안개 [시작, 끝]. 스트리밍 필드는 지형이 **확실히** 덮인 거리에서 뽑는다 —
	## 반경이나 청크 크기를 바꾸면 안개도 같이 따라간다. 두 수를 따로 손으로 맞추면
	## 한쪽만 커질 때 지형 끝이 안개 밖으로 나온다.
	if not _chunks_from_snapshot:
		return Vector2(FOG_SINGLE_BEGIN, FOG_SINGLE_END)
	var span := fog_span_for(float(VISUAL_RADIUS), _field)
	# 짙은 안개는 더 앞에서 잠근다 — 물가·동굴이 같은 키트의 평온 바이옴과 갈리는 축이다.
	# 1보다 작은 값(얇은 안개)은 거리를 늘리지 않는다: 지형 끝을 넘으면 허공이 보인다.
	var fog := 1.0
	if not _palette.is_empty():
		fog = maxf(1.0, float(_palette.get("fog", 1.0)))
	return span / fog


static func fog_span_for(radius: float, chunk: Vector2) -> Vector2:
	## 지형은 아바타 청크에서 `radius` 청크까지 깔린다. 아바타가 그 청크 안 어디에 서도
	## 가장 가까운 끝은 radius 청크 떨어져 있으므로, 안개는 그 앞에서 잠근다.
	## 시작은 끝의 고정 비율이다 — 지평선 앞에서 이미 100%가 되야 프롭의 옅은 판이 안 남는다.
	var covered := minf(chunk.x, chunk.y) * radius
	var end := maxf(FOG_MIN_END, covered - FOG_EDGE_MARGIN)
	return Vector2(end * FOG_BEGIN_RATIO, end)


func horizon_color() -> Color:
	## 지평선 헤이즈 — 새 팔레트 값이 아니라 천정색의 파생값이다.
	var palette := _palette if not _palette.is_empty() else FonsBiomePalette.defaults()
	var sky := _color(palette, "sky", FonsBiomePalette.DEFAULT_SKY)
	return Color.from_hsv(sky.h, sky.s * SKY_HAZE_SATURATION,
		lerpf(sky.v, 1.0, SKY_HAZE_MIX))


static func _color(palette: Dictionary, key: String, fallback: Color) -> Color:
	## 깨진 팔레트(문자열 등)가 들어와도 화면이 죽지 않게.
	var value: Variant = palette.get(key, fallback)
	return value if value is Color else fallback


func terrain_height(x: float, z: float) -> float:
	## 유닛·프롭 발밑 높이. 지형이 없으면 0 — 화면이 땅에 붙어 있게.
	return 0.0 if _terrain == null else _terrain.height_at(x, z)


func terrain_trail() -> PackedVector2Array:
	## 이 필드의 오솔길 — 지형색과 프롭 피하기가 **같은 선**을 본다.
	## 시작 모서리에서 조우 자리를 차례로 지나 반대 모서리로 난다. 조우가 아직 없으면 바이옴 시드의
	## 기본 결로 둔다 — 화면에 길이 아예 없는 것보다 낫다.
	if not _is_field:
		return PackedVector2Array()
	if _flats.is_empty():
		return FonsTerrain.make_trail(_field, _kit_seed(_biome))
	var points := PackedVector2Array()
	points.append(Vector2(2.0, 2.0))
	var sites := _flats.duplicate()
	sites.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.y < b.y)
	for site in sites:
		# 조우 링(반지름 1.5)을 비껴 지난다 — 길이 링을 지우면 조우가 길 위에 선 것처럼 보인다.
		points.append(Vector2(clampf(site.x + 2.6, 2.0, _field.x - 2.0), site.y))
	points.append(Vector2(_field.x - 2.0, _field.y - 2.0))
	return points


func terrain_normal(x: float, z: float) -> Vector3:
	## 프롭을 경사면에 눕힐 때 쓰는 법선. 지형이 없으면 위.
	if _terrain == null:
		return Vector3.UP
	var e := 0.6
	var dx := _terrain.height_at(x + e, z) - _terrain.height_at(x - e, z)
	var dz := _terrain.height_at(x, z + e) - _terrain.height_at(x, z - e)
	return Vector3(-dx, 2.0 * e, -dz).normalized()


func terrain_mesh() -> Mesh:
	## 첫 청크 메시. 폴백(평면)일 때는 그 평면이다.
	if _is_field:
		for coord in _chunk_meshes.keys():
			return (_chunk_meshes[coord] as MeshInstance3D).mesh
	return null if _ground == null else _ground.mesh


func chunk_count() -> int:
	## 테스트·디버그용 — 지금 떠 있는 청크 수.
	return _chunk_meshes.size()


func _update_flats(entities: Array) -> void:
	## 조우 자리와 탑 자리를 평탄화한다 — 유닛·원기둥·소환진이 경사에 뜨지 않게.
	_flats.clear()
	var tower_at: Variant = _tower_mark.get("pos", null)
	if tower_at is Vector3:
		var point: Vector3 = tower_at
		_flats.append(Vector2(point.x, point.z))
	for entity in entities:
		if String(entity.get("kind", "")) != KIND_SITE:
			continue
		var pos: Vector3 = entity.get("pos", Vector3.ZERO)
		_flats.append(Vector2(pos.x, pos.z))


func _visual_chunks(seed: Array) -> Array:
	## 심이 보낸 3×3 조우 청크를 중심으로 **지형만** 넓게 펼친다.
	## 안개가 지형 끝을 덮으려면 화면 쪽 끝이 안개 끝보다 멀어야 한다 (`fog_span_for` 주석).
	## 조우는 심의 목록 그대로라 이 확장에 늘지 않는다.
	if seed.is_empty() or VISUAL_RADIUS <= 0:
		return seed
	var low := Vector2(INF, INF)
	var high := Vector2(-INF, -INF)
	for at in seed:
		var origin := Vector2((at as Vector3).x, (at as Vector3).z)
		low = Vector2(minf(low.x, origin.x), minf(low.y, origin.y))
		high = Vector2(maxf(high.x, origin.x), maxf(high.y, origin.y))
	var center := (low + high) * 0.5
	var out: Array = []
	for dz in range(-VISUAL_RADIUS, VISUAL_RADIUS + 1):
		for dx in range(-VISUAL_RADIUS, VISUAL_RADIUS + 1):
			out.append(Vector3(center.x + float(dx) * _field.x, 0.0,
				center.y + float(dz) * _field.y))
	return out


func _sync_terrain(base: Color, palette: Dictionary) -> void:
	## 활성 청크마다 지형 메시 하나. 높이함수는 월드 좌표의 함수라 이웃 청크와 이음새가 없다.
	## 배율·색·기복·평탄 자리가 그대로면 다시 뜨지 않는다 (apply 는 매 입력마다 온다).
	if not _is_field or _ground == null or _chunks.is_empty():
		return
	var tints: Dictionary = {}
	var value: Variant = palette.get("tints", {})
	if value is Dictionary:
		tints = value
	var relief := float(palette.get("relief", FonsTerrain.default_relief()))
	var seed_value := _kit_seed(_biome)
	# 시드도 키에 넣는다 — 팔레트가 같은 두 바이옴이 지형·길을 그대로 물려받지 않게.
	var key := "%s|%s|%s|%.2f|%s|%d|%s" % [_field, base.to_html(), str(tints), relief,
		str(_flats), seed_value, str(_chunks)]
	if key == _terrain_key and _terrain != null:
		return
	# 지면색(`ground`)은 2D 배경용으로 어둡다. 3D 알베도는 식생 틴트를 쓴다 —
	# 기복의 명암이 보이려면 빛을 받을 색이 필요하고, 발광으로 밝히면 기복이 다시 지워진다.
	var albedo := base
	var grass: Variant = tints.get("grass", null)
	if grass is Color:
		albedo = (grass as Color) * TERRAIN_ALBEDO_GAIN
	# 샘플러 하나가 모든 청크의 높이·길을 답한다. 청크마다 따로 뜬 높이함수는 경계에서 어긋난다.
	# 스트리밍에서는 청크 메시가 빈틈을 메우므로 샘플러에 여백을 주지 않는다. 한 청크 폴백은
	# 예전처럼 여백을 준다 — 카메라가 필드 끝에서 뒤로 나가도 뜬 땅이 보였다.
	var margin := 0.0 if _chunks_from_snapshot else FonsTerrain.MARGIN
	var bounds := _chunk_bounds()
	_terrain = FonsTerrain.new(bounds.size, seed_value, relief, _flats, FonsTerrain.FLAT_RADIUS,
		_chunk_trails(), bounds.position, margin)
	_terrain_base = base
	# 평면 폴백은 필드에서 쓰지 않는다 — 청크 메시가 바닥을 맡는다.
	_ground.visible = false
	_sync_chunk_meshes(albedo, tints)
	_terrain_key = key


func _chunk_bounds() -> Rect2:
	## 활성 청크 전체를 덮는 구역. 샘플러의 크기로만 쓴다 (메시는 청크별).
	var low := Vector2(INF, INF)
	var high := Vector2(-INF, -INF)
	for at in _chunks:
		var origin := Vector2((at as Vector3).x, (at as Vector3).z)
		low = Vector2(minf(low.x, origin.x), minf(low.y, origin.y))
		high = Vector2(maxf(high.x, origin.x + _field.x), maxf(high.y, origin.y + _field.y))
	return Rect2(low, high - low)


func _chunk_trails() -> Array:
	## 청크마다 시드가 다른 오솔길을 **월드 좌표**로 펼친다 — 지형색만 바꾸므로 이음새가 없다.
	if not _chunks_from_snapshot:
		return [terrain_trail()]
	var out: Array = []
	for at in _chunks:
		var origin := Vector2((at as Vector3).x, (at as Vector3).z)
		var local := FonsTerrain.make_trail(_field, _chunk_seed(origin))
		var world := PackedVector2Array()
		for point in local:
			world.append(point + origin)
		out.append(world)
	return out


func _chunk_seed(origin: Vector2) -> int:
	## 청크마다 다른 배치 — 같은 청크는 언제 돌아와도 같은 숲이다.
	var cache := FonsExplore.chunk_of(origin)
	return absi(_kit_seed(_biome) + cache.x * 73856093 + cache.y * 19349663)


func _sync_chunk_meshes(albedo: Color, tints: Dictionary) -> void:
	## 청크 목록이 바뀌면 빠진 메시를 버리고 새 메시를 뜬다. 같은 청크는 다시 뜨지 않는다.
	## 새 청크는 프레임당 `CHUNK_BUILD_BUDGET` 개만 — 한꺼번에 뜨면 경계에서 멈춘다.
	if _chunk_root == null:
		return
	var want := {}
	var pending: Array = []
	for at in _chunks:
		var origin := Vector2((at as Vector3).x, (at as Vector3).z)
		var coord := FonsExplore.chunk_of(origin)
		want[coord] = origin
		var node: MeshInstance3D = _chunk_meshes.get(coord, null)
		if node == null:
			node = MeshInstance3D.new()
			node.name = "Chunk_%d_%d" % [coord.x, coord.y]
			node.material_override = _terrain_material()
			_chunk_root.add_child(node)
			_chunk_meshes[coord] = node
			_chunk_mesh_key[coord] = ""
		var rect := Rect2(origin, _field)
		if not _chunks_from_snapshot:
			rect = Rect2(origin - Vector2(FonsTerrain.MARGIN, FonsTerrain.MARGIN),
				_field + Vector2(FonsTerrain.MARGIN, FonsTerrain.MARGIN) * 2.0)
		# 평탄 자리는 **이 청크에 닿는 것만** 키에 넣는다. 전부 넣으면 조우가 스트리밍될 때마다
		# 49청크가 한꺼번에 다시 떠서 청크를 넘을 때마다 4초 넘게 멈춘다 (2026-10-26 실측).
		var near_flats: Array = []
		var grown := rect.grow(FonsTerrain.FLAT_RADIUS + FonsTerrain.FLAT_FEATHER)
		for point in _flats:
			if grown.has_point(point):
				near_flats.append(point)
		var mesh_key := "%s|%s|%s|%.1f" % [albedo.to_html(), str(tints), str(near_flats),
			FonsTerrain.MARGIN if not _chunks_from_snapshot else 0.0]
		if String(_chunk_mesh_key[coord]) != mesh_key or node.mesh == null:
			pending.append([coord, rect, mesh_key])
	for coord in _chunk_meshes.keys():
		if want.has(coord):
			continue
		_chunk_meshes[coord].queue_free()
		_chunk_meshes.erase(coord)
		_chunk_mesh_key.erase(coord)
	if _mounted and pending.size() > CHUNK_BUILD_BUDGET:
		pending.sort_custom(func(a, b): return _chunk_distance(a[0]) < _chunk_distance(b[0]))
		pending = pending.slice(0, CHUNK_BUILD_BUDGET)
	for item in pending:
		var coord: Vector2i = item[0]
		_chunk_meshes[coord].mesh = _terrain.build_region(item[1], albedo, tints)
		_chunk_mesh_key[coord] = String(item[2])
	# 새로 뜬 청크만 덮는다 — 매 프레임 전체를 돌면 청크 49장에서 비싸다.
	_toon.apply(_chunk_root)


func _chunk_distance(coord: Vector2i) -> float:
	## 아바타에서 가까운 청크부터 짓는다 — 가까운 쪽이 화면에 먼저 필요하다.
	var at: Vector3 = _positions.get("avatar", Vector3.ZERO)
	return FonsExplore.chunk_origin(coord).distance_to(Vector2(at.x, at.z))


func _clear_terrain() -> void:
	_terrain = null
	_terrain_key = ""
	_terrain_base = GROUND
	for coord in _chunk_meshes.keys():
		_chunk_meshes[coord].queue_free()
	_chunk_meshes.clear()
	_chunk_mesh_key.clear()
	if _ground != null:
		var plane := PlaneMesh.new()
		plane.size = Vector2(40.0, 28.0)
		_ground.mesh = plane
		_ground.position = Vector3(20.0, -0.02, 14.0)
		_ground.visible = true


func _terrain_material() -> StandardMaterial3D:
	## 정점색이 곧 알베도다. `_material` 처럼 발광을 섞지 않는다 — 발광은 기복의 명암을 지운다.
	var key := "terrain"
	if not _materials.has(key):
		var material := StandardMaterial3D.new()
		material.vertex_color_use_as_albedo = true
		# 정점색을 sRGB 로 굽기 때문에 여기서 한 번만 선형으로 바꾼다.
		material.vertex_color_is_srgb = true
		material.roughness = 0.95
		_materials[key] = material
	return _materials[key]


func _sync_entities(entities: Array) -> void:
	if _entities_root == null:
		return
	var seen := {}
	for entity in entities:
		var id := String(entity.get("id", ""))
		if id.is_empty():
			continue
		seen[id] = true
		_entities[id] = entity
		var node: Node3D = _nodes.get(id, null)
		if node == null:
			node = _make_node(entity)
			_nodes[id] = node
			_visuals[id] = node.get_child(0)
			_entities_root.add_child(node)
		_place(node, entity)
	_remove_missing(seen)


func _remove_missing(seen: Dictionary) -> void:
	for id in _nodes.keys():
		if seen.has(id):
			continue
		_nodes[id].queue_free()
		_nodes.erase(id)
		_positions.erase(id)
		_visuals.erase(id)
		_lifts.erase(id)
		_entities.erase(id)


## ── 에셋 키 → 메시 ──────────────────────────────────────────────────────

func register_asset(asset: String, resource: Resource) -> void:
	## 자산이 생기면 여기에 건다: `register_asset("hero:knight", load("res://...glb"))`.
	## `.glb` 는 `PackedScene` 으로 임포트된다 — 씬은 엔티티 아래에 인스턴스로 붙는다.
	## 이미 그려진 엔티티는 다음 `apply` 에서 새 자산을 쓴다.
	if asset.is_empty() or resource == null:
		return
	if resource is Mesh or resource is PackedScene:
		asset_resources[asset] = resource


func asset_mesh(asset: String) -> Mesh:
	var resource: Resource = asset_resources.get(asset, null)
	return resource if resource is Mesh else null


func asset_scene(asset: String) -> PackedScene:
	var resource: Resource = asset_resources.get(asset, null)
	return resource if resource is PackedScene else null


## ── 바이옴 키트 (S2) ────────────────────────────────────────────────────

func register_kit(kit: String, scene: PackedScene) -> void:
	## 테스트·조립 루트가 키트 씬을 직접 건다. 실제 경로는 `KIT_DIR` 규칙으로도 찾는다.
	if kit.is_empty() or scene == null:
		return
	kit_scenes[kit] = scene


func kit_module_count() -> int:
	return _kit_count


func current_kit_tints() -> Dictionary:
	return _kit_tints


func loaded_kit(kit: String) -> PackedScene:
	if kit_scenes.has(kit):
		return kit_scenes[kit]
	var path := KIT_DIR % kit
	return load(path) as PackedScene if ResourceLoader.exists(path) else null


func _sync_kit(entities: Array) -> void:
	## 청크마다 키트 하나. **새 청크만 깔고 나간 청크만 버린다** — 49청크를 매번 다시 깔면
	## 청크를 넘을 때마다 1초 넘게 멈춘다 (2026-10-26 실측: 49청크 1.1초).
	## 키트·틴트가 바뀌면 뿌리째 새로 만든다 — 색이 메시에 곱해져 있다.
	var want := _kit if _is_field else ""
	var tints: Dictionary = {}
	var value: Variant = _palette.get("tints", {})
	if value is Dictionary:
		tints = value
	var base_key := "%s|%s" % [want, str(tints)] if not want.is_empty() else ""
	if base_key != _kit_key:
		_clear_kit()
		_kit_built = want
		_kit_tints = tints
		_kit_key = base_key
		if not want.is_empty() and _world != null and not _chunks.is_empty():
			if loaded_kit(want) != null:
				_kit_root = Node3D.new()
				_kit_root.name = "Kit"
				_world.add_child(_kit_root)
	if _kit_root == null or want.is_empty() or _chunks.is_empty():
		return
	var scene := loaded_kit(want)
	if scene == null:
		# 아직 자산이 없는 키트 — 빈 필드로 둔다. 나중에 등록되면 다음 apply 에서 깐다.
		return
	var want_coords := {}
	var pending: Array = []
	for at in _chunks:
		var origin := Vector2((at as Vector3).x, (at as Vector3).z)
		var coord := FonsExplore.chunk_of(origin)
		want_coords[coord] = true
		var avoid := _kit_avoid(entities, origin)
		var clear := _kit_clear(origin)
		# 조우가 스트리밍되면 그 청크만 다시 깐다 — 나머지는 그대로 둔다.
		var key := "%s|%s" % [str(avoid), str(clear)]
		if _chunk_kits.has(coord) and String(_chunk_kit_key.get(coord, "")) == key:
			continue
		pending.append({"coord": coord, "origin": origin, "avoid": avoid, "clear": clear, "key": key})
	for coord in _chunk_kits.keys():
		if not want_coords.has(coord):
			_drop_chunk_kit(coord)
	if _mounted and pending.size() > CHUNK_BUILD_BUDGET:
		pending.sort_custom(func(a, b): return _chunk_distance(a["coord"]) < _chunk_distance(b["coord"]))
		pending = pending.slice(0, CHUNK_BUILD_BUDGET)
	# 프롭이 사라지는 거리 — 스트리밍 필드만. 안개 span 의 `KIT_CULL_RATIO` 지점에서 끈다.
	# 페이드가 안개 시작을 넘어오면 가까운 프롭까지 뿌옇게 되므로 그 앞으로는 내려가지 않는다.
	# 안개가 없는 화면(전투·헤드리스)은 0 — 끄면 지평선에 구멍이 난다.
	var draw_end := 0.0
	if _chunks_from_snapshot:
		var span := fog_span()
		draw_end = maxf(span.x + FonsBiomeKit.DRAW_END_FADE,
			span.x + (span.y - span.x) * KIT_CULL_RATIO)
	for item in pending:
		var coord: Vector2i = item["coord"]
		var origin: Vector2 = item["origin"]
		var avoid: Array = item["avoid"]
		var clear: Array = item["clear"]
		_drop_chunk_kit(coord)
		# 키트는 청크 로컬 좌표로 놓는다 — 뿌리만 월드로 옮겼다.
		var root := Node3D.new()
		root.name = "Kit_%d_%d" % [coord.x, coord.y]
		root.position = Vector3(origin.x, 0.0, origin.y)
		_kit_root.add_child(root)
		var trails: Array = []
		if _chunks_from_snapshot:
			trails.append(FonsTerrain.make_trail(_field, _chunk_seed(origin)))
		else:
			trails = [terrain_trail()]
		var blockers: Array = []
		var height := func(x: float, z: float) -> float:
			return terrain_height(x + origin.x, z + origin.y)
		var normal := func(x: float, z: float) -> Vector3:
			return terrain_normal(x + origin.x, z + origin.y)
		var count := FonsBiomeKit.build(root, scene, _field, _chunk_seed(origin), avoid, tints,
			false, height, normal, blockers, trails, draw_end, FonsBiomeKit.plan(_biome), clear)
		# 가림 원통은 로컬 좌표로 나온다 — 카메라는 월드로 보므로 여기서 옮긴다.
		for entry in blockers:
			entry["pos"] = (entry["pos"] as Vector3) + Vector3(origin.x, 0.0, origin.y)
		_chunk_kits[coord] = root
		_chunk_kit_key[coord] = String(item["key"])
		_chunk_kit_counts[coord] = count
		_chunk_blockers[coord] = blockers
		_kit_count += count
	_rebuild_blockers()
	# 새로 깐 키트만 덮는다(모듈이 이미 덮은 면은 건너뛴다).
	_toon.apply(_kit_root)


func _kit_clear(origin: Vector2) -> Array:
	## 비워 둘 구역 — 플레이어가 **서서 카메라를 돌리는 자리** 둘이다: **탑 광장**과
	## **시작·후퇴 자리**. 여기 부품이 서면 시작하자마자 붐이 접혀 화면이 막힌다
	## (2026-10-28 실측: 동굴 청크 (0,0) 에서 랜드마크 중심이 시작 자리 2.54유닛 · 24방향 중
	## 16방향 접힘). 반경은 **카메라 기본 거리**(탑은 소환진 고리 + 그 거리) — 그 자리에서
	## 어느 쪽으로 돌려도 부품에 안 닿는다. 부품 발자국은 키트가 더한다.
	##
	## 시작 자리는 **심의 상수**(`FonsExplore.SPAWN`)에서 온다 — 아바타 자리를 따라가면
	## 걸으며 지어지는 청크마다 구역이 달라져 같은 청크의 배치가 어긋난다.
	var out: Array = []
	if not _tower_mark.is_empty():
		var at: Vector3 = _tower_mark.get("pos", Vector3.ZERO)
		if at.x >= origin.x and at.x <= origin.x + _field.x \
				and at.z >= origin.y and at.z <= origin.y + _field.y:
			out.append({
				"pos": Vector2(at.x - origin.x, at.z - origin.y),
				"radius": float(_tower_mark.get("radius", 0.0)) + CAMERA_DISTANCE,
			})
	if FonsExplore.SPAWN.x >= origin.x and FonsExplore.SPAWN.x <= origin.x + _field.x \
			and FonsExplore.SPAWN.y >= origin.y and FonsExplore.SPAWN.y <= origin.y + _field.y:
		out.append({
			"pos": Vector2(FonsExplore.SPAWN.x - origin.x, FonsExplore.SPAWN.y - origin.y),
			"radius": CAMERA_DISTANCE,
		})
	return out


func _kit_avoid(entities: Array, origin: Vector2) -> Array:
	## 이 청크 안의 조우 자리 — 프롭이 그 위에 서지 않게.
	var avoid: Array = []
	for entity in entities:
		if String(entity.get("kind", "")) != KIND_SITE:
			continue
		var pos: Vector3 = entity.get("pos", Vector3.ZERO)
		if pos.x < origin.x or pos.x > origin.x + _field.x:
			continue
		if pos.z < origin.y or pos.z > origin.y + _field.y:
			continue
		avoid.append(Vector3(pos.x - origin.x, 0.0, pos.z - origin.y))
	return avoid


func _drop_chunk_kit(coord: Vector2i) -> void:
	if not _chunk_kits.has(coord):
		return
	(_chunk_kits[coord] as Node).queue_free()
	_kit_count -= int(_chunk_kit_counts.get(coord, 0))
	_chunk_kits.erase(coord)
	_chunk_kit_key.erase(coord)
	_chunk_kit_counts.erase(coord)
	_chunk_blockers.erase(coord)


func _rebuild_blockers() -> void:
	## 가림 목록은 청크별로 들고 있다가 합친다 — 청크 하나를 버린다고 남의 가림이 사라지면
	## 카메라가 나무를 뚫는다.
	_blockers.clear()
	for coord in _chunk_blockers:
		_blockers.append_array(_chunk_blockers[coord])


func _kit_seed(kit: String) -> int:
	## 같은 키트·같은 층이면 같은 배치 — 스크린샷과 눈 검토가 흔들리지 않는다.
	return absi(kit.hash() + _floor * 31)


func _clear_kit() -> void:
	if _kit_root != null:
		_kit_root.queue_free()
		_kit_root = null
	_kit_count = 0
	_kit_built = ""
	_kit_tints = {}
	_kit_key = ""
	_chunk_kits.clear()
	_chunk_kit_key.clear()
	_chunk_kit_counts.clear()
	_chunk_blockers.clear()
	_blockers.clear()


func kit_props() -> Array:
	## 테스트·디버그용 — 키트가 놓은 프롭 전부 (청크 묶음을 펼진다).
	var out: Array = []
	if _kit_root == null:
		return out
	for root in _kit_root.get_children():
		out.append_array(root.get_children())
	return out


## ── 탑·소환진 ─────────────────────────────────────────────────────

func _sync_tower() -> void:
	## 층 중심의 탑과 소환진. 자리·반경은 심이 `tower` 로 주고 **메시는 뷰가 만든다** —
	## 심은 메시를 모른다 (R1·R3). 팔레트가 바뀌면 돌빛·소환진 빛도 바뀌므로 키에 색을 넣는다.
	if _tower_mark.is_empty() or _world == null:
		_clear_tower()
		return
	var at: Vector3 = _tower_mark.get("pos", Vector3.ZERO)
	var radius := float(_tower_mark.get("radius", 0.0))
	var body := float(_tower_mark.get("body", radius * 0.35))
	if radius <= 0.0 or body <= 0.0:
		_clear_tower()
		return
	var palette := _palette if not _palette.is_empty() else FonsBiomePalette.defaults()
	# 돌은 지면색을 밝힌 값 — 회색을 박으면 눈밭의 탑만 혼자 남는다.
	var stone := _color(palette, "ground", FonsBiomePalette.DEFAULT_GROUND).lightened(0.55)
	var glow := _color(palette, "light", FonsBiomePalette.DEFAULT_LIGHT)
	var key := "%s|%s|%s|%.2f|%.2f" % [at, stone.to_html(), glow.to_html(), radius, body]
	if key == _tower_key and _tower_root != null:
		# 키트를 다시 깔면 `_blockers` 가 비어 탑 가림만 사라진다 — 다시 꿔아 준다.
		if not _blockers.has(_tower_blocker):
			_blockers.append(_tower_blocker)
		return
	_clear_tower()
	_tower_root = Node3D.new()
	_tower_root.name = "Tower"
	_world.add_child(_tower_root)
	var ground := terrain_height(at.x, at.z)
	_tower_root.position = Vector3(at.x, ground, at.z)

	# 몸통 — 아래가 넓고 위로 좁아지는 돌기둥 + 덮개.
	var shaft := CylinderMesh.new()
	shaft.top_radius = body * 0.72
	shaft.bottom_radius = body
	shaft.height = TOWER_HEIGHT
	shaft.radial_segments = 10
	_mesh_at(_tower_root, shaft, stone, Vector3(0.0, TOWER_HEIGHT * 0.5, 0.0))
	var crown := CylinderMesh.new()
	crown.top_radius = 0.12
	crown.bottom_radius = body * 1.3
	crown.height = TOWER_CROWN
	crown.radial_segments = 10
	_mesh_at(_tower_root, crown, stone, Vector3(0.0, TOWER_HEIGHT + TOWER_CROWN * 0.5, 0.0))

	# 소환진 — 바닥에 놓인 두 겸의 빛나는 고리. 반경은 심이 준 값 그대로다.
	_ring_at(_tower_root, radius, glow, 0.06)
	_ring_at(_tower_root, radius * 0.55, glow, 0.09)

	# 카메라가 탑을 뚫지 않게 가림 원통을 넣는다 (키트 프롭과 같은 규칙).
	_tower_blocker = {"pos": Vector3(at.x, ground, at.z), "radius": body * TOWER_BLOCKER_SCALE,
		"top": ground + TOWER_HEIGHT + TOWER_CROWN}
	_blockers.append(_tower_blocker)
	_tower_key = key


func _mesh_at(parent: Node3D, mesh: Mesh, color: Color, at: Vector3) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = _material(color)
	node.position = at
	parent.add_child(node)
	return node


func _ring_at(parent: Node3D, radius: float, color: Color, lift: float) -> MeshInstance3D:
	## 납작한 원판 대신 **고리**를 쓴다 — 판을 깔면 아래 지형색을 덮어 소환진이 색종이로 읽힌다.
	var torus := TorusMesh.new()
	torus.inner_radius = maxf(0.02, radius - 0.13)
	torus.outer_radius = radius
	torus.rings = 48
	torus.ring_segments = 6
	var node := MeshInstance3D.new()
	node.mesh = torus
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 1.6
	node.material_override = material
	node.position = Vector3(0.0, lift, 0.0)
	parent.add_child(node)
	return node


func _clear_tower() -> void:
	if _tower_root != null:
		_tower_root.queue_free()
		_tower_root = null
	if not _tower_blocker.is_empty():
		_blockers.erase(_tower_blocker)
		_tower_blocker = {}
	_tower_key = ""


func tower_radius() -> float:
	## 테스트·디버그용 — 지금 세워 진 소환진 반지름 (없으면 0).
	return 0.0 if _tower_root == null else float(_tower_mark.get("radius", 0.0))


func tower_node() -> Node3D:
	return _tower_root


func _play_strike(strike: Variant) -> void:
	## 심이 "방금 한 판"을 실어 보낸 순간에만 그 자리에 짧은 타격을 낸다.
	## seq 비교는 연출 전용이다 — 전투 결과는 이미 스냅샷의 조우 상태가 말한다.
	if not (strike is Dictionary) or _strike_root == null:
		return
	var seq := int((strike as Dictionary).get("seq", 0))
	if seq <= _strike_seq:
		return
	_strike_seq = seq
	_shake(bool((strike as Dictionary).get("heavy", false)))
	var site := int((strike as Dictionary).get("site", -1))
	if site < 0 or not _positions.has("site:%d" % site):
		return
	var at: Vector3 = _positions["site:%d" % site]
	# 땅에 살짝 띄운다 — 고리가 지형에 뚫리거나 z-파이팅으로 깜빡이지 않게.
	var ground := terrain_height(at.x, at.z)
	FonsStrikeFx.spawn(_strike_root, Vector3(at.x, ground + 0.04, at.z),
		int((strike as Dictionary).get("damage", 0)))


func _clear_strikes() -> void:
	if _strike_root == null:
		return
	for child in _strike_root.get_children():
		child.queue_free()


static func slot_hue(slot: int, count: int) -> float:
	## 색역을 count 칸으로 고르게 쪼갠 slot 번째 색상. count 가 1 이어도 색역 가운데는 안 쏠린다.
	var n := maxi(1, count)
	return HERO_HUE_FROM + (HERO_HUE_TO - HERO_HUE_FROM) * float(clampi(slot, 0, n - 1)) / float(n)


func _update_colors(entities: Array) -> void:
	## 이번 스냅샷의 영웅 키들을 정렬해 색을 나눠 준다 — 키가 다르면 반드시 색이 다르다.
	var assets: Array = []
	for entity in entities:
		if String(entity.get("kind", "")) != KIND_HERO:
			continue
		var asset := String(entity.get("asset", ""))
		if asset.is_empty() or assets.has(asset):
			continue
		assets.append(asset)
	assets.sort()
	asset_colors.clear()
	for i in assets.size():
		asset_colors[assets[i]] = Color.from_hsv(slot_hue(i, assets.size()), HERO_SATURATION, 1.0)


func _make_node(entity: Dictionary) -> Node3D:
	var kind := String(entity.get("kind", ""))
	var asset := String(entity.get("asset", ""))
	var node := Node3D.new()
	node.name = String(entity.get("id", "entity"))
	var mesh := MeshInstance3D.new()
	mesh.name = "Visual"
	var scene := asset_scene(asset)
	# 사람이 등록한 메시가 먼저다 — 대역 몸통은 그 키에 자산이 없을 때의 기본값이다.
	var custom := asset_mesh(asset)
	# 생물은 등록된 씬이 없어도 대역 몸통으로 그린다 — 키 매핑이 78칸 전부를 덮는다.
	var body := FonsMonsterBody.visual(asset) if kind == KIND_MONSTER else {}
	if scene == null and custom == null and not body.is_empty():
		scene = FonsMonsterBody.scene(String(body.get("band", "")))
	# 영웅도 몸통으로 그린다 — 색 상자·캡슐은 생물 옆에서 미완성 표시로 읽힌다.
	var hero_band := FonsHeroBody.band_for(asset) if kind == KIND_HERO or kind == KIND_AVATAR else ""
	if scene == null and custom == null and not hero_band.is_empty():
		scene = FonsHeroBody.scene(hero_band)
	if scene != null:
		# 씬이 그림을 맡는다 — 폴백 도형 자리는 비워 두고(child 0) 색·높이 계산 경로는 그대로 둔다.
		mesh.mesh = null
	else:
		mesh.mesh = custom if custom != null else _fallback_mesh(kind)
	mesh.position.y = _fallback_height(kind) * 0.5
	node.add_child(mesh)
	var height := _fallback_height(kind)
	if scene != null:
		var instance := scene.instantiate()
		instance.name = "Asset"
		node.add_child(instance)
		if not body.is_empty():
			var scale := float(body.get("scale", 1.0))
			var color: Color = body.get("color", Color.WHITE)
			instance.scale = Vector3.ONE * scale
			FonsMonsterBody.apply(instance, color)
			# 죽음은 밝기로만 알린다 — 씬 몸통은 폴백 메시처럼 material_override 가 안 먹는다.
			node.set_meta("body_color", color)
			node.set_meta("body_shade", 1.0)
			height = FonsMonsterBody.height(instance) * scale
		elif not hero_band.is_empty():
			var hero_color: Color = asset_colors.get(asset, AVATAR_COLOR if kind == KIND_AVATAR else HERO_COLOR)
			FonsHeroBody.apply(instance, hero_color)
			node.set_meta("hero_color", hero_color)
			node.set_meta("hero_shade", 1.0)
			height = FonsHeroBody.height(instance)
	_lifts[String(entity.get("id", ""))] = height
	return node


func _fallback_mesh(kind: String) -> Mesh:
	## 자산 키가 없거나 아직 등록 안 된 엔티티용 도형. 종류만큼은 한눈에 구분되게.
	match kind:
		KIND_SITE:
			var cylinder := CylinderMesh.new()
			cylinder.top_radius = 0.75
			cylinder.bottom_radius = 0.75
			cylinder.height = SITE_HEIGHT
			return cylinder
		KIND_AVATAR:
			var capsule := CapsuleMesh.new()
			capsule.radius = AVATAR_RADIUS
			capsule.height = 1.0
			return capsule
		KIND_MONSTER:
			var cone := CylinderMesh.new()
			cone.top_radius = 0.0
			cone.bottom_radius = 0.45
			cone.height = MONSTER_HEIGHT
			return cone
		_:
			var box := BoxMesh.new()
			box.size = Vector3(HERO_SIZE, HERO_SIZE, HERO_SIZE)
			return box


func _fallback_height(kind: String) -> float:
	match kind:
		KIND_SITE:
			return SITE_HEIGHT
		KIND_AVATAR:
			return 1.0
		KIND_MONSTER:
			return MONSTER_HEIGHT
		_:
			return HERO_SIZE


func _place(node: Node3D, entity: Dictionary) -> void:
	var kind := String(entity.get("kind", ""))
	var pos: Vector3 = entity.get("pos", Vector3.ZERO)
	# 심 좌표는 평면(y=0)이다 — 화면만 지형 높이만큼 들어 올린다.
	var world_pos := Vector3(pos.x, 0.0, pos.z)
	node.position = Vector3(pos.x, terrain_height(pos.x, pos.z), pos.z)
	_positions[String(entity.get("id", ""))] = world_pos
	var mesh: MeshInstance3D = node.get_child(0)
	var height := _fallback_height(kind)
	if kind == KIND_SITE:
		var cleared := bool(entity.get("cleared", false))
		mesh.material_override = _material(SITE_CLEARED if cleared else SITE_COLOR)
		mesh.scale = Vector3(1.0, 0.18, 1.0) if cleared else Vector3.ONE
		mesh.position.y = height * 0.5 * mesh.scale.y
	elif kind == KIND_AVATAR:
		mesh.material_override = _avatar_material()
		mesh.scale = Vector3.ONE
		mesh.position.y = height * 0.5
	else:
		var color: Color = MONSTER_COLOR if kind == KIND_MONSTER else HERO_COLOR
		if kind != KIND_MONSTER:
			color = asset_colors.get(String(entity.get("asset", "")), HERO_COLOR)
		if not bool(entity.get("alive", true)):
			color = color * DEAD_FADE
		mesh.material_override = _material(color)
		mesh.scale = Vector3.ONE
		mesh.position.y = height * 0.5
		if kind == KIND_MONSTER and node.has_meta("body_color"):
			var shade := 1.0 if bool(entity.get("alive", true)) else DEAD_FADE
			if not is_equal_approx(float(node.get_meta("body_shade", 1.0)), shade):
				node.set_meta("body_shade", shade)
				var body := node.get_node_or_null("Asset")
				if body != null:
					FonsMonsterBody.apply(body, (node.get_meta("body_color") as Color) * shade)
		elif node.has_meta("hero_color"):
			var hero_shade := 1.0 if bool(entity.get("alive", true)) else DEAD_FADE
			if not is_equal_approx(float(node.get_meta("hero_shade", 1.0)), hero_shade):
				node.set_meta("hero_shade", hero_shade)
				var hero_body := node.get_node_or_null("Asset")
				if hero_body != null:
					FonsHeroBody.apply(hero_body, (node.get_meta("hero_color") as Color) * hero_shade)


func _material(color: Color) -> StandardMaterial3D:
	var key := color.to_html()
	if not _materials.has(key):
		var material := StandardMaterial3D.new()
		material.albedo_color = color
		material.roughness = 0.8
		material.emission_enabled = true
		material.emission = Color(color.r * 0.25, color.g * 0.25, color.b * 0.25)
		_materials[key] = material
	return _materials[key]


## ── 입력 ────────────────────────────────────────────────────────────────

func _process(delta: float) -> void:
	if not _is_field:
		return
	# 카메라를 놓기 전에 흔들림을 줄인다 — 위치와 꼬리가 같이 줄어야 떨림이 자연스럽다.
	_shake_left = maxf(0.0, _shake_left - delta)
	_update_jump(delta)
	_turn_with_keys(delta)
	_update_camera(delta)
	var dir := Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		dir.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		dir.x += 1.0
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		dir.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		dir.y += 1.0
	if dir != Vector2.ZERO:
		dir = dir.normalized()
	# 카메라를 돌리면 같은 키라도 가는 방향이 바뀐다 — 입력이 같아도 다시 보낸다.
	if dir == _last_dir and is_equal_approx(_yaw, _last_yaw):
		return
	_last_dir = dir
	_last_yaw = _yaw
	intent.emit(&"move", {"dir": camera_relative(dir)})


func _turn_with_keys(delta: float) -> void:
	## 마우스 없이 시점을 돌리는 길. Q·E 는 걷기·행동 키와 겹치지 않는다.
	var turn := 0.0
	if Input.is_key_pressed(KEY_Q):
		turn -= 1.0
	if Input.is_key_pressed(KEY_E):
		turn += 1.0
	if turn != 0.0:
		orbit(turn * CAMERA_KEY_TURN * delta, 0.0)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		# 잡혀 있을 때만 시점이 돈다 — 버튼을 누를 필요가 없다. Esc 로 풀면 커서가 돌아온다.
		if _is_field and _capture_wanted:
			var motion := event as InputEventMouseMotion
			orbit(-motion.relative.x * CAMERA_SENSITIVITY, motion.relative.y * CAMERA_SENSITIVITY)
		return
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if not button.pressed:
			return
		if button.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom(1.0)
		elif button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom(-1.0)
		elif button.button_index == MOUSE_BUTTON_LEFT and _is_field and not _capture_wanted:
			# Esc 로 풀었을 때 돌아오는 길 — 필드를 클릭하면 다시 잡는다.
			set_mouse_capture(true)
		return
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var key := (event as InputEventKey).keycode
	if _is_field:
		match key:
			KEY_ESCAPE:
				set_mouse_capture(false)
			KEY_SPACE:
				jump()
			KEY_F, KEY_ENTER:
				intent.emit(&"interact", {})
			KEY_R:
				intent.emit(&"retreat", {})
			KEY_C:
				intent.emit(&"edict", {})
			KEY_1, KEY_2, KEY_3, KEY_4, KEY_5:
				intent.emit(&"switch_hero", {"index": int(key) - int(KEY_1)})
	else:
		match key:
			KEY_SPACE, KEY_ENTER:
				intent.emit(&"next_floor", {})
			KEY_R:
				intent.emit(&"restart", {})


func _viewport_size() -> Vector2:
	var vp := get_viewport()
	if vp == null:
		return Vector2(1280.0, 720.0)
	return vp.get_visible_rect().size
