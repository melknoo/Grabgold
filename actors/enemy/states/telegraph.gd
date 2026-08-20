extends State

var _t: int = 0
var _elapsed: int = 0

func enter(_msg: Dictionary = {}) -> void:
	var enemy := actor as Skeleton
	enemy.velocity = Vector2.ZERO
	var p: Node2D = enemy.get_player()
	if p:
		enemy.face_toward(p.global_position)
	enemy.play_anim(&"attack")
	_t = enemy.telegraph_frames
	_elapsed = 0

func exit() -> void:
	var enemy := actor as Skeleton
	enemy.sprite.modulate = Color(1.0, 1.0, 1.0, 1.0)

func physics_update(delta: float) -> void:
	var enemy := actor as Skeleton
	enemy.move_dir(Vector2.ZERO, delta)
	enemy.sprite.modulate = Color(1.0, 0.35, 0.35) if (int(_elapsed / 3) % 2 == 0) else Color(1.0, 1.0, 1.0, 1.0)
	_elapsed += 1
	_t -= 1
	if _t <= 0:
		state_machine.transition_to(&"attack")
