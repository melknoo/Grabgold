extends State

const STUN_FRAMES := 12
var _stun_left: int = 0

func enter(msg: Dictionary = {}) -> void:
	var player := actor as Player
	player.velocity = msg.get("knockback", Vector2.ZERO)
	_stun_left = STUN_FRAMES
	player.play_anim(&"hurt")

func physics_update(delta: float) -> void:
	var player := actor as Player
	player.velocity = player.velocity.move_toward(Vector2.ZERO, player.stats.friction * delta)
	player.move_and_slide()
	_stun_left -= 1
	if _stun_left <= 0:
		if player.get_input_vector() != Vector2.ZERO:
			state_machine.transition_to(&"move")
		else:
			state_machine.transition_to(&"idle")
