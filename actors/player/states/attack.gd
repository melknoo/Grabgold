extends State

func enter(_msg: Dictionary = {}) -> void:
	var player := actor as Player
	player.velocity = Vector2.ZERO
	player.sprite.animation = "attack_%s" % player.facing
	player.sprite.stop()
	player.sprite.frame = 0
	player.animation_player.play(&"attack")
	player.animation_player.animation_finished.connect(_on_finished, CONNECT_ONE_SHOT)

func exit() -> void:
	var player := actor as Player
	player.disable_hitbox()
	if player.animation_player.animation_finished.is_connected(_on_finished):
		player.animation_player.animation_finished.disconnect(_on_finished)

func physics_update(delta: float) -> void:
	var player := actor as Player
	player.apply_movement(Vector2.ZERO, delta)

func _on_finished(_anim: StringName) -> void:
	var player := actor as Player
	if player.consume_attack():
		state_machine.transition_to(&"attack")
	elif player.get_input_vector() != Vector2.ZERO:
		state_machine.transition_to(&"move")
	else:
		state_machine.transition_to(&"idle")
