extends State

var _t: int = 0

func enter(_msg: Dictionary = {}) -> void:
	_t = (actor as Skeleton).retreat_frames

func physics_update(delta: float) -> void:
	var enemy := actor as Skeleton
	var p: Node2D = enemy.get_player()
	if p:
		enemy.face_toward(p.global_position)
		enemy.play_anim(&"walk")
		enemy.move_dir(enemy.global_position - p.global_position, delta)
	_t -= 1
	if _t <= 0:
		state_machine.transition_to(&"idle")
