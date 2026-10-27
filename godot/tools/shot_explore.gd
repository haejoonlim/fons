extends SceneTree
## 임시 검증 하네스 — main.tscn 을 실제 창에 띄워 탐험 필드를 PNG 로 남긴다.
## `godot --path godot -s tools/shot_explore.gd` (headless 아님 — 렌더링이 필요하다)
## 결과: `godot/screenshots/explore_{contact,after_fight,retreat}.png`

class AlwaysEngage extends FonsBrain:
	## 교전/후퇴 판단만 강제하고, 전투 중 수·대상 판단은 부모에게 넘긴다.
	func decide(candidates: Array, ctx: Dictionary) -> Dictionary:
		if candidates.size() > 0 and String(candidates[0].get("action", "")) == "교전":
			return candidates[0]
		return super.decide(candidates, ctx)


func _initialize() -> void:
	root.size = Vector2i(1280, 720)
	var packed := load("res://game/main/main.tscn") as PackedScene
	var node: Node = packed.instantiate()
	root.add_child(node)
	for i in 4:
		await process_frame

	# ① 걸어서 첫 조우에 닿는다 — 순간이동이 아니라 `move` 의도로 실제 걷는다.
	# (게임에서 WASD 를 누르는 것과 같은 경로: 뷰 → intent → main → FonsFieldState.walk)
	var site: Dictionary = node._field.explore.sites[0]
	_walk_to(node, site["pos"])
	print("walked to %s · contact=%d" % [str(node._field.explore.avatar), node._field.contact_index()])
	await _save("res://screenshots/explore_contact.png")

	# ② 스페이스 — 조우 전투. 지운 지점과 전투 로그가 남는다.
	node._on_intent(&"interact", {})
	for i in 3:
		await process_frame
	await _save("res://screenshots/explore_after_fight.png")

	# ③ R — 후퇴. 입구로 돌아가되 지운 조우는 남는다.
	node._on_intent(&"retreat", {})
	for i in 2:
		await process_frame
	await _save("res://screenshots/explore_retreat.png")

	# ④ 동료 교전 — 1번 동료를 둘째 조우에 세우고, 교전을 고르는 브레인으로 바꿔
	#   점멸하는 준비 창과 실제 전투 결과를 본다.
	var ally := 1
	var old: Variant = node._field.heroes[ally].get("brain", null)
	if old is FonsBrain:
		var stub := AlwaysEngage.new()
		stub.setup(old.identity, old.data, old.job_profile, old.role, old.catalog_by_id.values(), 1)
		node._field.heroes[ally]["brain"] = stub
	# 플레이어를 조우 6유닛 앞까지 걷게 해 동료가 범위 안에서 닿는 실제 상황을 만든다.
	var site1: Dictionary = node._field.explore.sites[1]
	var to_site: Vector2 = site1["pos"] - node._field.explore.avatar
	if to_site.length() > 6.0:
		_walk_to(node, site1["pos"] - to_site.normalized() * 6.0)
	else:
		node._process(0.1)
	node._field.party_pos[ally] = site1["pos"]
	node._field.tick(0.1)
	node._push()
	print("ally shot · site1=%s · ally1=%s · state=%s" % [str(node._field.explore.sites[1]["pos"]),
		str(node._field.party_pos[1]), str(node._field._ally_state[1])])
	await _save("res://screenshots/explore_ally_ready.png")
	node._field.tick(1.6)
	node._push()
	await _save("res://screenshots/explore_ally_fight.png")
	print("saved 5 shots · cleared=%d · winner=%s" % [node._field.explore.cleared, node._field.winner])
	quit()


func _walk_to(node: Node, target: Vector2) -> void:
	## 한 번에 큰 delta 로 순간이동시키면 동료가 분리될 시간이 없다 — 0.1초씩 실제로 걷는다.
	var field: FonsFieldState = node._field
	node._on_intent(&"move", {"dir": (target - field.explore.avatar).normalized()})
	var guard := 0
	while field.explore.avatar.distance_to(target) > 0.6 and guard < 400:
		var left: float = field.explore.avatar.distance_to(target)
		node._process(minf(0.1, left / FonsExplore.WALK_SPEED))
		guard += 1
	node._on_intent(&"move", {"dir": Vector2.ZERO})


func _save(path: String) -> void:
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	if img == null or img.is_empty():
		printerr("viewport texture empty: %s" % path)
		return
	img.save_png(path)
	print("saved %s %dx%d" % [path, img.get_width(), img.get_height()])
