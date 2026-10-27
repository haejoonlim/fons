extends Node
## 슬롯 파일 IO — 경로·원자성·백업만 안다. 형식과 버전 규칙은 `godot/core/save.gd` 가 진다.
##
## 쓰기 순서 (설계 §3)
##   1. `slot_1.json.tmp` 에 전부 쓰고 flush
##   2. 기존 파일이 있으면 `slot_1.json.bak` 으로 **한 세대만** 옮긴다
##   3. tmp → 본파일 교체. 실패하면 tmp 를 남기고 오류를 돌려준다
## 반쯤 쓴 파일이 정본이 되면 안 된다. 교체 전에 죽으면 본파일은 그대로다.
##
## 읽기 순서
##   파일 없음 → "none" (새 게임. 오류가 아니다)
##   파싱·스키마 실패 → `.corrupt-<시각>.json` 으로 격리하고 `.bak` 을 한 번 시도
##   더 새 `schema` → "newer", 파일은 건드리지 않는다

const DIR := "user://saves"
const SLOT := "slot_1.json"


func path_of(slot: String = SLOT) -> String:
	## 테스트·진단용. 실제 경로는 플랫폼마다 다르므로 여기서만 만든다.
	return ProjectSettings.globalize_path(DIR.path_join(slot))


func save_payload(payload: Dictionary, slot: String = SLOT) -> Dictionary:
	var made := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	if made != OK and made != ERR_ALREADY_EXISTS:
		return {"ok": false, "error": "저장 폴더를 만들 수 없다: %s" % DIR}
	var target := path_of(slot)
	var tmp := target + ".tmp"
	var file := FileAccess.open(tmp, FileAccess.WRITE)
	if file == null:
		return {"ok": false, "error": "임시 파일을 열 수 없다: %s" % tmp}
	file.store_string(JSON.stringify(payload, "\t"))
	file.flush()
	file.close()
	if FileAccess.file_exists(target):
		var bak := target + ".bak"
		if FileAccess.file_exists(bak):
			DirAccess.remove_absolute(bak)
		if DirAccess.rename_absolute(target, bak) != OK:
			return {"ok": false, "error": "기존 세이브를 백업하지 못했다 — 원본 유지"}
		if DirAccess.rename_absolute(tmp, target) != OK:
			return {"ok": false, "error": "교체 실패 — 임시 파일을 남긴다: %s" % tmp}
		return {"ok": true, "error": ""}
	if DirAccess.rename_absolute(tmp, target) != OK:
		return {"ok": false, "error": "교체 실패 — 임시 파일을 남긴다: %s" % tmp}
	return {"ok": true, "error": ""}


func load_payload(slot: String = SLOT) -> Dictionary:
	var target := path_of(slot)
	if not FileAccess.file_exists(target):
		if FileAccess.file_exists(target + ".bak"):
			var from_bak := _read(target + ".bak")
			if from_bak["status"] == "ok":
				return {"ok": true, "status": "recovered", "data": from_bak["data"]}
		return {"ok": false, "status": "none", "data": {}}
	var loaded := _read(target)
	if loaded["status"] == "newer":
		return {"ok": false, "status": "newer", "data": {}}
	if loaded["status"] == "ok":
		return {"ok": true, "status": "ok", "data": loaded["data"]}
	return _quarantine(target)


func erase(slot: String = SLOT) -> void:
	## 테스트·새 게임용. 세이브 계열 파일만 지운다 — 폴더는 남긴다.
	var target := path_of(slot)
	for path in [target, target + ".tmp", target + ".bak"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)


func _read(path: String) -> Dictionary:
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		return {"status": "corrupt", "data": {}}
	# `JSON.parse_string` 는 실패할 때 엔진 오류를 찍는다 — 손상된 세이브를 읽는 것은
	# 예상된 길이므로 `JSON.parse` 로 조용히 오류 코드만 받는다.
	var json := JSON.new()
	if json.parse(text) != OK:
		return {"status": "corrupt", "data": {}}
	var result := FonsSave.migrate(json.data)
	return {"status": String(result["status"]), "data": result.get("data", {})}


func _quarantine(target: String) -> Dictionary:
	## 손상된 본파일은 지우지 않고 옆으로 옮긴다 — 지우면 복구할 것이 영영 사라진다.
	var aside := "%s.corrupt-%d.json" % [target, int(Time.get_unix_time_from_system())]
	if DirAccess.rename_absolute(target, aside) != OK:
		return {"ok": false, "status": "corrupt", "data": {}}
	var bak := target + ".bak"
	if FileAccess.file_exists(bak):
		var from_bak := _read(bak)
		if from_bak["status"] == "ok":
			return {"ok": true, "status": "recovered", "data": from_bak["data"]}
	return {"ok": false, "status": "corrupt", "data": {}}
