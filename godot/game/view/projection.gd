class_name FonsProjection
extends RefCounted
## 심의 Vector3(월드) → 2D 화면 Vector2. 순수 함수만 둔다.
##
## 2D/3D 교체의 핵심: 심은 언제나 Vector3 로 말하고, 2D 뷰만 여기서 축을 골라 접는다.
## 3D 뷰는 이 함수를 쓰지 않고 Vector3 를 월드 좌표로 그대로 쓴다.
##
## 부호가 뒤집히는 이유: Godot 화면 y 는 아래로 증가하고, 심의 z(앞)·y(위)는 증가 방향이 반대다.
## 부호를 뒤집지 않으면 화면이 상하 반전된다.

## 이름을 Plane 으로 두면 Godot 내장 타입 Plane 과 충돌한다(파서가 거부한다).
enum Axes { XZ, XY }


static func to_screen(p: Vector3, axes: int = Axes.XZ) -> Vector2:
	match axes:
		Axes.XY:
			# 횡스크롤: x 오른쪽, y 위
			return Vector2(p.x, -p.y)
		_:
			# 탑다운(기본): x 오른쪽, z 앞 → 화면 아래
			return Vector2(p.x, -p.z)
