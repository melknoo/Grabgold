extends State

func physics_update(delta: float) -> void:
	var enemy := actor as Skeleton
	var p: Node2D = enemy.get_player()
	if p == null:
		state_machine.transition_to(&"idle")
		return
	enemy.face_toward(p.global_position)
	enemy.play_anim(&"walk")
	var dist: float = enemy.global_position.distance_to(p.global_position)
	if dist <= enemy.attack_range:
		state_machine.transition_to(&"telegraph")
		return
	enemy.move_dir(p.global_position - enemy.global_position, delta)
