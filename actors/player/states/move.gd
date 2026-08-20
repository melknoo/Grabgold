extends State

func enter(_msg: Dictionary = {}) -> void:
	var player := actor as Player
	player.play_anim(&"walk")

func physics_update(delta: float) -> void:
	var player := actor as Player
	if player.consume_attack():
		state_machine.transition_to(&"attack")
		return
	var input: Vector2 = player.get_input_vector()
	if input == Vector2.ZERO:
		state_machine.transition_to(&"idle")
		return
	var prev: StringName = player.facing
	player.update_facing(input)
	if player.facing != prev:
		player.play_anim(&"walk")
	player.apply_movement(input, delta)
