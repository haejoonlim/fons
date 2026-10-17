class_name FonsView
extends Node
## 뷰 계약 — 2D 뷰와 3D 뷰가 똑같이 구현하는 4개 메서드 + 입력 시그널.
##
## 심은 이 계약을 모른다. run.gd 가 FonsViewFactory 로 뷰를 만들어 붙이고,
## 스냅샷(Dictionary)을 mount/apply 로 밀어 넣는다. 입력은 intent 로만 되돌아온다.
##
## 기본 구현은 조용히 통과하지 않고 push_error 로 실패를 남긴다.
## (상속해서 구현하지 않은 채 화면만 뜨는 상태를 만들지 않기 위해서다.)

signal intent(kind: StringName, payload: Dictionary)

var _mounted := false


func mount(_snapshot: Dictionary) -> void:
	push_error("FonsView.mount() 를 구현하지 않았다: %s" % name)


func apply(_snapshot: Dictionary) -> void:
	push_error("FonsView.apply() 를 구현하지 않았다: %s" % name)


func unmount() -> void:
	push_error("FonsView.unmount() 를 구현하지 않았다: %s" % name)


func is_mounted() -> bool:
	return _mounted
