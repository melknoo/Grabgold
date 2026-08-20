extends State

var _t: int = 0

func enter(_msg: Dictionary = {}) -> void:
	var enemy := actor as Skeleton
	enemy.enable_hitbox()
	_t = enemy.attack_active_frames

func exit() -> void:
	var enemy := actor as Skeleton
	enemy.disable_hitbox()

func physics_update(delta: float) -> void:
	var enemy := actor as Skeleton
	enemy.move_dir(Vector2.ZERO, delta)
	_t -= 1
	if _t <= 0:
		enemy.disable_hitbox()
		state_machine.transition_to(&"retreat")
