extends State

func enter(_msg: Dictionary = {}) -> void:
	var enemy := actor as Skeleton
	enemy.play_anim(&"idle")

func physics_update(delta: float) -> void:
	var enemy := actor as Skeleton
	enemy.move_dir(Vector2.ZERO, delta)
	var p: Node2D = enemy.get_player()
	if p and enemy.global_position.distance_to(p.global_position) <= enemy.aggro_range:
		state_machine.transition_to(&"approach")
